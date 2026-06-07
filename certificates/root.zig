const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");

// ─────────────────────────── Models ───────────────────────────

/// Pager type returned by `listCertificates`.
pub const CertificatePager = core.pager.PipelinePager(KeyVaultCertificate);

pub const CertificateProperties = struct {
    enabled: ?bool = null,
    not_before: ?i64 = null,
    expires_on: ?i64 = null,
    created_on: ?i64 = null,
};

pub const KeyVaultCertificate = struct {
    name: []const u8,
    id: ?[]const u8 = null,
    properties: CertificateProperties = .{},

    /// Free allocated `id`. `name` is NOT freed (borrows caller input).
    pub fn deinit(self: KeyVaultCertificate, allocator: std.mem.Allocator) void {
        if (self.id) |i| allocator.free(i);
    }
};

// ──────────────────── CertificateClient ───────────────────────

pub const CertificateClientOptions = struct {
    api_version: []const u8 = "7.6-preview.2",
};

pub const CertificateClient = struct {
    vault_url: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        vault_url: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: CertificateClientOptions,
    ) CertificateClient {
        _ = credential;
        return .{
            .vault_url = vault_url,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// GET /certificates/{name}?api-version=...
    pub fn getCertificate(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !KeyVaultCertificate {
        var r = try self.getCertificateResult(allocator, name);
        return r.unwrap(error.CertificateNotFound);
    }

    /// Same as `getCertificate` but returns `Result(KeyVaultCertificate)`.
    pub fn getCertificateResult(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !core.errors.Result(KeyVaultCertificate) {
        const url = try self.buildUrl(allocator, &.{ "certificates", name });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try parseCertificate(allocator, name, resp.body) };
    }

    /// POST /certificates/{name}/create?api-version=...
    pub fn createCertificate(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
        name: []const u8,
        subject: []const u8,
        issuer: []const u8,
    ) !KeyVaultCertificate {
        var r = try self.createCertificateResult(allocator, name, subject, issuer);
        return r.unwrap(error.CreateCertificateFailed);
    }

    /// Same as `createCertificate` but returns `Result(KeyVaultCertificate)`.
    pub fn createCertificateResult(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
        name: []const u8,
        subject: []const u8,
        issuer: []const u8,
    ) !core.errors.Result(KeyVaultCertificate) {
        const url = try self.buildUrl(allocator, &.{ "certificates", name, "create" });
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(
            allocator,
            "{{\"policy\":{{\"x509_props\":{{\"subject\":\"{s}\"}},\"issuer\":{{\"name\":\"{s}\"}}}}}}",
            .{ subject, issuer },
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

        return .{ .ok = try parseCertificate(allocator, name, resp.body) };
    }

    /// DELETE /certificates/{name}?api-version=...
    pub fn deleteCertificate(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !void {
        var r = try self.deleteCertificateResult(allocator, name);
        try r.unwrap(error.DeleteCertificateFailed);
    }

    /// Same as `deleteCertificate` but returns `Result(void)`.
    pub fn deleteCertificateResult(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !core.errors.Result(void) {
        const url = try self.buildUrl(allocator, &.{ "certificates", name });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (resp.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
            return .{ .err = az_err };
        }
        return error.AzureRequestFailed;
    }

    /// GET /certificates?api-version=... — returns a pager over certificates.
    pub fn listCertificates(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
    ) !CertificatePager {
        const url = try self.buildUrl(allocator, &.{"certificates"});
        defer allocator.free(url);

        return CertificatePager.init(
            self.pipeline,
            url,
            allocator,
            &parseCertificateListPage,
            "application/json",
        );
    }

    fn buildUrl(self: *CertificateClient, allocator: std.mem.Allocator, path_segments: []const []const u8) ![]u8 {
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

// ─────────────────────────── Parsing ──────────────────────────

const CertAttributesSchema = struct {
    enabled: ?bool = null,
    nbf: ?i64 = null,
    exp: ?i64 = null,
    created: ?i64 = null,
};

const CertSchema = struct {
    id: ?[]const u8 = null,
    attributes: ?CertAttributesSchema = null,
};

fn parseCertificate(allocator: std.mem.Allocator, name: []const u8, body: []const u8) !KeyVaultCertificate {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(CertSchema, arena.allocator(), body) catch
        return .{ .name = name };

    var cert = KeyVaultCertificate{ .name = name };
    if (parsed.id) |v| cert.id = try allocator.dupe(u8, v);
    if (parsed.attributes) |a| {
        cert.properties.enabled = a.enabled;
        cert.properties.not_before = a.nbf;
        cert.properties.expires_on = a.exp;
        cert.properties.created_on = a.created;
    }
    return cert;
}

const CertListEntrySchema = struct {
    id: ?[]const u8 = null,
};

const CertListSchema = struct {
    value: ?[]const CertListEntrySchema = null,
    nextLink: ?[]const u8 = null,
};

fn parseCertificateListPage(allocator: std.mem.Allocator, body: []const u8) !core.pager.PageResult(KeyVaultCertificate) {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(CertListSchema, arena.allocator(), body) catch
        return .{ .items = try allocator.alloc(KeyVaultCertificate, 0) };

    var next_link: ?[]u8 = null;
    if (parsed.nextLink) |nl| {
        if (nl.len > 0) next_link = try allocator.dupe(u8, nl);
    }

    const entries = parsed.value orelse
        return .{ .items = try allocator.alloc(KeyVaultCertificate, 0), .next_link = next_link };

    var result = try allocator.alloc(KeyVaultCertificate, entries.len);
    for (entries, 0..) |entry, i| {
        var cert = KeyVaultCertificate{ .name = "" };
        if (entry.id) |id| cert.id = try allocator.dupe(u8, id);
        result[i] = cert;
    }
    return .{ .items = result, .next_link = next_link };
}

// ─────────────────────────── Tests ────────────────────────────

test "CertificateClient getCertificate" {
    const allocator = std.testing.allocator;
    const body =
        \\{"id":"https://vault.azure.net/certificates/mycert/v1","attributes":{"enabled":true,"created":1700000000,"exp":1800000000}}
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    const identity = @import("azure_core").identity;
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var client = CertificateClient.init(
        "https://vault.azure.net",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    const cert = try client.getCertificate(allocator, "mycert");
    defer allocator.free(cert.id.?);

    try std.testing.expectEqualStrings("mycert", cert.name);
    try std.testing.expectEqual(true, cert.properties.enabled.?);
    try std.testing.expectEqual(@as(i64, 1800000000), cert.properties.expires_on.?);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "certificates/mycert?api-version=") != null);
}
