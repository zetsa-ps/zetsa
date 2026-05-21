pub const list: []const Entry = @import("tables/pet_grade");

const grade_ranges = gen: {
    var tmp: [list.len]struct {
        min: u32,
        max: u32,
        grade: Grade,
    } = undefined;

    for (list, 0..) |item, i| {
        tmp[i] = .{
            .min = item.grade[0],
            .max = item.grade[1],
            .grade = @enumFromInt(@as(u8, item.id)),
        };
    }

    break :gen tmp;
};

pub fn getById(id: u32) ?Entry {
    for (list) |g| if (g.id == id) return g;
    return null;
}

pub fn getPetGrade(score: u32) Grade {
    inline for (grade_ranges) |r| {
        if (score >= r.min and score <= r.max)
            return r.grade;
    }

    return .F;
}

pub fn getMinScore(grade: Grade) u32 {
    inline for (grade_ranges) |r| {
        if (r.grade == grade)
            return r.min;
    }

    return grade_ranges[0].min;
}

pub fn getMaxScore(grade: Grade) u32 {
    inline for (grade_ranges) |r| {
        if (r.grade == grade)
            return r.max;
    }

    return grade_ranges[0].max;
}

pub const Grade = gen: {
    var field_names: [list.len][:0]const u8 = undefined;
    var field_values: [list.len]u8 = undefined;

    for (list) |item| {
        if (item.id == 0 or item.id > list.len)
            @compileError("Invalid grade id (must be 1..N)");

        const i = item.id;

        field_names[i - 1] = item.name;
        field_values[i - 1] = @intCast(i);
    }

    break :gen @Enum(u8, .exhaustive, &field_names, &field_values);
};

pub const Entry = struct {
    id: u8,
    grade: [2]u32,
    grade_score: []const u8,
    grade_background: []const u8,
    icon: []const u8,
    icon_square: []const u8,
    pet_pixel_base: []const u8,
    pet_grade_frame: []const u8,
    name: [:0]const u8,
};
