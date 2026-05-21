pub const ItemMap = std.array_hash_map.Auto(ID, Item);
pub const RouletteMap = std.EnumMap(RouletteIndex, ID);

item_map: ItemMap,
roulette_map: RouletteMap,

pub const init: PetData = .{
    .item_map = .empty,
    .roulette_map = .init(.{}),
};

pub fn deinit(self: *PetData, gpa: std.mem.Allocator) void {
    self.item_map.deinit(gpa);
}

pub fn getPetRouletteIndex(
    self: *const PetData,
    pet_id: ID,
) ?RouletteIndex {
    inline for (std.enums.values(RouletteIndex)) |slot| {
        if (self.roulette_map.get(slot) == pet_id) {
            return slot;
        }
    }

    return null;
}

// TODO
pub const ID = packed struct(u64) {
    config_id: u32,
    serial: u32 = 0,
};

pub const Item = struct {
    name: Name,
    box: Box,
    lv: Level,
    exp: u32,
    rank: Rank,
    grade: Grade,

    hero_ref: HeroRef,

    pub fn init(config_id: u24) Item {
        return .{
            .name = .constant(""),
            .hero_ref = .none,
            .box = .{
                .index = .min,
                .slot = .min,
            },
            .lv = .min,
            .exp = 0,
            .rank = @enumFromInt(tables.pet_rank.getRankIndex(config_id) orelse 1),
            .grade = Grade.F,
        };
    }

    pub fn initMax(config_id: u24) Item {
        return .{
            .name = .constant(""),
            .hero_ref = .none,
            .box = .{
                .index = .min,
                .slot = .min,
            },
            .lv = .max,
            .exp = 0,
            .rank = @enumFromInt(tables.pet_rank.getRankIndex(config_id) orelse 1),
            .grade = Grade.SSS,
        };
    }
};

pub const Name = LimitedString(30);

pub const Box = struct {
    index: Index,
    slot: Slot,

    pub const Index = enum(std.math.IntFittingRange(0, tables.game.pet_box_num)) {
        min = 1,
        max = tables.game.pet_box_num,
        _,
    };

    pub const Slot = enum(std.math.IntFittingRange(0, tables.game.pet_box_limit)) {
        min = 1,
        max = tables.game.pet_box_limit,
        _,
    };

    pub fn toInt(self: Box) u32 {
        return @as(u32, @intFromEnum(self.index)) * 100 + @intFromEnum(self.slot);
    }

    pub fn fromInt(box_id: u32) Box {
        return .{
            .index = @enumFromInt(@as(u32, @intCast(box_id / 100))),
            .slot = @enumFromInt(@as(u32, @intCast(box_id % 100))),
        };
    }
};

pub const Level = tables.pet_level.Level;
pub const Grade = tables.pet_grade.Grade;
pub const Rank = tables.pet_rank.Rank;
pub const HeroRef = logic.PlayerStore.Hero.Ref;

pub const RouletteIndex = enum(u8) {
    slot1,
    slot2,
    slot3,
    slot4,
    slot5,
    slot6,
    slot7,
    slot8,
};

const LimitedString = common.mem.LimitedString;

const logic = @import("../../logic.zig");
const tables = @import("../../tables.zig");

const common = @import("common");
const proto = @import("proto");

const std = @import("std");

const PetData = @This();
