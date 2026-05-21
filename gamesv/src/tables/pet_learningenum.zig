pub const list: []const Entry = @import("tables/pet_learningenum");
const sorted_array = blk: {
    var tmp: [list.len]Entry = undefined;
    for (list, 0..) |item, i| tmp[i] = item;

    std.mem.sort(Entry, tmp[0..], {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            return a.order < b.order;
        }
    }.lessThan);

    break :blk tmp;
};
pub const sorted_list: []const Entry = sorted_array[0..];

pub fn getById(id: u8) ?Entry {
    for (list) |e| if (e.id == id) return e;
    return null;
}

pub fn getByEnumId(enum_id: u8) ?Entry {
    for (list) |e| if (e.enum_num == enum_id) return e;
    return null;
}

pub fn getAllEnum(need_sort: bool) []const Entry {
    return if (need_sort) sorted_list else list;
}

pub const Entry = struct {
    id: u8,
    name: LangString,
    @"enum": []const u8,
    enum_num: u8,
    icon: []const u8,
    icon2: []const u8,
    order: u8,
    color: []const u8,
    new_icon: []const u8,
    light_icon: []const u8,
};

const LangString = tables.LangString;
const tables = @import("../tables.zig");

const std = @import("std");
