const std = @import("std");
const core = @import("azure_sdk_core");
const base64 = core.base64;
const crypto = core.crypto;

pub const sas = @import("sas.zig");

test {
    std.testing.refAllDecls(sas);
}

fn wipe(bytes: []u8) void {
    const volatile_bytes: []volatile u8 = bytes;
    @memset(volatile_bytes, 0);
}

fn wipeAndFree(allocator: std.mem.Allocator, bytes: []u8) void {
    if (bytes.len == 0) return;
    wipe(bytes);
    allocator.rawFree(
        bytes,
        .fromByteUnits(@alignOf(u8)),
        @returnAddress(),
    );
}

fn decodeAccountKey(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    if (encoded.len == 0) return error.InvalidAccountKey;

    const decoder = std.base64.standard.Decoder;
    const decoded_size = try decoder.calcSizeForSlice(encoded);
    if (decoded_size == 0) return error.InvalidAccountKey;

    const decoded = try allocator.alloc(u8, decoded_size);
    errdefer wipeAndFree(allocator, decoded);
    try decoder.decode(decoded, encoded);
    return decoded;
}

fn versionAtLeast(version: ?[]const u8, minimum: []const u8) bool {
    const value = version orelse return true;
    return std.mem.order(u8, value, minimum) != .lt;
}

fn contentLengthToSign(request: *const core.http.Request) []const u8 {
    const value = request.getHeader("Content-Length") orelse return "";
    if (std.mem.eql(u8, value, "0")) {
        const version = request.getHeader("x-ms-version") orelse return "";
        if (std.mem.order(u8, version, "2014-02-14") == .gt) return "";
    }
    return value;
}

const CanonicalHeader = struct {
    name: []const u8,
    value: []const u8,
};

fn primaryHeaderWeight(byte: u8) u16 {
    const lower = std.ascii.toLower(byte);
    return switch (lower) {
        '!' => 0x071c,
        '#' => 0x071f,
        '$' => 0x0721,
        '%' => 0x0723,
        '&' => 0x0725,
        '\'' => 0,
        '*' => 0x072d,
        '+' => 0x0803,
        '-' => 0,
        '.' => 0x0733,
        '0'...'9' => ([_]u16{
            0x0d03, 0x0d1a, 0x0d1c, 0x0d1e, 0x0d20,
            0x0d22, 0x0d24, 0x0d26, 0x0d28, 0x0d2a,
        })[lower - '0'],
        '^' => 0x0743,
        '_' => 0x0744,
        '`' => 0x0748,
        'a'...'z' => ([_]u16{
            0x0e02, 0x0e09, 0x0e0a, 0x0e1a, 0x0e21, 0x0e23, 0x0e25,
            0x0e2c, 0x0e32, 0x0e35, 0x0e36, 0x0e48, 0x0e51, 0x0e70,
            0x0e7c, 0x0e7e, 0x0e89, 0x0e8a, 0x0e91, 0x0e99, 0x0e9f,
            0x0ea2, 0x0ea4, 0x0ea6, 0x0ea7, 0x0ea9,
        })[lower - 'a'],
        '|' => 0x074c,
        '~' => 0x0750,
        else => unreachable,
    };
}

fn headerWeight(level: usize, byte: u8) u16 {
    return switch (level) {
        0 => primaryHeaderWeight(byte),
        1 => 0,
        2 => switch (byte) {
            '\'' => 0x8012,
            '-' => 0x8212,
            else => 0,
        },
        else => unreachable,
    };
}

fn compareCanonicalHeaderNames(lhs: []const u8, rhs: []const u8) i32 {
    var level: usize = 0;
    var lhs_index: usize = 0;
    var rhs_index: usize = 0;

    while (level < 3) {
        if (level == 2 and lhs_index != rhs_index) {
            return @as(i32, @intCast(rhs_index)) - @as(i32, @intCast(lhs_index));
        }

        const lhs_weight = if (lhs_index < lhs.len)
            headerWeight(level, std.ascii.toLower(lhs[lhs_index]))
        else
            1;
        const rhs_weight = if (rhs_index < rhs.len)
            headerWeight(level, std.ascii.toLower(rhs[rhs_index]))
        else
            1;

        if (lhs_weight == 1 and rhs_weight == 1) {
            lhs_index = 0;
            rhs_index = 0;
            level += 1;
        } else if (lhs_weight == rhs_weight) {
            lhs_index += 1;
            rhs_index += 1;
        } else if (lhs_weight == 0) {
            lhs_index += 1;
        } else if (rhs_weight == 0) {
            rhs_index += 1;
        } else {
            return @as(i32, lhs_weight) - @as(i32, rhs_weight);
        }
    }
    return 0;
}

fn canonicalHeaderLessThan(_: void, lhs: CanonicalHeader, rhs: CanonicalHeader) bool {
    return compareCanonicalHeaderNames(lhs.name, rhs.name) < 0;
}

fn appendCanonicalHeaderValue(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    value: []const u8,
) !void {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    var in_quotes = false;
    var escaped = false;
    var pending_space = false;
    var emitted = false;

    for (trimmed) |byte| {
        if (!in_quotes and (byte == ' ' or byte == '\t' or byte == '\r' or byte == '\n')) {
            pending_space = emitted;
            continue;
        }
        if (pending_space) {
            try output.append(allocator, ' ');
            pending_space = false;
        }
        try output.append(allocator, byte);
        emitted = true;

        if (in_quotes and byte == '\\' and !escaped) {
            escaped = true;
            continue;
        }
        if (byte == '"' and !escaped) in_quotes = !in_quotes;
        escaped = false;
    }
}

