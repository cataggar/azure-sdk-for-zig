const std = @import("std");
const core = @import("azure_sdk_core");
const appconfiguration = @import("azure_sdk_data_appconfiguration");
const expect = std.testing.expect;

fn equal(expected: anytype, actual: anytype) !void {
    if (expected != actual) return error.TestExpectedEqual;
}

fn strings(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.TestExpectedEqual;
}

const parent = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01";
const trace_state = "vendor=fixture";
const service_name = "zig-appconfiguration-collector-fixture";
const scope_name = "azure_sdk_data_appconfiguration";
const scope_version = "0.3.1";
const namespace = "Microsoft.AppConfiguration";
const endpoint = "https://appconfig.fixture.invalid:8443";
const start_time = "1700000000000000000";
const end_time = "1700000000001000000";
pub const max_bytes = 64 * 1024;

pub const Capture = struct {
    payload: [max_bytes]u8 = undefined,
    payload_len: usize = 0,
    traceparent: [55]u8 = undefined,

    pub fn json(self: *const Capture) []const u8 {
        return self.payload[0..self.payload_len];
    }
};

const Clock = struct {
    ticks: u64 = 0,

    fn now(context: *anyopaque) core.tracing.ExportingTracerProvider.Clock.Sample {
        const self: *Clock = @ptrCast(@alignCast(context));
        defer self.ticks += 1;
        return .{
            .unix_ns = 1700000000000000000 + self.ticks * std.time.ns_per_ms,
            .monotonic_ns = self.ticks * std.time.ns_per_ms,
        };
    }
};

// Fixture-only IDs, never suitable for production randomness or credentials.
fn deterministicRandom(_: *anyopaque, bytes: []u8) !void {
    for (bytes, 0..) |*byte, index| byte.* = @intCast(index + 1);
}

pub fn capture(allocator: std.mem.Allocator, io: std.Io) !Capture {
    try strings("0.4.1", core.version);
    var result: Capture = .{};
    var transport = core.http.MockTransport.init(allocator, 200,
        \\{"key":"fixture-private-key","value":"mock-value-not-telemetry","label":"fixture-private-label"}
    );
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(io);
    var crypto_vtable = crypto.asProvider().vtable.*;
    crypto_vtable.random_bytes = deterministicRandom;
    const runtime = core.http.HttpRuntime.init(transport.asTransport(), .{
        .context = &crypto,
        .vtable = &crypto_vtable,
    });
    var writer: std.Io.Writer = .fixed(&result.payload);
    var scratch: [max_bytes]u8 = undefined;
    var exporter = core.tracing.OtlpJsonWriterExporter.init(&writer, &scratch);
    var clock: Clock = .{};
    var provider = try core.tracing.ExportingTracerProvider.init(
        allocator,
        io,
        runtime.crypto,
        exporter.asExporter(),
        .{
            .service_name = service_name,
            .max_spans = 1,
            .max_queued_spans = 1,
            .max_scopes = 1,
            .max_batch_size = 1,
            .clock = .{ .context = &clock, .nowFn = Clock.now },
        },
    );
    defer provider.deinit() catch unreachable;
    var pipeline = core.http.HttpPipeline.init(runtime, &.{});
    pipeline.setInstrumentation(.{
        .provider = provider.asProvider(),
        .scope_name = scope_name,
        .scope_version = scope_version,
        .namespace = namespace,
        .parent_context = core.tracing.TraceContext.extract(parent, trace_state),
    });
    // All borrowed interfaces/configuration remain address-stable until the
    // copied client pipeline has completed and the provider has shut down.
    {
        var client = appconfiguration.ConfigurationClient.init(endpoint, pipeline, .{});
        const setting = try client.getSetting(allocator, "fixture-private-key", "fixture-private-label");
        defer setting.deinit(allocator);
        try strings("fixture-private-key", setting.key);
        try strings("mock-value-not-telemetry", setting.value.?);
        try strings("fixture-private-label", setting.label.?);
    }
    try strings(
        endpoint ++ "/kv/fixture-private-key?label=fixture-private-label&api-version=2023-11-01",
        transport.last_url.?,
    );
    try equal(.GET, transport.last_method.?);
    const wire_parent = transport.last_headers.get("traceparent") orelse return error.MissingTraceparent;
    try equal(result.traceparent.len, wire_parent.len);
    @memcpy(&result.traceparent, wire_parent);
    try strings(trace_state, transport.last_headers.get("tracestate").?);
    try strings("application/vnd.microsoft.appconfig.kv+json", transport.last_headers.get("Accept").?);
    try equal(@as(usize, 0), writer.buffered().len);
    try equal(@as(usize, 1), provider.stats().queued_spans);
    try provider.forceFlush(1000);
    try provider.shutdown(1000);
    const stats = provider.stats();
    try equal(@as(u64, 1), stats.started);
    try equal(@as(u64, 1), stats.ended);
    try equal(@as(u64, 1), stats.exported);
    try equal(@as(u64, 0), stats.dropped_spans);
    try equal(@as(u64, 0), stats.dropped_attributes);
    try equal(@as(u64, 0), stats.export_errors);
    try equal(@as(u64, 0), stats.propagation_errors);
    try equal(@as(usize, 0), stats.active_spans);
    try equal(@as(usize, 0), stats.queued_spans);
    result.payload_len = writer.buffered().len;
    try validateTrace(allocator, result.json(), &result.traceparent);
    return result;
}

