pub const list: []const Entry = @import("tables/pet_learningtalent");

const sorted_array = blk: {
    @setEvalBranchQuota(100_000);

    var tmp: [list.len]Entry = undefined;
    for (list, 0..) |e, i| tmp[i] = e;

    std.mem.sort(Entry, tmp[0..], {}, struct {
        fn byEnumThenType(_: void, a: Entry, b: Entry) bool {
            if (a.enum_id != b.enum_id) return a.enum_id < b.enum_id;
            return a.type < b.type;
        }
    }.byEnumThenType);
    break :blk tmp;
};
pub const sorted_list: []const Entry = sorted_array[0..];

const grouped_array = blk: {
    @setEvalBranchQuota(100_000);

    var groups: [list.len]TalentGroup = undefined;
    var count: usize = 0;

    var i: usize = 0;
    while (i < sorted_list.len) {
        const enum_id = sorted_list[i].enum_id;
        const start = i;

        i += 1;
        while (i < sorted_list.len and sorted_list[i].enum_id == enum_id) : (i += 1) {}

        groups[count] = .{
            .enum_id = enum_id,
            .start = start,
            .len = i - start,
        };
        count += 1;
    }

    break :blk groups;
};
pub const grouped: []const TalentGroup = grouped_array[0..];

pub fn getById(id: u32) ?Entry {
    for (list) |e| if (e.id == id) return e;
    return null;
}

pub fn getByEnumId(enum_id: u8) ?Entry {
    for (list) |e| if (e.enum_id == enum_id) return e;
    return null;
}

pub fn getGroupByEnumId(enum_id: u8) ?TalentGroup {
    for (grouped) |e| if (e.enum_id == enum_id) return e;
    return null;
}

pub fn getMaxLevelValue(enum_id: u8) ?u32 {
    if (getGroupByEnumId(enum_id)) |group| {
        if (group.max()) |max| {
            return max.range[1];
        }
    }

    return null;
}

pub fn getMinLevelValue(enum_id: u8) ?u32 {
    if (getGroupByEnumId(enum_id)) |group| {
        if (group.min()) |min| {
            return min.range[0];
        }
    }

    return null;
}

pub const Entry = struct {
    id: u32,
    level: []const u8,
    type: u8,
    enum_id: u8,
    range: [2]u32,
};

pub const TalentGroup = struct {
    enum_id: u8,
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
