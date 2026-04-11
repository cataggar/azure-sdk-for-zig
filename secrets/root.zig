const std = @import("std");
const core = @import("azure_core");

const Context = core.context.Context;

// ─────────────────────────── Models ───────────────────────────

pub const SecretProperties = struct {
    enabled: ?bool = null,
    not_before: ?i64 = null,
    expires_on: ?i64 = null,
    created_on: ?i64 = null,
    updated_on: ?i64 = null,
    content_type: ?[]const u8 = null,
    version: ?[]const u8 = null,
    recovery_level: ?[]const u8 = null,
};

pub const KeyVaultSecret = struct {
    name: []const u8,
    value: ?[]const u8 = null,
    id: ?[]const u8 = null,
    properties: SecretProperties = .{},
};

pub const DeletedSecret = struct {
    name: []const u8,
    recovery_id: ?[]const u8 = null,
    deleted_date: ?i64 = null,
    scheduled_purge_date: ?i64 = null,
};

// ─────────────────────────── Client ───────────────────────────

pub const SecretClientOptions = struct {
    api_version: []const u8 = "7.6-preview.2",
};

/// Client for Azure Key Vault Secrets.
///
/// All REST calls go through the HTTP pipeline with bearer-token auth.
pub const SecretClient = struct {
    vault_url: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        vault_url: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: SecretClientOptions,
    ) SecretClient {
        _ = credential;
        return .{
            .vault_url = vault_url,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// GET /secrets/{name}?api-version=...
    pub fn getSecret(
        self: *SecretClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !KeyVaultSecret {
        const url = try self.buildUrl(allocator, &.{ "secrets", name }, null);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.SecretNotFound;
        }

        return parseSecret(allocator, name, resp.body);
    }

    /// PUT /secrets/{name}?api-version=...
    /// Body: {"value": "..."}
    pub fn setSecret(
        self: *SecretClient,
        allocator: std.mem.Allocator,
        name: []const u8,
        value: []const u8,
    ) !KeyVaultSecret {
        const url = try self.buildUrl(allocator, &.{ "secrets", name }, null);
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator, "{{\"value\":\"{s}\"}}", .{value});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) { _ = core.errors.errorFromResponse(resp); return error.SetSecretFailed; }

        return parseSecret(allocator, name, resp.body);
    }

    /// DELETE /secrets/{name}?api-version=...
    pub fn deleteSecret(
        self: *SecretClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !DeletedSecret {
        const url = try self.buildUrl(allocator, &.{ "secrets", name }, null);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) { _ = core.errors.errorFromResponse(resp); return error.DeleteSecretFailed; }

        return .{ .name = name };
    }

    /// DELETE /deletedsecrets/{name}?api-version=...  → 204
    pub fn purgeDeletedSecret(
        self: *SecretClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !void {
        const url = try self.buildUrl(allocator, &.{ "deletedsecrets", name }, null);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.status_code != 204 and !resp.isSuccess()) return error.PurgeFailed;
    }

    /// POST /deletedsecrets/{name}/recover?api-version=...
    pub fn recoverDeletedSecret(
        self: *SecretClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !KeyVaultSecret {
        const url = try self.buildUrl(allocator, &.{ "deletedsecrets", name, "recover" }, null);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) { _ = core.errors.errorFromResponse(resp); return error.RecoverFailed; }

        return parseSecret(allocator, name, resp.body);
    }

    // ──── Helpers ────

    fn buildUrl(
        self: *SecretClient,
        allocator: std.mem.Allocator,
        path_segments: []const []const u8,
        _: ?[]const u8,
    ) ![]u8 {
        // Start with vault_url (strip trailing slash).
        var base = self.vault_url;
        if (base.len > 0 and base[base.len - 1] == '/') base = base[0 .. base.len - 1];

        var total_len: usize = base.len;
        for (path_segments) |seg| total_len += 1 + seg.len;
        // ?api-version=...
        total_len += "?api-version=".len + self.api_version.len;

        var buf = try allocator.alloc(u8, total_len);
        var pos: usize = 0;
        @memcpy(buf[pos..][0..base.len], base);
        pos += base.len;
        for (path_segments) |seg| {
            buf[pos] = '/';
            pos += 1;
            @memcpy(buf[pos..][0..seg.len], seg);
            pos += seg.len;
        }
        const suffix = "?api-version=";
        @memcpy(buf[pos..][0..suffix.len], suffix);
        pos += suffix.len;
        @memcpy(buf[pos..][0..self.api_version.len], self.api_version);
        return buf;
    }
};

