pub const list: []const Entry = @import("tables/unit_property");

pub fn getById(id: u32) ?Entry {
    for (list) |h| if (h.id == id) return h;
    return null;
}

pub const Entry = struct {
    id: u32,
    base_attribute_id: u32,
    behavior: u32,
    confront_distance: f32,
    avoidness_heat_level: u32,
    avoidness_heat_decay_rate: f32,
    flash_rate: u32,
    follow_id: i32,
};
