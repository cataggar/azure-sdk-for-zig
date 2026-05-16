const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");

// ─────────────────────────── Models ───────────────────────────

/// Pager type returned by `listKeys`.
pub const KeyPager = core.pager.PipelinePager(KeyVaultKey);

pub const KeyProperties = struct {
    key_type: ?[]const u8 = null,
    key_ops: ?[]const []const u8 = null,
    enabled: ?bool = null,
    created_on: ?i64 = null,
    updated_on: ?i64 = null,
};

pub const KeyVaultKey = struct {
    name: []const u8,
    id: ?[]const u8 = null,
    key_type: ?[]const u8 = null,
    properties: KeyProperties = .{},
};

// ─────────────────────────── KeyClient ────────────────────────

pub const KeyClientOptions = struct {
    api_version: []const u8 = "7.6-preview.2",
};

pub const KeyClient = struct {
    vault_url: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        vault_url: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: KeyClientOptions,
    ) KeyClient {
        _ = credential;
        return .{
            .vault_url = vault_url,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// POST /keys/{name}/create?api-version=...
    pub fn createKey(
        self: *KeyClient,
        allocator: std.mem.Allocator,
        name: []const u8,
        key_type: []const u8,
    ) !KeyVaultKey {
        const url = try self.buildUrl(allocator, &.{ "keys", name, "create" });
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator, "{{\"kty\":\"{s}\"}}", .{key_type});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.CreateKeyFailed;
        }

        return parseKey(allocator, name, resp.body);
    }

    /// GET /keys/{name}?api-version=...
    pub fn getKey(
        self: *KeyClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !KeyVaultKey {
        const url = try self.buildUrl(allocator, &.{ "keys", name });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.KeyNotFound;
        }

        return parseKey(allocator, name, resp.body);
    }

    /// DELETE /keys/{name}?api-version=...
    pub fn deleteKey(
        self: *KeyClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !void {
        const url = try self.buildUrl(allocator, &.{ "keys", name });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.DeleteKeyFailed;
        }
    }

    /// GET /keys?api-version=... — returns a pager over keys.
    ///
    /// Usage:
    ///   var pager = try client.listKeys(allocator);
    ///   defer pager.deinit();
    ///   while (try pager.next()) |keys| {
    ///       defer allocator.free(keys);
    ///       for (keys) |key| { if (key.id) |id| allocator.free(id); }
    ///   }
    pub fn listKeys(
        self: *KeyClient,
        allocator: std.mem.Allocator,
    ) !KeyPager {
        const url = try self.buildUrl(allocator, &.{"keys"});
        defer allocator.free(url);

        return KeyPager.init(
            self.pipeline,
            url,
            allocator,
            &parseKeyListPage,
            "application/json",
        );
    }

    fn buildUrl(self: *KeyClient, allocator: std.mem.Allocator, path_segments: []const []const u8) ![]u8 {
        var base = self.vault_url;
        if (base.len > 0 and base[base.len - 1] == '/') base = base[0 .. base.len - 1];

        var total_len: usize = base.len;
        for (path_segments) |seg| total_len += 1 + seg.len;
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

// ──────────────────── CryptographyClient ──────────────────────

pub const CryptographyClient = struct {
    vault_url: []const u8,
    key_name: []const u8,
    key_version: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        vault_url: []const u8,
        key_name: []const u8,
        key_version: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
    ) CryptographyClient {
        _ = credential;
        return .{
            .vault_url = vault_url,
            .key_name = key_name,
            .key_version = key_version,
            .api_version = "7.6-preview.2",
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// POST /keys/{name}/{version}/encrypt
    pub fn encrypt(self: *CryptographyClient, allocator: std.mem.Allocator, algorithm: []const u8, plaintext: []const u8) ![]const u8 {
        return self.cryptoOperation(allocator, "encrypt", algorithm, plaintext);
    }

    /// POST /keys/{name}/{version}/decrypt
    pub fn decrypt(self: *CryptographyClient, allocator: std.mem.Allocator, algorithm: []const u8, ciphertext: []const u8) ![]const u8 {
        return self.cryptoOperation(allocator, "decrypt", algorithm, ciphertext);
    }

    /// POST /keys/{name}/{version}/sign
    pub fn sign(self: *CryptographyClient, allocator: std.mem.Allocator, algorithm: []const u8, digest: []const u8) ![]const u8 {
        return self.cryptoOperation(allocator, "sign", algorithm, digest);
    }

    /// POST /keys/{name}/{version}/verify
    pub fn verify(self: *CryptographyClient, allocator: std.mem.Allocator, algorithm: []const u8, digest: []const u8) ![]const u8 {
        return self.cryptoOperation(allocator, "verify", algorithm, digest);
    }

    fn cryptoOperation(
        self: *CryptographyClient,
        allocator: std.mem.Allocator,
        operation: []const u8,
        algorithm: []const u8,
        value: []const u8,
    ) ![]const u8 {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/keys/{s}/{s}/{s}?api-version={s}",
            .{ self.vault_url, self.key_name, self.key_version, operation, self.api_version },
        );
        defer allocator.free(url);

        // Azure KV requires base64url-encoded values for crypto operations.
        const base64 = core.base64;
        const encoded_value = try base64.encode(allocator, value);
        defer allocator.free(encoded_value);

        const body = try std.fmt.allocPrint(
            allocator,
            "{{\"alg\":\"{s}\",\"value\":\"{s}\"}}",
            .{ algorithm, encoded_value },
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
            core.errors.logErrorResponse(resp);
            return error.CryptoOperationFailed;
        }

        return allocator.dupe(u8, resp.body);
    }
};

// ─────────────────────────── Parsing ──────────────────────────

const KeyMaterialSchema = struct {
    kid: ?[]const u8 = null,
    kty: ?[]const u8 = null,
};

const KeyAttributesSchema = struct {
    enabled: ?bool = null,
    created: ?i64 = null,
    updated: ?i64 = null,
};

const KeySchema = struct {
    key: ?KeyMaterialSchema = null,
    attributes: ?KeyAttributesSchema = null,
};

fn parseKey(allocator: std.mem.Allocator, name: []const u8, body: []const u8) !KeyVaultKey {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(KeySchema, arena.allocator(), body) catch
        return .{ .name = name };

    var key = KeyVaultKey{ .name = name };
    if (parsed.key) |k| {
        if (k.kid) |v| key.id = try allocator.dupe(u8, v);
        if (k.kty) |v| key.key_type = try allocator.dupe(u8, v);
    }
    if (parsed.attributes) |a| {
        key.properties.enabled = a.enabled;
        key.properties.created_on = a.created;
        key.properties.updated_on = a.updated;
    }
    return key;
}

const KeyListEntrySchema = struct {
    kid: ?[]const u8 = null,
};

const KeyListSchema = struct {
    value: ?[]const KeyListEntrySchema = null,
    nextLink: ?[]const u8 = null,
};

fn parseKeyListPage(allocator: std.mem.Allocator, body: []const u8) !core.pager.PageResult(KeyVaultKey) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(KeyListSchema, arena.allocator(), body) catch
        return .{ .items = try allocator.alloc(KeyVaultKey, 0) };

    var next_link: ?[]u8 = null;
    if (parsed.nextLink) |nl| {
        if (nl.len > 0) next_link = try allocator.dupe(u8, nl);
    }

    const entries = parsed.value orelse
        return .{ .items = try allocator.alloc(KeyVaultKey, 0), .next_link = next_link };

    var result = try allocator.alloc(KeyVaultKey, entries.len);
    for (entries, 0..) |entry, i| {
        var key = KeyVaultKey{ .name = "" };
        if (entry.kid) |kid| key.id = try allocator.dupe(u8, kid);
        result[i] = key;
    }
    return .{ .items = result, .next_link = next_link };
}

