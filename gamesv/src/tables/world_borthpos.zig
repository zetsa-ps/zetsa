pub const data: []const WorldBorthPos = @import("tables/world_borthpos");

pub fn getById(id: u32) ?WorldBorthPos {
    for (data) |h| if (h.id == id) return h;
    return null;
}

pub fn queryCityBirthPos(map_id: u32) ?WorldBorthPos {
    for (data) |world_borthpos| {
        if (world_borthpos.city_id == map_id and world_borthpos.main_point == 1) {
            return world_borthpos;
        }
    }

    return null;
}

pub const WorldBorthPos = struct {
    id: u32,
    name: LangString,
    city_id: u32,
    type: u32,
    main_point: u32,
    lock_point: u32,
    borth_point: [6]f32,
    aoi_center_pos: u32,
};

const LangString = @import("../tables.zig").LangString;
