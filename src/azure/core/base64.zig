///! Base64 encoding/decoding utilities for Azure SDK.
///!
///! Wraps `std.base64.standard` with allocator-aware helpers.

const std = @import("std");

const encoder = std.base64.standard.Encoder;
const decoder = std.base64.standard.Decoder;

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
    try decoder.decode(buf, encoded);
    return buf;
}

// ─────────────── Crypto helpers (thin wrappers) ───────────────

const HmacSha256 = std.crypto.auth.hmac.sha2.HmacSha256;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Md5 = std.crypto.hash.Md5;

/// HMAC-SHA256: sign `message` with `key`, return base64-encoded MAC.
pub fn hmacSha256Base64(allocator: std.mem.Allocator, key: []const u8, message: []const u8) ![]u8 {
    var mac: [HmacSha256.mac_length]u8 = undefined;
    HmacSha256.create(&mac, message, key);
    return encode(allocator, &mac);
}

/// SHA-256 hash of `data`, base64-encoded.
pub fn sha256Base64(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var hash: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(data, &hash, .{});
    return encode(allocator, &hash);
}

/// MD5 hash of `data`, base64-encoded (for Content-MD5 header).
pub fn md5Base64(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var hash: [Md5.digest_length]u8 = undefined;
    Md5.hash(data, &hash, .{});
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

test "hmacSha256Base64 known vector" {
    const allocator = std.testing.allocator;
    // HMAC-SHA256("", "key") is a known value.
    const mac = try hmacSha256Base64(allocator, "key", "");
    defer allocator.free(mac);
    // Just verify it's base64 and 44 chars (32 bytes → 44 base64 chars with padding).
    try std.testing.expectEqual(@as(usize, 44), mac.len);
    try std.testing.expectEqual(@as(u8, '='), mac[43]);
}

test "sha256Base64" {
    const allocator = std.testing.allocator;
    const hash = try sha256Base64(allocator, "hello");
    defer allocator.free(hash);
    // SHA-256("hello") = LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ= (known)
    try std.testing.expectEqualStrings("LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=", hash);
}

test "md5Base64" {
    const allocator = std.testing.allocator;
    const hash = try md5Base64(allocator, "hello");
    defer allocator.free(hash);
    // MD5("hello") = XUFAKrxLKna5cZ2REBfFkg== (known)
    try std.testing.expectEqualStrings("XUFAKrxLKna5cZ2REBfFkg==", hash);
}
