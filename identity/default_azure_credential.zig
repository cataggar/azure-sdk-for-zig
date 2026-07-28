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

/// A credential that `DefaultAzureCredential` can place in its chain.
pub const CredentialKind = enum {
    environment,
    workload_identity,
    managed_identity,
    azure_cli,
    azure_developer_cli,
};

/// Chain selection requested through the `AZURE_TOKEN_CREDENTIALS`
/// environment variable.
///
/// `ManagedIdentityCredential` probes the Instance Metadata Service at
/// `169.254.169.254`, which is unroutable outside Azure and stalls every token
/// request until the connection times out. It is therefore excluded from the
/// default chain and only used when `AZURE_TOKEN_CREDENTIALS` selects it,
/// either directly or through the `prod` category.
pub const TokenCredentialSelection = enum {
    /// `AZURE_TOKEN_CREDENTIALS` unset: every credential except the IMDS probe.
    default,
    /// `prod`: deployed-service credentials.
    prod,
    /// `dev`: developer-tool credentials.
    dev,
    environment_credential,
    workload_identity_credential,
    managed_identity_credential,
    azure_cli_credential,
    azure_developer_cli_credential,

    pub const env_var = "AZURE_TOKEN_CREDENTIALS";

    pub const ParseError = error{UnknownTokenCredentialSelection};

    const Alias = struct { name: []const u8, selection: TokenCredentialSelection };

    const aliases = [_]Alias{
        .{ .name = "prod", .selection = .prod },
        .{ .name = "dev", .selection = .dev },
        .{ .name = "EnvironmentCredential", .selection = .environment_credential },
        .{ .name = "WorkloadIdentityCredential", .selection = .workload_identity_credential },
        .{ .name = "ManagedIdentityCredential", .selection = .managed_identity_credential },
        .{ .name = "AzureCliCredential", .selection = .azure_cli_credential },
        .{ .name = "AzureDeveloperCliCredential", .selection = .azure_developer_cli_credential },
    };

    /// Parses an `AZURE_TOKEN_CREDENTIALS` value. Matching ignores ASCII case
    /// and surrounding whitespace; an empty value means `.default`.
    pub fn parse(raw: []const u8) ParseError!TokenCredentialSelection {
        const value = std.mem.trim(u8, raw, " \t\r\n");
        if (value.len == 0) return .default;
        for (aliases) |alias| {
            if (std.ascii.eqlIgnoreCase(value, alias.name)) return alias.selection;
        }
        return error.UnknownTokenCredentialSelection;
    }

    pub fn fromEnv(env: anytype) ParseError!TokenCredentialSelection {
        return parse(envGet(env, env_var) orelse return .default);
    }

    /// Whether `kind` belongs in the chain for this selection.
    pub fn includes(self: TokenCredentialSelection, kind: CredentialKind) bool {
        return switch (self) {
            .default => kind != .managed_identity,
            .prod => switch (kind) {
                .environment, .workload_identity, .managed_identity => true,
                .azure_cli, .azure_developer_cli => false,
            },
            .dev => switch (kind) {
                .azure_cli, .azure_developer_cli => true,
                .environment, .workload_identity, .managed_identity => false,
            },
            .environment_credential => kind == .environment,
            .workload_identity_credential => kind == .workload_identity,
            .managed_identity_credential => kind == .managed_identity,
            .azure_cli_credential => kind == .azure_cli,
            .azure_developer_cli_credential => kind == .azure_developer_cli,
        };
    }
};

