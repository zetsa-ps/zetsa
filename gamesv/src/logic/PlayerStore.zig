id: ID,
basic_info: BasicInfo,
hero: Hero,
lineup: Lineup,
pet: Pet,
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

pub const init: PlayerStore = .{
    .id = .none,
    .basic_info = .init,
    .hero = .init,
    .lineup = .init,
    .pet = .init,
    .soul_essence = .init,
    .world = .init,
};

pub fn deinit(data: *PlayerStore, gpa: Allocator) void {
    data.pet.deinit(gpa);
    data.soul_essence.deinit(gpa);
}

pub const BasicInfo = @import("PlayerStore/BasicInfo.zig");
pub const Hero = @import("PlayerStore/Hero.zig");
pub const Lineup = @import("PlayerStore/Lineup.zig");
pub const Pet = @import("PlayerStore/Pet.zig");
pub const SoulEssence = @import("PlayerStore/SoulEssence.zig");
pub const World = @import("PlayerStore/World.zig");

const Allocator = std.mem.Allocator;

const std = @import("std");

const PlayerStore = @This();
