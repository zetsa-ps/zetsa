pub fn packGroupManagers(
    player_store: *PlayerStore,
    group_mgrs: *std.ArrayList(pb.GroupManager),
    group_mgrs_buf: []pb.GroupManager,
    groups_buf: []pb.Group,
    group_heros_buf: []pb.GroupHeroPos,
) void {
    const formations_per_group = PlayerStore.Lineup.Formation.count;
    const heros_per_formation = PlayerStore.Lineup.Formation.HeroPos.count;

    group_mgrs.* = .initBuffer(group_mgrs_buf);

    var group_iterator = player_store.lineup.group_map.iterator();
    var group_i: usize = 0;

    while (group_iterator.next()) |entry| : (group_i += 1) {
        const formation_group = entry.value;

        var group_manager: pb.GroupManager = .{
            .groups = .initBuffer(groups_buf[group_i * formations_per_group ..][0..formations_per_group]),
            .type = entry.key.toGroupManagerType(),
            .cur_group = formation_group.cur_formation + 1,
            .last_group = formation_group.cur_formation + 1,
            .src = .GMS_DEAULFT,
        };

        for (
            &formation_group.formation_names,
            formation_group.formation_heros,
            formation_group.formation_controls,
            0..,
        ) |*name, heros, control, i| {
            var group: pb.Group = .{
                .id = @intCast(i + 1),
                .control = if (control.toHeroId()) |id|
                    logic.Uuid.hero(player_store.id, id).toInt()
                else
                    null,
                .group_name = name.view(),
                .heros = .initBuffer(group_heros_buf[((group_i * formations_per_group) + i) * heros_per_formation ..][0..heros_per_formation]),
            };

            for (heros) |hero_pos| {
                const hero_id = hero_pos.toHeroId() orelse {
                    group.heros.appendAssumeCapacity(.{ .hero_id = null });
                    continue;
                };

                const uuid: logic.Uuid = .hero(player_store.id, hero_id);
                group.heros.appendAssumeCapacity(.{ .hero_id = uuid.toInt() });
            }

            group_manager.groups.appendAssumeCapacity(group);
        }

        group_mgrs.appendAssumeCapacity(group_manager);
    }
}

// Assumes `out` has capacity of `Attributes.len`.
pub fn packFightAttrs(
    attributes: *logic.big_world.Attributes,
    out: *std.ArrayList(pb.FightAttrOne),
) void {
    var it = attributes.iterator();

    while (it.next()) |entry| out.appendAssumeCapacity(.{
        .attr_id = @intFromEnum(entry.key),
        .attr_val = entry.value.*,
    });
}

pub fn packObjBattleInfoSync(
    arena: Allocator,
    battle: *logic.Services.Battle,
    reason: u32,
) Allocator.Error!pb.SCObjBattleInfoSync {
    var infos: std.ArrayList(pb.ObjBattleInfo) = try .initCapacity(arena, battle.modified_count);
    const slice = battle.objects.slice();

    const uuid_list = slice.items(.uuid);
    const hp_list = slice.items(.hp);
    const sp_list = slice.items(.sp);

    const modified = battle.modified();

    while (modified.next()) |index| {
        infos.appendAssumeCapacity(.{
            .uuid = uuid_list[index].toInt(),
            .hp = hp_list[index].toInt(),
            .sp = sp_list[index].toInt(),
            .alive_state = hp_list[index].aliveState().toAliveStateType(),
            .reason = reason,
        });
    }

    return .{ .infos = infos };
}

