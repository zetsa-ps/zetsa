pub const Maps = std.EnumMap(Map.Kind, Map);

maps: Maps,
attrs: Attrs,

pub const init: World = .{
    .maps = .init(.{ .exploration = .{
        .id = default_map_id,
        .position_x = logic.math.floatToInt(default_pos[0]),
        .position_y = logic.math.floatToInt(default_pos[1]),
        .position_z = logic.math.floatToInt(default_pos[2]),
        .angle = @intFromFloat(default_pos[4]),
        .area_id = default_area_id,
    } }),
    .attrs = .{ .active_kind = .exploration },
};

pub const Map = struct {
    id: u32,
    position_x: i32,
    position_y: i32,
    position_z: i32,
    angle: u32,
    area_id: u32,

    pub const Kind = enum {
        exploration,
        home,

        pub fn byMapId(map_id: u32) Kind {
            return switch (map_id) {
                tables.game.home_id => .home,
                else => .exploration,
            };
        }
    };

    pub fn initByBorthPos(world_borthpos: *const tables.world_borthpos.Entry) Map {
        const point = &world_borthpos.borth_point;

        return .{
            .id = world_borthpos.city_id,
            .position_x = logic.math.floatToInt(point[0]),
            .position_y = logic.math.floatToInt(point[1]),
            .position_z = logic.math.floatToInt(point[2]),
            .angle = @intFromFloat(point[4]),
            .area_id = tables.world_area.calculateBelongArea(
                world_borthpos.city_id,
                point[0..3].*,
                false,
            ),
        };
    }

    pub fn setPositionByBorthPoint(map: *Map, point_pos: [6]f32) void {
        map.position_x = logic.math.floatToInt(point_pos[0]);
        map.position_y = logic.math.floatToInt(point_pos[1]);
        map.position_z = logic.math.floatToInt(point_pos[2]);
        map.angle = @intFromFloat(point_pos[4]);
    }
};

pub const Attrs = struct {
    active_kind: Map.Kind,
};

const default_area_id: u32 = 100004;
const default_map_id: u32 = 100;
const default_borth_pos_id: u32 = 10045;
const default_pos = tables.world_borthpos.getById(default_borth_pos_id).?.borth_point;

const logic = @import("../../logic.zig");
const tables = @import("../../tables.zig");

const std = @import("std");
const World = @This();
