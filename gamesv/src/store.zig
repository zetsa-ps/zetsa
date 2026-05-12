pub const ParseAttrsetError = error{
    ReadFailed,
    StreamTooLong, // Line length limit reached.
    InvalidFormat, // One or more fields have invalid values.
    MissingAttributes, // The file is missing non-optional attributes.
};

// The `reader` should be buffered, its buffer size defines the line length limit.
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

// Saves an `attrset` to the specified `path`.
// * Creates the file and full path in case it doesn't exist
// * The caller must block cancelation requests
pub fn saveAttrset(comptime T: type, io: Io, path: []const u8, attrset: *const T) SaveAttrsetError!void {
    const file = createFilePath(io, .cwd(), path) catch return error.InputOutput;
    defer file.close(io);

    var fw_buf: [1024]u8 = undefined;
    var fw = file.writer(io, &fw_buf);

    writeAttrset(T, &fw.interface, attrset) catch return error.InputOutput;
}

pub const LoadAttrsetError = Io.Cancelable || error{
    InputOutput,
    NotFound,
    MissingAttributes,
    InvalidFormat,
    StreamTooLong,
};

pub fn loadAttrset(comptime T: type, io: Io, path: []const u8, out: *T) LoadAttrsetError!void {
    const file = Dir.openFile(.cwd(), io, path, .{}) catch |err| return switch (err) {
        error.Canceled => |e| e,
        error.FileNotFound => error.NotFound,
        else => error.InputOutput,
    };

    defer file.close(io);

    var fr_buf: [1024]u8 = undefined;
    var fr = file.reader(io, &fr_buf);

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

fn writeTsvField(comptime F: type, writer: *Io.Writer, value: F) Io.Writer.Error!void {
    switch (@typeInfo(F)) {
        .int => try writer.print("{d}\t", .{value}),
        .@"enum" => |e| if (e.is_exhaustive)
            try writer.print("{t}\t", .{value})
        else
            try writer.print("{d}\t", .{@intFromEnum(value)}),
        .array => |array| for (0..array.len) |i| try writeTsvField(array.child, writer, value[i]),
        .@"struct" => {
            if (@hasDecl(F, "max_length") and
                F == common.mem.LimitedString(F.max_length))
            {
                try writer.print("{s}\t", .{value.view()});
                return;
            }

            @compileError("Unsupported field type: " ++ @typeName(F));
        },
        else => @compileError("Unsupported field type: " ++ @typeName(F)),
    }
}

const LoadTableError = error{ InputOutput, InvalidFormat, NotFound } || Io.Cancelable;

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

        out.putAssumeCapacity(key, value);
    }
}

fn parseTsvField(comptime F: type, row: *std.mem.SplitIterator(u8, .scalar)) LoadTableError!F {
    switch (@typeInfo(F)) {
        .int => return std.fmt.parseInt(F, row.next() orelse return error.InvalidFormat, 10) catch
            error.InvalidFormat,
        .@"enum" => |e| if (e.is_exhaustive) {
            const string = row.next() orelse return error.InvalidFormat;
            return std.meta.stringToEnum(F, string) orelse return error.InvalidFormat;
        } else {
            const string = row.next() orelse return error.InvalidFormat;
            const int = std.fmt.parseInt(e.tag_type, string, 10) catch return error.InvalidFormat;

            return @enumFromInt(int);
        },
        .array => |array| {
            var result: [array.len]array.child = undefined;
            for (0..array.len) |i| {
                result[i] = try parseTsvField(array.child, row);
            }

            return result;
        },
        .@"struct" => {
            if (@hasDecl(F, "max_length") and
                F == common.mem.LimitedString(F.max_length))
            {
                return F.init(row.next() orelse return error.InvalidFormat) catch error.InvalidFormat;
            }

            @compileError("Unsupported field type: " ++ @typeName(F));
        },
        else => @compileError("Unsupported field type: " ++ @typeName(F)),
    }
}

pub const FetchAddError = error{
    InputOutput,
    CorruptedInteger,
};

// Performs a fetch-add operation on the file containing a decimal representation of `Int`.
// * Creates the file in case it doesn't exist
// * The caller must block cancelation requests
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

// Creates a File, and, if sub_path elements are missing, creates dir path as well.
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
