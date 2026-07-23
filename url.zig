const std = @import("std");

/// Parsed URL with query-parameter builder, wrapping `std.Uri`.
pub const Url = struct {
    scheme: []const u8 = "https",
    host: []const u8 = "",
    port: ?u16 = null,
    path: []const u8 = "/",
    raw_query: []const u8 = "",

    /// Parse a URL string.
    pub fn parse(raw: []const u8) !Url {
        const uri = try std.Uri.parse(raw);
        return .{
            .scheme = if (uri.scheme.len > 0) uri.scheme else "https",
            .host = if (uri.host) |h| switch (h) {
                .raw => |r| r,
                .percent_encoded => |pe| pe,
            } else "",
            .port = uri.port,
            .path = if (uri.path.isEmpty()) "/" else switch (uri.path) {
                .raw => |r| r,
                .percent_encoded => |pe| pe,
            },
            .raw_query = if (uri.query) |q| switch (q) {
                .raw => |r| r,
                .percent_encoded => |pe| pe,
            } else "",
        };
    }

    /// Render the URL to a writer.
    pub fn format(self: Url, writer: anytype) !void {
        try writer.print("{s}://{s}", .{ self.scheme, self.host });
        if (self.port) |p| try writer.print(":{d}", .{p});
        try writer.writeAll(self.path);
        if (self.raw_query.len > 0) {
            try writer.print("?{s}", .{self.raw_query});
        }
    }

    /// Render the URL to an allocated string.
    pub fn toString(self: Url, allocator: std.mem.Allocator) ![]u8 {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(allocator);
        try self.format(buf.writer(allocator));
        return try buf.toOwnedSlice(allocator);
    }
};

/// Percent-encode a string for use in URL query parameter values.
///
/// Encodes all characters except unreserved chars (A-Z, a-z, 0-9, '-', '.', '_', '~')
/// per RFC 3986 §2.3.
pub fn percentEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeWithMode(allocator, input, .segment);
}

/// Percent-encode one path segment.
pub fn encodePathSegment(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeWithMode(allocator, input, .segment);
}

/// Percent-encode an ACR repository name while preserving `/` separators.
pub fn encodeRepositoryName(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeWithMode(allocator, input, .repository);
}

/// Expand a greedy path value, preserving URI reserved characters and valid
/// existing percent escapes.
pub fn expandGreedyPathValue(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeWithMode(allocator, input, .greedy);
}

/// Resolve an absolute or relative URL reference against an endpoint.
pub fn resolveUrl(
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    reference: []const u8,
) ![]u8 {
    const base = std.Uri.parse(endpoint) catch return error.InvalidUrl;
    if (base.host == null) return error.InvalidUrl;

    var storage = try allocator.alloc(u8, reference.len + endpoint.len + 2);
    defer allocator.free(storage);
    @memcpy(storage[0..reference.len], reference);
    var available = storage;
    const resolved = std.Uri.resolveInPlace(base, reference.len, &available) catch
        return error.InvalidUrl;

    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try std.Uri.format(&resolved, &output.writer);
    return output.toOwnedSlice();
}

/// Validate that a URL is HTTPS and uses one of the expected hosts.
///
/// Host matching is exact and case-insensitive. An empty expected-host list
/// accepts any HTTPS host.
pub fn validateHttpsUrl(raw: []const u8, expected_hosts: []const []const u8) !void {
    const uri = std.Uri.parse(raw) catch return error.InvalidUrl;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "https")) return error.HttpsRequired;
    if (uri.host == null or uri.user != null or uri.password != null or uri.fragment != null)
        return error.InvalidUrl;

    var host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = uri.getHost(&host_buffer) catch return error.InvalidUrl;
    if (expected_hosts.len == 0) return;
    for (expected_hosts) |expected| {
        if (std.ascii.eqlIgnoreCase(host.bytes, expected)) return;
    }
    return error.UnexpectedHost;
}

/// Resolve a URL reference and validate the resulting HTTPS host.
pub fn resolveAndValidateUrl(
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    reference: []const u8,
    expected_hosts: []const []const u8,
) ![]u8 {
    const resolved = try resolveUrl(allocator, endpoint, reference);
    errdefer allocator.free(resolved);
    try validateHttpsUrl(resolved, expected_hosts);
    return resolved;
}

