world_maps: WorldMaps,

pub fn load(io: Io, gpa: Allocator) !Assets {
    const world_maps: WorldMaps = try .loadAll(io, gpa);
    errdefer world_maps.deinit();

    return .{ .world_maps = world_maps };
}

pub fn deinit(assets: *Assets) void {
    assets.world_maps.deinit();
}

pub const WorldMaps = struct {
    const Map = HashMap(u32, Entry);

    map: Map,
    arena: ArenaAllocator,

    const Loaded = struct {
        id: u32,
        entry: Entry,
    };

    pub fn loadAll(io: Io, gpa: Allocator) LoadOneError!WorldMaps {
        var arena_impl: ArenaAllocator = .init(gpa);
        errdefer arena_impl.deinit();
        const arena = arena_impl.allocator();

        var map: Map = .empty;
        try map.ensureTotalCapacity(arena, tables.world_city.list.len);

        const Result = union(enum) {
            one: LoadOneError!Loaded,
        };

        var select_buf: [tables.world_city.list.len]Result = undefined;
        var select: Io.Select(Result) = .init(io, &select_buf);
        defer select.cancelDiscard();

        for (tables.world_city.list) |item| select.async(
            .one,
            loadOne,
            .{ io, arena, item.id },
        );

        var outstanding = tables.world_city.list.len;

        while (outstanding != 0) : (outstanding -= 1) {
            const result = try select.await();
            const loaded = result.one catch |err| switch (err) {
                error.FileNotFound => continue,
                else => |e| return e,
            };

            map.putAssumeCapacity(loaded.id, loaded.entry);
        }

        return .{ .map = map, .arena = arena_impl };
    }

    pub fn deinit(wm: *WorldMaps) void {
        wm.arena.deinit();
    }

    fn loadOne(io: Io, arena: Allocator, id: u32) LoadOneError!Loaded {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "assets/maps/worldmap_{d}.bin", .{id}) catch unreachable;

        const content = Io.Dir.readFileAllocOptions(.cwd(), io, path, arena, .unlimited, .of(Entry.Point), null) catch |err| return switch (err) {
            error.Canceled, error.FileNotFound, error.OutOfMemory => |e| e,
            else => error.InputOutput,
        };

        const length = std.mem.readInt(u32, content[0..4], .little);
        const points = @as([*]Entry.Point, @ptrCast(content[4..].ptr))[0..length];

        var index: Entry.Index = .empty;
        try index.ensureTotalCapacity(arena, points.len);

        for (points) |*pt| index.putAssumeCapacity(pt.id, pt);

        return .{
            .id = id,
            .entry = .{ .bytes = content, .points = points, .index = index },
        };
    }

    pub const LoadOneError = error{
        InputOutput,
        FileNotFound,
    } || Io.Cancelable || Allocator.Error;

    pub const Entry = struct {
        const Raw = []align(@alignOf(Point)) const u8;

        pub const Index = HashMap(u32, *const Point);

        bytes: Raw,
        points: []const Point,
        index: Index,

        pub fn getPoint(entry: *const Entry, id: u32) ?Point.View {
            const point = entry.index.get(id) orelse return null;
            return .{ .bytes = entry.bytes, .config = point };
        }

        pub const Point = extern struct {
            pub const View = struct {
                bytes: Raw,
                config: *const Point,

                pub fn worldAreaIds(view: *const View) []const u32 {
                    const offset = view.config.world_area_ids_offset;
                    if (offset == std.math.maxInt(u32)) return &.{};

                    const ptr = @as([*]const u32, @ptrCast(@alignCast(view.bytes.ptr[offset..])));
                    return ptr[1..][0..ptr[0]];
                }
            };

            id: u32,
            city_id: u32,
            position: [3]f32,
            rotation: [3]f32,
            scale: f32,
            spawner_id: u32,
            expand_id: u32,
            ai_tree: u32,
            blueprint: u32,
            fsm: u32,
            status_reward_offset: u32,
            common_tag_offset: u32,
            all_block_show: u32,
            keep_on_complete: u32,
            filter_mark: u32,
            random_evt_id: u32,
            init_status: u32,
            initial_complete_state: u32,
            world_area_ids_offset: u32,
        };
    };
};

const Io = std.Io;
const Allocator = std.mem.Allocator;
const HashMap = std.AutoArrayHashMapUnmanaged;
const ArenaAllocator = std.heap.ArenaAllocator;

const tables = @import("tables.zig");
const std = @import("std");
const Assets = @This();
