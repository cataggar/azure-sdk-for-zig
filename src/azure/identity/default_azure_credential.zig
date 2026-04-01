const std = @import("std");
const core = @import("azure_core");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Tries a chain of credentials in order, returning the first success.
pub const ChainedTokenCredential = struct {
    sources: []Source,
    credential: TokenCredential,

    pub const Source = struct {
        name: []const u8,
        cred: *TokenCredential,
    };

    pub fn init(sources: []Source) ChainedTokenCredential {
        return .{
            .sources = sources,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn asCredential(self: *ChainedTokenCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        ctx: Context,
    ) anyerror!AccessToken {
        const self: *ChainedTokenCredential = @fieldParentPtr("credential", cred);
        var last_err: anyerror = error.NoCredentialSucceeded;
        for (self.sources) |source| {
            const result = source.cred.getToken(request_context, ctx);
            if (result) |token| return token else |err| {
                last_err = err;
                std.log.debug("azure-identity: {s} failed: {}", .{ source.name, err });
            }
        }
        return last_err;
    }
};

/// Pre-configured credential chain matching Azure's DefaultAzureCredential.
///
/// Chain order:
///   1. EnvironmentCredential
///   2. WorkloadIdentityCredential  (if AZURE_FEDERATED_TOKEN_FILE set)
///   3. ManagedIdentityCredential
///   4. AzureCliCredential
pub const DefaultAzureCredential = struct {
    chain: ChainedTokenCredential,
    // Storage for the individual credentials.
    env_cred: ?@import("environment.zig").EnvironmentCredential = null,
    mi_cred: @import("managed_identity.zig").ManagedIdentityCredential,
    cli_cred: @import("azure_cli.zig").AzureCliCredential,
    sources_buf: [4]ChainedTokenCredential.Source = undefined,
    num_sources: usize = 0,

    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
        env: anytype,
    ) DefaultAzureCredential {
        var self: DefaultAzureCredential = .{
            .chain = undefined,
            .mi_cred = @import("managed_identity.zig").ManagedIdentityCredential.init(allocator, transport),
            .cli_cred = @import("azure_cli.zig").AzureCliCredential.init(allocator),
        };

        // 1. EnvironmentCredential (may fail if env vars absent).
        if (@import("environment.zig").EnvironmentCredential.init(allocator, transport, env)) |ec| {
            self.env_cred = ec;
        } else |_| {}

        // Build sources list.
        var n: usize = 0;
        if (self.env_cred != null) {
            self.sources_buf[n] = .{ .name = "EnvironmentCredential", .cred = self.env_cred.?.asCredential() };
            n += 1;
        }
        // WorkloadIdentityCredential omitted here until token file reading is implemented.
        self.sources_buf[n] = .{ .name = "ManagedIdentityCredential", .cred = self.mi_cred.asCredential() };
        n += 1;
        self.sources_buf[n] = .{ .name = "AzureCliCredential", .cred = self.cli_cred.asCredential() };
        n += 1;
        self.num_sources = n;
        self.chain = ChainedTokenCredential.init(self.sources_buf[0..n]);

        return self;
    }

    pub fn asCredential(self: *DefaultAzureCredential) *TokenCredential {
        return self.chain.asCredential();
    }
};

test "ChainedTokenCredential uses first success" {
    const allocator = std.testing.allocator;
    var mock_fail = core.http.MockTransport.init(allocator, 401, "fail");
    defer mock_fail.deinit();
    var mock_ok = core.http.MockTransport.init(
        allocator,
        200,
        \\{"access_token":"chained-ok","expires_in":3600}
    );
    defer mock_ok.deinit();

    const client_secret= @import("client_secret.zig");
    // First credential will fail (401).
    var cred1 = client_secret.ClientSecretCredential.init(allocator, mock_fail.asTransport(), "t", "c", "s");
    // Second will succeed.
    var cred2 = client_secret.ClientSecretCredential.init(allocator, mock_ok.asTransport(), "t", "c", "s");

    var sources = [_]ChainedTokenCredential.Source{
        .{ .name = "fail", .cred = cred1.asCredential() },
        .{ .name = "ok", .cred = cred2.asCredential() },
    };
    var chain = ChainedTokenCredential.init(&sources);
    const token = try chain.asCredential().getToken(
        .{ .scopes = &.{"https://vault.azure.net/.default"} },
        Context.none,
    );
    defer allocator.free(token.token);
    try std.testing.expectEqualStrings("chained-ok", token.token);
}
