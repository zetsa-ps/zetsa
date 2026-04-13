pub const list: []const Entry = @import("tables/enemy_pack");

pub fn getById(id: u32) ?Entry {
    for (list) |h| if (h.id == id) return h;
    return null;
}

pub const Entry = struct {
    id: u32,
    enemy_id: u32,
    e_camp_type: u32,
    level_policy: u32,
    level_parameter: u32,
    level_area_parameter: []const MapEntry(u32, u32),
    template_id: u32,
    slot_tag: u32,
    drop_id: []const u32,
    level_step_drop: []const [3]u32,
    uncatchable_type: u32,
    levelpressure_type: u32,
    special_create_type: u32,
};

const MapEntry = tables.MapEntry;
const tables = @import("../tables.zig");