fn appendCanonicalizedHeaders(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    request: *const core.http.Request,
) !void {
    var headers: std.ArrayList(CanonicalHeader) = .empty;
    defer headers.deinit(allocator);

    var iterator = request.headers.iterator();
    while (iterator.next()) |entry| {
        if (!std.ascii.startsWithIgnoreCase(entry.key_ptr.*, "x-ms-")) continue;
        if (entry.value_ptr.*.len == 0 and
            !versionAtLeast(request.getHeader("x-ms-version"), "2016-05-31"))
        {
            continue;
        }
        try headers.append(allocator, .{
            .name = entry.key_ptr.*,
            .value = entry.value_ptr.*,
        });
    }

    std.mem.sort(CanonicalHeader, headers.items, {}, canonicalHeaderLessThan);
    for (headers.items) |header| {
        for (header.name) |byte| {
            try output.append(allocator, std.ascii.toLower(byte));
        }
        try output.append(allocator, ':');
        try appendCanonicalHeaderValue(output, allocator, header.value);
        try output.append(allocator, '\n');
    }
}

const UrlParts = struct {
    path: []const u8,
    query: []const u8,
};

fn splitUrl(url: []const u8) UrlParts {
    const without_fragment = if (std.mem.findScalar(u8, url, '#')) |index|
        url[0..index]
    else
        url;
    const query_start = std.mem.findScalar(u8, without_fragment, '?');
    const before_query = if (query_start) |index| without_fragment[0..index] else without_fragment;
    const query = if (query_start) |index| without_fragment[index + 1 ..] else "";

    if (std.mem.find(u8, before_query, "://")) |scheme_end| {
        const authority = before_query[scheme_end + 3 ..];
        if (std.mem.findScalar(u8, authority, '/')) |slash| {
            return .{ .path = authority[slash..], .query = query };
        }
        return .{ .path = "/", .query = query };
    }

    if (before_query.len == 0) return .{ .path = "/", .query = query };
    return .{ .path = before_query, .query = query };
}

fn hexValue(byte: u8) ?u8 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        'A'...'F' => byte - 'A' + 10,
        else => null,
    };
}

fn decodeQueryComponent(
    allocator: std.mem.Allocator,
    encoded: []const u8,
) ![]u8 {
    const decoded = try allocator.alloc(u8, encoded.len);
    errdefer allocator.free(decoded);

    var source_index: usize = 0;
    var destination_index: usize = 0;
    while (source_index < encoded.len) {
        if (encoded[source_index] == '%') {
            if (source_index + 2 >= encoded.len) return error.InvalidPercentEncoding;
            const high = hexValue(encoded[source_index + 1]) orelse
                return error.InvalidPercentEncoding;
            const low = hexValue(encoded[source_index + 2]) orelse
                return error.InvalidPercentEncoding;
            decoded[destination_index] = (high << 4) | low;
            source_index += 3;
        } else {
            decoded[destination_index] = if (encoded[source_index] == '+')
                ' '
            else
                encoded[source_index];
            source_index += 1;
        }
        destination_index += 1;
    }
    return allocator.realloc(decoded, destination_index);
}

const QueryPair = struct {
    name: []u8,
    value: []u8,
};

fn queryPairLessThan(_: void, lhs: QueryPair, rhs: QueryPair) bool {
    const name_order = std.mem.order(u8, lhs.name, rhs.name);
    if (name_order != .eq) return name_order == .lt;
    return std.mem.order(u8, lhs.value, rhs.value) == .lt;
}

fn appendCanonicalizedResource(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    account_name: []const u8,
    url: []const u8,
) !void {
    const parts = splitUrl(url);
    try output.append(allocator, '/');
    try output.appendSlice(allocator, account_name);
    if (parts.path.len == 0 or parts.path[0] != '/') {
        try output.append(allocator, '/');
    }
    try output.appendSlice(allocator, parts.path);

    var pairs: std.ArrayList(QueryPair) = .empty;
    defer {
        for (pairs.items) |pair| {
            allocator.free(pair.name);
            allocator.free(pair.value);
        }
        pairs.deinit(allocator);
    }

    var query_iterator = std.mem.splitScalar(u8, parts.query, '&');
    while (query_iterator.next()) |parameter| {
        if (parameter.len == 0) continue;
        {
            const equals = std.mem.findScalar(u8, parameter, '=');
            const encoded_name = if (equals) |index| parameter[0..index] else parameter;
            const encoded_value = if (equals) |index| parameter[index + 1 ..] else "";

            const name = try decodeQueryComponent(allocator, encoded_name);
            errdefer allocator.free(name);
            for (name) |*byte| byte.* = std.ascii.toLower(byte.*);
            const value = try decodeQueryComponent(allocator, encoded_value);
            errdefer allocator.free(value);
            try pairs.append(allocator, .{ .name = name, .value = value });
        }
    }

    std.mem.sort(QueryPair, pairs.items, {}, queryPairLessThan);
    var index: usize = 0;
    while (index < pairs.items.len) {
        const name = pairs.items[index].name;
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, name);
        try output.append(allocator, ':');

        var value_index = index;
        while (value_index < pairs.items.len and
            std.mem.eql(u8, pairs.items[value_index].name, name))
        {
            if (value_index != index) try output.append(allocator, ',');
            try output.appendSlice(allocator, pairs.items[value_index].value);
            value_index += 1;
        }
        index = value_index;
    }
}

fn buildSharedKeyStringToSign(
    allocator: std.mem.Allocator,
    account_name: []const u8,
    request: *const core.http.Request,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    const date = if (request.getHeader("x-ms-date") != null)
        ""
    else
        request.getHeader("Date") orelse "";
    const standard_headers = [_][]const u8{
        request.getHeader("Content-Encoding") orelse "",
        request.getHeader("Content-Language") orelse "",
        contentLengthToSign(request),
        request.getHeader("Content-MD5") orelse "",
        request.getHeader("Content-Type") orelse "",
        date,
        request.getHeader("If-Modified-Since") orelse "",
        request.getHeader("If-Match") orelse "",
        request.getHeader("If-None-Match") orelse "",
        request.getHeader("If-Unmodified-Since") orelse "",
        request.getHeader("Range") orelse "",
    };

    try output.appendSlice(allocator, @tagName(request.method));
    try output.append(allocator, '\n');
    for (standard_headers) |value| {
        try output.appendSlice(allocator, value);
        try output.append(allocator, '\n');
    }
    try appendCanonicalizedHeaders(&output, allocator, request);
    try appendCanonicalizedResource(&output, allocator, account_name, request.url);
    return output.toOwnedSlice(allocator);
}

