const std = @import("std");
const core = @import("azure_sdk_core");
const sas = @import("sas.zig");
const allocator = std.testing.allocator;
const Provider = core.tracing.ExportingTracerProvider;
const scope_name = "azure_sdk_storage_blobs";
const scope_version = "7.8.9";
const namespace = "Microsoft.Caller.Storage";
const sas_url = "https://account.blob.core.windows.net/private-path?sig=private-signature&sp=rw";
const upstream_parent = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01";
const upstream_state = "vendor=upstream, ,other=value,";
const original_parent = "00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-01";

const Probe = struct {
    exporter: core.tracing.SpanExporter = .{
        .exportFn = exportBatch,
        .forceFlushFn = flush,
        .shutdownFn = shutdown,
    },
    delegate: ?*core.tracing.SpanExporter = null,
    fail: bool = false,
    export_calls: usize = 0,
    flush_calls: usize = 0,
    shutdown_calls: usize = 0,
    count: usize = 0,
    records: [8]Record = undefined,

    const Record = struct {
        trace_id: [32]u8,
        span_id: [16]u8,
        parent_span_id: ?[16]u8,
        status: core.tracing.SpanStatus,
        status_code: ?i64 = null,
        error_type: bool = false,
    };

    fn exportBatch(
        exporter: *core.tracing.SpanExporter,
        batch: []const core.tracing.SpanData,
        context: core.tracing.ExportContext,
    ) !void {
        const self: *Probe = @fieldParentPtr("exporter", exporter);
        self.export_calls += 1;
        if (self.fail) return error.FixtureExportFailure;
        for (batch) |data| {
            try std.testing.expect(self.count < self.records.len);
            try std.testing.expectEqualStrings(scope_name, data.scope_name);
            try std.testing.expectEqualStrings(scope_version, data.scope_version);
            try std.testing.expectEqualStrings("storage-common-test", data.service_name);
            try std.testing.expectEqualStrings("HTTP", data.name);
            try std.testing.expectEqual(core.tracing.SpanKind.client, data.kind);
            try std.testing.expect(data.context.isValid());
            try std.testing.expect(data.end_time_unix_nano >= data.start_time_unix_nano);
            var record: Record = .{
                .trace_id = data.context.trace_id,
                .span_id = data.context.span_id,
                .parent_span_id = data.parent_span_id,
                .status = data.status,
            };
            var has_namespace = false;
            for (data.attributes) |attribute| {
                try std.testing.expect(
                    std.mem.eql(u8, attribute.key, "http.request.method") or
                        std.mem.eql(u8, attribute.key, "server.address") or
                        std.mem.eql(u8, attribute.key, "az.namespace") or
                        std.mem.eql(u8, attribute.key, "http.response.status_code") or
                        std.mem.eql(u8, attribute.key, "error.type"),
                );
                if (attribute.value == .string)
                    try std.testing.expect(std.mem.indexOf(u8, attribute.value.string, "private-") == null);
                if (std.mem.eql(u8, attribute.key, "az.namespace")) {
                    has_namespace = true;
                    try std.testing.expectEqualStrings(namespace, attribute.value.string);
                }
                if (std.mem.eql(u8, attribute.key, "http.response.status_code"))
                    record.status_code = attribute.value.int;
                if (std.mem.eql(u8, attribute.key, "error.type")) record.error_type = true;
            }
            try std.testing.expect(has_namespace);
            self.records[self.count] = record;
            self.count += 1;
        }
        if (self.delegate) |delegate| try delegate.exportBatch(batch, context);
    }

    fn flush(exporter: *core.tracing.SpanExporter, _: core.tracing.ExportContext) !void {
        const self: *Probe = @fieldParentPtr("exporter", exporter);
        self.flush_calls += 1;
    }

    fn shutdown(exporter: *core.tracing.SpanExporter, _: core.tracing.ExportContext) !void {
        const self: *Probe = @fieldParentPtr("exporter", exporter);
        self.shutdown_calls += 1;
    }

    fn expectUnmanaged(self: *const Probe) !void {
        try std.testing.expectEqual(@as(usize, 0), self.export_calls);
        try std.testing.expectEqual(@as(usize, 0), self.flush_calls);
        try std.testing.expectEqual(@as(usize, 0), self.shutdown_calls);
    }
};

