//! Validated service-administration models backed by generated XML wire types.

const std = @import("std");
const protocol = @import("azure_rest_data_tables");

pub const ServiceProperties = protocol.models.TableServiceProperties;
pub const Logging = protocol.models.Logging;
pub const Metrics = protocol.models.Metrics;
pub const RetentionPolicy = protocol.models.RetentionPolicy;
pub const CorsRule = protocol.models.CorsRule;
pub const ServiceStatistics = protocol.models.TableServiceStats;
pub const GeoReplication = protocol.models.GeoReplication;
pub const GeoReplicationStatus = protocol.enums.GeoReplicationStatusType;

/// A parsed `LastSyncTime` from a geo-replication response. An empty element
/// is an explicit, documented unavailable value rather than an invalid date.
pub const LastSyncTime = union(enum) {
    unavailable,
    rfc7231: []const u8,

    pub fn parse(value: []const u8) !LastSyncTime {
        if (value.len == 0) return .unavailable;
        try validateRfc7231Time(value);
        return .{ .rfc7231 = value };
    }
};

/// Serializes the generated service-property model while honoring the
/// 2019-02-02 partial-update semantics. The generated XML serializer writes
/// `null` optionals as empty nodes, so this adapter only overrides that
/// optional-node behavior; the operation, DTOs, and response parsing remain
/// generated.
pub fn serializeServicePropertiesXml(
    allocator: std.mem.Allocator,
    properties: ServiceProperties,
) ![]u8 {
    try validateServiceProperties(properties);
    var xml: std.ArrayList(u8) = .empty;
    errdefer xml.deinit(allocator);
    try xml.appendSlice(allocator, "<?xml version=\"1.0\" encoding=\"UTF-8\"?><StorageServiceProperties>");
    if (properties.logging) |logging| try appendLogging(&xml, allocator, logging);
    if (properties.hour_metrics) |metrics| try appendMetrics(&xml, allocator, "HourMetrics", metrics);
    if (properties.minute_metrics) |metrics| try appendMetrics(&xml, allocator, "MinuteMetrics", metrics);
    if (properties.cors) |cors| {
        if (cors.items.len == 0) {
            try xml.appendSlice(allocator, "<Cors/>");
        } else {
            try openTag(&xml, allocator, "Cors");
            for (cors.items) |rule| try appendCorsRule(&xml, allocator, rule);
            try closeTag(&xml, allocator, "Cors");
        }
    }
    try xml.appendSlice(allocator, "</StorageServiceProperties>");
    return xml.toOwnedSlice(allocator);
}

/// Validates service limits before serializing the generated XML model.
pub fn validateServiceProperties(properties: ServiceProperties) !void {
    if (properties.logging == null and properties.hour_metrics == null and
        properties.minute_metrics == null and properties.cors == null)
    {
        return error.MissingServiceProperties;
    }
    if (properties.logging) |logging| try validateLogging(logging);
    if (properties.hour_metrics) |metrics| try validateMetrics(metrics);
    if (properties.minute_metrics) |metrics| try validateMetrics(metrics);
    if (properties.cors) |cors| {
        if (cors.items.len > 5) return error.TooManyCorsRules;
        var limits = CorsLimits{};
        for (cors.items) |rule| try validateCorsRule(rule, &limits);
        if (limits.setting_bytes > 2048 or
            limits.allowed_literals + limits.exposed_literals > 64 or
            limits.allowed_prefixes + limits.exposed_prefixes > 2)
        {
            return error.InvalidCorsRule;
        }
    }
}

pub fn validateServiceStatistics(statistics: ServiceStatistics) !void {
    if (statistics.geo_replication) |replication| {
        if (replication.last_sync_time) |last_sync_time| _ = try LastSyncTime.parse(last_sync_time);
    }
}

fn validateLogging(logging: Logging) !void {
    if (!std.mem.eql(u8, logging.version, "1.0")) return error.InvalidAnalyticsVersion;
    try validateRetentionPolicy(logging.retention_policy);
}

fn validateMetrics(metrics: Metrics) !void {
    const version = metrics.version orelse return error.MissingMetricsVersion;
    if (!std.mem.eql(u8, version, "1.0")) return error.InvalidAnalyticsVersion;
    const retention = metrics.retention_policy orelse return error.MissingMetricsRetentionPolicy;
    try validateRetentionPolicy(retention);
    if (metrics.enabled) {
        if (metrics.include_apis == null) return error.MissingIncludeApis;
    }
}

