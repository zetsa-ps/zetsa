pub const ParseAttrsetError = error{
    ReadFailed,
    StreamTooLong, // Line length limit reached.
    InvalidFormat, // One or more fields have invalid values.
    MissingAttributes, // The file is missing non-optional attributes.
};

/// The `reader` should be buffered, its buffer size defines the line length limit.
pub fn parseAttrset(comptime T: type, reader: *Io.Reader, out: *T) ParseAttrsetError!void {
    const Attr = std.meta.FieldEnum(T);
    var set_attrs: std.EnumSet(Attr) = .empty;

    while (try reader.takeDelimiter('\n')) |line| {
        var parts = std.mem.tokenizeAny(u8, unclrf(line), "= ");
        const attr = parts.next() orelse continue;
        const value = parts.next() orelse return error.InvalidFormat;

        if (std.meta.stringToEnum(Attr, attr)) |attr_tag| switch (attr_tag) {
            inline else => |tag| {
                set_attrs.insert(tag);
                const FieldType = @FieldType(T, @tagName(tag));
                switch (@typeInfo(FieldType)) {
                    .int => {
                        @field(out, @tagName(tag)) = std.fmt.parseInt(FieldType, value, 10) catch
                            return error.InvalidFormat;
                    },
                    .@"struct" => {
                        if (@hasDecl(FieldType, "max_length") and
                            FieldType == common.mem.LimitedString(FieldType.max_length))
                        {
                            @field(out, @tagName(tag)).set(value) catch return error.InvalidFormat;
                            continue;
                        }

                        @compileError("unsupported attribute type: " ++ @typeName(FieldType));
                    },
                    .@"enum" => |e| if (e.is_exhaustive) {
                        @field(out, @tagName(tag)) = std.meta.stringToEnum(FieldType, value) orelse
                            return error.InvalidFormat;
                    } else {
                        const int = std.fmt.parseInt(e.tag_type, value, 10) catch return error.InvalidFormat;
                        @field(out, @tagName(tag)) = @enumFromInt(int);
                    },
                    // TODO: more types
                    else => @compileError("unsupported attribute type: " ++ @typeName(FieldType)),
                }
            },
        };
    }

    if (!set_attrs.eql(.full)) return error.MissingAttributes;
}

pub fn writeAttrset(comptime T: type, writer: *Io.Writer, data: *const T) Io.Writer.Error!void {
    inline for (@typeInfo(T).@"struct".fields) |field| {
        try writer.writeAll(field.name ++ " = ");

        switch (@typeInfo(field.type)) {
            .int => try writer.print("{d}\n", .{@field(data, field.name)}),
            .@"struct" => {
                if (@hasDecl(field.type, "max_length") and
                    field.type == common.mem.LimitedString(field.type.max_length))
                {
                    try writer.print("{s}\n", .{@field(data, field.name).view()});
                    continue;
                }

                @compileError("unsupported attribute type: " ++ @typeName(field.type));
            },
            .@"enum" => |e| if (e.is_exhaustive) {
                // Save exhaustive enums as strings.
                try writer.print("{s}\n", .{@tagName(@field(data, field.name))});
            } else {
                // Save non-exhaustive enums as their int values.
                try writer.print("{d}\n", .{@intFromEnum(@field(data, field.name))});
            },
            // TODO: more types
            else => @compileError("unsupported attribute type: " ++ @typeName(field.type)),
        }
    }

    try writer.flush();
}

pub const SaveAttrsetError = error{InputOutput};

/// Saves an `attrset` to the specified `path`.
/// * Creates the file and full path in case it doesn't exist
/// * The caller must block cancelation requests
pub fn saveAttrset(comptime T: type, io: Io, path: []const u8, attrset: *const T) SaveAttrsetError!void {
    const file = createFilePath(io, .cwd(), path) catch return error.InputOutput;
    defer file.close(io);

    var fw_buf: [1024]u8 = undefined;
    var fw = file.writer(io, &fw_buf);
    const writer = &fw.interface;

    writeSchemaHash(T, writer) catch return error.InputOutput;
    writeAttrset(T, writer, attrset) catch return error.InputOutput;
}

