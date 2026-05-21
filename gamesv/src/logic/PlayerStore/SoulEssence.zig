pub const ItemMap = std.array_hash_map.Auto(u32, Item);

item_map: ItemMap,

pub const init: SoulEssenceData = .{
    .item_map = .empty,
};

pub fn deinit(self: *SoulEssenceData, gpa: std.mem.Allocator) void {
    self.item_map.deinit(gpa);
}

pub const Item = struct {
    hero_id: u64,
    lv: u32,
    exp: u32,
    stars: Stars,
    rank: Rank,

    pub const init: Item = .{
        .hero_id = 0,
        .lv = 1,
        .exp = 0,
        .stars = .min,
        .rank = .min,
    };

    pub fn initMax(id: u32) Item {
        const max_rank = tables.soulessence_rank.getMaxRank(id).?;

        return .{
            .hero_id = 0,
            .lv = tables.soulessence_rank.getByIdAndRank(id, max_rank).?.rank_level_limit,
            .exp = 0,
            .stars = @enumFromInt(
                tables.skill_level.getMaxLevel(
                    tables.soulessence.getById(id).?.reishi_skill,
                ),
            ),
            .rank = @enumFromInt(max_rank),
        };
    }
};

pub const Stars = enum(u8) {
    min = 1,
    max = blk: {
        @setEvalBranchQuota(1_000_000);

        var stars: u32 = 1;

        for (tables.soulessence.list) |entry| {
            const level = tables.skill_level.getMaxLevel(entry.reishi_skill);

            if (level > stars) {
                stars = level;
            }
        }

        break :blk stars;
    },
    _,
};

pub const Rank = tables.soulessence_rank.Rank;

const tables = @import("../../tables.zig");

const std = @import("std");

const SoulEssenceData = @This();
