const std = @import("std");
const context_mod = @import("../context.zig");

/// An OAuth2 access token with expiry.
pub const AccessToken = struct {
    token: []const u8,
    /// Unix timestamp in seconds when the token expires.
    expires_on: i64,
};

/// Scopes to request when obtaining a token.
pub const TokenRequestContext = struct {
    scopes: []const []const u8,
};

/// Abstract credential — any type that can produce an access token.
pub const TokenCredential = struct {
    getTokenFn: *const fn (
        self: *TokenCredential,
        request_context: TokenRequestContext,
        ctx: context_mod.Context,
    ) anyerror!AccessToken,

    pub fn getToken(
        self: *TokenCredential,
        request_context: TokenRequestContext,
        ctx: context_mod.Context,
    ) !AccessToken {
        return self.getTokenFn(self, request_context, ctx);
    }
};

/// Get the current Unix timestamp in seconds using a single-threaded Io instance.
fn currentTimestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    return std.Io.Timestamp.now(threaded.io(), .real).toSeconds();
}

/// Wraps any TokenCredential with in-memory token caching.
///
/// Returns the cached token if it is still valid (with a buffer before
/// expiry to allow for clock skew and network latency). Otherwise
/// fetches a new token from the inner credential.
pub const CachedTokenCredential = struct {
    inner: *TokenCredential,
    allocator: std.mem.Allocator,
    credential: TokenCredential,
    cached_token: ?[]u8 = null,
    cached_expires_on: i64 = 0,
    /// Refresh the token this many seconds before it expires.
    refresh_buffer_secs: i64 = 300,

    pub fn init(allocator: std.mem.Allocator, inner: *TokenCredential) CachedTokenCredential {
        return .{
            .inner = inner,
            .allocator = allocator,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn asCredential(self: *CachedTokenCredential) *TokenCredential {
        return &self.credential;
    }

    pub fn deinit(self: *CachedTokenCredential) void {
        if (self.cached_token) |t| self.allocator.free(t);
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        ctx: context_mod.Context,
    ) anyerror!AccessToken {
        const self: *CachedTokenCredential = @alignCast(@fieldParentPtr("credential", cred));
        const now = currentTimestamp();

        // Return cached token if still valid.
        if (self.cached_token) |token| {
            if (now < self.cached_expires_on - self.refresh_buffer_secs) {
                return .{ .token = token, .expires_on = self.cached_expires_on };
            }
        }

        // Fetch fresh token.
        const fresh = try self.inner.getToken(request_context, ctx);

        // Cache it (take ownership of the token string).
        if (self.cached_token) |old| self.allocator.free(old);
        self.cached_token = try self.allocator.dupe(u8, fresh.token);
        self.cached_expires_on = fresh.expires_on;

        // Free the original token from the inner credential since we duped it.
        self.allocator.free(fresh.token);

        return .{ .token = self.cached_token.?, .expires_on = self.cached_expires_on };
    }
};

test "access token fields" {
    const t = AccessToken{ .token = "eyJ...", .expires_on = 1743523200 };
    try std.testing.expectEqualStrings("eyJ...", t.token);
}

test "CachedTokenCredential caches token" {
    const allocator = std.testing.allocator;

    // Use a mock credential that counts calls.
    const Counter = struct {
        var call_count: u32 = 0;

        fn reset() void {
            call_count = 0;
        }

        fn getTokenFn(
            _: *TokenCredential,
            _: TokenRequestContext,
            _: context_mod.Context,
        ) anyerror!AccessToken {
            call_count += 1;
            const token = try allocator.dupe(u8, "test-token");
            // Expires far in the future.
            return .{ .token = token, .expires_on = currentTimestamp() + 7200 };
        }
    };

    Counter.reset();
    var inner = TokenCredential{ .getTokenFn = &Counter.getTokenFn };
    var cached = CachedTokenCredential.init(allocator, &inner);
    defer cached.deinit();

    const ctx = context_mod.Context.none;
    const req = TokenRequestContext{ .scopes = &.{"https://vault.azure.net/.default"} };

    // First call fetches.
    const t1 = try cached.asCredential().getToken(req, ctx);
    try std.testing.expectEqualStrings("test-token", t1.token);
    try std.testing.expectEqual(@as(u32, 1), Counter.call_count);

    // Second call returns cached — no new fetch.
    const t2 = try cached.asCredential().getToken(req, ctx);
    try std.testing.expectEqualStrings("test-token", t2.token);
    try std.testing.expectEqual(@as(u32, 1), Counter.call_count);
}