pub const LoadAttrsetError = Io.Cancelable || error{
    InputOutput,
    NotFound,
    MissingAttributes,
    InvalidFormat,
    StreamTooLong,
    Outdated,
} || std.mem.Allocator.Error;

pub fn loadAttrset(comptime T: type, io: Io, path: []const u8, out: *T) LoadAttrsetError!void {
    const file = Dir.openFile(.cwd(), io, path, .{}) catch |err| return switch (err) {
        error.Canceled => |e| e,
        error.FileNotFound => error.NotFound,
        else => error.InputOutput,
    };

    defer file.close(io);

    var fr_buf: [1024]u8 = undefined;
    var fr = file.reader(io, &fr_buf);

    if (try readSchemaHash(&fr) != computeSchemaHash(T))
        return error.Outdated;

    parseAttrset(T, &fr.interface, out) catch |err| return switch (err) {
        error.ReadFailed => switch (fr.err.?) {
            error.Canceled => |e| e,
            else => error.InputOutput,
        },
        error.InvalidFormat, error.StreamTooLong, error.MissingAttributes => |e| e,
    };
}

pub const SaveTableError = error{InputOutput};

// Saves an `EnumMap` to the specified `path` as a TSV.
// * Creates the file and full path in case it doesn't exist
// * The caller must block cancelation requests
pub fn saveEnumMap(
    comptime K: type,
    comptime V: type,
    io: Io,
    path: []const u8,
    data: *const std.EnumMap(K, V),
) SaveTableError!void {
    const file = createFilePath(io, .cwd(), path) catch return error.InputOutput;
    defer file.close(io);

    var fw_buf: [1024]u8 = undefined;
    var fw = file.writer(io, &fw_buf);
    const writer = &fw.interface;

    writeSchemaHash(struct { key: K, value: V }, writer) catch return error.InputOutput;
    try writeTsvHeader(V, writer);

    var iterator = @constCast(data).iterator(); // We won't be modifying anything.

    while (iterator.next()) |entry| {
        writeTsvField(K, writer, entry.key) catch return error.InputOutput;

        inline for (@typeInfo(V).@"struct".fields) |field|
            writeTsvField(field.type, writer, @field(entry.value, field.name)) catch
                return error.InputOutput;

        writer.writeByte('\n') catch return error.InputOutput;
    }

    writer.flush() catch return error.InputOutput;
}

// Saves an `ArrayHashMap` (Auto) to the specified `path` as a TSV.
// * Creates the file and full path in case it doesn't exist
// * The caller must block cancelation requests
pub fn saveAutoArrayHashMap(
    comptime K: type,
    comptime V: type,
    io: Io,
    path: []const u8,
    data: *const std.array_hash_map.Auto(K, V),
) SaveTableError!void {
    const file = createFilePath(io, .cwd(), path) catch return error.InputOutput;
    defer file.close(io);

    var fw_buf: [1024]u8 = undefined;
    var fw = file.writer(io, &fw_buf);
    const writer = &fw.interface;

    writeSchemaHash(struct { key: K, value: V }, writer) catch return error.InputOutput;
    try writeTsvHeader(V, writer);

    var iterator = @constCast(data).iterator(); // We won't be modifying anything.

    while (iterator.next()) |entry| {
        writeTsvField(K, writer, entry.key_ptr.*) catch return error.InputOutput;

        inline for (@typeInfo(V).@"struct".fields) |field|
            writeTsvField(field.type, writer, @field(entry.value_ptr.*, field.name)) catch
                return error.InputOutput;

        writer.writeByte('\n') catch return error.InputOutput;
    }

    writer.flush() catch return error.InputOutput;
}

