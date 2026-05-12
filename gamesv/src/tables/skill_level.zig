pub const list: []const Entry = @import("tables/skill_level");

pub fn getMaxLevel(skill_id: u32) u32 {
    var level: u32 = 1;

    for (list) |entry| {
        if (entry.skill_id == skill_id and level < entry.level) {
            level = entry.level;
        }
    }

    return level;
}

pub fn getByIdAndLevel(skill_id: u32, level: u32) ?Entry {
    for (list) |entry| {
        if (entry.skill_id == skill_id and entry.level == level) {
            return entry;
        }
    }

    return null;
}

pub const Entry = struct {
    id: u32,
    skill_id: u32,
    level: u32,
    can_up: u1,
    gold: u32,
    item: []const []const u32,
    hero_level: u32,
    hero_rank: u32,
    sub_skill_id: u32,
    cool_down: u32,
    sp_cost: u32,
    skill_describe: LangString,
    skill_describe_detail: LangString,
    name: []const LangString,
    value: []const LangString,
    skill_special_desc: LangString,
};

const LangString = tables.LangString;

const tables = @import("../tables.zig");

const std = @import("std");
