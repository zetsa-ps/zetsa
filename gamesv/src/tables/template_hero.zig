pub const list: []const Entry = @import("tables/template_hero");

pub fn getById(id: u32) ?Entry {
    for (list) |h| if (h.id == id) return h;
    return null;
}

pub fn getBaseAttributeByRankAndLevel(rank: u32, level: u32) u32 {
    _ = rank;

    const id = level;
    const v = getById(id) orelse getById(1).?;

    return v.base_attribute;
}

pub const Entry = struct {
    type: u32,
    id: u32,
    ascension: u32,
    base_attribute: u32,
    level: u32,
};
