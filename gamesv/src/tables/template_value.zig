pub const list: []const Entry = @import("tables/template_value");

pub fn getById(id: u32) ?Entry {
    for (list) |h| if (h.id == id) return h;
    return null;
}

pub const Entry = struct {
    id: u32,
    base_attribute: []const MapEntry(u32, f32),
};

const MapEntry = @import("../tables.zig").MapEntry;
