///! Safe debug formatting for types containing sensitive data.
///!
///! Types like tokens, keys, and connection strings should not appear
///! in logs or debug output. This module provides formatting helpers
///! that redact sensitive fields.
const std = @import("std");

/// Redacted placeholder shown instead of sensitive values.
pub const redacted = "***";

/// Format a string, redacting it if it looks sensitive.
/// Shows first 4 and last 4 characters with '***' in between
/// if the string is long enough; otherwise fully redacts.
pub fn redactValue(value: []const u8) []const u8 {
    if (value.len == 0) return "";
    return redacted;
}

/// Check if a field name suggests it contains sensitive data.
pub fn isSensitiveField(name: []const u8) bool {
    const sensitive_names = [_][]const u8{
        "token",
        "access_token",
        "secret",
        "client_secret",
        "password",
        "key",
        "connection_string",
        "sas_token",
        "authorization",
        "api_key",
    };
    for (sensitive_names) |s| {
        if (eqlIgnoreCase(name, s)) return true;
    }
    return false;
}

/// Format a key-value pair, redacting the value if the key is sensitive.
pub fn formatField(writer: anytype, name: []const u8, value: []const u8) !void {
    try writer.writeAll(name);
    try writer.writeAll("=");
    if (isSensitiveField(name)) {
        try writer.writeAll(redacted);
    } else {
        try writer.writeAll(value);
    }
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
    }
    return true;
}

// ─────────────────────── Tests ───────────────────────

test "isSensitiveField" {
    try std.testing.expect(isSensitiveField("token"));
    try std.testing.expect(isSensitiveField("Token"));
    try std.testing.expect(isSensitiveField("access_token"));
    try std.testing.expect(isSensitiveField("client_secret"));
    try std.testing.expect(isSensitiveField("password"));
    try std.testing.expect(isSensitiveField("api_key"));
    try std.testing.expect(!isSensitiveField("name"));
    try std.testing.expect(!isSensitiveField("status"));
    try std.testing.expect(!isSensitiveField("content_type"));
}

test "redactValue" {
    try std.testing.expectEqualStrings(redacted, redactValue("my-secret-value"));
    try std.testing.expectEqualStrings("", redactValue(""));
}

test "formatField redacts sensitive" {
    var buf: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buf);

    try formatField(&writer, "token", "eyJhbGciOiJ...");
    try std.testing.expectEqualStrings("token=***", buf[0..writer.end]);

    writer.end = 0;
    try formatField(&writer, "name", "my-secret");
    try std.testing.expectEqualStrings("name=my-secret", buf[0..writer.end]);
}
