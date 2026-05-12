id: ID,
basic_info: BasicInfo,
hero: Hero,
lineup: Lineup,
soul_essence: SoulEssence,
world: World,

pub const ID = enum(u32) {
    none = 0,
    _,

    pub fn toInt(id: ID) u32 {
        std.debug.assert(id != .none); // Always a programmer's error.
        return @intFromEnum(id);
    }
};

pub fn init(gpa: Allocator) !PlayerStore {
    return .{
        .id = .none,
        .basic_info = .init,
        .hero = .init,
        .lineup = .init,
        .soul_essence = try .init(gpa),
        .world = .init,
    };
}

pub fn deinit(data: *PlayerStore, gpa: Allocator) void {
    data.soul_essence.deinit(gpa);
}

pub const BasicInfo = @import("PlayerStore/BasicInfo.zig");
pub const Hero = @import("PlayerStore/Hero.zig");
pub const Lineup = @import("PlayerStore/Lineup.zig");
pub const SoulEssence = @import("PlayerStore/SoulEssence.zig");
pub const World = @import("PlayerStore/World.zig");

const Allocator = std.mem.Allocator;

const std = @import("std");

const PlayerStore = @This();
