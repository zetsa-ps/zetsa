pub fn enterWorldMap(txn: Transaction(.CSProtoEnterWorldMap)) !void {
    const log = std.log.scoped(.CSProtoEnterWorldMap);
    log.debug("{any}", .{txn.request});

    const io = txn.any.io;
    const player_store = txn.any.player_store;

    if ((txn.request.map_id orelse 0) != 0 and (txn.request.point_id orelse 0) != 0) {
        const map_id = txn.request.map_id.?;
        const map_kind: PlayerStore.World.Map.Kind = .byMapId(map_id);

        const borth_pos = lookup: for (tables.world_borthpos.list) |world_borthpos| {
            if (world_borthpos.city_id == map_id and world_borthpos.id == txn.request.point_id.?)
                break :lookup world_borthpos;
        } else {
            log.warn("invalid point requested: map_id={d}, point_id={d}", .{ map_id, txn.request.point_id.? });
            return;
        };

        const map: PlayerStore.World.Map = .initByBorthPos(&borth_pos);
        player_store.world.maps.put(map_kind, map);
        player_store.world.attrs.active_kind = map_kind;

        var save_world_table = io.async(store.player.saveWorldMapTable, .{ io, player_store });
        defer save_world_table.cancel(io) catch {};

        var save_world_attrs = io.async(store.player.saveWorldAttributes, .{ io, player_store });
        defer save_world_attrs.cancel(io) catch {};

        save_world_table.await(io) catch |err| {
            log.err("failed to save world map table: {t}", .{err});
            return;
        };

        save_world_attrs.await(io) catch |err| {
            log.err("failed to save world attributes: {t}", .{err});
            return;
        };
    }

    const world_map = player_store.world.maps.getPtr(player_store.world.attrs.active_kind).?;
    const map_config = txn.any.assets.world_maps.map.getPtr(world_map.id) orelse {
        log.err("world map with id {d} doesn't exist", .{world_map.id});
        return;
    };

    const battle = &txn.any.services.battle;

    battle.map_config = map_config;
    try battle.reset(txn.any.gpa, player_store);

    try txn.respond(.{});

    try sendWorldMapSync(txn.any, txn.request.client_trans_data);

    try sendHeroAttrInfoSync(txn.any);

    try txn.any.send(
        .CSProtoObjBattleInfoSync,
        try encoding.packObjBattleInfoSync(txn.any.arena, battle, 1),
    );
}

pub fn dayWeatherSync(txn: Transaction(.CSProtoDayWeatherSync)) !void {
    try txn.respond(.{ .weather = txn.request.weather });
}

// TODO
pub fn worldDifficultyRedPointSet(txn: Transaction(.CSProtoWorldDifficultyRedPointSet)) !void {
    const log = std.log.scoped(.CSProtoWorldDifficultyRedPointSet);
    log.debug("{any}", .{txn.request});

    try txn.respond(.{});
}

// TODO
pub fn redPointSet(txn: Transaction(.CSProtoRedPointSet)) !void {
    const log = std.log.scoped(.CSProtoRedPointSet);
    log.debug("{any}", .{txn.request});

    try txn.respond(.{});
}

// TODO
pub fn worldObjInteract(txn: Transaction(.CSProtoWorldObjInteract)) !void {
    const log = std.log.scoped(.CSProtoWorldObjInteract);

    var objs: std.ArrayList(pb.SCWorldMapObjInteract.WorldMapObjInteract) = try .initCapacity(
        txn.any.arena,
        txn.request.objs.items.len,
    );

    for (txn.request.objs.items) |obj| {
        log.debug("{any}", .{obj});

        objs.appendAssumeCapacity(.{
            .obj = obj.obj,
            .pos = obj.pos,
            .rewards = .{},
            .drop_ids = .empty,
            .interact_type = obj.interact_type,
            .tool_type = null,
        });
    }

    try txn.respond(.{ .objs = objs });
}

