pub fn ping(txn: Transaction(.CSProtoPing)) !void {
    try txn.respond(.{
        .time_zone = 3,
        .time = @intCast(txn.any.time.toSeconds()),
        .time_msec = @intCast(@mod(txn.any.time.toMilliseconds(), 1000)),
        .client_ts = txn.request.client_ts,
    });
}

pub fn recycle(_: Transaction(.CSProtoRecycle)) !void {}

const Transaction = messaging.Transaction;
const pb = proto.pb;

const messaging = @import("../messaging.zig");
const proto = @import("proto");
const std = @import("std");
