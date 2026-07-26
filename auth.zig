//! Azure Storage Tables authentication.  This deliberately implements the
//! Table-only SharedKeyLite form rather than Storage's general Shared Key form.
const std = @import("std");
const core = @import("azure_sdk_core");

/// Microsoft Entra scope for Azure Storage data-plane requests.
pub const storage_scope = "https://storage.azure.com/.default";

pub const SharedKeyCredential = struct {
    allocator: std.mem.Allocator,
    account_name: []u8,
    key: []u8,

    pub fn init(
        allocator: std.mem.Allocator,
        account_name: []const u8,
        account_key: []const u8,
    ) !SharedKeyCredential {
        try validateAccountName(account_name);
        const key = core.base64.decode(allocator, account_key) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return error.InvalidAccountKey,
        };
        errdefer allocator.free(key);
        if (key.len == 0) return error.InvalidAccountKey;
        return .{
            .allocator = allocator,
            .account_name = try allocator.dupe(u8, account_name),
            .key = key,
        };
    }

    pub fn deinit(self: *SharedKeyCredential) void {
        self.allocator.free(self.account_name);
        self.allocator.free(self.key);
        self.* = undefined;
    }

    /// Replaces the key only after decoding the complete new Base64 value.
    pub fn updateKey(self: *SharedKeyCredential, account_key: []const u8) !void {
        const replacement = core.base64.decode(self.allocator, account_key) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return error.InvalidAccountKey,
        };
        errdefer self.allocator.free(replacement);
        if (replacement.len == 0) return error.InvalidAccountKey;
        self.allocator.free(self.key);
        self.key = replacement;
    }

    pub fn accountName(self: *const SharedKeyCredential) []const u8 {
        return self.account_name;
    }

    /// Signs an exact canonical byte sequence with the decoded account key.
    pub fn sign(
        self: *const SharedKeyCredential,
        allocator: std.mem.Allocator,
        canonical: []const u8,
    ) ![]u8 {
        return core.base64.hmacSha256Base64(allocator, self.key, canonical);
    }

    pub fn format(_: SharedKeyCredential, writer: anytype) !void {
        try writer.writeAll("SharedKeyCredential(***)");
    }
};

/// SharedKeyLite policy. It runs after retry, so both date and signature are
/// regenerated for every attempt.
pub const SharedKeyLitePolicy = struct {
    credential: *SharedKeyCredential,
    api_version: []const u8,
    policy: core.pipeline.HttpPolicy = .{ .processFn = &process },

    pub fn init(credential: *SharedKeyCredential, api_version: []const u8) SharedKeyLitePolicy {
        return .{ .credential = credential, .api_version = api_version };
    }

    pub fn asPolicy(self: *SharedKeyLitePolicy) *core.pipeline.HttpPolicy {
        return &self.policy;
    }

    fn process(
        policy: *core.pipeline.HttpPolicy,
        request: *core.http.Request,
        next: []*core.pipeline.HttpPolicy,
        transport: *core.http.HttpTransport,
    ) anyerror!core.http.Response {
        const self: *SharedKeyLitePolicy = @alignCast(@fieldParentPtr("policy", policy));
        var date: [32]u8 = undefined;
        var threaded: std.Io.Threaded = .init_single_threaded;
        const timestamp: i64 = @intCast(@divTrunc(
            std.Io.Timestamp.now(threaded.io(), .real).toNanoseconds(),
            std.time.ns_per_s,
        ));
        const date_value = formatHttpDate(&date, timestamp);
        try request.setHeader("x-ms-date", date_value);
        try request.setHeader("x-ms-version", self.api_version);

        const canonical = try canonicalizedResource(
            request.allocator,
            self.credential.account_name,
            request.url,
        );
        defer request.allocator.free(canonical);
        const to_sign = try std.fmt.allocPrint(
            request.allocator,
            "{s}\n{s}",
            .{ date_value, canonical },
        );
        defer request.allocator.free(to_sign);
        const signature = try self.credential.sign(request.allocator, to_sign);
        defer request.allocator.free(signature);
        const authorization = try std.fmt.allocPrint(
            request.allocator,
            "SharedKeyLite {s}:{s}",
            .{ self.credential.account_name, signature },
        );
        defer request.allocator.free(authorization);
        try request.setHeader("Authorization", authorization);
        if (next.len == 0) return transport.send(request);
        return next[0].process(request, next[1..], transport);
    }
};

/// Return the exact Table SharedKeyLite canonical resource.  Only `comp`
/// participates in the query portion; SAS and ordinary query fields do not.
pub fn canonicalizedResource(
    allocator: std.mem.Allocator,
    account_name: []const u8,
    url: []const u8,
) ![]u8 {
    if (account_name.len == 0) return error.InvalidAccountName;
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return error.InvalidEndpoint;
    const after_authority = scheme_end + 3;
    const path_start = std.mem.indexOfScalarPos(u8, url, after_authority, '/') orelse url.len;
    const query_start = std.mem.indexOfScalarPos(u8, url, after_authority, '?') orelse url.len;
    const resource_end = @min(path_start, query_start);
    _ = resource_end;
    const path_end = query_start;
    const raw_path = if (path_start < query_start) url[path_start..path_end] else "/";
    const path = if (raw_path.len == 0) "/" else raw_path;
    const raw_query = if (query_start < url.len) url[query_start + 1 ..] else "";

    var comp: ?[]u8 = null;
    defer if (comp) |value| allocator.free(value);
    var parts = std.mem.splitScalar(u8, raw_query, '&');
    while (parts.next()) |part| {
        const equal = std.mem.indexOfScalar(u8, part, '=') orelse part.len;
        if (!std.ascii.eqlIgnoreCase(part[0..equal], "comp")) continue;
        if (comp != null) return error.InvalidCompQuery;
        comp = try percentDecode(allocator, if (equal < part.len) part[equal + 1 ..] else "");
    }
    if (comp) |value|
        return std.fmt.allocPrint(allocator, "/{s}{s}?comp={s}", .{ account_name, path, value });
    return std.fmt.allocPrint(allocator, "/{s}{s}", .{ account_name, path });
}

