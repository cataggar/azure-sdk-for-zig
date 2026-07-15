//! A `TokenCredential` that hands back a caller-supplied bearer token
//! string verbatim — for environments where the SDK cannot reach an
//! interactive credential provider, notably wasm32-wasi (no `az`
//! subprocess, no managed-identity HTTP endpoint).
//!
//! Typical use: obtain a token on the host with
//!     az account get-access-token --resource https://management.azure.com \
//!         --query accessToken -o tsv
//! pass it to the component via `--env AZURE_TOKEN=<token>`, and feed
//! that env value to `EnvTokenCredential.init`.

const std = @import("std");
const token = @import("token.zig");
const context_mod = @import("../context.zig");

pub const EnvTokenCredential = struct {
    allocator: std.mem.Allocator,
    /// Borrowed bearer token (typically a slice of the WASI environ map).
    token: []const u8,
    credential: token.TokenCredential,

    /// Far-future expiry so `BearerTokenAuthPolicy` never tries to refresh
    /// mid-run. The real token's lifetime is the caller's concern; a single
    /// CLI invocation completes well within it.
    const far_future_unix: i64 = 7258118400; // 2200-01-01T00:00:00Z

    pub fn init(allocator: std.mem.Allocator, bearer_token: []const u8) EnvTokenCredential {
        return .{
            .allocator = allocator,
            .token = bearer_token,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn asCredential(self: *EnvTokenCredential) *token.TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *token.TokenCredential,
        _: token.TokenRequestContext,
        _: context_mod.Context,
    ) anyerror!token.AccessToken {
        const self: *EnvTokenCredential = @alignCast(@fieldParentPtr("credential", cred));
        // Return an explicitly owned copy; AccessToken carries its allocator.
        const owned = try self.allocator.dupe(u8, self.token);
        return .{
            .token = owned,
            .expires_on = far_future_unix,
            .allocator = self.allocator,
        };
    }
};
