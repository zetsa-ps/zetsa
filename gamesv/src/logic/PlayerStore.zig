id: ID,
basic_info: BasicInfo,
hero: Hero,
lineup: Lineup,
world_map: WorldMap,

pub const ID = enum(u32) {
    none = 0,
    _,

    pub fn toInt(id: ID) u32 {
        std.debug.assert(id != .none); // Always a programmer's error.
        return @intFromEnum(id);
    }
};

pub const init: PlayerStore = .{
    .id = .none,
    .basic_info = .init,
    .hero = .init,
    .lineup = .init,
    .world_map = .init,
};

pub fn deinit(data: *PlayerStore, gpa: Allocator) void {
    // This structure doesn't involve any heap allocations for now.
    _ = .{ data, gpa };
}

pub const WorldMap = @import("PlayerStore/WorldMap.zig");
pub const BasicInfo = @import("PlayerStore/BasicInfo.zig");
pub const Hero = @import("PlayerStore/Hero.zig");
pub const Lineup = @import("PlayerStore/Lineup.zig");

const Allocator = std.mem.Allocator;
const std = @import("std");
const PlayerStore = @This();
