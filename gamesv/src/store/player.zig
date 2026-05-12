pub const SaveError = Io.Cancelable || store.SaveAttrsetError;

// Saves all of the `PlayerStore` modules.
pub fn saveAll(io: Io, player_store: *const PlayerStore) SaveError!void {
    const saveFns = .{
        saveBasicInfo,
        saveHeroTable,
        saveWorldMapTable,
        saveWorldAttributes,
        saveFormationTable,
        saveSoulEssenceTable,
    };

    const Result = union(enum) {
        save: SaveError!void,
    };

    var buffer: [saveFns.len]Result = undefined;
    var select: Io.Select(Result) = .init(io, &buffer);

    defer select.cancelDiscard();
    var outstanding = saveFns.len;

    inline for (saveFns) |saveFn|
        select.async(.save, saveFn, .{ io, player_store });

    while (outstanding != 0) : (outstanding -= 1) {
        switch (try select.await()) {
            .save => |result| try result,
        }
    }
}

pub fn saveBasicInfo(io: Io, player_store: *const PlayerStore) SaveError!void {
    try io.checkCancel();

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const id = player_store.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/basicinfo", .{id}) catch unreachable;
    try store.saveAttrset(PlayerStore.BasicInfo, io, path, &player_store.basic_info);
}

pub fn saveHeroTable(io: Io, player_store: *const PlayerStore) SaveError!void {
    try io.checkCancel();

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const id = player_store.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/herotab", .{id}) catch unreachable;
    try store.saveEnumMap(
        PlayerStore.Hero.ItemMap.Key,
        PlayerStore.Hero.ItemMap.Value,
        io,
        path,
        &player_store.hero.item_map,
    );
}

pub fn saveWorldMapTable(io: Io, player_store: *const PlayerStore) SaveError!void {
    try io.checkCancel();

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const id = player_store.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldmaptab", .{id}) catch unreachable;
    try store.saveEnumMap(
        PlayerStore.World.Maps.Key,
        PlayerStore.World.Maps.Value,
        io,
        path,
        &player_store.world.maps,
    );
}

pub fn saveWorldAttributes(io: Io, player_store: *const PlayerStore) SaveError!void {
    try io.checkCancel();

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const id = player_store.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldattrs", .{id}) catch unreachable;
    try store.saveAttrset(PlayerStore.World.Attrs, io, path, &player_store.world.attrs);
}

pub fn saveFormationTable(io: Io, player_store: *const PlayerStore) SaveError!void {
    try io.checkCancel();

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const id = player_store.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const lineup_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/lineuptab", .{id}) catch unreachable;
    try store.saveEnumMap(
        PlayerStore.Lineup.Group.Type,
        PlayerStore.Lineup.Group,
        io,
        lineup_tab_path,
        &player_store.lineup.group_map,
    );
}

pub fn saveSoulEssenceTable(io: Io, player_store: *const PlayerStore) SaveError!void {
    try io.checkCancel();

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const id = player_store.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/soulessencetab", .{id}) catch unreachable;
    try store.saveAutoArrayHashMap(
        u32,
        PlayerStore.SoulEssence.Item,
        io,
        path,
        &player_store.soul_essence.item_map,
    );
}

pub const LoadError = store.LoadAttrsetError;

// Loads all of the `PlayerStore` modules.
// `out.player_id` must be valid.
pub fn loadAll(io: Io, out: *PlayerStore) LoadError!void {
    const loadFns = .{
        loadBasicInfo,
        loadHeroTable,
        loadLineupTable,
        loadWorldAttributes,
        loadWorldMapTable,
        loadSoulEssenceTable,
    };

    const Result = union(enum) {
        load: LoadError!void,
    };

    var buffer: [loadFns.len]Result = undefined;
    var select: Io.Select(Result) = .init(io, &buffer);

    defer select.cancelDiscard();
    var outstanding = loadFns.len;

    inline for (loadFns) |loadFn|
        select.async(.load, loadFn, .{ io, out });

    while (outstanding != 0) : (outstanding -= 1) {
        switch (try select.await()) {
            .load => |result| try result,
        }
    }
}

fn loadBasicInfo(io: Io, out: *PlayerStore) LoadError!void {
    const id = out.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/basicinfo", .{id}) catch unreachable;
    try store.loadAttrset(PlayerStore.BasicInfo, io, path, &out.basic_info);
}

fn loadHeroTable(io: Io, out: *PlayerStore) LoadError!void {
    const id = out.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/herotab", .{id}) catch unreachable;

    try store.loadEnumMap(
        PlayerStore.Hero.ItemMap.Key,
        PlayerStore.Hero.ItemMap.Value,
        io,
        path,
        &out.hero.item_map,
    );
}

fn loadLineupTable(io: Io, out: *PlayerStore) LoadError!void {
    const id = out.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/lineuptab", .{id}) catch unreachable;

    try store.loadEnumMap(
        PlayerStore.Lineup.Group.Type,
        PlayerStore.Lineup.Group,
        io,
        path,
        &out.lineup.group_map,
    );
}

fn loadWorldAttributes(io: Io, out: *PlayerStore) LoadError!void {
    const id = out.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldattrs", .{id}) catch unreachable;
    try store.loadAttrset(PlayerStore.World.Attrs, io, path, &out.world.attrs);
}

fn loadWorldMapTable(io: Io, out: *PlayerStore) LoadError!void {
    const id = out.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldmaptab", .{id}) catch unreachable;
    try store.loadEnumMap(
        PlayerStore.World.Maps.Key,
        PlayerStore.World.Maps.Value,
        io,
        path,
        &out.world.maps,
    );
}

fn loadSoulEssenceTable(io: Io, out: *PlayerStore) LoadError!void {
    const id = out.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/soulessencetab", .{id}) catch unreachable;

    try store.loadAutoArrayHashMap(
        u32,
        PlayerStore.SoulEssence.Item,
        io,
        path,
        &out.soul_essence.item_map,
    );
}

const PlayerStore = logic.PlayerStore;
const max_path_bytes = Io.Dir.max_path_bytes;

const Io = std.Io;

const logic = @import("../logic.zig");
const store = @import("../store.zig");
const std = @import("std");
