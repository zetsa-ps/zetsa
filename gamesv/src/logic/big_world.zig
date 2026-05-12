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

    pub fn change(hp: *Hp, chg: i32) void {
        hp.* = @enumFromInt(@max(0, @intFromEnum(hp.*) +| chg));
    }
};

pub const Sp = enum(u32) {
    exhausted = 0,
    full = 100,
    _,

    pub fn toInt(sp: Sp) u32 {
        return @intFromEnum(sp);
    }

    pub fn fromInt(int: u32) Sp {
        return @enumFromInt(@min(@intFromEnum(Sp.full), int));
    }
};

pub const EBattlePropertyType = enum(i32) {
    none = 0,
    atk = 1,
    matk = 2,
    def = 3,
    mdef = 4,
    maxhp = 5,
    maxsp = 6,
    cri = 7,
    cri_dmg = 8,
    shoot_dmgup = 21,
    suffer_dmgdown = 22,
    shoot_healup = 23,
    suffer_healup = 24,
    physical_shootdmgup = 25,
    physical_sufferdmgdown = 26,
    magic_shootdmgdup = 27,
    magic_sufferdmgdown = 28,
    perpiercing = 29,
    permpiercing = 30,
    leech = 31,
    rebound = 32,
    colddown = 33,
    mass = 34,
    speed = 35,
    fastrun_speedfactor = 36,
    walk_speed = 37,
    engage_speed = 38,
    mount_jump_height = 39,
    mount_jump_distance = 40,
    pet_mount_operatejumpstate = 43,
    pet_mount_dodge = 44,
    speed_ratio = 45,
    normal_shootdmgup = 51,
    fire_shootdmgup = 52,
    wind_shootdmgup = 53,
    earth_shootdmgup = 54,
    wood_shootdmgup = 55,
    ice_shootdmgup = 56,
    water_shootdmgup = 57,
    elec_shootdmgup = 58,
    light_shootdmgup = 59,
    dark_shootdmgup = 60,
    normal_defense = 61,
    fire_defense = 62,
    wind_defense = 63,
    earth_defense = 64,
    wood_defense = 65,
    ice_defense = 66,
    water_defense = 67,
    elec_defense = 68,
    light_defense = 69,
    dark_defense = 70,
    cri_sufferdmgdown = 101,
    cri_defense = 102,
    steeringspeed = 103,
    blockthrows = 104,
    spgetup = 105,
    soldier_sufferaoedmgdown = 106,
    piercing = 107,
    mpiercing = 108,
    hpr_sec = 109,
    spr_sec = 110,
    shield = 111,
    threat = 112,
    interruptionlevel = 113,
    attack_token = 114,
    cd_skill = 115,
    cd_skill_1 = 116,
    cd_skill_2 = 117,
    cd_skill_3 = 118,
    cd_skill_4 = 119,
    cd_skill_5 = 120,
    counter_threshold = 121,
    shoot_shieldup = 122,
    suffer_shieldup = 123,
    shield_defense = 124,
    attack_shootdmgup = 125,
    attack_sufferdmgdown = 126,
    chargedattack_shootdmgup = 127,
    chargedattack_sufferdmgdown = 128,
    skill_shootdmgup = 129,
    skill_sufferdmgdown = 130,
    aerialattack_shootdmgup = 131,
    aerialattack_sufferdmgdown = 132,
    ultraattack_shootdmgup = 133,
    ultraattack_sufferdmgdown = 134,
    switchenergy = 135,
    switchenergy_limit = 136,
    switchenergy_recoveryrate = 137,
    fire_reverberationdefense = 138,
    wind_reverberationdefense = 139,
    earth_reverberationdefense = 140,
    wood_reverberationdefense = 141,
    ice_reverberationdefense = 142,
    water_reverberationdefense = 143,
    elec_reverberationdefense = 144,
    light_reverberationdefense = 145,
    dark_reverberationdefense = 146,
    all_reverberationdefense = 147,
    fire_reverberationpiercing = 148,
    wind_reverberationpiercing = 149,
    earth_reverberationpiercing = 150,
    wood_reverberationpiercing = 151,
    ice_reverberationpiercing = 152,
    water_reverberationpiercing = 153,
    elec_reverberationpiercing = 154,
    light_reverberationpiercing = 155,
    dark_reverberationpiercing = 156,
    all_reverberationpiercing = 157,
    cd_skill_206 = 158,
    weakness_point_max = 201,
    wdm_physical = 202,
    wdm_magic = 203,
    wdm_heal = 204,
    wdm_normal = 205,
    wdm_fire = 206,
    wdm_wind = 207,
    wdm_earth = 208,
    wdm_wood = 209,
    wdm_ice = 210,
    wdm_water = 211,
    wdm_elec = 212,
    wdm_light = 213,
    wdm_dark = 214,
    wdm_min = 215,
    wdm_max = 216,
    wp_recovery_delay = 217,
    wp_recovery_rate = 218,
    wp_break_time = 219,
    wp_break_end_time = 220,
    wp_break_dmgup = 221,
    wdm_tag_heavyattack = 222,
    dodge = 225,
    mastery = 229,
    pet_reborn = 302,
    kibo_cost = 304,
    kibo_max = 305,
    kibo_recovery_speed = 306,
    kibo_cost_init = 307,
    fly_level = 998,
    impact_resistance = 999,
    per_atk = 1001,
    per_matk = 1002,
    per_def = 1003,
    per_mdef = 1004,
    per_maxhp = 1005,
    per_mass = 1006,
    per_speed = 1007,
    extra_atk = 2001,
    extra_matk = 2002,
    extra_def = 2003,
    extra_mdef = 2004,
    extra_maxhp = 2005,
    extra_mass = 2006,
    extra_speed = 2007,
    spr_sec_back = 226,
    spret_auto = 227,
    spgetup_atk = 228,
};

