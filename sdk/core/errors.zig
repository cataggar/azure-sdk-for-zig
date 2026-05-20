const std = @import("std");
const serde = @import("serde");
const http = @import("http/transport.zig");

/// Azure service error detail extracted from an HTTP response.
///
/// Owns its allocated `error_code` and `message` strings; call `deinit` to
/// release them.
pub const AzureError = struct {
    allocator: std.mem.Allocator,
    status_code: u16,
    error_code: ?[]const u8 = null,
    message: ?[]const u8 = null,

    pub fn deinit(self: *AzureError) void {
        if (self.error_code) |c| self.allocator.free(c);
        if (self.message) |m| self.allocator.free(m);
        self.error_code = null;
        self.message = null;
    }

    pub fn format(self: AzureError, writer: anytype) !void {
        try writer.print("AzureError(status={d}", .{self.status_code});
        if (self.error_code) |c| try writer.print(", code={s}", .{c});
        if (self.message) |m| try writer.print(", message={s}", .{m});
        try writer.writeAll(")");
    }
};

/// JSON shape of an Azure error envelope: `{ "error": { "code": "...", "message": "..." } }`.
const ErrorEnvelope = struct {
    @"error": ?ErrorBody = null,

    const ErrorBody = struct {
        code: ?[]const u8 = null,
        message: ?[]const u8 = null,
    };
};

/// Map an HTTP response to an `AzureError` if non-successful.
///
/// Tries to parse a JSON error body of the form:
/// ```json
/// { "error": { "code": "...", "message": "..." } }
/// ```
///
/// The returned `AzureError` owns its strings; call `deinit` to free them.
pub fn errorFromResponse(allocator: std.mem.Allocator, response: http.Response) ?AzureError {
    if (response.isSuccess()) return null;
    var err = AzureError{
        .allocator = allocator,
        .status_code = response.status_code,
    };

    // Use an arena for the parse, then dupe the strings we want to keep
    // into the caller-owned allocator.
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    if (serde.json.fromSlice(ErrorEnvelope, arena.allocator(), response.body)) |envelope| {
        if (envelope.@"error") |body| {
            if (body.code) |c| {
                err.error_code = allocator.dupe(u8, c) catch null;
            }
            if (body.message) |m| {
                err.message = allocator.dupe(u8, m) catch null;
            }
        }
    } else |_| {}

    return err;
}

/// Convenience wrapper: build an `AzureError`, write it to `std.log.warn`,
/// and free it. Use this from service-client code when a non-success
/// status arrives and you just want it surfaced to logs.
///
/// `.warn` (rather than `.err`) is used because HTTP non-success is often
/// expected by callers (404 existence checks, 412 conditional requests, etc.).
/// Callers that consider the failure fatal should propagate a Zig error
/// alongside this log.
pub fn logErrorResponse(response: http.Response) void {
    if (response.isSuccess()) return;
    if (errorFromResponse(response.allocator, response)) |maybe_err| {
        var e = maybe_err;
        defer e.deinit();
        std.log.warn("{f}", .{e});
    }
}

