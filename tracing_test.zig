const std = @import("std");
const core = @import("azure_sdk_core");
const blobs = @import("root.zig");
const allocator = std.testing.allocator;
const Provider = core.tracing.ExportingTracerProvider;
const scope_name = "caller.blobs";
const scope_version = "9.8.7";
const namespace = "Caller.Namespace";
const parent_header = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01";
const trace_state = "caller=value, ,vendor=ok,";
const endpoint = "https://account.blob.core.windows.net/private-resource";
const sas_url = endpoint ++ "?sig=private-signature";

const Capture = struct {
    mock: *core.http.MockTransport,
    count: usize = 0,
    contexts: [64]?core.tracing.TraceContext = @splat(null),
    bodies: []const []const u8 = &.{},
    statuses: []const u16 = &.{},
    fail_at: ?usize = null,
    require_sas: bool = false,

    const vtable: core.http.HttpTransport.VTable = .{ .send = send, .open = open };
    const buffered_vtable: core.http.HttpTransport.VTable = .{ .send = send };

    fn asTransport(self: *Capture) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    fn bufferedTransport(self: *Capture) core.http.HttpTransport {
        return .{ .context = self, .vtable = &buffered_vtable };
    }

    fn record(self: *Capture, request: *core.http.Request) !void {
        try std.testing.expect(self.count < self.contexts.len);
        if (request.getHeader("traceparent")) |header| {
            self.contexts[self.count] = core.tracing.TraceContext.parseTraceparent(header).?;
            try std.testing.expectEqualStrings(parent_header[3..35], &self.contexts[self.count].?.trace_id);
            try std.testing.expectEqualStrings(trace_state, request.getHeader("tracestate").?);
        }
        if (self.require_sas) {
            try std.testing.expect(!request.retryable);
            try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, request.redirect_policy);
            try std.testing.expect(request.getHeader("Authorization") == null);
            try std.testing.expect(request.getHeader("Cookie") == null);
        }
        if (self.count < self.bodies.len) self.mock.response_body = self.bodies[self.count];
        if (self.count < self.statuses.len) self.mock.response_status = self.statuses[self.count];
        self.count += 1;
        if (self.fail_at == self.count - 1) return error.FixtureTransportFailure;
    }

    fn send(context: *anyopaque, request: *core.http.Request) !core.http.Response {
        const self: *Capture = @ptrCast(@alignCast(context));
        try self.record(request);
        const inner = self.mock.asTransport();
        return inner.vtable.send(inner.context, request);
    }

    fn open(context: *anyopaque, request: *core.http.Request, options: core.http.OpenOptions) !*core.http.HttpOperation {
        const self: *Capture = @ptrCast(@alignCast(context));
        try self.record(request);
        const inner = self.mock.asTransport();
        return inner.vtable.open.?(inner.context, request, options);
    }
};

const Probe = struct {
    exporter: core.tracing.SpanExporter = .{ .exportFn = exportBatch },
    capture: *Capture,
    count: usize = 0,
    calls: usize = 0,
    statuses: [64]core.tracing.SpanStatus = undefined,
    require_wire: bool = true,
    fail: bool = false,

    fn exportBatch(exporter: *core.tracing.SpanExporter, batch: []const core.tracing.SpanData, _: core.tracing.ExportContext) !void {
        const self: *Probe = @fieldParentPtr("exporter", exporter);
        self.calls += 1;
        if (self.fail) return error.FixtureExportFailure;
        for (batch) |data| {
            try std.testing.expectEqualStrings(scope_name, data.scope_name);
            try std.testing.expectEqualStrings(scope_version, data.scope_version);
            try std.testing.expectEqualStrings(parent_header[3..35], &data.context.trace_id);
            try std.testing.expectEqualStrings(parent_header[36..52], &data.parent_span_id.?);
            try std.testing.expectEqualStrings(trace_state, data.context.trace_state.?);
            try std.testing.expect(data.end_time_unix_nano >= data.start_time_unix_nano);
            var matched = false;
            for (self.capture.contexts[0..self.capture.count]) |context| {
                if (context) |value| {
                    if (std.mem.eql(u8, &value.span_id, &data.context.span_id)) matched = true;
                }
            }
            if (self.require_wire) try std.testing.expect(matched);
            var has_namespace = false;
            for (data.attributes) |attribute| {
                try std.testing.expect(!std.mem.eql(u8, attribute.key, "url.full"));
                try std.testing.expect(!std.mem.eql(u8, attribute.key, "Authorization"));
                if (attribute.value == .string)
                    try std.testing.expect(std.mem.indexOf(u8, attribute.value.string, "private-") == null);
                if (std.mem.eql(u8, attribute.key, "az.namespace")) {
                    has_namespace = true;
                    try std.testing.expectEqualStrings(namespace, attribute.value.string);
                }
            }
            try std.testing.expect(has_namespace);
            self.statuses[self.count] = data.status;
            self.count += 1;
        }
    }
};