pub fn worldPoint(txn: Transaction(.CSProtoWorldPoint)) !void {
    const log = std.log.scoped(.CSProtoWorldPoint);
    log.debug("{any}", .{txn.request});

    const point_id = txn.request.point_id orelse {
        log.warn("point_id is null", .{});
        return;
    };

    const pos = tables.world_borthpos.getById(point_id) orelse {
        log.warn("invalid point_id: {d}", .{point_id});
        return;
    };

    const player_store = txn.any.player_store;
    const world_map = player_store.world.maps.getPtr(player_store.world.attrs.active_kind).?;

    world_map.id = pos.city_id;
    world_map.area_id = tables.world_area.calculateBelongArea(
        pos.city_id,
        pos.borth_point[0..3].*,
        false,
    );

    world_map.setPositionByBorthPoint(pos.borth_point);

    store.player.saveWorldMapTable(txn.any.io, txn.any.player_store) catch |err| {
        log.err("failed to save world map table: {t}", .{err});
        return;
    };

    try txn.respond(.{});
    try sendWorldMapSync(txn.any, txn.request.client_trans_data);
}

pub fn objHatredIncSync(txn: Transaction(.CSProtoObjHatredIncSync)) !void {
    const log = std.log.scoped(.CSProtoObjHatredIncSync);

    if (txn.request.info) |info| if (info.id) |hatred_id| {
        const uuid: logic.Uuid = @bitCast(hatred_id);
        const object_type = uuid.object_type.toFightObjType() orelse return;

        if (object_type != .FO_Monster) {
            log.warn("unimplemented object type: {t}", .{object_type});
            return;
        }

        const battle = &txn.any.services.battle;
        try battle.instantiateEnemyGroup(txn.any.gpa, uuid.player_id);
    };

    try txn.respond(.{
        .inc = txn.request.inc,
        .info = txn.request.info,
    });
}

pub fn hatredResetToHomeSync(txn: Transaction(.CSProtoHatredResetToHomeSync)) !void {
    if (txn.request.obj_id) |id| {
        const uuid: logic.Uuid = @bitCast(id);
        txn.any.services.battle.resetEnemyGroup(uuid.player_id);
    }

    try txn.respond(.{
        .obj_id = txn.request.obj_id,
    });
}

pub fn stateUpdate(txn: Transaction(.CSProtoStateUpdate)) !void {
    const log = std.log.scoped(.CSProtoStateUpdate);
    const player_store = txn.any.player_store;

    const world_group = player_store.lineup.group_map.getPtr(.world).?;
    const active_uuid = logic.Uuid.hero(
        player_store.id,
        world_group.formation_controls[world_group.cur_formation].toHeroId().?,
    ).toInt();

    const map = player_store.world.maps.getPtr(player_store.world.attrs.active_kind).?;

    if (txn.request.move_msg) |move_msg| for (move_msg.move.items) |move_item| {
        if (move_msg.map_id == tables.game.home_id) break;

        if (active_uuid == move_item.uuid) {
            const move_info = move_item.info orelse continue;

            const pos = move_info.pos orelse continue;

            if (move_info.angle) |angle|
                map.angle = angle * 100;

            if (move_info.area_id) |area_id|
                map.area_id = area_id;

            map.position_x = pos.x orelse 0;
            map.position_y = pos.y orelse 0;
            map.position_z = pos.z orelse 0;

            store.player.saveWorldMapTable(txn.any.io, player_store) catch |err| {
                log.err("failed to save world map table: {t}", .{err});
                return;
            };

            break;
        }
    };
}

pub fn battleInfoReduce(txn: Transaction(.CSProtoBattleInfoReduce)) !void {
    const battle = &txn.any.services.battle;
    battle.reduce(txn.request);

    if (battle.modified_count != 0) try txn.any.send(
        .CSProtoObjBattleInfoSync,
        try encoding.packObjBattleInfoSync(txn.any.arena, battle, 0),
    );

    switch (battle.hatred.acknowledge()) {
        .reset => try txn.any.send(.SCProtoWorldHatredSync, .{}),
        .nothing => {},
    }
}

