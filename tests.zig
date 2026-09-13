const std = @import("std");
const adapter = @import("azure_sdk_core_httpx");
const core = adapter.core;
const httpx = @import("httpx");
const backend = @import("test_backend.zig");
const interruption = @import("interruption_fixture.zig");
const conformance = backend.conformance;
const allocator = std.testing.allocator;
const io = std.testing.io;

test "canonical HTTPX module identity" {
    try std.testing.expect(adapter.httpx.Client == httpx.Client);
    try std.testing.expect(adapter.httpx.tls.TLSConfig == httpx.tls.TLSConfig);
}

fn cancelledAllocationFixture(test_allocator: std.mem.Allocator) !void {
    var instance = try backend.factory().create(test_allocator, io, .{
        .fixture_allocator = allocator,
        .allow_peer_failure = true,
        .response = .{ .body = "cancel response" },
    });
    defer instance.deinit();
    var request = core.http.Request.init(test_allocator, .GET, instance.url);
    defer request.deinit();
    var token = core.http.CancellationToken{};
    {
        const operation = try instance.transport.open(&request, .{ .cancellation = &token });
        defer operation.deinit();
        operation.cancel();
    }
    try instance.assertQuiescent();
    try instance.finish();
}

test "allocation failure with cancellation bridge releases every resource" {
    try std.testing.checkAllAllocationFailures(allocator, cancelledAllocationFixture, .{});
}

test "published Core raw transport conformance" {
    try conformance.runRawTransportContracts(allocator, io, backend.factory());
}

test "published Core per-phase interruption evidence" {
    var report: interruption.Report = .{};
    var factory = backend.factory();
    factory.context = &report;
    try conformance.runInterruptionContracts(allocator, io, factory);
    try std.testing.expectEqual(@as(usize, 10), report.count);
    for (report.samples[0..report.count]) |sample| {
        const evidence = sample.evidence;
        std.debug.print("interruption {s}/{s}: {s}, {d}ms, entered={}, started={}, close={d}, live={d}, leased={d}, connect={d}, ping={d}, upload={d}, credit={d}\n", .{
            @tagName(sample.phase),
            @tagName(sample.trigger),
            @errorName(evidence.outcome),
            evidence.elapsed_ms,
            evidence.phase_entered,
            evidence.transport_started,
            evidence.cleanup_count,
            evidence.live_operations,
            evidence.leased_connections,
            sample.connect_requests,
            sample.ping_acks,
            sample.uploaded_bytes,
            sample.body_credit,
        });
    }
}

test "unproved upload_read interruption remains unadvertised" {
    const factory = backend.factory();
    try std.testing.expect(!factory.capabilities.interruption.token.contains(.upload_read));
    try std.testing.expect(!factory.capabilities.interruption.deadline.contains(.upload_read));
    for (std.meta.tags(conformance.InterruptionTrigger)) |trigger| {
        try std.testing.expectError(error.UnsupportedInterruptionPair, interruption.run(null, allocator, io, .upload_read, trigger));
    }
}

test "published Core pipeline attempt ownership" {
    try conformance.runPipelineContracts(allocator, io, backend.factory());
}

test "published Core adapter allocation failure cleanup" {
    try conformance.runBackendAllocationFailureContracts(allocator, io, backend.factory());
}

test "configuration rejects ambient credentials and unauthenticated TLS" {
    try std.testing.expectError(error.TlsVerificationRequired, adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .verify_ssl = false },
    }));
    try std.testing.expectError(error.TlsVerificationRequired, adapter.HttpxTransport.init(allocator, io, .{
        .operation = .{ .verify_ssl = false },
    }));
    try std.testing.expectError(error.AzureOwnsRequestOptions, adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .default_headers = &.{.{ "Authorization", "test" }} },
    }));
    try std.testing.expectError(error.AzureOwnsRequestOptions, adapter.HttpxTransport.init(allocator, io, .{
        .operation = .{ .bearer_token = "test" },
    }));
}

