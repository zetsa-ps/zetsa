pub fn enterWorldMap(txn: Transaction(.CSProtoEnterWorldMap)) !void {
    const log = std.log.scoped(.CSProtoEnterWorldMap);
    log.debug("{any}", .{txn.request});

    var previous_world_map: ?logic.PlayerStore.WorldMap = null;
    const world_map = &txn.any.player_store.world_map;

    if ((txn.request.map_id orelse 0) != 0 and (txn.request.point_id orelse 0) != 0) {
        const map_id = txn.request.map_id.?;

        if (map_id == tables.game.home_id) {
            previous_world_map = world_map.*;
        }

        for (tables.world_borthpos.list) |world_borthpos| {
            if (world_borthpos.city_id == map_id) {
                if (world_borthpos.id == txn.request.point_id.?) {
                    world_map.map_id = @bitCast(map_id);
                    world_map.area_id = tables.world_area.calculateBelongArea(
                        map_id,
                        world_borthpos.borth_point[0..3].*,
                        false,
                    );

                    world_map.setPositionByBorthPoint(world_borthpos.borth_point);

                    if (map_id == tables.game.home_id) break;

                    {
                        const old_cancel_protection = txn.any.io.swapCancelProtection(.blocked);
                        defer _ = txn.any.io.swapCancelProtection(old_cancel_protection);

                        store.player.saveWorldMapAttributes(txn.any.io, txn.any.player_store) catch |err| {
                            log.err("failed to save world map attributes: {t}", .{err});
                            return;
                        };
                    }

                    break;
                }
            }
        } else {
            log.warn("invalid point requested: map_id={d}, point_id={d}", .{ map_id, txn.request.point_id.? });
            return;
        }
    }

    try txn.respond(.{});

    try sendWorldMapSync(txn.any, txn.request.client_trans_data);

    try sendObjBattleInfoSync(txn.any);
    try sendBattleHeroInfoSync(txn.any);
    try sendHeroAttrInfoSync(txn.any);

    if (previous_world_map != null) {
        world_map.* = previous_world_map.?;
    }
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

    const world_map = &txn.any.player_store.world_map;

    world_map.map_id = pos.city_id;
    world_map.area_id = tables.world_area.calculateBelongArea(
        pos.city_id,
        pos.borth_point[0..3].*,
        false,
    );

    world_map.setPositionByBorthPoint(pos.borth_point);

    {
        const old_cancel_protection = txn.any.io.swapCancelProtection(.blocked);
        defer _ = txn.any.io.swapCancelProtection(old_cancel_protection);

        store.player.saveWorldMapAttributes(txn.any.io, txn.any.player_store) catch |err| {
            log.err("failed to save world map attributes: {t}", .{err});
            return;
        };
    }

    try txn.respond(.{});
    try sendWorldMapSync(txn.any, txn.request.client_trans_data);
}

