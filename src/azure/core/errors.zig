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