fn makeProvider(runtime: core.http.HttpRuntime, probe: *Probe, capacity: usize) !Provider {
    return Provider.init(allocator, std.testing.io, runtime.crypto, &probe.exporter, .{
        .max_spans = capacity,
        .max_queued_spans = capacity,
        .max_scopes = 1,
        .max_batch_size = @min(capacity, 32),
    });
}

fn instrumentation(provider: *Provider) core.tracing.InstrumentationOptions {
    return .{
        .provider = provider.asProvider(),
        .scope_name = scope_name,
        .scope_version = scope_version,
        .namespace = namespace,
        .parent_context = core.tracing.TraceContext.extract(parent_header, trace_state).?,
    };
}

fn configuredPipeline(runtime: core.http.HttpRuntime, provider: *Provider) core.http.HttpPipeline {
    var pipeline = core.http.HttpPipeline.init(runtime, &.{});
    pipeline.setInstrumentation(instrumentation(provider));
    return pipeline;
}

test "tracing generated client families preserve copied options and default-disabled errors" {
    for ([_]bool{ false, true }) |enabled| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 503, "");
        defer mock.deinit();
        var capture: Capture = .{ .mock = &mock };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 8);
        defer provider.deinit() catch unreachable;
        {
            const scope = try allocator.dupe(u8, scope_name);
            defer allocator.free(scope);
            const version = try allocator.dupe(u8, scope_version);
            defer allocator.free(version);
            const ns = try allocator.dupe(u8, namespace);
            defer allocator.free(ns);
            const state = try allocator.dupe(u8, trace_state);
            defer allocator.free(state);
            var pipeline = core.http.HttpPipeline.init(runtime, &.{});
            if (enabled) pipeline.setInstrumentation(.{
                .provider = provider.asProvider(),
                .scope_name = scope,
                .scope_version = version,
                .namespace = ns,
                .parent_context = core.tracing.TraceContext.extract(parent_header, state).?,
            });
            var client = blobs.BlobClient.init(pipeline, .{ .endpoint = endpoint });
            pipeline.setInstrumentation(null);
            var service = client.service();
            var container = client.container();
            var blob = client.blob();
            var append = client.appendBlob();
            var block = client.blockBlob();
            var page = client.pageBlob();
            client.pipeline.setInstrumentation(null);
            try std.testing.expectError(error.AzureRequestFailed, service.getAccountInfo(allocator, null, null));
            try std.testing.expectError(error.AzureRequestFailed, container.getAccountInfo(allocator, null, null));
            try std.testing.expectError(error.AzureRequestFailed, blob.getAccountInfo(allocator, null, null));
            try std.testing.expectError(error.AzureRequestFailed, append.seal(allocator, null, null, null, null, null, null, null, null));
            try std.testing.expectError(error.AzureRequestFailed, blobs.uploadBlockBlob(&block, allocator, "private-body", .{}));
            try std.testing.expectError(error.AzureRequestFailed, page.getPageRanges(allocator, null, null, null, null, null, null, null, null, null, null, null, null));
            for ([_][]u8{ scope, version, ns, state }) |bytes| @memset(bytes, 'x');
        }
        try std.testing.expectEqual(@as(usize, 6), capture.count);
        try std.testing.expectEqual(@as(usize, 0), probe.calls);
        for (capture.contexts[0..capture.count]) |context|
            try std.testing.expectEqual(enabled, context != null);
        _ = try provider.drain(1000);
        try std.testing.expectEqual(@as(usize, if (enabled) 6 else 0), probe.count);
        for (probe.statuses[0..probe.count]) |status| try std.testing.expectEqual(core.tracing.SpanStatus.@"error", status);
    }
}

