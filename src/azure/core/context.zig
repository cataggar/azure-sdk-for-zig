/// Carries cancellation signals and trace context across API boundaries.
///
/// Deadline-based cancellation is left to callers who have access to
/// `std.Io`; this type provides a lightweight, IO-independent
/// cancellation token that can be threaded through the SDK.
pub const Context = struct {
    cancelled: bool = false,
    trace_id: ?[32]u8 = null,
    span_id: ?[16]u8 = null,

    pub const none = Context{};

    pub fn cancel(self: *Context) void {
        self.cancelled = true;
    }

    pub fn isCancelled(self: Context) bool {
        return self.cancelled;
    }

    /// Create a child context inheriting trace context.
    pub fn withTrace(self: Context, trace_id: [32]u8, span_id: [16]u8) Context {
        return .{
            .cancelled = self.cancelled,
            .trace_id = trace_id,
            .span_id = span_id,
        };
    }
};

const std = @import("std");

test "context none is never cancelled" {
    try std.testing.expect(!Context.none.isCancelled());
}

test "context cancel" {
    var ctx = Context{};
    try std.testing.expect(!ctx.isCancelled());
    ctx.cancel();
    try std.testing.expect(ctx.isCancelled());
}