fn writeValue(
    comptime F: type,
    writer: *Io.Writer,
    value: F,
) !void {
    switch (@typeInfo(F)) {
        .int => try writer.print("{d}", .{value}),
        .@"enum" => |e| if (e.is_exhaustive)
            try writer.print("{t}", .{value})
        else
            try writer.print("{d}", .{@intFromEnum(value)}),
        .array => |array| {
            const sep: u8 = switch (@typeInfo(array.child)) {
                .array => ';',
                else => ',',
            };

            for (value, 0..) |elem, i| {
                if (i != 0)
                    try writer.writeByte(sep);

                try writeValue(array.child, writer, elem);
            }
        },
        .@"struct" => |s| {
            if (@hasDecl(F, "max_length") and
                F == common.mem.LimitedString(F.max_length))
            {
                try writer.print("{s}", .{value.view()});
                return;
            }

            if (@hasDecl(F, "toInt")) {
                try writer.print("{d}", .{value.toInt()});
                return;
            }

            if (s.backing_integer) |backing_integer| {
                try writer.print("{d}", .{@as(backing_integer, @bitCast(value))});
                return;
            }

            @compileError("Unsupported field type: " ++ @typeName(F));
        },
        else => @compileError("Unsupported field type: " ++ @typeName(F)),
    }
}

fn writeTsvField(comptime F: type, writer: *Io.Writer, value: F) !void {
    try writeValue(F, writer, value);
    try writer.writeByte('\t');
}

fn writeTsvHeader(comptime V: type, writer: *Io.Writer) !void {
    writer.printAscii("key\t", .{}) catch return error.InputOutput;

    inline for (@typeInfo(V).@"struct".fields) |field| {
        writer.print("{s}\t", .{field.name}) catch return error.InputOutput;
    }

    writer.writeByte('\n') catch return error.InputOutput;
}

fn writeSchemaHash(comptime V: type, writer: *Io.Writer) !void {
    try writer.print("# schema={x:0>16}\n", .{computeSchemaHash(V)});
}

pub fn readSchemaHash(fr: *Io.File.Reader) !u64 {
    const prefix = "# schema=";

    if (fr.interface.takeDelimiter('\n') catch |err|
        return switch (err) {
            error.ReadFailed => switch (fr.err.?) {
                error.Canceled => |e| e,
                else => error.InputOutput,
            },
            else => error.InputOutput,
        }) |line|
    {
        if (!std.mem.startsWith(u8, line, prefix))
            return error.InvalidFormat;

        return std.fmt.parseUnsigned(u64, line[prefix.len..], 16) catch
            return error.InvalidFormat;
    } else return error.InvalidFormat;
}

const LoadTableError = error{
    InputOutput,
    InvalidFormat,
    NotFound,
    Outdated,
} || Io.Cancelable || std.mem.Allocator.Error;

pub fn loadEnumMap(
    comptime K: type,
    comptime V: type,
    io: Io,
    path: []const u8,
    out: *std.EnumMap(K, V),
) LoadTableError!void {
    const file = Dir.openFile(.cwd(), io, path, .{}) catch |err| return switch (err) {
        error.Canceled => |e| e,
        error.FileNotFound => error.NotFound,
        else => error.InputOutput,
    };

    defer file.close(io);

    var fr_buf: [1024]u8 = undefined;
    var fr = file.reader(io, &fr_buf);
    const reader = &fr.interface;

    if (try readSchemaHash(&fr) != computeSchemaHash(struct { key: K, value: V }))
        return error.Outdated;

    const header = reader.takeDelimiter('\n') catch |err| return switch (err) {
        error.ReadFailed => switch (fr.err.?) {
            error.Canceled => |e| e,
            else => error.InputOutput,
        },
        else => error.InputOutput,
    };

    if (header == null)
        return error.InvalidFormat;

    while (true) {
        const maybe_line = reader.takeDelimiter('\n') catch |err| return switch (err) {
            error.ReadFailed => switch (fr.err.?) {
                error.Canceled => |e| e,
                else => error.InputOutput,
            },
            else => error.InputOutput,
        };

        const line = maybe_line orelse break;

        var row = std.mem.splitScalar(u8, unclrf(line), '\t');
        const key = try parseTsvField(K, &row);
        var value: V = undefined;

        inline for (@typeInfo(V).@"struct".fields) |field| {
            @field(value, field.name) = try parseTsvField(field.type, &row);
        }

        out.put(key, value);
    }
}

