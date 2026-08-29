//! Account and table SAS values, validation, canonical signing, and encoding.
const std = @import("std");
const core = @import("azure_sdk_core");
const auth = @import("auth.zig");
const request = @import("request.zig");

var testing_crypto_provider = core.crypto.StdCryptoProvider.init(std.testing.io);

fn testingCrypto() core.crypto.CryptoProvider {
    return testing_crypto_provider.asProvider();
}

fn wipe(bytes: []u8) void {
    const volatile_bytes: []volatile u8 = bytes;
    @memset(volatile_bytes, 0);
}

fn wipeAndFree(allocator: std.mem.Allocator, bytes: []u8) void {
    wipe(bytes);
    allocator.free(bytes);
}

/// The newest stable Azure Tables contract version. A newer general Storage
/// version is not a newer Tables data-plane contract.
pub const version = "2019-02-02";

const Flag = struct {
    field: []const u8,
    byte: u8,
};

/// Maps boolean fields to their service-defined order. Every mapping is
/// checked at comptime and the same implementation is used for permissions,
/// services, and resource types.
fn orderedFlags(
    comptime T: type,
    value: T,
    comptime mapping: []const Flag,
    buffer: *[mapping.len]u8,
) []const u8 {
    comptime {
        const fields = std.meta.fields(T);
        if (fields.len != mapping.len)
            @compileError(@typeName(T) ++ " must map every flag exactly once");
        for (mapping, 0..) |entry, index| {
            if (!@hasField(T, entry.field))
                @compileError(@typeName(T) ++ " has no field named " ++ entry.field);
            if (@TypeOf(@field(@as(T, undefined), entry.field)) != bool)
                @compileError(@typeName(T) ++ "." ++ entry.field ++ " must be bool");
            for (mapping[0..index]) |previous| {
                if (std.mem.eql(u8, previous.field, entry.field) or previous.byte == entry.byte)
                    @compileError(@typeName(T) ++ " has a duplicate flag mapping");
            }
        }
    }

    var length: usize = 0;
    inline for (mapping) |entry| {
        if (@field(value, entry.field)) {
            buffer[length] = entry.byte;
            length += 1;
        }
    }
    return buffer[0..length];
}

pub const AccountPermissions = struct {
    read: bool = false,
    write: bool = false,
    delete: bool = false,
    list: bool = false,
    add: bool = false,
    create: bool = false,
    update: bool = false,

    const order = &[_]Flag{
        .{ .field = "read", .byte = 'r' },
        .{ .field = "write", .byte = 'w' },
        .{ .field = "delete", .byte = 'd' },
        .{ .field = "list", .byte = 'l' },
        .{ .field = "add", .byte = 'a' },
        .{ .field = "create", .byte = 'c' },
        .{ .field = "update", .byte = 'u' },
    };

    pub fn string(self: AccountPermissions, buffer: *[order.len]u8) []const u8 {
        return orderedFlags(AccountPermissions, self, order, buffer);
    }
};

/// Account SAS generation in this package is intentionally Table-only.
pub const AccountServices = struct {
    table: bool = false,

    const order = &[_]Flag{.{ .field = "table", .byte = 't' }};

    pub fn string(self: AccountServices, buffer: *[order.len]u8) []const u8 {
        return orderedFlags(AccountServices, self, order, buffer);
    }
};

pub const AccountResourceTypes = struct {
    service: bool = false,
    container: bool = false,
    object: bool = false,

    const order = &[_]Flag{
        .{ .field = "service", .byte = 's' },
        .{ .field = "container", .byte = 'c' },
        .{ .field = "object", .byte = 'o' },
    };

    pub fn string(self: AccountResourceTypes, buffer: *[order.len]u8) []const u8 {
        return orderedFlags(AccountResourceTypes, self, order, buffer);
    }
};

pub const TablePermissions = struct {
    read: bool = false,
    add: bool = false,
    update: bool = false,
    delete: bool = false,

    const order = &[_]Flag{
        .{ .field = "read", .byte = 'r' },
        .{ .field = "add", .byte = 'a' },
        .{ .field = "update", .byte = 'u' },
        .{ .field = "delete", .byte = 'd' },
    };

    pub fn string(self: TablePermissions, buffer: *[order.len]u8) []const u8 {
        return orderedFlags(TablePermissions, self, order, buffer);
    }
};

