var userCallback: *const fn () void = undefined; // Populated by `setup`.

pub fn setup(callback: *const fn () void) void {
    userCallback = callback;
    switch (native_os) {
        .windows => registerWindows(),
        else => registerPosix(),
    }
}

fn registerPosix() void {
    _ = posix.system.sigaction(.INT, &.{
        .handler = .{ .handler = posixCallback },
        .mask = std.mem.zeroes(@FieldType(posix.Sigaction, "mask")),
        .flags = 0,
    }, null);
}

fn registerWindows() void {
    _ = SetConsoleCtrlHandler(windowsCallback, .TRUE);
}

fn posixCallback(_: posix.SIG) callconv(.c) void {
    userCallback();
}

fn windowsCallback(ctrl_type: windows.DWORD) callconv(.winapi) windows.BOOL {
    if (ctrl_type != CTRL_C_EVENT) return .FALSE;

    userCallback();
    return .TRUE;
}

extern "kernel32" fn SetConsoleCtrlHandler(
    handler_routine: *const fn (windows.DWORD) callconv(.winapi) windows.BOOL,
    add: windows.BOOL,
) windows.BOOL;

const CTRL_C_EVENT: windows.DWORD = 0;

const posix = std.posix;
const windows = std.os.windows;
const native_os = builtin.os.tag;

const builtin = @import("builtin");
const std = @import("std");
const Termination = @This();