pub fn loadAutoArrayHashMap(
    comptime K: type,
    comptime V: type,
    gpa: std.mem.Allocator,
    io: Io,
    path: []const u8,
    out: *std.array_hash_map.Auto(K, V),
) LoadTableError!void {
    const file = Dir.openFile(.cwd(), io, path, .{}) catch |err| return switch (err) {
        error.Canceled => |e| e,
        error.FileNotFound => error.NotFound,
        else => error.InputOutput,
    };

    defer file.close(io);

    var fr_buf: [1024]u8 = undefined;
    var fr = file.reader(io, &fr_buf);
    const reader = &fr.interface;

    if (try readSchemaHash(&fr) != computeSchemaHash(struct { key: K, value: V }))
        return error.Outdated;

    const header = reader.takeDelimiter('\n') catch |err| return switch (err) {
        error.ReadFailed => switch (fr.err.?) {
            error.Canceled => |e| e,
            else => error.InputOutput,
        },
        else => error.InputOutput,
    };

    if (header == null)
        return error.InvalidFormat;

    while (true) {
        const maybe_line = reader.takeDelimiter('\n') catch |err| return switch (err) {
            error.ReadFailed => switch (fr.err.?) {
                error.Canceled => |e| e,
                else => error.InputOutput,
            },
            else => error.InputOutput,
        };

        const line = maybe_line orelse break;

        var row = std.mem.splitScalar(u8, unclrf(line), '\t');
        const key = try parseTsvField(K, &row);
        var value: V = undefined;

        inline for (@typeInfo(V).@"struct".fields) |field| {
            @field(value, field.name) = try parseTsvField(field.type, &row);
        }

        try out.put(gpa, key, value);
    }
}

fn parseValue(comptime F: type, text: []const u8) LoadTableError!F {
    switch (@typeInfo(F)) {
        .int => {
            return std.fmt.parseInt(F, text, 10) catch error.InvalidFormat;
        },
        .@"enum" => |e| if (e.is_exhaustive) {
            return std.meta.stringToEnum(F, text) orelse error.InvalidFormat;
        } else {
            return @enumFromInt(
                std.fmt.parseInt(
                    e.tag_type,
                    text,
                    10,
                ) catch return error.InvalidFormat,
            );
        },
        .array => |array| {
            var result: [array.len]array.child = undefined;

            const sep: u8 = switch (@typeInfo(array.child)) {
                .array => ';',
                else => ',',
            };

            var it = std.mem.splitScalar(u8, text, sep);

            for (0..array.len) |i| {
                result[i] = try parseValue(
                    array.child,
                    it.next() orelse return error.InvalidFormat,
                );
            }

            if (it.next() != null) return error.InvalidFormat;

            return result;
        },
        .@"struct" => |s| {
            if (@hasDecl(F, "max_length") and
                F == common.mem.LimitedString(F.max_length))
            {
                return F.init(text) catch error.InvalidFormat;
            }

            if (@hasDecl(F, "fromInt")) {
                const fn_info = @typeInfo(@TypeOf(@field(F, "fromInt"))).@"fn";

                if (fn_info.params.len == 1) {
                    if (fn_info.params[0].type) |int_type| {
                        return F.fromInt(
                            std.fmt.parseInt(
                                int_type,
                                text,
                                10,
                            ) catch return error.InvalidFormat,
                        );
                    }
                }
            }

            if (s.backing_integer) |backing_integer|
                return @bitCast(
                    std.fmt.parseInt(
                        backing_integer,
                        text,
                        10,
                    ) catch return error.InvalidFormat,
                );

            @compileError("Unsupported field type: " ++ @typeName(F));
        },
        else => @compileError("Unsupported field type: " ++ @typeName(F)),
    }
}

