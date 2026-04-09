pub const SaveStoreDataError = store.SaveAttrsetError;

// Saves all of the `StoreData` modules.
pub fn saveStoreData(io: Io, data: *const StoreData) SaveStoreDataError!void {
    const id = data.player_id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const basic_info_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/basicinfo", .{id}) catch unreachable;
    try store.saveAttrset(StoreData.BasicInfo, io, basic_info_path, &data.basic_info);

    try saveWorldMapAttributes(io, data);

    const hero_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/herotab", .{id}) catch unreachable;
    try store.saveEnumMap(
        StoreData.HeroData.ItemMap.Key,
        StoreData.HeroData.ItemMap.Value,
        io,
        hero_tab_path,
        &data.hero_data.item_map,
    );

    const battle_hero_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/battleherotab", .{id}) catch unreachable;
    try store.saveEnumMap(
        StoreData.HeroData.BattleMap.Key,
        StoreData.HeroData.BattleMap.Value,
        io,
        battle_hero_tab_path,
        &data.hero_data.battle_map,
    );

    try saveFormationTable(io, data);
}

pub fn saveWorldMapAttributes(io: Io, data: *const StoreData) SaveStoreDataError!void {
    const id = data.player_id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const world_map_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldmapattrs", .{id}) catch unreachable;
    try store.saveAttrset(StoreData.WorldMap, io, world_map_path, &data.world_map);
}

pub fn saveFormationTable(io: Io, data: *const StoreData) SaveStoreDataError!void {
    const id = data.player_id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const formation_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/formationtab", .{id}) catch unreachable;
    try store.saveEnumMap(
        StoreData.FormationStore.Group.Type,
        StoreData.FormationStore.Group,
        io,
        formation_tab_path,
        &data.formation.group_map,
    );
}

pub const LoadStoreDataError = store.LoadAttrsetError;

// Loads all of the `StoreData` modules.
// `out.player_id` must be valid.
pub fn loadStoreData(io: Io, out: *StoreData) LoadStoreDataError!void {
    const id = out.player_id.toInt();
    var path_buf: [max_path_bytes]u8 = undefined;

    const basic_info_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/basicinfo", .{id}) catch unreachable;
    try store.loadAttrset(StoreData.BasicInfo, io, basic_info_path, &out.basic_info);

    const world_map_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/worldmapattrs", .{id}) catch unreachable;
    try store.loadAttrset(StoreData.WorldMap, io, world_map_path, &out.world_map);

    const hero_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/herotab", .{id}) catch unreachable;
    try store.loadEnumMap(
        StoreData.HeroData.ItemMap.Key,
        StoreData.HeroData.ItemMap.Value,
        io,
        hero_tab_path,
        &out.hero_data.item_map,
    );

    const battle_hero_tab = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/battleherotab", .{id}) catch unreachable;
    try store.loadEnumMap(
        StoreData.HeroData.BattleMap.Key,
        StoreData.HeroData.BattleMap.Value,
        io,
        battle_hero_tab,
        &out.hero_data.battle_map,
    );

    const formation_tab_path = std.fmt.bufPrint(&path_buf, "store/player/by-id/{d}/formationtab", .{id}) catch unreachable;
    try store.loadEnumMap(
        StoreData.FormationStore.Group.Type,
        StoreData.FormationStore.Group,
        io,
        formation_tab_path,
        &out.formation.group_map,
    );
}

const StoreData = logic.StoreData;
const max_path_bytes = std.fs.max_path_bytes;

const Io = std.Io;

const logic = @import("../logic.zig");
const store = @import("../store.zig");
const std = @import("std");