/// Parse a JSON secret response into a KeyVaultSecret.
fn parseSecret(allocator: std.mem.Allocator, name: []const u8, body: []const u8) !KeyVaultSecret {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return .{ .name = name };

    defer parsed.deinit();
    const obj = if (parsed.value == .object) parsed.value.object else return .{ .name = name };

    var secret = KeyVaultSecret{ .name = name };

    if (obj.get("value")) |v| {
        if (v == .string) secret.value = try allocator.dupe(u8, v.string);
    }
    if (obj.get("id")) |v| {
        if (v == .string) secret.id = try allocator.dupe(u8, v.string);
    }
    if (obj.get("attributes")) |attrs| {
        if (attrs == .object) {
            if (attrs.object.get("enabled")) |e| {
                if (e == .bool) secret.properties.enabled = e.bool;
            }
            if (attrs.object.get("exp")) |e| {
                if (e == .integer) secret.properties.expires_on = e.integer;
            }
            if (attrs.object.get("nbf")) |e| {
                if (e == .integer) secret.properties.not_before = e.integer;
            }
            if (attrs.object.get("created")) |e| {
                if (e == .integer) secret.properties.created_on = e.integer;
            }
            if (attrs.object.get("updated")) |e| {
                if (e == .integer) secret.properties.updated_on = e.integer;
            }
        }
    }
    if (obj.get("contentType")) |v| {
        if (v == .string) secret.properties.content_type = try allocator.dupe(u8, v.string);
    }

    return secret;
}

// ─────────────────────────── Tests ───────────────────────────

test "SecretClient getSecret" {
    const allocator = std.testing.allocator;
    const body =
        \\{"value":"my-secret-value","id":"https://myvault.vault.azure.net/secrets/mysecret/abc123","attributes":{"enabled":true,"created":1700000000,"updated":1700000001}}
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = SecretClient.init(
        "https://myvault.vault.azure.net",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const secret = try client.getSecret(allocator, "mysecret");
    defer allocator.free(secret.value.?);
    defer allocator.free(secret.id.?);

    try std.testing.expectEqualStrings("mysecret", secret.name);
    try std.testing.expectEqualStrings("my-secret-value", secret.value.?);
    try std.testing.expectEqual(true, secret.properties.enabled.?);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "secrets/mysecret?api-version=") != null);
}

test "SecretClient setSecret" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"value":"new-val","id":"https://v.vault.azure.net/secrets/s/v1"}
    );
    defer mock.deinit();

    const identity2 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity2.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = SecretClient.init(
        "https://v.vault.azure.net",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const secret = try client.setSecret(allocator, "s", "new-val");
    defer allocator.free(secret.value.?);
    defer allocator.free(secret.id.?);

    try std.testing.expectEqualStrings("new-val", secret.value.?);
    try std.testing.expectEqual(core.http.Method.PUT, mock.last_method.?);
}

test "SecretClient getSecret 404" {
    const allocator = std.testing.allocator;
    const body =
        \\{"error":{"code":"SecretNotFound","message":"Secret not found"}}
    ;
    var mock = core.http.MockTransport.init(allocator, 404, body);
    defer mock.deinit();

    const identity3 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity3.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = SecretClient.init(
        "https://myvault.vault.azure.net",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const result = client.getSecret(allocator, "nonexistent");
    try std.testing.expectError(error.SecretNotFound, result);
}

test "SecretClient setSecret failure" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 403,
        \\{"error":{"code":"Forbidden","message":"Access denied"}}
    );
    defer mock.deinit();

    const identity4 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity4.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = SecretClient.init(
        "https://myvault.vault.azure.net",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const result = client.setSecret(allocator, "s", "val");
    try std.testing.expectError(error.SetSecretFailed, result);
}
