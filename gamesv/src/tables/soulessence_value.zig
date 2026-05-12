pub const list: []const Entry = @import("tables/soulessence_value");

pub fn getById(id: u32) ?Entry {
    for (list) |e| if (e.id == id) return e;
    return null;
}

pub const Entry = struct {
    id: u32,
    base_attribute: []const MapEntry(u32, f32),
};

const MapEntry = @import("../tables.zig").MapEntry;