/// Compare URL origins using case-insensitive schemes and hosts plus effective
/// ports. Both URLs must be absolute and must not contain user information.
pub fn sameOrigin(left_raw: []const u8, right_raw: []const u8) !bool {
    const left = std.Uri.parse(left_raw) catch return error.InvalidUrl;
    const right = std.Uri.parse(right_raw) catch return error.InvalidUrl;
    if (left.host == null or right.host == null or
        left.user != null or left.password != null or
        right.user != null or right.password != null)
    {
        return error.InvalidUrl;
    }

    var left_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    var right_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const left_host = left.getHost(&left_buffer) catch return error.InvalidUrl;
    const right_host = right.getHost(&right_buffer) catch return error.InvalidUrl;
    return std.ascii.eqlIgnoreCase(left.scheme, right.scheme) and
        std.ascii.eqlIgnoreCase(left_host.bytes, right_host.bytes) and
        effectivePort(left) == effectivePort(right);
}

fn effectivePort(uri: std.Uri) ?u16 {
    if (uri.port) |port| return port;
    if (std.ascii.eqlIgnoreCase(uri.scheme, "https")) return 443;
    if (std.ascii.eqlIgnoreCase(uri.scheme, "http")) return 80;
    return null;
}

const EncodeMode = enum {
    segment,
    repository,
    greedy,
};

fn encodeWithMode(
    allocator: std.mem.Allocator,
    input: []const u8,
    mode: EncodeMode,
) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    const hex = "0123456789ABCDEF";
    var index: usize = 0;
    while (index < input.len) : (index += 1) {
        const c = input[index];
        if (isUnreserved(c) or
            (mode == .repository and c == '/') or
            (mode == .greedy and isReserved(c)))
        {
            try buf.append(allocator, c);
        } else if (mode == .greedy and c == '%' and index + 2 < input.len and
            hexVal(input[index + 1]) != null and hexVal(input[index + 2]) != null)
        {
            try buf.appendSlice(allocator, input[index .. index + 3]);
            index += 2;
        } else {
            try buf.append(allocator, '%');
            try buf.append(allocator, hex[c >> 4]);
            try buf.append(allocator, hex[c & 0x0f]);
        }
    }
    return buf.toOwnedSlice(allocator);
}

/// Percent-decode a string (reverse of percentEncode).
pub fn percentDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hi = hexVal(input[i + 1]) orelse {
                try buf.append(allocator, input[i]);
                i += 1;
                continue;
            };
            const lo = hexVal(input[i + 2]) orelse {
                try buf.append(allocator, input[i]);
                i += 1;
                continue;
            };
            try buf.append(allocator, (@as(u8, hi) << 4) | @as(u8, lo));
            i += 3;
        } else if (input[i] == '+') {
            try buf.append(allocator, ' ');
            i += 1;
        } else {
            try buf.append(allocator, input[i]);
            i += 1;
        }
    }
    return buf.toOwnedSlice(allocator);
}

fn isUnreserved(c: u8) bool {
    return (c >= 'A' and c <= 'Z') or
        (c >= 'a' and c <= 'z') or
        (c >= '0' and c <= '9') or
        c == '-' or c == '.' or c == '_' or c == '~';
}

fn isReserved(c: u8) bool {
    return switch (c) {
        ':', '/', '?', '#', '[', ']', '@', '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '=' => true,
        else => false,
    };
}

fn hexVal(c: u8) ?u4 {
    if (c >= '0' and c <= '9') return @intCast(c - '0');
    if (c >= 'A' and c <= 'F') return @intCast(c - 'A' + 10);
    if (c >= 'a' and c <= 'f') return @intCast(c - 'a' + 10);
    return null;
}

test "parse https url" {
    const u = try Url.parse("https://myaccount.blob.core.windows.net/container/blob?sv=2021-06-08&sr=b");
    try std.testing.expectEqualStrings("https", u.scheme);
    try std.testing.expectEqualStrings("myaccount.blob.core.windows.net", u.host);
    try std.testing.expectEqualStrings("/container/blob", u.path);
}

test "percentEncode basic" {
    const allocator = std.testing.allocator;
    const encoded = try percentEncode(allocator, "hello world");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("hello%20world", encoded);
}

test "percentEncode special chars" {
    const allocator = std.testing.allocator;
    const encoded = try percentEncode(allocator, "key=val&foo/bar");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("key%3Dval%26foo%2Fbar", encoded);
}

