pub const OpenID = LimitedString(127);

player_id: u32,

pub const FetchError = error{
    NotFound,
    Corrupted,
    InputOutput,
} || SanitizeOpenIDError || Io.Cancelable;

pub fn fetch(io: Io, open_id: *const OpenID) FetchError!Account {
    try sanitizeOpenID(open_id);

    var path_buf: [max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "store/account/by-open-id/{s}", .{open_id.view()}) catch
        return error.InvalidOpenID;

    const file = Dir.openFile(.cwd(), io, path, .{}) catch |err| return switch (err) {
        error.Canceled => |e| e,
        error.FileNotFound => error.NotFound,
        else => error.InputOutput,
    };

    defer file.close(io);

    var fr_buf: [1024]u8 = undefined;
    var fr = file.reader(io, &fr_buf);

    var account: Account = undefined;

    store.parseAttrset(Account, &fr.interface, &account) catch |err| return switch (err) {
        error.ReadFailed => switch (fr.err.?) {
            error.Canceled => |e| e,
            else => error.InputOutput,
        },
        else => error.Corrupted,
    };

    return account;
}

pub const CreateError = error{
    InputOutput,
} || SanitizeOpenIDError;

pub fn create(io: Io, open_id: *const OpenID) CreateError!Account {
    try sanitizeOpenID(open_id);

    const old_cancel_protection = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(old_cancel_protection);

    const player_id = store.fetchAdd(u32, io, "store/account/counter", 1) catch
        return error.InputOutput;

    const account: Account = .{ .player_id = player_id };

    var path_buf: [max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "store/account/by-open-id/{s}", .{open_id.view()}) catch
        return error.InvalidOpenID;

    const file = store.createFilePath(io, .cwd(), path) catch return error.InputOutput;
    defer file.close(io);

    var fw_buf: [1024]u8 = undefined;
    var fw = file.writer(io, &fw_buf);

    store.writeAttrset(Account, &fw.interface, &account) catch return error.InputOutput;

    return account;
}

pub const SanitizeOpenIDError = error{InvalidOpenID};

fn sanitizeOpenID(open_id: *const OpenID) SanitizeOpenIDError!void {
    for (open_id.view()) |char| if (!std.ascii.isAlphanumeric(char))
        return error.InvalidOpenID;
}

const Io = std.Io;
const Dir = std.Io.Dir;
const LimitedString = common.mem.LimitedString;

const max_path_bytes = std.fs.max_path_bytes;

const store = @import("../store.zig");

const common = @import("common");
const std = @import("std");
const Account = @This();
