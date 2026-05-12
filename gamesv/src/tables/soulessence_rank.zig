pub const list: []const Entry = @import("tables/soulessence_rank");

pub const sorted_entries: []const Entry = &sorted_array;
pub const groups: []const Group = &groups_array;

pub fn getChildren(related_id: u32) ?[]const Entry {
    const g = getGroup(related_id) orelse return null;

    return sorted_entries[g.start..][0..g.len];
}

pub fn getByIdAndRank(related_id: u32, rank: u32) ?Entry {
    const g = getGroup(related_id) orelse return null;

    if (rank == 0 or rank > g.len) return null;

    return sorted_entries[g.start + rank - 1];
}

pub fn getMaxRank(related_id: u32) ?u32 {
    const g = getGroup(related_id) orelse return null;
    const last = sorted_entries[g.start + g.len - 1];

    return last.rank;
}

pub const Rank = enum(u8) {
    min = 1,
    max = blk: {
        var rank: u32 = 1;

        for (list) |entry| {
            if (entry.rank > rank) {
                rank = entry.rank;
            }
        }

        break :blk rank;
    },
    _,
};

pub const Entry = struct {
    id: u32,
    related_id: u32,
    rank: u32,
    rank_up_item: []const []const u32,
    rank_up_coin: u32,
    condition: []const u32,
    rank_level_limit: u32,
    rank_up_attribute: []const MapEntry(u32, u32),
    rank_up_attribute_all: []const MapEntry(u32, u32),
};

pub const Group = struct {
    related_id: u32,
    start: u32,
    len: u32,
};

const sorted_array = blk: {
    @setEvalBranchQuota(100_000);

    var arr: [list.len]Entry = undefined;
    @memcpy(&arr, list);

    std.sort.insertion(Entry, &arr, {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            if (a.related_id != b.related_id) return a.related_id < b.related_id;
            return a.rank < b.rank;
        }
    }.lessThan);

    break :blk arr;
};

const group_count = blk: {
    var count: usize = 0;
    var i: usize = 0;

    while (i < sorted_entries.len) {
        const id = sorted_entries[i].related_id;
        i += 1;

        while (i < sorted_entries.len and sorted_entries[i].related_id == id) : (i += 1) {}

        count += 1;
    }

    break :blk count;
};

const groups_array = blk: {
    var gs: [group_count]Group = undefined;
    var g_idx: usize = 0;
    var i: usize = 0;

    while (i < sorted_entries.len) {
        const id = sorted_entries[i].related_id;
        const start = i;
        i += 1;

        while (i < sorted_entries.len and sorted_entries[i].related_id == id) : (i += 1) {}

        const slice = sorted_entries[start..i];

        gs[g_idx] = .{
            .related_id = id,
            .start = @intCast(start),
            .len = @intCast(slice.len),
        };

        g_idx += 1;
    }

    break :blk gs;
};

fn getGroup(related_id: u32) ?Group {
    const idx = std.sort.binarySearch(
        Group,
        groups,
        related_id,
        struct {
            fn predicate(id: u32, g: Group) std.math.Order {
                return std.math.order(id, g.related_id);
            }
        }.predicate,
    );

    if (idx) |i| return groups[i] else return null;
}

const MapEntry = @import("../tables.zig").MapEntry;

const std = @import("std");
