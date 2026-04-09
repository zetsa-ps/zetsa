pub fn main(init: std.process.Init) void {
    const io = init.io;
    const gpa = init.gpa;

    const args = init.minimal.args.toSlice(init.arena.allocator()) catch
        fatal("couldn't obtain cli arguments", .{});

    if (args.len <= 1) fatal("no input files", .{});

    var stdout_buffer: [4096]u8 = undefined;
    var stdout = Io.File.writerStreaming(.stdout(), io, &stdout_buffer);

    writeOutputFileHeader(&stdout.interface) catch |err|
        fatal("couldn't write output: {t}", .{err});

    for (args[1..]) |path| {
        const content = Io.Dir.readFileAlloc(.cwd(), io, path, gpa, .unlimited) catch |err|
            fatal("couldn't read input file '{s}': {t}", .{ path, err });

        defer gpa.free(content);

        if (content[content.len - 1] != '\n')
            fatal("input file '{s}' doesn't have a terminating newline", .{path});

        var arena: std.heap.ArenaAllocator = .init(gpa);
        defer arena.deinit();

        writeGeneratedCodeForProto(arena.allocator(), &stdout.interface, content, path) catch |err|
            fatal("failed to generate code for '{s}': {t}", .{ path, err });
    }

    stdout.interface.flush() catch fatal("failed to write to stdout", .{});
}

fn writeOutputFileHeader(out: *Io.Writer) !void {
    try out.writeAll(
        \\const std = @import("std");
        \\
        \\pub const FieldDesc = struct {
        \\    number: u29,
        \\    encoding: enum {
        \\        normal,
        \\        zigzag,
        \\        fixed,
        \\    },
        \\    is_packed: bool,
        \\};
        \\
    );
}

fn writeGeneratedCodeForProto(
    arena: Allocator,
    out: *Io.Writer,
    input_proto: []const u8,
    input_path: []const u8,
) !void {
    try out.print("\n// {s}\n\n", .{input_path});
    var l: Lexer = .init(input_path, input_proto);

    while (!l.isAtEnd()) {
        const keyword = try l.expect(.keyword);
        switch (keyword.keyword) {
            .syntax => {
                try l.expectPunct(.equal_sign);
                const syntax = try l.expect(.quoted);
                if (!std.mem.eql(u8, syntax.quoted, "proto2")) {
                    std.log.err("{f}", .{Diagnostic.custom(&l, syntax, "unsupported syntax; this compiler only supports \"proto2\"")});
                    return error.UnsupportedSyntax;
                }
                try l.expectPunct(.semicolon);
            },
            .package => {
                while (true) {
                    _ = try l.expect(.name);
                    const p = try l.expect(.punct);
                    switch (p.punct) {
                        .semicolon => break,
                        .dot => continue,
                        else => {
                            std.log.err("{f}", .{Diagnostic.unexpected(&l, p)});
                            return error.UnexpectedToken;
                        },
                    }
                }
            },
            .option => {
                _ = try l.expect(.name);
                try l.expectPunct(.equal_sign);
                _ = try l.expect(.quoted);
                try l.expectPunct(.semicolon);
            },
            .import => {
                _ = try l.expect(.quoted);
                try l.expectPunct(.semicolon);
            },
            .@"enum" => try compileEnum(&l, .zero, out),
            .message => try compileMessage(arena, &l, .zero, out),
            else => {
                std.log.err("{f}", .{Diagnostic.unexpected(&l, keyword)});
                return error.UnexpectedToken;
            },
        }
    }
}