pub const ESkillSlotType = enum(i32) {
    none = 0,
    attack = 1,
    skill1 = 2,
    skill2 = 3,
    ultra_skill = 4,
    command_pet_ultra = 5,
    coop_skill = 11,
    ai_legal_slot_range = 100,
    evade = 101,
    evade_back = 102,
    jump = 114,
    double_jump = 115,
    exit_skill = 201,
    enter_dash = 202,
    enter_skill = 203,
    evade_attack = 204,
    pet_ultra_blink = 205,
    pet_ultra = 206,
    evade_boost_attack = 207,
    player_joint_strike_skill = 208,
    counter_measures = 209,
    aerial_attack = 301,
    jump_back = 401,
    jump_left = 402,
    jump_right = 403,
    pet_puzzle_skill = 501,
    pet_puzzle_blink = 502,
    pet_communicate = 504,
    pet_joint_strike_skill = 601,
    kibo_versus_common_skill1 = 701,
    kibo_versus_common_skill2 = 702,
};

pub const Attributes = EnumMap(EBattlePropertyType, i64);

pub fn getHeroAttributes(id: tables.hero.Id, level: u32, rank: u32, out: *Attributes) void {
    const hero = tables.hero.getById(@intFromEnum(id)).?;
    const att_id = tables.unit_property.getById(hero.property_id).?.base_attribute_id;
    const base_att_id = tables.template_hero.getBaseAttributeByRankAndLevel(rank, level);
    const base_template = tables.template_value.getById(base_att_id).?;

    const base_values = base_template.base_attribute;
    const factor_template = tables.template_value.getById(att_id).?;

    const factor_values = factor_template.base_attribute;
    var factor_map: std.EnumMap(EBattlePropertyType, f32) = .init(.{});

    for (factor_values) |entry| factor_map.put(
        std.enums.fromInt(EBattlePropertyType, entry.key) orelse continue,
        entry.value,
    );

    for (base_values) |entry| {
        const key = std.enums.fromInt(EBattlePropertyType, entry.key) orelse continue;

        out.put(key, if (factor_map.get(key)) |factor|
            @trunc(entry.value * factor)
        else
            0);
    }
}