test "tracing generated pagers keep configuration after originating clients leave scope" {
    inline for (0..5) |kind| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        var capture: Capture = .{ .mock = &mock, .bodies = &.{
            "<EnumerationResults><NextMarker>private-marker</NextMarker></EnumerationResults>",
            "<EnumerationResults/>",
        } };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 2);
        defer provider.deinit() catch unreachable;
        {
            var pager = blk: {
                var client = blobs.BlobClient.init(configuredPipeline(runtime, &provider), .{ .endpoint = endpoint });
                var service = client.service();
                var container = client.container();
                break :blk switch (kind) {
                    0 => try service.listContainers(allocator, null, null, null, null, null, null),
                    1 => try service.findBlobsByTags(allocator, null, null, "private-filter", null, null, null),
                    2 => try container.findBlobsByTags(allocator, null, null, "private-filter", null, null, null),
                    3 => try container.listBlobs(allocator, null, null, null, null, null, null, null),
                    else => try container.listBlobHierarchySegment(allocator, null, "/", null, null, null, null, null, null),
                };
            };
            defer pager.deinit();
            try std.testing.expect((try pager.next()) != null);
            try std.testing.expect((try pager.next()) != null);
            try std.testing.expect((try pager.next()) == null);
            try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "marker=private-marker") != null);
        }
        try std.testing.expectEqual(@as(usize, 2), capture.count);
        try std.testing.expectEqual(@as(usize, 0), probe.calls);
        try std.testing.expectEqual(@as(usize, 2), try provider.drain(1000));
    }
}

test "tracing handwritten clients and convenience status upload download paths" {
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();
    var capture: Capture = .{ .mock = &mock };
    const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
    var probe: Probe = .{ .capture = &capture };
    var provider = try makeProvider(runtime, &probe, 32);
    defer provider.deinit() catch unreachable;
    {
        var container = blobs.BlobContainerClient.init(configuredPipeline(runtime, &provider), .{
            .endpoint = endpoint,
            .container_name = "private-container",
        });
        try container.create(allocator);
        var blob = container.getBlobClient("private-blob");
        var copied = blob;
        blob.pipeline.setInstrumentation(null);
        try copied.upload(allocator, "private-body", "text/plain");
        const metadata_result = try copied.setMetadata(allocator, &.{.{ .name = "test", .value = "private-metadata" }}, .{});
        metadata_result.deinit(allocator);
        mock.response_status = 200;
        mock.response_body = "private-response";
        const downloaded = try copied.downloadWithProperties(allocator);
        downloaded.deinit(allocator);
        const properties = try copied.getProperties(allocator);
        properties.deinit(allocator);
        try copied.deleteBlob(allocator);
        capture.bodies = &.{
            "",                                                                                 "",                      "", "", "", "",
            "<EnumerationResults><NextMarker>private-marker</NextMarker></EnumerationResults>", "<EnumerationResults/>",
        };
        const items = try container.listBlobs(allocator);
        blobs.freeBlobItems(allocator, items);
        capture.bodies = &.{};
        try container.deleteContainer(allocator);

        var generated = blobs.BlobClient.init(configuredPipeline(runtime, &provider), .{ .endpoint = endpoint });
        var generated_blob = generated.blob();
        var generated_container = generated.container();
        var block = generated.blockBlob();
        mock.response_status = 404;
        mock.response_body = "";
        try std.testing.expect(!try blobs.blobExists(&generated_blob, allocator, .{}));
        mock.response_status = 200;
        try std.testing.expect(try blobs.containerExists(&generated_container, allocator, .{}));
        mock.response_status = 201;
        try blobs.uploadBlockBlob(&block, allocator, "private-body", .{});
        try blobs.uploadBlockBlob(&block, allocator, "private-body", .{ .single_upload_max_bytes = 0, .block_size = 6 });
        mock.response_status = 200;
        mock.response_body = "private-response";
        var result = try blobs.download(&generated_blob, allocator, .{});
        defer result.deinit();
        try std.testing.expectEqualStrings("private-response", result.data);
        var buffer: [32]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try std.testing.expectEqual(@as(u64, "private-response".len), try blobs.downloadInto(&generated_blob, allocator, &writer, .{}));
        var failing_writer: std.Io.Writer = .fixed(&.{});
        try std.testing.expectError(error.WriteFailed, blobs.downloadInto(&generated_blob, allocator, &failing_writer, .{}));
    }
    try std.testing.expectEqual(@as(usize, 18), capture.count);
    try std.testing.expectEqual(@as(usize, 0), probe.calls);
    try std.testing.expectEqual(capture.count, try provider.drain(1000));
    try std.testing.expectEqual(core.tracing.SpanStatus.unset, probe.statuses[probe.count - 1]);
}