/// Tagged union over a successful response of type `T` or an Azure-side
/// error. Service-client `*Result` variants return this so callers can
/// branch on `AzureError.error_code` (e.g. retry on `"ServerBusy"`, fail
/// fast on `"AuthFailed"`) — the standard pattern in Azure SDKs for other
/// languages.
///
/// **Layered error model**
///
/// - The outer Zig error union (`!Result(T)`) carries *local* failures —
///   network errors, OOM, malformed responses, allocator failures. Use
///   normal `try`/`catch` for these.
/// - The `.err` variant carries *Azure-side* failures — any HTTP
///   non-2xx response whose body parsed as an Azure error envelope (or
///   didn't, in which case `error_code`/`message` are null but
///   `status_code` is still populated).
/// - The `.ok` variant carries the successful response value.
///
/// **Lifetime**
///
/// `Result.deinit(allocator)` frees both branches:
/// - On `.err`, it frees the `AzureError`'s strings.
/// - On `.ok`, if the payload type `T` declares
///   `pub fn deinit(self, allocator: std.mem.Allocator) void`, that
///   method is called; otherwise no-op. This lets callers write
///   `defer r.deinit(allocator);` once and trust both paths are
///   cleaned up.
///
/// **Example**
///
/// ```zig
/// var r = try client.getSecretResult(allocator, "name");
/// defer r.deinit(allocator);
/// switch (r) {
///     .ok => |secret| use(secret),
///     .err => |az_err| {
///         if (std.mem.eql(u8, az_err.error_code orelse "", "SecretNotFound")) {
///             // expected: secret didn't exist
///         } else {
///             return error.UnexpectedAzureFailure;
///         }
///     },
/// }
/// ```
pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: AzureError,

        const Self = @This();

        /// Free both the `AzureError` strings (on the `.err` path) and the
        /// payload's allocations (on the `.ok` path, if `T` declares a
        /// `deinit(self, allocator) void` method — comptime-detected).
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            switch (self.*) {
                .ok => |*payload| {
                    if (comptime hasPayloadDeinit(T)) payload.deinit(allocator);
                },
                .err => |*e| e.deinit(),
            }
        }

        /// Convenience for the common "succeeded?" check.
        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        /// Return the Azure error code if this is the `.err` variant
        /// and the response body contained an `error.code` field;
        /// `null` otherwise. Useful for branching:
        ///
        /// ```zig
        /// if (std.mem.eql(u8, r.errorCode() orelse "", "Throttled")) ...
        /// ```
        pub fn errorCode(self: Self) ?[]const u8 {
            return switch (self) {
                .ok => null,
                .err => |e| e.error_code,
            };
        }

        /// Convert this Result into the corresponding Zig error union:
        /// returns the `.ok` payload on success, or logs+deinits the
        /// `AzureError` and returns `fail_error` on Azure-side failure.
        ///
        /// Designed for the thin-wrapper pattern: a simple-form method
        /// like `getSecret(...) !KeyVaultSecret` calls the matching
        /// `getSecretResult` and then `return r.unwrap(error.X);`. Two
        /// lines instead of an explicit switch.
        ///
        /// Note: this consumes the `AzureError` strings via `deinit`,
        /// so callers cannot use `r` again afterward.
        pub fn unwrap(self: *Self, fail_error: anyerror) anyerror!T {
            switch (self.*) {
                .ok => |v| return v,
                .err => |*e| {
                    std.log.warn("{f}", .{e.*});
                    e.deinit();
                    return fail_error;
                },
            }
        }
    };
}

/// True if `T` has `pub fn deinit(self, allocator: std.mem.Allocator) void`.
/// Used by `Result(T).deinit` to dispatch to payload cleanup without forcing
/// every payload type to grow a deinit method.
fn hasPayloadDeinit(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!@hasDecl(T, "deinit")) return false;
    const Fn = @TypeOf(T.deinit);
    const info = @typeInfo(Fn);
    if (info != .@"fn") return false;
    const params = info.@"fn".params;
    return params.len == 2;
}

test "errorFromResponse success" {
    var resp = http.Response{
        .status_code = 200,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, "ok"),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    try std.testing.expect(errorFromResponse(std.testing.allocator, resp) == null);
}

test "errorFromResponse 404" {
    const body =
        \\{"error":{"code":"SecretNotFound","message":"Secret not found"}}
    ;
    var resp = http.Response{
        .status_code = 404,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, body),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    var err = errorFromResponse(std.testing.allocator, resp).?;
    defer err.deinit();
    try std.testing.expectEqual(@as(u16, 404), err.status_code);
    try std.testing.expectEqualStrings("SecretNotFound", err.error_code.?);
    try std.testing.expectEqualStrings("Secret not found", err.message.?);
}

