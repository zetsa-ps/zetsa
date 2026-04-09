const log = std.log.scoped(.@"cdnsv::routes");

pub const Error = Io.Cancelable || Io.Writer.Error;
const RouteError = Io.Writer.Error;

const namespaces: []const type = &.{
    @import("routes/version.zig"),
};

const manifest_hashes: std.StaticStringMap([]const u8) = .initComptime(@import("hashes"));

const Route = blk: {
    var field_names: []const [:0]const u8 = &.{};
    var tag_values: []const u8 = &.{};
    var i: u8 = 0;

    for (namespaces) |ns| for (@typeInfo(ns).@"struct".decls) |decl| {
        field_names = field_names ++ [1][:0]const u8{decl.name};
        tag_values = tag_values ++ [1]u8{i};
        i += 1;
    };

    break :blk @Enum(u8, .exhaustive, field_names, @ptrCast(tag_values));
};

pub fn dispatch(io: Io, options: Options, sink: *Io.Writer, request: *const http.RequestLine) Error!void {
    if (std.meta.stringToEnum(Route, request.target)) |route| {
        switch (route) {
            inline else => |r| lookup: inline for (namespaces) |ns| {
                inline for (@typeInfo(ns).@"struct".decls) |decl| if (comptime std.mem.eql(u8, decl.name, @tagName(r))) {
                    @field(ns, decl.name)(io, options, sink) catch |err| switch (@as(RouteError, err)) {
                        error.WriteFailed => |e| return e,
                    };
                    break :lookup;
                };
            } else comptime unreachable,
        }
    } else if (parseTargetAsManifestPath(request.target)) |path| {
        const hash = manifest_hashes.get(path) orelse {
            log.warn("unknown manifest hash requested: '{s}'", .{path});
            return;
        };

        var response: http.Response = .init(sink);
        try response.respond(.OK, .@"text/plain", hash);
    } else {
        log.warn("unhandled route: {s}", .{request.target});
    }
}

fn parseTargetAsManifestPath(target: []const u8) ?[]const u8 {
    const files_prefix = "/chs/windows/";
    const files_suffix = ".hash";

    return if (std.mem.startsWith(u8, target, files_prefix) and
        std.mem.endsWith(u8, target, files_suffix))
        std.mem.trimStart(u8, target[files_prefix.len..], "/")
    else
        null;
}

const Io = std.Io;

const Options = @import("Options.zig");
const http = @import("http.zig");
const std = @import("std");