fn validateRetentionPolicy(retention: RetentionPolicy) !void {
    if (retention.days) |days| {
        if (days < 1 or days > 365) return error.InvalidRetentionDays;
    } else if (retention.enabled) return error.MissingRetentionDays;
}

const CorsLimits = struct {
    setting_bytes: usize = 0,
    allowed_literals: usize = 0,
    exposed_literals: usize = 0,
    allowed_prefixes: usize = 0,
    exposed_prefixes: usize = 0,
};

fn validateCorsRule(rule: CorsRule, limits: *CorsLimits) !void {
    if (rule.allowed_origins.len == 0 or rule.allowed_methods.len == 0 or
        rule.allowed_headers.len == 0 or rule.exposed_headers.len == 0)
    {
        return error.InvalidCorsRule;
    }
    const origin_count = try validateCommaDelimited(rule.allowed_origins, true);
    if (origin_count > 64) return error.InvalidCorsRule;
    const allowed = try validateHeaders(rule.allowed_headers);
    const exposed = try validateHeaders(rule.exposed_headers);
    limits.allowed_literals += allowed.literals;
    limits.exposed_literals += exposed.literals;
    limits.allowed_prefixes += allowed.prefixes;
    limits.exposed_prefixes += exposed.prefixes;
    limits.setting_bytes += rule.allowed_origins.len + rule.allowed_methods.len +
        rule.allowed_headers.len + rule.exposed_headers.len + decimalLength(rule.max_age_in_seconds);
    if (rule.max_age_in_seconds < 0)
        return error.InvalidCorsMaxAge;

    var methods = std.mem.splitScalar(u8, rule.allowed_methods, ',');
    var count: usize = 0;
    while (methods.next()) |method| {
        if (method.len == 0 or !isAllowedMethod(method)) return error.InvalidCorsMethod;
        count += 1;
    }
    if (count == 0 or count > 7) return error.InvalidCorsMethod;
}

fn validateCommaDelimited(value: []const u8, enforce_value_length: bool) !usize {
    var values = std.mem.splitScalar(u8, value, ',');
    var count: usize = 0;
    while (values.next()) |part| {
        if (part.len == 0 or (enforce_value_length and part.len > 256))
            return error.InvalidCorsRule;
        count += 1;
    }
    return count;
}

const HeaderCounts = struct {
    literals: usize = 0,
    prefixes: usize = 0,
};

fn validateHeaders(value: []const u8) !HeaderCounts {
    var values = std.mem.splitScalar(u8, value, ',');
    var counts = HeaderCounts{};
    while (values.next()) |header| {
        if (header.len == 0 or header.len > 256) return error.InvalidCorsRule;
        if (std.mem.indexOfScalar(u8, header, '*') != null) {
            if (header[header.len - 1] != '*' or std.mem.indexOfScalar(u8, header[0 .. header.len - 1], '*') != null)
                return error.InvalidCorsRule;
            counts.prefixes += 1;
        } else {
            counts.literals += 1;
        }
    }
    return counts;
}

fn decimalLength(value: i32) usize {
    if (value < 0) return 1;
    var remaining: u32 = @intCast(value);
    var length: usize = 1;
    while (remaining >= 10) : (remaining /= 10) length += 1;
    return length;
}

fn isAllowedMethod(method: []const u8) bool {
    const allowed = [_][]const u8{ "DELETE", "GET", "HEAD", "MERGE", "OPTIONS", "POST", "PUT" };
    for (allowed) |candidate| {
        if (std.mem.eql(u8, method, candidate)) return true;
    }
    return false;
}

fn daysInMonth(year: i32, month: u8) u8 {
    return switch (month) {
        2 => if (isLeapYear(year)) 29 else 28,
        4, 6, 9, 11 => 30,
        else => 31,
    };
}

fn isLeapYear(year: i32) bool {
    return @mod(year, 4) == 0 and (@mod(year, 100) != 0 or @mod(year, 400) == 0);
}

fn appendLogging(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, logging: Logging) !void {
    try openTag(xml, allocator, "Logging");
    try appendElement(xml, allocator, "Version", logging.version);
    try appendBoolElement(xml, allocator, "Delete", logging.delete);
    try appendBoolElement(xml, allocator, "Read", logging.read);
    try appendBoolElement(xml, allocator, "Write", logging.write);
    try appendRetentionPolicy(xml, allocator, logging.retention_policy);
    try closeTag(xml, allocator, "Logging");
}

