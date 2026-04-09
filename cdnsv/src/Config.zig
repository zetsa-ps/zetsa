recv_buffer_size: usize,
send_buffer_size: usize,
request_timeout_milliseconds: u63,
drain_timeout_milliseconds: u63,
listen_address: []const u8,
gamesv_address: []const u8,
hot_revision: []const u8,

pub fn requestTimeout(config: Config) Io.Timeout {
    return .{ .duration = .{
        .raw = .fromMilliseconds(config.request_timeout_milliseconds),
        .clock = .awake,
    } };
}

pub fn drainTimeout(config: Config) Io.Timeout {
    return .{ .duration = .{
        .raw = .fromMilliseconds(config.drain_timeout_milliseconds),
        .clock = .awake,
    } };
}

const Io = @import("std").Io;
const Config = @This();
