pub const data: []const HeroLevelData = @import("tables/hero_level");

pub fn getById(id: u32) ?HeroLevelData {
    for (data) |lv| if (lv.lv == id) return lv;
    return null;
}

pub const Level = enum(u8) {
    min = data[0].lv,
    max = data[data.len - 1].lv,
    _,

    pub fn toInt(level: Level) u8 {
        return @intFromEnum(level);
    }
};

pub const HeroLevelData = struct {
    lv: u8,
    exp: u32,
    condition: []const u32,
};
