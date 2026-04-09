const log = std.log.scoped(.@"cdnsv::connection");

const config: @import("Config.zig") = @import("config");

pub fn run(io: Io, options: Options, stream: net.Stream) Io.Cancelable!void {
    defer stream.close(io);

    var recv_buffer: [config.recv_buffer_size]u8 = undefined;
    var reader = stream.reader(io, &recv_buffer);

    var send_buffer: [config.send_buffer_size]u8 = undefined;
    var writer = stream.writer(io, &send_buffer);

    const request = runWithTimeout(
        io,
        config.requestTimeout(),
        http.RequestLine.read,
        .{&reader.interface},
    ) catch |err| switch (err) {
        error.Canceled => |e| return e,
        error.EndOfStream => return,
        error.Timeout => {
            log.warn("request timed out, dropping connection from {f}", .{stream.socket.address});
            return;
        },
        error.ConcurrencyUnavailable => {
            log.warn("concurrency limit reached. dropping connection from {f}", .{stream.socket.address});
            return;
        },
        error.ReadFailed => switch (reader.err.?) {
            error.Canceled => |e| return e,
            else => |e| {
                log.warn("failed to receive http request from {f}: {t}", .{ stream.socket.address, e });
                return;
            },
        },
        error.InvalidMethod,
        error.MissingComponents,
        error.StreamTooLong,
        => |e| {
            log.warn("malformed request from {f}: {t}", .{ stream.socket.address, e });
            return;
        },
    };

    log.info("received request '{s}' from {f}", .{ request.target, stream.socket.address });
    routes.dispatch(io, options, &writer.interface, &request) catch |err| switch (err) {
        error.Canceled => |e| return e,
        error.WriteFailed => switch (writer.err.?) {
            error.Canceled => |e| return e,
            else => |e| {
                log.warn("failed to respond to request from {f}: {t}", .{ stream.socket.address, e });
                return;
            },
        },
    };

    _ = runWithTimeout(
        io,
        config.drainTimeout(),
        Io.Reader.discardRemaining,
        .{&reader.interface},
    ) catch |err| switch (err) {
        error.Canceled => |e| return e,
        else => {},
    };
}

const Io = std.Io;

const net = std.Io.net;
const runWithTimeout = common.io.runWithTimeout;

const Options = @import("Options.zig");
const routes = @import("routes.zig");
const http = @import("http.zig");
const common = @import("common");
const std = @import("std");