pub const TableAccessPolicy = union(enum) {
    adHoc: struct {
        permissions: TablePermissions,
        startTime: ?UtcTime = null,
        expiryTime: UtcTime,
    },
    stored: []const u8,
};

pub const Protocol = enum {
    https,
    httpsAndHttp,

    pub fn string(self: Protocol) []const u8 {
        return switch (self) {
            .https => "https",
            .httpsAndHttp => "https,http",
        };
    }
};

pub const UtcTime = struct {
    unix_seconds: i64,

    pub fn fromUnixSeconds(unix_seconds: i64) UtcTime {
        return .{ .unix_seconds = unix_seconds };
    }
};

pub const IPv4Address = [4]u8;

pub const IPRange = struct {
    start: IPv4Address,
    end: ?IPv4Address = null,

    pub fn init(start: IPv4Address, end: ?IPv4Address) !IPRange {
        if (end) |last| {
            if (addressInteger(start) > addressInteger(last))
                return error.InvalidSasIPRange;
        }
        return .{ .start = start, .end = end };
    }

    pub fn parse(start: []const u8, end: ?[]const u8) !IPRange {
        const first = try parseIPv4(start);
        const last = if (end) |value| try parseIPv4(value) else null;
        return init(first, last);
    }
};

pub const AccountSignatureValues = struct {
    permissions: AccountPermissions,
    services: AccountServices = .{ .table = true },
    resourceTypes: AccountResourceTypes,
    startTime: ?UtcTime = null,
    expiryTime: ?UtcTime,
    protocol: Protocol = .https,
    ipRange: ?IPRange = null,

    pub fn sign(
        self: AccountSignatureValues,
        allocator: std.mem.Allocator,
        credential: *const auth.SharedKeyCredential,
        crypto_provider: core.crypto.CryptoProvider,
    ) !QueryParameters {
        try self.validate();

        var permissions_buffer: [AccountPermissions.order.len]u8 = undefined;
        const permissions = self.permissions.string(&permissions_buffer);
        var services_buffer: [AccountServices.order.len]u8 = undefined;
        const services = self.services.string(&services_buffer);
        var resource_types_buffer: [AccountResourceTypes.order.len]u8 = undefined;
        const resource_types = self.resourceTypes.string(&resource_types_buffer);
        var start_buffer: [32]u8 = undefined;
        const start = if (self.startTime) |value| try formatTime(&start_buffer, value) else "";
        var expiry_buffer: [32]u8 = undefined;
        const expiry = try formatTime(&expiry_buffer, self.expiryTime.?);
        var ip_buffer: [31]u8 = undefined;
        const ip = if (self.ipRange) |value| formatIPRange(&ip_buffer, value) else "";

        const string_to_sign = try std.fmt.allocPrint(
            allocator,
            "{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n",
            .{
                credential.accountName(),
                permissions,
                services,
                resource_types,
                start,
                expiry,
                ip,
                self.protocol.string(),
                version,
            },
        );
        defer allocator.free(string_to_sign);
        const signature = try credential.sign(allocator, crypto_provider, string_to_sign);
        defer wipeAndFree(allocator, signature);

        var query: std.ArrayList(u8) = .empty;
        errdefer query.deinit(allocator);
        var has_parameter = false;
        try appendQueryParameter(&query, allocator, &has_parameter, "se", expiry);
        try appendQueryParameter(&query, allocator, &has_parameter, "sig", signature);
        if (ip.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "sip", ip);
        try appendQueryParameter(&query, allocator, &has_parameter, "sp", permissions);
        try appendQueryParameter(&query, allocator, &has_parameter, "spr", self.protocol.string());
        try appendQueryParameter(&query, allocator, &has_parameter, "srt", resource_types);
        try appendQueryParameter(&query, allocator, &has_parameter, "ss", services);
        if (start.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "st", start);
        try appendQueryParameter(&query, allocator, &has_parameter, "sv", version);
        return .{ .allocator = allocator, .encoded_query = try query.toOwnedSlice(allocator) };
    }

    fn validate(self: AccountSignatureValues) !void {
        var permissions_buffer: [AccountPermissions.order.len]u8 = undefined;
        if (self.permissions.string(&permissions_buffer).len == 0)
            return error.MissingSasPermissions;
        var services_buffer: [AccountServices.order.len]u8 = undefined;
        if (self.services.string(&services_buffer).len == 0)
            return error.MissingSasServices;
        var resource_types_buffer: [AccountResourceTypes.order.len]u8 = undefined;
        if (self.resourceTypes.string(&resource_types_buffer).len == 0)
            return error.MissingSasResourceTypes;
        const expiry = self.expiryTime orelse return error.MissingSasExpiry;
        try validateTimeRange(self.startTime, expiry);
        if (self.ipRange) |value| try validateIPRange(value);

        const types = self.resourceTypes;
        if (self.permissions.read and !types.service and !types.object)
            return error.InvalidSasPermissionResourceCombination;
        if (self.permissions.write and !types.service and !types.container)
            return error.InvalidSasPermissionResourceCombination;
        if (self.permissions.delete and !types.container and !types.object)
            return error.InvalidSasPermissionResourceCombination;
        if (self.permissions.list and !types.container)
            return error.InvalidSasPermissionResourceCombination;
        if ((self.permissions.add or self.permissions.update) and !types.object)
            return error.InvalidSasPermissionResourceCombination;
        if (self.permissions.create and !types.container)
            return error.InvalidSasPermissionResourceCombination;
    }

    pub fn format(_: AccountSignatureValues, writer: anytype) !void {
        try writer.writeAll("AccountSignatureValues(***)");
    }
};

