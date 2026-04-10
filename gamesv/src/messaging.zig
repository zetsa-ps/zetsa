const log = std.log.scoped(.@"gamesv::messaging");

pub const Error = HandlerError || error{
    MalformedMessage, // The protobuf message payload is invalid.
    UnexpectedMessage, // The received message is unexpected in current state.
};

// Error set of every handler should be coercible to `HandlerError`.
pub const HandlerError = Io.Cancelable || Allocator.Error || Io.Writer.Error;

const MsgGenCode = struct {
    entries: []const struct {
        request_name: ?[]const u8 = null,
        response_name: ?[]const u8 = null,
    },
};

pub fn Transaction(comptime id: proto.CSProtoIDType) type {
    const entry = @as(MsgGenCode, @import("msg_gen_code")).entries[@intFromEnum(id)];

    return struct {
        pub const proto_id = id;
        pub const Request = if (entry.request_name) |name| @field(proto.pb, name) else void;
        pub const Response = if (entry.response_name) |name| @field(proto.pb, name) else noreturn;

        any: *AnyTransaction,
        request: *const Request,

        pub inline fn respond(txn: @This(), response: Response) Io.Writer.Error!void {
            return txn.any.send(proto_id, response);
        }
    };
}

// A type-erased structure containing all of
// the resources associated with the Transaction.
pub const AnyTransaction = struct {
    // general-purpose
    io: Io,
    gpa: Allocator,
    arena: Allocator,
    time: Io.Timestamp,
    // network-related
    sink: *Io.Writer,
    seq_no: u16,
    push_seq: u16,
    // logic-related
    player_store: *logic.PlayerStore,

    pub fn send(txn: *AnyTransaction, comptime id: proto.CSProtoIDType, message: @field(
        proto.pb,
        @as(MsgGenCode, @import("msg_gen_code")).entries[@intFromEnum(id)].response_name orelse
            @compileError("no response for " ++ @tagName(id)),
    )) Io.Writer.Error!void {
        try channel.writeMsg(txn.sink, &.{
            .flag = 0,
            .msg_id = @intFromEnum(id),
            .error_id = 0, // TODO: a way to send errors
            .seq_no = txn.seq_no,
            .push_seq = txn.push_seq,
            .unk_1 = 0,
            .unk_2 = 0,
        }, message);
    }
};

// A subset of proto.CSProtoIDType, only contains
// proto ids that have handlers defined for them.
const BoundProtoID = blk: {
    var field_names: []const [:0]const u8 = &.{};
    var field_values: []const u16 = &.{};

    for (namespaces) |ns| for (@typeInfo(ns).@"struct".decls) |decl| {
        const info = @typeInfo(@TypeOf(@field(ns, decl.name))).@"fn";
        debug.assert(info.params.len == 1);

        const proto_id = info.params[0].type.?.proto_id;
        field_names = field_names ++ @as([1][:0]const u8, .{@tagName(proto_id)});
        field_values = field_values ++ @as([1]u16, .{@intFromEnum(proto_id)});
    };

    break :blk @Enum(u16, .exhaustive, field_names, @ptrCast(field_values));
};

pub fn dispatch(
    io: Io,
    gpa: Allocator,
    player_store: *logic.PlayerStore,
    msg: *channel.NetMsg,
    sink: *Io.Writer,
) Error!void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    defer arena.deinit();

    var any_txn: AnyTransaction = .{
        .io = io,
        .gpa = gpa,
        .arena = arena.allocator(),
        .time = .now(io, .real),
        .sink = sink,
        .seq_no = msg.data.seq_no,
        .push_seq = msg.data.push_seq,
        .player_store = player_store,
    };

    const recv_proto_id = std.enums.fromInt(BoundProtoID, msg.data.msg_id) orelse {
        if (std.enums.fromInt(proto.CSProtoIDType, msg.data.msg_id)) |id| {
            log.warn("unhandled message: {t}", .{id});
        } else {
            log.debug("received illegal message id: {d}", .{msg.data.msg_id});
        }

        msg.reader.interface.discardAll(msg.reader.remaining()) catch
            return error.MalformedMessage;

        return;
    };

    // The enter game request should be the first one.
    // Any subsequent message is allowed if and only if it succeeded.
    if (recv_proto_id != .CSProtoEnterGame and player_store.id == .none)
        return error.UnexpectedMessage;

    switch (recv_proto_id) {
        inline else => |proto_id| lookup: inline for (namespaces) |ns| {
            inline for (@typeInfo(ns).@"struct".decls) |decl| {
                const info = @typeInfo(@TypeOf(@field(ns, decl.name))).@"fn";
                const Txn = info.params[0].type.?;
                if (@intFromEnum(proto_id) != @intFromEnum(Txn.proto_id)) continue;

                const request = if (Txn.Request != void)
                    proto.decode(Txn.Request, arena.allocator(), &msg.reader.interface) catch |err| {
                        log.debug("failed to decode '" ++ @typeName(Txn.Request) ++ "': {t}", .{err});
                        return;
                    }
                else {};

                const txn: Txn = .{ .any = &any_txn, .request = &request };

                @field(ns, decl.name)(txn) catch |err| switch (@as(HandlerError, err)) {
                    // Just propagation works fine for now.
                    error.OutOfMemory, error.Canceled, error.WriteFailed => |e| return e,
                };

                break :lookup;
            }
        } else comptime unreachable,
    }
}

const namespaces: []const type = &.{
    @import("messaging/heart.zig"),
    @import("messaging/enter_game.zig"),
    @import("messaging/world.zig"),
    @import("messaging/achievement.zig"),
    @import("messaging/group.zig"),
};

const Io = std.Io;
const Allocator = std.mem.Allocator;

const debug = std.debug;
const comptimePrint = std.fmt.comptimePrint;

const channel = @import("channel.zig");
const logic = @import("logic.zig");
const proto = @import("proto");
const std = @import("std");
