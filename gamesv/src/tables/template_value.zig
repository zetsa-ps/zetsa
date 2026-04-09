pub const data: []const TemplateValue = @import("tables/template_value");

pub fn getById(id: u32) ?TemplateValue {
    for (data) |h| if (h.id == id) return h;
    return null;
}

pub const TemplateValue = struct {
    id: u32,
    base_attribute: []const MapEntry(u32, f32),
};

const MapEntry = @import("../tables.zig").MapEntry;