pub const TableSignatureValues = struct {
    tableName: []const u8 = "",
    accessPolicy: TableAccessPolicy,
    protocol: Protocol = .https,
    ipRange: ?IPRange = null,
    startPartitionKey: ?[]const u8 = null,
    startRowKey: ?[]const u8 = null,
    endPartitionKey: ?[]const u8 = null,
    endRowKey: ?[]const u8 = null,

    pub fn sign(
        self: TableSignatureValues,
        allocator: std.mem.Allocator,
        credential: *const auth.SharedKeyCredential,
        crypto_provider: core.crypto.CryptoProvider,
    ) !QueryParameters {
        try self.validate();

        var permissions_buffer: [TablePermissions.order.len]u8 = undefined;
        const permissions = switch (self.accessPolicy) {
            .adHoc => |policy| policy.permissions.string(&permissions_buffer),
            .stored => "",
        };
        var start_buffer: [32]u8 = undefined;
        const start = switch (self.accessPolicy) {
            .adHoc => |policy| if (policy.startTime) |value|
                try formatTime(&start_buffer, value)
            else
                "",
            .stored => "",
        };
        var expiry_buffer: [32]u8 = undefined;
        const expiry = switch (self.accessPolicy) {
            .adHoc => |policy| try formatTime(&expiry_buffer, policy.expiryTime),
            .stored => "",
        };
        var ip_buffer: [31]u8 = undefined;
        const ip = if (self.ipRange) |value| formatIPRange(&ip_buffer, value) else "";
        const identifier = switch (self.accessPolicy) {
            .adHoc => "",
            .stored => |value| value,
        };
        const start_pk = self.startPartitionKey orelse "";
        const start_rk = self.startRowKey orelse "";
        const end_pk = self.endPartitionKey orelse "";
        const end_rk = self.endRowKey orelse "";

        const lower_table = try allocator.dupe(u8, self.tableName);
        defer allocator.free(lower_table);
        for (lower_table) |*byte| byte.* = std.ascii.toLower(byte.*);
        const canonical_name = try std.fmt.allocPrint(
            allocator,
            "/table/{s}/{s}",
            .{ credential.accountName(), lower_table },
        );
        defer allocator.free(canonical_name);
        const string_to_sign = try std.fmt.allocPrint(
            allocator,
            "{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}\n{s}",
            .{
                permissions,
                start,
                expiry,
                canonical_name,
                identifier,
                ip,
                self.protocol.string(),
                version,
                start_pk,
                start_rk,
                end_pk,
                end_rk,
            },
        );
        defer allocator.free(string_to_sign);
        const signature = try credential.sign(allocator, crypto_provider, string_to_sign);
        defer wipeAndFree(allocator, signature);

        var query: std.ArrayList(u8) = .empty;
        errdefer query.deinit(allocator);
        var has_parameter = false;
        if (end_pk.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "epk", end_pk);
        if (end_rk.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "erk", end_rk);
        if (expiry.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "se", expiry);
        if (identifier.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "si", identifier);
        try appendQueryParameter(&query, allocator, &has_parameter, "sig", signature);
        if (ip.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "sip", ip);
        if (permissions.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "sp", permissions);
        if (start_pk.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "spk", start_pk);
        try appendQueryParameter(&query, allocator, &has_parameter, "spr", self.protocol.string());
        if (start_rk.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "srk", start_rk);
        if (start.len != 0)
            try appendQueryParameter(&query, allocator, &has_parameter, "st", start);
        try appendQueryParameter(&query, allocator, &has_parameter, "sv", version);
        try appendQueryParameter(&query, allocator, &has_parameter, "tn", lower_table);
        return .{ .allocator = allocator, .encoded_query = try query.toOwnedSlice(allocator) };
    }

    fn validate(self: TableSignatureValues) !void {
        try request.validateTableName(self.tableName);
        switch (self.accessPolicy) {
            .adHoc => |policy| {
                var permissions_buffer: [TablePermissions.order.len]u8 = undefined;
                if (policy.permissions.string(&permissions_buffer).len == 0)
                    return error.MissingSasPermissions;
                try validateTimeRange(policy.startTime, policy.expiryTime);
            },
            .stored => |identifier| try validateIdentifier(identifier),
        }
        if (self.ipRange) |value| try validateIPRange(value);

        const has_start_pk = self.startPartitionKey != null;
        const has_start_rk = self.startRowKey != null;
        const has_end_pk = self.endPartitionKey != null;
        const has_end_rk = self.endRowKey != null;
        if ((!has_start_pk and has_start_rk) or (!has_end_pk and has_end_rk))
            return error.InvalidSasKeyRange;
        if (self.startPartitionKey) |value| try request.validateEntityKey(value);
        if (self.startRowKey) |value| try request.validateEntityKey(value);
        if (self.endPartitionKey) |value| try request.validateEntityKey(value);
        if (self.endRowKey) |value| try request.validateEntityKey(value);
        if (self.startPartitionKey != null and self.endPartitionKey != null) {
            const partition_order = std.mem.order(
                u8,
                self.startPartitionKey.?,
                self.endPartitionKey.?,
            );
            if (partition_order == .gt or (partition_order == .eq and
                has_start_rk and has_end_rk and
                std.mem.order(u8, self.startRowKey.?, self.endRowKey.?) == .gt))
            {
                return error.InvalidSasKeyRange;
            }
        }
    }

    pub fn format(_: TableSignatureValues, writer: anytype) !void {
        try writer.writeAll("TableSignatureValues(***)");
    }
};