test "percentEncode unreserved passthrough" {
    const allocator = std.testing.allocator;
    const encoded = try percentEncode(allocator, "abc-123_XYZ.~");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings("abc-123_XYZ.~", encoded);
}

test "path segment repository and greedy encoding" {
    const allocator = std.testing.allocator;

    const digest = try encodePathSegment(allocator, "sha256:abc/def");
    defer allocator.free(digest);
    try std.testing.expectEqualStrings("sha256%3Aabc%2Fdef", digest);

    const repository = try encodeRepositoryName(allocator, "team/my image");
    defer allocator.free(repository);
    try std.testing.expectEqualStrings("team/my%20image", repository);

    const upload = try expandGreedyPathValue(
        allocator,
        "/v2/team/app/blobs/uploads/id?_state=a%2Fb&digest=sha256:abc",
    );
    defer allocator.free(upload);
    try std.testing.expectEqualStrings(
        "/v2/team/app/blobs/uploads/id?_state=a%2Fb&digest=sha256:abc",
        upload,
    );
}

test "resolve relative and absolute URLs" {
    const allocator = std.testing.allocator;

    const relative = try resolveUrl(
        allocator,
        "https://registry.example/v2/team/app/",
        "../tags/list?n=10",
    );
    defer allocator.free(relative);
    try std.testing.expectEqualStrings(
        "https://registry.example/v2/team/tags/list?n=10",
        relative,
    );

    const root_relative = try resolveUrl(
        allocator,
        "https://registry.example/v2/",
        "/oauth2/token?service=registry.example",
    );
    defer allocator.free(root_relative);
    try std.testing.expectEqualStrings(
        "https://registry.example/oauth2/token?service=registry.example",
        root_relative,
    );

    const absolute = try resolveUrl(
        allocator,
        "https://registry.example/v2/",
        "https://auth.example/oauth2/token",
    );
    defer allocator.free(absolute);
    try std.testing.expectEqualStrings("https://auth.example/oauth2/token", absolute);
}

test "validate HTTPS URL expected hosts" {
    const allocator = std.testing.allocator;
    const expected = [_][]const u8{ "registry.example", "auth.example" };

    const relative = try resolveAndValidateUrl(
        allocator,
        "https://registry.example/v2/",
        "/v2/team/app/tags/list",
        &expected,
    );
    defer allocator.free(relative);
    try std.testing.expectEqualStrings(
        "https://registry.example/v2/team/app/tags/list",
        relative,
    );

    try validateHttpsUrl("https://AUTH.EXAMPLE/oauth2/token", &expected);
    try std.testing.expectError(
        error.HttpsRequired,
        validateHttpsUrl("http://registry.example/v2/", &expected),
    );
    try std.testing.expectError(
        error.UnexpectedHost,
        validateHttpsUrl("https://registry.example.evil.test/v2/", &expected),
    );
    try std.testing.expectError(
        error.UnexpectedHost,
        resolveAndValidateUrl(
            allocator,
            "https://registry.example/v2/",
            "//evil.test/v2/",
            &expected,
        ),
    );
    try std.testing.expectError(
        error.HttpsRequired,
        resolveAndValidateUrl(
            allocator,
            "https://registry.example/v2/",
            "http://registry.example/v2/",
            &expected,
        ),
    );
    try std.testing.expectError(
        error.InvalidUrl,
        validateHttpsUrl("https://user@registry.example/v2/", &expected),
    );
}

test "sameOrigin compares effective ports and host case" {
    try std.testing.expect(try sameOrigin(
        "https://REGISTRY.example/v2/",
        "https://registry.example:443/blobs/data",
    ));
    try std.testing.expect(!(try sameOrigin(
        "https://registry.example/v2/",
        "https://storage.example/blobs/data",
    )));
    try std.testing.expect(!(try sameOrigin(
        "https://registry.example/v2/",
        "https://registry.example:444/blobs/data",
    )));
}

test "percentDecode round-trip" {
    const allocator = std.testing.allocator;
    const original = "hello world & stuff=123";
    const encoded = try percentEncode(allocator, original);
    defer allocator.free(encoded);
    const decoded = try percentDecode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(original, decoded);
}

test "percentDecode plus to space" {
    const allocator = std.testing.allocator;
    const decoded = try percentDecode(allocator, "hello+world");
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("hello world", decoded);
}
