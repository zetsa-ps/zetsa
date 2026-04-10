name: Name,
sex: Sex,
level: Level,
gold: Gold,
diamond: Diamond,
sign: Sign,

pub const init: BasicInfo = .{
    .name = .constant("ReversedRooms"),
    .sex = .female,
    .level = .max,
    .gold = .zero,
    .diamond = .zero,
    .sign = .constant("discord.gg/reversedrooms"),
};

pub const Name = LimitedString(15);
pub const Sign = LimitedString(255);

pub const Sex = enum {
    female,
    male,

    pub fn toPlayerSexType(sex: Sex) u32 {
        return @intCast(@intFromEnum(@as(proto.pb.PlayerSexType, switch (sex) {
            .female => .PST_FEMALE,
            .male => .PST_MALE,
        })));
    }
};

pub const Level = tables.player_level.Level;

pub const Gold = enum(u31) {
    zero = 0,
    _,

    pub fn toInt(gold: Gold) i32 {
        return @intFromEnum(gold);
    }

    pub fn fromInt(int: i32) Gold {
        return if (int < 0) .zero else @enumFromInt(@as(u31, @intCast(int)));
    }
};

pub const Diamond = enum(u31) {
    zero = 0,
    _,

    pub fn toInt(diamond: Diamond) i32 {
        return @intFromEnum(diamond);
    }

    pub fn fromInt(int: i32) Diamond {
        return if (int < 0) .zero else @enumFromInt(@as(u31, @intCast(int)));
    }
};

const LimitedString = common.mem.LimitedString;

const tables = @import("../../tables.zig");
const common = @import("common");
const proto = @import("proto");
const std = @import("std");
const BasicInfo = @This();