fn compileEnum(l: *Lexer, unscoped: Indentation, out: *Io.Writer) !void {
    const name = try l.expect(.name);
    const scoped = unscoped.increment();

    try out.print("{f}pub const {s} = enum(i32) {{\n", .{ unscoped, name.name });
    try l.expectPunct(.open_curly);

    while (true) {
        const token = try l.next() orelse return error.EndOfFile;
        if (std.meta.activeTag(token) == .punct and token.punct == .close_curly) break;

        if (std.meta.activeTag(token) != .name) {
            std.log.err("{f}", .{Diagnostic.unexpected(l, token)});
            return error.UnexpectedToken;
        }

        try l.expectPunct(.equal_sign);
        const discriminant = try l.expect(.number);
        try l.expectPunct(.semicolon);

        try out.print("{f}{s} = {s},\n", .{ scoped, token.name, discriminant.number });
    }

    try out.print("{f}}};\n\n", .{unscoped});
}

const Encoding = enum {
    normal,
    zigzag,
    fixed,
    pack,
};

const Primitive = enum {
    bool,
    int32,
    sint32,
    sint64,
    fixed32,
    sfixed32,
    fixed64,
    sfixed64,
    int64,
    uint32,
    uint64,
    string,
    bytes,
    float,
    double,

    pub fn format(p: Primitive, w: *Io.Writer) !void {
        try w.writeAll(switch (p) {
            .bool => "bool",
            .sint32 => "i32",
            .sint64 => "i64",
            .fixed32 => "u32",
            .fixed64 => "u64",
            .sfixed32 => "i32",
            .sfixed64 => "i64",
            .int32 => "i32",
            .int64 => "i64",
            .uint32 => "u32",
            .uint64 => "u64",
            .string, .bytes => "[]const u8",
            .float => "f32",
            .double => "f64",
        });
    }

    pub fn encoding(p: Primitive) Encoding {
        return switch (p) {
            .bool,
            .int32,
            .int64,
            .uint32,
            .uint64,
            .string,
            .bytes,
            .float,
            .double,
            => .normal,

            .sint32, .sint64 => .zigzag,

            .fixed32, .fixed64, .sfixed32, .sfixed64 => .fixed,
        };
    }
};

const FieldDesc = struct {
    name: []const u8,
    number: []const u8,
    encoding: Encoding,
    is_packed: bool,
};

const Indentation = enum(u32) {
    zero = 0,
    _,

    pub fn format(i: Indentation, writer: *Io.Writer) !void {
        try writer.splatByteAll(' ', i.toInt());
    }

    pub fn increment(i: Indentation) Indentation {
        return @enumFromInt(i.toInt() + 4);
    }

    pub fn toInt(i: Indentation) u32 {
        return @intFromEnum(i);
    }
};

const Field = struct {
    name: []const u8,
    modifier: Modifier,
    type: Type,

    pub const Type = union(enum) {
        primitive: Primitive,
        custom: []const u8,

        pub fn fromToken(t: Lexer.Token, l: *Lexer) !Field.Type {
            if (std.meta.activeTag(t) != .name) {
                std.log.err("{f}", .{Diagnostic.unexpected(l, t)});
                return error.UnexpectedToken;
            }

            return .{ .primitive = std.meta.stringToEnum(Primitive, t.name) orelse return .{ .custom = t.name } };
        }

        pub fn encoding(t: Type) Encoding {
            return switch (t) {
                .custom => .normal,
                .primitive => |p| p.encoding(),
            };
        }

        pub fn format(t: Type, writer: *Io.Writer) !void {
            switch (t) {
                .primitive => |p| try writer.print("{f}", .{p}),
                .custom => |string| try writer.print("{s}", .{string}),
            }
        }
    };

    pub const Modifier = enum {
        optional,
        required,
        repeated,

        pub fn fromToken(t: Lexer.Token, l: *Lexer) !Field.Modifier {
            if (std.meta.activeTag(t) != .keyword) {
                std.log.err("{f}", .{Diagnostic.unexpected(l, t)});
                return error.UnexpectedToken;
            }

            return switch (t.keyword) {
                .optional => .optional,
                .required => .required,
                .repeated => .repeated,
                else => {
                    std.log.err("{f}", .{Diagnostic.unexpected(l, t)});
                    return error.UnexpectedToken;
                },
            };
        }
    };

    pub fn format(field: Field, writer: *Io.Writer) !void {
        try writer.print("{s}: ", .{field.name});

        switch (field.modifier) {
            .required => try writer.print("{f}", .{field.type}),
            .optional => try writer.print("?{f} = null", .{field.type}),
            .repeated => try writer.print("std.ArrayList({f}) = .empty", .{field.type}),
        }
    }
};

