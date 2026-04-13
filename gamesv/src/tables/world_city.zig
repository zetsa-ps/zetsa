pub const list: []const Entry = @import("tables/world_city");

pub fn getById(id: u32) ?Entry {
    for (list) |h| if (h.id == id) return h;
    return null;
}

pub const Entry = struct {
    id: u32,
    city: []const u8,
    type: u32,
    city_story: struct {},
    mount_available: u32,
    default_time: u32,
    time_pass_available: u32,
    lobby_users: u32,
    scene_reborn_time: u32,
    explore_switch: u1,
    formation_sence: []const u8,
    charge: u32,
    bgm: []const u8,
    amb: []const u8,
    art_scene: []const u8,
    play_module: []const u8,
    feature_block_list: []const u32,
    enter_point: []const MapEntry(u32, u32),
    default_height_limit: u32,
};

const MapEntry = @import("../tables.zig").MapEntry;
const LangString = @import("../tables.zig").LangString;
