///! OpenTelemetry-compatible distributed tracing for Azure SDK.
///!
///! Provides pluggable `TracerProvider` / `Tracer` / `Span` interfaces
///! following the fn-pointer pattern used throughout the SDK. A
///! `NoopTracerProvider` is the default — zero overhead when tracing
///! is disabled. W3C Trace Context propagation is built in.
const std = @import("std");

// ─────────────────── Enums ───────────────────────

pub const SpanKind = enum {
    client,
    server,
    producer,
    consumer,
    internal,
};

pub const SpanStatus = enum {
    unset,
    ok,
    @"error",
};

// ─────────────────── Span Interface ──────────────

/// A unit of work in a trace.
pub const Span = struct {
    setAttributeFn: *const fn (self: *Span, key: []const u8, value: []const u8) anyerror!void,
    setStatusFn: *const fn (self: *Span, status: SpanStatus) void,
    endFn: *const fn (self: *Span) void,

    pub fn setAttribute(self: *Span, key: []const u8, value: []const u8) !void {
        return self.setAttributeFn(self, key, value);
    }

    pub fn setStatus(self: *Span, status: SpanStatus) void {
        self.setStatusFn(self, status);
    }

    pub fn end(self: *Span) void {
        self.endFn(self);
    }
};

/// A tracer that creates spans for a specific service.
pub const Tracer = struct {
    startSpanFn: *const fn (self: *Tracer, name: []const u8, kind: SpanKind) anyerror!*Span,

    pub fn startSpan(self: *Tracer, name: []const u8, kind: SpanKind) !*Span {
        return self.startSpanFn(self, name, kind);
    }
};

/// Factory for creating service-specific tracers.
pub const TracerProvider = struct {
    getTracerFn: *const fn (self: *TracerProvider, name: []const u8, version: []const u8) *Tracer,

    pub fn getTracer(self: *TracerProvider, name: []const u8, version: []const u8) *Tracer {
        return self.getTracerFn(self, name, version);
    }
};

// ─────────────── Noop Implementation ─────────────

/// Zero-cost tracer provider for when tracing is disabled (default).
pub const NoopTracerProvider = struct {
    tracer: NoopTracer = NoopTracer.init(),
    provider: TracerProvider,

    pub fn init() NoopTracerProvider {
        return .{
            .provider = .{ .getTracerFn = &getTracerImpl },
        };
    }

    pub fn asProvider(self: *NoopTracerProvider) *TracerProvider {
        return &self.provider;
    }

    fn getTracerImpl(p: *TracerProvider, name: []const u8, version: []const u8) *Tracer {
        _ = name;
        _ = version;
        const self: *NoopTracerProvider = @fieldParentPtr("provider", p);
        return &self.tracer.tracer;
    }
};

pub const NoopTracer = struct {
    span: NoopSpan = NoopSpan.init(),
    tracer: Tracer,

    pub fn init() NoopTracer {
        return .{
            .tracer = .{ .startSpanFn = &startSpanImpl },
        };
    }

    fn startSpanImpl(t: *Tracer, name: []const u8, kind: SpanKind) !*Span {
        _ = name;
        _ = kind;
        const self: *NoopTracer = @fieldParentPtr("tracer", t);
        return &self.span.span;
    }
};

pub const NoopSpan = struct {
    span: Span,

    pub fn init() NoopSpan {
        return .{
            .span = .{
                .setAttributeFn = &setAttributeImpl,
                .setStatusFn = &setStatusImpl,
                .endFn = &endImpl,
            },
        };
    }

    fn setAttributeImpl(s: *Span, key: []const u8, value: []const u8) !void {
        _ = s;
        _ = key;
        _ = value;
    }

    fn setStatusImpl(s: *Span, status: SpanStatus) void {
        _ = s;
        _ = status;
    }

    fn endImpl(s: *Span) void {
        _ = s;
    }
};

// ─────────────── Recording Implementation ────────

/// A span that records attributes and status for testing / export.
pub const RecordingSpan = struct {
    name: []const u8,
    kind: SpanKind,
    status: SpanStatus = .unset,
    attributes: std.StringHashMap([]const u8),
    ended: bool = false,
    span: Span,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, kind: SpanKind) RecordingSpan {
        return .{
            .name = name,
            .kind = kind,
            .attributes = std.StringHashMap([]const u8).init(allocator),
            .span = .{
                .setAttributeFn = &setAttributeImpl,
                .setStatusFn = &setStatusImpl,
                .endFn = &endImpl,
            },
        };
    }

    pub fn asSpan(self: *RecordingSpan) *Span {
        return &self.span;
    }

    pub fn deinit(self: *RecordingSpan) void {
        self.attributes.deinit();
    }

    fn setAttributeImpl(s: *Span, key: []const u8, value: []const u8) !void {
        const self: *RecordingSpan = @fieldParentPtr("span", s);
        try self.attributes.put(key, value);
    }

    fn setStatusImpl(s: *Span, status: SpanStatus) void {
        const self: *RecordingSpan = @fieldParentPtr("span", s);
        self.status = status;
    }

    fn endImpl(s: *Span) void {
        const self: *RecordingSpan = @fieldParentPtr("span", s);
        self.ended = true;
    }
};