fn makeProvider(runtime: core.http.HttpRuntime, probe: *Probe, capacity: usize) !Provider {
    return Provider.init(allocator, std.testing.io, runtime.crypto, &probe.exporter, .{
        .service_name = "storage-common-test",
        .max_spans = capacity,
        .max_queued_spans = capacity,
        .max_scopes = 1,
        .max_batch_size = capacity,
    });
}

fn instrumentation(provider: *Provider) core.tracing.InstrumentationOptions {
    return .{
        .provider = provider.asProvider(),
        .scope_name = scope_name,
        .scope_version = scope_version,
        .namespace = namespace,
    };
}

fn capturedHeader(mock: *const core.http.MockTransport, name: []const u8) ?[]const u8 {
    var headers = mock.last_headers.iterator();
    while (headers.next()) |header| {
        if (std.ascii.eqlIgnoreCase(header.key_ptr.*, name)) return header.value_ptr.*;
    }
    return null;
}

test "SAS send public options expose tracing only and package version follows manifest" {
    const fields = @typeInfo(sas.SendOptions).@"struct".fields;
    try std.testing.expectEqual(@as(usize, 1), fields.len);
    try std.testing.expectEqualStrings("instrumentation", fields[0].name);
    try std.testing.expect(fields[0].type == ?core.tracing.InstrumentationOptions);
    try std.testing.expect((sas.SendOptions{}).instrumentation == null);
    try std.testing.expectEqualStrings(@import("build.zig.zon").version, @import("root.zig").version);
}

