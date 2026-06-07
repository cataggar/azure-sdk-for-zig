const std = @import("std");
const core = @import("azure_core");
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
    api_version: []const u8 = "2022-08-01",
};

pub const AttestationClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: AttestationClientOptions,
    ) AttestationClient {
        _ = credential;
        return .{
            .endpoint = endpoint,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
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
        var r = try self.attestResult(allocator, enclave_type, evidence);
        return r.unwrap(error.AttestationFailed);
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

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseAttestationResult(allocator, resp.body) };
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

    const parsed = serde.json.fromSlice(Schema, arena.allocator(), body) catch
        return .{};

    var result = AttestationResult{};
    if (parsed.token) |v| result.token = try allocator.dupe(u8, v);
    result.is_debuggable = parsed.isDebuggable;
    return result;
}

// ─────────────────────────── Tests ────────────────────────────

test "AttestationClient attestSgxEnclave" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"token":"eyJhbGciOiJSUzI1NiJ9.attestation-token","isDebuggable":false}
    );
    defer mock.deinit();

    const identity = @import("azure_core").identity;
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = AttestationClient.init(
        "https://myattestation.attest.azure.net",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const result = try client.attestSgxEnclave(allocator, "base64-encoded-quote");
    defer allocator.free(result.token.?);

    try std.testing.expectEqualStrings("eyJhbGciOiJSUzI1NiJ9.attestation-token", result.token.?);
    try std.testing.expectEqual(false, result.is_debuggable.?);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "attest/SgxEnclave?api-version=") != null);
}
