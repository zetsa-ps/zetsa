pub const Method = std.http.Method;

pub const RequestLine = struct {
    method: Method,
    target: []const u8,

    pub const ParseError = error{
        InvalidMethod,
        MissingComponents,
        StreamTooLong,
    } || Io.Reader.Error;

    pub fn read(source: *Io.Reader) ParseError!RequestLine {
        const line = try source.takeDelimiter('\n') orelse return error.EndOfStream;
        var reader: Io.Reader = .fixed(line);

        const method_str = reader.takeDelimiter(' ') catch null orelse return error.MissingComponents;
        const method = std.meta.stringToEnum(Method, method_str) orelse return error.InvalidMethod;
        const target = reader.takeDelimiter(' ') catch null orelse return error.MissingComponents;

        return .{ .method = method, .target = target };
    }
};

pub const Response = struct {
    writer: *Io.Writer,

    const json_options: json.Stringify.Options = .{
        .emit_null_optional_fields = false,
    };

    pub const Status = enum(u16) {
        OK = 200,
        @"Not Found" = 404,
        @"Internal Server Error" = 500,
    };

    pub const ContentType = union(enum) {
        @"text/plain": void,
        @"application/json": type,

        pub fn Type(ct: ContentType) type {
            return switch (ct) {
                .@"text/plain" => []const u8,
                .@"application/json" => |T| T,
            };
        }
    };

    pub fn init(writer: *Io.Writer) Response {
        return .{ .writer = writer };
    }

    pub fn respondAny(rsp: *Response, status: Status, payload: anytype) Io.Writer.Error!void {
        try rsp.respond(status, .{ .@"application/json" = @TypeOf(payload) }, payload);
    }

    pub fn respond(
        rsp: *Response,
        status: Status,
        comptime ct: ContentType,
        content: ct.Type(),
    ) Io.Writer.Error!void {
        try rsp.writer.print("HTTP/1.1 {0d} {0t}\r\n", .{status});
        try rsp.writer.print("Connection: close\r\n", .{});
        try rsp.writer.print("Content-Type: {t}\r\n", .{ct});
        try rsp.writer.print("Content-Length: {d}\r\n\r\n", .{contentLength(ct, content)});

        switch (ct) {
            .@"text/plain" => try rsp.writer.writeAll(content),
            .@"application/json" => try rsp.writer.print("{f}", .{json.fmt(content, json_options)}),
        }

        try rsp.writer.flush();
    }

    fn contentLength(comptime ct: ContentType, content: ct.Type()) u64 {
        return switch (ct) {
            .@"text/plain" => content.len,
            .@"application/json" => {
                var buf: [128]u8 = undefined;
                var discarding: Io.Writer.Discarding = .init(&buf);
                discarding.writer.print("{f}", .{json.fmt(content, json_options)}) catch unreachable;

                return discarding.fullCount();
            },
        };
    }
};

const Io = std.Io;

const json = std.json;
const std = @import("std");
