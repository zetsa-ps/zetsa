pub fn onFirstEntrance(player_store: *PlayerStore) void {
    for (tables.hero.list) |hero| if (hero.is_usable != 0) {
        player_store.hero.unlockById(hero.getId());
    };

    for (tables.soulessence.list) |soul_essence| {
        player_store.soul_essence.item_map.putAssumeCapacity(soul_essence.id, .init);
    }

    for (tables.pet.list, 0..) |pet, i| {
        if (tables.template_value.getById(pet.id) == null or pet.pet_stage == 0) continue;

        var pet_item: PlayerStore.Pet.Item = .init(pet.id);

        pet_item.box = .{
            .index = @enumFromInt(@as(std.meta.Tag(PlayerStore.Pet.Box.Index), @intCast((i / tables.game.pet_box_limit) + 1))),
            .slot = @enumFromInt(@as(std.meta.Tag(PlayerStore.Pet.Box.Slot), @intCast((i % tables.game.pet_box_limit) + 1))),
        };

        player_store.pet.item_map.putAssumeCapacity(@bitCast(@as(u64, @intCast(pet.id))), pet_item);
    }
}

const PlayerStore = logic.PlayerStore;

const logic = @import("../logic.zig");
const tables = @import("../tables.zig");

const std = @import("std");