test "tracing SAS byte reader file and block stream paths including disable" {
    const Mode = enum { bytes, byte_blocks, reader, reader_blocks, file, file_blocks, block_stream, empty_stream, buffered_only };
    for (std.enums.values(Mode)) |mode| {
        for (0..3) |configuration| {
            var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
            var mock = core.http.MockTransport.init(allocator, 201, "");
            defer mock.deinit();
            var capture: Capture = .{ .mock = &mock, .require_sas = true };
            const runtime = core.http.HttpRuntime.init(
                if (mode == .buffered_only) capture.bufferedTransport() else capture.asTransport(),
                crypto.asProvider(),
            );
            var probe: Probe = .{ .capture = &capture };
            var provider = try makeProvider(runtime, &probe, 8);
            defer provider.deinit() catch unreachable;
            {
                var client = try blobs.SasBlobClient.init(allocator, sas_url, runtime);
                defer client.deinit();
                if (configuration != 0) client.setInstrumentation(instrumentation(&provider));
                if (configuration == 2) client.setInstrumentation(null);
                var reader: std.Io.Reader = .fixed("private-body");
                var empty: std.Io.Reader = .fixed("");
                const outcome = switch (mode) {
                    .bytes, .buffered_only => try client.uploadBytes("private-body", .{}),
                    .byte_blocks => try client.uploadBytes("private-body", .{ .single_upload_max_bytes = 0, .block_size = 6 }),
                    .reader => try client.uploadReader(&reader, "private-body".len, .{}),
                    .reader_blocks => try client.uploadReader(&reader, "private-body".len, .{ .single_upload_max_bytes = 0, .block_size = 6 }),
                    .file => try client.uploadFile("testdata/tracing_upload.txt", .{}),
                    .file_blocks => try client.uploadFile("testdata/tracing_upload.txt", .{ .single_upload_max_bytes = 0, .block_size = 8 }),
                    .block_stream => try client.uploadBlockStream(&reader, .{ .block_size = 6 }),
                    .empty_stream => try client.uploadBlockStream(&empty, .{ .block_size = 6 }),
                };
                try std.testing.expectEqual(@as(u16, 201), outcome.accepted.status_code);
            }
            const expected: usize = switch (mode) {
                .byte_blocks, .reader_blocks, .block_stream => 3,
                .file_blocks => 4,
                else => 1,
            };
            try std.testing.expectEqual(expected, capture.count);
            for (capture.contexts[0..capture.count]) |context|
                try std.testing.expectEqual(configuration == 1, context != null);
            try std.testing.expectEqual(@as(usize, 0), probe.calls);
            try std.testing.expectEqual(if (configuration == 1) expected else 0, try provider.drain(1000));
        }
    }
}

