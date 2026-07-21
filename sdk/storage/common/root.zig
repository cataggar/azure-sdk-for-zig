const std = @import("std");
const core = @import("azure_core");
const base64 = core.base64;

pub const sas = @import("sas.zig");

test {
    std.testing.refAllDecls(sas);
}

const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;

/// Shared Key credential for Azure Storage.
///
/// Signs requests with HMAC-SHA256 over a canonical string,
/// adding the `Authorization: SharedKey <account>:<signature>` header.
pub const StorageSharedKeyCredential = struct {
    account_name: []const u8,
    account_key: []const u8,

    pub fn init(account_name: []const u8, account_key: []const u8) StorageSharedKeyCredential {
        return .{
            .account_name = account_name,
            .account_key = account_key,
        };
    }

    /// Sign a request in-place by computing the SharedKey authorization header.
    ///
    /// Builds a canonical string from the request method, standard headers,
    /// x-ms-* headers, and the resource path, then HMAC-SHA256 signs it
    /// with the base64-decoded account key.
    pub fn signRequest(self: StorageSharedKeyCredential, request: *core.http.Request) !void {
        const allocator = request.allocator;

        // 1. Decode the base64 account key.
        const key = try base64.decode(allocator, self.account_key);
        defer allocator.free(key);

        // 2. Build the canonical string.
        //    Format: METHOD\n{Content-*}\n{x-ms-date}\n{CanonicalizedResource}
        const method_str = @tagName(request.method);
        const content_length = request.headers.get("Content-Length") orelse "";
        const content_type = request.headers.get("Content-Type") orelse "";
        const date = request.headers.get("x-ms-date") orelse request.headers.get("Date") orelse "";
        const ms_version = request.headers.get("x-ms-version") orelse "";

        // Extract resource path from URL.
        const resource = extractResource(request.url, self.account_name);

        // Simplified canonical string (Blob service format).
        const string_to_sign = try std.fmt.allocPrint(
            allocator,
            "{s}\n\n\n{s}\n\n{s}\n\n\n\n\n\n\nx-ms-date:{s}\nx-ms-version:{s}\n/{s}{s}",
            .{ method_str, content_length, content_type, date, ms_version, self.account_name, resource },
        );
        defer allocator.free(string_to_sign);

        // 3. HMAC-SHA256 sign.
        var mac: [HmacSha256.mac_length]u8 = undefined;
        HmacSha256.create(&mac, string_to_sign, key);

        // 4. Base64-encode the signature.
        const signature = try base64.encode(allocator, &mac);
        defer allocator.free(signature);

        // 5. Set Authorization header.
        const auth = try std.fmt.allocPrint(allocator, "SharedKey {s}:{s}", .{ self.account_name, signature });
        defer allocator.free(auth);
        try request.setHeader("Authorization", auth);
    }
};

/// Extract the path portion from a URL for the canonicalized resource.
fn extractResource(url: []const u8, account_name: []const u8) []const u8 {
    // Find the path after the host.
    _ = account_name;
    if (std.mem.find(u8, url, "://")) |schema_end| {
        const after_schema = url[schema_end + 3 ..];
        if (std.mem.findScalar(u8, after_schema, '/')) |slash| {
            return after_schema[slash..];
        }
    }
    return "/";
}

/// Generate a service-level or resource-level SAS token.
pub const SasBuilder = struct {
    permissions: []const u8 = "r",
    resource_types: []const u8 = "sco",
    services: []const u8 = "b",
    expiry: []const u8,
    protocol: []const u8 = "https",
    version: []const u8 = "2024-11-04",

    /// Render the SAS query string (without leading '?'), unsigned.
    pub fn toQueryString(self: SasBuilder, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "sv={s}&ss={s}&srt={s}&sp={s}&se={s}&spr={s}",
            .{ self.version, self.services, self.resource_types, self.permissions, self.expiry, self.protocol },
        );
    }

    /// Build the string-to-sign, HMAC-SHA256 it, and return the full
    /// SAS query string with `&sig=<base64url-encoded-signature>`.
    pub fn sign(self: SasBuilder, allocator: std.mem.Allocator, account_key: []const u8) ![]u8 {
        // Decode key.
        const key = try base64.decode(allocator, account_key);
        defer allocator.free(key);

        // String to sign for account SAS.
        const string_to_sign = try std.fmt.allocPrint(
            allocator,
            "{s}\n{s}\n{s}\n{s}\n\n{s}\n\n{s}\n",
            .{ self.permissions, self.services, self.resource_types, self.expiry, self.protocol, self.version },
        );
        defer allocator.free(string_to_sign);

        // HMAC-SHA256.
        var mac: [HmacSha256.mac_length]u8 = undefined;
        HmacSha256.create(&mac, string_to_sign, key);

        const sig = try base64.encode(allocator, &mac);
        defer allocator.free(sig);

        // Build the full query string with sig.
        const qs = try self.toQueryString(allocator);
        defer allocator.free(qs);

        return std.fmt.allocPrint(allocator, "{s}&sig={s}", .{ qs, sig });
    }
};

