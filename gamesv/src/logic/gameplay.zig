pub fn onFirstEntrance(store_data: *StoreData) void {
    for (tables.hero.data) |hero| if (hero.is_usable != 0) {
        store_data.hero_data.unlockById(hero.getId());
    };
}

const StoreData = logic.StoreData;

const tables = @import("../tables.zig");
const logic = @import("../logic.zig");
const std = @import("std");
