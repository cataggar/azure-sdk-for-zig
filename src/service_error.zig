//! Azure DevOps service errors.
//!
//! Azure DevOps does not use the `{"error":{"code","message"}}` envelope
//! the rest of Azure uses. It returns a flat object keyed by `typeKey`
//! and `errorCode`, and — for a signed-out or PAT-scoped-out caller —
//! frequently answers with `203 Non-Authoritative Information` and an
//! HTML sign-in page rather than a `401`. Callers that only check for
//! `401` therefore see a "successful" response containing HTML, so this
//! module classifies that case explicitly.

const std = @import("std");

/// The error body Azure DevOps returns for a failed REST call.
pub const ServiceErrorInfo = struct {
    /// Human-readable message. Always present in practice.
    message: ?[]const u8 = null,
    /// Server-side exception type, e.g.
    /// `GitRepositoryNotFoundException`. More stable than `message` for
    /// programmatic matching.
    typeKey: ?[]const u8 = null,
    typeName: ?[]const u8 = null,
    errorCode: ?i64 = null,
    eventId: ?i64 = null,
};

pub const ServiceError = struct {
    status_code: u16,
    info: ServiceErrorInfo,
    /// The raw body, retained because Azure DevOps sometimes answers
    /// with HTML instead of JSON.
    body: []const u8,
    /// Owns `body` and any strings inside `info`.
    arena: std.heap.ArenaAllocator,

    pub fn deinit(self: *ServiceError) void {
        self.arena.deinit();
        self.* = undefined;
    }

    /// True when the response is Azure DevOps' sign-in redirect, which
    /// means the credential is missing, expired, or lacks the scope the
    /// operation requires — not that the request succeeded.
    pub fn isSignInRedirect(self: ServiceError) bool {
        return isSignInPage(self.status_code, self.body);
    }
};

/// Azure DevOps answers unauthenticated browser-shaped requests with
/// `203` and a sign-in page instead of `401`. Treat that as an auth
/// failure rather than a success.
pub fn isSignInPage(status_code: u16, body: []const u8) bool {
    if (status_code != 203) return false;
    return std.mem.indexOf(u8, body, "<html") != null or
        std.mem.indexOf(u8, body, "<!DOCTYPE html") != null or
        std.mem.indexOf(u8, body, "Azure DevOps Services | Sign In") != null;
}

/// Parse an Azure DevOps error body. Bodies that are not JSON — the
/// sign-in page, or a proxy's plain-text error — still produce a
/// `ServiceError` carrying the status and the raw body.
pub fn parse(
    allocator: std.mem.Allocator,
    status_code: u16,
    body: []const u8,
) !ServiceError {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();
    const owned_body = try arena_allocator.dupe(u8, body);

    const info = std.json.parseFromSliceLeaky(
        ServiceErrorInfo,
        arena_allocator,
        owned_body,
        .{ .ignore_unknown_fields = true },
    ) catch ServiceErrorInfo{};

    return .{
        .status_code = status_code,
        .info = info,
        .body = owned_body,
        .arena = arena,
    };
}

test "a typed Azure DevOps error body is parsed" {
    const body =
        \\{"$id":"1","innerException":null,
        \\"message":"TF401019: The Git repository with name or identifier x does not exist.",
        \\"typeName":"Microsoft.TeamFoundation.Git.Server.GitRepositoryNotFoundException",
        \\"typeKey":"GitRepositoryNotFoundException","errorCode":0,"eventId":3000}
    ;
    var err = try parse(std.testing.allocator, 404, body);
    defer err.deinit();
    try std.testing.expectEqual(@as(u16, 404), err.status_code);
    try std.testing.expectEqualStrings("GitRepositoryNotFoundException", err.info.typeKey.?);
    try std.testing.expectEqual(@as(i64, 3000), err.info.eventId.?);
}

test "a non-JSON body still yields the status and raw body" {
    var err = try parse(std.testing.allocator, 502, "<html>bad gateway</html>");
    defer err.deinit();
    try std.testing.expectEqual(@as(u16, 502), err.status_code);
    try std.testing.expect(err.info.message == null);
    try std.testing.expectEqualStrings("<html>bad gateway</html>", err.body);
}

test "a 203 sign-in page is classified as an auth failure, not a success" {
    var err = try parse(
        std.testing.allocator,
        203,
        "<!DOCTYPE html><html><title>Azure DevOps Services | Sign In</title></html>",
    );
    defer err.deinit();
    try std.testing.expect(err.isSignInRedirect());

    var other = try parse(std.testing.allocator, 203, "{\"count\":0}");
    defer other.deinit();
    try std.testing.expect(!other.isSignInRedirect());
}
