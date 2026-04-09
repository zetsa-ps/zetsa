const accept_delay: Io.Timeout = .{ .duration = .{ .raw = .fromSeconds(1), .clock = .awake } };

pub fn serve(gpa: Allocator, io: Io, address: net.IpAddress) Io.Cancelable!u8 {
    const log = std.log.scoped(.@"gamesv::app");

    var server = address.listen(io, .{ .reuse_address = true }) catch |err| switch (err) {
        error.Canceled => |e| return e,
        error.AddressInUse => {
            log.err("address '{f}' is already in use. another instance of this server might be already running", .{address});
            return 1;
        },
        else => |e| {
            log.err("failed to listen at {f}: {t}", .{ address, e });
            return 1;
        },
    };

    defer server.deinit(io);

    var client_group: Io.Group = .init;
    defer client_group.cancel(io);

    log.info("listening at {f}", .{address});
    defer log.info("shutting down...", .{});

    while (true) {
        if (server.accept(io)) |stream| {
            client_group.concurrent(io, channel.run, .{ io, stream, gpa }) catch |err| switch (err) {
                error.ConcurrencyUnavailable => {
                    log.warn("concurrency limit reached. dropping connection from {f}", .{stream.socket.address});
                    stream.close(io);
                },
            };
        } else |err| switch (err) {
            error.Canceled => |e| return e,

            error.SystemResources,
            error.SystemFdQuotaExceeded,
            error.ProcessFdQuotaExceeded,
            => try accept_delay.sleep(io),

            else => |e| log.debug("accept failed: {t}", .{e}),
        }
    }

    return 0;
}

const Io = std.Io;
const Allocator = std.mem.Allocator;

const net = std.Io.net;

const channel = @import("channel.zig");
const std = @import("std");