test "SAS send forwards scope parent and W3C context with owned delayed OTLP JSON" {
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var mock = core.http.MockTransport.init(allocator, 201, "private-response-body");
    defer mock.deinit();
    const runtime = core.http.HttpRuntime.init(mock.asTransport(), crypto.asProvider());
    var output: [16 * 1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&output);
    var scratch: [16 * 1024]u8 = undefined;
    var json_exporter = core.tracing.OtlpJsonWriterExporter.init(&writer, &scratch);
    var probe: Probe = .{ .delegate = json_exporter.asExporter() };
    var provider = try makeProvider(runtime, &probe, 2);
    defer provider.deinit() catch unreachable;
    var wire_context: core.tracing.TraceContext = undefined;
    {
        const url = try allocator.dupe(u8, sas_url);
        defer allocator.free(url);
        const borrowed_scope = try allocator.dupe(u8, scope_name);
        defer allocator.free(borrowed_scope);
        const borrowed_version = try allocator.dupe(u8, scope_version);
        defer allocator.free(borrowed_version);
        const borrowed_namespace = try allocator.dupe(u8, namespace);
        defer allocator.free(borrowed_namespace);
        const borrowed_state = try allocator.dupe(u8, upstream_state);
        defer allocator.free(borrowed_state);
        var parent = core.tracing.TraceContext.extract(upstream_parent, borrowed_state).?;
        var request = core.http.Request.init(allocator, .PUT, url);
        defer request.deinit();
        try request.setHeader("Traceparent", original_parent);
        try request.setHeader("Tracestate", "caller=retained");
        try request.setHeader("User-Agent", "caller-storage-client/7.8.9");
        try request.setHeader("x-test-secret", "private-header");
        var body: std.Io.Reader = .fixed("private-upload-body");
        const result = try sas.sendWithOptions(
            runtime,
            &request,
            .knownLength(&body, "private-upload-body".len),
            .{ .instrumentation = .{
                .provider = provider.asProvider(),
                .scope_name = borrowed_scope,
                .scope_version = borrowed_version,
                .namespace = borrowed_namespace,
                .parent_context = parent,
            } },
        );
        try std.testing.expectEqual(@as(u16, 201), result.accepted.status_code);
        try std.testing.expectEqualStrings(sas_url, mock.last_url.?);
        try std.testing.expectEqualStrings("private-upload-body", mock.last_body.?);
        try std.testing.expectEqualStrings("caller-storage-client/7.8.9", capturedHeader(&mock, "User-Agent").?);
        try std.testing.expect(capturedHeader(&mock, "Authorization") == null);
        try std.testing.expect(capturedHeader(&mock, "Cookie") == null);
        wire_context = core.tracing.TraceContext.parseTraceparent(mock.last_headers.get("traceparent").?).?;
        try std.testing.expectEqualStrings(&parent.trace_id, &wire_context.trace_id);
        try std.testing.expect(!std.mem.eql(u8, &parent.span_id, &wire_context.span_id));
        try std.testing.expectEqualStrings(upstream_state, mock.last_headers.get("tracestate").?);
        try std.testing.expectEqualStrings(original_parent, request.getHeader("traceparent").?);
        try std.testing.expectEqualStrings("caller=retained", request.getHeader("tracestate").?);
        try std.testing.expectEqualStrings("private-header", request.getHeader("x-test-secret").?);
        try std.testing.expectEqual(@as(?bool, false), mock.last_retryable);
        try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, mock.last_redirect_policy.?);
        try std.testing.expectEqual(@as(usize, 1), mock.stream_deinit_count);
        try probe.expectUnmanaged();
        try std.testing.expectEqual(@as(usize, 0), writer.buffered().len);
        for ([_][]u8{ url, borrowed_scope, borrowed_version, borrowed_namespace, borrowed_state }) |bytes|
            @memset(bytes, 'x');
        parent = .{};
    }
    try std.testing.expectEqual(@as(usize, 1), provider.stats().queued_spans);
    try std.testing.expectEqual(@as(usize, 1), try provider.drain(1000));
    try std.testing.expectEqual(@as(usize, 1), probe.count);
    try std.testing.expectEqualStrings(&wire_context.trace_id, &probe.records[0].trace_id);
    try std.testing.expectEqualStrings(&wire_context.span_id, &probe.records[0].span_id);
    try std.testing.expectEqualStrings("b7ad6b7169203331", &probe.records[0].parent_span_id.?);
    try std.testing.expectEqual(core.tracing.SpanStatus.unset, probe.records[0].status);
    try std.testing.expect(std.mem.indexOf(u8, writer.buffered(), "private-") == null);
    try std.testing.expect(std.mem.indexOf(u8, writer.buffered(), "Authorization") == null);
    try std.testing.expect(std.mem.indexOf(u8, writer.buffered(), "Cookie") == null);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, writer.buffered(), .{});
    defer parsed.deinit();
    const resource = parsed.value.object.get("resourceSpans").?.array.items[0];
    const scoped = resource.object.get("scopeSpans").?.array.items[0];
    const exported_scope = scoped.object.get("scope").?;
    try std.testing.expectEqualStrings(scope_name, exported_scope.object.get("name").?.string);
    try std.testing.expectEqualStrings(scope_version, exported_scope.object.get("version").?.string);
    const span = scoped.object.get("spans").?.array.items[0];
    try std.testing.expectEqualStrings(&wire_context.trace_id, span.object.get("traceId").?.string);
    try std.testing.expectEqualStrings(&wire_context.span_id, span.object.get("spanId").?.string);
    try std.testing.expectEqualStrings(upstream_state, span.object.get("traceState").?.string);
    try provider.forceFlush(1000);
    try provider.shutdown(1000);
    try std.testing.expectEqual(@as(usize, 1), probe.shutdown_calls);
    try std.testing.expectEqual(@as(usize, 1), mock.call_count);
}