fn compileMessage(arena: Allocator, l: *Lexer, unscoped: Indentation, out: *Io.Writer) !void {
    const name = try l.expect(.name);
    const scoped = unscoped.increment();

    try out.print("{f}pub const {s} = struct {{\n", .{ unscoped, name.name });
    try out.print("{f}pub const message_name = \"{s}\";\n", .{ scoped, name.name });

    try l.expectPunct(.open_curly);

    var field_descs: std.ArrayList(FieldDesc) = .empty;

    while (true) {
        const token = try l.next() orelse return error.EndOfFile;
        const token_kind = std.meta.activeTag(token);

        if (token_kind == .punct and token.punct == .close_curly) break;

        if (token_kind != .keyword) {
            std.log.err("{f}", .{Diagnostic.unexpected(l, token)});
            return error.UnexpectedToken;
        }

        switch (token.keyword) {
            .message => try compileMessage(arena, l, scoped, out),
            .@"enum" => try compileEnum(l, scoped, out),
            else => {
                const field: Field = .{
                    .modifier = try .fromToken(token, l),
                    .type = try .fromToken(try l.next() orelse return error.EndOfFile, l),
                    .name = try l.expectNameOrKeyword(),
                };

                try l.expectPunct(.equal_sign);
                const field_number = (try l.expect(.number)).number;

                const punct = try l.expectPuncts(&.{ .semicolon, .open_square });

                const is_packed = switch (punct) {
                    .semicolon => false,
                    .open_square => parse_attr: { // [packed = true];
                        const attr = try l.expect(.name);
                        if (!std.mem.eql(u8, attr.name, "packed")) {
                            std.log.err("{f}", .{Diagnostic.custom(l, attr, "unsupported field attribute")});
                            return error.UnexpectedToken;
                        }

                        try l.expectPunct(.equal_sign);

                        const boolean = try l.expect(.name);
                        if (!std.mem.eql(u8, boolean.name, "true")) {
                            std.log.err("{f}", .{Diagnostic.unexpected(l, boolean)});
                            return error.UnexpectedToken;
                        }

                        try l.expectPunct(.close_square);
                        try l.expectPunct(.semicolon);

                        break :parse_attr true;
                    },
                };

                try field_descs.append(arena, .{
                    .name = field.name,
                    .number = field_number,
                    .encoding = field.type.encoding(),
                    .is_packed = is_packed,
                });

                try out.print("{f}{f},\n", .{ scoped, field });
            },
        }
    }

    for (field_descs.items) |desc| {
        try out.print(
            "{f}pub const {s}_field_desc: FieldDesc = .{{ .number = {s}, .encoding = .{t}, .is_packed = {any} }};\n",
            .{ scoped, desc.name, desc.number, desc.encoding, desc.is_packed },
        );
    }

    try out.print("{f}}};\n\n", .{unscoped});
}