fn percentDecode(allocator: std.mem.Allocator, value: []const u8) ![]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    var i: usize = 0;
    while (i < value.len) : (i += 1) {
        if (value[i] != '%') {
            try decoded.append(allocator, value[i]);
            continue;
        }
        if (i + 2 >= value.len) return error.InvalidPercentEncoding;
        const hi = hexDigit(value[i + 1]) orelse return error.InvalidPercentEncoding;
        const lo = hexDigit(value[i + 2]) orelse return error.InvalidPercentEncoding;
        try decoded.append(allocator, @intCast(hi * 16 + lo));
        i += 2;
    }

    return decoded.toOwnedSlice(allocator);
}

fn hexDigit(byte: u8) ?u8 {
    if (byte >= '0' and byte <= '9') return byte - '0';
    if (byte >= 'a' and byte <= 'f') return byte - 'a' + 10;
    if (byte >= 'A' and byte <= 'F') return byte - 'A' + 10;
    return null;
}

pub fn validateAccountName(name: []const u8) !void {
    if (name.len < 3 or name.len > 24) return error.InvalidAccountName;
    for (name) |byte| if (!std.ascii.isLower(byte) and !std.ascii.isDigit(byte))
        return error.InvalidAccountName;
}

fn formatHttpDate(buffer: *[32]u8, timestamp: i64) []const u8 {
    // Howard Hinnant's civil-from-days conversion, UTC and allocation-free.
    const days = @divFloor(timestamp, 86_400);
    const seconds: u64 = @intCast(@mod(timestamp, 86_400));
    const z = days + 719_468;
    const era = @divFloor(if (z >= 0) z else z - 146_096, 146_097);
    const doe = z - era * 146_097;
    const yoe = @divFloor(doe - @divFloor(doe, 1460) + @divFloor(doe, 36_524) - @divFloor(doe, 146_096), 365);
    var year = yoe + era * 400;
    const doy = doe - (365 * yoe + @divFloor(yoe, 4) - @divFloor(yoe, 100));
    const mp = @divFloor(5 * doy + 2, 153);
    const day = doy - @divFloor(153 * mp + 2, 5) + 1;
    const month = mp + (if (mp < 10) @as(i64, 3) else @as(i64, -9));
    year += if (month <= 2) @as(i64, 1) else @as(i64, 0);
    const weekdays = [_][]const u8{ "Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed" };
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    return std.fmt.bufPrint(
        buffer,
        "{s}, {d:0>2} {s} {d:0>4} {d:0>2}:{d:0>2}:{d:0>2} GMT",
        .{ weekdays[@intCast(@mod(days, 7))], day, months[@intCast(month - 1)], year, seconds / 3600, (seconds / 60) % 60, seconds % 60 },
    ) catch unreachable;
}

test "published Tables SharedKeyLite vector" {
    const allocator = std.testing.allocator;
    const resource = try canonicalizedResource(
        allocator,
        "account-name",
        "https://goqu.table.core.windows.net?restype=service&comp=properties",
    );
    defer allocator.free(resource);
    try std.testing.expectEqualStrings("/account-name/?comp=properties", resource);
    const signature = try core.base64.hmacSha256Base64(
        allocator,
        "account-key",
        "Thu, 23 Apr 2020 09:43:37 GMT\n/account-name/?comp=properties",
    );
    defer allocator.free(signature);
    try std.testing.expectEqualStrings("tW8SGePdivpFOEJfTxikbSwjdDWkpxSTfFtqUMED3v8=", signature);
}

test "canonical resource includes paths and only decoded comp" {
    const allocator = std.testing.allocator;
    const root = try canonicalizedResource(allocator, "account", "https://account.table.core.windows.net");
    defer allocator.free(root);
    try std.testing.expectEqualStrings("/account/", root);
    const entity = try canonicalizedResource(allocator, "account", "https://account.table.core.windows.net/People(PartitionKey='p',RowKey='r')?sig=secret&comp=acl%2Fvalue&x=1");
    defer allocator.free(entity);
    try std.testing.expectEqualStrings("/account/People(PartitionKey='p',RowKey='r')?comp=acl/value", entity);
}

test "canonical resource recognizes comp case-insensitively and emits lowercase comp" {
    const allocator = std.testing.allocator;
    const title_case = try canonicalizedResource(
        allocator,
        "account",
        "https://account.table.core.windows.net?Comp=acl%2Fvalue",
    );
    defer allocator.free(title_case);
    try std.testing.expectEqualStrings("/account/?comp=acl/value", title_case);

    const upper_case = try canonicalizedResource(
        allocator,
        "account",
        "https://account.table.core.windows.net?COMP=properties%20value",
    );
    defer allocator.free(upper_case);
    try std.testing.expectEqualStrings("/account/?comp=properties value", upper_case);
    try std.testing.expectError(
        error.InvalidCompQuery,
        canonicalizedResource(
            allocator,
            "account",
            "https://account.table.core.windows.net?Comp=one&COMP=two",
        ),
    );
}