/// Shared Key credential for Azure Storage.
///
/// This is a single-owner value because it owns decoded key material. Do not
/// copy it after initialization; call `deinit` exactly once.
pub const StorageSharedKeyCredential = struct {
    allocator: std.mem.Allocator,
    account_name: []const u8,
    decoded_account_key: []u8,

    pub fn init(
        allocator: std.mem.Allocator,
        account_name: []const u8,
        encoded_account_key: []const u8,
    ) !StorageSharedKeyCredential {
        const decoded_account_key = try decodeAccountKey(allocator, encoded_account_key);
        errdefer wipeAndFree(allocator, decoded_account_key);

        const owned_account_name = try allocator.dupe(u8, account_name);
        return .{
            .allocator = allocator,
            .account_name = owned_account_name,
            .decoded_account_key = decoded_account_key,
        };
    }

    pub fn deinit(self: *StorageSharedKeyCredential) void {
        self.allocator.free(self.account_name);
        wipeAndFree(self.allocator, self.decoded_account_key);
        self.* = undefined;
    }

    /// Replace the account key without exposing decoded key material.
    ///
    /// A decode or allocation failure leaves the existing key unchanged.
    pub fn replaceAccountKey(
        self: *StorageSharedKeyCredential,
        encoded_account_key: []const u8,
    ) !void {
        const replacement = try decodeAccountKey(self.allocator, encoded_account_key);
        wipeAndFree(self.allocator, self.decoded_account_key);
        self.decoded_account_key = replacement;
    }

    /// Sign a request in-place using the caller's configured crypto provider.
    ///
    /// Pipeline integrations should pass `runtime.crypto`. The provider is
    /// invoked before any authorization value is constructed or installed.
    pub fn signRequest(
        self: *const StorageSharedKeyCredential,
        request: *core.http.Request,
        crypto_provider: crypto.CryptoProvider,
    ) !void {
        const allocator = request.allocator;
        const string_to_sign = try buildSharedKeyStringToSign(
            allocator,
            self.account_name,
            request,
        );
        defer allocator.free(string_to_sign);

        const signature = try base64.hmacSha256Base64(
            allocator,
            crypto_provider,
            self.decoded_account_key,
            string_to_sign,
        );
        defer allocator.free(signature);

        const authorization = try std.fmt.allocPrint(
            allocator,
            "SharedKey {s}:{s}",
            .{ self.account_name, signature },
        );
        defer allocator.free(authorization);
        try request.setHeader("Authorization", authorization);
    }
};

fn appendPercentEncodedQueryValue(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    value: []const u8,
) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or
            byte == '-' or byte == '.' or byte == '_' or byte == '~')
        {
            try output.append(allocator, byte);
        } else {
            try output.append(allocator, '%');
            try output.append(allocator, hex[byte >> 4]);
            try output.append(allocator, hex[byte & 0x0f]);
        }
    }
}

fn appendQueryParameter(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    name: []const u8,
    value: []const u8,
) !void {
    if (output.items.len != 0) try output.append(allocator, '&');
    try output.appendSlice(allocator, name);
    try output.append(allocator, '=');
    try appendPercentEncodedQueryValue(output, allocator, value);
}

/// Generate an account SAS token.
pub const SasBuilder = struct {
    account_name: []const u8,
    permissions: []const u8 = "r",
    resource_types: []const u8 = "sco",
    services: []const u8 = "b",
    start: ?[]const u8 = null,
    expiry: []const u8,
    ip: ?[]const u8 = null,
    protocol: ?[]const u8 = "https",
    version: []const u8 = "2024-11-04",
    encryption_scope: ?[]const u8 = null,

    fn validate(self: SasBuilder) !void {
        if (self.account_name.len == 0) return error.InvalidAccountName;
        if (self.permissions.len == 0) return error.SasPermissionsRequired;
        if (self.services.len == 0) return error.SasServicesRequired;
        if (self.resource_types.len == 0) return error.SasResourceTypesRequired;
        if (self.expiry.len == 0) return error.SasExpiryRequired;
        if (self.version.len == 0) return error.SasVersionRequired;
        if (!versionAtLeast(self.version, "2015-04-05"))
            return error.AccountSasVersionUnsupported;
        if (self.encryption_scope != null and
            !versionAtLeast(self.version, "2020-12-06"))
        {
            return error.EncryptionScopeUnsupported;
        }
    }

    /// Render the SAS query string (without leading '?'), unsigned.
    pub fn toQueryString(self: SasBuilder, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);
        try appendQueryParameter(&output, allocator, "sv", self.version);
        try appendQueryParameter(&output, allocator, "ss", self.services);
        try appendQueryParameter(&output, allocator, "srt", self.resource_types);
        try appendQueryParameter(&output, allocator, "sp", self.permissions);
        if (self.start) |start| {
            try appendQueryParameter(&output, allocator, "st", start);
        }
        try appendQueryParameter(&output, allocator, "se", self.expiry);
        if (self.ip) |ip| {
            try appendQueryParameter(&output, allocator, "sip", ip);
        }
        if (self.protocol) |protocol| {
            try appendQueryParameter(&output, allocator, "spr", protocol);
        }
        if (self.encryption_scope) |encryption_scope| {
            try appendQueryParameter(&output, allocator, "ses", encryption_scope);
        }
        return output.toOwnedSlice(allocator);
    }

    fn stringToSign(self: SasBuilder, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();

        if (versionAtLeast(self.version, "2020-12-06")) {
            return std.fmt.allocPrint(
                allocator,
                "{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n",
                .{
                    self.account_name,
                    self.permissions,
                    self.services,
                    self.resource_types,
                    self.start orelse "",
                    self.expiry,
                    self.ip orelse "",
                    self.protocol orelse "",
                    self.version,
                    self.encryption_scope orelse "",
                },
            );
        }
        return std.fmt.allocPrint(
            allocator,
            "{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n",
            .{
                self.account_name,
                self.permissions,
                self.services,
                self.resource_types,
                self.start orelse "",
                self.expiry,
                self.ip orelse "",
                self.protocol orelse "",
                self.version,
            },
        );
    }

    /// Build and sign an account SAS query with the selected crypto provider.
    pub fn sign(
        self: SasBuilder,
        allocator: std.mem.Allocator,
        crypto_provider: crypto.CryptoProvider,
        encoded_account_key: []const u8,
    ) ![]u8 {
        try self.validate();
        const decoded_account_key = try decodeAccountKey(allocator, encoded_account_key);
        defer wipeAndFree(allocator, decoded_account_key);

        const string_to_sign = try self.stringToSign(allocator);
        defer allocator.free(string_to_sign);

        const signature = try base64.hmacSha256Base64(
            allocator,
            crypto_provider,
            decoded_account_key,
            string_to_sign,
        );
        defer allocator.free(signature);

        const query = try self.toQueryString(allocator);
        defer allocator.free(query);

        var signed_query: std.ArrayList(u8) = .empty;
        errdefer signed_query.deinit(allocator);
        try signed_query.appendSlice(allocator, query);
        try appendQueryParameter(&signed_query, allocator, "sig", signature);
        return signed_query.toOwnedSlice(allocator);
    }
};

