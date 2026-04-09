const config: @import("../../Config.zig") = @import("config");

comptime {
    if (config.default_characters[0] == null)
        @compileError("config: first character must not be null.");
}

pub const GroupMap = EnumMap(Group.Type, Group);

group_map: GroupMap,

pub const init: FormationStore = .{
    .group_map = .init(.{
        .world = .{
            .cur_formation = 0,
            .formation_names = @splat(.constant("ReversedRooms")),
            .formation_heros = .{
                .{
                    if (config.default_characters[0]) |id| .fromHeroId(id) else .empty,
                    if (config.default_characters[1]) |id| .fromHeroId(id) else .empty,
                    if (config.default_characters[2]) |id| .fromHeroId(id) else .empty,
                },
                @splat(.empty),
                @splat(.empty),
                @splat(.empty),
                @splat(.empty),
            },
            .formation_controls = .{
                .fromHeroId(config.default_characters[0].?),
                .empty,
                .empty,
                .empty,
                .empty,
            },
        },
    }),
};

pub const Group = struct {
    cur_formation: u8,
    formation_names: [Formation.count]Formation.Name,
    formation_heros: [Formation.count]Formation.Heros,
    formation_controls: [Formation.count]Formation.HeroPos,

    pub const init: Group = .{
        .formations = @splat(.empty),
    };

    pub const Type = enum(u8) {
        world,
        rogue,
        tower,

        pub fn toGroupManagerType(t: Type) u32 {
            return @intCast(@intFromEnum(@as(proto.pb.GroupManagerType, switch (t) {
                .world => .GMT_WORLD,
                .rogue => .GMT_ROGUE,
                .tower => .GMT_TOWER,
            })));
        }
    };
};

pub const Formation = struct {
    pub const count: usize = 5;

    pub const Heros = [HeroPos.count]HeroPos;
    pub const Name = LimitedString(15);

    pub const HeroPos = enum(u24) {
        pub const count: usize = 3;

        empty = 0,
        _,

        pub fn fromHeroId(id: tables.hero.Id) HeroPos {
            return @enumFromInt(@intFromEnum(id));
        }

        pub fn toHeroId(pos: HeroPos) ?tables.hero.Id {
            return if (pos == .empty) null else @enumFromInt(@intFromEnum(pos));
        }

        pub const Index = enum(u8) {
            @"1" = 0,
            @"2" = 1,
            @"3" = 2,
        };
    };
};

const EnumMap = std.enums.EnumMap;
const LimitedString = common.mem.LimitedString;

const tables = @import("../../tables.zig");
const common = @import("common");
const proto = @import("proto");
const std = @import("std");
const FormationStore = @This();