pub fn skillStart(txn: Transaction(.CSProtoSkillStart)) !void {
    const battle = &txn.any.services.battle;

    const uuid: logic.Uuid = @bitCast(txn.request.unit_id orelse return);
    if (uuid.object_type.toFightObjType() != .FO_Hero) return;

    const skill = txn.request.skill orelse return;
    const skill_id = skill.skill_id orelse return;
    const config = tables.hero.getById(uuid.config_id) orelse return;
    const slot = std.enums.fromInt(
        big_world.ESkillSlotType,
        config.getSkillSlot(skill_id) orelse return,
    ) orelse return;

    switch (slot) {
        .ultra_skill => battle.drainSp(uuid),
        else => {},
    }

    if (battle.modified_count != 0) try txn.any.send(
        .CSProtoObjBattleInfoSync,
        try encoding.packObjBattleInfoSync(txn.any.arena, battle, 0),
    );
}

pub fn enterHome(txn: Transaction(.CSProtoEnterHome)) !void {
    const log = std.log.scoped(.CSProtoEnterHome);
    const player_store = txn.any.player_store;

    if (txn.request.creator_id) |creator_id| {
        if (creator_id == player_store.id.toInt()) {
            const borth_pos = tables.world_borthpos.queryCityBirthPos(tables.game.home_id).?;
            const map: PlayerStore.World.Map = .initByBorthPos(&borth_pos);

            player_store.world.maps.put(.home, map);
            player_store.world.attrs.active_kind = .home;

            const io = txn.any.io;

            const map_config = txn.any.assets.world_maps.map.getPtr(map.id).?;

            const battle = &txn.any.services.battle;
            battle.map_config = map_config;
            try battle.reset(txn.any.gpa, player_store);

            var save_world_table = io.async(store.player.saveWorldMapTable, .{ io, player_store });
            defer save_world_table.cancel(io) catch {};

            var save_world_attrs = io.async(store.player.saveWorldAttributes, .{ io, player_store });
            defer save_world_attrs.cancel(io) catch {};

            save_world_table.await(io) catch |err| {
                log.err("failed to save world map table: {t}", .{err});
                return;
            };

            save_world_attrs.await(io) catch |err| {
                log.err("failed to save world attributes: {t}", .{err});
                return;
            };

            try sendWorldMapSync(txn.any, null);
        }
    }

    try txn.respond(.{});
}

pub fn worldQuitHome(txn: Transaction(.CSProtoWorldQuitHome)) !void {
    const log = std.log.scoped(.CSProtoWorldQuitHome);
    txn.any.player_store.world.attrs.active_kind = .exploration;
    const map = txn.any.player_store.world.maps.getPtr(.exploration).?;

    const io = txn.any.io;

    const map_config = txn.any.assets.world_maps.map.getPtr(map.id) orelse {
        log.err("world map with id {d} doesn't exist", .{map.id});
        return;
    };

    const battle = &txn.any.services.battle;
    battle.map_config = map_config;
    try battle.reset(txn.any.gpa, txn.any.player_store);

    store.player.saveWorldAttributes(io, txn.any.player_store) catch |err| {
        log.err("failed to save world attributes: {t}", .{err});
        return;
    };

    try sendWorldMapSync(txn.any, null);
    try txn.respond(.{});
}

