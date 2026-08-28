///! Base64 encoding/decoding utilities for Azure SDK.
///!
///! Wraps `std.base64.standard` with allocator-aware helpers.
const std = @import("std");
const crypto = @import("crypto.zig");

const encoder = std.base64.standard.Encoder;
const decoder = std.base64.standard.Decoder;
const url_encoder = std.base64.url_safe_no_pad.Encoder;
const url_decoder = std.base64.url_safe_no_pad.Decoder;

/// Base64-encode `data`, returning an allocator-owned slice.
pub fn encode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const size = encoder.calcSize(data.len);
    const buf = try allocator.alloc(u8, size);
    _ = encoder.encode(buf, data);
    return buf;
}

/// Base64-decode `encoded`, returning an allocator-owned slice.
pub fn decode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const size = try decoder.calcSizeForSlice(encoded);
    const buf = try allocator.alloc(u8, size);
    errdefer allocator.free(buf);
    try decoder.decode(buf, encoded);
    return buf;
}

/// Base64url-encode `data` without padding, as required by Azure Key Vault.
pub fn urlEncode(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const size = url_encoder.calcSize(data.len);
    const buf = try allocator.alloc(u8, size);
    _ = url_encoder.encode(buf, data);
    return buf;
}

/// Decode unpadded base64url data.
pub fn urlDecode(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const size = try url_decoder.calcSizeForSlice(encoded);
    const buf = try allocator.alloc(u8, size);
    errdefer allocator.free(buf);
    try url_decoder.decode(buf, encoded);
    return buf;
}

// ─────────────── Crypto helpers (thin wrappers) ───────────────

fn wipe(bytes: []u8) void {
    const volatile_bytes: []volatile u8 = bytes;
    @memset(volatile_bytes, 0);
}

/// HMAC-SHA256: sign `message` with `key`, return base64-encoded MAC.
pub fn hmacSha256Base64(
    allocator: std.mem.Allocator,
    provider: crypto.CryptoProvider,
    key: []const u8,
    message: []const u8,
) ![]u8 {
    var mac = try provider.hmacSha256(key, message);
    defer wipe(&mac);
    return encode(allocator, &mac);
}

/// SHA-256 hash of `data`, base64-encoded.
pub fn sha256Base64(
    allocator: std.mem.Allocator,
    provider: crypto.CryptoProvider,
    data: []const u8,
) ![]u8 {
    var hash = try provider.sha256(data);
    defer wipe(&hash);
    return encode(allocator, &hash);
}

/// MD5 hash of `data`, base64-encoded for integrity and compatibility only.
///
/// MD5 must not be used as a security primitive.
pub fn md5Base64(
    allocator: std.mem.Allocator,
    provider: crypto.CryptoProvider,
    data: []const u8,
) ![]u8 {
    var hash = try provider.md5(data);
    defer wipe(&hash);
    return encode(allocator, &hash);
}

// ─────────────── Tests ───────────────

test "base64 round-trip" {
    const allocator = std.testing.allocator;
    const original = "Hello, Azure!";
    const encoded = try encode(allocator, original);
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("SGVsbG8sIEF6dXJlIQ==", encoded);

    const decoded = try decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(original, decoded);
}

test "base64 empty" {
    const allocator = std.testing.allocator;
    const encoded = try encode(allocator, "");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("", encoded);
}

test "base64url round-trip without padding" {
    const allocator = std.testing.allocator;
    const encoded = try urlEncode(allocator, &.{ 0xfb, 0xff, 0xfe });
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("-__-", encoded);
    const decoded = try urlDecode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &.{ 0xfb, 0xff, 0xfe }, decoded);
}

test "invalid base64url does not leak" {
    try std.testing.expectError(
        error.InvalidCharacter,
        urlDecode(std.testing.allocator, "a!"),
    );
}

