const weak_key: []const u8 = &.{ 0x52, 0x54, 0x45, 0x57, 0x67, 0x64, 0x73, 0x74, 0x25, 0x5E, 0x26, 0x32, 0x33, 0x66, 0x62, 0x38, 0x37, 0x2A, 0x23, 0x57, 0x33, 0x72, 0x64, 0x66, 0x64, 0x36, 0x37, 0x57, 0x24, 0x23, 0x26, 0x5E, 0x2A, 0x26, 0x2A, 0x40, 0x23, 0x21, 0x24, 0x44, 0x46, 0x65, 0x64, 0x66, 0x74, 0x79, 0x24, 0x5E, 0x25, 0x54, 0x57, 0x23, 0x23, 0x45, 0x23, 0x40, 0x25, 0x24, 0x64, 0x73, 0x54, 0x48, 0x5E, 0x2A, 0x26, 0x2A, 0x26, 0x66, 0x61, 0x73, 0x64, 0x66, 0x61, 0x3C, 0x3E, 0x3C, 0x3F, 0x3E, 0x3E, 0x4C, 0x66, 0x64, 0x66, 0x64, 0x66, 0x46, 0x24, 0x54, 0x24, 0x67, 0x67, 0x61, 0x64, 0x73, 0x66, 0x34, 0x5E, 0x26, 0x6B, 0x25, 0x40, 0x23, 0x24, 0x2A, 0x29, 0x23, 0x21, 0x46, 0x47, 0x46, 0x44, 0x47, 0x73, 0x24, 0x23, 0x25, 0x25, 0x26, 0x25, 0x44, 0x47, 0x46, 0x65, 0x61, 0x77, 0x65, 0x66 };

pub const unencrypted_head_len: usize = 7;

const chunk_size: usize = 128;

offset: usize,
full_size: Io.Limit,

// The `size` must not include the `unencrypted_head_len`.
pub fn init(size: Io.Limit) Translator {
    return .{ .offset = 0, .full_size = size };
}

pub const Reader = struct {
    translator: Translator,
    interface: Io.Reader,
    source: *Io.Reader,

    // Writes bytes from the internally tracked logical position to io_w.
    // This function can write up to 128 bytes at a time due to additional chunking.
    fn stream(io_r: *Io.Reader, io_w: *Io.Writer, limit: Io.Limit) Io.Reader.StreamError!usize {
        const r: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
        const t = &r.translator;
        const to_read = try r.remainingLimitUnbuffered(limit);

        var chunk: [chunk_size]u8 = undefined;
        var bufs: [1][]u8 = .{chunk[0..@min(chunk.len, to_read)]};

        const n_read = try r.source.readVec(&bufs);
        t.xor(chunk[0..n_read]);

        try io_w.writeAll(chunk[0..n_read]);
        return n_read;
    }

    fn readVec(io_r: *Io.Reader, data: [][]u8) Io.Reader.Error!usize {
        const r: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
        const t = &r.translator;
        const to_read = try r.remainingLimitUnbuffered(.unlimited);

        if (data[0].len == 0) {
            // Read into `io_r.buffer`

            var bufs = [1][]u8{io_r.buffer[io_r.end..][0..@min(io_r.buffer.len - io_r.end, to_read)]};
            const n_read = try r.source.readVec(&bufs);

            t.xor(bufs[0][0..n_read]);
            io_r.end += n_read;
            return 0;
        }

        // Last buffer length to be restored if truncated.
        const last_buf_len = data[data.len - 1].len;
        defer data[data.len - 1].len = last_buf_len;

        // The number of bytes the caller is ready to consume.
        var can_read: usize = 0;
        var n_bufs: usize = 0;

        for (data) |*buf| {
            can_read += buf.len;
            n_bufs += 1;

            // If the caller is able to consume more than the limit of this Reader,
            // truncate the buffers.
            if (can_read > to_read) {
                can_read -= buf.len;
                const truncated_len = to_read - can_read;
                buf.len = truncated_len;

                break;
            } else if (can_read == to_read) break;
        }

        const n_read = try r.source.readVec(data[0..n_bufs]);
        var to_xor: usize = n_read;

        for (data[0..n_bufs]) |buf| {
            if (to_xor == 0) break;

            const len = @min(buf.len, to_xor);
            t.xor(buf[0..len]);
            to_xor -= len;
        }

        return n_read;
    }

    fn discard(io_r: *Io.Reader, limit: Io.Limit) Io.Reader.Error!usize {
        const r: *Reader = @alignCast(@fieldParentPtr("interface", io_r));
        const t = &r.translator;
        const to_discard = try r.remainingLimitUnbuffered(limit);

        const n_discarded = try r.source.discard(.limited(to_discard));
        t.offset += n_discarded;

        return n_discarded;
    }

    fn remainingLimitUnbuffered(r: *const Reader, user_limit: Io.Limit) Io.Reader.Error!usize {
        const read_limit = user_limit.min(
            r.translator.full_size.subtract(r.translator.offset) orelse return error.EndOfStream,
        );

        if (read_limit == .nothing)
            return error.EndOfStream;

        return read_limit.toInt().?;
    }

    // Includes the data available in Io.Reader's buffer.
    pub fn remaining(r: *const Reader) usize {
        const buffered_len = r.interface.end - r.interface.seek;
        return r.translator.full_size.subtract(r.translator.offset).?.toInt().? + buffered_len;
    }
};

