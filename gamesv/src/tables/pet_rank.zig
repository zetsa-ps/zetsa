pub const list: []const Entry = @import("tables/pet_rank");

const pet_rank_map = gen: {
    @setEvalBranchQuota(100_000);

    var is_child: [list.len]bool = .{false} ** list.len;
    var tmp: [list.len]packed struct(u32) {
        pet_id: u24,
        rank: u8,
    } = undefined;
    var filled: usize = 0;

    for (list) |e| {
        if (e.next_pet_id == 0) continue;

        var found = false;
        for (list, 0..) |x, i| {
            if (x.pet_id == e.next_pet_id) {
                is_child[i] = true;
                found = true;
                break;
            }
        }

        if (!found) @compileError("pet_rank_map: next_pet_id missing from list");
    }

    for (list, 0..) |start, start_idx| {
        if (is_child[start_idx]) continue;

        var current = start.pet_id;
        var rank: u8 = 1;

        while (true) {
            if (filled >= tmp.len) @compileError("pet_rank_map overflow");

            tmp[filled] = .{
                .pet_id = @intCast(current),
                .rank = rank,
            };
            filled += 1;

            var next: u32 = 0;
            var found = false;
            for (list) |e| {
                if (e.pet_id == current) {
                    next = e.next_pet_id;
                    found = true;
                    break;
                }
            }

            if (!found) @compileError("pet_rank_map: pet_id missing from list");
            if (next == 0) break;

            current = next;
            rank += 1;
        }
    }

    if (filled != list.len) @compileError("pet_rank_map: some entries were not assigned");

    break :gen tmp;
};

pub fn getById(pet_id: u32) ?Entry {
    for (list) |rank| if (rank.pet_id == pet_id) return rank;

    return null;
}

pub fn getPreviousRank(pet_id: u32) ?Entry {
    for (list) |rank| if (rank.next_pet_id == pet_id) return rank.pet_id;

    return null;
}

pub fn getNextRank(pet_id: u32) ?Entry {
    if (getById(pet_id)) |rank| {
        return getById(rank.next_pet_id);
    }

    return null;
}

pub fn getRankIndex(pet_id: u24) ?u8 {
    for (pet_rank_map) |e| if (e.pet_id == pet_id) return e.rank;

    return null;
}

pub const Rank = enum(u8) {
    min = 1,
    max = blk: {
        var rank: u8 = 1;

        for (pet_rank_map) |e| {
            if (e.rank > rank) {
                rank = e.rank;
            }
        }

        break :blk rank;
    },
    _,
};

pub const Entry = struct {
    pet_id: u24,
    pet_group: u32,
    pet_group_name: LangString,
    next_pet_id: u24,
    rank_breakthrough_item: []const [3]u32,
    rank_breakthrough_coin: u32,
    level_need: u32,
    evo_perform: []const u8,
    loop_frame: u32,
    evolution_pre: []const u8,
    evolution_after_start: []const u8,
    pet1_scale: u32,
    pet1_rotation: []const f32,
    pet2_scale: u32,
    pet2_rotation: []const f32,
    color1: []const u8,
};

const LangString = tables.LangString;
const tables = @import("../tables.zig");
