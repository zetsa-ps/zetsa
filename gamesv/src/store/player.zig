pub const SavePlayerStoreError = store.SaveAttrsetError;

// Saves all of the `PlayerStore` modules.
pub fn saveAll(io: Io, player_store: *const PlayerStore) SavePlayerStoreError!void {
    const id = player_store.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const basic_info_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/basicinfo", .{id}) catch unreachable;
    try store.saveAttrset(PlayerStore.BasicInfo, io, basic_info_path, &player_store.basic_info);

    try saveWorldMapTable(io, player_store);
    try saveWorldAttributes(io, player_store);

    const hero_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/herotab", .{id}) catch unreachable;
    try store.saveEnumMap(
        PlayerStore.Hero.ItemMap.Key,
        PlayerStore.Hero.ItemMap.Value,
        io,
        hero_tab_path,
        &player_store.hero.item_map,
    );

    try saveFormationTable(io, player_store);
}

pub fn saveWorldMapTable(io: Io, player_store: *const PlayerStore) SavePlayerStoreError!void {
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

pub fn saveWorldAttributes(io: Io, player_store: *const PlayerStore) SavePlayerStoreError!void {
    const id = player_store.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldattrs", .{id}) catch unreachable;
    try store.saveAttrset(PlayerStore.World.Attrs, io, path, &player_store.world.attrs);
}

pub fn saveFormationTable(io: Io, player_store: *const PlayerStore) SavePlayerStoreError!void {
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

pub const LoadPlayerStoreError = store.LoadAttrsetError;

// Loads all of the `PlayerStore` modules.
// `out.player_id` must be valid.
pub fn loadAll(io: Io, out: *PlayerStore) LoadPlayerStoreError!void {
    const id = out.id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const basic_info_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/basicinfo", .{id}) catch unreachable;
    try store.loadAttrset(PlayerStore.BasicInfo, io, basic_info_path, &out.basic_info);

    const world_attrs_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldattrs", .{id}) catch unreachable;
    try store.loadAttrset(PlayerStore.World.Attrs, io, world_attrs_path, &out.world.attrs);

    const world_map_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldmaptab", .{id}) catch unreachable;
    try store.loadEnumMap(
        PlayerStore.World.Maps.Key,
        PlayerStore.World.Maps.Value,
        io,
        world_map_tab_path,
        &out.world.maps,
    );

    const hero_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/herotab", .{id}) catch unreachable;
    try store.loadEnumMap(
        PlayerStore.Hero.ItemMap.Key,
        PlayerStore.Hero.ItemMap.Value,
        io,
        hero_tab_path,
        &out.hero.item_map,
    );

    const lineup_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/lineuptab", .{id}) catch unreachable;
    try store.loadEnumMap(
        PlayerStore.Lineup.Group.Type,
        PlayerStore.Lineup.Group,
        io,
        lineup_tab_path,
        &out.lineup.group_map,
    );
}

const PlayerStore = logic.PlayerStore;
const max_path_bytes = std.fs.max_path_bytes;

const Io = std.Io;

const logic = @import("../logic.zig");
const store = @import("../store.zig");
const std = @import("std");
