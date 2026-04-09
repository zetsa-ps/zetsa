pub fn clientBehaviourRecord(txn: Transaction(.CSProtoClientBehaviourRecord)) !void {
    const log = std.log.scoped(.CSProtoClientBehaviourRecord);
    log.debug("{any}", .{txn.request});

    try txn.respond(.{});
}

const Transaction = messaging.Transaction;
const pb = proto.pb;

const messaging = @import("../messaging.zig");
const proto = @import("proto");
const std = @import("std");