const Diagnostic = struct {
    where: Placement,
    kind: union(enum) {
        unexpected: Lexer.Token,
        custom: []const u8,
    },

    pub fn unexpected(l: *const Lexer, t: Lexer.Token) Diagnostic {
        return .{
            .where = .extract(l, t.size()),
            .kind = .{ .unexpected = t },
        };
    }

    pub fn custom(l: *const Lexer, t: Lexer.Token, message: []const u8) Diagnostic {
        return .{
            .where = .extract(l, t.size()),
            .kind = .{ .custom = message },
        };
    }

    pub fn customNoToken(l: *const Lexer, width: usize, message: []const u8) Diagnostic {
        return .{
            .where = .extract(l, width),
            .kind = .{ .custom = message },
        };
    }

    pub fn format(d: Diagnostic, w: *Io.Writer) !void {
        try w.print("{s}:{d}:{d}: ", .{ d.where.file, d.where.line, d.where.pos });
        switch (d.kind) {
            .unexpected => |token| {
                try w.print("unexpected {f}\n", .{token});
            },
            .custom => |message| {
                try w.print("{s}\n", .{message});
            },
        }

        try w.print("{s}\n", .{d.where.region});
        try w.splatByteAll(' ', d.where.pos);
        try w.splatByteAll('^', d.where.width);
        try w.writeByte('\n');
    }

    const Placement = struct {
        region: []const u8,
        file: []const u8,
        line: usize,
        pos: usize,
        width: usize,

        fn extract(l: *const Lexer, unit_width: usize) Placement {
            const cur_pos = l.start.len - l.content.len - unit_width;

            const line_end = cur_pos + unit_width + (std.mem.findScalar(u8, l.content, '\n') orelse l.content.len);
            const line_beginning = if (std.mem.findScalarLast(u8, l.start[0..cur_pos], '\n')) |nl| nl + 1 else 0;

            return .{
                .file = l.filename,
                .region = l.start[line_beginning..line_end],
                .line = l.line,
                .pos = cur_pos - line_beginning,
                .width = unit_width,
            };
        }
    };
};

