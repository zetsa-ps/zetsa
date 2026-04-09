// The `slice` should *not* include argv0.
pub fn parseArguments(comptime Args: type, slice: []const [:0]const u8, diagnostic: *Diagnostic) ?Args {
    const fields = @typeInfo(Args).@"struct".fields;
    comptime var field_names: [fields.len][:0]const u8 = undefined;
    comptime var flags: [fields.len]u8 = undefined;

    inline for (fields, 0..) |field, i| {
        flags[i] = field.name[0];
        field_names[i] = field.name;
    }

    const Flag = @Enum(u8, .exhaustive, &field_names, &flags);

    var result: Args = .{};

    var arg_stack_buffer: [fields.len]Flag = undefined;
    var arg_stack = std.ArrayList(Flag).initBuffer(arg_stack_buffer[0..]);

    for (slice) |arg| {
        if (arg[0] == '-') {
            for (arg[1..]) |char| {
                const flag = std.enums.fromInt(Flag, char) orelse {
                    diagnostic.* = .{ .invalid_option = char };
                    return null;
                };

                switch (flag) {
                    inline else => |f| if (@FieldType(Args, @tagName(f)) != bool)
                        arg_stack.appendBounded(flag) catch {
                            diagnostic.* = .too_much_options;
                            return null;
                        },
                }
            }
        } else {
            if (arg_stack.items.len == 0) {
                diagnostic.* = .{ .redundant_argument = arg };
                return null;
            }

            switch (arg_stack.swapRemove(0)) {
                inline else => |flag| if (@FieldType(Args, @tagName(flag)) == []const u8) {
                    @field(result, @tagName(flag)) = arg;
                } else {
                    diagnostic.* = .{ .redundant_argument = arg };
                    return null;
                },
            }
        }
    }

    if (arg_stack.items.len != 0) {
        diagnostic.* = .{ .missing_argument = @intFromEnum(arg_stack.items[0]) };
        return null;
    }

    return result;
}

pub const Diagnostic = union(enum) {
    invalid_option: u8,
    too_much_options: void,
    redundant_argument: []const u8,
    missing_argument: u8,

    pub fn format(diagnostic: Diagnostic, writer: *Io.Writer) !void {
        return switch (diagnostic) {
            .invalid_option => |char| writer.print("invalid option -- '{c}'", .{char}),
            .too_much_options => writer.writeAll("too much options encountered"),
            .redundant_argument => |str| writer.print("unexpected trailing argument -- '{s}'", .{str}),
            .missing_argument => |char| writer.print("option requires an argument -- '{c}'", .{char}),
        };
    }
};

pub fn Usage(comptime Args: type) type {
    return struct {
        const usage_string = blk: {
            const fields = @typeInfo(Args).@"struct".fields;
            var fmt: []const u8 = "";

            for (fields) |field| if (field.type == bool) {
                if (fmt.len == 0) fmt = "[-";
                fmt = fmt ++ .{field.name[0]};
            };

            if (fmt.len != 0) fmt = fmt ++ "]";

            for (fields) |field| if (field.type == []const u8) {
                if (fmt.len != 0) fmt = fmt ++ " ";
                fmt = fmt ++ "[-" ++ .{field.name[0]} ++ " " ++ field.name ++ "]";
            };

            break :blk fmt;
        };

        pub fn format(writer: *Io.Writer) !void {
            return writer.writeAll(usage_string);
        }
    };
}

const Io = std.Io;
const std = @import("std");
