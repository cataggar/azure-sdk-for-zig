/// Carries cancellation signals across API boundaries.
///
/// Deadline-based cancellation is left to callers who have access to
/// `std.Io`; this type provides a lightweight, IO-independent
/// cancellation token that can be threaded through the SDK.
pub const Context = struct {
    cancelled: bool = false,

    pub const none = Context{};

    pub fn cancel(self: *Context) void {
        self.cancelled = true;
    }

    pub fn isCancelled(self: Context) bool {
        return self.cancelled;
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