test "tracing SAS outcome boundaries and header-complete body failure" {
    const Mode = enum { rejected, redirect, unknown, pre_dispatch, drain_failure, incomplete, stage_rejected, commit_unknown };
    for (std.enums.values(Mode)) |mode| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 201, "private-response");
        defer mock.deinit();
        if (mode == .drain_failure) mock.stream_fail_response_after = 0;
        if (mode == .rejected) mock.response_status = 403;
        if (mode == .redirect) {
            mock.response_status = 307;
            mock.response_headers_list = &.{.{ .name = "Location", .value = "https://other.test/private-path" }};
        }
        var capture: Capture = .{
            .mock = &mock,
            .require_sas = true,
            .fail_at = if (mode == .unknown) 0 else if (mode == .commit_unknown) 2 else null,
            .statuses = if (mode == .stage_rejected) &.{ 201, 503 } else &.{},
        };
        const runtime = core.http.HttpRuntime.init(
            if (mode == .pre_dispatch) capture.bufferedTransport() else capture.asTransport(),
            crypto.asProvider(),
        );
        var probe: Probe = .{ .capture = &capture, .require_wire = mode != .pre_dispatch };
        var provider = try makeProvider(runtime, &probe, 4);
        defer provider.deinit() catch unreachable;
        {
            var client = try blobs.SasBlobClient.init(allocator, sas_url, runtime);
            defer client.deinit();
            client.setInstrumentation(instrumentation(&provider));
            var reader: std.Io.Reader = .fixed("private-body");
            switch (mode) {
                .rejected, .redirect => {
                    const result = try client.uploadBytes("private-body", .{});
                    try std.testing.expectEqual(mock.response_status, result.rejected.status_code);
                },
                .unknown => try std.testing.expectEqual(error.FixtureTransportFailure, (try client.uploadBytes("private-body", .{})).unknown.cause),
                .pre_dispatch => try std.testing.expectError(error.StreamingRequestUnsupported, client.uploadReader(&reader, "private-body".len, .{})),
                .drain_failure => try std.testing.expect((try client.uploadBytes("private-body", .{})).isAccepted()),
                .incomplete => {
                    const result = try client.uploadReader(&reader, 6, .{ .single_upload_max_bytes = 0, .block_size = 6 });
                    try std.testing.expectEqual(@as(u64, 1), result.incomplete.staged_blocks);
                },
                .stage_rejected => {
                    const result = try client.uploadBytes("private-body", .{ .single_upload_max_bytes = 0, .block_size = 6 });
                    try std.testing.expectEqual(blobs.BlobUploadPhase.put_block, result.rejected.phase);
                },
                .commit_unknown => {
                    const result = try client.uploadBytes("private-body", .{ .single_upload_max_bytes = 0, .block_size = 6 });
                    try std.testing.expectEqual(blobs.BlobUploadPhase.put_block_list, result.unknown.phase);
                },
            }
        }
        const expected: usize = switch (mode) {
            .pre_dispatch => 0,
            .stage_rejected => 2,
            .commit_unknown => 3,
            else => 1,
        };
        try std.testing.expectEqual(expected, capture.count);
        try std.testing.expectEqual(@as(usize, 0), probe.calls);
        _ = try provider.drain(1000);
        try std.testing.expectEqual(@max(expected, 1), probe.count);
        if (mode == .drain_failure or mode == .incomplete)
            try std.testing.expectEqual(core.tracing.SpanStatus.unset, probe.statuses[0]);
    }
}

test "tracing SAS allocation and exporter failures preserve outcomes without extra dispatch" {
    var propagation_failures: usize = 0;
    for (0..16) |offset| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 201, "");
        defer mock.deinit();
        var capture: Capture = .{ .mock = &mock, .require_sas = true };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 1);
        defer provider.deinit() catch unreachable;
        var failing = std.testing.FailingAllocator.init(allocator, .{});
        {
            var client = try blobs.SasBlobClient.init(failing.allocator(), sas_url, runtime);
            defer client.deinit();
            client.setInstrumentation(instrumentation(&provider));
            failing.fail_index = failing.alloc_index + offset;
            if (client.uploadBytes("private-body", .{})) |outcome| {
                try std.testing.expect(outcome.isAccepted());
                try std.testing.expectEqual(@as(usize, 1), capture.count);
                if (provider.stats().propagation_errors != 0) {
                    propagation_failures += 1;
                    probe.require_wire = false;
                    try std.testing.expect(capture.contexts[0] == null);
                }
            } else |err| {
                try std.testing.expectEqual(error.OutOfMemory, err);
                try std.testing.expectEqual(@as(usize, 0), capture.count);
            }
        }
        try std.testing.expectEqual(@as(usize, 0), probe.calls);
        _ = try provider.drain(1000);
    }
    try std.testing.expectEqual(@as(usize, 4), propagation_failures);

    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();
    var capture: Capture = .{ .mock = &mock, .require_sas = true };
    const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
    var probe: Probe = .{ .capture = &capture, .fail = true };
    var provider = try makeProvider(runtime, &probe, 1);
    defer provider.deinit() catch unreachable;
    var client = try blobs.SasBlobClient.init(allocator, sas_url, runtime);
    defer client.deinit();
    client.setInstrumentation(instrumentation(&provider));
    const outcome = try client.uploadBytes("private-body", .{ .single_upload_max_bytes = 0, .block_size = 6 });
    try std.testing.expect(outcome.isAccepted());
    try std.testing.expectEqual(@as(usize, 3), capture.count);
    try std.testing.expectEqual(@as(u64, 2), provider.stats().dropped_spans);
    try std.testing.expectEqual(@as(usize, 0), probe.calls);
    try std.testing.expectError(error.FixtureExportFailure, provider.forceFlush(1000));
    try std.testing.expectEqual(@as(u64, 1), provider.stats().export_errors);
    try std.testing.expect(outcome.isAccepted());
    try std.testing.expectEqual(@as(usize, 3), capture.count);
}
