//! Strict Storage Table connection-string parsing.
const std = @import("std");
const auth = @import("auth.zig");
const request = @import("request.zig");

pub const development_account_name = "devstoreaccount1";
pub const development_account_key =
    "Eby8vdM02xNOcqFeqCnf2q8uFJqC0cF8wH9n+zIu4O0s=";

pub const Parsed = struct {
    allocator: std.mem.Allocator,
    endpoint: []u8,
    account_name: []u8,
    account_key: ?[]u8 = null,
    sas: ?[]u8 = null,

    pub fn deinit(self: *Parsed) void {
        self.allocator.free(self.endpoint);
        self.allocator.free(self.account_name);
        if (self.account_key) |value| self.allocator.free(value);
        if (self.sas) |value| self.allocator.free(value);
        self.* = undefined;
    }

    pub fn format(_: Parsed, writer: anytype) !void {
        try writer.writeAll("TablesConnectionString(***)");
    }
};

/// Parses account-key and SAS connection strings before any client or pipeline
/// allocation. Unknown keys, duplicates, mixed credentials, and ambiguous
/// endpoint forms are rejected.
pub fn parse(allocator: std.mem.Allocator, value: []const u8) !Parsed {
    if (std.mem.eql(u8, value, "UseDevelopmentStorage=true"))
        return development(allocator);
    if (value.len == 0) return error.InvalidConnectionString;

    var account_name: ?[]const u8 = null;
    var account_key: ?[]const u8 = null;
    var sas: ?[]const u8 = null;
    var protocol: ?[]const u8 = null;
    var suffix: ?[]const u8 = null;
    var table_endpoint: ?[]const u8 = null;
    var development_storage = false;
    var entries = std.mem.splitScalar(u8, value, ';');
    while (entries.next()) |entry| {
        if (entry.len == 0) return error.InvalidConnectionString;
        const equal = std.mem.indexOfScalar(u8, entry, '=') orelse return error.InvalidConnectionString;
        const key = std.mem.trim(u8, entry[0..equal], " \t");
        const field_value = std.mem.trim(u8, entry[equal + 1 ..], " \t");
        if (key.len == 0 or field_value.len == 0) return error.InvalidConnectionString;
        if (std.ascii.eqlIgnoreCase(key, "AccountName")) {
            if (account_name != null) return error.DuplicateConnectionStringKey;
            account_name = field_value;
        } else if (std.ascii.eqlIgnoreCase(key, "AccountKey")) {
            if (account_key != null) return error.DuplicateConnectionStringKey;
            account_key = field_value;
        } else if (std.ascii.eqlIgnoreCase(key, "SharedAccessSignature")) {
            if (sas != null) return error.DuplicateConnectionStringKey;
            sas = field_value;
        } else if (std.ascii.eqlIgnoreCase(key, "DefaultEndpointsProtocol")) {
            if (protocol != null) return error.DuplicateConnectionStringKey;
            protocol = field_value;
        } else if (std.ascii.eqlIgnoreCase(key, "EndpointSuffix")) {
            if (suffix != null) return error.DuplicateConnectionStringKey;
            suffix = field_value;
        } else if (std.ascii.eqlIgnoreCase(key, "TableEndpoint")) {
            if (table_endpoint != null) return error.DuplicateConnectionStringKey;
            table_endpoint = field_value;
        } else if (std.ascii.eqlIgnoreCase(key, "UseDevelopmentStorage")) {
            if (development_storage) return error.DuplicateConnectionStringKey;
            if (!std.ascii.eqlIgnoreCase(field_value, "true")) return error.InvalidConnectionString;
            development_storage = true;
        } else return error.UnknownConnectionStringKey;
    }
    if (development_storage) return error.InvalidConnectionString;
    if (account_name == null or (account_key == null and sas == null) or
        (account_key != null and sas != null))
        return error.InvalidConnectionString;
    try auth.validateAccountName(account_name.?);
    if (account_key) |key| {
        const decoded = @import("azure_sdk_core").base64.decode(allocator, key) catch
            return error.InvalidAccountKey;
        defer allocator.free(decoded);
        if (decoded.len == 0) return error.InvalidAccountKey;
    }
    if (table_endpoint != null and (protocol != null or suffix != null))
        return error.AmbiguousConnectionStringEndpoint;

    const endpoint = if (table_endpoint) |explicit|
        try allocator.dupe(u8, explicit)
    else blk: {
        const scheme = protocol orelse "https";
        if (!std.ascii.eqlIgnoreCase(scheme, "https") and !std.ascii.eqlIgnoreCase(scheme, "http"))
            return error.InvalidEndpointScheme;
        const endpoint_suffix = suffix orelse "core.windows.net";
        if (std.mem.indexOfAny(u8, endpoint_suffix, "/?#@") != null) return error.InvalidEndpoint;
        break :blk try std.fmt.allocPrint(
            allocator,
            "{s}://{s}.table.{s}",
            .{ scheme, account_name.?, endpoint_suffix },
        );
    };
    errdefer allocator.free(endpoint);
    if (std.mem.indexOfScalar(u8, endpoint, '?') != null)
        return error.InvalidConnectionString;
    if (sas) |token| {
        const raw = if (token[0] == '?') token[1..] else token;
        if (raw.len == 0) return error.InvalidConnectionString;
        const complete = try std.fmt.allocPrint(allocator, "{s}?{s}", .{ endpoint, raw });
        errdefer allocator.free(complete);
        const owned_account_name = try allocator.dupe(u8, account_name.?);
        errdefer allocator.free(owned_account_name);
        const owned_sas = try allocator.dupe(u8, raw);
        allocator.free(endpoint);
        return .{
            .allocator = allocator,
            .endpoint = complete,
            .account_name = owned_account_name,
            .sas = owned_sas,
        };
    }
    const owned_account_name = try allocator.dupe(u8, account_name.?);
    errdefer allocator.free(owned_account_name);
    const owned_key = try allocator.dupe(u8, account_key.?);
    return .{
        .allocator = allocator,
        .endpoint = endpoint,
        .account_name = owned_account_name,
        .account_key = owned_key,
    };
}