const Attribute = struct {
    key: []const u8,
    value: struct {
        stringValue: ?[]const u8 = null,
        intValue: ?[]const u8 = null,
    },
};

const TraceExport = struct {
    resourceSpans: []const struct {
        resource: struct { attributes: []const Attribute },
        scopeSpans: []const struct {
            scope: struct { name: []const u8, version: []const u8 },
            spans: []const struct {
                traceId: []const u8,
                spanId: []const u8,
                parentSpanId: []const u8,
                traceState: []const u8,
                flags: u32,
                name: []const u8,
                kind: u8,
                startTimeUnixNano: []const u8,
                endTimeUnixNano: []const u8,
                attributes: []const Attribute,
                droppedAttributesCount: u32 = 0,
                status: struct { code: u8 = 0 } = .{},
            },
        },
    },
};

fn attribute(attributes: []const Attribute, key: []const u8, value: []const u8, comptime integer: bool) !void {
    var count: usize = 0;
    for (attributes) |item| {
        if (!std.mem.eql(u8, item.key, key)) continue;
        count += 1;
        try strings(value, (if (integer) item.value.intValue else item.value.stringValue) orelse
            return error.WrongAttributeType);
        try expect((if (integer) item.value.stringValue else item.value.intValue) == null);
    }
    try equal(@as(usize, 1), count);
}

