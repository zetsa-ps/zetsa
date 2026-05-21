pub const list: []const Entry = @import("tables/mount_saddle");

pub fn getById(id: u32) ?Entry {
    for (list) |e| if (e.id == id) return e;
    return null;
}

pub const Entry = struct {
    id: u32,
    name: LangString,
    desc: LangString,
    special_desc: LangString,
    icon: []const u8,
    rarity: u32,
    default_saddle: []const u8,
    default_id: u32,
};

const LangString = tables.LangString;
const tables = @import("../tables.zig");
