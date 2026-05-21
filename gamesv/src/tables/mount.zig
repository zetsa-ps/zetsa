pub const list: []const Entry = @import("tables/mount");

pub fn getById(id: u32) ?Entry {
    for (list) |e| if (e.id == id) return e;
    return null;
}

pub const Entry = struct {
    id: u32,
    name: LangString,
    move_type: []const u32,
    default_move_type: u32,
    default_move_type_water: u32,
    move_desc: LangString,
    desc: LangString,
    rarity: u32,
    control_config: []const u8,
    icon: []const u8,
    default_saddle: []const u8,
    unlock: u32, // saddle
    unlock_condition: []const u32,
    homelevelshow: u32,
    fast_move_speed: u32,
    deceleration: u32,
    max_fly_distance: u32,
    landing_distance: u32,
    sprint_cd: []const f32,
    collision_type: u32,
    consume: [3][2]f32,
    dash_cost: f32,
    jump_cost: f32,
    skill_cost: f32,
    min_water_depth: f32,
    collider_info: [4]f32,
    skill_ability: u32,
};

const LangString = tables.LangString;
const tables = @import("../tables.zig");
