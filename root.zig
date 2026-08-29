const std = @import("std");
const core = @import("azure_sdk_core");
const serde = @import("serde");

// ─────────────────────────── Models ───────────────────────────

pub const AttestationResult = struct {
    token: ?[]const u8 = null,
    is_debuggable: ?bool = null,

    pub fn deinit(self: AttestationResult, allocator: std.mem.Allocator) void {
        if (self.token) |t| allocator.free(t);
    }
};

// ──────────────────── AttestationClient ───────────────────────

pub const AttestationClientOptions = struct {
    runtime: core.http.HttpRuntime,
    api_version: []const u8 = "2022-08-01",
};

pub const attestation_scopes: []const []const u8 = &.{
    "https://attest.azure.net/.default",
};

pub const AttestationClient = struct {
    allocator: std.mem.Allocator,
    endpoint: []u8,
    api_version: []u8,
    auth_policy: *core.http.BearerTokenAuthPolicy,
    request_id_policy: *core.http.RequestIdPolicy,
    policy_ptrs: []*core.http.HttpPolicy,
    pipeline: core.http.HttpPipeline,

    /// Constructs a client with the canonical HTTP runtime.
    ///
    /// Runtime descriptors are copied by value. Their transport and crypto
    /// backend contexts, and `credential`, remain borrowed and must outlive
    /// this client and every operation on it. The selected crypto provider is
    /// used for request IDs without falling back to the standard provider.
    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        credential: *core.credentials.TokenCredential,
        options: AttestationClientOptions,
    ) !AttestationClient {
        const owned_endpoint = try allocator.dupe(u8, endpoint);
        errdefer allocator.free(owned_endpoint);
        const owned_api_version = try allocator.dupe(u8, options.api_version);
        errdefer allocator.free(owned_api_version);

        const request_id_policy = try allocator.create(core.http.RequestIdPolicy);
        errdefer allocator.destroy(request_id_policy);
        request_id_policy.* = .init();

        const auth_policy = try allocator.create(core.http.BearerTokenAuthPolicy);
        errdefer allocator.destroy(auth_policy);
        auth_policy.* = .init(allocator, credential, attestation_scopes);
        errdefer auth_policy.deinit();

        const policy_ptrs = try allocator.alloc(*core.http.HttpPolicy, 2);
        errdefer allocator.free(policy_ptrs);
        policy_ptrs[0] = request_id_policy.asPolicy();
        policy_ptrs[1] = auth_policy.asPolicy();

        return .{
            .allocator = allocator,
            .endpoint = owned_endpoint,
            .api_version = owned_api_version,
            .auth_policy = auth_policy,
            .request_id_policy = request_id_policy,
            .policy_ptrs = policy_ptrs,
            .pipeline = .init(options.runtime, policy_ptrs),
        };
    }

    pub fn deinit(self: *AttestationClient) void {
        self.allocator.free(self.policy_ptrs);
        self.auth_policy.deinit();
        self.allocator.destroy(self.auth_policy);
        self.allocator.destroy(self.request_id_policy);
        self.allocator.free(self.api_version);
        self.allocator.free(self.endpoint);
        self.* = undefined;
    }

    /// Returns a copy of the runtime descriptor used by every operation.
    ///
    /// The returned descriptor borrows the same backend contexts as the
    /// client.
    pub fn runtime(self: *const AttestationClient) core.http.HttpRuntime {
        return self.pipeline.runtime;
    }

    /// POST /attest/SgxEnclave?api-version=...
    pub fn attestSgxEnclave(
        self: *AttestationClient,
        allocator: std.mem.Allocator,
        quote: []const u8,
    ) !AttestationResult {
        return self.attest(allocator, "SgxEnclave", quote);
    }

    /// POST /attest/OpenEnclave?api-version=...
    pub fn attestOpenEnclave(
        self: *AttestationClient,
        allocator: std.mem.Allocator,
        report: []const u8,
    ) !AttestationResult {
        return self.attest(allocator, "OpenEnclave", report);
    }

    /// `Result(...)` variants — branch on `AzureError.error_code` when
    /// the attestation backend is unavailable, the enclave evidence is
    /// invalid, etc.
    pub fn attestSgxEnclaveResult(
        self: *AttestationClient,
        allocator: std.mem.Allocator,
        quote: []const u8,
    ) !core.errors.Result(AttestationResult) {
        return self.attestResult(allocator, "SgxEnclave", quote);
    }

    pub fn attestOpenEnclaveResult(
        self: *AttestationClient,
        allocator: std.mem.Allocator,
        report: []const u8,
    ) !core.errors.Result(AttestationResult) {
        return self.attestResult(allocator, "OpenEnclave", report);
    }

    fn attest(
        self: *AttestationClient,
        allocator: std.mem.Allocator,
        enclave_type: []const u8,
        evidence: []const u8,
    ) !AttestationResult {
        var result = try self.attestResult(allocator, enclave_type, evidence);
        return result.unwrap(error.AttestationFailed);
    }

    fn attestResult(
        self: *AttestationClient,
        allocator: std.mem.Allocator,
        enclave_type: []const u8,
        evidence: []const u8,
    ) !core.errors.Result(AttestationResult) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/attest/{s}?api-version={s}",
            .{ self.endpoint, enclave_type, self.api_version },
        );
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(
            allocator,
            "{{\"quote\":\"{s}\"}}",
            .{evidence},
        );
        defer allocator.free(body);

        var request = core.http.Request.init(allocator, .POST, url);
        defer request.deinit();
        try request.setHeader("Content-Type", "application/json");
        try request.setHeader("Accept", "application/json");
        request.body = body;

        var response = try self.pipeline.send(&request);
        defer response.deinit();

        if (!response.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, response)) |azure_error| {
                return .{ .err = azure_error };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseAttestationResult(allocator, response.body) };
    }
};