test "errorFromResponse 500 no body" {
    var resp = http.Response{
        .status_code = 500,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, ""),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    var err = errorFromResponse(std.testing.allocator, resp).?;
    defer err.deinit();
    try std.testing.expectEqual(@as(u16, 500), err.status_code);
    try std.testing.expect(err.error_code == null);
    try std.testing.expect(err.message == null);
}

test "errorFromResponse malformed JSON" {
    var resp = http.Response{
        .status_code = 400,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, "not json at all"),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    var err = errorFromResponse(std.testing.allocator, resp).?;
    defer err.deinit();
    try std.testing.expectEqual(@as(u16, 400), err.status_code);
    try std.testing.expect(err.error_code == null);
}

test "errorFromResponse 429 throttled" {
    const body =
        \\{"error":{"code":"TooManyRequests","message":"Rate limit exceeded"}}
    ;
    var resp = http.Response{
        .status_code = 429,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, body),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    var err = errorFromResponse(std.testing.allocator, resp).?;
    defer err.deinit();
    try std.testing.expectEqual(@as(u16, 429), err.status_code);
    try std.testing.expectEqualStrings("TooManyRequests", err.error_code.?);
}

test "AzureError deinit frees strings" {
    var err = AzureError{
        .allocator = std.testing.allocator,
        .status_code = 500,
        .error_code = try std.testing.allocator.dupe(u8, "InternalServerError"),
        .message = try std.testing.allocator.dupe(u8, "boom"),
    };
    defer err.deinit();
    try std.testing.expectEqualStrings("InternalServerError", err.error_code.?);
}

test "logErrorResponse is a no-op on success" {
    var resp = http.Response{
        .status_code = 200,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, "ok"),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    // Should not log anything and should not allocate beyond what resp owns.
    logErrorResponse(resp);
}

test "Result.ok holds payload, deinit is a no-op when T has no deinit" {
    var r: Result(u32) = .{ .ok = 42 };
    defer r.deinit(std.testing.allocator);
    try std.testing.expect(r.isOk());
    try std.testing.expectEqual(@as(?[]const u8, null), r.errorCode());
    try std.testing.expectEqual(@as(u32, 42), r.ok);
}

test "Result.err carries AzureError and frees it on deinit" {
    var r: Result(u32) = .{ .err = .{
        .allocator = std.testing.allocator,
        .status_code = 429,
        .error_code = try std.testing.allocator.dupe(u8, "Throttled"),
        .message = try std.testing.allocator.dupe(u8, "Slow down"),
    } };
    defer r.deinit(std.testing.allocator);
    try std.testing.expect(!r.isOk());
    try std.testing.expectEqualStrings("Throttled", r.errorCode().?);
    try std.testing.expectEqual(@as(u16, 429), r.err.status_code);
}

test "Result.deinit dispatches to payload.deinit when present" {
    const Payload = struct {
        owned: []const u8,

        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            allocator.free(self.owned);
        }
    };
    var r: Result(Payload) = .{
        .ok = .{ .owned = try std.testing.allocator.dupe(u8, "data") },
    };
    defer r.deinit(std.testing.allocator);
    try std.testing.expect(r.isOk());
    try std.testing.expectEqualStrings("data", r.ok.owned);
    // testing.allocator catches leaks: if deinit didn't dispatch, this test
    // would fail with a "leaked 1 allocation" error.
}

test "Result.unwrap: .ok returns the value" {
    var r: Result(u32) = .{ .ok = 99 };
    const v = try r.unwrap(error.UnusedFail);
    try std.testing.expectEqual(@as(u32, 99), v);
}

test "Result.unwrap: .err deinits and returns supplied error" {
    var r: Result(u32) = .{ .err = .{
        .allocator = std.testing.allocator,
        .status_code = 403,
        .error_code = try std.testing.allocator.dupe(u8, "Forbidden"),
        .message = try std.testing.allocator.dupe(u8, "Access denied"),
    } };
    const got = r.unwrap(error.SecretNotFound);
    try std.testing.expectError(error.SecretNotFound, got);
    // unwrap deinits the AzureError on the .err path; testing.allocator
    // would flag a leak here if it didn't.
}