/// Storage-specific retry options (e.g. secondary endpoint failover).
pub const StorageRetryOptions = struct {
    max_retries: u32 = 4,
    initial_delay_ms: u64 = 800,
    max_delay_ms: u64 = 120_000,
    secondary_host: ?[]const u8 = null,
};

/// Compute Content-MD5 for a blob body (base64-encoded MD5).
///
/// MD5 is provided only for integrity and compatibility, not as a security
/// primitive.
pub fn contentMd5(
    allocator: std.mem.Allocator,
    crypto_provider: crypto.CryptoProvider,
    body: []const u8,
) ![]u8 {
    return base64.md5Base64(allocator, crypto_provider, body);
}

/// Compute x-ms-content-sha256 header value (base64-encoded SHA-256).
pub fn contentSha256(
    allocator: std.mem.Allocator,
    crypto_provider: crypto.CryptoProvider,
    body: []const u8,
) ![]u8 {
    return base64.sha256Base64(allocator, crypto_provider, body);
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
    fail: bool = false,
    data: [128]u8 = undefined,
    data_len: usize = 0,
    key: [128]u8 = undefined,
    key_len: usize = 0,
    message: [2048]u8 = undefined,
    message_len: usize = 0,

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
        @memcpy(self.data[0..data.len], data);
        self.data_len = data.len;
        @memset(out, 0xa5);
        try self.record(.md5);
    }

    fn sha256(context: *anyopaque, data: []const u8, out: *crypto.Sha256Digest) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        @memcpy(self.data[0..data.len], data);
        self.data_len = data.len;
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
        @memcpy(self.key[0..key.len], key);
        self.key_len = key.len;
        @memcpy(self.message[0..message.len], message);
        self.message_len = message.len;
        @memset(out, 0xa5);
        out[0..3].* = .{ 0xfb, 0xff, 0xfe };
        try self.record(.hmac_sha256);
    }

    fn sha256Init(
        _: *anyopaque,
        _: std.mem.Allocator,
    ) !crypto.Sha256Operation {
        return error.Unused;
    }
};

const TestWipeAllocator = struct {
    backing: std.mem.Allocator,
    free_count: usize = 0,
    freed_was_zero: [16]bool = [_]bool{false} ** 16,

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = &alloc,
        .resize = &resize,
        .remap = &remap,
        .free = &free,
    };

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn alloc(
        context: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.backing.rawAlloc(len, alignment, ret_addr);
    }

    fn resize(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.backing.rawResize(memory, alignment, new_len, ret_addr);
    }

    fn remap(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.backing.rawRemap(memory, alignment, new_len, ret_addr);
    }

    fn free(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        var all_zero = true;
        for (memory) |byte| {
            if (byte != 0) {
                all_zero = false;
                break;
            }
        }
        self.freed_was_zero[self.free_count] = all_zero;
        self.free_count += 1;
        self.backing.rawFree(memory, alignment, ret_addr);
    }
};

const azurite_account_key =
    "Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==";

