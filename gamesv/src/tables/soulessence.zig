pub const list: []const Entry = @import("tables/soulessence");

pub fn getById(id: u32) ?Entry {
    for (list) |e| if (e.id == id) return e;
    return null;
}

pub const Entry = struct {
    id: u32,
    name: LangString,
    rarity: u32,
    valid_profession: []const u32,
    attribute: u32,
    reishi_skill: u32,
    reishi_exp: u32,
    icon: []const []const u8,
    resource_path: []const u8,
    cg_path: []const u8,
    ui_path: []const u8,
    desc: LangString,
    video: []const u8,
    video_sound: []const u8,
    animation_sound: []const u8,
    task: u32,
    story: u32,
    story_lock: []const []const u32,
    is_valid: u1,
};

const LangString = tables.LangString;

const tables = @import("../tables.zig");

const std = @import("std");
