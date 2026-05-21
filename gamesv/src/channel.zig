const log = std.log.scoped(.@"gamesv::channel");

const config: @import("Config.zig") = @import("config");

pub fn run(io: Io, assets: *Assets, stream: net.Stream, gpa: Allocator) Io.Cancelable!void {
    defer stream.close(io);

    log.info("new connection from {f}", .{stream.socket.address});
    defer log.info("client from {f} disconnected", .{stream.socket.address});

    var player_store: logic.PlayerStore = .init;
    defer player_store.deinit(gpa);

    var services: logic.Services = .init;
    defer services.deinit(gpa);

    var read_buffer: [config.recv_buffer_size]u8 = undefined;
    var reader = stream.reader(io, &read_buffer);

    // See `Translator.writer()` for the rationale on buffer size.
    var write_buffer: [Translator.unencrypted_head_len]u8 = undefined;
    var writer = stream.writer(io, &write_buffer);

    while (true) {
        var translator_buffer: [128]u8 = undefined; // just for amortizing vtable calls.
        var msg: NetMsg = undefined;

        readMsg(&reader.interface, &msg, &translator_buffer) catch |err| switch (err) {
            error.ReadFailed => switch (reader.err.?) {
                error.Canceled => |e| return e,
                else => |e| {
                    log.err("readMsg failed: {t}", .{e});
                    return;
                },
            },
            error.EndOfStream => return, // Client disconnected.
        };

        messaging.dispatch(
            io,
            gpa,
            assets,
            &player_store,
            &services,
            &msg,
            &writer.interface,
        ) catch |err| switch (err) {
            error.Canceled => |e| return e,
            error.WriteFailed => switch (writer.err.?) {
                error.Canceled => |e| return e,
                else => |e| {
                    log.warn(
                        "network write failed for '{f}', disconnecting. ({t})",
                        .{ stream.socket.address, e },
                    );
                    return;
                },
            },
            error.OutOfMemory => {
                log.warn("Out of Memory! Disconnecting client from '{f}'.", .{stream.socket.address});
                return;
            },
            error.MalformedMessage => {
                log.warn(
                    "received malformed message with id {d} from '{f}', disconnecting.",
                    .{ msg.data.msg_id, stream.socket.address },
                );
                return;
            },
            error.UnexpectedMessage => {
                log.warn(
                    "received unexpected message with id {d} from '{f}', disconnecting.",
                    .{ msg.data.msg_id, stream.socket.address },
                );
                return;
            },
        };
    }
}

pub const NetMsg = struct {
    data: Data,
    reader: Translator.Reader,

    pub const Data = struct {
        const size = 17;

        flag: u8,
        msg_id: u16,
        error_id: u16,
        seq_no: u16,
        push_seq: u16,
        unk_1: i32,
        unk_2: i32,
    };
};

pub fn readMsg(source: *Io.Reader, out: *NetMsg, translator_buffer: []u8) Io.Reader.Error!void {
    const size = try source.takeInt(u32, .big);
    out.data.flag = try source.takeByte();
    out.data.msg_id = try source.takeInt(u16, .big);

    const translator: Translator = .init(.limited(
        size - Translator.unencrypted_head_len,
    ));

    var tr = translator.reader(source, translator_buffer);
    const reader = &tr.interface;

    out.data.error_id = try reader.takeInt(u16, .big);
    out.data.seq_no = try reader.takeInt(u16, .big);
    out.data.push_seq = try reader.takeInt(u16, .big);
    out.data.unk_1 = try reader.takeInt(i32, .big);
    out.data.unk_2 = try reader.takeInt(i32, .big);

    out.reader = tr;
}

pub fn writeMsg(sink: *Io.Writer, metadata: *const NetMsg.Data, message: anytype) Io.Writer.Error!void {
    const encoding_length = proto.encodingLength(message) + NetMsg.Data.size + 4;

    try sink.writeInt(u32, @truncate(encoding_length), .big);
    try sink.writeByte(metadata.flag);
    try sink.writeInt(u16, metadata.msg_id, .big);

    const translator: Translator = .init(.limited(
        encoding_length - Translator.unencrypted_head_len,
    ));

    // See `Translator.writer()` for the rationale on buffer size.
    var tw_buf: [config.send_buffer_size]u8 = undefined;
    var tw = translator.writer(sink, &tw_buf);
    const writer = &tw.interface;

    try writer.writeInt(u16, metadata.error_id, .big);
    try writer.writeInt(u16, metadata.seq_no, .big);
    try writer.writeInt(u16, metadata.push_seq, .big);
    try writer.writeInt(i32, metadata.unk_1, .big);
    try writer.writeInt(i32, metadata.unk_2, .big);

    try proto.encode(writer, message);

    try writer.flush();
    try sink.flush();
}

const Io = std.Io;
const Allocator = std.mem.Allocator;

const pb = proto.pb;
const net = std.Io.net;

const logic = @import("logic.zig");
const Assets = @import("Assets.zig");
const messaging = @import("messaging.zig");
const Translator = @import("channel/Translator.zig");
const proto = @import("proto");
const std = @import("std");