fn appendMetrics(
    xml: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    comptime root: []const u8,
    metrics: Metrics,
) !void {
    try openTag(xml, allocator, root);
    const version = metrics.version orelse return error.MissingMetricsVersion;
    const retention = metrics.retention_policy orelse return error.MissingMetricsRetentionPolicy;
    try appendElement(xml, allocator, "Version", version);
    try appendBoolElement(xml, allocator, "Enabled", metrics.enabled);
    if (metrics.enabled) {
        if (metrics.include_apis) |include_apis|
            try appendBoolElement(xml, allocator, "IncludeAPIs", include_apis);
    }
    try appendRetentionPolicy(xml, allocator, retention);
    try closeTag(xml, allocator, root);
}

fn appendRetentionPolicy(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, retention: RetentionPolicy) !void {
    try openTag(xml, allocator, "RetentionPolicy");
    try appendBoolElement(xml, allocator, "Enabled", retention.enabled);
    if (retention.days) |days| try appendIntegerElement(xml, allocator, "Days", days);
    try closeTag(xml, allocator, "RetentionPolicy");
}

fn appendCorsRule(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, rule: CorsRule) !void {
    try openTag(xml, allocator, "CorsRule");
    try appendElement(xml, allocator, "AllowedOrigins", rule.allowed_origins);
    try appendElement(xml, allocator, "AllowedMethods", rule.allowed_methods);
    try appendElement(xml, allocator, "AllowedHeaders", rule.allowed_headers);
    try appendElement(xml, allocator, "ExposedHeaders", rule.exposed_headers);
    try appendIntegerElement(xml, allocator, "MaxAgeInSeconds", rule.max_age_in_seconds);
    try closeTag(xml, allocator, "CorsRule");
}

fn appendBoolElement(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime name: []const u8, value: bool) !void {
    try appendElement(xml, allocator, name, if (value) "true" else "false");
}

fn appendIntegerElement(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime name: []const u8, value: i32) !void {
    try openTag(xml, allocator, name);
    try xml.print(allocator, "{d}", .{value});
    try closeTag(xml, allocator, name);
}

fn appendElement(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime name: []const u8, value: []const u8) !void {
    try openTag(xml, allocator, name);
    try appendXmlEscaped(xml, allocator, value);
    try closeTag(xml, allocator, name);
}

fn openTag(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime name: []const u8) !void {
    try xml.append(allocator, '<');
    try xml.appendSlice(allocator, name);
    try xml.append(allocator, '>');
}

fn closeTag(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, comptime name: []const u8) !void {
    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, name);
    try xml.append(allocator, '>');
}

fn appendXmlEscaped(xml: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    for (value) |byte| switch (byte) {
        '&' => try xml.appendSlice(allocator, "&amp;"),
        '<' => try xml.appendSlice(allocator, "&lt;"),
        '>' => try xml.appendSlice(allocator, "&gt;"),
        '"' => try xml.appendSlice(allocator, "&quot;"),
        '\'' => try xml.appendSlice(allocator, "&apos;"),
        else => try xml.append(allocator, byte),
    };
}

fn validateRfc7231Time(value: []const u8) !void {
    if (try validateImfFixdate(value)) return;
    if (try validateRfc850Date(value)) return;
    if (try validateAsctimeDate(value)) return;
    return error.InvalidLastSyncTime;
}

fn validateImfFixdate(value: []const u8) !bool {
    if (value.len != 29 or !isWeekday(value[0..3]) or !std.mem.eql(u8, value[3..5], ", ") or
        value[7] != ' ' or value[11] != ' ' or value[16] != ' ' or value[19] != ':' or
        value[22] != ':' or !std.mem.eql(u8, value[26..29], "GMT"))
    {
        return false;
    }
    try validateDateTime(value[5..7], value[8..11], value[12..16], value[17..25]);
    return true;
}

fn validateRfc850Date(value: []const u8) !bool {
    const comma = std.mem.indexOf(u8, value, ", ") orelse return false;
    if (!isLongWeekday(value[0..comma])) return false;
    const rest = value[comma + 2 ..];
    if (rest.len != 22 or rest[2] != '-' or rest[6] != '-' or rest[9] != ' ' or
        rest[12] != ':' or rest[15] != ':' or rest[18] != ' ' or !std.mem.eql(u8, rest[19..22], "GMT"))
    {
        return false;
    }
    const short_year = try parseDecimal(rest[7..9]);
    try validateDateTime(rest[0..2], rest[3..6], 2000 + short_year, rest[10..18]);
    return true;
}

