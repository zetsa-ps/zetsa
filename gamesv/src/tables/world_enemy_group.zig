pub const list: []const Entry = @import("tables/world_enemy_group");

pub fn getById(id: u32) ?Entry {
    for (list) |h| if (h.id == id) return h;
    return null;
}

pub const Entry = struct {
    id: u32,
    enemy_list: []const u32,
    enemy_ai: []const u32,
    world_fsm: []const u32,
    enemy_group_ai: u32,
    appear_condition: u32,
    display_count: u32,
    fill_display_type: u32,
    settle_type: u32,
    no_escape: u32,
    can_riding: u32,
    changeable_battle_radius: u32,
    enter_battle_range: u32,
    battle_radius: u32,
    battle_start_timeline: u32,
    battle_end_timeline: []const u8,
    battle_fsm_type: u32,
    time_limit: u32,
    world_property_list: []const u32,
    can_force_kill: bool,
    default_move_type_list: []const u32,
    group_type: u32,
    domain_range: u32,
    camp_type: u32,
    death_borthpos: u32,
    enemy_group_type: u32,
};
