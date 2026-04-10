pub const ItemMap = EnumMap(ID, HeroItem);
pub const BattleMap = EnumMap(ID, BattleHero);

item_map: ItemMap,
battle_map: BattleMap,

pub const init: HeroData = .{
    .item_map = .init(.{}),
    .battle_map = .init(.{}),
};

pub const HeroItem = struct {
    lv: Level,
    exp: u32,
    rank: Rank,
    system_skill_levels: [SystemSkillLevel.count]SystemSkillLevel,

    pub fn initDefault() HeroItem {
        return .{
            .lv = .min,
            .exp = 0,
            .rank = .min,
            .system_skill_levels = @splat(.min),
        };
    }
};

pub const BattleHero = struct {
    hp: Hp,
    sp: Sp,

    pub fn initDefault(id: ID) BattleHero {
        return .{
            .hp = @enumFromInt(logic.big_world.getHeroBaseAttrValue(.maxhp, @intFromEnum(id), 1, 1)),
            .sp = .full,
        };
    }
};

pub const Hp = enum(i33) {
    dead = 0,
    _,

    pub fn toInt(hp: Hp) u32 {
        const int = @intFromEnum(hp);
        if (int < 0) return 0;

        return @intCast(int);
    }

    pub const AliveState = enum {
        alive,
        dead,
        overhurt,

        pub fn toAliveStateType(as: AliveState) u32 {
            return @intCast(@intFromEnum(@as(proto.pb.AliveStateType, switch (as) {
                .alive => .AST_Alive,
                .dead => .AST_Dead,
                .overhurt => .AST_OverHurt,
            })));
        }
    };

    pub fn aliveState(hp: Hp) AliveState {
        return switch (hp) {
            .dead => .dead,
            else => if (@intFromEnum(hp) < 0) .overhurt else .alive,
        };
    }
};

pub const Sp = enum(u32) {
    exhausted = 0,
    full = 100,
    _,

    pub fn toInt(sp: Sp) u32 {
        return @intFromEnum(sp);
    }
};

pub fn unlockById(hero_data: *HeroData, id: ID) void {
    if (hero_data.item_map.contains(id))
        return;

    hero_data.item_map.put(id, .initDefault());
    hero_data.battle_map.put(id, .initDefault(id));
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

const EnumMap = std.enums.EnumMap;

const tables = @import("../../tables.zig");
const logic = @import("../../logic.zig");
const proto = @import("proto");
const std = @import("std");
const HeroData = @This();