pub fn packPetInfo(
    arena: Allocator,
    pet_id: PlayerStore.Pet.ID,
    pet: PlayerStore.Pet.Item,
    roulette_index: ?PlayerStore.Pet.RouletteIndex,
) Allocator.Error!pb.PetbaseInfo {
    const pet_table_entry = tables.pet.getById(pet_id.config_id).?;

    var pet_info: pb.PetbaseInfo = .{
        .pet_name = pet.name.viewOrNull(),
        .guid = @bitCast(pet_id),
        .feature = 1,
        .comprehension = try .initCapacity(arena, tables.pet_learningenum.list.len),
        .inherent_skills = try .initCapacity(arena, pet_table_entry.fixed_skill_list.len + pet_table_entry.break_skill_list.len + pet_table_entry.kibo_b_propertyskill_list.len + pet_table_entry.kibo_f_propertyskill_list.len + pet_table_entry.f_propertyskill_list.len + pet_table_entry.b_propertyskill_list.len + 1),
        .lv = @intFromEnum(pet.lv),
        .config_id = pet_id.config_id,
        .rank = @intFromEnum(pet.rank),
        .hero_id = @intFromEnum(pet.hero_ref),
        .speed = if (tables.mount.getById(pet_id.config_id)) |mount| mount.fast_move_speed else null,
        .roulette_pos = if (roulette_index) |p| @intFromEnum(p) else null,
        .box_id = pet.box.toInt(),
        .grade = tables.pet_grade.getMaxScore(pet.grade),
        .type = @intFromEnum(pb.PetType.PT_NORMAL),
        .satiety_val = tables.game.pet_satiety_max_value,

        .exp = 0,
        .is_lock = true,
        .talent_id = .empty,
        .base_lv = 1,
        .favor_lv = 1,
        .favor_val = 0,
    };

    for (tables.pet_learningenum.list) |entry| {
        pet_info.comprehension.appendAssumeCapacity(.{
            .attr_id = entry.enum_num,
            .level = if (tables.pet_learningtalent.getByEnumId(entry.enum_num)) |e| e.type else 1,
            .cur_exp = 0,
            .value = @intCast(tables.pet_learningtalent.getMinLevelValue(entry.enum_num) orelse 0),
        });
    }

    for (pet_table_entry.fixed_skill_list) |entry| {
        pet_info.inherent_skills.appendAssumeCapacity(.{
            .skill_slot = entry.key,
            .skill_id = entry.value,
            .skill_lv = 1,
        });
    }

    for (pet_table_entry.break_skill_list) |entry| {
        pet_info.inherent_skills.appendAssumeCapacity(.{
            .skill_slot = entry.key,
            .skill_id = entry.value,
            .skill_lv = 1,
        });
    }

    for (pet_table_entry.kibo_b_propertyskill_list) |entry| {
        pet_info.inherent_skills.appendAssumeCapacity(.{
            .skill_slot = entry.key,
            .skill_id = entry.value,
            .skill_lv = 1,
        });
    }

    for (pet_table_entry.kibo_f_propertyskill_list) |entry| {
        pet_info.inherent_skills.appendAssumeCapacity(.{
            .skill_slot = entry.key,
            .skill_id = entry.value,
            .skill_lv = 1,
        });
    }

    for (pet_table_entry.f_propertyskill_list) |entry| {
        pet_info.inherent_skills.appendAssumeCapacity(.{
            .skill_slot = entry.key,
            .skill_id = entry.value,
            .skill_lv = 1,
        });
    }

    for (pet_table_entry.b_propertyskill_list) |entry| {
        pet_info.inherent_skills.appendAssumeCapacity(.{
            .skill_slot = entry.key,
            .skill_id = entry.value,
            .skill_lv = 1,
        });
    }

    return pet_info;
}

pub fn packHeroItemInfo(
    arena: Allocator,
    hero_uuid: logic.Uuid,
    hero: PlayerStore.Hero.Item,
) Allocator.Error!pb.HeroItemInfo {
    var system_skill_levels: std.ArrayList(u32) = try .initCapacity(arena, PlayerStore.Hero.SystemSkillLevel.count);

    for (hero.system_skill_levels) |level|
        system_skill_levels.appendAssumeCapacity(@intFromEnum(level));

    return .{
        .guid = hero_uuid.toInt(),
        .hero_lv = hero.lv.toInt(),
        .hero_exp = hero.exp,
        .hero_rank = hero.rank.toInt(),
        .system_skill_levels = system_skill_levels,
        .wguid = hero.soul_essence_id,
        .pet_id = hero.pet_id,
        .conf_id = hero_uuid.config_id,
        .type = PlayerStore.Hero.Type.byHeroId(@enumFromInt(hero_uuid.config_id)).toHeroType(),

        .hero_star = 0,
        .oguid = .empty,
        .waguid = null,
        .favorability_exp = 0,
        .favorability_lv = 1,
        .trail = false,
        .store_favor_rewards = .empty,
        .rune_ids = .empty,
        .trial_pet = null,
        .hero_rank_reward = null,
        .furnitures = .empty,
        .fight_favorability_exp = 0,
        .dorm_id = null,
        .daily_gift_num = null,
    };
}

const PlayerStore = logic.PlayerStore;
const Allocator = std.mem.Allocator;

const logic = @import("logic.zig");
const tables = @import("tables.zig");

const pb = @import("proto").pb;
const std = @import("std");
