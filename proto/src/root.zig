pub const DecodeError = Io.Reader.Error || ReadVarIntError || Allocator.Error || error{
    InvalidWireType,
    InvalidEnumVariant,
};

pub fn decode(comptime Message: type, arena: Allocator, reader: *Io.Reader) DecodeError!Message {
    @setEvalBranchQuota(100_000);
    const fields = @typeInfo(Message).@"struct".fields;
    if (fields.len == 0) return .{};

    const FieldNumber = comptime blk: {
        var field_names: [fields.len][:0]const u8 = undefined;
        var field_numbers: [fields.len]u32 = undefined;

        for (fields, 0..) |field, i| {
            field_names[i] = field.name;
            field_numbers[i] = @field(Message, field.name ++ "_field_desc").number;
        }

        break :blk @Enum(u32, .exhaustive, &field_names, &field_numbers);
    };

    var result: Message = undefined;

    inline for (fields) |field| if (field.defaultValue()) |val| {
        @field(result, field.name) = val;
    };

    while (readVarInt(reader, u32) catch null) |wt_int| {
        const wt: WireTag = @bitCast(wt_int);
        const field_number = std.enums.fromInt(FieldNumber, wt.field_number) orelse {
            try skipField(reader, wt.wire_type);
            continue;
        };

        switch (field_number) {
            inline else => |number| {
                const field_name = @tagName(number);
                const desc = @field(Message, field_name ++ "_field_desc");
                const FieldType = @FieldType(Message, field_name);

                if (Repeated(FieldType)) |Item| {
                    if (desc.is_packed) {
                        const length = try readVarInt(reader, usize); // packed list of scalar values

                        var limited_buf: [128]u8 = undefined;
                        var limited = reader.limited(.limited(length), &limited_buf);
                        while (decodeField(&limited.interface, arena, Item, desc.encoding, .of(Item)) catch null) |value|
                            try @field(result, field_name).append(arena, value);
                    } else {
                        const item = try decodeField(reader, arena, Item, desc.encoding);
                        try @field(result, field_name).append(arena, item);
                    }
                } else {
                    @field(result, field_name) = try decodeField(reader, arena, FieldType, desc.encoding);
                }
            },
        }
    }

    return result;
}

fn decodeField(
    r: *Io.Reader,
    arena: Allocator,
    comptime T: type,
    comptime encoding: anytype,
) DecodeError!T {
    if (Optional(T)) |C|
        return try decodeField(r, arena, C, encoding)
    else if (T == []const u8) {
        const len = try readVarInt(r, usize);
        return try r.readAlloc(arena, len);
    } else switch (@typeInfo(T)) {
        .int => return switch (encoding) {
            .normal => try readVarInt(r, T),
            .zigzag => zag(try readVarInt(r, T)),
            .fixed => try r.takeInt(T, .little),
        },
        .bool => return (try readVarInt(r, u8)) != 0,
        .float => |float| return @bitCast(try r.takeInt(@Int(.unsigned, float.bits), .little)),
        .@"enum" => return std.enums.fromInt(T, try readVarInt(r, i32)) orelse error.InvalidEnumVariant,
        .@"struct" => {
            const length = try readVarInt(r, usize);

            var limited_buf: [128]u8 = undefined;
            var limited = r.limited(.limited(length), &limited_buf);

            return try decode(T, arena, &limited.interface);
        },
        else => @compileError("unsupported type: " ++ @typeName(T)),
    }
}

pub fn encode(w: *Io.Writer, message: anytype) Io.Writer.Error!void {
    @setEvalBranchQuota(100_000);

    const Message = @TypeOf(message);
    inline for (@typeInfo(Message).@"struct".fields) |field| {
        const desc = @field(Message, field.name ++ "_field_desc");
        try encodeField(w, field.type, @field(message, field.name), desc);
    }
}

pub fn encodingLength(message: anytype) usize {
    var buf: [128]u8 = undefined;
    var discarding: Io.Writer.Discarding = .init(&buf);
    encode(&discarding.writer, message) catch unreachable;

    return discarding.fullCount();
}