const Lexer = struct {
    filename: []const u8,
    start: []const u8,
    content: []const u8,
    line: usize = 1,

    pub fn init(filename: []const u8, content: []const u8) Lexer {
        return .{ .filename = filename, .start = content, .content = content };
    }

    pub fn isAtEnd(l: *Lexer) bool {
        l.skipWhitespaces();
        return l.content.len == 0;
    }

    pub fn next(l: *Lexer) !?Token {
        if (l.isAtEnd()) return null;

        if (std.enums.fromInt(Token.Punct, l.content[0])) |punct| {
            l.content = l.content[1..];
            return .{ .punct = punct };
        }

        switch (l.content[0]) {
            '-', '0'...'9' => return .{ .number = l.consumeNumber() },
            'a'...'z', 'A'...'Z', '_' => {
                const name = l.consumeName();
                return if (std.meta.stringToEnum(Token.Keyword, name)) |keyword|
                    .{ .keyword = keyword }
                else
                    .{ .name = name };
            },
            '"' => return .{ .quoted = try l.consumeEnclosed('"') },
            else => {
                l.content = l.content[1..];
                std.log.err("{f}", .{Diagnostic.customNoToken(l, 1, "unexpected character")});
                return error.UnexpectedCharacter;
            },
        }
    }

    pub fn expectPunct(l: *Lexer, expected: Token.Punct) !void {
        const p = try l.expect(.punct);
        if (p.punct != expected) {
            std.log.err("{f}", .{Diagnostic.unexpected(l, p)});
            return error.UnexpectedToken;
        }
    }

    pub fn expect(l: *Lexer, expected_kind: std.meta.Tag(Token)) !Token {
        const t = try l.next() orelse return error.EndOfFile;

        if (std.meta.activeTag(t) != expected_kind) {
            std.log.err("{f}", .{Diagnostic.unexpected(l, t)});
            return error.UnexpectedToken;
        }

        return t;
    }

    pub fn expectPuncts(l: *Lexer, comptime variants: []const Token.Punct) !Token.Punct.Restricted(variants) {
        const R = Token.Punct.Restricted(variants);
        const t = try l.expect(.punct);

        return std.enums.fromInt(R, @intFromEnum(t.punct)) orelse {
            std.log.err("{f}", .{Diagnostic.unexpected(l, t)});
            return error.UnexpectedToken;
        };
    }

    // apparently, field names can consist of keywords...
    pub fn expectNameOrKeyword(l: *Lexer) ![]const u8 {
        switch (try l.next() orelse return error.EndOfFile) {
            .name => |name| return name,
            .keyword => |keyword| return @tagName(keyword),
            else => |t| {
                std.log.err("{f}", .{Diagnostic.unexpected(l, t)});
                return error.UnexpectedToken;
            },
        }
    }

    fn consumeNumber(l: *Lexer) []const u8 {
        const start = l.content;
        l.content = l.content[1..]; // checked in main.zig:0/fn(.)next
        while (l.content.len > 0) : (l.content = l.content[1..]) {
            switch (l.content[0]) {
                '0'...'9' => continue,
                else => break,
            }
        }

        return start[0 .. start.len - l.content.len];
    }

    fn consumeName(l: *Lexer) []const u8 {
        const start = l.content;
        while (l.content.len > 0) : (l.content = l.content[1..]) {
            switch (l.content[0]) {
                'a'...'z', 'A'...'Z', '0'...'9', '_', '.' => continue,
                else => break,
            }
        }

        return start[0 .. start.len - l.content.len];
    }

    fn consumeEnclosed(l: *Lexer, c: u8) ![]const u8 {
        l.content = l.content[1..]; // checked in main.zig:0/fn(.)next
        const start = l.content;

        while (l.content.len > 0) : (l.content = l.content[1..]) {
            if (l.content[0] == c) break;
        } else return error.UnclosedLiteral;

        l.content = l.content[1..];
        return start[0 .. start.len - l.content.len - 1];
    }

    fn skipWhitespaces(l: *Lexer) void {
        var skipping_line: bool = false; // indicates if we're skipping the rest of line (due to '//')

        while (l.content.len > 0) : (l.content = l.content[1..]) {
            switch (l.content[0]) {
                ' ', '\r', '\t' => continue,
                '\n' => {
                    l.line += 1;
                    skipping_line = false;
                },
                '/' => if (skipping_line) continue else if (l.content.len >= 2 and l.content[1] == '/') {
                    skipping_line = true;
                } else break,
                else => if (!skipping_line) break,
            }
        }
    }

    pub const Token = union(enum) {
        number: []const u8,
        name: []const u8,
        quoted: []const u8,
        keyword: Keyword,
        punct: Punct,

        pub const Keyword = enum {
            syntax,
            package,
            import,
            option,
            message,
            @"enum",
            optional,
            required,
            repeated,
        };

        pub const Punct = enum(u8) {
            semicolon = ';',
            open_curly = '{',
            close_curly = '}',
            equal_sign = '=',
            comma = ',',
            dot = '.',
            open_paren = '(',
            close_paren = ')',
            open_square = '[',
            close_square = ']',

            pub fn Restricted(comptime variants: []const Punct) type {
                var field_names: []const []const u8 = &.{};
                inline for (variants) |variant|
                    field_names = field_names ++ .{@tagName(variant)};

                var field_values: [field_names.len]u8 = undefined;
                inline for (variants, 0..) |variant, i|
                    field_values[i] = @intFromEnum(variant);

                return @Enum(u8, .exhaustive, field_names, &field_values);
            }
        };

        pub fn size(t: Token) usize {
            return switch (t) {
                .punct => 1,
                .quoted => |string| string.len + 2,
                .number, .name => |content| content.len,
                .keyword => |keyword| switch (keyword) {
                    inline else => |tag| @tagName(tag).len,
                },
            };
        }

        pub fn format(t: Token, w: *Io.Writer) !void {
            switch (t) {
                .punct => |p| try w.print("'{c}'", .{@intFromEnum(p)}),
                .quoted => |s| try w.print("\"{s}\"", .{s}),
                .name, .number => |n| try w.print("'{s}'", .{n}),
                .keyword => |kw| try w.print("'{s}'", .{@tagName(kw)}),
            }
        }
    };
};

const Io = std.Io;
const Allocator = std.mem.Allocator;

const fatal = std.process.fatal;

const std = @import("std");
