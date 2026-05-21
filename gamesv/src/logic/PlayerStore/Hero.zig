pub const ItemMap = EnumMap(ID, Item);

item_map: ItemMap,

pub const init: HeroData = .{
    .item_map = .init(.{}),
};

pub const Item = struct {
    lv: Level,
    exp: u32,
    rank: Rank,
    system_skill_levels: [SystemSkillLevel.count]SystemSkillLevel,

    soul_essence_id: u32,
    pet_id: u64,

    hp: logic.big_world.Hp,
    sp: logic.big_world.Sp,

    pub fn initDefault(id: ID) Item {
        return .{
            .lv = .min,
            .exp = 0,
            .rank = .min,
            .system_skill_levels = @splat(.min),
            .soul_essence_id = 0,

            .hp = @enumFromInt(logic.big_world.getHeroBaseAttrValue(.maxhp, @intFromEnum(id), 1, 1)),
            .sp = .full,
            .pet_id = 0,
        };
    }
};

pub fn unlockById(hero_data: *HeroData, id: ID) void {
    if (hero_data.item_map.contains(id))
        return;

    hero_data.item_map.put(id, .initDefault(id));
}

pub const ID = tables.hero.Id;
pub const Level = tables.hero_level.Level;

pub const Rank = enum(u8) {
    min = 1,
    _,

    pub fn toInt(rank: Rank) u8 {
        return @intFromEnum(rank);
    }
};

pub const SystemSkillLevel = enum(u8) {
    pub const count: usize = 6;

    min = 1,
    _,

    pub fn toInt(rank: Rank) u8 {
        return @intFromEnum(rank);
    }
};

pub const Type = enum {
    normal,
    main,

    pub fn toHeroType(t: Type) u32 {
        return @intCast(@intFromEnum(@as(proto.pb.HeroType, switch (t) {
            .normal => .HT_NORMAL,
            .main => .HT_MAIN,
        })));
    }

    pub fn byHeroId(id: ID) Type {
        return switch (@intFromEnum(id)) {
            tables.game.avatar_hero_id_male,
            tables.game.avatar_hero_id_female,
            => .main,
            else => .normal,
        };
    }
};

pub const Ref = enum(u64) {
    none = 0,
    _,

    pub inline fn fromUuid(uuid: logic.Uuid) Ref {
        return @enumFromInt(uuid.toInt());
    }

    pub inline fn toUuid(self: Ref) ?logic.Uuid {
        const raw = @intFromEnum(self);
        if (raw == 0) return null;
        return logic.Uuid.fromInt(raw);
    }
};

const EnumMap = std.enums.EnumMap;

const tables = @import("../../tables.zig");
const logic = @import("../../logic.zig");
const proto = @import("proto");
const std = @import("std");
const HeroData = @This();