test "all Core methods and no synthesized policy headers" {
    for (std.meta.tags(core.http.Method)) |method| {
        var instance = try backend.factory().create(allocator, io, .{});
        defer instance.deinit();
        var request = core.http.Request.init(allocator, method, instance.url);
        defer request.deinit();
        var response = try instance.transport.send(&request);
        defer response.deinit();
        try instance.finish();
        const observation = instance.observe();
        const space = std.mem.indexOfScalar(u8, observation.request_line, ' ') orelse return error.MissingMethod;
        try std.testing.expectEqualStrings(@tagName(method), observation.request_line[0..space]);
        try std.testing.expectEqual(@as(usize, 0), observation.user_agent_count);
        try std.testing.expectEqual(@as(usize, 0), observation.accept_encoding_count);
    }
}

test "expired Azure operation budget never becomes unlimited" {
    var transport = try adapter.HttpxTransport.init(allocator, io, .{});
    defer transport.deinit();
    var request = core.http.Request.init(allocator, .GET, "http://127.0.0.1:1/");
    defer request.deinit();
    request.operation_timeout_ms = 0;
    try std.testing.expectError(error.OperationTimedOut, transport.asTransport().open(&request, .{}));
    try std.testing.expect(request.transport_started);
    try std.testing.expectEqual(@as(usize, 0), transport.live_operations);
}

const MemoryPeer = struct {
    responses: []const []const u8,
    wire: std.ArrayList(u8) = .empty,
    response_offset: usize = 0,
    attempt_start: usize = 0,
    completed: [16][]const u8 = undefined,
    reused: [16]bool = undefined,
    closes: usize = 0,

    fn asBackend(self: *MemoryPeer) httpx.TransportAdapter {
        return .{ .context = self, .readFn = read, .writeFn = write, .closeFn = close };
    }

    fn write(context: *anyopaque, bytes: []const u8) !usize {
        const self: *MemoryPeer = @ptrCast(@alignCast(context));
        try self.wire.appendSlice(allocator, bytes);
        return bytes.len;
    }

    fn read(context: *anyopaque, bytes: []u8) !usize {
        const self: *MemoryPeer = @ptrCast(@alignCast(context));
        if (self.closes >= self.responses.len) return error.UnexpectedAttempt;
        const response = self.responses[self.closes];
        const count = @min(bytes.len, response.len - self.response_offset);
        @memcpy(bytes[0..count], response[self.response_offset..][0..count]);
        self.response_offset += count;
        return count;
    }

    fn close(context: *anyopaque, reusable: bool) void {
        const self: *MemoryPeer = @ptrCast(@alignCast(context));
        std.debug.assert(self.closes < self.completed.len);
        self.completed[self.closes] = allocator.dupe(u8, self.wire.items[self.attempt_start..]) catch @panic("test allocation");
        self.reused[self.closes] = reusable;
        self.closes += 1;
        self.attempt_start = self.wire.items.len;
        self.response_offset = 0;
    }

    fn deinit(self: *MemoryPeer) void {
        for (self.completed[0..self.closes]) |bytes| allocator.free(bytes);
        self.wire.deinit(allocator);
    }
};

const empty_response = "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n";
const body_response = "HTTP/1.1 200 OK\r\nContent-Length: 4\r\n\r\nbody";

test "explicit streaming zero and inherited client limits are not unlimited" {
    const cases = [_]struct { limit: httpx.ResponseLimit, client_limit: u64, fails: bool }{
        .{ .limit = .{ .bytes = 0 }, .client_limit = 0, .fails = true },
        .{ .limit = .inherit, .client_limit = 3, .fails = true },
        .{ .limit = .unlimited, .client_limit = 3, .fails = false },
        .{ .limit = .inherit, .client_limit = 0, .fails = false },
    };
    for (cases) |case| {
        var peer = MemoryPeer{ .responses = &.{body_response} };
        defer peer.deinit();
        var native_backend = peer.asBackend();
        var transport = try adapter.HttpxTransport.init(allocator, io, .{
            .client = .{ .transport_adapter = &native_backend, .max_response_size = case.client_limit },
            .operation = .{ .response_limit = case.limit },
        });
        defer transport.deinit();
        var request = core.http.Request.init(allocator, .GET, "http://127.0.0.1/");
        defer request.deinit();
        // HTTPX may enforce a declared-length limit while obtaining the head.
        const result = transport.asTransport().open(&request, .{});
        if (result) |operation| {
            defer operation.deinit();
            if (case.fails) {
                try std.testing.expectError(error.StreamTooLong, operation.finish());
                try std.testing.expectEqual(core.http.OperationState.aborted, operation.state);
            } else {
                try operation.finish();
            }
        } else |err| {
            try std.testing.expect(case.fails);
            try std.testing.expectEqual(error.StreamTooLong, err);
        }
        try std.testing.expectEqual(@as(usize, 1), peer.closes);
        try std.testing.expectEqual(@as(usize, 0), native_backend.lease_lock.load(.acquire));
    }
}