const TestCryptoProvider = struct {
    const Operation = enum {
        none,
        md5,
        sha256,
        hmac_sha256,
    };

    calls: usize = 0,
    operation: Operation = .none,
    data: []const u8 = "",
    key: []const u8 = "",
    message: []const u8 = "",
    fail: bool = false,

    const vtable: crypto.CryptoProvider.VTable = .{
        .random_bytes = &randomBytes,
        .md5 = &md5,
        .sha256 = &sha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &sha256Init,
    };

    fn provider(self: *@This()) crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn record(self: *@This(), operation: Operation) !void {
        self.calls += 1;
        self.operation = operation;
        if (self.fail) return error.ProviderFailure;
    }

    fn randomBytes(_: *anyopaque, _: []u8) !void {
        return error.Unused;
    }

    fn md5(context: *anyopaque, data: []const u8, out: *crypto.Md5Digest) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.data = data;
        @memset(out, 0xa5);
        try self.record(.md5);
    }

    fn sha256(context: *anyopaque, data: []const u8, out: *crypto.Sha256Digest) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.data = data;
        @memset(out, 0xa5);
        try self.record(.sha256);
    }

    fn hmacSha256(
        context: *anyopaque,
        key: []const u8,
        message: []const u8,
        out: *crypto.HmacSha256Digest,
    ) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.key = key;
        self.message = message;
        @memset(out, 0xa5);
        try self.record(.hmac_sha256);
    }

    fn sha256Init(
        _: *anyopaque,
        _: std.mem.Allocator,
    ) !crypto.Sha256Operation {
        return error.Unused;
    }
};

test "provider-backed base64 crypto helpers use standard vectors" {
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const provider = provider_impl.asProvider();

    const mac = try hmacSha256Base64(allocator, provider, "key", "");
    defer allocator.free(mac);
    try std.testing.expectEqualStrings(
        "XV0TlWPJW1lnub2ajJsjOp3ttFByeUzSMtwbdIMmB9A=",
        mac,
    );

    const sha256 = try sha256Base64(allocator, provider, "hello");
    defer allocator.free(sha256);
    try std.testing.expectEqualStrings(
        "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=",
        sha256,
    );

    const md5 = try md5Base64(allocator, provider, "hello");
    defer allocator.free(md5);
    try std.testing.expectEqualStrings("XUFAKrxLKna5cZ2REBfFkg==", md5);
}

test "provider-backed base64 crypto helpers handle empty input" {
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const provider = provider_impl.asProvider();

    const sha256 = try sha256Base64(allocator, provider, "");
    defer allocator.free(sha256);
    try std.testing.expectEqualStrings(
        "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=",
        sha256,
    );

    const md5 = try md5Base64(allocator, provider, "");
    defer allocator.free(md5);
    try std.testing.expectEqualStrings("1B2M2Y8AsgTpgAmY7PhCfg==", md5);
}

test "base64 crypto helpers dispatch to the selected provider" {
    const allocator = std.testing.allocator;
    var spy = TestCryptoProvider{};
    const provider = spy.provider();

    const md5 = try md5Base64(allocator, provider, "md5-data");
    defer allocator.free(md5);
    try std.testing.expectEqual(.md5, spy.operation);
    try std.testing.expectEqualStrings("md5-data", spy.data);
    try std.testing.expectEqualStrings("paWlpaWlpaWlpaWlpaWlpQ==", md5);

    const sha256 = try sha256Base64(allocator, provider, "sha-data");
    defer allocator.free(sha256);
    try std.testing.expectEqual(.sha256, spy.operation);
    try std.testing.expectEqualStrings("sha-data", spy.data);
    try std.testing.expectEqualStrings(
        "paWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaU=",
        sha256,
    );

    const mac = try hmacSha256Base64(allocator, provider, "secret", "message");
    defer allocator.free(mac);
    try std.testing.expectEqual(.hmac_sha256, spy.operation);
    try std.testing.expectEqualStrings("secret", spy.key);
    try std.testing.expectEqualStrings("message", spy.message);
    try std.testing.expectEqualStrings(
        "paWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaU=",
        mac,
    );
    try std.testing.expectEqual(@as(usize, 3), spy.calls);
}

test "provider failures propagate before base64 output allocation" {
    var fault = TestCryptoProvider{ .fail = true };
    const provider = fault.provider();

    try std.testing.expectError(
        error.ProviderFailure,
        md5Base64(std.testing.failing_allocator, provider, "data"),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        sha256Base64(std.testing.failing_allocator, provider, "data"),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        hmacSha256Base64(std.testing.failing_allocator, provider, "key", "message"),
    );
    try std.testing.expectEqual(@as(usize, 3), fault.calls);
}

test "base64 crypto helpers return allocation failures without output" {
    var spy = TestCryptoProvider{};
    const provider = spy.provider();

    try std.testing.expectError(
        error.OutOfMemory,
        md5Base64(std.testing.failing_allocator, provider, "data"),
    );
    try std.testing.expectError(
        error.OutOfMemory,
        sha256Base64(std.testing.failing_allocator, provider, "data"),
    );
    try std.testing.expectError(
        error.OutOfMemory,
        hmacSha256Base64(std.testing.failing_allocator, provider, "key", "message"),
    );
    try std.testing.expectEqual(@as(usize, 3), spy.calls);
}
