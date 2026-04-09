pub fn @"/version/client/patchV1"(io: Io, options: Options, writer: *Io.Writer) !void {
    var response: http.Response = .init(writer);
    const timestamp: Io.Timestamp = .now(io, .real);

    const addr_bytes = options.gamesv_address.bytes;
    var addr_buf: [15]u8 = undefined;
    const addr = std.fmt.bufPrint(
        &addr_buf,
        "{d}.{d}.{d}.{d}",
        .{ addr_bytes[0], addr_bytes[1], addr_bytes[2], addr_bytes[3] },
    ) catch unreachable;

    const server_info_slot = .{ .serverInfo = &.{.{
        .name = "zetsa",
        .type = 4,
        .addr = addr,
        .port = options.gamesv_address.port,
        .state = 0,
        .version = "",
        .tag = "1337",
        .tls = false,
        .desc = "1337-2026-04-03 02:30:07.303357803 +0000 UTC m=+331885.404656489\n",
        .timestamp = timestamp.toSeconds(),
        .pay = "",
        .id = 1337,
        .zoneId = 22,
    }} };

    try response.respondAny(.OK, .{
        .api = "PatchV1",
        .code = 0,
        .message = "OK",
        .timestamp = timestamp.toSeconds(),
        .data = .{
            .status = 4,
            .pkgUrl = "http://0.0.0.0/",
            .zoneId = 22,
            .buildPipe = 1,
            .jobName = "CBT2-Client-PC-Release-V0.2.0",
            .version = "0.2.0.48",
            .waterMark = .{ .accessKeyId = "", .accessKeySecret = "", .url = "" },
            .serverSlots = .{
                .gbtestServer = server_info_slot,
                .testServer = server_info_slot,
                .reviewServer = server_info_slot,
                .releaseServer = server_info_slot,
            },
            .hotSlots = .{
                .testHot = options.hot_revision,
                .gbtestHot = options.hot_revision,
                .reviewHot = options.hot_revision,
                .releaseHot = options.hot_revision,
            },
            .returnAll = 0,
            .isWhite = 0,
            .isForceHot = false,
            .releaseHotHis = &.{},
        },
    });
}

pub fn @"/version/client/getCdnV1"(io: Io, options: Options, writer: *Io.Writer) !void {
    _ = options;
    var response: http.Response = .init(writer);

    const timestamp: Io.Timestamp = .now(io, .real);

    try response.respondAny(.OK, .{
        .api = "GetCdnV1",
        .code = 0,
        .message = "OK",
        .timestamp = timestamp.toSeconds(),
        .data = .{ .cdn = "http://127.0.0.1:20001/" },
    });
}

pub fn @"/version/client/cdntoken"(io: Io, options: Options, writer: *Io.Writer) !void {
    _ = options;
    var response: http.Response = .init(writer);

    const timestamp: Io.Timestamp = .now(io, .real);

    try response.respondAny(.OK, .{
        .api = "CdnToken",
        .code = 0,
        .message = "OK",
        .timestamp = timestamp.toSeconds(),
        .data = .{
            .tc = .{
                .tmpSecretID = "",
                .tmpSecretKey = "",
                .sessionToken = "",
                .expiredTime = std.math.maxInt(u32),
                .url = "",
                .type = 0,
                .appid = "",
                .region = "",
                .bucket = "",
            },
        },
    });
}

pub fn @"/version/client/announceV1"(io: Io, options: Options, writer: *Io.Writer) !void {
    _ = options;
    var response: http.Response = .init(writer);

    const timestamp: Io.Timestamp = .now(io, .real);

    try response.respondAny(.OK, .{
        .api = "AnnounceV1",
        .code = 0,
        .message = "OK",
        .timestamp = timestamp.toSeconds(),
        .data = .{
            .infos = .{},
            .scrolling = .{},
            .gateway = .{
                .meta = .{},
                .name = "zetsa",
                .orderId = 0,
                .tabId = 0,
                .endTime = 2_000_000_000,
                .id = 0,
                .type = 0,
                .jumpId = "",
                .hide = true,
                .showPosition = 0,
                .publishTime = 0,
            },
        },
    });
}

const Io = std.Io;

const Options = @import("../Options.zig");
const http = @import("../http.zig");
const std = @import("std");