test "explicit empty response limit accepts an empty response" {
    var peer = MemoryPeer{ .responses = &.{empty_response} };
    defer peer.deinit();
    var native_backend = peer.asBackend();
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .transport_adapter = &native_backend },
        .operation = .{ .response_limit = .{ .bytes = 0 } },
    });
    defer transport.deinit();
    var request = core.http.Request.init(allocator, .GET, "http://127.0.0.1/");
    defer request.deinit();
    var response = try transport.asTransport().send(&request);
    defer response.deinit();
    try std.testing.expectEqual(@as(usize, 0), response.body.len);
}

test "operations own request metadata and borrowed upload is consumed only during open" {
    var peer = MemoryPeer{ .responses = &.{body_response} };
    defer peer.deinit();
    var native_backend = peer.asBackend();
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .transport_adapter = &native_backend },
    });
    defer transport.deinit();
    const operation = blk: {
        const url = try allocator.dupe(u8, "http://127.0.0.1/");
        defer allocator.free(url);
        var request = core.http.Request.init(allocator, .POST, url);
        defer request.deinit();
        try request.setHeader("X-Owned", "request");
        var source = std.Io.Reader.fixed("upload");
        break :blk try transport.asTransport().open(&request, .{
            .body = core.http.StreamingRequestBody.knownLength(&source, 6),
        });
    };
    defer operation.deinit();
    const bytes = try (try operation.reader()).allocRemaining(allocator, .unlimited);
    defer allocator.free(bytes);
    try std.testing.expectEqualStrings("body", bytes);
    try operation.finish();
}

const DelayedHandler = struct {
    // Set before starting the server; cleared only after its thread joins.
    var token: ?*core.http.CancellationToken = null;
    var entered: std.atomic.Value(bool) = .init(false);

    fn respond(ctx: *httpx.Context) !httpx.Response {
        entered.store(true, .release);
        if (token) |value| value.cancel();
        try std.Io.sleep(io, .fromMilliseconds(150), .awake);
        return ctx.text("delayed");
    }
};

fn ignoreExpectedDisconnect(level: httpx.server_mod.LogLevel, message: []const u8) void {
    if (std.mem.indexOf(u8, message, "ConnectionResetByPeer") != null or
        std.mem.indexOf(u8, message, "BrokenPipe") != null) return;
    std.debug.print("HTTPX fixture {s}: {s}\n", .{ @tagName(level), message });
}

test "native cancellation while waiting for headers and whole-operation timeout" {
    for ([_]bool{ false, true }) |cancel| {
        var token = core.http.CancellationToken{};
        DelayedHandler.token = if (cancel) &token else null;
        DelayedHandler.entered.store(false, .release);
        defer DelayedHandler.token = null;
        var server = httpx.Server.initWithConfig(allocator, .{
            .port = 0,
            .log_level = .err,
            .log_fn = ignoreExpectedDisconnect,
            .shutdown_timeout_ms = 1000,
        });
        defer server.deinit();
        try server.get("/delayed", DelayedHandler.respond);
        const thread = try startServer(&server);
        defer {
            server.stop();
            thread.join();
        }
        const url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/delayed", .{server.listeningPort()});
        defer allocator.free(url);
        var transport = try adapter.HttpxTransport.init(allocator, io, .{
            .operation = .{
                .timeouts = .{ .request_ms = if (cancel) 2000 else 40 },
                .timeout_ms = 2000,
            },
        });
        defer transport.deinit();
        var request = core.http.Request.init(allocator, .GET, url);
        defer request.deinit();
        const start = std.Io.Timestamp.now(io, .awake).toNanoseconds();
        try std.testing.expectError(
            if (cancel) error.OperationCancelled else error.OperationTimedOut,
            transport.asTransport().open(&request, .{ .cancellation = if (cancel) &token else null }),
        );
        const elapsed = std.Io.Timestamp.now(io, .awake).toNanoseconds() - start;
        try std.testing.expect(DelayedHandler.entered.load(.acquire));
        try std.testing.expect(request.transport_started);
        try std.testing.expect(elapsed < std.time.ns_per_s);
        try std.testing.expectEqual(@as(usize, 0), transport.live_operations);
        try std.testing.expectEqual(@as(usize, 0), transport.poolStats().active);
    }
}

