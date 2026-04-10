pub const list: []const Entry = @import("tables/player_level");

pub fn getById(id: u32) ?Entry {
    for (list) |lv| if (lv.id == id) return lv;
    return null;
}

pub const Level = enum(u8) {
    min = list[0].id,
    max = list[list.len - 1].id,
    _,

    pub fn toInt(level: Level) u8 {
        return @intFromEnum(level);
    }
};

pub const Entry = struct {
    id: u8,
    exp: u32,
    stamina: u32,
    reward: []const []const u32,
};