fn encodeField(w: *Io.Writer, comptime F: type, value: F, comptime desc: anytype) Io.Writer.Error!void {
    const tag: WireTag = .{
        .wire_type = .of(F, desc.encoding),
        .field_number = desc.number,
    };

    if (Optional(F)) |Child| {
        return encodeField(w, Child, value orelse return, desc);
    } else if (Repeated(F)) |Item| {
        for (value.items) |item| try encodeField(w, Item, item, desc);
    } else {
        try writeVarInt(w, u32, @bitCast(tag));
        switch (@typeInfo(F)) {
            .int => switch (desc.encoding) {
                .normal => try writeVarInt(w, F, value),
                .fixed => try w.writeInt(F, value, .little),
                .zigzag => try writeVarInt(w, F, zig(value)),
            },
            .float => |float| try w.writeInt(@Int(.unsigned, float.bits), @bitCast(value), .little),
            .bool => try writeVarInt(w, i32, @intFromBool(value)),
            .@"enum" => try writeVarInt(w, i32, @intFromEnum(value)),
            .@"struct" => {
                try writeVarInt(w, u64, encodingLength(value));
                try encode(w, value);
            },
            else => switch (F) {
                []const u8, []u8 => {
                    try writeVarInt(w, u64, value.len);
                    try w.writeAll(value);
                },
                else => @compileError("unsupported type: " ++ @typeName(F)),
            },
        }
    }
}

const WireTag = packed struct(u32) {
    wire_type: WireType,
    field_number: u29,
};

const WireType = enum(u3) {
    var_int = 0,
    int64 = 1,
    length_prefixed = 2,
    int32 = 5,
    _,

    pub fn of(comptime T: type, comptime encoding: anytype) WireType {
        return switch (@typeInfo(T)) {
            .int => |int| switch (encoding) {
                .normal, .zigzag => .var_int,
                .fixed => switch (int.bits) {
                    32 => .int32,
                    64 => .int64,
                    else => @compileError("invalid integer type for fixed-length encoding: " ++ @typeName(T)),
                },
            },
            .bool, .@"enum" => .var_int,
            .float => |float| return switch (float.bits) {
                32 => .int32,
                64 => .int64,
                else => @compileError("unsupported float type: " ++ @typeName(T)),
            },
            .pointer => switch (T) {
                []const u8, []u8 => .length_prefixed,
                else => @compileError("unsupported type: " ++ @typeName(T)),
            },
            .optional => |container| of(container.child, encoding),
            .@"struct" => .length_prefixed,
            else => @compileError("unsupported type: " ++ @typeName(T)),
        };
    }
};

pub const ReadVarIntError = error{VarIntOverflow} || Io.Reader.Error;

fn readVarInt(r: *Io.Reader, comptime T: type) ReadVarIntError!T {
    const int = @typeInfo(T).int;
    var shift: std.math.Log2Int(u64) = 0;
    var result: u64 = 0;

    while (true) : (shift += 7) {
        const byte = try r.takeByte();
        result |= @as(u64, byte & 0x7F) << shift;
        if ((byte & 0x80) != 0x80) return switch (int.signedness) {
            .unsigned => @truncate(result),
            .signed => @bitCast(@as(@Int(.unsigned, int.bits), @truncate(result))),
        };

        if (shift >= @bitSizeOf(u64) - 7) return error.VarIntOverflow;
    }
}

fn writeVarInt(w: *Io.Writer, comptime Int: type, int: Int) Io.Writer.Error!void {
    var v = int;
    while (v >= 0x80) : (v >>= 7) {
        try w.writeByte(@intCast(0x80 | (v & 0x7F)));
    } else try w.writeByte(@intCast(v & 0x7F));
}

fn skipField(r: *Io.Reader, wire_type: WireType) DecodeError!void {
    switch (wire_type) {
        .var_int => _ = try readVarInt(r, u64),
        .int32 => try r.discardAll(4),
        .int64 => try r.discardAll(8),
        .length_prefixed => try r.discardAll(try readVarInt(r, usize)),
        _ => return error.InvalidWireType,
    }
}

inline fn zig(v: anytype) @TypeOf(v) {
    const int = @typeInfo(@TypeOf(v)).int;
    comptime debug.assert(int.signedness == .signed);
    return (v << 1) ^ (v >> int.bits - 1);
}

inline fn zag(v: anytype) @TypeOf(v) {
    comptime debug.assert(@typeInfo(@TypeOf(v)).int.signedness == .signed);
    return (v >> 1) ^ -(v & 1);
}

fn Repeated(comptime T: type) ?type {
    return switch (@typeInfo(T)) {
        .@"struct" => if (@hasField(T, "items")) switch (@typeInfo(@FieldType(T, "items"))) {
            .pointer => |pointer| if (T == std.ArrayList(pointer.child)) return pointer.child else null,
            else => null,
        } else null,
        else => null,
    };
}

fn Optional(comptime T: type) ?type {
    return switch (@typeInfo(T)) {
        .optional => |optional| optional.child,
        else => null,
    };
}

pub const pb = @import("azur_generated");
pub const CSProtoIDType = @import("constants.zig").CSProtoIDType;
pub const ErrCode = @import("constants.zig").ErrCode;

const Io = std.Io;
const Allocator = std.mem.Allocator;

const meta = std.meta;
const debug = std.debug;

const std = @import("std");
