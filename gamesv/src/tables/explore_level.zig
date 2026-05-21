pub const list: []const Entry = @import("tables/explore_level");

const sorted_array = blk: {
    @setEvalBranchQuota(100_000);

    var tmp: [list.len]Entry = undefined;
    for (list, 0..) |e, i| tmp[i] = e;

    std.mem.sort(Entry, tmp[0..], {}, struct {
        fn byLvAndRegion(_: void, a: Entry, b: Entry) bool {
            if (a.regionid != b.regionid) return a.regionid < b.regionid;

            return a.lv < b.lv;
        }
    }.byLvAndRegion);

    break :blk tmp;
};
pub const sorted_list: []const Entry = sorted_array[0..];

const grouped_array = blk: {
    @setEvalBranchQuota(100_000);

    var groups: [list.len]Group = undefined;
    var count: usize = 0;

    var i: usize = 0;
    while (i < sorted_list.len) : (count += 1) {
        const region_id = sorted_list[i].regionid;
        const start = i;

        i += 1;
        while (i < sorted_list.len and sorted_list[i].regionid == region_id) : (i += 1) {}

        groups[count] = .{
            .region_id = region_id,
            .start = start,
            .len = i - start,
        };
    }

    break :blk groups;
};
pub const grouped: []const Group = grouped_array[0..];

pub fn getById(id: u32) ?Entry {
    for (list) |e| if (e.id == id) return e;
    return null;
}

pub fn getGroupByRegionId(region_id: u8) ?Group {
    for (grouped) |e| if (e.region_id == region_id) return e;
    return null;
}

pub fn getMaxLevelOfRegion(region_id: u32) ?u32 {
    if (getGroupByRegionId(region_id)) |group| {
        if (group.max()) |max| {
            return max.lv;
        }
    }

    return null;
}

pub fn getMinLevelOfRegion(region_id: u32) ?u32 {
    if (getGroupByRegionId(region_id)) |group| {
        if (group.min()) |min| {
            return min.lv;
        }
    }

    return null;
}

pub const Entry = struct {
    id: u32,
    regionid: u32,
    lv: u32,
    explore_level: []const u8,
    exp: u32,
    reward: []const [3]u32,
    if_fly: u1,
};

pub const Group = struct {
    region_id: u8,
    start: usize,
    len: usize,

    pub fn entries(self: @This()) []const Entry {
        return sorted_list[self.start .. self.start + self.len];
    }

    pub fn min(self: @This()) ?Entry {
        if (self.len == 0) return null;
        return sorted_list[self.start];
    }

    pub fn max(self: @This()) ?Entry {
        if (self.len == 0) return null;
        return sorted_list[self.start + self.len - 1];
    }
};

const LangString = tables.LangString;
const tables = @import("../tables.zig");

const std = @import("std");