test "SAS send legacy default null and suppressed instrumentation stay inert" {
    for (0..4) |mode| {
        for ([_]bool{ false, true }) |has_caller_headers| {
            var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
            var mock = core.http.MockTransport.init(allocator, 204, "");
            defer mock.deinit();
            const runtime = core.http.HttpRuntime.init(mock.asTransport(), crypto.asProvider());
            var probe: Probe = .{};
            var provider = try makeProvider(runtime, &probe, 1);
            defer provider.deinit() catch unreachable;
            var request = core.http.Request.init(allocator, .PUT, sas_url);
            defer request.deinit();
            if (has_caller_headers) {
                try request.setHeader("traceparent", "opaque-caller-parent");
                try request.setHeader("tracestate", "opaque-caller-state");
            }
            request.context.tracing_suppressed = mode == 3;
            const outcome = switch (mode) {
                0 => try sas.send(runtime, &request, null),
                1 => try sas.sendWithOptions(runtime, &request, null, .{}),
                2 => try sas.sendWithOptions(runtime, &request, null, .{ .instrumentation = null }),
                else => try sas.sendWithOptions(runtime, &request, null, .{ .instrumentation = instrumentation(&provider) }),
            };
            try std.testing.expectEqual(@as(u16, 204), outcome.accepted.status_code);
            if (has_caller_headers) {
                try std.testing.expectEqualStrings("opaque-caller-parent", mock.last_headers.get("traceparent").?);
                try std.testing.expectEqualStrings("opaque-caller-state", request.getHeader("tracestate").?);
            } else {
                try std.testing.expect(!mock.last_headers.contains("traceparent"));
                try std.testing.expect(!mock.last_headers.contains("tracestate"));
            }
            try std.testing.expect(capturedHeader(&mock, "User-Agent") == null);
            try std.testing.expect(capturedHeader(&mock, "Authorization") == null);
            try std.testing.expect(capturedHeader(&mock, "Cookie") == null);
            try std.testing.expectEqual(@as(u64, 0), provider.stats().started);
            try std.testing.expectEqual(@as(u64, 0), provider.stats().propagation_errors);
            try probe.expectUnmanaged();
        }
    }
}

test "SAS send extracts valid W3C state drops invalid state and restores request reuse" {
    const State = struct { value: []const u8, valid: bool };
    for ([_]State{
        .{ .value = "", .valid = true },
        .{ .value = " \t", .valid = true },
        .{ .value = upstream_state, .valid = true },
        .{ .value = "vendor=one,vendor=two", .valid = false },
        .{ .value = "vendor=", .valid = false },
    }) |state| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 201, "");
        defer mock.deinit();
        const runtime = core.http.HttpRuntime.init(mock.asTransport(), crypto.asProvider());
        var probe: Probe = .{};
        var provider = try makeProvider(runtime, &probe, 2);
        defer provider.deinit() catch unreachable;
        var request = core.http.Request.init(allocator, .PUT, sas_url);
        defer request.deinit();
        try request.setHeader("traceparent", original_parent);
        try request.setHeader("tracestate", state.value);
        var ids: [2][16]u8 = undefined;
        for (&ids) |*id| {
            const outcome = try sas.sendWithOptions(runtime, &request, null, .{
                .instrumentation = instrumentation(&provider),
            });
            try std.testing.expectEqual(@as(u16, 201), outcome.accepted.status_code);
            const wire = core.tracing.TraceContext.parseTraceparent(mock.last_headers.get("traceparent").?).?;
            id.* = wire.span_id;
            try std.testing.expectEqualStrings(original_parent[3..35], &wire.trace_id);
            if (state.valid) {
                try std.testing.expectEqualStrings(state.value, mock.last_headers.get("tracestate").?);
            } else {
                try std.testing.expect(!mock.last_headers.contains("tracestate"));
            }
            try std.testing.expectEqualStrings(original_parent, request.getHeader("traceparent").?);
            try std.testing.expectEqualStrings(state.value, request.getHeader("tracestate").?);
        }
        try probe.expectUnmanaged();
        try std.testing.expectEqual(@as(usize, 2), try provider.drain(1000));
        try std.testing.expect(!std.mem.eql(u8, &ids[0], &ids[1]));
        for (ids, probe.records[0..2]) |id, record| {
            try std.testing.expectEqualStrings(&id, &record.span_id);
            try std.testing.expectEqualStrings(original_parent[36..52], &record.parent_span_id.?);
        }
    }
}

