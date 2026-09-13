const std = @import("std");
const core = @import("azure_sdk_core");
const client_mod = @import("client.zig");
const content_mod = @import("content_client.zig");
const download_mod = @import("blob_download.zig");
const digest_mod = @import("digest.zig");
const test_runtime = @import("test_runtime.zig");

const allocator = std.testing.allocator;
const endpoint = "https://registry.example";

const WireTransport = struct {
    inner: core.http.HttpTransport,
    contexts: [8]?core.tracing.TraceContext = @splat(null),
    authorized: [8]bool = @splat(false),
    count: usize = 0,
    fail: bool = false,
    fail_on: ?usize = null,

    fn asTransport(self: *@This()) core.http.HttpTransport {
        return .{ .context = self, .vtable = &.{ .send = send, .open = open } };
    }

    fn capture(self: *@This(), request: *core.http.Request) !void {
        if (self.count == self.contexts.len) return error.TooManyMockRequests;
        if (request.getHeader("traceparent")) |value| {
            self.contexts[self.count] = core.tracing.TraceContext.parseTraceparent(value) orelse
                return error.InvalidMockTraceparent;
            try std.testing.expectEqualStrings("0af7651916cd43dd8448eb211c80319c", &self.contexts[self.count].?.trace_id);
            try std.testing.expectEqualStrings("vendor=caller", request.getHeader("tracestate").?);
        } else {
            try std.testing.expect(request.getHeader("tracestate") == null);
        }
        self.authorized[self.count] = request.getHeader("Authorization") != null;
        self.count += 1;
        if (self.fail or (self.fail_on != null and self.count - 1 == self.fail_on.?))
            return error.MockUnavailable;
    }

    fn send(context: *anyopaque, request: *core.http.Request) !core.http.Response {
        const self: *@This() = @ptrCast(@alignCast(context));
        try self.capture(request);
        return self.inner.send(request);
    }

    fn open(context: *anyopaque, request: *core.http.Request, options: core.http.OpenOptions) !*core.http.HttpOperation {
        const self: *@This() = @ptrCast(@alignCast(context));
        try self.capture(request);
        return self.inner.open(request, options);
    }
};

const SpanProbe = struct {
    exporter: core.tracing.SpanExporter = .{ .exportFn = exportBatch },
    wire_ids: [8][16]u8 = undefined,
    statuses: [8]?u16 = @splat(200),
    methods: [8][]const u8 = @splat("GET"),
    count: usize = 0,

    fn exportBatch(exporter: *core.tracing.SpanExporter, spans: []const core.tracing.SpanData, _: core.tracing.ExportContext) !void {
        const self: *@This() = @fieldParentPtr("exporter", exporter);
        for (spans) |span| {
            try std.testing.expect(self.count < self.wire_ids.len);
            const expected_status = self.statuses[self.count];
            try std.testing.expectEqualStrings("caller.registry", span.scope_name);
            try std.testing.expectEqualStrings("custom-1", span.scope_version);
            try std.testing.expectEqualStrings("HTTP", span.name);
            try std.testing.expectEqual(core.tracing.SpanKind.client, span.kind);
            try std.testing.expectEqual(
                if (expected_status == null or expected_status.? >= 400) core.tracing.SpanStatus.@"error" else .unset,
                span.status,
            );
            try std.testing.expectEqualStrings("b7ad6b7169203331", &span.parent_span_id.?);
            try std.testing.expectEqualStrings("0af7651916cd43dd8448eb211c80319c", &span.context.trace_id);
            try std.testing.expectEqualStrings(&self.wire_ids[self.count], &span.context.span_id);
            var namespace = false;
            var method = false;
            var status = false;
            var transport_error = false;
            for (span.attributes) |attribute| {
                if (std.mem.eql(u8, attribute.key, "az.namespace")) {
                    try std.testing.expectEqualStrings("Caller.Namespace", attribute.value.string);
                    namespace = true;
                }
                if (std.mem.eql(u8, attribute.key, "http.request.method")) {
                    try std.testing.expectEqualStrings(self.methods[self.count], attribute.value.string);
                    method = true;
                }
                if (std.mem.eql(u8, attribute.key, "http.response.status_code")) {
                    try std.testing.expectEqual(@as(i64, expected_status.?), attribute.value.int);
                    status = true;
                }
                if (expected_status == null and std.mem.eql(u8, attribute.key, "error.type")) {
                    try std.testing.expectEqualStrings("MockUnavailable", attribute.value.string);
                    transport_error = true;
                }
                try std.testing.expect(!std.mem.eql(u8, attribute.key, "url.full"));
                if (attribute.value == .string)
                    try std.testing.expect(std.mem.indexOf(u8, attribute.value.string, "signature") == null);
            }
            try std.testing.expect(namespace and method);
            try std.testing.expectEqual(expected_status != null, status);
            try std.testing.expectEqual(expected_status == null, transport_error);
            self.count += 1;
        }
    }
};

