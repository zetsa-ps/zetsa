pub const list: []const Entry = @import("tables/world_difficulty_obj_level");

pub fn get(group: u32, difficult_lv: u32, mapid: u32) ?Entry {
    for (list) |h| if (h.groupid == group and h.difficult_lv == difficult_lv and h.mapid == mapid)
        return h;

    return null;
}

pub const Entry = struct {
    id: u32,
    groupid: u32,
    difficult_lv: u32,
    monster_level: u32,
    mapid: u32,
};
