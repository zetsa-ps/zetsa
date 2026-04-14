const log = std.log.scoped(.@"gamesv::logic::Services::Battle");

objects: MultiArrayList(Object),
free_list: Object.List,
modified_list: Object.List,
modified_count: u32 = 0,
map_config: ?*const Assets.WorldMaps.Entry,

pub const init: Battle = .{
    .objects = .empty,
    .free_list = .empty,
    .modified_list = .empty,
    .modified_count = 0,
    .map_config = null,
};

pub const Object = struct {
    uuid: Uuid,
    hp: big_world.Hp,
    sp: big_world.Sp,

    // Singly-linked-list node.
    next: OptionalIndex,
    state: State,

    pub const State = enum { idle, free, modified };

    pub const OptionalIndex = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn toInt(oi: OptionalIndex) u32 {
            debug.assert(oi != .none);
            return @intFromEnum(oi);
        }

        pub fn fromInt(int: u32) OptionalIndex {
            debug.assert(int != std.math.maxInt(u32));
            return @enumFromInt(int);
        }
    };

    pub const List = struct {
        pub const empty: List = .{ .head = .none };

        head: OptionalIndex,

        pub fn pop(list: *List, storage: []const OptionalIndex) OptionalIndex {
            const head = list.head;

            list.head = switch (head) {
                .none => .none,
                _ => storage[head.toInt()],
            };

            return head;
        }

        pub fn prepend(list: *List, storage: []OptionalIndex, index: u32) void {
            storage[index] = list.head;
            list.head = .fromInt(index);
        }
    };

    pub const Iterator = struct {
        list: *Object.List,
        storage: []OptionalIndex,
        state_list: []Object.State,

        pub fn next(it: Iterator) ?u32 {
            switch (it.list.pop(it.storage)) {
                .none => return null,
                _ => |i| {
                    const index = i.toInt();

                    it.state_list[index] = .idle;
                    return index;
                },
            }
        }
    };

    pub fn Batch(capacity: usize) type {
        return struct {
            pub const init: @This() = .{
                .uuid_list = undefined,
                .hp_list = undefined,
                .sp_list = undefined,
                .count = 0,
            };

            uuid_list: [capacity]Uuid,
            hp_list: [capacity]big_world.Hp,
            sp_list: [capacity]big_world.Sp,
            count: u32,

            pub fn add(batch: *@This(), uuid: Uuid, hp: big_world.Hp, sp: big_world.Sp) void {
                debug.assert(batch.count < capacity);

                const i = batch.count;
                batch.uuid_list[i] = uuid;
                batch.hp_list[i] = hp;
                batch.sp_list[i] = sp;

                batch.count += 1;
            }

            pub fn toSlices(batch: *const @This()) Slices {
                return .{
                    .count = batch.count,
                    .uuid = &batch.uuid_list,
                    .hp = &batch.hp_list,
                    .sp = &batch.sp_list,
                };
            }
        };
    }

    pub const Slices = struct {
        count: u32,
        uuid: [*]const Uuid,
        hp: [*]const big_world.Hp,
        sp: [*]const big_world.Sp,
    };
};

const Frame = struct {
    participators: []const u64,

    pub fn fromReduce(message: *const pb.BattleInfoReduce) Frame {
        return .{ .participators = message.uint64_dic.items };
    }

    pub fn getParticipatorAt(frame: *const Frame, index: usize) ?Uuid {
        return if (index == 0 or frame.participators.len <= index - 1)
            null
        else
            @bitCast(frame.participators[index - 1]);
    }
};

pub fn deinit(battle: *Battle, gpa: Allocator) void {
    battle.objects.deinit(gpa);
}

pub fn reduce(battle: *Battle, message: *const pb.BattleInfoReduce) void {
    const frame: Frame = .fromReduce(message);

    const slice = battle.objects.slice();
    const hp_list = slice.items(.hp);
    const node_list = slice.items(.next);
    const uuid_list = slice.items(.uuid);
    const state_list = slice.items(.state);

    for (message.battle_info.items) |battle_info| if (battle_info.hurt_info) |hurt_info| {
        const hp_change = hurt_info.hp_change orelse continue;
        const target_uuid = frame.getParticipatorAt(hurt_info.tar_id orelse continue) orelse continue;
        const index: u32 = @intCast(std.mem.findScalar(Uuid, uuid_list, target_uuid) orelse continue);

        switch (state_list[index]) {
            .idle => {
                state_list[index] = .modified;
                battle.modified_list.prepend(node_list, index);
                battle.modified_count += 1;
            },
            .modified => {},
            .free => continue,
        }

        hp_list[index].change(hp_change);
    };
}

pub fn reset(
    battle: *Battle,
    gpa: Allocator,
    player_store: *logic.PlayerStore,
) Allocator.Error!void {
    battle.objects.clearRetainingCapacity();
    battle.free_list.head = .none;
    battle.modified_list.head = .none;
    battle.modified_count = 0;

    const formation_group = player_store.lineup.group_map.getPtr(.world).?;
    const heros = &formation_group.formation_heros[formation_group.cur_formation];

    var batch: Object.Batch(Lineup.Formation.HeroPos.count) = .init;

    for (heros) |hero_pos| if (hero_pos.toHeroId()) |hero_id| {
        const hero = player_store.hero.item_map.getPtr(hero_id).?;
        batch.add(
            .hero(player_store.id, hero_id),
            @enumFromInt(@divFloor(hero.hp.toInt(), 10_000)),
            hero.sp,
        );
    };

    try battle.add(gpa, batch.toSlices());
}