/// Owns the opaque encoded SAS query. Formatting never exposes its signature.
pub const QueryParameters = struct {
    allocator: std.mem.Allocator,
    encoded_query: []u8,

    pub fn deinit(self: *QueryParameters) void {
        wipeAndFree(self.allocator, self.encoded_query);
        self.* = undefined;
    }

    pub fn encode(self: QueryParameters, allocator: std.mem.Allocator) ![]u8 {
        return allocator.dupe(u8, self.encoded_query);
    }

    pub fn appendToUrl(
        self: QueryParameters,
        allocator: std.mem.Allocator,
        base_url: []const u8,
    ) ![]u8 {
        if (std.mem.indexOfScalar(u8, base_url, '#') != null)
            return error.InvalidEndpoint;
        return std.fmt.allocPrint(
            allocator,
            "{s}{s}{s}",
            .{
                base_url,
                if (std.mem.indexOfScalar(u8, base_url, '?') == null) "?" else "&",
                self.encoded_query,
            },
        );
    }

    pub fn format(_: QueryParameters, writer: anytype) !void {
        try writer.writeAll("SASQueryParameters(***)");
    }
};

fn validateTimeRange(start: ?UtcTime, expiry: UtcTime) !void {
    var buffer: [32]u8 = undefined;
    _ = try formatTime(&buffer, expiry);
    if (start) |value| {
        _ = try formatTime(&buffer, value);
        if (value.unix_seconds >= expiry.unix_seconds)
            return error.InvalidSasTimeRange;
    }
}