fn sendWorldMapSync(txn: *AnyTransaction, ctd: ?u32) !void {
    const player_store = txn.player_store;
    var map_points: std.ArrayList(u32) = .empty;

    const world_map = player_store.world.maps.getPtr(player_store.world.attrs.active_kind).?;

    for (tables.world_borthpos.list) |world_borthpos| {
        if (world_borthpos.city_id == world_map.id) {
            try map_points.append(txn.arena, world_borthpos.id);
        }
    }

    var players_buf: [1]pb.WorldMapPlayer = undefined;

    var world_map_pb: pb.WorldMap = .{
        .creator_id = player_store.id.toInt(),
        .map_id = world_map.id,
        .players = .initBuffer(&players_buf),
    };

    const move_info: pb.MoveInfo = .{
        .pos = .{
            .x = world_map.position_x,
            .y = world_map.position_y,
            .z = world_map.position_z,
        },
        .angle = world_map.angle,
        .area_id = world_map.area_id,
        .move_status = @intFromEnum(pb.MoveStatus.MS_TRANSFER),
        .timestamp = @intCast(txn.time.toSeconds()),
    };

    const world_group = player_store.lineup.group_map.getPtr(.world).?;
    const formation_index = world_group.cur_formation;

    var group_heros_buf: [PlayerStore.Lineup.Formation.HeroPos.count]u64 = undefined;
    var group_hero_mid_buf: [PlayerStore.Lineup.Formation.HeroPos.count]u64 = undefined;

    var group: pb.WorldMapGroup = .{
        .heros = .initBuffer(&group_heros_buf),
        .hero_mid = .initBuffer(&group_hero_mid_buf),
        .control = if (world_group.formation_controls[formation_index].toHeroId()) |hero_id|
            logic.Uuid.hero(player_store.id, hero_id).toInt()
        else
            null,
    };

    for (world_group.formation_heros[formation_index]) |hero_pos| {
        const hero_id = hero_pos.toHeroId() orelse continue;
        const uuid: logic.Uuid = .hero(player_store.id, hero_id);

        group.heros.appendAssumeCapacity(uuid.toInt());
        group.hero_mid.appendAssumeCapacity(uuid.toInt());
    }

    const basic_info = &txn.player_store.basic_info;

    var player_move_buf: [1]pb.MoveInfo = undefined;

    var player: pb.WorldMapPlayer = .{
        .player_id = player_store.id.toInt(),
        .status = @intFromEnum(pb.WorldMapPlayerStatusType.WMPST_NORMAL),
        .reason = 0,
        .name = basic_info.name.view(),
        .host = true,
        .move = .initBuffer(&player_move_buf),
        .group = group,
        .face = .{
            .sex = basic_info.sex.toPlayerSexType(),
            .height = 90,
            .complexion = 0,
        },
        .apparel_info = .{ .apparel_ids = .empty },
    };

    player.move.appendAssumeCapacity(move_info);

    world_map_pb.players.appendAssumeCapacity(player);

    try txn.send(.CSProtoWorldMapPointSync, .{ .u32s = map_points });

    try txn.send(.CSProtoWorldMapSync, .{
        .cmd = @intFromEnum(pb.WorldMapCmdType.WMCT_ENTER),
        .creator_id = player_store.id.toInt(),
        .map_id = world_map.id,
        .player_id = player_store.id.toInt(),
        .notify_id = player_store.id.toInt(), // ??
        .zone_id = 0, // battle zone ?
        .client_trans_data = ctd,
        .chats = .empty,
        .map_info = world_map_pb,
    });
}