fn parseTsvField(
    comptime F: type,
    row: *std.mem.SplitIterator(u8, .scalar),
) LoadTableError!F {
    const text = row.next() orelse return error.InvalidFormat;

    return parseValue(F, text);
}

/// Returns the hash of a type using `FNV-1a` algorithm
fn computeSchemaHash(comptime T: type) u64 {
    var h: u64 = 0xcbf29ce484222325; // FNV offset basis
    hashType(&h, T);
    return h;
}

fn hashType(h: *u64, comptime T: type) void {
    switch (@typeInfo(T)) {
        .@"struct" => |s| {
            hashU64(h, @as(u64, @intCast(s.fields.len)));

            inline for (s.fields) |field| {
                hashStr(h, field.name);
                hashType(h, field.type);
            }
        },
        else => hashStr(h, @typeName(T)),
    }
}

fn hashStr(h: *u64, s: []const u8) void {
    hashU64(h, @as(u64, @intCast(s.len)));
    hashBytes(h, s);
}

fn hashBytes(h: *u64, bytes: []const u8) void {
    for (bytes) |b| {
        h.* ^= b;
        h.* = h.* *% 0x100000001b3; // FNV prime
    }
}

fn hashU64(h: *u64, value: u64) void {
    const bytes = [_]u8{
        @truncate(value >> 0),
        @truncate(value >> 8),
        @truncate(value >> 16),
        @truncate(value >> 24),
        @truncate(value >> 32),
        @truncate(value >> 40),
        @truncate(value >> 48),
        @truncate(value >> 56),
    };
    hashBytes(h, &bytes);
}

pub const FetchAddError = error{
    InputOutput,
    CorruptedInteger,
};

/// Performs a fetch-add operation on the file containing a decimal representation of `Int`.
/// * Creates the file in case it doesn't exist
/// * The caller must block cancelation requests
pub fn fetchAdd(comptime Int: type, io: Io, path: []const u8, comptime default: Int) FetchAddError!Int {
    var int_buf: [128]u8 = undefined;

    const string = Dir.readFile(.cwd(), io, path, &int_buf) catch |err| switch (err) {
        error.FileNotFound => {
            const file = createFilePath(io, .cwd(), path) catch return error.InputOutput;
            defer file.close(io);

            const string = std.fmt.bufPrint(&int_buf, "{d}", .{default + 1}) catch unreachable;
            file.writeStreamingAll(io, string) catch return error.InputOutput;

            return default;
        },
        else => return error.InputOutput,
    };

    const value = std.fmt.parseInt(Int, string, 10) catch return error.CorruptedInteger;
    const new_string = std.fmt.bufPrint(&int_buf, "{d}", .{value + 1}) catch unreachable;

    Dir.writeFile(.cwd(), io, .{ .sub_path = path, .data = new_string }) catch return error.InputOutput;

    return value;
}

const CreateFilePathError = Io.File.OpenError || Io.Dir.CreateDirPathError;

/// Creates a File, and, if sub_path elements are missing, creates dir path as well.
pub fn createFilePath(io: Io, dir: Io.Dir, sub_path: []const u8) CreateFilePathError!Io.File {
    while (true) return dir.createFile(io, sub_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            const dirname = std.fs.path.dirname(sub_path) orelse return error.FileNotFound;
            try dir.createDirPath(io, dirname);
            continue;
        },
        else => |e| return e,
    };
}

fn unclrf(line: []const u8) []const u8 {
    return if (line.len != 0 and line[line.len - 1] == '\r') line[0 .. line.len - 1] else line;
}

pub const Account = @import("store/Account.zig");
pub const player = @import("store/player.zig");

const Io = std.Io;
const Dir = std.Io.Dir;

const logic = @import("logic.zig");
const common = @import("common");
const std = @import("std");