pub fn validateTrace(allocator: std.mem.Allocator, json: []const u8, wire_parent: []const u8) !void {
    if (core.tracing.TraceContext.parseTraceparent(wire_parent) == null) return error.InvalidWireTraceparent;
    try strings(parent[3..35], wire_parent[3..35]);
    try expect(!std.mem.eql(u8, parent[36..52], wire_parent[36..52]));
    try strings("01", wire_parent[53..55]);
    const parsed = try std.json.parseFromSlice(TraceExport, allocator, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try equal(@as(usize, 1), parsed.value.resourceSpans.len);
    const resource = parsed.value.resourceSpans[0];
    try equal(@as(usize, 1), resource.resource.attributes.len);
    try attribute(resource.resource.attributes, "service.name", service_name, false);
    try equal(@as(usize, 1), resource.scopeSpans.len);
    const scope = resource.scopeSpans[0];
    try strings(scope_name, scope.scope.name);
    try strings(scope_version, scope.scope.version);
    try equal(@as(usize, 1), scope.spans.len);
    const span = scope.spans[0];
    try strings(wire_parent[3..35], span.traceId);
    try strings(wire_parent[36..52], span.spanId);
    try strings(parent[36..52], span.parentSpanId);
    try strings(trace_state, span.traceState);
    try equal(@as(u32, 1), span.flags);
    try strings("HTTP", span.name);
    try equal(@as(u8, 3), span.kind);
    try strings(start_time, span.startTimeUnixNano);
    try strings(end_time, span.endTimeUnixNano);
    try equal(@as(u8, 0), span.status.code);
    try equal(@as(u32, 0), span.droppedAttributesCount);
    try equal(@as(usize, 5), span.attributes.len);
    try attribute(span.attributes, "http.request.method", "GET", false);
    try attribute(span.attributes, "http.response.status_code", "200", true);
    try attribute(span.attributes, "server.address", "appconfig.fixture.invalid", false);
    try attribute(span.attributes, "server.port", "8443", true);
    try attribute(span.attributes, "az.namespace", namespace, false);
    for ([_][]const u8{
        "fixture-private-key", "fixture-private-label", "mock-value-not-telemetry",
        "/kv/",                "api-version",           "authorization",
    }) |private| try expect(std.mem.indexOf(u8, json, private) == null);
}

pub fn validateResponse(allocator: std.mem.Allocator, response: []const u8) !void {
    const Response = struct {
        partialSuccess: ?struct {
            rejectedSpans: std.json.Value = .{ .string = "0" },
            errorMessage: []const u8 = "",
        } = null,
    };
    const parsed = try std.json.parseFromSlice(Response, allocator, response, .{});
    defer parsed.deinit();
    if (parsed.value.partialSuccess) |partial| {
        const rejected = switch (partial.rejectedSpans) {
            .string => |s| try std.fmt.parseInt(i64, s, 10),
            .integer => |i| i,
            else => return error.InvalidRejectedSpanCount,
        };
        if (rejected != 0 or partial.errorMessage.len != 0) return error.CollectorRejectedSpans;
    }
}

pub fn verify(
    allocator: std.mem.Allocator,
    request: []const u8,
    wire_parent: []const u8,
    response: []const u8,
    accepted: []const u8,
) !void {
    try validateResponse(allocator, response);
    try validateTrace(allocator, request, wire_parent);
    try validateTrace(allocator, accepted, wire_parent);
}

test "released service operation exports deterministic owned telemetry offline" {
    const first = try capture(std.testing.allocator, std.testing.io);
    const second = try capture(std.testing.allocator, std.testing.io);
    try strings(first.json(), second.json());
    try strings(&first.traceparent, &second.traceparent);
}

test "protocol response requires valid JSON and no rejected spans or warnings" {
    for ([_][]const u8{
        "{}",                                                               "{\"partialSuccess\":{}}", "{\"partialSuccess\":{\"rejectedSpans\":\"0\"}}",
        "{\"partialSuccess\":{\"rejectedSpans\":0,\"errorMessage\":\"\"}}",
    }) |response| try validateResponse(std.testing.allocator, response);
    for ([_][]const u8{
        "",                                                     "not json",                                   "{\"error\":\"bad payload\"}",
        "{\"partialSuccess\":{\"rejectedSpans\":\"1\"}}",       "{\"partialSuccess\":{\"rejectedSpans\":1}}", "{\"partialSuccess\":{\"rejectedSpans\":-1}}",
        "{\"partialSuccess\":{\"errorMessage\":\"rejected\"}}",
    }) |response| {
        if (validateResponse(std.testing.allocator, response)) |_| {
            return error.AcceptedInvalidResponse;
        } else |_| {}
    }
}

test "verification requires actual matching output, not merely a successful response" {
    const data = try capture(std.testing.allocator, std.testing.io);
    try verify(std.testing.allocator, data.json(), &data.traceparent, "{}", data.json());
    try std.testing.expectError(
        error.UnexpectedEndOfInput,
        verify(std.testing.allocator, data.json(), &data.traceparent, "{}", ""),
    );
    var wrong_parent = data.traceparent;
    wrong_parent[36] = if (wrong_parent[36] == 'a') 'b' else 'a';
    try std.testing.expectError(
        error.TestExpectedEqual,
        verify(std.testing.allocator, data.json(), &wrong_parent, "{}", data.json()),
    );
}

test "verification rejects changed collector span semantics and duplicate output" {
    const data = try capture(std.testing.allocator, std.testing.io);
    for ([_][]const u8{
        scope_name, scope_version, service_name, namespace, parent[36..52],
        "GET",      "200",         "8443",       "HTTP",    start_time,
    }) |value| {
        var altered = data;
        const index = std.mem.indexOf(u8, altered.json(), value).?;
        altered.payload[index] = if (altered.payload[index] == 'a') 'b' else 'a';
        if (verify(std.testing.allocator, data.json(), &data.traceparent, "{}", altered.json())) |_| {
            return error.AcceptedChangedTelemetry;
        } else |_| {}
    }
    const duplicate = try std.mem.concat(std.testing.allocator, u8, &.{ data.json(), data.json() });
    defer std.testing.allocator.free(duplicate);
    if (verify(std.testing.allocator, data.json(), &data.traceparent, "{}", duplicate)) |_| {
        return error.AcceptedDuplicateTelemetry;
    } else |_| {}
}
