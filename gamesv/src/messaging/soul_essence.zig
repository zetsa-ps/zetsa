pub fn moveSoulEssence(txn: Transaction(.CSProtoMoveSoulEssence)) !void {
    const log = std.log.scoped(.CSProtoMoveSoulEssence);

    const player_store = txn.any.player_store;

    const target_hero_guid: logic.Uuid = @bitCast(txn.request.hero_id orelse {
        try txn.respondError(.ReqParamsError);
        return;
    });

    const target_hero = player_store.hero.item_map.getPtr(
        std.enums.fromInt(PlayerStore.Hero.ID, target_hero_guid.config_id) orelse {
            return try txn.respondError(.HeroNotExist);
        },
    ) orelse {
        return try txn.respondError(.HeroNotExist);
    };

    const old_se_guid = target_hero.soul_essence_id;

    const ChangedHero = struct {
        hero_guid: u64,
        old_se_guid: u32,
    };

    var changed_heroes_buf: [2]ChangedHero = undefined;
    var changed_heroes: std.ArrayList(ChangedHero) = .initBuffer(&changed_heroes_buf);

    var changed_soul_essences_buf: [2]pb.SoulEssence = undefined;
    var changed_soul_essences = std.ArrayList(pb.SoulEssence).initBuffer(&changed_soul_essences_buf);

    const addChangedHero = struct {
        fn add(
            list: *std.ArrayList(ChangedHero),
            hero_guid: u64,
            se_guid: u32,
        ) void {
            for (list.items) |item| {
                if (item.hero_guid == hero_guid) {
                    return;
                }
            }

            list.appendAssumeCapacity(.{
                .hero_guid = hero_guid,
                .old_se_guid = se_guid,
            });
        }
    }.add;

    // Unequip current soul essence (if any) from the target hero
    if (target_hero.soul_essence_id != 0) {
        addChangedHero(
            &changed_heroes,
            target_hero_guid.toInt(),
            target_hero.soul_essence_id,
        );

        // We also have to update the old soul essence
        const old_soul_essence = player_store.soul_essence.item_map.getPtr(target_hero.soul_essence_id).?;

        old_soul_essence.hero_id = 0;

        changed_soul_essences.appendAssumeCapacity(.{
            .guid = target_hero.soul_essence_id,
            .id = target_hero.soul_essence_id,
            .lv = old_soul_essence.lv,
            .wear_hero = old_soul_essence.hero_id,
            .advance = @intFromEnum(old_soul_essence.stars),
            .exp = old_soul_essence.exp,
            .lock = true,
            .rank = @intFromEnum(old_soul_essence.rank),
            .nums = null,
            .zombie = null,
        });

        target_hero.soul_essence_id = 0;
    }

    // Equip new soul essence
    if (txn.request.guid) |new_se_guid| {
        const new_soul_essence = player_store.soul_essence.item_map.getPtr(new_se_guid) orelse {
            try txn.respondError(.SoulEssenceNotExist);
            return;
        };

        // If this soul essence is already equipped to someone else then unequip it first
        if (new_soul_essence.hero_id != 0) {
            const old_hero_guid = new_soul_essence.hero_id;

            if (player_store.hero.item_map.getPtr(
                @enumFromInt(@as(logic.Uuid, @bitCast(old_hero_guid)).config_id),
            )) |old_hero| {
                addChangedHero(
                    &changed_heroes,
                    old_hero_guid,
                    old_hero.soul_essence_id,
                );

                old_hero.soul_essence_id = 0;
            }
        }

        // Equip soul essence
        new_soul_essence.hero_id = target_hero_guid.toInt();
        target_hero.soul_essence_id = new_se_guid;

        addChangedHero(
            &changed_heroes,
            new_soul_essence.hero_id,
            old_se_guid,
        );

        changed_soul_essences.appendAssumeCapacity(.{
            .guid = new_se_guid,
            .id = new_se_guid,
            .lv = new_soul_essence.lv,
            .wear_hero = new_soul_essence.hero_id,
            .advance = @intFromEnum(new_soul_essence.stars),
            .exp = new_soul_essence.exp,
            .lock = true,
            .rank = @intFromEnum(new_soul_essence.rank),
            .nums = null,
            .zombie = null,
        });
    }

    // Sync player data

    var heroes_info_buf: [2]pb.HeroItemInfo = undefined;
    var heroes_info = std.ArrayList(pb.HeroItemInfo).initBuffer(&heroes_info_buf);

    for (changed_heroes.items) |changed_hero| {
        const hero_uuid: logic.Uuid = @bitCast(changed_hero.hero_guid);

        heroes_info.appendAssumeCapacity(
            try encoding.packHeroItemInfo(
                txn.any.arena,
                hero_uuid,
                player_store.hero.item_map.get(
                    @enumFromInt(hero_uuid.config_id),
                ).?,
            ),
        );
    }

    try txn.any.send(.CSProtoSyncPlayerData, pb.PlayerData{
        .heros_info = .{ .heros = heroes_info },
        .soulessence_infos = .{ .soulessences = changed_soul_essences },
    });

    // Sync hero modules (soul essence only)

    var heroes_attrs_buf: [2]pb.HeroAttrInfo = undefined;
    var modules_buf: [2]pb.HeroAttrModuleInfo = undefined;
    var sub_modules_buf: [2]pb.HeroAttrSubModuleInfo = undefined;
    var se_skills_buf: [2]pb.UnitSkillInfo = undefined;
    var attrs_buf: [2 * big_world.Attributes.len]pb.FightAttrOne = undefined;

    var heroes_attrs: std.ArrayList(pb.HeroAttrInfo) = .initBuffer(&heroes_attrs_buf);

    for (changed_heroes.items, 0..) |changed_hero, i| {
        const hero_uuid: logic.Uuid = @bitCast(changed_hero.hero_guid);

        const hero = player_store.hero.item_map.getPtr(
            std.enums.fromInt(PlayerStore.Hero.ID, hero_uuid.config_id) orelse continue,
        ) orelse continue;

        const current_hp = hero.hp.toInt();

        const base_max_hp = logic.big_world.getHeroBaseAttrValue(
            .maxhp,
            hero_uuid.config_id,
            hero.lv.toInt(),
            hero.rank.toInt(),
        );

        var old_max_hp = base_max_hp;
        var new_max_hp = base_max_hp;

        if (changed_hero.old_se_guid != 0) {
            if (player_store.soul_essence.item_map.get(changed_hero.old_se_guid)) |old_se| {
                old_max_hp += @intCast(logic.big_world.getSoulEssenceBaseAttrValue(
                    .maxhp,
                    changed_hero.old_se_guid,
                    old_se.lv,
                    @intFromEnum(old_se.rank),
                ));

                old_max_hp += @trunc(
                    @as(f64, @floatFromInt(old_max_hp)) * @as(
                        f64,
                        @floatFromInt(logic.big_world.getSoulEssenceBaseAttrValue(
                            .per_maxhp,
                            changed_hero.old_se_guid,
                            old_se.lv,
                            @intFromEnum(old_se.rank),
                        )),
                    ) / 10000,
                );
            }
        }

        var hero_modules = std.ArrayList(pb.HeroAttrModuleInfo)
            .initBuffer(modules_buf[i .. i + 1]);

        var se_mod_sub_mods = std.ArrayList(pb.HeroAttrSubModuleInfo)
            .initBuffer(sub_modules_buf[i .. i + 1]);

        if (hero.soul_essence_id != 0) {
            if (player_store.soul_essence.item_map.get(hero.soul_essence_id)) |se| {
                const se_cfg = tables.soulessence.getById(hero.soul_essence_id).?;

                var se_skills: std.ArrayList(pb.UnitSkillInfo) = .initBuffer(se_skills_buf[i .. i + 1]);

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

                var se_attrs_list: std.ArrayList(pb.FightAttrOne) =
                    .initBuffer(attrs_buf[i * big_world.Attributes.len .. i * big_world.Attributes.len + big_world.Attributes.len]);

                encoding.packFightAttrs(&se_attr_map, &se_attrs_list);

                new_max_hp += @intCast(logic.big_world.getSoulEssenceBaseAttrValue(
                    .maxhp,
                    hero.soul_essence_id,
                    se.lv,
                    @intFromEnum(se.rank),
                ));

                new_max_hp += @trunc(
                    @as(f64, @floatFromInt(new_max_hp)) * @as(
                        f64,
                        @floatFromInt(logic.big_world.getSoulEssenceBaseAttrValue(
                            .per_maxhp,
                            hero.soul_essence_id,
                            se.lv,
                            @intFromEnum(se.rank),
                        )),
                    ) / 10000,
                );

                se_mod_sub_mods.appendAssumeCapacity(.{
                    .sub_module_id = 0,
                    .attrs = .{ .attrs = se_attrs_list },
                    .skills = se_skills,
                });
            } else {
                se_mod_sub_mods.appendAssumeCapacity(.{
                    .sub_module_id = 0,
                    .attrs = .{ .attrs = .empty },
                    .skills = .empty,
                });
            }
        } else {
            se_mod_sub_mods.appendAssumeCapacity(.{
                .sub_module_id = 0,
                .attrs = .{ .attrs = .empty },
                .skills = .empty,
            });
        }

        if (old_max_hp > 0) {
            hero.hp = @enumFromInt(@as(u32, @intCast(
                (@as(u64, @intCast(current_hp)) *
                    @as(u64, @intCast(new_max_hp))) /
                    @as(u64, @intCast(old_max_hp)),
            )));
        } else {
            hero.hp = @enumFromInt(new_max_hp);
        }

        hero_modules.appendAssumeCapacity(.{
            .module_type = @intFromEnum(pb.HeroAttrModuleType.HAMT_SOULESSENCE),
            .sub_modules = se_mod_sub_mods,
        });

        heroes_attrs.appendAssumeCapacity(.{
            .hero_guid = changed_hero.hero_guid,
            .hero_conf_id = hero_uuid.config_id,
            .type = @intFromEnum(pb.FightObjType.FO_Hero),
            .modules = hero_modules,
        });
    }

    if (heroes_attrs.items.len > 0) {
        try txn.any.send(.CSProtoHeroAttrInfoSync, .{
            .heros = heroes_attrs,
        });
    }

    try txn.any.services.battle.reset(txn.any.gpa, player_store);
    try txn.any.send(
        .CSProtoObjBattleInfoSync,
        try encoding.packObjBattleInfoSync(txn.any.arena, &txn.any.services.battle, 0),
    );

    //

    store.player.saveSoulEssenceTable(txn.any.io, player_store) catch |err| {
        log.warn("failed to save soul_essence table: {t}", .{err});
    };

    store.player.saveHeroTable(txn.any.io, player_store) catch |err| {
        log.warn("failed to save hero table: {t}", .{err});
    };

    try txn.respond(.{});
}

const PlayerStore = logic.PlayerStore;
const big_world = logic.big_world;

const Transaction = messaging.Transaction;

const pb = proto.pb;

const messaging = @import("../messaging.zig");
const encoding = @import("../encoding.zig");
const tables = @import("../tables.zig");
const logic = @import("../logic.zig");
const store = @import("../store.zig");

const proto = @import("proto");

const std = @import("std");