test "Shared Key matches Azure SDK arbitrary x-ms header vector" {
    // Azure.Storage.Common's StorageSharedKeyPipelinePolicyTests.BuildSignature.
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "accountName",
        "YWNjb3VudEtleQ==",
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .GET,
        "http://dummyaccount.blob.core.windows.net",
    );
    defer request.deinit();
    try request.setHeader("x-ms-version", "2021-10-04");
    try request.setHeader("Accept-Ranges", "bytes");
    try request.setHeader("Accept", "application/xml");
    try request.setHeader("ETag", "\"0x8DAB6A893E4304F\"");
    try request.setHeader("Server", "Windows-Azure-Blob/1.0,Microsoft-HTTPAPI/2.0");
    try request.setHeader("x-ms-request-id", "a12bc899-001e-003a-3a91-e8439e000000");
    try request.setHeader("x-ms-client-request-id", "8f978611-738a-4cd4-a318-33b2f31068d9");
    try request.setHeader("x-ms-creation-time", "Tue, 25 Oct 2022 16:47:17 GMT");
    try request.setHeader("x-ms-Return-Client-request-id", "true");
    try request.setHeader("x-ms-blob-content-md5", "2OD7XGeI0jSOrsBn8ZwHTw==");
    try request.setHeader("x-ms-lease-status", "unlocked");
    try request.setHeader("x-ms-meta-foo", "bar");
    try request.setHeader("x-ms-meta-meta", "data");
    try request.setHeader("x-ms-meta-Capital", "letter");
    try request.setHeader("x-ms-meta-UPPER", "case");
    try request.setHeader("x-ms-enable-snapshot-virtual-directory-access", "true");
    try request.setHeader("x-ms-enabled-protocols", "NFS");
    try request.setHeader("Date", "Thu, 24 Feb 2022 02:39:43 GMT");
    try request.setHeader("x-ms-date", "Wed, 23 Feb 2022 02:39:43 GMT");

    const expected_string =
        "GET\n" ++
        "\n" ** 11 ++
        "x-ms-blob-content-md5:2OD7XGeI0jSOrsBn8ZwHTw==\n" ++
        "x-ms-client-request-id:8f978611-738a-4cd4-a318-33b2f31068d9\n" ++
        "x-ms-creation-time:Tue, 25 Oct 2022 16:47:17 GMT\n" ++
        "x-ms-date:Wed, 23 Feb 2022 02:39:43 GMT\n" ++
        "x-ms-enabled-protocols:NFS\n" ++
        "x-ms-enable-snapshot-virtual-directory-access:true\n" ++
        "x-ms-lease-status:unlocked\n" ++
        "x-ms-meta-capital:letter\n" ++
        "x-ms-meta-foo:bar\n" ++
        "x-ms-meta-meta:data\n" ++
        "x-ms-meta-upper:case\n" ++
        "x-ms-request-id:a12bc899-001e-003a-3a91-e8439e000000\n" ++
        "x-ms-return-client-request-id:true\n" ++
        "x-ms-version:2021-10-04\n" ++
        "/accountName/";

    try credential.signRequest(&request, provider_impl.asProvider());
    try std.testing.expectEqualStrings(
        "SharedKey accountName:Wjhed5+kLPnT9/EhIgKd7e0y/AEau6G4KKxrUqZxA8s=",
        request.getHeader("Authorization").?,
    );
    var spy = TestCryptoProvider{};
    try credential.signRequest(&request, spy.provider());
    try std.testing.expectEqual(.hmac_sha256, spy.operation);
    try std.testing.expectEqualStrings(expected_string, spy.message[0..spy.message_len]);
    try std.testing.expectEqualStrings(
        "SharedKey accountName:+//+paWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaU=",
        request.getHeader("Authorization").?,
    );
}

test "Shared Key matches authoritative punctuation header ordering vector" {
    // Expected order and signature were generated independently from Azure
    // Storage's HeaderStringComparer weight tables.
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "devstoreaccount1",
        azurite_account_key,
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://devstoreaccount1.blob.core.windows.net/",
    );
    defer request.deinit();
    try request.setHeader("Date", "Fri, 26 Jun 2015 23:39:12 GMT");
    try request.setHeader("x-ms-meta-a!z", "bang");
    try request.setHeader("x-ms-meta-a#z", "hash");
    try request.setHeader("x-ms-meta-a$z", "dollar");
    try request.setHeader("x-ms-meta-a%z", "percent");
    try request.setHeader("x-ms-meta-a&z", "ampersand");
    try request.setHeader("x-ms-meta-a'z", "apostrophe");
    try request.setHeader("x-ms-meta-a*z", "asterisk");
    try request.setHeader("x-ms-meta-a+z", "plus");
    try request.setHeader("x-ms-meta-a-z", "hyphen");
    try request.setHeader("x-ms-meta-a.z", "dot");
    try request.setHeader("x-ms-meta-a^z", "caret");
    try request.setHeader("X-MS-META-A_Z", "underscore");
    try request.setHeader("x-ms-meta-a`z", "backtick");
    try request.setHeader("x-ms-meta-a|z", "pipe");
    try request.setHeader("x-ms-meta-a~z", "tilde");
    try request.setHeader("x-ms-meta-ab", "letters");

    const expected_string =
        "GET\n" ++
        "\n" ** 5 ++
        "Fri, 26 Jun 2015 23:39:12 GMT\n" ++
        "\n" ** 5 ++
        "x-ms-meta-a!z:bang\n" ++
        "x-ms-meta-a#z:hash\n" ++
        "x-ms-meta-a$z:dollar\n" ++
        "x-ms-meta-a%z:percent\n" ++
        "x-ms-meta-a&z:ampersand\n" ++
        "x-ms-meta-a*z:asterisk\n" ++
        "x-ms-meta-a.z:dot\n" ++
        "x-ms-meta-a^z:caret\n" ++
        "x-ms-meta-a_z:underscore\n" ++
        "x-ms-meta-a`z:backtick\n" ++
        "x-ms-meta-a|z:pipe\n" ++
        "x-ms-meta-a~z:tilde\n" ++
        "x-ms-meta-a+z:plus\n" ++
        "x-ms-meta-ab:letters\n" ++
        "x-ms-meta-a'z:apostrophe\n" ++
        "x-ms-meta-a-z:hyphen\n" ++
        "/devstoreaccount1/";

    try std.testing.expect(
        compareCanonicalHeaderNames("x-ms-meta-a_z", "x-ms-meta-ab") < 0,
    );
    try std.testing.expect(
        compareCanonicalHeaderNames("x-ms-meta-a'z", "x-ms-meta-a-z") < 0,
    );
    try credential.signRequest(&request, provider_impl.asProvider());
    try std.testing.expectEqualStrings(
        "SharedKey devstoreaccount1:nB1SHSCO6trrvw6+dhfCrhlYC/4SfYfkFy4vzueeyEs=",
        request.getHeader("Authorization").?,
    );

    var spy = TestCryptoProvider{};
    try credential.signRequest(&request, spy.provider());
    try std.testing.expectEqualStrings(expected_string, spy.message[0..spy.message_len]);
}

