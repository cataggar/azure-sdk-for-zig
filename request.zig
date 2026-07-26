const std = @import("std");
const core = @import("azure_sdk_core");

pub const NormalizedEndpoint = struct {
    base_url: []u8,
    raw_query: []u8,
    has_query: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8) !NormalizedEndpoint {
        const parsed = try parseEndpoint(endpoint);

        const owned_base = try allocator.dupe(u8, parsed.base_input[0..parsed.end]);
        errdefer allocator.free(owned_base);
        return .{
            .base_url = owned_base,
            .raw_query = try allocator.dupe(u8, parsed.raw_query),
            .has_query = parsed.has_query,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *NormalizedEndpoint) void {
        self.allocator.free(self.base_url);
        self.allocator.free(self.raw_query);
        self.* = undefined;
    }
};

const ParsedEndpoint = struct {
    base_input: []const u8,
    raw_query: []const u8,
    has_query: bool,
    end: usize,
    scheme: []const u8,
};

fn parseEndpoint(endpoint: []const u8) !ParsedEndpoint {
    if (endpoint.len == 0) return error.InvalidEndpoint;
    for (endpoint) |byte| {
        if (byte <= 0x20 or byte == 0x7f) return error.InvalidEndpoint;
    }
    if (std.mem.indexOfScalar(u8, endpoint, '#') != null) return error.InvalidEndpoint;

    const query_index = std.mem.indexOfScalar(u8, endpoint, '?');
    const base_input = if (query_index) |index| endpoint[0..index] else endpoint;
    const raw_query = if (query_index) |index| endpoint[index + 1 ..] else "";

    const uri = std.Uri.parse(base_input) catch return error.InvalidEndpoint;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "https") and
        !std.ascii.eqlIgnoreCase(uri.scheme, "http"))
    {
        return error.InvalidEndpointScheme;
    }
    if (uri.host == null or uri.user != null or uri.password != null or uri.fragment != null)
        return error.InvalidEndpoint;
    var host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = uri.getHost(&host_buffer) catch return error.InvalidEndpoint;
    if (host.bytes.len == 0) return error.InvalidEndpoint;

    var end = base_input.len;
    const authority_start = (std.mem.indexOf(u8, base_input, "://") orelse
        return error.InvalidEndpoint) + 3;
    const authority_end = std.mem.indexOfScalarPos(u8, base_input, authority_start, '/') orelse
        base_input.len;
    while (end > authority_end and base_input[end - 1] == '/') end -= 1;

    return .{
        .base_input = base_input,
        .raw_query = raw_query,
        .has_query = query_index != null,
        .end = end,
        .scheme = uri.scheme,
    };
}

/// Token-authenticated clients must never use a cleartext endpoint.
pub fn validateTokenEndpoint(endpoint: []const u8) !void {
    const parsed = try parseEndpoint(endpoint);
    if (!std.ascii.eqlIgnoreCase(parsed.scheme, "https"))
        return error.TokenAuthenticationRequiresHttps;
}

/// Cleartext is restricted to local emulator endpoints. Production Shared Key
/// and SAS URLs must remain HTTPS even though they do not use bearer tokens.
pub fn validateSharedKeyEndpoint(endpoint: []const u8) !void {
    const parsed = try parseEndpoint(endpoint);
    if (std.ascii.eqlIgnoreCase(parsed.scheme, "https")) return;
    try validateLocalEmulator(endpoint);
}

pub fn validateSasEndpoint(endpoint: []const u8) !void {
    const parsed = try parseEndpoint(endpoint);
    if (!parsed.has_query or parsed.raw_query.len == 0) return error.MissingSasQuery;
    if (std.ascii.eqlIgnoreCase(parsed.scheme, "https")) return;
    try validateLocalEmulator(endpoint);
}

fn validateLocalEmulator(endpoint: []const u8) !void {
    const uri = std.Uri.parse(endpoint) catch return error.InvalidEndpoint;
    var host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = uri.getHost(&host_buffer) catch return error.InvalidEndpoint;
    if (!std.mem.eql(u8, host.bytes, "127.0.0.1") and
        !std.ascii.eqlIgnoreCase(host.bytes, "localhost"))
    {
        return error.CleartextEndpointRequiresLocalEmulator;
    }
}

pub fn validateTableName(name: []const u8) !void {
    if (name.len < 3 or name.len > 63 or !std.ascii.isAlphabetic(name[0]))
        return error.InvalidTableName;
    for (name[1..]) |byte| {
        if (!std.ascii.isAlphanumeric(byte)) return error.InvalidTableName;
    }
}

pub fn validateEntityKey(key: []const u8) !void {
    if (key.len == 0 or key.len > 1024 or !std.unicode.utf8ValidateSlice(key))
        return error.InvalidEntityKey;
    var index: usize = 0;
    while (index < key.len) {
        const sequence_len = std.unicode.utf8ByteSequenceLength(key[index]) catch
            return error.InvalidEntityKey;
        const codepoint = std.unicode.utf8Decode(key[index .. index + sequence_len]) catch
            return error.InvalidEntityKey;
        if (codepoint < 0x20 or (codepoint >= 0x7f and codepoint <= 0x9f) or
            codepoint == '/' or codepoint == '\\' or codepoint == '#' or codepoint == '?')
        {
            return error.InvalidEntityKey;
        }
        index += sequence_len;
    }
}