pub fn modified(battle: *Battle) Object.Iterator {
    battle.modified_count = 0;

    const slice = battle.objects.slice();

    return .{
        .list = &battle.modified_list,
        .storage = slice.items(.next),
        .state_list = slice.items(.state),
    };
}

fn add(battle: *Battle, gpa: Allocator, slices: Object.Slices) Allocator.Error!void {
    var allocated: ?u32 = null;

    var i: u32 = 0;
    while (i < slices.count) : (i += 1) {
        const index: u32 = if (allocated) |allocated_index| allocated: {
            allocated = allocated_index + 1;
            break :allocated allocated_index;
        } else switch (battle.free_list.pop(battle.objects.items(.next))) {
            _ => |oi| oi.toInt(),
            .none => allocation: {
                const needed = slices.count - i;

                try battle.objects.ensureUnusedCapacity(gpa, needed);

                // Save the next available index from the newly allocated space.
                allocated = @truncate(battle.objects.len + 1);
                battle.objects.len += needed;

                break :allocation allocated.? - 1;
            },
        };

        battle.objects.set(index, .{
            .uuid = slices.uuid[i],
            .hp = slices.hp[i],
            .sp = slices.sp[i],
            .next = .none,
            .state = .modified,
        });

        battle.modified_list.prepend(battle.objects.items(.next), index);
    }

    battle.modified_count += slices.count;
}

pub fn instantiateEnemyGroup(battle: *Battle, gpa: Allocator, id: u32) Allocator.Error!void {
    const config = battle.map_config orelse return;
    const point = config.getPoint(id) orelse return;
    const enemy_group = tables.world_enemy_group.getById(point.config.expand_id) orelse return;

    const world_area_ids = point.worldAreaIds();
    const area_id = if (world_area_ids.len != 0) world_area_ids[0] else 0;

    log.debug("instantiating group {d} of {d} monsters", .{ id, enemy_group.enemy_list.len });

    // Batch with the size of max length of enemy_list in world_enemy_group
    // In case it was still not enough for some reason, the batch will be committed and cleaned,
    // continuing to add objects.
    const batch_size: usize = 12;
    var batch: Object.Batch(batch_size) = .init;

    var i: u24 = 0;
    while (i < enemy_group.enemy_list.len) : (i += 1) {
        const enemy_pack = tables.enemy_pack.getById(enemy_group.enemy_list[i]) orelse return;
        const enemy = tables.enemy.getById(enemy_pack.enemy_id) orelse return;

        const level = getEnemyLevel(&enemy_pack, config.points[0].city_id, area_id, 1);
        const template_id = if (enemy_pack.template_id == 0) enemy.enemy_type else enemy_pack.template_id;

        const max_hp = logic.big_world.getEnemyBaseAttrValue(.maxhp, enemy_pack.enemy_id, template_id, level);
        batch.add(.monster(id, i), @enumFromInt(@divFloor(max_hp, 10_000)), .exhausted);

        if (batch.count == batch_size) {
            try battle.add(gpa, batch.toSlices());
            batch.count = 0;
        }
    } else if (batch.count != 0)
        try battle.add(gpa, batch.toSlices());
}

fn getEnemyLevel(enemy_pack: *const tables.enemy_pack.Entry, map_id: u32, area_id: u32, difficulty: u32) u32 {
    const level_param = if (area_id == 0) enemy_pack.level_parameter else lookup: for (enemy_pack.level_area_parameter) |entry| {
        if (entry.key == area_id) break :lookup entry.value;
    } else break :lookup enemy_pack.level_parameter;

    if (enemy_pack.level_policy != 1) {
        log.warn("unimplemented level policy: {d}", .{enemy_pack.level_policy});
        return 1;
    } else return if (tables.world_difficulty_obj_level.get(level_param, difficulty, map_id)) |obj|
        obj.monster_level
    else
        1;
}

pub fn resetEnemyGroup(battle: *Battle, id: u32) void {
    const config = battle.map_config orelse return;
    const point = config.getPoint(id) orelse return;
    const enemy_group = tables.world_enemy_group.getById(point.config.expand_id) orelse return;

    const slice = battle.objects.slice();
    const node_list = slice.items(.next);
    const uuid_list = slice.items(.uuid);
    const state_list = slice.items(.state);

    var i: u24 = 0;
    while (i < enemy_group.enemy_list.len) : (i += 1) {
        const index: u32 = @intCast(std.mem.findScalar(Uuid, uuid_list, .monster(id, i)) orelse continue);
        debug.assert(state_list[index] != .free);

        uuid_list[index] = .zero;
        state_list[index] = .free;
        battle.free_list.prepend(node_list, index);
    }
}

const Uuid = logic.Uuid;
const Lineup = logic.PlayerStore.Lineup;

const Allocator = std.mem.Allocator;
const MultiArrayList = std.MultiArrayList;

const pb = proto.pb;
const big_world = logic.big_world;

const debug = std.debug;

const Assets = @import("../../Assets.zig");
const tables = @import("../../tables.zig");
const logic = @import("../../logic.zig");
const proto = @import("proto");
const std = @import("std");
const Battle = @This();