test "Shared Key canonicalizes Date Content-MD5 whitespace and repeated encoded queries" {
    // Microsoft Learn's Shared Key sequence and query rules, signed with the
    // documented Azurite development account credentials.
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "devstoreaccount1",
        azurite_account_key,
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .PUT,
        "https://devstoreaccount1.blob.core.windows.net/container/blob%20name?include=uncommittedblobs&Comp=metadata&include=snapshots&include=metadata%2Fencoded&z=a%2Bb&Z=a+b&empty=",
    );
    defer request.deinit();
    try request.setHeader("Content-Encoding", "gzip");
    try request.setHeader("Content-Language", "en-US");
    try request.setHeader("Content-Length", "0");
    try request.setHeader("Content-MD5", "Q2hlY2sgSW50ZWdyaXR5IQ==");
    try request.setHeader("Content-Type", "application/octet-stream");
    try request.setHeader("Date", "Fri, 26 Jun 2015 23:39:12 GMT");
    try request.setHeader("If-Modified-Since", "Thu, 25 Jun 2015 23:39:12 GMT");
    try request.setHeader("If-Match", "\"etag\"");
    try request.setHeader("If-None-Match", "\"other\"");
    try request.setHeader("If-Unmodified-Since", "Sat, 27 Jun 2015 23:39:12 GMT");
    try request.setHeader("Range", "bytes=0-511");
    try request.setHeader("X-Ms-Meta-Zeta", "  alpha\t beta  ");
    try request.setHeader("x-ms-meta-quoted", "\"a  b\"");
    try request.setHeader("x-ms-version", "2021-10-04");

    const expected_string =
        "PUT\n" ++
        "gzip\n" ++
        "en-US\n" ++
        "\n" ++
        "Q2hlY2sgSW50ZWdyaXR5IQ==\n" ++
        "application/octet-stream\n" ++
        "Fri, 26 Jun 2015 23:39:12 GMT\n" ++
        "Thu, 25 Jun 2015 23:39:12 GMT\n" ++
        "\"etag\"\n" ++
        "\"other\"\n" ++
        "Sat, 27 Jun 2015 23:39:12 GMT\n" ++
        "bytes=0-511\n" ++
        "x-ms-meta-quoted:\"a  b\"\n" ++
        "x-ms-meta-zeta:alpha beta\n" ++
        "x-ms-version:2021-10-04\n" ++
        "/devstoreaccount1/container/blob%20name\n" ++
        "comp:metadata\n" ++
        "empty:\n" ++
        "include:metadata/encoded,snapshots,uncommittedblobs\n" ++
        "z:a b,a+b";

    try credential.signRequest(&request, provider_impl.asProvider());
    try std.testing.expectEqualStrings(
        "SharedKey devstoreaccount1:7iPGWBPwxm5aCgpfzy/CB1QsJGpKx/GCg8WGNQpSU38=",
        request.getHeader("Authorization").?,
    );
    var spy = TestCryptoProvider{};
    try credential.signRequest(&request, spy.provider());
    try std.testing.expectEqualStrings(expected_string, spy.message[0..spy.message_len]);
}

test "Shared Key applies versioned zero length and Blob Queue File resource rules" {
    const allocator = std.testing.allocator;
    const urls = [_][]const u8{
        "https://account.blob.core.windows.net/container",
        "https://account.queue.core.windows.net/queue",
        "https://account.file.core.windows.net/share/file",
    };
    const resources = [_][]const u8{
        "/account/container",
        "/account/queue",
        "/account/share/file",
    };

    for (urls, resources) |url, resource| {
        var request = core.http.Request.init(allocator, .PUT, url);
        defer request.deinit();
        try request.setHeader("Content-Length", "0");
        try request.setHeader("x-ms-version", "2014-02-14");
        const old_string = try buildSharedKeyStringToSign(allocator, "account", &request);
        defer allocator.free(old_string);
        try std.testing.expect(std.mem.startsWith(u8, old_string, "PUT\n\n\n0\n"));
        try std.testing.expect(std.mem.endsWith(u8, old_string, resource));

        try request.setHeader("x-ms-version", "2014-08-16");
        const current_string = try buildSharedKeyStringToSign(allocator, "account", &request);
        defer allocator.free(current_string);
        try std.testing.expect(std.mem.startsWith(u8, current_string, "PUT\n\n\n\n"));
        try std.testing.expect(std.mem.endsWith(u8, current_string, resource));
    }
}

test "StorageSharedKeyCredential provider failure leaves authorization unchanged" {
    const allocator = std.testing.allocator;
    var fault = TestCryptoProvider{ .fail = true };
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "myaccount",
        azurite_account_key,
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://myaccount.blob.core.windows.net/container/blob",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "unchanged");

    try std.testing.expectError(
        error.ProviderFailure,
        credential.signRequest(&request, fault.provider()),
    );
    try std.testing.expectEqualStrings(
        "unchanged",
        request.headers.get("Authorization").?,
    );
}

test "Shared Key canonicalization failure leaves authorization unchanged" {
    const allocator = std.testing.allocator;
    var spy = TestCryptoProvider{};
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "devstoreaccount1",
        azurite_account_key,
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://devstoreaccount1.queue.core.windows.net/queue?comp=%ZZ",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "unchanged");

    try std.testing.expectError(
        error.InvalidPercentEncoding,
        credential.signRequest(&request, spy.provider()),
    );
    try std.testing.expectEqual(@as(usize, 0), spy.calls);
    try std.testing.expectEqualStrings(
        "unchanged",
        request.getHeader("Authorization").?,
    );
}