/// Pre-configured credential chain matching Azure's DefaultAzureCredential.
///
/// The chain is selected by `AZURE_TOKEN_CREDENTIALS`:
///
///   unset  EnvironmentCredential, WorkloadIdentityCredential,
///          AzureCliCredential, AzureDeveloperCliCredential
///   prod   EnvironmentCredential, WorkloadIdentityCredential,
///          ManagedIdentityCredential
///   dev    AzureCliCredential, AzureDeveloperCliCredential
///   a credential name  only that credential
///
/// `WorkloadIdentityCredential` still requires `AZURE_TENANT_ID`,
/// `AZURE_CLIENT_ID`, and `AZURE_FEDERATED_TOKEN_FILE`, and
/// `EnvironmentCredential` still requires its own variables; a selected
/// credential that is not configured is left out of the chain.
///
/// `ManagedIdentityCredential` is never in the default chain because its IMDS
/// probe stalls outside Azure. Set `AZURE_TOKEN_CREDENTIALS=prod` on deployed
/// services, or name the credential directly, to use it.
pub const DefaultAzureCredential = struct {
    allocator: std.mem.Allocator,
    state: *State,

    const State = struct {
        chain: ChainedTokenCredential,
        selection: TokenCredentialSelection,
        env_cred: ?@import("environment.zig").EnvironmentCredential = null,
        wi_cred: ?@import("workload_identity.zig").WorkloadIdentityCredential = null,
        mi_cred: @import("managed_identity.zig").ManagedIdentityCredential,
        mi_client_id: ?[]u8 = null,
        cli_cred: @import("azure_cli.zig").AzureCliCredential,
        azd_cred: @import("azure_developer_cli.zig").AzureDeveloperCliCredential,
        sources_buf: [5]ChainedTokenCredential.Source = undefined,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        transport: *core.http.HttpTransport,
        env: anytype,
    ) !DefaultAzureCredential {
        return initWithSelection(
            allocator,
            io,
            transport,
            env,
            try TokenCredentialSelection.fromEnv(env),
        );
    }

    /// Builds the chain for an explicit selection, ignoring
    /// `AZURE_TOKEN_CREDENTIALS`.
    pub fn initWithSelection(
        allocator: std.mem.Allocator,
        io: std.Io,
        transport: *core.http.HttpTransport,
        env: anytype,
        requested: TokenCredentialSelection,
    ) !DefaultAzureCredential {
        const state = try allocator.create(State);
        state.* = .{
            .chain = undefined,
            .selection = requested,
            .mi_cred = @import("managed_identity.zig").ManagedIdentityCredential.init(allocator, transport),
            .cli_cred = @import("azure_cli.zig").AzureCliCredential.init(allocator, io),
            .azd_cred = @import("azure_developer_cli.zig").AzureDeveloperCliCredential.init(allocator, io),
        };
        errdefer {
            if (state.env_cred) |*credential| credential.deinit();
            if (state.wi_cred) |*credential| credential.deinit();
            if (state.mi_client_id) |client_id| allocator.free(client_id);
            allocator.destroy(state);
        }

        if (requested.includes(.managed_identity)) {
            if (envGet(env, "AZURE_CLIENT_ID")) |client_id| {
                state.mi_client_id = try allocator.dupe(u8, client_id);
                state.mi_cred.withClientId(state.mi_client_id.?);
            }
        }

        // EnvironmentCredential (may fail if env vars absent).
        if (requested.includes(.environment)) {
            state.env_cred = @import("environment.zig").EnvironmentCredential.init(
                allocator,
                transport,
                env,
            ) catch |err| switch (err) {
                error.EnvironmentNotConfigured => null,
                else => return err,
            };
        }

        // WorkloadIdentityCredential (if federated token file is configured).
        if (requested.includes(.workload_identity)) {
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
        if (requested.includes(.managed_identity)) {
            state.sources_buf[n] = .{ .name = "ManagedIdentityCredential", .cred = state.mi_cred.asCredential() };
            n += 1;
        }
        if (requested.includes(.azure_cli)) {
            state.sources_buf[n] = .{ .name = "AzureCliCredential", .cred = state.cli_cred.asCredential() };
            n += 1;
        }
        if (requested.includes(.azure_developer_cli)) {
            state.sources_buf[n] = .{ .name = "AzureDeveloperCliCredential", .cred = state.azd_cred.asCredential() };
            n += 1;
        }
        if (n == 0) return error.NoCredentialConfigured;
        state.chain = ChainedTokenCredential.init(state.sources_buf[0..n]);

        return .{ .allocator = allocator, .state = state };
    }

    /// The `AZURE_TOKEN_CREDENTIALS` selection this chain was built from.
    pub fn selection(self: *const DefaultAzureCredential) TokenCredentialSelection {
        return self.state.selection;
    }

    /// Names of the credentials in the chain, in order.
    pub fn chainSources(self: *const DefaultAzureCredential) []const ChainedTokenCredential.Source {
        return self.state.chain.sources;
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

const TestEnv = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMap([]const u8),

    fn init(alloc: std.mem.Allocator) TestEnv {
        return .{
            .allocator = alloc,
            .map = std.StringHashMap([]const u8).init(alloc),
        };
    }

    fn put(self: *TestEnv, key: []const u8, value: []const u8) !void {
        try self.map.put(key, try self.allocator.dupe(u8, value));
    }

    pub fn get(self: TestEnv, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }

    fn deinit(self: *TestEnv) void {
        var iterator = self.map.valueIterator();
        while (iterator.next()) |value| self.allocator.free(value.*);
        self.map.deinit();
    }
};

fn expectChain(
    credential: *const DefaultAzureCredential,
    expected: []const []const u8,
) !void {
    const sources = credential.chainSources();
    try std.testing.expectEqual(expected.len, sources.len);
    for (expected, sources) |name, source| {
        try std.testing.expectEqualStrings(name, source.name);
    }
}

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

    var env = TestEnv.init(allocator);
    defer env.deinit();
    try env.put("AZURE_TOKEN_CREDENTIALS", "ManagedIdentityCredential");

    const Factory = struct {
        fn create(
            alloc: std.mem.Allocator,
            transport: *core.http.HttpTransport,
            test_env: TestEnv,
        ) !DefaultAzureCredential {
            return DefaultAzureCredential.init(
                alloc,
                std.testing.io,
                transport,
                test_env,
            );
        }
    };

    var returned = try Factory.create(allocator, mock.asTransport(), env);
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

test "TokenCredentialSelection parses AZURE_TOKEN_CREDENTIALS values" {
    const Selection = TokenCredentialSelection;
    try std.testing.expectEqual(Selection.default, try Selection.parse(""));
    try std.testing.expectEqual(Selection.default, try Selection.parse("  \t"));
    try std.testing.expectEqual(Selection.prod, try Selection.parse("prod"));
    try std.testing.expectEqual(Selection.prod, try Selection.parse(" PROD\n"));
    try std.testing.expectEqual(Selection.dev, try Selection.parse("Dev"));
    try std.testing.expectEqual(
        Selection.managed_identity_credential,
        try Selection.parse("managedidentitycredential"),
    );
    try std.testing.expectEqual(
        Selection.azure_developer_cli_credential,
        try Selection.parse("AzureDeveloperCliCredential"),
    );
    try std.testing.expectError(
        error.UnknownTokenCredentialSelection,
        Selection.parse("AzurePowerShellCredential"),
    );
}

test "DefaultAzureCredential omits managed identity by default" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    var env = TestEnv.init(allocator);
    defer env.deinit();

    var credential = try DefaultAzureCredential.init(
        allocator,
        std.testing.io,
        mock.asTransport(),
        env,
    );
    defer credential.deinit();

    try std.testing.expectEqual(TokenCredentialSelection.default, credential.selection());
    try expectChain(&credential, &.{ "AzureCliCredential", "AzureDeveloperCliCredential" });
    try std.testing.expectEqual(@as(?[]const u8, null), credential.state.mi_cred.client_id);
}

test "DefaultAzureCredential prod selection enables managed identity" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    var env = TestEnv.init(allocator);
    defer env.deinit();
    try env.put("AZURE_TOKEN_CREDENTIALS", "prod");
    try env.put("AZURE_TENANT_ID", "tenant");
    try env.put("AZURE_CLIENT_ID", "client");
    try env.put("AZURE_CLIENT_SECRET", "secret");
    try env.put("AZURE_FEDERATED_TOKEN_FILE", "/tmp/federated-token");

    var credential = try DefaultAzureCredential.init(
        allocator,
        std.testing.io,
        mock.asTransport(),
        env,
    );
    defer credential.deinit();

    try expectChain(&credential, &.{
        "EnvironmentCredential",
        "WorkloadIdentityCredential",
        "ManagedIdentityCredential",
    });
    try std.testing.expectEqualStrings("client", credential.state.mi_cred.client_id.?);
}