fn validateAsctimeDate(value: []const u8) !bool {
    if (value.len != 24 or !isWeekday(value[0..3]) or value[3] != ' ' or value[7] != ' ' or
        value[10] != ' ' or value[13] != ':' or value[16] != ':' or value[19] != ' ')
    {
        return false;
    }
    const day = if (value[8] == ' ') value[9..10] else value[8..10];
    try validateDateTime(day, value[4..7], value[20..24], value[11..19]);
    return true;
}

fn validateDateTime(day_text: []const u8, month_text: []const u8, year_text: anytype, time_text: []const u8) !void {
    const day = try parseDecimal(day_text);
    const month = parseMonth(month_text) orelse return error.InvalidLastSyncTime;
    const year: i32 = switch (@TypeOf(year_text)) {
        i32 => year_text,
        else => try parseDecimal(year_text),
    };
    const hour = try parseDecimal(time_text[0..2]);
    const minute = try parseDecimal(time_text[3..5]);
    const second = try parseDecimal(time_text[6..8]);
    if (day == 0 or day > daysInMonth(year, month) or hour > 23 or minute > 59 or second > 59)
        return error.InvalidLastSyncTime;
}

fn parseDecimal(value: []const u8) !i32 {
    if (value.len == 0) return error.InvalidLastSyncTime;
    for (value) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidLastSyncTime;
    return std.fmt.parseInt(i32, value, 10) catch error.InvalidLastSyncTime;
}

fn parseMonth(value: []const u8) ?u8 {
    const months = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    for (months, 1..) |month, index| {
        if (std.mem.eql(u8, value, month)) return @intCast(index);
    }
    return null;
}

fn isWeekday(value: []const u8) bool {
    const days = [_][]const u8{ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };
    for (days) |day| if (std.mem.eql(u8, value, day)) return true;
    return false;
}

