pub const data: []const PlayerLevelData = @import("tables/player_level");

pub fn getById(id: u32) ?PlayerLevelData {
    for (data) |lv| if (lv.id == id) return lv;
    return null;
}

pub const Level = enum(u8) {
    min = data[0].id,
    max = data[data.len - 1].id,
    _,

    pub fn toInt(level: Level) u8 {
        return @intFromEnum(level);
    }
};

pub const PlayerLevelData = struct {
    id: u8,
    exp: u32,
    stamina: u32,
    reward: []const []const u32,
};
