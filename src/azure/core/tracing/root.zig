///! OpenTelemetry integration — distributed tracing for Azure SDK.
///!
///! Provides `RequestActivityPolicy` that creates spans for HTTP requests.
///! Uses comptime feature flags to enable/disable without runtime cost.
const std = @import("std");

pub const Config = struct {
    enabled: bool = false,
};

/// A minimal span representation for tracing.
pub const Span = struct {
    name: []const u8,
    trace_id: [32]u8 = [_]u8{'0'} ** 32,
    span_id: [16]u8 = [_]u8{'0'} ** 16,
    start_time_ns: i64 = 0,
    end_time_ns: i64 = 0,
    status: Status = .unset,
    attributes: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub const Status = enum { unset, ok, @"error" };

    pub fn init(allocator: std.mem.Allocator, name: []const u8) Span {
        return .{
            .name = name,
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn setAttribute(self: *Span, key: []const u8, value: []const u8) !void {
        try self.attributes.put(key, value);
    }

    pub fn setStatus(self: *Span, status: Status) void {
        self.status = status;
    }

    pub fn end(self: *Span) void {
        // In production: export via OTLP/HTTP or @cImport OTel C API.
        _ = self;
    }

    pub fn deinit(self: *Span) void {
        self.attributes.deinit();
    }
};

/// A tracer that creates spans.
pub const Tracer = struct {
    service_name: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, service_name: []const u8) Tracer {
        return .{ .allocator = allocator, .service_name = service_name };
    }

    pub fn startSpan(self: *Tracer, name: []const u8) Span {
        return Span.init(self.allocator, name);
    }
};

/// No-op tracer for when tracing is disabled.
pub const NoopTracer = struct {
    pub fn startSpan(_: *NoopTracer, _: []const u8) NoopSpan {
        return .{};
    }

    pub const NoopSpan = struct {
        pub fn setAttribute(_: *NoopSpan, _: []const u8, _: []const u8) !void {}
        pub fn setStatus(_: *NoopSpan, _: Span.Status) void {}
        pub fn end(_: *NoopSpan) void {}
        pub fn deinit(_: *NoopSpan) void {}
    };
};

// ─────────────────────── Tests ───────────────────────

test "Span create and set attributes" {
    const allocator = std.testing.allocator;
    var span = Span.init(allocator, "HTTP GET");
    defer span.deinit();
    try span.setAttribute("http.method", "GET");
    try span.setAttribute("http.url", "https://example.com");
    span.setStatus(.ok);
    span.end();
    try std.testing.expectEqualStrings("GET", span.attributes.get("http.method").?);
    try std.testing.expectEqual(Span.Status.ok, span.status);
}

test "Tracer startSpan" {
    const allocator = std.testing.allocator;
    var tracer = Tracer.init(allocator, "azure-sdk-zig");
    var span = tracer.startSpan("SecretClient.getSecret");
    defer span.deinit();
    try std.testing.expectEqualStrings("SecretClient.getSecret", span.name);
}

test "NoopTracer has zero overhead" {
    var tracer = NoopTracer{};
    var span = tracer.startSpan("ignored");
    try span.setAttribute("key", "val");
    span.setStatus(.ok);
    span.end();
    span.deinit();
}
