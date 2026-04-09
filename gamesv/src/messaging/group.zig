pub fn changeHeroGroupIndex(txn: Transaction(.CSProtoChangeHeroGroupIndex)) !void {
    const log = std.log.scoped(.CSProtoChangeHeroGroupIndex);

    const store_data = txn.any.store_data;

    if (txn.request.type != 1) {
        log.warn("group type {?d} is not implemented yet.", .{txn.request.type});
        return;
    }

    const client_group = txn.request.group orelse {
        log.warn("received null group from client", .{});
        return;
    };

    if (client_group.heros.items.len > FormationStore.Formation.HeroPos.count) {
        log.warn(
            "hero count exceeded ({d}/{d})",
            .{ client_group.heros.items.len, FormationStore.Formation.HeroPos.count },
        );
        return;
    }

    const formation_id = client_group.id orelse {
        log.warn("received null group.id from client", .{});
        return;
    };

    if (formation_id > FormationStore.Formation.count or formation_id == 0) {
        log.warn("illegal group.id: {d}", .{formation_id});
        return;
    }

    var new_heros: FormationStore.Formation.Heros = @splat(.empty);

    for (client_group.heros.items, 0..) |hero_pos, i| {
        if (hero_pos.hero_id) |raw_uuid| {
            const uuid: logic.Uuid = @bitCast(raw_uuid);
            const hero_id = std.enums.fromInt(tables.hero.Id, uuid.config_id) orelse {
                log.warn("illegal hero_id: {d}", .{uuid.config_id});
                return;
            };

            if (!store_data.hero_data.item_map.contains(hero_id)) {
                log.warn("hero '{t}' is not unlocked", .{hero_id});
                return;
            }

            new_heros[i] = .fromHeroId(hero_id);
        }
    }

    const formation_group = store_data.formation.group_map.getPtr(.world).?;
    formation_group.formation_heros[formation_id - 1] = new_heros;

    {
        const old_cancel_protection = txn.any.io.swapCancelProtection(.blocked);
        defer _ = txn.any.io.swapCancelProtection(old_cancel_protection);

        store.player.saveFormationTable(txn.any.io, store_data) catch |err| {
            log.warn("failed to save formation table: {t}", .{err});
            return;
        };
    }

    var group_mgrs: std.ArrayList(pb.GroupManager) = .empty;
    var group_mgrs_buf: [FormationStore.GroupMap.len]pb.GroupManager = undefined;
    var groups_buf: [group_mgrs_buf.len * FormationStore.Formation.count]pb.Group = undefined;
    var group_heros_buf: [FormationStore.Formation.HeroPos.count * groups_buf.len]pb.GroupHeroPos = undefined;

    encoding.packGroupManagers(
        store_data,
        &group_mgrs,
        &group_mgrs_buf,
        &groups_buf,
        &group_heros_buf,
    );

    try txn.any.send(.CSProtoSyncPlayerData, .{ .group_mgrs = group_mgrs });
    try txn.respond(.{});
}

pub fn switchWorldGroupControl(txn: Transaction(.CSProtoSwitchWorldGroupControl)) !void {
    const log = std.log.scoped(.CSProtoSwitchWorldGroupControl);

    if (txn.request.type != 1) {
        log.warn("group type {?d} is not implemented yet.", .{txn.request.type});
        return;
    }

    const raw_uuid = txn.request.control orelse {
        log.warn("received null control UUID", .{});
        return;
    };

    const uuid: logic.Uuid = @bitCast(raw_uuid);

    const formation_store = &txn.any.store_data.formation;
    const world_group = formation_store.group_map.getPtr(.world).?;
    const formation_index = world_group.cur_formation;

    for (world_group.formation_heros[formation_index]) |hero_pos| {
        if (hero_pos != .empty and @intFromEnum(hero_pos) == uuid.config_id) {
            break;
        }
    } else {
        log.warn("hero with config_id {d} is not in formation", .{uuid.config_id});
        return;
    }

    world_group.formation_controls[formation_index] = @enumFromInt(uuid.config_id);

    {
        const old_cancel_protection = txn.any.io.swapCancelProtection(.blocked);
        defer _ = txn.any.io.swapCancelProtection(old_cancel_protection);

        store.player.saveFormationTable(txn.any.io, txn.any.store_data) catch |err| {
            log.warn("failed to save formation table: {t}", .{err});
            return;
        };
    }

    try txn.respond(.{});
}

const FormationStore = StoreData.FormationStore;

const StoreData = logic.StoreData;
const Transaction = messaging.Transaction;

const store = @import("../store.zig");
const logic = @import("../logic.zig");
const tables = @import("../tables.zig");
const encoding = @import("../encoding.zig");
const messaging = @import("../messaging.zig");

const pb = @import("proto").pb;
const std = @import("std");
