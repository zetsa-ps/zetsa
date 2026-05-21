pub fn petSetRoulettePos(txn: Transaction(.CSProtoPetSetRoulettePos)) !void {
    const log = std.log.scoped(.CSProtoPetSetRoulettePos);

    const player_store = txn.any.player_store;

    const roulette_index = std.enums.fromInt(
        PlayerStore.Pet.RouletteIndex,
        txn.request.pos orelse return txn.respondError(.ParamError),
    ) orelse return txn.respond(.{});

    const pet_id: PlayerStore.Pet.ID = @bitCast(txn.request.guid orelse return txn.respondError(.ParamError));
    const pet = player_store.pet.item_map.getPtr(pet_id) orelse return txn.respondError(.PetNotExist);

    if (player_store.pet.roulette_map.contains(roulette_index)) {
        return txn.respondError(.RoulettePosHadPet);
    }

    const pet_roulette_index = player_store.pet.getPetRouletteIndex(pet_id);

    if (pet_roulette_index) |slot| {
        // Just return, pet is already in the requested position
        if (slot == roulette_index) {
            return txn.respond(.{});
        }

        player_store.pet.roulette_map.remove(slot);
    }

    player_store.pet.roulette_map.put(roulette_index, pet_id);

    var updated_pets_buf: [1]pb.PetbaseInfo = undefined;
    var updated_pets: std.ArrayList(pb.PetbaseInfo) = .initBuffer(&updated_pets_buf);

    updated_pets.appendAssumeCapacity(
        try encoding.packPetInfo(
            txn.any.arena,
            pet_id,
            pet.*,
            player_store.pet.getPetRouletteIndex(pet_id),
        ),
    );

    try txn.any.send(.CSProtoPetInfoSync, pb.SCPetInfoSync{
        .pet_infos = .{
            .pets = updated_pets,
        },
    });

    try txn.respond(.{});

    store.player.savePetTable(txn.any.io, player_store) catch |err| {
        log.warn("failed to save pet table: {t}", .{err});
    };

    store.player.savePetRouletteTable(txn.any.io, player_store) catch |err| {
        log.warn("failed to save pet roulette table: {t}", .{err});
    };
}

pub fn petRemoveRoulettePos(txn: Transaction(.CSProtoPetRemoveRoulettePos)) !void {
    const log = std.log.scoped(.CSProtoPetRemoveRoulettePos);

    const roulette_index = std.enums.fromInt(
        PlayerStore.Pet.RouletteIndex,
        txn.request.u32 orelse return txn.respondError(.ParamError),
    ) orelse return txn.respond(.{});

    const player_store = txn.any.player_store;

    const pet_id = player_store.pet.roulette_map.fetchRemove(roulette_index) orelse return txn.respond(.{});
    const pet = player_store.pet.item_map.getPtr(pet_id).?;
    const pet_roulette_index = player_store.pet.getPetRouletteIndex(pet_id);

    var updated_pets_buf: [1]pb.PetbaseInfo = undefined;
    var updated_pets: std.ArrayList(pb.PetbaseInfo) = .initBuffer(&updated_pets_buf);

    updated_pets.appendAssumeCapacity(
        try encoding.packPetInfo(
            txn.any.arena,
            pet_id,
            pet.*,
            pet_roulette_index,
        ),
    );

    try txn.respond(.{});

    try txn.any.send(.CSProtoPetInfoSync, pb.SCPetInfoSync{
        .pet_infos = .{
            .pets = updated_pets,
        },
    });

    store.player.savePetTable(txn.any.io, player_store) catch |err| {
        log.warn("failed to save pet table: {t}", .{err});
    };

    store.player.savePetRouletteTable(txn.any.io, player_store) catch |err| {
        log.warn("failed to save pet roulette table: {t}", .{err});
    };
}