pub fn getHeroBaseAttrValue(attr: EBattlePropertyType, hero_id: u32, hero_level: u32, hero_rank: u32) i64 {
    const hero = tables.hero.getById(hero_id).?;
    const hero_att_id = tables.unit_property.getById(hero.property_id).?.base_attribute_id;
    const hero_base_att_id = tables.template_hero.getBaseAttributeByRankAndLevel(hero_rank, hero_level);
    const base_template = tables.template_value.getById(hero_base_att_id);

    const base_values = base_template.?.base_attribute;
    const factor_template = tables.template_value.getById(hero_att_id);

    const factor_values = factor_template.?.base_attribute;

    for (base_values) |bv_entry| {
        if (bv_entry.key == @intFromEnum(attr)) {
            for (factor_values) |f_entry| {
                if (f_entry.key == @intFromEnum(attr)) {
                    return @trunc(bv_entry.value * f_entry.value);
                }
            }
        }
    } else return 0;
}

pub fn getEnemyBaseAttrValue(attr: EBattlePropertyType, enemy_id: u32, template_id: u32, level: u32) i64 {
    const enemy = tables.enemy.getById(enemy_id).?;
    const enemy_att_id = tables.unit_property.getById(enemy.property_id).?.base_attribute_id;

    const enemy_base_att_id = level + 1000 * (template_id + 3000);

    const base_template = tables.template_value.getById(enemy_base_att_id).?;
    const base_values = base_template.base_attribute;

    const factor_template = tables.template_value.getById(enemy_att_id);
    const factor_values = factor_template.?.base_attribute;

    for (base_values) |bv_entry| {
        if (bv_entry.key == @intFromEnum(attr)) {
            for (factor_values) |f_entry| {
                if (f_entry.key == @intFromEnum(attr)) {
                    return @trunc(bv_entry.value * f_entry.value);
                }
            }
        }
    } else return 0;
}

pub fn getSoulEssenceAttributes(id: u32, level: u32, rank: u32, out: *Attributes) void {
    for (tables.soulessence_rank.getChildren(id).?[rank - 1].rank_up_attribute_all) |entry| {
        const key = std.enums.fromInt(EBattlePropertyType, entry.key) orelse continue;
        out.put(
            key,
            (out.get(key) orelse 0) + scaledAttrIncrement(key, entry.value),
        );
    }

    for (tables.soulessence_value.getById(tables.soulessence.getById(id).?.attribute * 1000 + level).?.base_attribute) |entry| {
        const key = std.enums.fromInt(EBattlePropertyType, entry.key) orelse continue;
        out.put(key, (out.get(key) orelse 0) + scaledAttrIncrement(
            key,
            entry.value,
        ));
    }
}

pub fn getSoulEssenceBaseAttrValue(attr: EBattlePropertyType, id: u32, level: u32, rank: u32) i64 {
    var total: i64 = 0;

    if (tables.soulessence_rank.getChildren(id)) |children| {
        for (children[rank - 1].rank_up_attribute_all) |entry| {
            const key = std.enums.fromInt(EBattlePropertyType, entry.key) orelse continue;
            if (key == attr) {
                total += scaledAttrIncrement(key, entry.value);
                break;
            }
        }
    }

    if (tables.soulessence_value.getById(tables.soulessence.getById(id).?.attribute * 1000 + level)) |base| {
        for (base.base_attribute) |entry| {
            const key = std.enums.fromInt(EBattlePropertyType, entry.key) orelse continue;
            if (key == attr) {
                total += scaledAttrIncrement(key, entry.value);
                break;
            }
        }
    }

    return total;
}

fn scaledAttrIncrement(key: EBattlePropertyType, value: anytype) i64 {
    const is_special_att = switch (key) {
        .atk, .def, .mdef, .maxhp, .weakness_point_max, .mastery => true,
        else => false,
    };

    return switch (@typeInfo(@TypeOf(value))) {
        .int, .comptime_int => if (is_special_att)
            @as(i64, @intCast(value * 10000))
        else
            @as(i64, @intCast(value)),
        .float, .comptime_float => if (is_special_att)
            @as(i64, @intFromFloat(@floor(value * 10000.0)))
        else
            @as(i64, @intFromFloat(@floor(value))),
        else => @compileError("Unsupported value type: " ++ @typeName(@TypeOf(value))),
    };
}

const EnumMap = std.EnumMap;

const tables = @import("../tables.zig");
const proto = @import("proto");
const std = @import("std");
