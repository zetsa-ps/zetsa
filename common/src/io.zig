var shutdown_handler_active = false;

// Runs the provided function as a concurrent task, canceling it on shutdown request.
pub fn runUntilShutdown(
    io: Io,
    comptime function: anytype,
    args: meta.ArgsTuple(@TypeOf(function)),
) @typeInfo(@TypeOf(function)).@"fn".return_type.? {
    const Function = @TypeOf(function);
    const Result = @typeInfo(Function).@"fn".return_type.?;
    const Args = meta.ArgsTuple(Function);

    debug.assert(
        // runUntilShutdown can only be called once.
        !@atomicRmw(bool, &shutdown_handler_active, .Xchg, true, .seq_cst),
    );

    const wrap = struct {
        var future_guard: bool = false;
        var future_io: Io = undefined;
        var future: Io.Future(void) = undefined;

        var result_buf: [1]Result = undefined;
        var result: Io.Queue(Result) = .init(&result_buf);

        fn onShutdown() void {
            if (!@atomicRmw(bool, &future_guard, .Xchg, true, .seq_cst)) {
                future.cancel(future_io);
            }
        }

        fn concurrentWrap(a: Args) void {
            result.putOneUncancelable(
                future_io,
                @call(.auto, function, a),
            ) catch |err| switch (err) {
                error.Closed => unreachable,
            };
        }
    };

    wrap.future_io = io;
    wrap.future = io.concurrent(wrap.concurrentWrap, .{args}) catch {
        // Fallback to non-concurrent call without shutdown handling.
        // TODO: should we return ConcurrencyUnavailable and give a chance to user to handle it instead?
        return @call(.auto, function, args);
    };

    // Free resources associated with the `future`.
    defer if (!@atomicRmw(bool, &wrap.future_guard, .Xchg, true, .seq_cst)) {
        wrap.future.await(io);
    };

    termination.setup(&wrap.onShutdown);
    return wrap.result.getOneUncancelable(io) catch |err| switch (err) {
        error.Closed => unreachable,
    };
}

const RunWithTimeoutError = Io.Timeout.Error || Io.Cancelable || Io.ConcurrentError;

// Extends callee's return type to contain the appropriate errors.
fn RunWithTimeoutResult(comptime Result: type) type {
    return switch (@typeInfo(Result)) {
        .error_union => |u| (RunWithTimeoutError || u.error_set)!u.payload,
        else => |T| RunWithTimeoutError!T,
    };
}

// Spawns a new `concurrent` task and waits until its completion with a specified `timeout`.
// This API is similar to `std.Io.operateTimeout`, except it accepts an actual function.
pub fn runWithTimeout(
    io: Io,
    timeout: Io.Timeout,
    function: anytype,
    args: std.meta.ArgsTuple(@TypeOf(function)),
) RunWithTimeoutResult(@typeInfo(@TypeOf(function)).@"fn".return_type.?) {
    const Args = @TypeOf(args);
    const Result = @typeInfo(@TypeOf(function)).@"fn".return_type.?;
    const ExtendedResult = RunWithTimeoutResult(Result);

    const Awaiter = struct {
        io: Io,
        event: Io.Event,
        result: Result,

        pub fn complete(awaiter: *@This(), result: Result) void {
            awaiter.result = result;
            awaiter.event.set(awaiter.io);
        }
    };

    const Wrapped = struct {
        fn start(awaiter: *Awaiter, start_args: Args) void {
            awaiter.complete(@call(.auto, function, start_args));
        }
    };

    var awaiter: Awaiter = .{ .io = io, .event = .unset, .result = undefined };
    var future = try io.concurrent(Wrapped.start, .{ &awaiter, args });

    awaiter.event.waitTimeout(io, timeout) catch |wait_err| switch (wait_err) {
        error.Canceled, error.Timeout => {
            future.cancel(io);

            return switch (@typeInfo(Result)) {
                .error_union => awaiter.result catch |child_err| switch (@as(
                    @typeInfo(ExtendedResult).error_union.error_set,
                    child_err,
                )) {
                    error.Canceled, error.Timeout => wait_err,
                    else => |e| return e,
                },
                else => awaiter.result,
            };
        },
    };

    future.await(io); // Cleanup associated resources
    return awaiter.result;
}

const Io = std.Io;

const meta = std.meta;
const debug = std.debug;

const termination = @import("io/termination.zig");
const std = @import("std");