pub fn wearPet(txn: Transaction(.CSProtoWearPet)) !void {
    const log = std.log.scoped(.CSProtoWearPet);
    log.debug("hero: {?}, pet: {?}", .{
        txn.request.hero_guid,
        txn.request.pet_guid,
    });

    const hero_guid = txn.request.hero_guid orelse return txn.respondError(.ParamError);
    const pet_guid = txn.request.pet_guid orelse 0;

    const player_store = txn.any.player_store;

    const hero = player_store.hero.item_map.getPtr(
        std.enums.fromInt(PlayerStore.Hero.ID, logic.Uuid.fromInt(hero_guid).config_id) orelse
            return txn.respondError(.HeroNotExist),
    ) orelse
        return txn.respondError(.HeroNotExist);

    var heroes_buf: [2]pb.HeroItemInfo = undefined;
    var heroes: std.ArrayList(pb.HeroItemInfo) = .initBuffer(&heroes_buf);

    var pets_buf: [2]pb.PetbaseInfo = undefined;
    var pets: std.ArrayList(pb.PetbaseInfo) = .initBuffer(&pets_buf);

    const old_pet_id = hero.pet_id;

    // Unequip current pet
    if (pet_guid == 0) {
        if (old_pet_id == 0) return txn.respond(.{});

        if (player_store.pet.item_map.getPtr(@bitCast(old_pet_id))) |old_pet| {
            old_pet.hero_ref = .none;

            pets.appendAssumeCapacity(
                try encoding.packPetInfo(
                    txn.any.arena,
                    @bitCast(old_pet_id),
                    old_pet.*,
                    player_store.pet.getPetRouletteIndex(@bitCast(old_pet_id)),
                ),
            );
        }

        hero.pet_id = 0;

        heroes.appendAssumeCapacity(.{
            .guid = hero_guid,
            .pet_id = 0,
        });
    } else {
        const new_pet = player_store.pet.item_map.getPtr(@bitCast(pet_guid)) orelse
            return txn.respond(.{});

        const old_pet_hero_ref = new_pet.hero_ref;

        // Already equipped
        if (old_pet_id == pet_guid and @intFromEnum(old_pet_hero_ref) == hero_guid) {
            return txn.respondError(.PetInHero);
        }

        // Remove old pet from this hero
        if (old_pet_id != 0 and old_pet_id != pet_guid) {
            if (player_store.pet.item_map.getPtr(@bitCast(old_pet_id))) |old_pet| {
                old_pet.hero_ref = .none;

                pets.appendAssumeCapacity(
                    try encoding.packPetInfo(
                        txn.any.arena,
                        @bitCast(old_pet_id),
                        old_pet.*,
                        player_store.pet.getPetRouletteIndex(@bitCast(old_pet_id)),
                    ),
                );
            }
        }

        // Remove this pet from previous hero
        if (old_pet_hero_ref.toUuid()) |hero_uuid| {
            if (hero_uuid.toInt() != hero_guid) {
                const old_hero_id: PlayerStore.Hero.ID =
                    @enumFromInt(hero_uuid.config_id);

                if (player_store.hero.item_map.getPtr(old_hero_id)) |old_hero| {
                    old_hero.pet_id = 0;

                    heroes.appendAssumeCapacity(.{
                        .guid = @intFromEnum(old_pet_hero_ref),
                        .pet_id = 0,
                    });
                }
            }
        }

        // Equip new pet
        new_pet.hero_ref = @enumFromInt(hero_guid);
        hero.pet_id = pet_guid;

        heroes.appendAssumeCapacity(.{
            .guid = hero_guid,
            .pet_id = pet_guid,
        });

        pets.appendAssumeCapacity(
            try encoding.packPetInfo(
                txn.any.arena,
                @bitCast(pet_guid),
                new_pet.*,
                player_store.pet.getPetRouletteIndex(@bitCast(pet_guid)),
            ),
        );
    }

    try txn.respond(.{});

    try txn.any.send(.CSProtoSyncPlayerData, pb.PlayerData{
        .heros_info = .{ .heros = heroes },
    });

    try txn.any.send(.CSProtoPetInfoSync, pb.SCPetInfoSync{
        .pet_infos = .{
            .pets = pets,
        },
    });

    store.player.saveHeroTable(txn.any.io, player_store) catch |err| {
        log.warn("failed to save hero table: {t}", .{err});
    };

    store.player.savePetTable(txn.any.io, player_store) catch |err| {
        log.warn("failed to save pet table: {t}", .{err});
    };
}

pub fn petStationInHomeHub(txn: Transaction(.CSProtoPetStationInHomeHub)) !void {
    try txn.respond(.{});
}

const PlayerStore = logic.PlayerStore;

const AnyTransaction = messaging.AnyTransaction;
const Transaction = messaging.Transaction;

const pb = proto.pb;

const messaging = @import("../messaging.zig");
const encoding = @import("../encoding.zig");
const Assets = @import("../Assets.zig");
const tables = @import("../tables.zig");
const logic = @import("../logic.zig");
const store = @import("../store.zig");

const proto = @import("proto");

const std = @import("std");
