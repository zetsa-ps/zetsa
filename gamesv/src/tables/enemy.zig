pub const list: []const Entry = @import("tables/enemy");

pub fn getById(id: u32) ?Entry {
    for (list) |h| if (h.id == id) return h;
    return null;
}

pub const Entry = struct {
    id: u32,
    name: LangString,
    desc: LangString,
    unit_id: u32,
    attack_skill: u32,
    passive_skill_list: []const u32,
    backup_skill_list: []const u32,
    skill_bytes_path: []const [2][]const u8,
    change_skill_list: []const ?u32,
    enemy_type: u32,
    element: []const u32,
    hp_bar_type: u32,
    hp_index: []const u32,
    hp_bar_weakness: u32,
    knis_attack_distance: []const u32,
    hp_bar_name: u32,
    boss_item_num: u32,
    property_id: u32,
    is_usable: u32,
    avatar_texture: []const u8,
    collision_type: u32,
    world_collision_type: u32,
    pet_id: u32,
    catch_camera_param: u32,
    world_property_id: u32,
    move_type: []const u32,
    default_move_type: u32,
    gameplay_tag: []const u8,
};

const LangString = tables.LangString;
const MapEntry = tables.MapEntry;
const tables = @import("../tables.zig");