pub fn reader(t: Translator, source: *Io.Reader, buffer: []u8) Reader {
    return .{ .translator = t, .source = source, .interface = .{
        .buffer = buffer,
        .seek = 0,
        .end = 0,
        .vtable = &.{
            .stream = Reader.stream,
            .readVec = Reader.readVec,
            .discard = Reader.discard,
        },
    } };
}

pub const Writer = struct {
    translator: Translator,
    interface: Io.Writer,
    sink: *Io.Writer,

    fn drain(io_w: *Io.Writer, data: []const []const u8, splat: usize) Io.Writer.Error!usize {
        const w: *Writer = @alignCast(@fieldParentPtr("interface", io_w));
        _ = try writeBuf(w, io_w.buffered());
        io_w.end = 0;

        var written: usize = 0;

        for (0..data.len - 1) |buf_i|
            written += try writeConstBuf(w, data[buf_i]);

        const pattern = data[data.len - 1];
        for (0..splat) |_|
            written += try writeConstBuf(w, pattern);

        return written;
    }

    fn flush(io_w: *Io.Writer) Io.Writer.Error!void {
        const w: *Writer = @alignCast(@fieldParentPtr("interface", io_w));
        _ = try writeBuf(w, io_w.buffered());
        io_w.end = 0;
    }

    // This function takes advantage of `buf` being mutable and performs xor in-place.
    fn writeBuf(w: *Writer, buf: []u8) Io.Writer.Error!usize {
        w.translator.xor(buf);
        try w.sink.writeAll(buf);

        return buf.len;
    }

    // Less efficient than `writeBuf`. Uses intermediate chunks.
    fn writeConstBuf(w: *Writer, buf: []const u8) Io.Writer.Error!usize {
        var cursor = buf;
        var chunk: [chunk_size]u8 = undefined;

        while (cursor.len != 0) {
            const to_write = @min(chunk.len, cursor.len);
            @memcpy(chunk[0..to_write], cursor[0..to_write]);
            cursor = cursor[to_write..];

            w.translator.xor(chunk[0..to_write]);
            try w.sink.writeAll(chunk[0..to_write]);
        }

        return buf.len;
    }
};

// A large `buffer` is preferred here, the buffer of `sink` should be kept small, if possible.
// The `buffer` will be utilized to perform xor operations in-place.
pub fn writer(t: Translator, sink: *Io.Writer, buffer: []u8) Writer {
    return .{ .translator = t, .sink = sink, .interface = .{
        .buffer = buffer,
        .vtable = &.{ .drain = Writer.drain, .flush = Writer.flush },
    } };
}

fn xor(t: *Translator, data: []u8) void {
    const off = ((t.full_size.toInt().? + unencrypted_head_len) / 3) - unencrypted_head_len;

    for (data, 0..) |*v, i| v.* ^= weak_key[
        @mod(
            off + unencrypted_head_len + t.offset + i,
            weak_key.len,
        )
    ];

    t.offset += data.len;
}

const Io = std.Io;

const std = @import("std");
const Translator = @This();
