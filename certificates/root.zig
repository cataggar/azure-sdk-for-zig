const std = @import("std");
const core = @import("azure_core");

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
        const url = try self.buildUrl(allocator, &.{ "certificates", name });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.CertificateNotFound;
        }

        return parseCertificate(allocator, name, resp.body);
    }

    /// POST /certificates/{name}/create?api-version=...
    pub fn createCertificate(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
        name: []const u8,
        subject: []const u8,
        issuer: []const u8,
    ) !KeyVaultCertificate {
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
            _ = core.errors.errorFromResponse(resp);
            return error.CreateCertificateFailed;
        }

        return parseCertificate(allocator, name, resp.body);
    }

    /// DELETE /certificates/{name}?api-version=...
    pub fn deleteCertificate(
        self: *CertificateClient,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !void {
        const url = try self.buildUrl(allocator, &.{ "certificates", name });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            _ = core.errors.errorFromResponse(resp);
            return error.DeleteCertificateFailed;
        }
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

fn parseCertificate(allocator: std.mem.Allocator, name: []const u8, body: []const u8) !KeyVaultCertificate {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return .{ .name = name };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return .{ .name = name };

    var cert = KeyVaultCertificate{ .name = name };

    if (obj.get("id")) |v| {
        if (v == .string) cert.id = try allocator.dupe(u8, v.string);
    }
    if (obj.get("attributes")) |attrs| {
        if (attrs == .object) {
            if (attrs.object.get("enabled")) |e| {
                if (e == .bool) cert.properties.enabled = e.bool;
            }
            if (attrs.object.get("nbf")) |e| {
                if (e == .integer) cert.properties.not_before = e.integer;
            }
            if (attrs.object.get("exp")) |e| {
                if (e == .integer) cert.properties.expires_on = e.integer;
            }
            if (attrs.object.get("created")) |e| {
                if (e == .integer) cert.properties.created_on = e.integer;
            }
        }
    }

    return cert;
}

fn parseCertificateListPage(allocator: std.mem.Allocator, body: []const u8) !core.pager.PageResult(KeyVaultCertificate) {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return .{ .items = try allocator.alloc(KeyVaultCertificate, 0) };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return .{ .items = try allocator.alloc(KeyVaultCertificate, 0) };

    var next_link: ?[]u8 = null;
    if (obj.get("nextLink")) |nl| {
        if (nl == .string and nl.string.len > 0)
            next_link = try allocator.dupe(u8, nl.string);
    }

    const values = if (obj.get("value")) |v| (if (v == .array) v.array.items else null) else null;
    const items = values orelse return .{ .items = try allocator.alloc(KeyVaultCertificate, 0), .next_link = next_link };

    var result = try allocator.alloc(KeyVaultCertificate, items.len);
    for (items, 0..) |item, i| {
        var cert = KeyVaultCertificate{ .name = "" };
        if (item == .object) {
            if (item.object.get("id")) |id| {
                if (id == .string) cert.id = try allocator.dupe(u8, id.string);
            }
        }
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

    const identity = @import("azure_identity");
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
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "certificates/mycert?api-version=") != null);
}