fn development(allocator: std.mem.Allocator) !Parsed {
    return .{
        .allocator = allocator,
        .endpoint = try allocator.dupe(u8, "http://127.0.0.1:10002/devstoreaccount1"),
        .account_name = try allocator.dupe(u8, development_account_name),
        .account_key = try allocator.dupe(u8, development_account_key),
    };
}

test "parse Azure custom SAS and Azurite connection strings" {
    const allocator = std.testing.allocator;
    var azure = try parse(allocator, "DefaultEndpointsProtocol=https;AccountName=account;AccountKey=YQ==;EndpointSuffix=core.windows.net");
    defer azure.deinit();
    try std.testing.expectEqualStrings("https://account.table.core.windows.net", azure.endpoint);
    var custom = try parse(allocator, "AccountName=account;SharedAccessSignature=sv=1%2F2&sig=a+b%3D;TableEndpoint=https://tables.example.test/root");
    defer custom.deinit();
    try std.testing.expectEqualStrings("https://tables.example.test/root?sv=1%2F2&sig=a+b%3D", custom.endpoint);
    var azurite = try parse(allocator, "UseDevelopmentStorage=true");
    defer azurite.deinit();
    try std.testing.expectEqualStrings("http://127.0.0.1:10002/devstoreaccount1", azurite.endpoint);
}

test "connection strings reject malformed secret and endpoint combinations" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidAccountKey, parse(allocator, "AccountName=account;AccountKey=not base64!"));
    try std.testing.expectError(error.DuplicateConnectionStringKey, parse(allocator, "AccountName=account;AccountName=other;AccountKey=YQ=="));
    try std.testing.expectError(error.UnknownConnectionStringKey, parse(allocator, "AccountName=account;AccountKey=YQ==;BlobEndpoint=x"));
    try std.testing.expectError(error.AmbiguousConnectionStringEndpoint, parse(allocator, "AccountName=account;AccountKey=YQ==;TableEndpoint=https://x;EndpointSuffix=example.test"));
}
