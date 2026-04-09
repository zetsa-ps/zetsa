const log = std.log.scoped(.@"cdnsv::app");

const accept_delay: Io.Timeout = .{ .duration = .{ .raw = .fromSeconds(1), .clock = .awake } };

pub fn serve(gpa: Allocator, io: Io, address: net.IpAddress, options: Options) Io.Cancelable!u8 {
    _ = gpa;

    var server = address.listen(io, .{ .reuse_address = true }) catch |err| {
        log.err("failed to listen at {f}: {t}", .{ address, err });
        return 1;
    };

    defer server.deinit(io);

    var connection_group: Io.Group = .init;
    defer connection_group.cancel(io);

    log.info("listening at {f}", .{address});
    defer log.info("shutting down...", .{});

    while (true) {
        if (server.accept(io)) |stream| {
            connection_group.concurrent(io, connection.run, .{ io, options, stream }) catch |err| switch (err) {
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

const connection = @import("connection.zig");
const Options = @import("Options.zig");
const std = @import("std");