/// A tracer that creates RecordingSpans — useful for tests.
pub const RecordingTracer = struct {
    allocator: std.mem.Allocator,
    last_span: ?RecordingSpan = null,
    tracer: Tracer,

    pub fn init(allocator: std.mem.Allocator) RecordingTracer {
        return .{
            .allocator = allocator,
            .tracer = .{ .startSpanFn = &startSpanImpl },
        };
    }

    pub fn asTracer(self: *RecordingTracer) *Tracer {
        return &self.tracer;
    }

    pub fn deinit(self: *RecordingTracer) void {
        if (self.last_span) |*s| s.deinit();
    }

    fn startSpanImpl(t: *Tracer, name: []const u8, kind: SpanKind) !*Span {
        const self: *RecordingTracer = @fieldParentPtr("tracer", t);
        if (self.last_span) |*s| s.deinit();
        self.last_span = RecordingSpan.init(self.allocator, name, kind);
        return &self.last_span.?.span;
    }
};

// ─────────────── W3C Trace Context ───────────────

/// W3C Trace Context for distributed trace propagation.
pub const TraceContext = struct {
    trace_id: [32]u8 = [_]u8{'0'} ** 32,
    span_id: [16]u8 = [_]u8{'0'} ** 16,
    trace_flags: u8 = 0,
    trace_state: ?[]const u8 = null,

    /// Format as W3C traceparent header: `00-{trace_id}-{span_id}-{flags}`
    pub fn formatTraceparent(self: TraceContext) [55]u8 {
        var buf: [55]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "00-{s}-{s}-{s}", .{
            &self.trace_id,
            &self.span_id,
            std.fmt.bytesToHex([_]u8{self.trace_flags}, .lower),
        }) catch unreachable;
        return buf;
    }

    /// Parse a W3C traceparent header value.
    pub fn parseTraceparent(header: []const u8) ?TraceContext {
        // Format: 00-{32 hex trace_id}-{16 hex span_id}-{2 hex flags}
        if (header.len < 55) return null;
        if (header[0] != '0' or header[1] != '0' or header[2] != '-') return null;
        if (header[35] != '-' or header[52] != '-') return null;

        var ctx = TraceContext{};
        @memcpy(&ctx.trace_id, header[3..35]);
        @memcpy(&ctx.span_id, header[36..52]);
        ctx.trace_flags = std.fmt.parseUnsigned(u8, header[53..55], 16) catch return null;
        return ctx;
    }
};

// ─────────────────────── Tests ───────────────────────

test "NoopTracerProvider creates noop spans" {
    var provider = NoopTracerProvider.init();
    const tracer = provider.asProvider().getTracer("test", "0.1.0");
    const span = try tracer.startSpan("op", .client);
    try span.setAttribute("key", "val");
    span.setStatus(.ok);
    span.end();
}

test "RecordingSpan captures attributes and status" {
    const allocator = std.testing.allocator;
    var span = RecordingSpan.init(allocator, "HTTP GET", .client);
    defer span.deinit();
    try span.asSpan().setAttribute("http.method", "GET");
    span.asSpan().setStatus(.ok);
    span.asSpan().end();
    try std.testing.expectEqualStrings("GET", span.attributes.get("http.method").?);
    try std.testing.expectEqual(SpanStatus.ok, span.status);
    try std.testing.expect(span.ended);
}

test "RecordingTracer creates recording spans" {
    const allocator = std.testing.allocator;
    var tracer = RecordingTracer.init(allocator);
    defer tracer.deinit();
    const span = try tracer.asTracer().startSpan("test.op", .internal);
    try span.setAttribute("az.namespace", "KeyVault");
    span.setStatus(.ok);
    span.end();
    try std.testing.expectEqualStrings("test.op", tracer.last_span.?.name);
    try std.testing.expectEqual(SpanKind.internal, tracer.last_span.?.kind);
    try std.testing.expect(tracer.last_span.?.ended);
}

test "TraceContext formatTraceparent" {
    var ctx = TraceContext{};
    @memcpy(&ctx.trace_id, "0af7651916cd43dd8448eb211c80319c");
    @memcpy(&ctx.span_id, "b7ad6b7169203331");
    ctx.trace_flags = 0x01;
    const tp = ctx.formatTraceparent();
    try std.testing.expectEqualStrings("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01", &tp);
}

test "TraceContext parseTraceparent" {
    const ctx = TraceContext.parseTraceparent("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01").?;
    try std.testing.expectEqualStrings("0af7651916cd43dd8448eb211c80319c", &ctx.trace_id);
    try std.testing.expectEqualStrings("b7ad6b7169203331", &ctx.span_id);
    try std.testing.expectEqual(@as(u8, 0x01), ctx.trace_flags);
}

test "TraceContext parseTraceparent invalid" {
    try std.testing.expect(TraceContext.parseTraceparent("invalid") == null);
    try std.testing.expect(TraceContext.parseTraceparent("") == null);
}