test "decoded credential keys are wiped on failure replacement and deinit" {
    try std.testing.expectError(
        error.InvalidAccountKey,
        StorageSharedKeyCredential.init(std.testing.allocator, "account", ""),
    );

    var invalid_allocator = TestWipeAllocator{ .backing = std.testing.allocator };
    try std.testing.expectError(
        error.InvalidCharacter,
        StorageSharedKeyCredential.init(invalid_allocator.allocator(), "account", "QU!D"),
    );
    try std.testing.expectEqual(@as(usize, 1), invalid_allocator.free_count);
    try std.testing.expect(invalid_allocator.freed_was_zero[0]);

    var init_wipe_allocator = TestWipeAllocator{ .backing = std.testing.allocator };
    var init_failing_allocator = std.testing.FailingAllocator.init(
        init_wipe_allocator.allocator(),
        .{ .fail_index = 1 },
    );
    try std.testing.expectError(
        error.OutOfMemory,
        StorageSharedKeyCredential.init(
            init_failing_allocator.allocator(),
            "account",
            "AQID",
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), init_wipe_allocator.free_count);
    try std.testing.expect(init_wipe_allocator.freed_was_zero[0]);

    var allocator = TestWipeAllocator{ .backing = std.testing.allocator };
    var credential = try StorageSharedKeyCredential.init(
        allocator.allocator(),
        "a",
        "AQID",
    );

    try std.testing.expectError(
        error.InvalidCharacter,
        credential.replaceAccountKey("QU!D"),
    );
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, credential.decoded_account_key);
    try std.testing.expectEqual(@as(usize, 1), allocator.free_count);
    try std.testing.expect(allocator.freed_was_zero[0]);

    try credential.replaceAccountKey("BAUG");
    try std.testing.expectEqual(@as(usize, 2), allocator.free_count);
    try std.testing.expect(allocator.freed_was_zero[1]);
    credential.deinit();
    try std.testing.expectEqual(@as(usize, 4), allocator.free_count);
    try std.testing.expect(!allocator.freed_was_zero[2]);
    try std.testing.expect(allocator.freed_was_zero[3]);
}

test "SasBuilder matches Azure SDK account SAS vector" {
    // Azure/azure-storage-node test/common/sharedkey-tests.js.
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const builder = SasBuilder{
        .account_name = "devstoreaccount1",
        .permissions = "r",
        .services = "b",
        .resource_types = "s",
        .start = "2016-02-16T00:00:00Z",
        .expiry = "2016-02-16T00:30:00Z",
        .ip = "168.1.5.60-168.1.5.70",
        .protocol = "https",
        .version = "2018-03-28",
    };
    const query = try builder.sign(
        allocator,
        provider_impl.asProvider(),
        azurite_account_key,
    );
    defer allocator.free(query);
    try std.testing.expectEqualStrings(
        "sv=2018-03-28&ss=b&srt=s&sp=r&st=2016-02-16T00%3A00%3A00Z&se=2016-02-16T00%3A30%3A00Z&sip=168.1.5.60-168.1.5.70&spr=https&sig=AHRdNnjupqU4dUXLlbOX6ACUA7JQNFBob%2FzbFHKKzwI%3D",
        query,
    );

    var spy = TestCryptoProvider{};
    const spy_query = try builder.sign(allocator, spy.provider(), azurite_account_key);
    defer allocator.free(spy_query);
    try std.testing.expectEqualStrings(
        "devstoreaccount1\nr\nb\ns\n2016-02-16T00:00:00Z\n2016-02-16T00:30:00Z\n168.1.5.60-168.1.5.70\nhttps\n2018-03-28\n",
        spy.message[0..spy.message_len],
    );
    try std.testing.expect(std.mem.endsWith(
        u8,
        spy_query,
        "sig=%2B%2F%2F%2BpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaWlpaU%3D",
    ));
}

test "SasBuilder signs encryption scope only for supported versions" {
    // Microsoft Learn's account SAS 2020-12-06 string-to-sign extension.
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const builder = SasBuilder{
        .account_name = "devstoreaccount1",
        .permissions = "rwdlacup",
        .services = "bfqt",
        .resource_types = "sco",
        .start = "2021-01-01T00:00:00Z",
        .expiry = "2021-01-02T00:00:00Z",
        .ip = "168.1.5.60-168.1.5.70",
        .protocol = "https,http",
        .version = "2020-12-06",
        .encryption_scope = "scope-2",
    };
    const query = try builder.sign(
        allocator,
        provider_impl.asProvider(),
        azurite_account_key,
    );
    defer allocator.free(query);
    try std.testing.expectEqualStrings(
        "sv=2020-12-06&ss=bfqt&srt=sco&sp=rwdlacup&st=2021-01-01T00%3A00%3A00Z&se=2021-01-02T00%3A00%3A00Z&sip=168.1.5.60-168.1.5.70&spr=https%2Chttp&ses=scope-2&sig=%2B7sBhcx8KqEYxxP4N54W%2FvES8O8I4nFZKRztwMalUlI%3D",
        query,
    );

    var unsupported = builder;
    unsupported.version = "2020-10-02";
    try std.testing.expectError(
        error.EncryptionScopeUnsupported,
        unsupported.sign(allocator, provider_impl.asProvider(), azurite_account_key),
    );
    unsupported.encryption_scope = null;
    unsupported.version = "2014-02-14";
    try std.testing.expectError(
        error.AccountSasVersionUnsupported,
        unsupported.sign(allocator, provider_impl.asProvider(), azurite_account_key),
    );
}