test "SAS send preserves status and drain outcomes without redirects or replay" {
    for ([_]u16{ 201, 302, 403, 503 }) |status| {
        for ([_]bool{ false, true }) |drain_fails| {
            var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
            var mock = core.http.MockTransport.init(allocator, status, "private-response");
            defer mock.deinit();
            mock.response_headers_list = &.{.{ .name = "Location", .value = "https://other.test/private-redirect" }};
            if (drain_fails) mock.stream_fail_response_after = 0;
            const runtime = core.http.HttpRuntime.init(mock.asTransport(), crypto.asProvider());
            var probe: Probe = .{};
            var provider = try makeProvider(runtime, &probe, 1);
            defer provider.deinit() catch unreachable;
            var request = core.http.Request.init(allocator, .PUT, sas_url);
            defer request.deinit();
            request.retryable = true;
            var body = core.http.ReplayableBytes.init("private-upload");
            const outcome = try sas.sendWithOptions(runtime, &request, body.body(), .{
                .instrumentation = instrumentation(&provider),
            });
            if (status == 201) {
                try std.testing.expectEqual(status, outcome.accepted.status_code);
            } else {
                try std.testing.expectEqual(status, outcome.rejected.status_code);
            }
            try std.testing.expectEqual(@as(usize, 1), mock.call_count);
            try std.testing.expectEqual(@as(?bool, false), mock.last_retryable);
            try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, mock.last_redirect_policy.?);
            try std.testing.expectEqual(@as(usize, 1), mock.stream_finish_count);
            try std.testing.expectEqual(@as(usize, 1), mock.stream_deinit_count);
            try std.testing.expectEqual(@as(usize, @intFromBool(drain_fails)), mock.stream_abort_count);
            try probe.expectUnmanaged();
            _ = try provider.drain(1000);
            try std.testing.expectEqual(@as(usize, 1), probe.count);
            try std.testing.expectEqual(@as(?i64, status), probe.records[0].status_code);
            try std.testing.expectEqual(
                if (status >= 400) core.tracing.SpanStatus.@"error" else .unset,
                probe.records[0].status,
            );
            try std.testing.expectEqual(status >= 400, probe.records[0].error_type);
        }
    }
}

test "SAS send preserves upload uncertainty and pre-dispatch errors" {
    for ([_]bool{ false, true }) |supports_streaming| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 201, "");
        defer mock.deinit();
        mock.stream_fail_upload_after = 0;
        const descriptor = mock.asTransport();
        const buffered_only: core.http.HttpTransport.VTable = .{ .send = descriptor.vtable.send };
        const runtime = core.http.HttpRuntime.init(if (supports_streaming) descriptor else .{
            .context = descriptor.context,
            .vtable = &buffered_only,
        }, crypto.asProvider());
        var probe: Probe = .{};
        var provider = try makeProvider(runtime, &probe, 1);
        defer provider.deinit() catch unreachable;
        var request = core.http.Request.init(allocator, .PUT, sas_url);
        defer request.deinit();
        try request.setHeader("traceparent", original_parent);
        try request.setHeader("tracestate", "caller=retained");
        request.transport_started = true;
        var body: std.Io.Reader = .fixed("private-upload");
        const result = sas.sendWithOptions(runtime, &request, .knownLength(&body, "private-upload".len), .{
            .instrumentation = instrumentation(&provider),
        });
        if (supports_streaming) {
            try std.testing.expectEqual(error.InjectedUploadFailure, (try result).unknown.cause);
        } else {
            try std.testing.expectError(error.StreamingRequestUnsupported, result);
        }
        try std.testing.expectEqual(supports_streaming, request.transport_started);
        try std.testing.expectEqualStrings(original_parent, request.getHeader("traceparent").?);
        try std.testing.expectEqualStrings("caller=retained", request.getHeader("tracestate").?);
        try std.testing.expectEqual(@as(usize, 0), mock.stream_deinit_count);
        try probe.expectUnmanaged();
        _ = try provider.drain(1000);
        try std.testing.expectEqual(@as(usize, 1), probe.count);
        try std.testing.expectEqual(core.tracing.SpanStatus.@"error", probe.records[0].status);
        try std.testing.expect(probe.records[0].error_type);
        try std.testing.expect(probe.records[0].status_code == null);
    }
}