fn instrumentation(provider: *core.tracing.ExportingTracerProvider) core.tracing.InstrumentationOptions {
    var parent = core.tracing.TraceContext.parseTraceparent("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01").?;
    parent.trace_state = "vendor=caller";
    return .{
        .provider = provider.asProvider(),
        .scope_name = "caller.registry",
        .scope_version = "custom-1",
        .namespace = "Caller.Namespace",
        .parent_context = parent,
    };
}

fn expectCopies(client: *client_mod.ContainerRegistryClient) !void {
    const protocol = client.protocolClient();
    try std.testing.expectEqualDeep(client.pipeline, protocol.pipeline);
    inline for (.{ "containerRegistry", "containerRegistryBlob", "authentication" }) |name| {
        const group = @call(.auto, @field(@TypeOf(protocol.*), name), .{protocol});
        try std.testing.expectEqualDeep(client.pipeline, group.pipeline);
    }
    var repositories = try client.listRepositories(allocator, .{});
    defer repositories.deinit();
    var manifests = try client.listManifestProperties(allocator, "team/app", .{});
    defer manifests.deinit();
    var tags = try client.listTagProperties(allocator, "team/app", .{});
    defer tags.deinit();
    try std.testing.expectEqualDeep(client.pipeline, repositories.pipeline);
    try std.testing.expectEqualDeep(client.pipeline, manifests.pipeline);
    try std.testing.expectEqualDeep(client.pipeline, tags.pipeline);
}

fn expectCallerFlush(provider: *core.tracing.ExportingTracerProvider, probe: *SpanProbe, count: usize) !void {
    try std.testing.expectEqual(count, provider.stats().started);
    try std.testing.expectEqual(count, provider.stats().ended);
    try std.testing.expectEqual(@as(usize, 0), provider.stats().active_spans);
    try std.testing.expectEqual(@as(usize, 0), probe.count);
    try std.testing.expect(!provider.closed);
    try provider.forceFlush(1000);
    try std.testing.expectEqual(count, probe.count);
    try provider.shutdown(1000);
}

test "optional tracing preserves wrapper copies, generated clients and service results" {
    const Mode = enum { default, enabled, disabled, forbidden, not_found, transport_error };
    for ([_]Mode{ .default, .enabled, .disabled, .forbidden, .not_found, .transport_error }) |mode| {
        const traced = mode != .default and mode != .disabled;
        var mock = core.http.MockTransport.init(
            allocator,
            if (mode == .forbidden) 403 else if (mode == .not_found) 404 else 202,
            "{\"errors\":[{\"code\":\"DENIED\",\"message\":\"access denied\"}]}",
        );
        defer mock.deinit();
        var wire: WireTransport = .{ .inner = mock.asTransport(), .fail = mode == .transport_error };
        const runtime = test_runtime.init(wire.asTransport());
        var probe: SpanProbe = .{};
        probe.methods[0] = "DELETE";
        probe.statuses[0] = if (wire.fail) null else mock.response_status;
        var provider = try core.tracing.ExportingTracerProvider.init(allocator, std.testing.io, runtime.crypto, &probe.exporter, .{});
        defer provider.deinit() catch unreachable;
        {
            var options: client_mod.ContainerRegistryClientOptions = .{ .runtime = runtime, .authentication = .anonymous };
            try std.testing.expect(options.instrumentation == null);
            if (mode != .default) options.instrumentation = instrumentation(&provider);
            if (mode == .disabled) options.instrumentation = null;
            var client = try client_mod.ContainerRegistryClient.init(allocator, endpoint, options);
            defer client.deinit();
            var content = try content_mod.ContainerRegistryContentClient.init(allocator, endpoint, "team/app", options);
            defer content.deinit();
            var blobs = try download_mod.BlobDownloadClient.init(allocator, endpoint, "team/app", options);
            defer blobs.deinit();
            try std.testing.expectEqualDeep(options.instrumentation, client.pipeline.instrumentation);
            try std.testing.expectEqualDeep(options.instrumentation, content.registry_client.pipeline.instrumentation);
            try std.testing.expectEqualDeep(options.instrumentation, blobs.registry_client.pipeline.instrumentation);
            options.instrumentation = null;
            try expectCopies(&client);
            try expectCopies(&content.registry_client);
            try expectCopies(&blobs.registry_client);
            if (wire.fail) {
                try std.testing.expectError(error.MockUnavailable, client.deleteRepository(allocator, "team/app"));
            } else {
                var result = try client.deleteRepository(allocator, "team/app");
                defer result.deinit();
                if (mode == .forbidden) {
                    try std.testing.expect(result == .err);
                    try std.testing.expectEqual(@as(u16, 403), result.err.status_code);
                    try std.testing.expectEqualStrings("DENIED", result.err.code.?);
                } else {
                    try std.testing.expectEqual(
                        if (mode == .not_found) client_mod.DeleteOutcome.not_found else .accepted,
                        result.ok,
                    );
                }
                try std.testing.expectEqual(core.http.Method.DELETE, mock.last_method);
                try std.testing.expect(mock.last_headers.get("User-Agent") == null);
            }
            try std.testing.expectEqual(traced, wire.contexts[0] != null);
            try std.testing.expect(!wire.authorized[0]);
            if (traced) probe.wire_ids[0] = wire.contexts[0].?.span_id;
            if (mode == .enabled) {
                mock.response_status = 200;
                var service = client.protocolClient().containerRegistry();
                try service.checkDockerV2Support(allocator);
                probe.wire_ids[1] = wire.contexts[1].?.span_id;
            }
        }
        try expectCallerFlush(&provider, &probe, if (mode == .enabled) 2 else if (traced) 1 else 0);
    }
}

