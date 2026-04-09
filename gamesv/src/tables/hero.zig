pub const data: []const HeroData = @import("tables/hero");

pub fn getById(id: u32) ?HeroData {
    for (data) |h| if (h.id == id) return h;
    return null;
}

pub const Id = gen: {
    var field_names: [data.len][:0]const u8 = undefined;
    var field_values: [data.len]u24 = undefined;
    var active_count: usize = 0;

    for (data) |item| if (item.is_usable != 0) {
        field_values[active_count] = item.id;

        field_names[active_count] = if (std.mem.eql(u8, "STARBORN", item.english_name))
            std.fmt.comptimePrint("{s}_{d}", .{ item.english_name, item.id })
        else
            item.english_name;

        active_count += 1;
    };

    break :gen @Enum(u24, .exhaustive, field_names[0..active_count], field_values[0..active_count]);
};

pub const HeroData = struct {
    id: u24,
    name: LangString,
    english_name: [:0]const u8,
    is_collect: u32,
    favor: u32,
    rarity: u32,
    groups: u32,
    cost: u32,
    position: u32,
    battle_tag: []const u32,
    element: u32,
    unit_id: u32,
    voice: []const u8,
    avatar_texture: []const []const u8,
    uiperform: []const u8,
    uibackground: []const u8,
    uibackground_gift: []const u8,
    level_up_param: []const f32,
    starlink_param: []const f32,
    ui_charging: []const u8,
    ui_charging_param: u32,
    attack_skill: u32,
    level_up_type: u32,
    skill_list: []const MapEntry(u32, u32),
    aerial_skill_list: []const MapEntry(u32, u32),
    passive_skill_list: []const u32,
    home_skill_list: []const u32,
    backup_skill_list: []const u32,
    skill_bytes_path: []const [2][]const u8,
    lifeskill_desc: LangString,
    weapon_type: u32,
    weapon_default: u32,
    skill_system: []const u32,
    dec: LangString,
    property_id: u32,
    leave_behavior_id: u32,
    is_usable: u32,
    main_elementld: []const u32,
    collision_type: u32,
    swim_param: []const f32,
    nest_coop_team: []const [3]f32,
    nest_coop_team_action: []const u8,
    kibo_duel_info: []const [3]f32,
    kibo_duel_formation: []const [3]f32,
    gift_info: []const [3]f32,
    gift_action: []const u8,
    fish_action: u32,
    cut_stone_param: []const f32,
    cut_tree_param: []const f32,
    playercard_dress: []const []const u32,
    enter_skill_offset: f32,
    hero_pixel_idle: []const u8,
    hero_pixel_walk: []const u8,
    nestcoop_success_action: []const u8,

    pub fn getId(h: *const HeroData) Id {
        return @enumFromInt(h.id);
    }
};

const LangString = tables.LangString;
const MapEntry = tables.MapEntry;
const tables = @import("../tables.zig");
const std = @import("std");
