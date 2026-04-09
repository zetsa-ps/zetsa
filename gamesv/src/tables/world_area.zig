pub const data: []const WorldArea = @import("tables/world_area");

pub fn getById(id: u32) ?WorldArea {
    for (data) |a| if (a.id == id) return a;
    return null;
}

pub fn getSceneMainArea(scene_id: u32) ?WorldArea {
    for (data) |a| if (a.scene_id == scene_id and a.main_area == 1) return a;
    return null;
}

pub fn AABBArea(td: *const WorldArea) f32 {
    return calculateAABBArea(td.vertices);
}

fn calculateAABBArea(area_vertices: []const [3]f32) f32 {
    if (area_vertices.len <= 2) return 0.0;

    var min_x = area_vertices[0][0];
    var max_x = area_vertices[0][0];
    var min_z = area_vertices[0][2];
    var max_z = area_vertices[0][2];

    for (area_vertices[1..]) |v| {
        if (v[0] < min_x) min_x = v[0];
        if (v[0] > max_x) max_x = v[0];
        if (v[2] < min_z) min_z = v[2];
        if (v[2] > max_z) max_z = v[2];
    }

    return (max_x - min_x) * (max_z - min_z);
}

pub fn isInArea(td: *const WorldArea, pos: [3]f32, need_height_check: bool) bool {
    if (need_height_check) {
        const height: f32 = @floatFromInt(td.height);
        if (pos[1] < td.area_pos[1] or pos[1] > td.area_pos[1] + if (height > 0.0) height else 50.0) return false;
    }

    const verts = td.vertices;
    if (verts.len < 3) return false;

    var inside = false;
    var j: usize = verts.len - 1;

    for (verts, 0..) |v, i| {
        const xi = td.area_pos[0] + v[0];
        const zi = td.area_pos[2] + v[2];
        const xj = td.area_pos[0] + verts[j][0];
        const zj = td.area_pos[2] + verts[j][2];

        const crosses =
            ((zi > pos[2]) != (zj > pos[2])) and
            (pos[0] < (xj - xi) * (pos[2] - zi) / ((zj - zi) + 0.000001) + xi);

        if (crosses) inside = !inside;
        j = i;
    }

    return inside;
}

pub fn calculateBelongArea(
    scene_id: u32,
    position: [3]f32,
    need_height_check: bool,
) u32 {
    var best_area: ?WorldArea = null;
    var best_score: f32 = @import("std").math.floatMax(f32);

    for (data) |area| {
        if (area.scene_id != scene_id) continue;
        if (!isInArea(&area, position, need_height_check)) continue;

        const score = AABBArea(&area);
        if (best_area == null or score < best_score) {
            best_area = area;
            best_score = score;
        }
    }

    return if (best_area) |area| area.id else 0;
}

pub const WorldArea = struct {
    id: u32,
    name: LangString,
    scene_id: u32,
    teleportation: []const u32,
    type: u32,
    area_pos: [3]f32,
    enter_focus_point: []const f32,
    enter_scale: f32,
    area_map: []const u8,
    map_size: []const u32,
    map_offset: []const f32,
    map_rotation: f32,
    scene_size: []const u32,
    vertices: []const [3]f32,
    height: u32,
    cell_info: []const u32,
    area_level_collect_id: u32,
    north_angle: u32,
    mini_map_resolution: []const u32,
    map_mask_icon: []const u8,
    mini_map_init_scale: f32,
    main_area: u32,
};

const LangString = @import("../tables.zig").LangString;