test "canonical cancellation token remains effective beside the Core token" {
    var peer = MemoryPeer{ .responses = &.{body_response} };
    defer peer.deinit();
    var native_backend = peer.asBackend();
    var native_token = httpx.CancellationToken{};
    var core_token = core.http.CancellationToken{};
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .transport_adapter = &native_backend },
        .operation = .{ .cancel_token = &native_token },
    });
    defer transport.deinit();
    var request = core.http.Request.init(allocator, .GET, "http://127.0.0.1/");
    defer request.deinit();
    native_token.cancel();
    try std.testing.expectError(error.OperationCancelled, transport.asTransport().open(&request, .{
        .cancellation = &core_token,
    }));
    try std.testing.expectEqual(@as(usize, 0), transport.live_operations);
}

test "first concrete response error survives reader and finish" {
    var peer = MemoryPeer{ .responses = &.{"HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\nshort"} };
    defer peer.deinit();
    var native_backend = peer.asBackend();
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .transport_adapter = &native_backend },
    });
    defer transport.deinit();
    var request = core.http.Request.init(allocator, .GET, "http://127.0.0.1/");
    defer request.deinit();
    var operation = try transport.asTransport().open(&request, .{});
    defer operation.deinit();
    var bytes: [32]u8 = undefined;
    try std.testing.expectError(error.ReadFailed, (try operation.reader()).readSliceShort(&bytes));
    try std.testing.expectEqual(error.HttpContentLengthTruncated, operation.bodyError().?);
    try std.testing.expectError(error.HttpContentLengthTruncated, operation.finish());
    operation.cancel();
    try std.testing.expectEqual(@as(usize, 1), peer.closes);
    try std.testing.expect(!peer.reused[0]);
}

test "drain and trailers complete before reuse and abort discards" {
    var peer = MemoryPeer{ .responses = &.{
        "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nbody\r\n0\r\nX-Trailer: complete\r\n\r\n",
        body_response,
        empty_response,
    } };
    defer peer.deinit();
    var native_backend = peer.asBackend();
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .transport_adapter = &native_backend },
    });
    defer transport.deinit();
    var request = core.http.Request.init(allocator, .GET, "http://127.0.0.1/");
    defer request.deinit();
    for (0..3) |attempt| {
        const operation = try transport.asTransport().open(&request, .{});
        defer operation.deinit();
        if (attempt == 1) operation.abort() else try operation.finish();
        if (attempt == 0) {
            const trailers = (try transport.trailers(operation)).?;
            try std.testing.expectEqualStrings("complete", trailers.get("X-Trailer").?);
            try std.testing.expect(operation.getHeader("X-Trailer") == null);
        }
    }
    try std.testing.expectEqual(@as(usize, 3), peer.closes);
    try std.testing.expect(peer.reused[0]);
    try std.testing.expect(!peer.reused[1]);
    try std.testing.expect(peer.reused[2]);
}

