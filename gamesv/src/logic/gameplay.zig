pub fn onFirstEntrance(player_store: *PlayerStore) void {
    for (tables.hero.list) |hero| if (hero.is_usable != 0) {
        player_store.hero.unlockById(hero.getId());
    };
}

const PlayerStore = logic.PlayerStore;

const tables = @import("../tables.zig");
const logic = @import("../logic.zig");
const std = @import("std");
