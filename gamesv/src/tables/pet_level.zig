pub const list: []const Entry = @import("tables/pet_level");

pub fn getById(id: u32) ?Entry {
    for (list) |lv| if (lv.lv == id) return lv;
    return null;
}

pub const Level = enum(u8) {
    min = list[0].lv,
    max = list[list.len - 1].lv,
    _,
};

pub const Entry = struct {
    lv: u8,
    exp: u32,
    condition: []const u32,
};
