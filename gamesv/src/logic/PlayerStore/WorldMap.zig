map_id: u32,
position_x: i32,
position_y: i32,
position_z: i32,
angle: u32,
area_id: u32,

pub const init: WorldMap = .{
    .map_id = default_map_id,
    .position_x = logic.math.floatToInt(default_pos[0]),
    .position_y = logic.math.floatToInt(default_pos[1]),
    .position_z = logic.math.floatToInt(default_pos[2]),
    .angle = @intFromFloat(default_pos[4]),
    .area_id = default_area_id,
};

pub fn setPositionByBorthPoint(wm: *WorldMap, point_pos: [6]f32) void {
    wm.position_x = logic.math.floatToInt(point_pos[0]);
    wm.position_y = logic.math.floatToInt(point_pos[1]);
    wm.position_z = logic.math.floatToInt(point_pos[2]);
    wm.angle = @intFromFloat(point_pos[4]);
}

const default_area_id: u32 = 100004;
const default_map_id: u32 = 100;
const default_borth_pos_id: u32 = 10045;
const default_pos = tables.world_borthpos.getById(default_borth_pos_id).?.borth_point;

const logic = @import("../../logic.zig");
const tables = @import("../../tables.zig");

const WorldMap = @This();
