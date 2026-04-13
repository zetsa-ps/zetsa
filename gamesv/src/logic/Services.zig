battle: Battle,

pub const init: Services = .{
    .battle = .init,
};

pub fn deinit(services: *Services, gpa: Allocator) void {
    services.battle.deinit(gpa);
}

pub const Battle = @import("Services/Battle.zig");

const Allocator = std.mem.Allocator;

const std = @import("std");
const Services = @This();