test "SasBuilder dispatches provider and rejects invalid keys without output" {
    const allocator = std.testing.allocator;
    const builder = SasBuilder{
        .account_name = "devstoreaccount1",
        .expiry = "2026-12-31T23:59:59Z",
    };
    var spy = TestCryptoProvider{};
    const query = try builder.sign(allocator, spy.provider(), "AQID");
    defer allocator.free(query);
    try std.testing.expectEqual(.hmac_sha256, spy.operation);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, spy.key[0..spy.key_len]);

    var fault = TestCryptoProvider{ .fail = true };
    try std.testing.expectError(
        error.ProviderFailure,
        builder.sign(allocator, fault.provider(), "AQID"),
    );
    try std.testing.expectError(
        error.InvalidAccountKey,
        builder.sign(allocator, spy.provider(), ""),
    );

    var wipe_allocator = TestWipeAllocator{ .backing = std.testing.allocator };
    try std.testing.expectError(
        error.InvalidCharacter,
        builder.sign(wipe_allocator.allocator(), spy.provider(), "QU!D"),
    );
    try std.testing.expectEqual(@as(usize, 1), wipe_allocator.free_count);
    try std.testing.expect(wipe_allocator.freed_was_zero[0]);
}

test "SasBuilder toQueryString unsigned" {
    const allocator = std.testing.allocator;
    const builder = SasBuilder{
        .account_name = "devstoreaccount1",
        .permissions = "rl",
        .start = "2026-01-01T00:00:00Z",
        .expiry = "2026-12-31T23:59:59Z",
        .ip = "127.0.0.1",
        .protocol = "https,http",
        .encryption_scope = "scope/name",
    };
    const query = try builder.toQueryString(allocator);
    defer allocator.free(query);
    try std.testing.expectEqualStrings(
        "sv=2024-11-04&ss=b&srt=sco&sp=rl&st=2026-01-01T00%3A00%3A00Z&se=2026-12-31T23%3A59%3A59Z&sip=127.0.0.1&spr=https%2Chttp&ses=scope%2Fname",
        query,
    );
}

test "content hash standard vectors include empty bodies" {
    const allocator = std.testing.allocator;
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const provider = provider_impl.asProvider();

    const md5 = try contentMd5(allocator, provider, "hello");
    defer allocator.free(md5);
    try std.testing.expectEqualStrings("XUFAKrxLKna5cZ2REBfFkg==", md5);

    const empty_md5 = try contentMd5(allocator, provider, "");
    defer allocator.free(empty_md5);
    try std.testing.expectEqualStrings("1B2M2Y8AsgTpgAmY7PhCfg==", empty_md5);

    const sha256 = try contentSha256(allocator, provider, "hello");
    defer allocator.free(sha256);
    try std.testing.expectEqualStrings(
        "LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=",
        sha256,
    );

    const empty_sha256 = try contentSha256(allocator, provider, "");
    defer allocator.free(empty_sha256);
    try std.testing.expectEqualStrings(
        "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=",
        empty_sha256,
    );
}

test "content hashes dispatch provider and propagate failures without output" {
    const allocator = std.testing.allocator;
    var spy = TestCryptoProvider{};

    const md5 = try contentMd5(allocator, spy.provider(), "md5-data");
    defer allocator.free(md5);
    try std.testing.expectEqual(.md5, spy.operation);
    try std.testing.expectEqualStrings("md5-data", spy.data[0..spy.data_len]);

    const sha256 = try contentSha256(allocator, spy.provider(), "sha-data");
    defer allocator.free(sha256);
    try std.testing.expectEqual(.sha256, spy.operation);
    try std.testing.expectEqualStrings("sha-data", spy.data[0..spy.data_len]);

    const empty_sha256 = try contentSha256(allocator, spy.provider(), "");
    defer allocator.free(empty_sha256);
    try std.testing.expectEqual(.sha256, spy.operation);
    try std.testing.expectEqual(@as(usize, 0), spy.data_len);

    var fault = TestCryptoProvider{ .fail = true };
    try std.testing.expectError(
        error.ProviderFailure,
        contentMd5(allocator, fault.provider(), "body"),
    );
    try std.testing.expectError(
        error.ProviderFailure,
        contentSha256(allocator, fault.provider(), "body"),
    );
}

fn sharedKeyAllocationCase(allocator: std.mem.Allocator) !void {
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    var credential = try StorageSharedKeyCredential.init(
        allocator,
        "myaccount",
        azurite_account_key,
    );
    defer credential.deinit();
    var request = core.http.Request.init(
        allocator,
        .GET,
        "https://myaccount.blob.core.windows.net/container/blob",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "unchanged");

    credential.signRequest(&request, provider_impl.asProvider()) catch |err| {
        try std.testing.expectEqualStrings(
            "unchanged",
            request.getHeader("Authorization").?,
        );
        return err;
    };
}

fn sasAllocationCase(allocator: std.mem.Allocator) !void {
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const builder = SasBuilder{
        .account_name = "devstoreaccount1",
        .expiry = "2026-12-31T23:59:59Z",
    };
    const query = try builder.sign(
        allocator,
        provider_impl.asProvider(),
        azurite_account_key,
    );
    defer allocator.free(query);
}

fn contentMd5AllocationCase(allocator: std.mem.Allocator) !void {
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const value = try contentMd5(allocator, provider_impl.asProvider(), "body");
    defer allocator.free(value);
}

fn contentSha256AllocationCase(allocator: std.mem.Allocator) !void {
    var provider_impl = crypto.StdCryptoProvider.init(std.testing.io);
    const value = try contentSha256(allocator, provider_impl.asProvider(), "body");
    defer allocator.free(value);
}

test "crypto operations clean up on every allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        sharedKeyAllocationCase,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        sasAllocationCase,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        contentMd5AllocationCase,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        contentSha256AllocationCase,
        .{},
    );
}
