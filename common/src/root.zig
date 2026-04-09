pub fn printStartupSplash() void {
    std.debug.print(
        \\__________      __
        \\\____    /_____/  |_  ___________
        \\  /     // __ \   __\/  ___/\__  \
        \\ /     /\  ___/|  |  \___ \  / __ \_
        \\/_______ \___  >__| /____  >(____  /
        \\        \/   \/          \/      \/
        \\
    , .{});
}

pub const io = @import("io.zig");
pub const cli = @import("cli.zig");
pub const mem = @import("mem.zig");

const std = @import("std");
