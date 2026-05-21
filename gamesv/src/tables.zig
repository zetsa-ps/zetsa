pub fn MapEntry(comptime Key: type, comptime Value: type) type {
    return struct {
        key: Key,
        value: Value,
    };
}

pub const LangString = struct {
    group: []const u8,
    lang_key: u64,
};

pub const game = @import("tables/game");

pub const enemy = @import("tables/enemy.zig");
pub const enemy_pack = @import("tables/enemy_pack.zig");
pub const explore_level = @import("tables/explore_level.zig");
pub const hero = @import("tables/hero.zig");
pub const hero_level = @import("tables/hero_level.zig");
pub const mount = @import("tables/mount.zig");
pub const mount_saddle = @import("tables/mount_saddle.zig");
pub const pet = @import("tables/pet.zig");
pub const pet_grade = @import("tables/pet_grade.zig");
pub const pet_learningenum = @import("tables/pet_learningenum.zig");
pub const pet_learningtalent = @import("tables/pet_learningtalent.zig");
pub const pet_level = @import("tables/pet_level.zig");
pub const pet_rank = @import("tables/pet_rank.zig");
pub const player_level = @import("tables/player_level.zig");
pub const skill_level = @import("tables/skill_level.zig");
pub const soulessence = @import("tables/soulessence.zig");
pub const soulessence_rank = @import("tables/soulessence_rank.zig");
pub const soulessence_value = @import("tables/soulessence_value.zig");
pub const template_hero = @import("tables/template_hero.zig");
pub const template_value = @import("tables/template_value.zig");
pub const unit_property = @import("tables/unit_property.zig");
pub const world_area = @import("tables/world_area.zig");
pub const world_borthpos = @import("tables/world_borthpos.zig");
pub const world_city = @import("tables/world_city.zig");
pub const world_difficulty_obj_level = @import("tables/world_difficulty_obj_level.zig");
pub const world_enemy_group = @import("tables/world_enemy_group.zig");