test "Link pager retains complete tracing and emits distinct page spans" {
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Link", .value = "</acr/v1/_catalog?last=first>; rel=\"next\"" },
    };
    var mock = core.http.MockTransport.init(allocator, 200, "{\"repositories\":[\"first\"]}");
    defer mock.deinit();
    mock.response_headers_list = &headers;
    var wire: WireTransport = .{ .inner = mock.asTransport() };
    const runtime = test_runtime.init(wire.asTransport());
    var probe: SpanProbe = .{};
    var provider = try core.tracing.ExportingTracerProvider.init(allocator, std.testing.io, runtime.crypto, &probe.exporter, .{});
    defer provider.deinit() catch unreachable;
    {
        var client = try client_mod.ContainerRegistryClient.init(allocator, endpoint, .{
            .runtime = runtime,
            .authentication = .anonymous,
            .instrumentation = instrumentation(&provider),
        });
        defer client.deinit();
        var pager = try client.listRepositories(allocator, .{ .max_results = 1 });
        defer pager.deinit();
        try std.testing.expectEqualDeep(client.pipeline, pager.pipeline);
        client.pipeline.setInstrumentation(null);
        var first = (try pager.next()).?;
        defer first.deinit();
        try std.testing.expectEqualStrings("first", first.ok.names[0]);
        mock.response_body = "{\"repositories\":[\"second\"]}";
        mock.response_headers_list = &.{};
        var second = (try pager.next()).?;
        defer second.deinit();
        try std.testing.expectEqualStrings("second", second.ok.names[0]);
        try std.testing.expectEqualStrings(endpoint ++ "/acr/v1/_catalog?last=first", mock.last_url.?);
        try std.testing.expect((try pager.next()) == null);
        for (0..2) |i| probe.wire_ids[i] = wire.contexts[i].?.span_id;
        try std.testing.expect(!std.mem.eql(u8, &probe.wire_ids[0], &probe.wire_ids[1]));
    }
    try expectCallerFlush(&provider, &probe, 2);
}