fn formatTime(buffer: *[32]u8, value: UtcTime) ![]const u8 {
    const days = @divFloor(value.unix_seconds, 86_400);
    const seconds: u64 = @intCast(@mod(value.unix_seconds, 86_400));
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
    if (year < 1 or year > 9999) return error.InvalidSasTime;
    return std.fmt.bufPrint(
        buffer,
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z",
        .{
            @as(u64, @intCast(year)),
            @as(u64, @intCast(month)),
            @as(u64, @intCast(day)),
            seconds / 3600,
            (seconds / 60) % 60,
            seconds % 60,
        },
    ) catch unreachable;
}

fn addressInteger(address: IPv4Address) u32 {
    return (@as(u32, address[0]) << 24) |
        (@as(u32, address[1]) << 16) |
        (@as(u32, address[2]) << 8) |
        address[3];
}

fn validateIPRange(value: IPRange) !void {
    if (value.end) |last| {
        if (addressInteger(value.start) > addressInteger(last))
            return error.InvalidSasIPRange;
    }
}

fn parseIPv4(value: []const u8) !IPv4Address {
    var result: IPv4Address = undefined;
    var parts = std.mem.splitScalar(u8, value, '.');
    var index: usize = 0;
    while (parts.next()) |part| : (index += 1) {
        if (index == result.len or part.len == 0 or
            (part.len > 1 and part[0] == '0'))
        {
            return error.InvalidSasIPAddress;
        }
        result[index] = std.fmt.parseInt(u8, part, 10) catch
            return error.InvalidSasIPAddress;
    }
    if (index != result.len) return error.InvalidSasIPAddress;
    return result;
}

fn formatIPRange(buffer: *[31]u8, value: IPRange) []const u8 {
    if (value.end) |last| {
        return std.fmt.bufPrint(
            buffer,
            "{d}.{d}.{d}.{d}-{d}.{d}.{d}.{d}",
            .{
                value.start[0],
                value.start[1],
                value.start[2],
                value.start[3],
                last[0],
                last[1],
                last[2],
                last[3],
            },
        ) catch unreachable;
    }
    return std.fmt.bufPrint(
        buffer,
        "{d}.{d}.{d}.{d}",
        .{ value.start[0], value.start[1], value.start[2], value.start[3] },
    ) catch unreachable;
}

pub fn validateIdentifier(value: []const u8) !void {
    if (value.len == 0 or !std.unicode.utf8ValidateSlice(value))
        return error.InvalidSasIdentifier;
    if ((std.unicode.utf8CountCodepoints(value) catch unreachable) > 64)
        return error.InvalidSasIdentifier;
    for (value) |byte| {
        if (byte < 0x20 or byte == 0x7f)
            return error.InvalidSasIdentifier;
    }
}

fn appendQueryParameter(
    query: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    has_parameter: *bool,
    name: []const u8,
    value: []const u8,
) !void {
    if (has_parameter.*) try query.append(allocator, '&');
    has_parameter.* = true;
    try query.appendSlice(allocator, name);
    try query.append(allocator, '=');
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '-' or byte == '.' or
            byte == '_' or byte == '~')
        {
            try query.append(allocator, byte);
        } else {
            const hex = "0123456789ABCDEF";
            try query.append(allocator, '%');
            try query.append(allocator, hex[byte >> 4]);
            try query.append(allocator, hex[byte & 0x0f]);
        }
    }
}

test "comptime mappings emit service-required order" {
    var account_buffer: [AccountPermissions.order.len]u8 = undefined;
    try std.testing.expectEqualStrings(
        "rwdlacu",
        (AccountPermissions{
            .update = true,
            .list = true,
            .read = true,
            .create = true,
            .write = true,
            .add = true,
            .delete = true,
        }).string(&account_buffer),
    );
    var table_buffer: [TablePermissions.order.len]u8 = undefined;
    try std.testing.expectEqualStrings(
        "raud",
        (TablePermissions{
            .delete = true,
            .update = true,
            .add = true,
            .read = true,
        }).string(&table_buffer),
    );
    var resource_buffer: [AccountResourceTypes.order.len]u8 = undefined;
    try std.testing.expectEqualStrings(
        "sco",
        (AccountResourceTypes{ .object = true, .service = true, .container = true })
            .string(&resource_buffer),
    );
}