fn sendHeroAttrInfoSync(txn: *AnyTransaction) !void {
    const hero_count = PlayerStore.Hero.ItemMap.len - 1;
    const module_count = 2;
    const sub_module_count = 1;

    var heroes_buf: [hero_count]pb.HeroAttrInfo = undefined;
    var modules_buf: [hero_count * module_count]pb.HeroAttrModuleInfo = undefined;
    var sub_modules_buf: [hero_count * module_count * sub_module_count]pb.HeroAttrSubModuleInfo = undefined;
    var attrs_buf: [hero_count * module_count * sub_module_count * big_world.Attributes.len]pb.FightAttrOne = undefined;

    var heroes: std.ArrayList(pb.HeroAttrInfo) = .initBuffer(&heroes_buf);

    var it = txn.player_store.hero.item_map.iterator();
    var i: usize = 0;

    while (it.next()) |entry| {
        const hero_id = entry.key;
        const hero = entry.value;

        if (@intFromEnum(hero_id) == @as(u32, switch (txn.player_store.basic_info.sex) {
            .female => tables.game.avatar_hero_id_male,
            .male => tables.game.avatar_hero_id_female,
        })) continue;

        var hero_modules: std.ArrayList(pb.HeroAttrModuleInfo) = .initBuffer(modules_buf[i * module_count .. i * module_count + module_count]);

        const uuid: logic.Uuid = .hero(txn.player_store.id, hero_id);
        const conf = tables.hero.getById(@intFromEnum(hero_id)).?;

        var basic_mod_sub_mods: std.ArrayList(pb.HeroAttrSubModuleInfo) = .initBuffer(sub_modules_buf[(i * module_count) * sub_module_count .. (i * module_count + 1) * sub_module_count]);

        var hero_skills: std.ArrayList(pb.UnitSkillInfo) = try .initCapacity(txn.arena, conf.skill_list.len + conf.aerial_skill_list.len + conf.passive_skill_list.len + conf.backup_skill_list.len + 1);

        for (conf.skill_list) |skill| hero_skills.appendAssumeCapacity(.{
            .skill_id = skill.value,
            .skill_slot = skill.key,
            .skill_lv = 1,
            .type = 0,
        });

        for (conf.aerial_skill_list) |skill| hero_skills.appendAssumeCapacity(.{
            .skill_id = skill.value,
            .skill_slot = skill.key,
            .skill_lv = 1,
            .type = 0,
        });

        for (conf.passive_skill_list) |id| {
            hero_skills.appendAssumeCapacity(.{ .skill_id = id, .skill_lv = 1, .type = 0 });
        }

        for (conf.backup_skill_list) |id| {
            hero_skills.appendAssumeCapacity(.{ .skill_id = id, .skill_lv = 1, .type = 0 });
        }

        hero_skills.appendAssumeCapacity(.{
            .skill_id = conf.attack_skill,
            .skill_slot = 1,
            .skill_lv = 1,
            .type = 0,
        });

        var hero_attr_map: big_world.Attributes = .init(.{});
        big_world.getHeroAttributes(
            hero_id,
            @intFromEnum(hero.lv),
            @intFromEnum(hero.rank),
            &hero_attr_map,
        );

        var hero_attrs: std.ArrayList(pb.FightAttrOne) = .initBuffer(attrs_buf[(i * module_count) * big_world.Attributes.len .. (i * module_count) * big_world.Attributes.len + big_world.Attributes.len]);
        encoding.packFightAttrs(&hero_attr_map, &hero_attrs);

        basic_mod_sub_mods.appendAssumeCapacity(.{
            .sub_module_id = 0,
            .attrs = .{ .attrs = hero_attrs },
            .skills = hero_skills,
        });

        hero_modules.appendAssumeCapacity(.{
            .module_type = @intFromEnum(pb.HeroAttrModuleType.HAMT_HERO_BASIC),
            .sub_modules = basic_mod_sub_mods,
        });

        if (txn.player_store.soul_essence.item_map.get(hero.soul_essence_id)) |se| {
            const se_cfg = tables.soulessence.getById(hero.soul_essence_id).?;

            var se_mod_sub_mods: std.ArrayList(pb.HeroAttrSubModuleInfo) = .initBuffer(sub_modules_buf[(i * module_count + 1) * sub_module_count .. (i * module_count + 2) * sub_module_count]);

            var se_skills_buf: [1]pb.UnitSkillInfo = undefined;
            var se_skills: std.ArrayList(pb.UnitSkillInfo) = .initBuffer(&se_skills_buf);
            se_skills.appendAssumeCapacity(.{
                .skill_id = se_cfg.reishi_skill,
                .skill_lv = @intFromEnum(se.stars),
                .skill_slot = 0,
                .type = 0,
            });

            var se_attr_map: big_world.Attributes = .init(.{});
            big_world.getSoulEssenceAttributes(
                hero.soul_essence_id,
                se.lv,
                @intFromEnum(se.rank),
                &se_attr_map,
            );

            const se_attrs_slice = attrs_buf[(i * module_count + 1) * big_world.Attributes.len .. (i * module_count + 1) * big_world.Attributes.len + big_world.Attributes.len];
            var se_attrs_list: std.ArrayList(pb.FightAttrOne) = .initBuffer(se_attrs_slice);
            encoding.packFightAttrs(&se_attr_map, &se_attrs_list);

            se_mod_sub_mods.appendAssumeCapacity(.{
                .sub_module_id = 0,
                .attrs = .{ .attrs = se_attrs_list },
                .skills = se_skills,
            });

            hero_modules.appendAssumeCapacity(.{
                .module_type = @intFromEnum(pb.HeroAttrModuleType.HAMT_SOULESSENCE),
                .sub_modules = se_mod_sub_mods,
            });
        }

        heroes.appendAssumeCapacity(.{
            .hero_guid = @truncate(uuid.toInt()),
            .hero_conf_id = conf.id,
            .type = @intFromEnum(pb.FightObjType.FO_Hero),
            .modules = hero_modules,
        });

        i += 1;
    }

    try txn.send(.CSProtoHeroAttrInfoSync, .{ .heros = heroes });
}

const PlayerStore = logic.PlayerStore;
const big_world = logic.big_world;

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
