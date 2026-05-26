pub fn enterGame(txn: Transaction(.CSProtoEnterGame)) !void {
    const log = std.log.scoped(.CSProtoEnterGame);
    const raw_open_id = txn.request.open_id orelse {
        const msg = "received null open_id";

        log.warn("{s}", .{msg});

        return try kickPlayer(txn.any, msg);
    };

    log.debug("open_id: '{s}'", .{raw_open_id});

    const open_id = store.Account.OpenID.init(raw_open_id) catch |err| switch (err) {
        error.TooLongString => return try kickPlayer(txn.any, "received open_id is too long"),
    };

    if (store.Account.fetch(txn.any.io, &open_id)) |account| {
        txn.any.player_store.id = @enumFromInt(account.player_id);
        store.player.loadAll(
            txn.any.gpa,
            txn.any.io,
            txn.any.player_store,
        ) catch |err| {
            const log_msg = try std.fmt.allocPrint(
                txn.any.arena,
                "failed to load store of player with id {d}: {t}",
                .{ account.player_id, err },
            );
            const kick_msg = if (err == error.Outdated)
                "<size=32><b>Error:</b> <color=#c63e39>Outdated store</color></size>\n\n\n" ++
                    "<size=20>Delete <size=16>(or move)</size> the <b><color=#3266b4>store</color></b> folder in the server directory and try to log in again.\n" ++
                    "You can also delete only the current user store folder.</size>"
            else
                log_msg;

            log.warn("{s}", .{log_msg});

            return try kickPlayer(txn.any, kick_msg);
        };
    } else |err| switch (err) {
        error.Canceled => |e| return e,
        error.InvalidOpenID, error.InputOutput => return try kickPlayer(txn.any, "invalid open_id"),
        error.Corrupted => {
            const msg = try std.fmt.allocPrint(
                txn.any.arena,
                "account with open_id '{s}' is corrupted",
                .{raw_open_id},
            );

            log.warn("{s}", .{msg});

            return try kickPlayer(txn.any, msg);
        },
        error.NotFound => {
            const account = store.Account.create(txn.any.io, &open_id) catch |create_err| switch (create_err) {
                error.InvalidOpenID, error.InputOutput => return try kickPlayer(txn.any, "invalid open_id"),
            };

            txn.any.player_store.id = @enumFromInt(account.player_id);

            try logic.gameplay.onFirstEntrance(
                txn.any.player_store,
                txn.any.gpa,
            );

            {
                const old_cancel_protection = txn.any.io.swapCancelProtection(.blocked);
                defer _ = txn.any.io.swapCancelProtection(old_cancel_protection);

                store.player.saveAll(txn.any.io, txn.any.player_store) catch |save_err| {
                    const msg = try std.fmt.allocPrint(
                        txn.any.arena,
                        "failed to save player store upon first entrance: {t}",
                        .{save_err},
                    );

                    log.warn("{s}", .{msg});

                    return try kickPlayer(txn.any, msg);
                };
            }
        },
    }

    const player_store = txn.any.player_store;
    const player_id = player_store.id.toInt();
    const basic_info = &player_store.basic_info;

    var heros_buffer: [tables.hero.list.len]pb.HeroItemInfo = undefined;
    var battle_heros_buffer: [tables.hero.list.len]pb.GroupHero = undefined;

    var player_data: pb.PlayerData = .{
        .basic_info = .{
            .id = player_id,
            .zone_id = 1,
            .name = basic_info.name.view(),
            .sex = basic_info.sex.toPlayerSexType(),
            .lv = basic_info.level.toInt(),
            .sign = basic_info.sign.view(),
            .gold = basic_info.gold.toInt(),
            .diamond = basic_info.diamond.toInt(),
            .birth = 1,
            .offlinetm = 0,
            .onlinetm = 0,
            .is_busy = false,
            .wardrobe = .{
                .sex = basic_info.sex.toPlayerSexType(),
                .height = 90,
                .complexion = 0,
            },
            .account = open_id.view(),
            .regtm = 0,
            .exp = 0,
            .home_lv = 1,
            .info = .{},
            .detail_info = .{},
            .lend_info = .{ .can_lend_num = 0, .last_lend_time = 0 },
            .language = 1,
            .lock_system = .empty,
            .preffix_title = 0,
            .suffix_title = 0,
            .little_avatar = "",
            .last_change_name_time = 0,
            .birthday = .{ .month = 2, .day = 21 },
            .world_time = 0,
            .stand_plates = .{},
            .hero_gift_info = .{},
            .is_created = true,
            .scene_showcase = .empty,
            .skip_guide = 1,
            .apparel_info = .{},
            .show_case = 0,
            .show_case_id = 0,
            .team_id = 0,
            .map_id = 0,
            .nest_star = 0,
            .nest_guide_finish = 1,
        },
        .heros_info = .{
            .heros = .initBuffer(&heros_buffer),
            .battle_infos = .initBuffer(&battle_heros_buffer),
        },
        .sbag_infos = .{ .items = .empty },
        .attr_infos = .{},
        .soulessence_infos = .{
            .soulessences = try .initCapacity(
                txn.any.arena,
                player_store.soul_essence.item_map.entries.len,
            ),
        },
        .group_mgrs = .empty,
        .guide_infos = .{ .infos = .empty },
    };

    var hero_items = player_store.hero.item_map.iterator();

    while (hero_items.next()) |entry| {
        const hero_id = entry.key;
        const hero = entry.value;

        if (@intFromEnum(hero_id) == @as(u32, switch (player_store.basic_info.sex) {
            .female => tables.game.avatar_hero_id_male,
            .male => tables.game.avatar_hero_id_female,
        })) continue;

        const uuid: logic.Uuid = .hero(player_store.id, hero_id);

        player_data.heros_info.?.heros.appendAssumeCapacity(
            try encoding.packHeroItemInfo(
                txn.any.arena,
                uuid,
                hero.*,
            ),
        );
    }

    var soul_essence_items = player_store.soul_essence.item_map.iterator();

    while (soul_essence_items.next()) |entry| {
        const soul_essence_id = entry.key_ptr.*;
        const soul_essence = entry.value_ptr;

        player_data.soulessence_infos.?.soulessences.appendAssumeCapacity(.{
            .guid = soul_essence_id,
            .id = soul_essence_id,
            .lv = soul_essence.lv,
            .wear_hero = soul_essence.hero_id,
            .advance = @intFromEnum(soul_essence.stars),
            .exp = soul_essence.exp,
            .lock = true,
            .rank = @intFromEnum(soul_essence.rank),
            .nums = null,
            .zombie = null,
        });
    }

    var group_mgrs_buf: [PlayerStore.Lineup.GroupMap.len]pb.GroupManager = undefined;
    var groups_buf: [group_mgrs_buf.len * PlayerStore.Lineup.Formation.count]pb.Group = undefined;
    var group_heros_buf: [PlayerStore.Lineup.Formation.HeroPos.count * groups_buf.len]pb.GroupHeroPos = undefined;

    encoding.packGroupManagers(
        player_store,
        &player_data.group_mgrs,
        &group_mgrs_buf,
        &groups_buf,
        &group_heros_buf,
    );

    try txn.respond(.{
        .data = player_data,
        .reconnect = txn.request.reconnect,
        .time_zone = 3,
        .time = @intCast(txn.any.time.toSeconds()),
        .time_msec = @intCast(@mod(txn.any.time.toMilliseconds(), 1000)),
        .player_id = player_id,
        .server_token = txn.request.server_token,
        .rc4_key = "",
        .ntf_seq = txn.request.ntf_seq,
        .req_seq = txn.any.seq_no,
        .line_id = 0,
        .server_id = "zetsa",
        .node_id = "zetsa-node0",
    });

    var syslist_buf: [1]pb.GameSystemInfo = undefined;
    var syslist: std.ArrayList(pb.GameSystemInfo) = .initBuffer(&syslist_buf);

    syslist.appendAssumeCapacity(.{
        .sysId = @intFromEnum(logic.System.waterMark),
        .status = 1,
        .reason = "",
    });

    try txn.any.send(.CSProtoGMSystemCloseSync, .{ .syslist = syslist });

    // Pets

    var pets: std.ArrayList(pb.PetbaseInfo) = try .initCapacity(txn.any.arena, player_store.pet.item_map.entries.len);

    var pet_items = player_store.pet.item_map.iterator();

    while (pet_items.next()) |pet_entry| pets.appendAssumeCapacity(
        try encoding.packPetInfo(
            txn.any.arena,
            pet_entry.key_ptr.*,
            pet_entry.value_ptr.*,
            player_store.pet.getPetRouletteIndex(pet_entry.key_ptr.*),
        ),
    );

    try txn.any.send(.CSProtoPetInfoSync, pb.SCPetInfoSync{
        .pet_infos = .{
            .pets = pets,
        },
    });

    // Mounts

    var saddles_buf: [tables.mount_saddle.list.len]u32 = undefined;
    var saddles: std.ArrayList(u32) = .initBuffer(&saddles_buf);

    for (tables.mount_saddle.list) |saddle| {
        saddles.appendAssumeCapacity(saddle.id);
    }

    try txn.any.send(.CSProtoRideMountInfo, pb.PlayerMountInfo{
        .mount_saddlerys = saddles,
    });

    // Exploration level

    var exploration_info_list_buf: [tables.explore_level.list.len]pb.ExplorationMapInfo = undefined;
    var exploration_info_list: std.ArrayList(pb.ExplorationMapInfo) = .initBuffer(&exploration_info_list_buf);

    for (tables.explore_level.grouped) |g| {
        if (g.max()) |max| {
            exploration_info_list.appendAssumeCapacity(.{
                .map_id = max.regionid,
                .lv = max.lv,
                .exp = 0,
            });
        }
    }

    try txn.any.send(.CSProtoWorldExplorationSync, pb.SCExplorationSync{
        .map_info = exploration_info_list,
    });
}

fn kickPlayer(txn: *messaging.AnyTransaction, reason: []const u8) !void {
    return try txn.sendErrorMsg(
        .CSProtoRetrun2Login,
        .Ban,
        .{
            .timestamp = 1,
            .reason = reason,
        },
    );
}

const PlayerStore = logic.PlayerStore;
const ArrayList = std.ArrayList;

const Transaction = messaging.Transaction;

const pb = proto.pb;

const messaging = @import("../messaging.zig");
const encoding = @import("../encoding.zig");
const tables = @import("../tables.zig");
const logic = @import("../logic.zig");
const store = @import("../store.zig");
const proto = @import("proto");
const std = @import("std");