fn isLongWeekday(value: []const u8) bool {
    const days = [_][]const u8{ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" };
    for (days) |day| if (std.mem.eql(u8, value, day)) return true;
    return false;
}

test "service property validation enforces retention, metrics, and CORS boundaries" {
    const retention = RetentionPolicy{ .enabled = true, .days = 1 };
    try validateServiceProperties(.{
        .hour_metrics = .{ .version = "1.0", .enabled = true, .include_apis = true, .retention_policy = retention },
        .minute_metrics = .{ .version = "1.0", .enabled = false, .retention_policy = .{ .enabled = false } },
        .cors = .{ .items = &.{.{
            .allowed_origins = "https://example.test",
            .allowed_methods = "GET,PUT",
            .allowed_headers = "x-ms-meta-*",
            .exposed_headers = "x-ms-request-id",
            .max_age_in_seconds = 86_400,
        }} },
    });
    try std.testing.expectError(error.InvalidRetentionDays, validateServiceProperties(.{
        .hour_metrics = .{ .version = "1.0", .enabled = true, .include_apis = true, .retention_policy = .{ .enabled = true, .days = 366 } },
    }));
    try validateServiceProperties(.{
        .minute_metrics = .{ .version = "1.0", .enabled = false, .retention_policy = .{ .enabled = false, .days = 1 } },
    });
    try std.testing.expectError(error.MissingIncludeApis, validateServiceProperties(.{
        .minute_metrics = .{ .version = "1.0", .enabled = true, .retention_policy = .{ .enabled = false } },
    }));
    try std.testing.expectError(error.MissingMetricsRetentionPolicy, validateServiceProperties(.{
        .minute_metrics = .{ .version = "1.0", .enabled = true, .include_apis = false },
    }));
    try validateServiceProperties(.{
        .minute_metrics = .{ .version = "1.0", .enabled = false, .include_apis = false, .retention_policy = .{ .enabled = false } },
    });
    try std.testing.expectError(error.InvalidRetentionDays, validateServiceProperties(.{
        .minute_metrics = .{ .version = "1.0", .enabled = false, .retention_policy = .{ .enabled = false, .days = 0 } },
    }));
    try validateServiceProperties(.{
        .cors = .{ .items = &.{.{
            .allowed_origins = "*",
            .allowed_methods = "GET",
            .allowed_headers = "*",
            .exposed_headers = "*",
            .max_age_in_seconds = std.math.maxInt(i32),
        }} },
    });
}

test "CORS validation uses request-wide and per-value Storage limits" {
    var too_long: [257]u8 = undefined;
    @memset(&too_long, 'a');
    try std.testing.expectError(error.InvalidCorsRule, validateServiceProperties(.{
        .cors = .{ .items = &.{.{
            .allowed_origins = too_long[0..],
            .allowed_methods = "GET",
            .allowed_headers = "*",
            .exposed_headers = "*",
            .max_age_in_seconds = 0,
        }} },
    }));
    try std.testing.expectError(error.InvalidCorsRule, validateServiceProperties(.{
        .cors = .{ .items = &.{.{
            .allowed_origins = "*",
            .allowed_methods = "GET",
            .allowed_headers = "x-a*,x-b*",
            .exposed_headers = "x-c*",
            .max_age_in_seconds = 0,
        }} },
    }));

    var setting: [256]u8 = undefined;
    @memset(&setting, 'a');
    const large_rule = CorsRule{
        .allowed_origins = setting[0..],
        .allowed_methods = "GET",
        .allowed_headers = setting[0..],
        .exposed_headers = setting[0..],
        .max_age_in_seconds = 0,
    };
    try std.testing.expectError(error.InvalidCorsRule, validateServiceProperties(.{
        .cors = .{ .items = &.{ large_rule, large_rule, large_rule } },
    }));
}

test "service-property XML omits absent roots and keeps empty CORS explicit" {
    const allocator = std.testing.allocator;
    const partial = try serializeServicePropertiesXml(allocator, .{
        .logging = .{
            .version = "1.0",
            .delete = true,
            .read = false,
            .write = true,
            .retention_policy = .{ .enabled = false },
        },
    });
    defer allocator.free(partial);
    try std.testing.expectEqualStrings(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><StorageServiceProperties><Logging><Version>1.0</Version><Delete>true</Delete><Read>false</Read><Write>true</Write><RetentionPolicy><Enabled>false</Enabled></RetentionPolicy></Logging></StorageServiceProperties>",
        partial,
    );
    const clear_cors = try serializeServicePropertiesXml(allocator, .{ .cors = .{} });
    defer allocator.free(clear_cors);
    try std.testing.expectEqualStrings(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><StorageServiceProperties><Cors/></StorageServiceProperties>",
        clear_cors,
    );

    const disabled_metrics = try serializeServicePropertiesXml(allocator, .{
        .hour_metrics = .{
            .version = "1.0",
            .enabled = false,
            .include_apis = false,
            .retention_policy = .{ .enabled = false, .days = 7 },
        },
    });
    defer allocator.free(disabled_metrics);
    try std.testing.expectEqualStrings(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><StorageServiceProperties><HourMetrics><Version>1.0</Version><Enabled>false</Enabled><RetentionPolicy><Enabled>false</Enabled><Days>7</Days></RetentionPolicy></HourMetrics></StorageServiceProperties>",
        disabled_metrics,
    );
}

test "public service property serializer rejects incomplete metrics instead of panicking" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.MissingMetricsVersion, serializeServicePropertiesXml(allocator, .{
        .hour_metrics = .{ .enabled = false, .retention_policy = .{ .enabled = false } },
    }));
    try std.testing.expectError(error.MissingMetricsRetentionPolicy, serializeServicePropertiesXml(allocator, .{
        .hour_metrics = .{ .version = "1.0", .enabled = false },
    }));
    try std.testing.expectError(error.MissingIncludeApis, serializeServicePropertiesXml(allocator, .{
        .hour_metrics = .{ .version = "1.0", .enabled = true, .retention_policy = .{ .enabled = false } },
    }));
}

test "geo-replication last sync time is RFC 7231 and supports unavailable values" {
    const imf = try LastSyncTime.parse("Wed, 23 Oct 2013 22:05:54 GMT");
    try std.testing.expectEqualStrings("Wed, 23 Oct 2013 22:05:54 GMT", imf.rfc7231);
    try std.testing.expectEqual(LastSyncTime.unavailable, try LastSyncTime.parse(""));
    _ = try LastSyncTime.parse("Sunday, 06-Nov-94 08:49:37 GMT");
    _ = try LastSyncTime.parse("Sun Nov  6 08:49:37 1994");
    try std.testing.expectError(error.InvalidLastSyncTime, LastSyncTime.parse("2026-07-26T18:32:16Z"));

    const unknown = try GeoReplicationStatus.fromWire(std.testing.allocator, "future-state");
    defer switch (unknown) {
        .unrecognized => |value| std.testing.allocator.free(value),
        else => {},
    };
    try std.testing.expectEqualStrings("future-state", unknown.toWire());
}