test "SAS send telemetry allocation failures preserve caller context and every outcome" {
    const Outcome = enum { accepted, rejected, unknown, pre_dispatch };
    for (std.enums.values(Outcome)) |expected| {
        for (0..4) |allocation_offset| {
            var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
            var mock = core.http.MockTransport.init(allocator, if (expected == .rejected) 503 else 201, "");
            defer mock.deinit();
            if (expected == .unknown) mock.stream_fail_upload_after = 0;
            const descriptor = mock.asTransport();
            const buffered_only: core.http.HttpTransport.VTable = .{ .send = descriptor.vtable.send };
            const runtime = core.http.HttpRuntime.init(if (expected != .pre_dispatch) descriptor else .{
                .context = descriptor.context,
                .vtable = &buffered_only,
            }, crypto.asProvider());
            var probe: Probe = .{};
            var provider = try makeProvider(runtime, &probe, 1);
            defer provider.deinit() catch unreachable;
            var failing = std.testing.FailingAllocator.init(allocator, .{});
            var request = core.http.Request.init(failing.allocator(), .PUT, sas_url);
            defer request.deinit();
            try request.setHeader("traceparent", original_parent);
            try request.setHeader("tracestate", upstream_state);
            try request.setHeader("x-caller", "retained");
            failing.fail_index = failing.alloc_index + allocation_offset;
            var body: std.Io.Reader = .fixed("private-upload");
            const result = sas.sendWithOptions(runtime, &request, .knownLength(&body, "private-upload".len), .{
                .instrumentation = instrumentation(&provider),
            });
            switch (expected) {
                .accepted => try std.testing.expectEqual(@as(u16, 201), (try result).accepted.status_code),
                .rejected => try std.testing.expectEqual(@as(u16, 503), (try result).rejected.status_code),
                .unknown => try std.testing.expectEqual(error.InjectedUploadFailure, (try result).unknown.cause),
                .pre_dispatch => try std.testing.expectError(error.StreamingRequestUnsupported, result),
            }
            try std.testing.expect(failing.has_induced_failure);
            try std.testing.expectEqualStrings(original_parent, request.getHeader("traceparent").?);
            try std.testing.expectEqualStrings(upstream_state, request.getHeader("tracestate").?);
            try std.testing.expectEqualStrings("retained", request.getHeader("x-caller").?);
            try std.testing.expectEqual(expected != .pre_dispatch, request.transport_started);
            try std.testing.expectEqual(@as(u64, 1), provider.stats().propagation_errors);
            try std.testing.expectEqual(@as(usize, 0), provider.stats().active_spans);
            try probe.expectUnmanaged();
            _ = try provider.drain(1000);
            try std.testing.expectEqual(
                if (expected == .accepted) core.tracing.SpanStatus.unset else .@"error",
                probe.records[0].status,
            );
        }
    }
}

test "SAS send queue saturation and failed explicit export never replace service outcome" {
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();
    const runtime = core.http.HttpRuntime.init(mock.asTransport(), crypto.asProvider());
    var probe: Probe = .{ .fail = true };
    var provider = try makeProvider(runtime, &probe, 1);
    defer provider.deinit() catch unreachable;
    var outcomes: [2]sas.RequestOutcome = undefined;
    for (&outcomes, 0..) |*outcome, index| {
        mock.response_status = if (index == 0) 201 else 503;
        var request = core.http.Request.init(allocator, .PUT, sas_url);
        defer request.deinit();
        outcome.* = try sas.sendWithOptions(runtime, &request, null, .{
            .instrumentation = instrumentation(&provider),
        });
        try std.testing.expectEqual(index == 0, mock.last_headers.contains("traceparent"));
        try std.testing.expect(request.getHeader("traceparent") == null);
    }
    try std.testing.expectEqual(@as(u16, 201), outcomes[0].accepted.status_code);
    try std.testing.expectEqual(@as(u16, 503), outcomes[1].rejected.status_code);
    try std.testing.expectEqual(@as(u64, 1), provider.stats().dropped_spans);
    try std.testing.expectEqual(@as(usize, 1), provider.stats().queued_spans);
    try probe.expectUnmanaged();
    try std.testing.expectError(error.FixtureExportFailure, provider.forceFlush(1000));
    try std.testing.expectEqual(@as(u64, 1), provider.stats().export_errors);
    try std.testing.expectEqual(@as(u16, 201), outcomes[0].accepted.status_code);
    try std.testing.expectEqual(@as(u16, 503), outcomes[1].rejected.status_code);
    try std.testing.expectEqual(@as(usize, 2), mock.call_count);
    try std.testing.expectEqual(@as(usize, 0), probe.shutdown_calls);
}
