// See LICENSE file for copyright and license details.
//
// Zetsa cdnsv is implemented as a HTTP/1.1 server.
// It's configured through the comptime configuration,
// see `config.zon`. Some of the options can be overridden
// through cli arguments.
//
// The comptime configuration includes the sizes for per-client
// on-stack buffer sizes, network timeouts, data manifest hashes.
// See also: assets/cdn/hashes.zon.
//
// The request handlers are defined under the `routes` directory.
//
// To understand everything else, start reading app::serve().

const log = std.log.scoped(.cdnsv);

const config: @import("Config.zig") = @import("config");

const Args = struct {
    address: []const u8 = config.listen_address,
    gamesv_address: []const u8 = config.gamesv_address,
    hot_revision: []const u8 = config.hot_revision,
};

pub fn main(init: process.Init.Minimal) u8 {
    var debug_allocator: DebugAllocator(.{}) = .init;
    defer if (is_debug) debug.assert(.ok == debug_allocator.deinit());

    const gpa = if (is_debug)
        debug_allocator.allocator()
    else
        std.heap.smp_allocator;

    var args_arena: ArenaAllocator = .init(gpa);
    defer if (is_debug) args_arena.deinit();

    const args_slice = init.args.toSlice(args_arena.allocator()) catch
        fatal("unable to collect command line arguments", .{});

    var cli_diag: cli.Diagnostic = undefined;
    const args = cli.parseArguments(Args, args_slice[1..], &cli_diag) orelse
        fatal("{f}\nusage: {s} {f}", .{ cli_diag, args_slice[0], cli.Usage(Args) });

    const address = net.IpAddress.parseLiteral(args.address) catch |err|
        fatal("invalid listen address provided: {t}", .{err});

    const gamesv_address = net.IpAddress.parseLiteral(args.gamesv_address) catch |err|
        fatal("invalid gamesv address provided: {t}", .{err});

    const options: Options = .{
        .gamesv_address = switch (gamesv_address) {
            .ip4 => |ip4| ip4,
            .ip6 => fatal("gamesv via ipv6 is not supported", .{}),
        },
        .hot_revision = args.hot_revision,
    };

    var threaded: Io.Threaded = .init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    common.printStartupSplash();

    return runUntilShutdown(io, app.serve, .{ gpa, io, address, options }) catch |err| switch (err) {
        error.Canceled => return 0,
    };
}

// Same as std.process.fatal, except it uses scoped log.
fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    log.err(fmt, args);
    process.exit(1);
}

const Io = std.Io;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const DebugAllocator = std.heap.DebugAllocator;

const is_debug = builtin.mode == .Debug;
const runUntilShutdown = common.io.runUntilShutdown;

const cli = common.cli;
const net = std.Io.net;
const debug = std.debug;
const process = std.process;

const app = @import("app.zig");
const Options = @import("Options.zig");

const builtin = @import("builtin");
const common = @import("common");
const std = @import("std");
