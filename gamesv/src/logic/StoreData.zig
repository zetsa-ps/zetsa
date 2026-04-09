player_id: PlayerID,
basic_info: BasicInfo,
hero_data: HeroData,
formation: FormationStore,
world_map: WorldMap,

pub const PlayerID = enum(u32) {
    none = 0,
    _,

    pub fn toInt(player_id: PlayerID) u32 {
        std.debug.assert(player_id != .none); // Always a programmer's error.
        return @intFromEnum(player_id);
    }
};

pub const init: StoreData = .{
    .player_id = .none,
    .basic_info = .init,
    .hero_data = .init,
    .formation = .init,
    .world_map = .init,
};

pub fn deinit(data: *StoreData, gpa: Allocator) void {
    // This structure doesn't involve any heap allocations for now.
    _ = .{ data, gpa };
}

pub const WorldMap = @import("StoreData/WorldMap.zig");
pub const BasicInfo = @import("StoreData/BasicInfo.zig");
pub const HeroData = @import("StoreData/HeroData.zig");
pub const FormationStore = @import("StoreData/FormationStore.zig");

const Allocator = std.mem.Allocator;
const std = @import("std");
const StoreData = @This();