test "Core redirect stripping reaches HTTPX unchanged in deterministic wire mock" {
    // Synthetic HTTPS bytes exercise policy composition, not TLS verification.
    var peer = MemoryPeer{ .responses = &.{
        "HTTP/1.1 307 Temporary Redirect\r\nLocation: https://127.0.0.2/next\r\nSet-Cookie: ambient=forbidden\r\nContent-Length: 0\r\n\r\n",
        empty_response,
    } };
    defer peer.deinit();
    var native_backend = peer.asBackend();
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .transport_adapter = &native_backend, .policy = .managed() },
        .operation = .{ .policy = .{ .cookies = .send_and_store, .redirect = .{ .policy = .{} } } },
    });
    defer transport.deinit();
    var request = core.http.Request.init(allocator, .POST, "https://127.0.0.1/start");
    defer request.deinit();
    try request.setHeader("Authorization", "Bearer synthetic");
    try request.setHeader("Proxy-Authorization", "Basic synthetic");
    try request.setHeader("Cookie", "explicit=test");
    try request.setHeader("traceparent", "managed");
    request.tracing_headers_managed = true;
    var replay = core.http.ReplayableBytes.init("upload");
    const operation = try transport.asTransport().open(&request, .{ .body = replay.body() });
    defer operation.deinit();
    try operation.finish();
    try std.testing.expect(request.transport_started);
    try std.testing.expectEqual(@as(usize, 2), peer.closes);
    try std.testing.expect(std.mem.indexOf(u8, peer.completed[0], "Bearer synthetic") != null);
    try std.testing.expect(std.mem.indexOf(u8, peer.completed[1], "Authorization:") == null);
    try std.testing.expect(std.mem.indexOf(u8, peer.completed[1], "Cookie:") == null);
    try std.testing.expect(std.mem.indexOf(u8, peer.completed[1], "traceparent:") == null);
    try std.testing.expect(std.mem.endsWith(u8, peer.completed[1], "upload"));
}

test "disabled redirects and retries produce exactly one HTTPX attempt" {
    for ([_][]const u8{
        "HTTP/1.1 307 Temporary Redirect\r\nLocation: https://127.0.0.2/next\r\nContent-Length: 0\r\n\r\n",
        "HTTP/1.1 503 Unavailable\r\nRetry-After: 0\r\nContent-Length: 0\r\n\r\n",
    }) |response| {
        var peer = MemoryPeer{ .responses = &.{response} };
        defer peer.deinit();
        var native_backend = peer.asBackend();
        var transport = try adapter.HttpxTransport.init(allocator, io, .{
            .client = .{ .transport_adapter = &native_backend, .policy = .managed() },
        });
        defer transport.deinit();
        var request = core.http.Request.init(allocator, .GET, "https://127.0.0.1/");
        defer request.deinit();
        request.redirect_policy = .not_allowed;
        var result = try transport.asTransport().send(&request);
        defer result.deinit();
        try std.testing.expectEqual(@as(usize, 1), peer.closes);
    }
}

test "Expect early final response does not consume borrowed upload" {
    var peer = MemoryPeer{ .responses = &.{"HTTP/1.1 417 Expectation Failed\r\nContent-Length: 0\r\n\r\n"} };
    defer peer.deinit();
    var native_backend = peer.asBackend();
    var transport = try adapter.HttpxTransport.init(allocator, io, .{
        .client = .{ .transport_adapter = &native_backend },
    });
    defer transport.deinit();
    var request = core.http.Request.init(allocator, .POST, "http://127.0.0.1/");
    defer request.deinit();
    try request.setHeader("Expect", "100-continue");
    var source = std.Io.Reader.fixed("not-sent");
    const operation = try transport.asTransport().open(&request, .{
        .body = core.http.StreamingRequestBody.knownLength(&source, 8),
    });
    defer operation.deinit();
    try std.testing.expectEqual(@as(u16, 417), operation.status_code);
    try std.testing.expectEqual(@as(usize, 0), source.seek);
    try operation.finish();
    try std.testing.expect(!peer.reused[0]);
}