pub fn objHatredIncSync(txn: Transaction(.CSProtoObjHatredIncSync)) !void {
    const log = std.log.scoped(.CSProtoObjHatredIncSync);
    log.debug("{any}", .{txn.request});

    try txn.respond(.{
        .inc = txn.request.inc,
        .info = txn.request.info,
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

    if (txn.request.move_msg) |move_msg| for (move_msg.move.items) |move_item| {
        if (move_msg.map_id == tables.game.home_id) break;

        if (active_uuid == move_item.uuid) {
            const move_info = move_item.info orelse continue;

            const pos = move_info.pos orelse continue;

            if (move_info.angle) |angle|
                player_store.world_map.angle = angle * 100;

            if (move_info.area_id) |area_id|
                player_store.world_map.area_id = area_id;

            player_store.world_map.position_x = pos.x orelse 0;
            player_store.world_map.position_y = pos.y orelse 0;
            player_store.world_map.position_z = pos.z orelse 0;

            {
                const old_cancel_protection = txn.any.io.swapCancelProtection(.blocked);
                defer _ = txn.any.io.swapCancelProtection(old_cancel_protection);

                store.player.saveWorldMapAttributes(txn.any.io, player_store) catch |err| {
                    log.err("failed to save world map attributes: {t}", .{err});
                    return;
                };
            }

            break;
        }
    };
}

pub fn enterHome(txn: Transaction(.CSProtoEnterHome)) !void {
    if (txn.request.creator_id) |creator_id| {
        if (creator_id == txn.any.player_store.id.toInt()) {
            const world_map = &txn.any.player_store.world_map;
            const previous_world_map = world_map.*;

            world_map.map_id = tables.game.home_id;
            world_map.setPositionByBorthPoint(tables.world_borthpos.queryCityBirthPos(world_map.map_id).?.borth_point);

            try sendWorldMapSync(txn.any, null);

            world_map.* = previous_world_map;
        }
    }

    try txn.respond(.{});
}

pub fn worldQuitHome(txn: Transaction(.CSProtoWorldQuitHome)) !void {
    try sendWorldMapSync(txn.any, null);

    try txn.respond(.{});
}

fn sendWorldMapSync(txn: *AnyTransaction, ctd: ?u32) !void {
    const player_store = txn.player_store;
    var map_points: std.ArrayList(u32) = .empty;

    for (tables.world_borthpos.list) |world_borthpos| {
        if (world_borthpos.city_id == player_store.world_map.map_id) {
            try map_points.append(txn.arena, world_borthpos.id);
        }
    }

    var world_map: pb.WorldMap = .{
        .creator_id = player_store.id.toInt(),
        .map_id = player_store.world_map.map_id,
        .players = .empty,
    };

    const move_info: pb.MoveInfo = .{
        .pos = .{
            .x = player_store.world_map.position_x,
            .y = player_store.world_map.position_y,
            .z = player_store.world_map.position_z,
        },
        .angle = player_store.world_map.angle,
        .area_id = player_store.world_map.area_id,
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

    var player: pb.WorldMapPlayer = .{
        .player_id = player_store.id.toInt(),
        .status = @intFromEnum(pb.WorldMapPlayerStatusType.WMPST_NORMAL),
        .reason = 0,
        .name = basic_info.name.view(),
        .host = true,
        .move = .empty,
        .group = group,
        .face = .{
            .sex = basic_info.sex.toPlayerSexType(),
            .height = 90,
            .complexion = 0,
        },
        .apparel_info = .{ .apparel_ids = .empty },
    };

    try player.move.append(txn.arena, move_info);

    try world_map.players.append(txn.arena, player);

    try txn.send(.CSProtoWorldMapPointSync, .{ .u32s = map_points });

    try txn.send(.CSProtoWorldMapSync, .{
        .cmd = @intFromEnum(pb.WorldMapCmdType.WMCT_ENTER),
        .creator_id = player_store.id.toInt(),
        .map_id = player_store.world_map.map_id,
        .player_id = player_store.id.toInt(),
        .notify_id = player_store.id.toInt(), // ??
        .zone_id = 0, // battle zone ?
        .client_trans_data = ctd,
        .chats = .empty,
        .map_info = world_map,
    });
}

fn sendObjBattleInfoSync(txn: *AnyTransaction) !void {
    const player_store = txn.player_store;

    var infos_buf: [PlayerStore.Hero.ItemMap.len - 1]pb.ObjBattleInfo = undefined;
    var infos: std.ArrayList(pb.ObjBattleInfo) = .initBuffer(&infos_buf);

    var hero_items = player_store.hero.item_map.iterator();

    while (hero_items.next()) |entry| {
        const id = entry.key;
        const hero = entry.value;

        if (@intFromEnum(id) == @as(u32, switch (txn.player_store.basic_info.sex) {
            .female => tables.game.avatar_hero_id_male,
            .male => tables.game.avatar_hero_id_female,
        })) continue;

        const uuid: logic.Uuid = .hero(player_store.id, id);

        infos.appendAssumeCapacity(.{
            .uuid = uuid.toInt(),
            .hp = hero.hp.toInt(),
            .sp = hero.sp.toInt(),
            .alive_state = hero.hp.aliveState().toAliveStateType(),
            .reason = 1,
        });
    }

    try txn.send(.CSProtoObjBattleInfoSync, .{ .infos = infos });
}

fn sendBattleHeroInfoSync(txn: *AnyTransaction) !void {
    const player_store = txn.player_store;

    var heros_buf: [PlayerStore.Hero.ItemMap.len - 1]pb.FightHeroInfo = undefined;
    var heros: std.ArrayList(pb.FightHeroInfo) = .initBuffer(&heros_buf);

    var oinfo_buf: [1]pb.FightOrnamentInfo = undefined;
    var oinfo: std.ArrayList(pb.FightOrnamentInfo) = .initBuffer(&oinfo_buf);

    oinfo.appendAssumeCapacity(.{
        .id = 0,
        .attrs = .{},
        .main_attrs = .{},
    });

    var it = player_store.hero.item_map.iterator();

    while (it.next()) |entry| {
        const hero_id = entry.key;
        const hero = entry.value;

        if (@intFromEnum(hero_id) == @as(u32, switch (txn.player_store.basic_info.sex) {
            .female => tables.game.avatar_hero_id_male,
            .male => tables.game.avatar_hero_id_female,
        })) continue;

        const conf = tables.hero.getById(@intFromEnum(hero_id)).?;

        const uuid: logic.Uuid = .hero(player_store.id, hero_id);

        var skill_infos: pb.HeroSkillInfos = .{ .skills = try .initCapacity(txn.arena, conf.skill_list.len) };

        for (conf.skill_list) |skill| {
            skill_infos.skills.appendAssumeCapacity(.{
                .skill_id = skill.value,
                .skill_level = 1,
            });
        }

        heros.appendAssumeCapacity(.{
            .hero_guid = @truncate(uuid.toInt()),
            .hero_conf_id = conf.id,
            .winfo = .{ .attrs = .{} },
            .strategy = 0,
            .attrs = .{
                .attrs = try buildHeroBaseAttrs(txn.arena, conf.id, 1, 1),
            },
            .skills = skill_infos,
            .hp = hero.hp.toInt(),
            .sp = hero.sp.toInt(),
            .lv = hero.lv.toInt(),
            .rank = hero.rank.toInt(),
            .star = 0,
            .wainfo = .{ .id = conf.weapon_default },
            .wardrobeinfos = .{
                .sex = @intFromEnum(pb.PlayerSexType.PST_FEMALE),
                .height = 90,
                .complexion = 0,
            },
            .oinfo = oinfo,
            .suitSkills = .{},
            .star_gifts = .empty,
            .favor_lv = 1,
            .time = @intCast(txn.time.toSeconds()),
            .buffs = .{ .attrs = .empty },
        });
    }

    try txn.send(.CSProtoBattleHeroInfoSync, .{ .heros = heros });
}

fn sendHeroAttrInfoSync(txn: *AnyTransaction) !void {
    var heros_buf: [PlayerStore.Hero.ItemMap.len - 1]pb.HeroAttrInfo = undefined;
    var modules_buf: [PlayerStore.Hero.ItemMap.len - 1]pb.HeroAttrModuleInfo = undefined;
    var sub_modules_buf: [PlayerStore.Hero.ItemMap.len - 1]pb.HeroAttrSubModuleInfo = undefined;

    var heros: std.ArrayList(pb.HeroAttrInfo) = .initBuffer(&heros_buf);
    var modules: std.ArrayList(pb.HeroAttrModuleInfo) = .initBuffer(&modules_buf);
    var sub_modules: std.ArrayList(pb.HeroAttrSubModuleInfo) = .initBuffer(&sub_modules_buf);

    var it = txn.player_store.hero.item_map.iterator();

    while (it.next()) |entry| {
        const hero_id = entry.key;

        if (@intFromEnum(hero_id) == @as(u32, switch (txn.player_store.basic_info.sex) {
            .female => tables.game.avatar_hero_id_male,
            .male => tables.game.avatar_hero_id_female,
        })) continue;

        const uuid: logic.Uuid = .hero(txn.player_store.id, hero_id);
        const conf = tables.hero.getById(@intFromEnum(hero_id)).?;

        var skills: std.ArrayList(pb.UnitSkillInfo) = try .initCapacity(txn.arena, conf.skill_list.len + conf.aerial_skill_list.len + conf.passive_skill_list.len + conf.backup_skill_list.len + 1);

        for (conf.skill_list) |skill| skills.appendAssumeCapacity(.{
            .skill_id = skill.value,
            .skill_slot = skill.key,
            .skill_lv = 1,
            .type = 0,
        });

        for (conf.aerial_skill_list) |skill| skills.appendAssumeCapacity(.{
            .skill_id = skill.value,
            .skill_slot = skill.key,
            .skill_lv = 1,
            .type = 0,
        });

        for (conf.passive_skill_list) |id| {
            skills.appendAssumeCapacity(.{ .skill_id = id, .skill_lv = 1, .type = 0 });
        }

        for (conf.backup_skill_list) |id| {
            skills.appendAssumeCapacity(.{ .skill_id = id, .skill_lv = 1, .type = 0 });
        }

        skills.appendAssumeCapacity(.{
            .skill_id = conf.attack_skill,
            .skill_slot = 1,
            .skill_lv = 1,
            .type = 0,
        });

        sub_modules.appendAssumeCapacity(.{
            .sub_module_id = 0,
            .attrs = .{
                .attrs = try buildHeroBaseAttrs(txn.arena, conf.id, 1, 1),
            },
            .skills = skills,
        });

        modules.appendAssumeCapacity(.{
            .module_type = @intFromEnum(pb.HeroAttrModuleType.HAMT_HERO_BASIC),
            .sub_modules = sub_modules,
        });

        heros.appendAssumeCapacity(.{
            .hero_guid = @truncate(uuid.toInt()),
            .hero_conf_id = conf.id,
            .type = @intFromEnum(pb.FightObjType.FO_Hero),
            .modules = modules,
        });
    }

    try txn.send(.CSProtoHeroAttrInfoSync, .{ .heros = heros });
}

fn buildHeroBaseAttrs(arena: std.mem.Allocator, hero_id: u32, hero_level: u32, hero_rank: u32) !std.ArrayList(pb.FightAttrOne) {
    const EBattlePropertyType = logic.big_world.EBattlePropertyType;

    const hero = tables.hero.getById(hero_id).?;
    const hero_att_id = tables.unit_property.getById(hero.property_id).?.base_attribute_id;
    const hero_base_att_id = tables.template_hero.getBaseAttributeByRankAndLevel(hero_rank, hero_level);
    const base_template = tables.template_value.getById(hero_base_att_id);

    const base_values = base_template.?.base_attribute;
    const factor_template = tables.template_value.getById(hero_att_id);

    const factor_values = factor_template.?.base_attribute;
    var factor_map: std.EnumMap(EBattlePropertyType, f32) = .init(.{});

    for (factor_values) |entry| {
        factor_map.put(std.enums.fromInt(EBattlePropertyType, entry.key) orelse continue, entry.value);
    }

    var attributes: std.ArrayList(pb.FightAttrOne) = try .initCapacity(arena, base_values.len);

    for (base_values) |entry| {
        attributes.appendAssumeCapacity(.{
            .attr_id = @intCast(entry.key),
            .attr_val = if (factor_map.get(
                std.enums.fromInt(EBattlePropertyType, entry.key) orelse continue,
            )) |factor|
                @intFromFloat(entry.value * factor)
            else
                0,
        });
    }

    return attributes;
}

const PlayerStore = logic.PlayerStore;

const AnyTransaction = messaging.AnyTransaction;
const Transaction = messaging.Transaction;
const pb = proto.pb;

const messaging = @import("../messaging.zig");
const tables = @import("../tables.zig");
const logic = @import("../logic.zig");
const store = @import("../store.zig");
const proto = @import("proto");
const std = @import("std");