pub fn validateApiVersion(version: []const u8) !void {
    if (version.len == 0) return error.InvalidApiVersion;
    for (version) |byte| {
        if (byte < 0x20 or byte == 0x7f) return error.InvalidApiVersion;
    }
}

pub fn validateProtocolOptions(options: anytype) !void {
    if (options.timeout) |timeout| {
        if (timeout <= 0) return error.InvalidTimeout;
    }
    if (options.client_request_id) |request_id| {
        if (request_id.len == 0) return error.InvalidClientRequestId;
        for (request_id) |byte| {
            if ((byte < 0x20 and byte != '\t') or byte == 0x7f)
                return error.InvalidClientRequestId;
        }
    }
}

pub fn validateIfMatch(value: []const u8) !void {
    if (value.len == 0) return error.InvalidIfMatch;
    for (value) |byte| {
        if (byte < 0x20 or byte == 0x7f) return error.InvalidIfMatch;
    }
}

/// Doubles apostrophes for an OData literal, then encodes the raw bytes once.
pub fn encodeODataStringLiteral(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    try validateEntityKey(value);
    var escaped: std.ArrayList(u8) = .empty;
    defer escaped.deinit(allocator);
    for (value) |byte| {
        try escaped.append(allocator, byte);
        if (byte == '\'') try escaped.append(allocator, '\'');
    }
    return core.url.encodePathSegment(allocator, escaped.items);
}

pub fn buildEntityUrl(
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    table: []const u8,
    partition_key: []const u8,
    row_key: []const u8,
) ![]u8 {
    try validateTableName(table);
    const encoded_partition = try encodeODataStringLiteral(allocator, partition_key);
    defer allocator.free(encoded_partition);
    const encoded_row = try encodeODataStringLiteral(allocator, row_key);
    defer allocator.free(encoded_row);
    var normalized = try NormalizedEndpoint.init(allocator, endpoint);
    defer normalized.deinit();

    return std.fmt.allocPrint(
        allocator,
        "{s}/{s}(PartitionKey='{s}',RowKey='{s}'){s}{s}",
        .{
            normalized.base_url,
            table,
            encoded_partition,
            encoded_row,
            if (normalized.has_query) "?" else "",
            normalized.raw_query,
        },
    );
}

/// Writes a JSON-escaped string without surrounding quotes.
pub fn writeJsonEscaped(writer: anytype, value: []const u8) !void {
    for (value) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    const hex = "0123456789abcdef";
                    try writer.writeAll("\\u00");
                    try writer.writeByte(hex[c >> 4]);
                    try writer.writeByte(hex[c & 0x0f]);
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
}

test "entity URL goldens encode OData literals exactly once" {
    const allocator = std.testing.allocator;
    const cases = [_]struct { key: []const u8, encoded: []const u8 }{
        .{ .key = "O'Brien", .encoded = "O%27%27Brien" },
        .{ .key = "two words", .encoded = "two%20words" },
        .{ .key = "雪", .encoded = "%E9%9B%AA" },
        .{ .key = "a&b=c", .encoded = "a%26b%3Dc" },
        .{ .key = "already%20encoded", .encoded = "already%2520encoded" },
    };
    for (cases) |case| {
        const url = try buildEntityUrl(
            allocator,
            "https://account.table.core.windows.net/",
            "Table123",
            case.key,
            "row",
        );
        defer allocator.free(url);
        const expected = try std.fmt.allocPrint(
            allocator,
            "https://account.table.core.windows.net/Table123(PartitionKey='{s}',RowKey='row')",
            .{case.encoded},
        );
        defer allocator.free(expected);
        try std.testing.expectEqualStrings(expected, url);
    }
}

test "SAS endpoint query bytes and order are unchanged" {
    const allocator = std.testing.allocator;
    const url = try buildEntityUrl(
        allocator,
        "https://account.table.core.windows.net///?sv=1%2F2&sig=a+b%3D&sp=r",
        "Table123",
        "part",
        "row",
    );
    defer allocator.free(url);
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Table123(PartitionKey='part',RowKey='row')?sv=1%2F2&sig=a+b%3D&sp=r",
        url,
    );
}

test "endpoint table key and property validation rejects invalid inputs" {
    const entity = @import("entity.zig");
    try std.testing.expectError(
        error.InvalidEndpointScheme,
        NormalizedEndpoint.init(std.testing.allocator, "ftp://example.com"),
    );
    try std.testing.expectError(
        error.InvalidEndpoint,
        NormalizedEndpoint.init(std.testing.allocator, "https:///missing-host"),
    );
    try std.testing.expectError(error.InvalidTableName, validateTableName("1table"));
    try std.testing.expectError(error.InvalidEntityKey, validateEntityKey("bad/key"));
    try std.testing.expectError(error.ReservedPropertyName, entity.validatePropertyName("PartitionKey"));
    try std.testing.expectError(error.InvalidPropertyName, entity.validatePropertyName("bad/name"));
}

test "normalized endpoints retain HTTP support for non-token authentication" {
    var normalized = try NormalizedEndpoint.init(
        std.testing.allocator,
        "http://127.0.0.1:10002/devstoreaccount1/",
    );
    defer normalized.deinit();
    try std.testing.expectEqualStrings(
        "http://127.0.0.1:10002/devstoreaccount1",
        normalized.base_url,
    );
}