/// Storage-specific retry options (e.g. secondary endpoint failover).
pub const StorageRetryOptions = struct {
    max_retries: u32 = 4,
    initial_delay_ms: u64 = 800,
    max_delay_ms: u64 = 120_000,
    secondary_host: ?[]const u8 = null,
};

// ─────────────── Content hash helpers ───────────────

/// Compute Content-MD5 for a blob body (base64-encoded MD5).
pub fn contentMd5(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    return base64.md5Base64(allocator, body);
}

/// Compute x-ms-content-sha256 header value (base64-encoded SHA-256).
pub fn contentSha256(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    return base64.sha256Base64(allocator, body);
}

// ─────────────── Tests ───────────────

test "StorageSharedKeyCredential signRequest produces real HMAC" {
    const allocator = std.testing.allocator;
    // Use a known base64 key (32 bytes of zeros → "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=").
    const cred = StorageSharedKeyCredential.init("myaccount", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=");
    var req = core.http.Request.init(allocator, .GET, "https://myaccount.blob.core.windows.net/container/blob");
    defer req.deinit();
    try req.setHeader("x-ms-date", "Sun, 01 Apr 2026 12:00:00 GMT");
    try req.setHeader("x-ms-version", "2024-11-04");

    try cred.signRequest(&req);
    const auth = req.headers.get("Authorization").?;
    // Must start with "SharedKey myaccount:" followed by a 44-char base64 signature.
    try std.testing.expect(std.mem.startsWith(u8, auth, "SharedKey myaccount:"));
    try std.testing.expect(auth.len == "SharedKey myaccount:".len + 44);
}

test "SasBuilder sign produces HMAC signature" {
    const allocator = std.testing.allocator;
    const builder = SasBuilder{
        .permissions = "rl",
        .expiry = "2026-12-31T23:59:59Z",
    };
    const qs = try builder.sign(allocator, "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=");
    defer allocator.free(qs);
    // Must contain sig= with a base64 value.
    try std.testing.expect(std.mem.find(u8, qs, "&sig=") != null);
    try std.testing.expect(std.mem.find(u8, qs, "sp=rl") != null);
}

test "SasBuilder toQueryString unsigned" {
    const allocator = std.testing.allocator;
    const builder = SasBuilder{
        .permissions = "rl",
        .expiry = "2026-12-31T23:59:59Z",
    };
    const qs = try builder.toQueryString(allocator);
    defer allocator.free(qs);
    try std.testing.expect(std.mem.find(u8, qs, "sp=rl") != null);
    try std.testing.expect(std.mem.find(u8, qs, "se=2026-12-31T23:59:59Z") != null);
}

test "contentMd5" {
    const allocator = std.testing.allocator;
    const md5 = try contentMd5(allocator, "hello");
    defer allocator.free(md5);
    try std.testing.expectEqualStrings("XUFAKrxLKna5cZ2REBfFkg==", md5);
}

test "contentSha256" {
    const allocator = std.testing.allocator;
    const sha = try contentSha256(allocator, "hello");
    defer allocator.free(sha);
    try std.testing.expectEqualStrings("LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=", sha);
}

test "extractResource" {
    const r = extractResource("https://myaccount.blob.core.windows.net/container/blob?x=1", "myaccount");
    try std.testing.expect(std.mem.startsWith(u8, r, "/container/blob"));
}
