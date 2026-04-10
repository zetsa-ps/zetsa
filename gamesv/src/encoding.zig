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

const PlayerStore = logic.PlayerStore;

const logic = @import("logic.zig");

const pb = @import("proto").pb;
const std = @import("std");
