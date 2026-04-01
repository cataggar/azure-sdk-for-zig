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

test "access token fields" {
    const t = AccessToken{ .token = "eyJ...", .expires_on = 1743523200 };
    try std.testing.expectEqualStrings("eyJ...", t.token);
}