test "stored SAS identifiers count Unicode scalar values" {
    const allocator = std.testing.allocator;
    var credential = try vectorCredential(allocator);
    defer credential.deinit();

    var ascii = try (TableSignatureValues{
        .tableName = "People",
        .accessPolicy = .{ .stored = "a" ** 64 },
    }).sign(allocator, &credential, testingCrypto());
    ascii.deinit();
    var multibyte = try (TableSignatureValues{
        .tableName = "People",
        .accessPolicy = .{ .stored = "雪" ** 64 },
    }).sign(allocator, &credential, testingCrypto());
    multibyte.deinit();

    const invalid = [_][]const u8{ "a" ** 65, "雪" ** 65, "\xff" };
    for (invalid) |identifier| {
        try std.testing.expectError(
            error.InvalidSasIdentifier,
            (TableSignatureValues{
                .tableName = "People",
                .accessPolicy = .{ .stored = identifier },
            }).sign(allocator, &credential, testingCrypto()),
        );
    }
}

fn vectorCredential(allocator: std.mem.Allocator) !auth.SharedKeyCredential {
    const account_name = try allocator.dupe(u8, "fake-account");
    errdefer allocator.free(account_name);
    return .{
        .allocator = allocator,
        .account_name = account_name,
        .key = try allocator.dupe(u8, "fake-key"),
    };
}

test "Azure Go SDK table SAS vector adapted to a valid table name" {
    const allocator = std.testing.allocator;
    var credential = try vectorCredential(allocator);
    defer credential.deinit();
    var parameters = try (TableSignatureValues{
        .tableName = "faketable",
        .accessPolicy = .{ .adHoc = .{
            .permissions = .{ .read = true },
            .startTime = .fromUnixSeconds(1_699_455_845),
            .expiryTime = .fromUnixSeconds(1_699_459_445),
        } },
    }).sign(allocator, &credential, testingCrypto());
    defer parameters.deinit();
    const encoded = try parameters.encode(allocator);
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings(
        "se=2023-11-08T16%3A04%3A05Z&sig=mWBNAR0n0J%2FQdXUuG%2BkVNQHhr9tes5SB2Ihmyb9rPoM%3D&sp=r&spr=https&st=2023-11-08T15%3A04%3A05Z&sv=2019-02-02&tn=faketable",
        encoded,
    );
}

test "official account SAS canonical form and SDK ordering" {
    const allocator = std.testing.allocator;
    var credential = try vectorCredential(allocator);
    defer credential.deinit();
    var parameters = try (AccountSignatureValues{
        .permissions = .{
            .read = true,
            .write = true,
            .delete = true,
            .list = true,
            .add = true,
            .create = true,
            .update = true,
        },
        .resourceTypes = .{ .service = true, .container = true, .object = true },
        .startTime = .fromUnixSeconds(1_699_455_845),
        .expiryTime = .fromUnixSeconds(1_699_459_445),
    }).sign(allocator, &credential, testingCrypto());
    defer parameters.deinit();
    const encoded = try parameters.encode(allocator);
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings(
        "se=2023-11-08T16%3A04%3A05Z&sig=lJdjpQI2E%2FYkAkAtNipV5Ch3lCjSW8VAxZHj7xf0g0I%3D&sp=rwdlacu&spr=https&srt=sco&ss=t&st=2023-11-08T15%3A04%3A05Z&sv=2019-02-02",
        encoded,
    );
}

test "stored policy omits inline access fields and signs exact canonical values" {
    const allocator = std.testing.allocator;
    var credential = try vectorCredential(allocator);
    defer credential.deinit();
    var parameters = try (TableSignatureValues{
        .tableName = "People",
        .accessPolicy = .{ .stored = "policy & one" },
        .ipRange = try IPRange.parse("192.0.2.1", "192.0.2.20"),
        .protocol = .httpsAndHttp,
        .startPartitionKey = "A + & = 雪",
        .startRowKey = "00",
        .endPartitionKey = "Z",
        .endRowKey = "99",
    }).sign(allocator, &credential, testingCrypto());
    defer parameters.deinit();
    const encoded = try parameters.encode(allocator);
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings(
        "epk=Z&erk=99&si=policy%20%26%20one&sig=npbOLkJRhAhlx4bDjVjlPs7bAOixqDhZY6DcKvWLsgg%3D&sip=192.0.2.1-192.0.2.20&spk=A%20%2B%20%26%20%3D%20%E9%9B%AA&spr=https%2Chttp&srk=00&sv=2019-02-02&tn=people",
        encoded,
    );
}