test "HTTP3 Unix HTTP2 and Unix TLS are explicitly rejected" {
    const cases = [_]struct { options: adapter.Options, url: []const u8, err: anyerror }{
        .{ .options = .{ .client = .{ .http3_enabled = true } }, .url = "http://127.0.0.1/", .err = error.UnsupportedHttpVersion },
        .{ .options = .{ .client = .{ .unix_socket_path = "unused", .http2_enabled = true } }, .url = "http://127.0.0.1/", .err = error.UnsupportedStreamingTransport },
        .{ .options = .{ .operation = .{ .unix_socket_path = "unused" } }, .url = "https://127.0.0.1/", .err = error.UnsupportedStreamingTransport },
    };
    for (cases) |case| {
        var transport = try adapter.HttpxTransport.init(allocator, io, case.options);
        defer transport.deinit();
        var request = core.http.Request.init(allocator, .GET, case.url);
        defer request.deinit();
        try std.testing.expectError(case.err, transport.asTransport().open(&request, .{}));
        try std.testing.expectEqual(@as(usize, 0), transport.poolStats().active);
    }
}

test "strict DNS validates the final proxy and no_proxy route without lookup" {
    const cases = [_]struct { proxy: ?httpx.Proxy, url: []const u8 }{
        .{ .proxy = null, .url = "http://not-a-real-host.invalid/" },
        .{ .proxy = .{ .host = "not-a-real-proxy.invalid", .port = 1 }, .url = "http://127.0.0.1/" },
        .{ .proxy = .{ .host = "127.0.0.1", .port = 1, .no_proxy = "*" }, .url = "http://not-a-real-host.invalid/" },
    };
    for (cases) |case| {
        var transport = try adapter.HttpxTransport.init(allocator, io, .{ .client = .{ .proxy = case.proxy } });
        defer transport.deinit();
        var request = core.http.Request.init(allocator, .GET, case.url);
        defer request.deinit();
        try std.testing.expectError(error.SystemDnsCancellationUnsupported, transport.asTransport().open(&request, .{}));
    }
}

fn echoProtocol(ctx: *httpx.Context) !httpx.Response {
    var response = try ctx.text(ctx.request.body orelse "");
    errdefer response.deinit();
    try response.headers.append("X-Protocol", ctx.request.version.toString());
    return response;
}

fn startServer(server: *httpx.Server) !std.Thread {
    const thread = try server.listenInBackground();
    errdefer {
        server.stop();
        thread.join();
    }
    const start = std.Io.Timestamp.now(io, .awake).toNanoseconds();
    while (!server.running.load(.acquire)) {
        if (std.Io.Timestamp.now(io, .awake).toNanoseconds() - start > std.time.ns_per_s)
            return error.ServerStartTimedOut;
        try std.Io.sleep(io, .fromMilliseconds(1), .awake);
    }
    return thread;
}

test "native HTTP1 and HTTP2 streaming reuse and early abort" {
    for ([_]bool{ false, true }) |h2| {
        var server = httpx.Server.initWithConfig(allocator, .{
            .port = 0,
            .http2_enabled = h2,
            .log_level = .err,
            .log_fn = ignoreExpectedDisconnect,
            .shutdown_timeout_ms = 1000,
        });
        defer server.deinit();
        try server.post("/echo", echoProtocol);
        const thread = try startServer(&server);
        defer {
            server.stop();
            thread.join();
        }
        const url = try std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}/echo", .{server.listeningPort()});
        defer allocator.free(url);
        var transport = try adapter.HttpxTransport.init(allocator, io, .{
            .client = .{ .http2_enabled = h2, .timeouts = .uniform(2000) },
        });
        defer transport.deinit();
        for (0..3) |attempt| {
            var request = core.http.Request.init(allocator, .POST, url);
            defer request.deinit();
            var source = std.Io.Reader.fixed("native-upload");
            const operation = try transport.asTransport().open(&request, .{
                .body = core.http.StreamingRequestBody.knownLength(&source, 13),
            });
            defer operation.deinit();
            try std.testing.expectEqualStrings(if (h2) "HTTP/2" else "HTTP/1.1", operation.getHeader("X-Protocol").?);
            if (attempt == 2) {
                operation.abort();
                try std.testing.expectEqual(@as(usize, 0), transport.poolStats().total);
            } else {
                var prefix: [2]u8 = undefined;
                try (try operation.reader()).readSliceAll(&prefix);
                try std.testing.expectEqualStrings("na", &prefix);
                try operation.finish();
                try std.testing.expectEqual(@as(usize, 1), transport.poolStats().idle);
                try std.testing.expectEqual(@as(usize, 1), transport.poolStats().total);
            }
        }
    }
}