// ─────────────────────────── Parsing ──────────────────────────

fn parseAttestationResult(allocator: std.mem.Allocator, body: []const u8) !AttestationResult {
    const Schema = struct {
        token: ?[]const u8 = null,
        isDebuggable: ?bool = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(Schema, arena.allocator(), body) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return .{},
    };

    var result = AttestationResult{};
    if (parsed.token) |value| result.token = try allocator.dupe(u8, value);
    result.is_debuggable = parsed.isDebuggable;
    return result;
}

// ─────────────────────────── Tests ────────────────────────────

const TestCredential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = &getToken },
    calls: usize = 0,
    transport_context: ?*anyopaque = null,
    crypto_context: ?*anyopaque = null,
    scope: ?[]const u8 = null,

    fn asCredential(self: *@This()) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        _: core.context.Context,
        runtime_value: core.http.HttpRuntime,
    ) anyerror!core.credentials.AccessToken {
        const self: *@This() = @alignCast(@fieldParentPtr("credential", credential));
        self.calls += 1;
        self.transport_context = runtime_value.transport.context;
        self.crypto_context = runtime_value.crypto.context;
        self.scope = request_context.scopes[0];
        return .{
            .token = "test-token",
            .expires_on = std.math.maxInt(i64),
        };
    }
};

const TestCryptoProvider = struct {
    random_calls: usize = 0,
    fail_random: bool = false,

    const vtable: core.crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    fn asProvider(self: *@This()) core.crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn randomBytes(context: *anyopaque, out: []u8) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.random_calls += 1;
        if (self.fail_random) return error.ProviderFailure;
        for (out, 0..) |*byte, index| byte.* = @truncate(index);
    }

    fn md5(_: *anyopaque, _: []const u8, _: *core.crypto.Md5Digest) !void {
        return error.Unused;
    }

    fn sha256(_: *anyopaque, _: []const u8, _: *core.crypto.Sha256Digest) !void {
        return error.Unused;
    }

    fn hmacSha256(
        _: *anyopaque,
        _: []const u8,
        _: []const u8,
        _: *core.crypto.HmacSha256Digest,
    ) !void {
        return error.Unused;
    }

    fn sha256Init(
        _: *anyopaque,
        _: std.mem.Allocator,
    ) !core.crypto.Sha256Operation {
        return error.Unused;
    }
};

fn attestationAllocationFixture(allocator: std.mem.Allocator) !void {
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"token":"attestation-token","isDebuggable":false}
    );
    defer mock.deinit();
    var provider = TestCryptoProvider{};
    var credential = TestCredential{};
    var client = try AttestationClient.init(
        allocator,
        "https://myattestation.attest.azure.net",
        credential.asCredential(),
        .{ .runtime = .init(mock.asTransport(), provider.asProvider()) },
    );
    defer client.deinit();

    const result = try client.attestSgxEnclave(allocator, "base64-encoded-quote");
    defer result.deinit(allocator);
}

test "AttestationClient preserves runtime providers across operations" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"token":"attestation-token","isDebuggable":false}
    );
    defer mock.deinit();
    var provider = TestCryptoProvider{};
    var credential = TestCredential{};
    const runtime_value = core.http.HttpRuntime.init(
        mock.asTransport(),
        provider.asProvider(),
    );
    var client = try AttestationClient.init(
        allocator,
        "https://myattestation.attest.azure.net",
        credential.asCredential(),
        .{ .runtime = runtime_value },
    );
    defer client.deinit();

    const result = try client.attestSgxEnclave(allocator, "base64-encoded-quote");
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("attestation-token", result.token.?);
    try std.testing.expectEqual(false, result.is_debuggable.?);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    try std.testing.expect(std.mem.find(
        u8,
        mock.last_url.?,
        "attest/SgxEnclave?api-version=",
    ) != null);
    try std.testing.expectEqualStrings(
        "Bearer test-token",
        mock.last_headers.get("Authorization").?,
    );
    try std.testing.expectEqualStrings(
        "00010203-0405-4607-8809-0a0b0c0d0e0f",
        mock.last_headers.get("x-ms-client-request-id").?,
    );
    try std.testing.expectEqual(@as(usize, 1), provider.random_calls);
    try std.testing.expectEqual(@as(usize, 1), credential.calls);
    try std.testing.expectEqual(runtime_value.transport.context, credential.transport_context.?);
    try std.testing.expectEqual(runtime_value.crypto.context, credential.crypto_context.?);
    try std.testing.expectEqualStrings(attestation_scopes[0], credential.scope.?);
    try std.testing.expectEqual(runtime_value.transport.context, client.runtime().transport.context);
    try std.testing.expectEqual(runtime_value.crypto.context, client.runtime().crypto.context);
}

test "AttestationClient propagates selected provider failure before transport" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var provider = TestCryptoProvider{ .fail_random = true };
    var credential = TestCredential{};
    var client = try AttestationClient.init(
        allocator,
        "https://myattestation.attest.azure.net",
        credential.asCredential(),
        .{ .runtime = .init(mock.asTransport(), provider.asProvider()) },
    );
    defer client.deinit();

    try std.testing.expectError(
        error.ProviderFailure,
        client.attestSgxEnclave(allocator, "base64-encoded-quote"),
    );
    try std.testing.expectEqual(@as(usize, 1), provider.random_calls);
    try std.testing.expectEqual(@as(usize, 0), credential.calls);
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}

test "AttestationClient releases every allocation failure path" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        attestationAllocationFixture,
        .{},
    );
}
