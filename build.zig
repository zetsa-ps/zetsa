pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zetsa_proto_gen = b.addExecutable(.{
        .name = "zetsa_proto_gen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("proto/gen/src/main.zig"),
            .optimize = optimize,
            .target = b.graph.host,
        }),
    });

    const compile_proto = b.addRunArtifact(zetsa_proto_gen);
    compile_proto.expectExitCode(0);
    const pb_generated = compile_proto.captureStdOut(.{ .basename = "azur_generated.zig" });

    for (proto_sources) |source| {
        compile_proto.addFileArg(b.path(source));
    }

    const proto = b.createModule(.{ .root_source_file = b.path("proto/src/root.zig") });
    proto.addAnonymousImport("azur_generated", .{ .root_source_file = pb_generated });

    const common = b.createModule(.{ .root_source_file = b.path("common/src/root.zig") });

    const cdnsv = b.addExecutable(.{
        .name = "zetsa-cdnsv",
        .root_module = b.createModule(.{
            .root_source_file = b.path("cdnsv/src/main.zig"),
            .imports = &.{.{ .name = "common", .module = common }},
            .target = target,
            .optimize = optimize,
        }),
    });

    for (cdnsv_assets) |asset| cdnsv.root_module.addAnonymousImport(
        asset.name,
        .{ .root_source_file = b.path(asset.path) },
    );

    const gamesv = b.addExecutable(.{
        .name = "zetsa-gamesv",
        .root_module = b.createModule(.{
            .root_source_file = b.path("gamesv/src/main.zig"),
            .imports = &.{
                .{ .name = "common", .module = common },
                .{ .name = "proto", .module = proto },
            },
            .target = target,
            .optimize = optimize,
        }),
    });

    for (gamesv_assets) |asset| gamesv.root_module.addAnonymousImport(
        asset.name,
        .{ .root_source_file = b.path(asset.path) },
    );

    b.step(
        "run-cdnsv",
        "Run the cdn server",
    ).dependOn(&b.addRunArtifact(cdnsv).step);

    b.step(
        "run-gamesv",
        "Run the game server",
    ).dependOn(&b.addRunArtifact(gamesv).step);

    b.installArtifact(cdnsv);
    b.installArtifact(gamesv);
}

const gamesv_assets: []const ComptimeAsset = &.{
    .asset("config", "gamesv/config.zon"),
    .asset("msg_gen_code", "assets/protocol/msg_gen_code.zon"),
    .asset("tables/game", "assets/tables/game.zon"),
    .asset("tables/hero", "assets/tables/hero.zon"),
    .asset("tables/hero_level", "assets/tables/hero_level.zon"),
    .asset("tables/player_level", "assets/tables/player_level.zon"),
    .asset("tables/skill_level", "assets/tables/skill_level.zon"),
    .asset("tables/soulessence", "assets/tables/soulessence.zon"),
    .asset("tables/soulessence_rank", "assets/tables/soulessence_rank.zon"),
    .asset("tables/soulessence_value", "assets/tables/soulessence_value.zon"),
    .asset("tables/template_hero", "assets/tables/template_hero.zon"),
    .asset("tables/template_value", "assets/tables/template_value.zon"),
    .asset("tables/unit_property", "assets/tables/unit_property.zon"),
    .asset("tables/world_area", "assets/tables/world_area.zon"),
    .asset("tables/world_borthpos", "assets/tables/world_borthpos.zon"),
    .asset("tables/world_city", "assets/tables/world_city.zon"),
    .asset("tables/world_enemy_group", "assets/tables/world_enemy_group.zon"),
    .asset("tables/enemy", "assets/tables/enemy.zon"),
    .asset("tables/enemy_pack", "assets/tables/enemy_pack.zon"),
    .asset("tables/world_difficulty_obj_level", "assets/tables/world_difficulty_obj_level.zon"),
};

const cdnsv_assets: []const ComptimeAsset = &.{
    .asset("config", "cdnsv/config.zon"),
    .asset("hashes", "assets/cdn/hashes.zon"),
};

const ComptimeAsset = struct {
    name: []const u8,
    path: []const u8,

    pub fn asset(name: []const u8, path: []const u8) ComptimeAsset {
        return .{ .name = name, .path = path };
    }
};

const proto_sources: []const []const u8 = &.{
    "proto/pb/Act.proto",
    "proto/pb/Activity.proto",
    "proto/pb/Battle.proto",
    "proto/pb/CSCore.proto",
    "proto/pb/Campaign.proto",
    "proto/pb/CommonMsg.proto",
    "proto/pb/Core.proto",
    "proto/pb/ExOptions.proto",
    "proto/pb/GMMsg.proto",
    "proto/pb/Home.proto",
    "proto/pb/KiboDuel.proto",
    "proto/pb/NestCoop.proto",
    "proto/pb/Pet.proto",
    "proto/pb/RogueLike.proto",
    "proto/pb/Task.proto",
    "proto/pb/WorldMap.proto",
    "proto/pb/conf.proto",
};

const Build = std.Build;
const std = @import("std");