test "partition-only bounds have exact canonical signature" {
    const allocator = std.testing.allocator;
    var credential = try vectorCredential(allocator);
    defer credential.deinit();
    var parameters = try (TableSignatureValues{
        .tableName = "People",
        .accessPolicy = .{ .stored = "policy" },
        .startPartitionKey = "A",
        .endPartitionKey = "Z",
    }).sign(allocator, &credential, testingCrypto());
    defer parameters.deinit();
    const encoded = try parameters.encode(allocator);
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings(
        "epk=Z&si=policy&sig=HXhHt66%2F1r83Zy%2FXe4rRBwpDvBbBlhr7J8jv2pGO%2BI0%3D&spk=A&spr=https&sv=2019-02-02&tn=people",
        encoded,
    );
}

test "all absent partition-only and partition-row bound combinations are valid" {
    const allocator = std.testing.allocator;
    var credential = try vectorCredential(allocator);
    defer credential.deinit();
    const Bound = struct {
        partition: ?[]const u8,
        row: ?[]const u8,
    };
    const starts = [_]Bound{
        .{ .partition = null, .row = null },
        .{ .partition = "A", .row = null },
        .{ .partition = "A", .row = "0" },
    };
    const ends = [_]Bound{
        .{ .partition = null, .row = null },
        .{ .partition = "Z", .row = null },
        .{ .partition = "Z", .row = "9" },
    };
    for (starts) |start| {
        for (ends) |end| {
            var parameters = try (TableSignatureValues{
                .tableName = "People",
                .accessPolicy = .{ .stored = "policy" },
                .startPartitionKey = start.partition,
                .startRowKey = start.row,
                .endPartitionKey = end.partition,
                .endRowKey = end.row,
            }).sign(allocator, &credential, testingCrypto());
            parameters.deinit();
        }
    }
}