test "DefaultAzureCredential dev selection uses developer tools only" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    var env = TestEnv.init(allocator);
    defer env.deinit();
    try env.put("AZURE_TOKEN_CREDENTIALS", "dev");
    try env.put("AZURE_TENANT_ID", "tenant");
    try env.put("AZURE_CLIENT_ID", "client");
    try env.put("AZURE_CLIENT_SECRET", "secret");

    var credential = try DefaultAzureCredential.init(
        allocator,
        std.testing.io,
        mock.asTransport(),
        env,
    );
    defer credential.deinit();

    try expectChain(&credential, &.{ "AzureCliCredential", "AzureDeveloperCliCredential" });
}

test "DefaultAzureCredential honors a named credential" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    var env = TestEnv.init(allocator);
    defer env.deinit();
    try env.put("AZURE_TOKEN_CREDENTIALS", "AzureCliCredential");
    try env.put("AZURE_TENANT_ID", "tenant");
    try env.put("AZURE_CLIENT_ID", "client");
    try env.put("AZURE_CLIENT_SECRET", "secret");

    var credential = try DefaultAzureCredential.init(
        allocator,
        std.testing.io,
        mock.asTransport(),
        env,
    );
    defer credential.deinit();

    try expectChain(&credential, &.{"AzureCliCredential"});
}

test "DefaultAzureCredential rejects an unknown selection" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    var env = TestEnv.init(allocator);
    defer env.deinit();
    try env.put("AZURE_TOKEN_CREDENTIALS", "NotACredential");

    try std.testing.expectError(error.UnknownTokenCredentialSelection, DefaultAzureCredential.init(
        allocator,
        std.testing.io,
        mock.asTransport(),
        env,
    ));
}

test "DefaultAzureCredential rejects a selection with no configured credential" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    var env = TestEnv.init(allocator);
    defer env.deinit();
    try env.put("AZURE_TOKEN_CREDENTIALS", "WorkloadIdentityCredential");

    try std.testing.expectError(error.NoCredentialConfigured, DefaultAzureCredential.init(
        allocator,
        std.testing.io,
        mock.asTransport(),
        env,
    ));
}
