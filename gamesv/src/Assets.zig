const log = std.log.scoped(.@"gamesv::Assets");

world_maps: WorldMaps,

pub fn init(gpa: Allocator) Assets {
    return .{ .world_maps = .init(gpa) };
}

pub fn deinit(assets: *Assets) void {
    assets.world_maps.deinit();
}

pub const WorldMaps = struct {
    loaded_maps: HashMap(u32, *const Entry),
    // Protects the `loaded_maps`.
    access_lock: Io.RwLock,
    // Makes sure that only one map is being loaded at a time,
    // so we won't load same map multiple times and leak memory.
    load_lock: Io.Mutex,
    arena: ArenaAllocator,

    const Loaded = struct {
        id: u32,
        entry: Entry,
    };

    pub fn init(gpa: Allocator) WorldMaps {
        return .{
            .loaded_maps = .empty,
            .access_lock = .init,
            .load_lock = .init,
            .arena = .init(gpa),
        };
    }

    // Not threadsafe.
    pub fn deinit(wm: *WorldMaps) void {
        wm.arena.deinit();
    }

    // Threadsafe.
    pub fn load(wm: *WorldMaps, io: Io, gpa: Allocator, id: u32) LoadOneError!*const Entry {
        var prev_count: usize = undefined;

        {
            try wm.access_lock.lockShared(io);
            defer wm.access_lock.unlockShared(io);

            if (wm.loaded_maps.get(id)) |ptr|
                return ptr;

            prev_count = wm.loaded_maps.entries.len;
        }

        try wm.load_lock.lock(io);
        defer wm.load_lock.unlock(io);

        if (prev_count != wm.loaded_maps.entries.len) {
            // Lookup again, maybe the map was just loaded.
            if (wm.loaded_maps.get(id)) |ptr|
                return ptr;
        }

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "assets/maps/worldmap_{d}.zon", .{id}) catch unreachable;

        var start_time: Io.Timestamp = if (is_debug) .now(io, .awake) else .zero;

        const content = Io.Dir.readFileAllocOptions(.cwd(), io, path, gpa, .unlimited, .of(u8), 0) catch |err| return switch (err) {
            error.Canceled, error.FileNotFound, error.OutOfMemory => |e| e,
            else => error.InputOutput,
        };

        defer gpa.free(content);

        const points = std.zon.parse.fromSliceAlloc([]const Entry.Point, wm.arena.allocator(), content, null, .{
            .ignore_unknown_fields = true,
            .free_on_error = false,
        }) catch return error.ParseFailed;

        var index: Entry.Index = .empty;
        try index.ensureTotalCapacity(wm.arena.allocator(), points.len);
        for (points) |*pt| index.putAssumeCapacity(pt.id, pt);

        const entry = try wm.arena.allocator().create(Entry);
        entry.* = .{ .points = points, .index = index };

        try wm.access_lock.lock(io);
        defer wm.access_lock.unlock(io);

        try wm.loaded_maps.put(wm.arena.allocator(), id, entry);

        if (is_debug)
            log.debug("loading map asset '{s}' took {f}", .{ path, start_time.untilNow(io, .awake) });

        return entry;
    }

    pub const LoadOneError = error{
        InputOutput,
        FileNotFound,
        ParseFailed,
    } || Io.Cancelable || Allocator.Error;

    pub const Entry = struct {
        pub const Index = HashMap(u32, *const Point);

        points: []const Point,
        index: Index,

        pub const Point = struct {
            id: u32,
            city_id: u32,
            spawner_id: u32,
            expand_id: u32,
            world_area_ids: []const u32,
        };
    };
};

const Io = std.Io;
const Allocator = std.mem.Allocator;
const HashMap = std.AutoArrayHashMapUnmanaged;
const ArenaAllocator = std.heap.ArenaAllocator;

const is_debug = @import("builtin").mode == .Debug;

const tables = @import("tables.zig");
const std = @import("std");
const Assets = @This();
