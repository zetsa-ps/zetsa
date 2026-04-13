const log = std.log.scoped(.@"gamesv::logic::Services::Battle");

objects: MultiArrayList(Object),
map_config: ?*const Assets.WorldMaps.Entry,

pub const init: Battle = .{
    .objects = .empty,
    .map_config = null,
};

pub const Object = struct {
    uuid: Uuid,
    hp: big_world.Hp,
    sp: big_world.Sp,
};

pub const Frame = struct {
    participators: []const u64,

    pub fn fromReduce(reduce: *const pb.BattleInfoReduce) Frame {
        return .{ .participators = reduce.uint64_dic.items };
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

pub fn reset(
    battle: *Battle,
    gpa: Allocator,
    player_store: *logic.PlayerStore,
) Allocator.Error!void {
    const formation_group = player_store.lineup.group_map.getPtr(.world).?;
    const heros = &formation_group.formation_heros[formation_group.cur_formation];

    battle.objects.clearRetainingCapacity();
    try battle.objects.ensureTotalCapacity(gpa, heros.len);

    for (heros) |hero_pos| if (hero_pos.toHeroId()) |hero_id| {
        const hero = player_store.hero.item_map.getPtr(hero_id).?;

        battle.objects.appendAssumeCapacity(.{
            .uuid = .hero(player_store.id, hero_id),
            .hp = @enumFromInt(hero.hp.toInt() / 10_000),
            .sp = hero.sp,
        });
    };
}

// TODO: O(1) indexing
pub fn getObjectIndexByUuid(battle: *Battle, uuid: Uuid) ?usize {
    return std.mem.findScalar(Uuid, battle.objects.items(.uuid), uuid);
}

pub fn instantiateEnemyGroup(battle: *Battle, gpa: Allocator, id: u32) Allocator.Error!void {
    const config = battle.map_config orelse return;
    const point = config.getPoint(id) orelse return;
    const enemy_group = tables.world_enemy_group.getById(point.config.expand_id) orelse return;

    const world_area_ids = point.worldAreaIds();
    const area_id = if (world_area_ids.len != 0) world_area_ids[0] else 0;

    log.debug("instantiating group {d} of {d} monsters", .{ id, enemy_group.enemy_list.len });
    try battle.objects.ensureUnusedCapacity(gpa, enemy_group.enemy_list.len);

    for (enemy_group.enemy_list, 0..) |enemy_pack_id, i| {
        const enemy_pack = tables.enemy_pack.getById(enemy_pack_id) orelse return;
        const enemy = tables.enemy.getById(enemy_pack.enemy_id) orelse return;

        const level = getEnemyLevel(&enemy_pack, config.points[0].city_id, area_id, 1);
        const template_id = if (enemy_pack.template_id == 0) enemy.enemy_type else enemy_pack.template_id;

        const hp = logic.big_world.getEnemyBaseAttrValue(.maxhp, enemy_pack.enemy_id, template_id, level);

        battle.objects.appendAssumeCapacity(.{
            .uuid = .monster(id, @truncate(i)),
            .hp = @enumFromInt(@divFloor(hp, 10_000)),
            .sp = .exhausted,
        });
    }
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

// TODO: index-based free_list
pub fn resetEnemyGroup(battle: *Battle, id: u32) void {
    const config = battle.map_config orelse return;
    const point = config.getPoint(id) orelse return;
    const enemy_group = tables.world_enemy_group.getById(point.config.expand_id) orelse return;

    var i: u24 = 0;
    while (i < enemy_group.enemy_list.len) : (i += 1) {
        const index = battle.getObjectIndexByUuid(.monster(id, @truncate(i))) orelse continue;
        battle.objects.swapRemove(index);
    }
}

const Uuid = logic.Uuid;
const Allocator = std.mem.Allocator;
const MultiArrayList = std.MultiArrayList;

const pb = proto.pb;
const big_world = logic.big_world;

const Assets = @import("../../Assets.zig");
const tables = @import("../../tables.zig");
const logic = @import("../../logic.zig");
const proto = @import("proto");
const std = @import("std");
const Battle = @This();