// ─────────────────────────── Tests ────────────────────────────

test "KeyClient createKey and getKey" {
    const allocator = std.testing.allocator;
    const body =
        \\{"key":{"kid":"https://vault.azure.net/keys/mykey/v1","kty":"RSA"},"attributes":{"enabled":true,"created":1700000000,"updated":1700000001}}
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = KeyClient.init(
        "https://vault.azure.net",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const key = try client.createKey(allocator, "mykey", "RSA");
    defer allocator.free(key.id.?);
    defer allocator.free(key.key_type.?);

    try std.testing.expectEqualStrings("mykey", key.name);
    try std.testing.expectEqualStrings("RSA", key.key_type.?);
    try std.testing.expectEqual(true, key.properties.enabled.?);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "keys/mykey/create?api-version=") != null);
}

test "CryptographyClient encrypt" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"value":"encrypted-result"}
    );
    defer mock.deinit();

    const identity2 = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity2.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var crypto = CryptographyClient.init(
        "https://vault.azure.net",
        "mykey",
        "v1",
        cred.asCredential(),
        mock.asTransport(),
    );

    const result = try crypto.encrypt(allocator, "RSA-OAEP", "plaintext");
    defer allocator.free(result);

    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "keys/mykey/v1/encrypt") != null);
}