test "buffered and streaming challenge replay share one logical span and restore owned headers" {
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{
            .name = "WWW-Authenticate",
            .value = "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"registry:catalog:*\"",
        },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{ .status = 200, .body = "{\"access_token\":\"e30.eyJleHAiOjQxMDI0NDQ4MDB9.signature\"}" },
        .{ .status = 200, .body = "{}" },
        .{ .status = 200, .body = "{}" },
        .{ .status = 200, .body = "{}" },
    };
    for ([_]struct { streaming: bool, fail_replay: bool }{
        .{ .streaming = false, .fail_replay = false },
        .{ .streaming = true, .fail_replay = false },
        .{ .streaming = false, .fail_replay = true },
        .{ .streaming = true, .fail_replay = true },
    }) |mode| {
        var mock = core.http.SequenceMockTransport.init(allocator, &responses);
        var wire: WireTransport = .{
            .inner = mock.asTransport(),
            .fail_on = if (mode.fail_replay) 2 else null,
        };
        const runtime = test_runtime.init(wire.asTransport());
        var probe: SpanProbe = .{};
        if (mode.fail_replay) probe.statuses[0] = null;
        var provider = try core.tracing.ExportingTracerProvider.init(allocator, std.testing.io, runtime.crypto, &probe.exporter, .{});
        defer provider.deinit() catch unreachable;
        {
            var client = try client_mod.ContainerRegistryClient.init(allocator, endpoint, .{
                .runtime = runtime,
                .authentication = .anonymous,
                .instrumentation = instrumentation(&provider),
            });
            defer client.deinit();
            var request = core.http.Request.init(allocator, .GET, endpoint ++ "/v2/_catalog");
            defer request.deinit();
            const original_parent = "00-11111111111111111111111111111111-2222222222222222-01";
            try request.setHeader("traceparent", original_parent);
            try request.setHeader("tracestate", "vendor=original");
            try request.setHeader("X-Unrelated", "retained");
            for (0..3) |i| {
                if (i == 2) try request.setHeader("Authorization", "Custom caller-owned");
                if (mode.fail_replay and i == 0) {
                    if (mode.streaming) {
                        try std.testing.expectError(error.MockUnavailable, client.pipeline.open(&request, .{}));
                    } else {
                        try std.testing.expectError(error.MockUnavailable, client.pipeline.send(&request));
                    }
                } else if (mode.streaming) {
                    var operation = try client.pipeline.open(&request, .{});
                    defer operation.deinit();
                    try std.testing.expectEqual(@as(u16, 200), operation.status_code);
                    try operation.finish();
                } else {
                    var response = try client.pipeline.send(&request);
                    defer response.deinit();
                    try std.testing.expectEqual(@as(u16, 200), response.status_code);
                }
                if (i == 2) {
                    try std.testing.expectEqualStrings("Custom caller-owned", request.getHeader("Authorization").?);
                } else {
                    try std.testing.expect(request.getHeader("Authorization") == null);
                }
                try std.testing.expectEqualStrings(original_parent, request.getHeader("traceparent").?);
                try std.testing.expectEqualStrings("vendor=original", request.getHeader("tracestate").?);
                try std.testing.expectEqualStrings("retained", request.getHeader("X-Unrelated").?);
            }
            try std.testing.expectEqual(@as(usize, 5), wire.count);
            try std.testing.expectEqualDeep(wire.contexts[0], wire.contexts[2]);
            try std.testing.expect(wire.contexts[1] == null);
            try std.testing.expect(!wire.authorized[0] and wire.authorized[2] and wire.authorized[3] and wire.authorized[4]);
            probe.wire_ids[0] = wire.contexts[0].?.span_id;
            probe.wire_ids[1] = wire.contexts[3].?.span_id;
            probe.wire_ids[2] = wire.contexts[4].?.span_id;
            try std.testing.expect(!std.mem.eql(u8, &probe.wire_ids[0], &probe.wire_ids[1]));
        }
        try expectCallerFlush(&provider, &probe, 3);
    }
}

test "content and blob wrappers trace actual operations with streaming spans ending at headers" {
    const bytes = "abc";
    const digest = try digest_mod.computeSha256Digest(test_runtime.crypto(), bytes);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Content-Length", .value = "3" },
        .{ .name = "Docker-Content-Digest", .value = &digest },
    };
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();
    mock.response_headers_list = &headers;
    var wire: WireTransport = .{ .inner = mock.asTransport() };
    const runtime = test_runtime.init(wire.asTransport());
    var probe: SpanProbe = .{};
    probe.statuses[0] = 201;
    probe.methods[0] = "PUT";
    var provider = try core.tracing.ExportingTracerProvider.init(allocator, std.testing.io, runtime.crypto, &probe.exporter, .{});
    defer provider.deinit() catch unreachable;
    {
        const options: client_mod.ContainerRegistryClientOptions = .{
            .runtime = runtime,
            .authentication = .anonymous,
            .instrumentation = instrumentation(&provider),
        };
        var content = try content_mod.ContainerRegistryContentClient.init(allocator, endpoint, "team/app", options);
        defer content.deinit();
        var manifest = try content.uploadManifest(bytes, .{});
        defer manifest.deinit(allocator);
        try std.testing.expectEqualStrings(&digest, manifest.digest);
        try std.testing.expectEqual(@as(usize, 1), mock.stream_finish_count);
        mock.response_status = 200;
        mock.response_body = bytes;
        var blobs = try download_mod.BlobDownloadClient.init(allocator, endpoint, "team/app", options);
        defer blobs.deinit();
        var stream = try blobs.downloadBlobStreaming(&digest, .{});
        defer stream.deinit();
        try std.testing.expectEqual(@as(usize, 2), provider.stats().ended);
        try std.testing.expectEqual(@as(usize, 0), provider.stats().active_spans);
        try std.testing.expectEqual(@as(usize, 0), probe.count);
        try std.testing.expectEqual(@as(usize, 1), mock.stream_finish_count);
        var buffer: [3]u8 = undefined;
        try std.testing.expectEqual(@as(usize, 3), try (try stream.reader()).readSliceShort(&buffer));
        try std.testing.expectEqualStrings(bytes, &buffer);
        try stream.finish();
        try std.testing.expectEqualStrings(&digest, &(try stream.computedDigest()));
        try std.testing.expectEqual(@as(usize, 2), mock.stream_finish_count);
        for (0..2) |i| probe.wire_ids[i] = wire.contexts[i].?.span_id;
    }
    try expectCallerFlush(&provider, &probe, 2);
}