test "SAS validation rejects missing fields combinations and reversed ranges" {
    const allocator = std.testing.allocator;
    var credential = try vectorCredential(allocator);
    defer credential.deinit();
    try std.testing.expectError(
        error.MissingSasPermissions,
        (AccountSignatureValues{
            .permissions = .{},
            .resourceTypes = .{ .service = true },
            .expiryTime = .fromUnixSeconds(2),
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasPermissionResourceCombination,
        (AccountSignatureValues{
            .permissions = .{ .add = true },
            .resourceTypes = .{ .service = true },
            .expiryTime = .fromUnixSeconds(2),
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.MissingSasServices,
        (AccountSignatureValues{
            .permissions = .{ .read = true },
            .services = .{},
            .resourceTypes = .{ .service = true },
            .expiryTime = .fromUnixSeconds(2),
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.MissingSasResourceTypes,
        (AccountSignatureValues{
            .permissions = .{ .read = true },
            .resourceTypes = .{},
            .expiryTime = .fromUnixSeconds(2),
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.MissingSasExpiry,
        (AccountSignatureValues{
            .permissions = .{ .read = true },
            .resourceTypes = .{ .service = true },
            .expiryTime = null,
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasPermissionResourceCombination,
        (AccountSignatureValues{
            .permissions = .{ .read = true },
            .resourceTypes = .{ .container = true },
            .expiryTime = .fromUnixSeconds(2),
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasTimeRange,
        (TableSignatureValues{
            .tableName = "People",
            .accessPolicy = .{ .adHoc = .{
                .permissions = .{ .read = true },
                .startTime = .fromUnixSeconds(2),
                .expiryTime = .fromUnixSeconds(2),
            } },
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasIdentifier,
        (TableSignatureValues{
            .tableName = "People",
            .accessPolicy = .{ .stored = "" },
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasKeyRange,
        (TableSignatureValues{
            .tableName = "People",
            .accessPolicy = .{ .stored = "policy" },
            .startPartitionKey = "z",
            .startRowKey = "0",
            .endPartitionKey = "a",
            .endRowKey = "0",
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasKeyRange,
        (TableSignatureValues{
            .tableName = "People",
            .accessPolicy = .{ .stored = "policy" },
            .endRowKey = "z",
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasKeyRange,
        (TableSignatureValues{
            .tableName = "People",
            .accessPolicy = .{ .stored = "policy" },
            .startPartitionKey = "a",
            .startRowKey = "z",
            .endPartitionKey = "a",
            .endRowKey = "a",
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasKeyRange,
        (TableSignatureValues{
            .tableName = "People",
            .accessPolicy = .{ .stored = "policy" },
            .startRowKey = "a",
        }).sign(allocator, &credential, testingCrypto()),
    );
    try std.testing.expectError(
        error.InvalidSasIPRange,
        IPRange.parse("192.0.2.20", "192.0.2.1"),
    );
    try std.testing.expectError(
        error.InvalidSasIPAddress,
        IPRange.parse("192.0.2.999", null),
    );
}

test "SAS times have exact UTC second precision and bounded year" {
    var buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings(
        "1969-12-31T23:59:59Z",
        try formatTime(&buffer, .fromUnixSeconds(-1)),
    );
    try std.testing.expectEqualStrings(
        "2023-11-08T15:04:05Z",
        try formatTime(&buffer, .fromUnixSeconds(1_699_455_845)),
    );
    try std.testing.expectError(
        error.InvalidSasTime,
        formatTime(&buffer, .fromUnixSeconds(std.math.maxInt(i64))),
    );
}

test "SAS value and query formatting redact all sensitive values" {
    const allocator = std.testing.allocator;
    var credential = try vectorCredential(allocator);
    defer credential.deinit();
    const values = TableSignatureValues{
        .tableName = "People",
        .accessPolicy = .{ .adHoc = .{
            .permissions = .{ .read = true },
            .expiryTime = .fromUnixSeconds(1_699_459_445),
        } },
    };
    var parameters = try values.sign(allocator, &credential, testingCrypto());
    defer parameters.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    try output.writer.print("{f} {f}", .{ values, parameters });
    try std.testing.expectEqualStrings(
        "TableSignatureValues(***) SASQueryParameters(***)",
        output.written(),
    );
}

fn testSasSigningAllocationFailures(allocator: std.mem.Allocator) !void {
    var credential = try auth.SharedKeyCredential.init(
        allocator,
        "fakeaccount",
        "ZmFrZS1rZXk=",
    );
    defer credential.deinit();
    var account_parameters = try (AccountSignatureValues{
        .permissions = .{ .read = true, .list = true },
        .resourceTypes = .{ .service = true, .container = true },
        .startTime = .fromUnixSeconds(1_699_455_845),
        .expiryTime = .fromUnixSeconds(1_699_459_445),
        .ipRange = try IPRange.parse("192.0.2.1", "192.0.2.20"),
    }).sign(allocator, &credential, testingCrypto());
    defer account_parameters.deinit();
    const account_url = try account_parameters.appendToUrl(
        allocator,
        "https://fakeaccount.table.core.windows.net/",
    );
    defer allocator.free(account_url);
    var parameters = try (TableSignatureValues{
        .tableName = "People",
        .accessPolicy = .{ .adHoc = .{
            .permissions = .{ .read = true },
            .startTime = .fromUnixSeconds(1_699_455_845),
            .expiryTime = .fromUnixSeconds(1_699_459_445),
        } },
        .ipRange = try IPRange.parse("192.0.2.1", "192.0.2.20"),
        .startPartitionKey = "A & B",
        .startRowKey = "0",
        .endPartitionKey = "Z",
        .endRowKey = "9",
    }).sign(allocator, &credential, testingCrypto());
    defer parameters.deinit();
    const url = try parameters.appendToUrl(
        allocator,
        "https://fakeaccount.table.core.windows.net/People",
    );
    defer allocator.free(url);
}

test "SAS signing and URL allocation failures are leak-free" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testSasSigningAllocationFailures,
        .{},
    );
}
