//! A `TokenCredential` that returns a bearer token read from an environment
//! variable (no `az` subprocess — that can't run under WASI).
//!
//! Obtain a token on the host with, e.g.:
//!   az account get-access-token --resource https://management.azure.com \
//!       --query accessToken -o tsv
//! and pass it to the component via `--env AZURE_TOKEN=<token>`.

const std = @import("std");
const core = @import("azure_core");

pub const EnvTokenCredential = struct {
    allocator: std.mem.Allocator,
    /// Borrowed bearer token (typically a slice of the WASI environ map).
    token: []const u8,
    credential: core.credentials.TokenCredential,

    /// Far-future expiry so `BearerTokenAuthPolicy` never tries to refresh
    /// mid-run. The real token's lifetime is the caller's concern; a single
    /// CLI invocation completes well within it.
    const far_future_unix: i64 = 7258118400; // 2200-01-01T00:00:00Z

    pub fn init(allocator: std.mem.Allocator, token: []const u8) EnvTokenCredential {
        return .{
            .allocator = allocator,
            .token = token,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn asCredential(self: *EnvTokenCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *core.credentials.TokenCredential,
        _: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *EnvTokenCredential = @fieldParentPtr("credential", cred);
        // BearerTokenAuthPolicy takes ownership and frees this, so hand back
        // an allocator-owned copy rather than the borrowed env slice.
        const owned = try self.allocator.dupe(u8, self.token);
        return .{ .token = owned, .expires_on = far_future_unix };
    }
};
