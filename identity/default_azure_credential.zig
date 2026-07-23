const std = @import("std");
const core = @import("../root.zig");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

fn envGet(env: anytype, key: []const u8) ?[]const u8 {
    return env.get(key);
}

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
    allocator: std.mem.Allocator,
    state: *State,

    const State = struct {
        chain: ChainedTokenCredential,
        env_cred: ?@import("environment.zig").EnvironmentCredential = null,
        wi_cred: ?@import("workload_identity.zig").WorkloadIdentityCredential = null,
        mi_cred: @import("managed_identity.zig").ManagedIdentityCredential,
        mi_client_id: ?[]u8 = null,
        cli_cred: @import("azure_cli.zig").AzureCliCredential,
        sources_buf: [5]ChainedTokenCredential.Source = undefined,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        transport: *core.http.HttpTransport,
        env: anytype,
    ) !DefaultAzureCredential {
        const state = try allocator.create(State);
        state.* = .{
            .chain = undefined,
            .mi_cred = @import("managed_identity.zig").ManagedIdentityCredential.init(allocator, transport),
            .cli_cred = @import("azure_cli.zig").AzureCliCredential.init(allocator, io),
        };
        errdefer {
            if (state.env_cred) |*credential| credential.deinit();
            if (state.wi_cred) |*credential| credential.deinit();
            if (state.mi_client_id) |client_id| allocator.free(client_id);
            allocator.destroy(state);
        }

        if (envGet(env, "AZURE_CLIENT_ID")) |client_id| {
            state.mi_client_id = try allocator.dupe(u8, client_id);
            state.mi_cred.withClientId(state.mi_client_id.?);
        }

        // 1. EnvironmentCredential (may fail if env vars absent).
        state.env_cred = @import("environment.zig").EnvironmentCredential.init(
            allocator,
            transport,
            env,
        ) catch |err| switch (err) {
            error.EnvironmentNotConfigured => null,
            else => return err,
        };

        // 2. WorkloadIdentityCredential (if federated token file is configured).
        const wi_tenant = envGet(env, "AZURE_TENANT_ID");
        const wi_client = envGet(env, "AZURE_CLIENT_ID");
        const wi_file = envGet(env, "AZURE_FEDERATED_TOKEN_FILE");
        if (wi_tenant != null and wi_client != null and wi_file != null) {
            state.wi_cred = try @import("workload_identity.zig").WorkloadIdentityCredential.init(
                allocator,
                transport,
                wi_tenant.?,
                wi_client.?,
                wi_file.?,
            );
            if (envGet(env, "AZURE_AUTHORITY_HOST")) |authority_host| {
                try state.wi_cred.?.setAuthorityHost(authority_host);
            }
        }

        // Build sources list.
        var n: usize = 0;
        if (state.env_cred != null) {
            state.sources_buf[n] = .{ .name = "EnvironmentCredential", .cred = state.env_cred.?.asCredential() };
            n += 1;
        }
        if (state.wi_cred != null) {
            state.sources_buf[n] = .{ .name = "WorkloadIdentityCredential", .cred = state.wi_cred.?.asCredential() };
            n += 1;
        }
        state.sources_buf[n] = .{ .name = "ManagedIdentityCredential", .cred = state.mi_cred.asCredential() };
        n += 1;
        state.sources_buf[n] = .{ .name = "AzureCliCredential", .cred = state.cli_cred.asCredential() };
        n += 1;
        state.chain = ChainedTokenCredential.init(state.sources_buf[0..n]);

        return .{ .allocator = allocator, .state = state };
    }

    pub fn asCredential(self: *DefaultAzureCredential) *TokenCredential {
        return self.state.chain.asCredential();
    }

    pub fn deinit(self: *DefaultAzureCredential) void {
        if (self.state.env_cred) |*credential| credential.deinit();
        if (self.state.wi_cred) |*credential| credential.deinit();
        if (self.state.mi_client_id) |client_id| self.allocator.free(client_id);
        self.allocator.destroy(self.state);
        self.* = undefined;
    }
};

test "ChainedTokenCredential uses first success" {
    const allocator = std.testing.allocator;
    var mock_fail = core.http.MockTransport.init(allocator, 401, "fail");
    defer mock_fail.deinit();
    var mock_ok = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"chained-ok","expires_in":3600}
    );
    defer mock_ok.deinit();

    const client_secret = @import("client_secret.zig");
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

test "DefaultAzureCredential remains valid after return and move" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"managed-identity-token","expires_in":"3600","expires_on":"1743523200"}
    );
    defer mock.deinit();

    const EmptyEnv = struct {
        pub fn get(_: @This(), _: []const u8) ?[]const u8 {
            return null;
        }
    };
    const Factory = struct {
        fn create(
            alloc: std.mem.Allocator,
            transport: *core.http.HttpTransport,
        ) !DefaultAzureCredential {
            return DefaultAzureCredential.init(
                alloc,
                std.testing.io,
                transport,
                EmptyEnv{},
            );
        }
    };

    var returned = try Factory.create(allocator, mock.asTransport());
    var moved = returned;
    returned = undefined;
    defer moved.deinit();

    const token = try moved.asCredential().getToken(
        .{ .scopes = &.{"https://vault.azure.net/.default"} },
        Context.none,
    );
    defer allocator.free(token.token);
    try std.testing.expectEqualStrings("managed-identity-token", token.token);
}

test "DefaultAzureCredential owns environment credential values" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"environment-token","expires_in":3600}
    );
    defer mock.deinit();

    const TestEnv = struct {
        allocator: std.mem.Allocator,
        map: std.StringHashMap([]const u8),

        fn init(alloc: std.mem.Allocator) @This() {
            return .{
                .allocator = alloc,
                .map = std.StringHashMap([]const u8).init(alloc),
            };
        }

        fn put(self: *@This(), key: []const u8, value: []const u8) !void {
            try self.map.put(key, try self.allocator.dupe(u8, value));
        }

        pub fn get(self: @This(), key: []const u8) ?[]const u8 {
            return self.map.get(key);
        }

        fn deinit(self: *@This()) void {
            var iterator = self.map.valueIterator();
            while (iterator.next()) |value| self.allocator.free(value.*);
            self.map.deinit();
        }
    };

    var env = TestEnv.init(allocator);
    var env_owned = true;
    defer if (env_owned) env.deinit();
    try env.put("AZURE_TENANT_ID", "tenant");
    try env.put("AZURE_CLIENT_ID", "client");
    try env.put("AZURE_CLIENT_SECRET", "secret");
    try env.put("AZURE_FEDERATED_TOKEN_FILE", "/tmp/federated-token");
    try env.put("AZURE_AUTHORITY_HOST", "https://login.microsoftonline.us");
    const original_tenant_ptr = env.get("AZURE_TENANT_ID").?.ptr;

    var credential = try DefaultAzureCredential.init(
        allocator,
        std.testing.io,
        mock.asTransport(),
        env,
    );
    defer credential.deinit();
    try std.testing.expect(credential.state.env_cred.?.tenant_id.ptr != original_tenant_ptr);
    try std.testing.expectEqualStrings("client", credential.state.mi_cred.client_id.?);
    try std.testing.expectEqualStrings(
        "https://login.microsoftonline.us",
        credential.state.wi_cred.?.authority_host,
    );
    env.deinit();
    env_owned = false;

    const token = try credential.asCredential().getToken(
        .{ .scopes = &.{"https://vault.azure.net/.default"} },
        Context.none,
    );
    defer allocator.free(token.token);
    try std.testing.expectEqualStrings("environment-token", token.token);
}
