const std = @import("std");
const core = @import("azure_sdk_core");
pub const scripted = @import("scripted_http_server.zig");
pub const fakes = @import("azure_sdk_core_conformance_fakes");

pub const CancellationGrade = enum {
    none,
    preflight,
    cooperative_upload,
};

pub const Capabilities = struct {
    streaming: bool = true,
    ordered_duplicate_response_headers: bool = true,
    request_framing_validation: bool = true,
    response_framing_validation: bool = false,
    response_body_limit: bool = false,
    decompression: bool = false,
    cancellation: CancellationGrade = .preflight,
    lifecycle_observable: bool = false,
    automatic_request_headers: bool = false,
    bounded_memory_logical_large_upload: bool = false,
};

pub const BackendOptions = struct {
    response: scripted.Response = .{},
    expect_request: bool = true,
    allow_peer_failure: bool = false,
    max_response_body: ?usize = null,
};

pub const Observation = struct {
    request_count: usize = 0,
    body: []const u8 = "",
    body_length: usize = 0,
    user_agent_count: usize = 0,
    accept_encoding_count: usize = 0,
    host_count: usize = 0,
    connection_count: usize = 0,
    accept_count: usize = 0,
    finish_count: usize = 0,
    abort_count: usize = 0,
    cancel_count: usize = 0,
    deinit_count: usize = 0,
};

pub const BackendInstance = struct {
    transport: core.http.HttpTransport,
    url: []const u8,
    context: *anyopaque,
    finishFn: *const fn (context: *anyopaque) anyerror!void,
    observeFn: *const fn (context: *anyopaque) Observation,
    deinitFn: *const fn (context: *anyopaque) void,

    pub fn finish(self: *BackendInstance) !void {
        return self.finishFn(self.context);
    }

    pub fn observe(self: *const BackendInstance) Observation {
        return self.observeFn(self.context);
    }

    pub fn deinit(self: *BackendInstance) void {
        self.deinitFn(self.context);
        self.* = undefined;
    }
};

pub const BackendFactory = struct {
    name: []const u8,
    capabilities: Capabilities,
    context: ?*anyopaque = null,
    createFn: *const fn (
        context: ?*anyopaque,
        allocator: std.mem.Allocator,
        io: std.Io,
        options: BackendOptions,
    ) anyerror!BackendInstance,

    pub fn create(
        self: BackendFactory,
        allocator: std.mem.Allocator,
        io: std.Io,
        options: BackendOptions,
    ) !BackendInstance {
        return self.createFn(self.context, allocator, io, options);
    }
};

/// Run raw transport contracts against a backend factory.
///
/// Capabilities explicitly distinguish unsupported contracts from failures,
/// including build-only backends whose runtime host is unavailable.
pub fn runRawTransportContracts(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    try runBufferedContract(allocator, io, factory);
    if (factory.capabilities.streaming) {
        try runStreamingContract(allocator, io, factory, true);
        try runStreamingContract(allocator, io, factory, false);
        try runLifecycleContract(allocator, io, factory);
    }
    if (factory.capabilities.request_framing_validation) {
        try runRequestFramingContracts(allocator, io, factory);
    }
    if (factory.capabilities.cancellation != .none) {
        try runCancellationContracts(allocator, io, factory);
    }
    if (factory.capabilities.response_framing_validation) {
        try runResponseFramingContract(allocator, io, factory);
    }
    if (factory.capabilities.response_body_limit) {
        try runResponseLimitContract(allocator, io, factory);
    }
    if (factory.capabilities.decompression) {
        try runDecompressionContract(allocator, io, factory, false);
        try runDecompressionContract(allocator, io, factory, true);
    }
    if (factory.capabilities.bounded_memory_logical_large_upload) {
        try runLogicalLargeUploadContract(allocator, io, factory);
    }
}

/// Run Core pipeline ownership, redirect, replay, retry, and decompression
/// contracts. Adapter packages should invoke this with their backend factory.
pub fn runPipelineContracts(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    try runPipelineDispatchContract(allocator, io, factory);
    try runRedirectContracts(allocator);
    try runRetryContracts(allocator);
    if (factory.capabilities.decompression) {
        try runPipelineDecompressionContract(allocator, io, factory);
    }
}

/// Exhaustively fail allocator calls in the reusable fake streaming,
/// redirect, and retry fixtures.
pub fn runAllocationFailureContracts() !void {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        mockStreamingAllocationFixture,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        redirectAllocationFixture,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        retryAllocationFixture,
        .{},
    );
}

fn runBufferedContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    const headers = [_]scripted.Header{
        .{ .name = "X-Duplicate", .value = "first" },
        .{ .name = "x-duplicate", .value = "second" },
    };
    var backend = try factory.create(allocator, io, .{
        .response = .{
            .status_code = 201,
            .reason = "Created",
            .headers = &headers,
            .body = "buffered-response",
        },
    });
    defer backend.deinit();

    const copied = backend.transport;
    var request = core.http.Request.init(allocator, .GET, backend.url);
    defer request.deinit();
    try request.setHeader("User-Agent", "azsdk-zig-conformance/0.3.0");
    try request.setHeader("Accept-Encoding", "identity");
    try request.setHeader("Accept", "application/json");

    var response = try copied.send(&request);
    defer response.deinit();
    try backend.finish();
    try std.testing.expectEqual(@as(u16, 201), response.status_code);
    try std.testing.expectEqualStrings("buffered-response", response.body);
    if (factory.capabilities.ordered_duplicate_response_headers) {
        const values = try response.getHeaderValues(allocator, "X-DUPLICATE");
        defer allocator.free(values);
        try std.testing.expectEqual(@as(usize, 2), values.len);
        try std.testing.expectEqualStrings("first", values[0]);
        try std.testing.expectEqualStrings("second", values[1]);
    }

    const observation = backend.observe();
    try std.testing.expectEqual(@as(usize, 1), observation.request_count);
    if (factory.capabilities.automatic_request_headers) {
        try std.testing.expectEqual(@as(usize, 1), observation.user_agent_count);
        try std.testing.expectEqual(@as(usize, 1), observation.accept_encoding_count);
        try std.testing.expectEqual(@as(usize, 1), observation.host_count);
        try std.testing.expectEqual(@as(usize, 1), observation.connection_count);
        try std.testing.expectEqual(@as(usize, 1), observation.accept_count);
    }
}

fn runStreamingContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
    known_length: bool,
) !void {
    var backend = try factory.create(allocator, io, .{
        .response = .{ .status_code = 202, .reason = "Accepted", .body = "stream-response" },
    });
    defer backend.deinit();

    var request = core.http.Request.init(allocator, .POST, backend.url);
    defer request.deinit();
    var reader = std.Io.Reader.fixed("stream-upload");
    const body = if (known_length)
        core.http.StreamingRequestBody.knownLength(&reader, "stream-upload".len)
    else
        core.http.StreamingRequestBody.chunked(&reader);
    var operation = try backend.transport.open(&request, .{ .body = body });
    const response = try (try operation.reader()).allocRemaining(allocator, .unlimited);
    defer allocator.free(response);
    try std.testing.expectEqualStrings("stream-response", response);
    try operation.finish();
    try std.testing.expectError(error.HttpOperationNotActive, operation.finish());
    operation.abort();
    operation.cancel();
    operation.deinit();
    try backend.finish();

    const observation = backend.observe();
    try std.testing.expectEqual(@as(usize, 1), observation.request_count);
    try std.testing.expectEqualStrings("stream-upload", observation.body);
    try std.testing.expectEqual(@as(usize, "stream-upload".len), observation.body_length);
    if (factory.capabilities.lifecycle_observable) {
        try std.testing.expectEqual(@as(usize, 1), observation.finish_count);
        try std.testing.expectEqual(@as(usize, 0), observation.abort_count);
        try std.testing.expectEqual(@as(usize, 0), observation.cancel_count);
        try std.testing.expectEqual(@as(usize, 1), observation.deinit_count);
    }
}

fn runLifecycleContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    {
        var backend = try factory.create(allocator, io, .{
            .response = .{ .body = "abort" },
        });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .GET, backend.url);
        defer request.deinit();
        var operation = try backend.transport.open(&request, .{});
        operation.abort();
        operation.abort();
        operation.cancel();
        operation.deinit();
        try backend.finish();
        if (factory.capabilities.lifecycle_observable) {
            const observation = backend.observe();
            try std.testing.expectEqual(@as(usize, 1), observation.abort_count);
            try std.testing.expectEqual(@as(usize, 0), observation.cancel_count);
            try std.testing.expectEqual(@as(usize, 1), observation.deinit_count);
        }
    }
    {
        var backend = try factory.create(allocator, io, .{
            .response = .{ .body = "cancel" },
        });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .GET, backend.url);
        defer request.deinit();
        var operation = try backend.transport.open(&request, .{});
        operation.cancel();
        operation.cancel();
        operation.abort();
        operation.deinit();
        try backend.finish();
        if (factory.capabilities.lifecycle_observable) {
            const observation = backend.observe();
            try std.testing.expectEqual(@as(usize, 0), observation.abort_count);
            try std.testing.expectEqual(@as(usize, 1), observation.cancel_count);
            try std.testing.expectEqual(@as(usize, 1), observation.deinit_count);
        }
    }
}

fn runRequestFramingContracts(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    {
        var backend = try factory.create(allocator, io, .{ .expect_request = false });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .POST, backend.url);
        defer request.deinit();
        try request.setHeader("Content-Length", "99");
        var source = std.Io.Reader.fixed("body");
        try std.testing.expectError(
            error.ConflictingRequestFraming,
            backend.transport.open(&request, .{
                .body = core.http.StreamingRequestBody.knownLength(&source, 4),
            }),
        );
        try backend.finish();
        try std.testing.expect(request.transport_started);
    }
    {
        var backend = try factory.create(allocator, io, .{
            .allow_peer_failure = true,
        });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .POST, backend.url);
        defer request.deinit();
        var source = std.Io.Reader.fixed("short");
        try std.testing.expectError(
            error.RequestBodyTooShort,
            backend.transport.open(&request, .{
                .body = core.http.StreamingRequestBody.knownLength(&source, 6),
            }),
        );
        try backend.finish();
    }
    {
        var backend = try factory.create(allocator, io, .{
            .allow_peer_failure = true,
        });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .POST, backend.url);
        defer request.deinit();
        var source = std.Io.Reader.fixed("long");
        try std.testing.expectError(
            error.RequestBodyTooLong,
            backend.transport.open(&request, .{
                .body = core.http.StreamingRequestBody.knownLength(&source, 3),
            }),
        );
        try backend.finish();
    }
    {
        var backend = try factory.create(allocator, io, .{ .expect_request = false });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .POST, backend.url);
        defer request.deinit();
        request.body = "buffered";
        var source = std.Io.Reader.fixed("streamed");
        try std.testing.expectError(
            error.MultipleRequestBodies,
            backend.transport.open(&request, .{
                .body = core.http.StreamingRequestBody.chunked(&source),
            }),
        );
        try backend.finish();
    }
}

fn runCancellationContracts(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    {
        var backend = try factory.create(allocator, io, .{ .expect_request = false });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .GET, backend.url);
        defer request.deinit();
        var token = core.http.CancellationToken{};
        token.cancel();
        try std.testing.expectError(
            error.OperationCancelled,
            backend.transport.open(&request, .{ .cancellation = &token }),
        );
        try backend.finish();
        try std.testing.expect(!request.transport_started);
    }
    if (factory.capabilities.cancellation == .cooperative_upload) {
        var backend = try factory.create(allocator, io, .{
            .allow_peer_failure = true,
        });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .POST, backend.url);
        defer request.deinit();
        var token = core.http.CancellationToken{};
        var source = fakes.CancellingReader.init(&token);
        try std.testing.expectError(
            error.OperationCancelled,
            backend.transport.open(&request, .{
                .body = core.http.StreamingRequestBody.chunked(&source.interface),
                .cancellation = &token,
            }),
        );
        try backend.finish();
    }
}

fn runResponseFramingContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    {
        var backend = try factory.create(allocator, io, .{
            .response = .{
                .body = "short",
                .advertised_content_length = 12,
            },
        });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .GET, backend.url);
        defer request.deinit();
        var operation = try backend.transport.open(&request, .{});
        defer operation.deinit();
        try std.testing.expectError(
            error.HttpContentLengthTruncated,
            operation.finish(),
        );
        try std.testing.expectEqual(core.http.OperationState.aborted, operation.state);
        try backend.finish();
    }
    {
        var backend = try factory.create(allocator, io, .{
            .response = .{
                .body = "short",
                .advertised_content_length = 12,
            },
        });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .GET, backend.url);
        defer request.deinit();
        try std.testing.expectError(
            error.HttpContentLengthTruncated,
            backend.transport.send(&request),
        );
        try backend.finish();
    }
    {
        const malformed_headers = [_]scripted.Header{
            .{ .name = "Content-Length", .value = "not-a-number" },
        };
        var backend = try factory.create(allocator, io, .{
            .response = .{ .headers = &malformed_headers },
        });
        defer backend.deinit();
        var request = core.http.Request.init(allocator, .GET, backend.url);
        defer request.deinit();
        try std.testing.expectError(
            error.HttpHeadersInvalid,
            backend.transport.open(&request, .{}),
        );
        try backend.finish();
    }
}

fn runResponseLimitContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    var backend = try factory.create(allocator, io, .{
        .response = .{ .body = "0123456789abcdef" },
        .max_response_body = 8,
    });
    defer backend.deinit();
    var request = core.http.Request.init(allocator, .GET, backend.url);
    defer request.deinit();
    try std.testing.expectError(
        error.StreamTooLong,
        backend.transport.send(&request),
    );
    try backend.finish();
}

const gzip_conformance_body =
    "\x1f\x8b\x08\x00\x00\x00\x00\x00\x02\xff" ++
    "\x4b\xce\xcf\x4b\xcb\x2f\xca\x4d\xcc\x4b" ++
    "\x4e\x05\x00\xe7\x15\x15\xe8\x0b\x00\x00\x00";

fn runDecompressionContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
    chunked: bool,
) !void {
    const headers = [_]scripted.Header{
        .{ .name = "Content-Encoding", .value = "gzip" },
    };
    var backend = try factory.create(allocator, io, .{
        .response = .{
            .headers = &headers,
            .body = gzip_conformance_body,
            .chunked = chunked,
        },
    });
    defer backend.deinit();
    var request = core.http.Request.init(allocator, .GET, backend.url);
    defer request.deinit();
    var response = try backend.transport.send(&request);
    defer response.deinit();
    try backend.finish();
    try std.testing.expectEqualStrings("conformance", response.body);
}

fn runLogicalLargeUploadContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    const logical_length = 8 * 1024 * 1024;
    var backend = try factory.create(allocator, io, .{});
    defer backend.deinit();
    var request = core.http.Request.init(allocator, .PUT, backend.url);
    defer request.deinit();
    var source = fakes.RepeatingReader.init('x', logical_length);
    var operation = try backend.transport.open(&request, .{
        .body = core.http.StreamingRequestBody.knownLength(
            &source.interface,
            logical_length,
        ),
    });
    try operation.finish();
    operation.deinit();
    try backend.finish();
    const observation = backend.observe();
    try std.testing.expectEqual(@as(usize, logical_length), observation.body_length);
    try std.testing.expectEqual(@as(usize, 4096), observation.body.len);
    for (observation.body) |byte| try std.testing.expectEqual(@as(u8, 'x'), byte);
}

fn runPipelineDispatchContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    var backend = try factory.create(allocator, io, .{
        .response = .{ .body = "pipeline" },
    });
    defer backend.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(io);
    var telemetry = core.http.TelemetryPolicy.init("azsdk-zig-conformance/0.3.0");
    var policies = [_]*core.http.HttpPolicy{telemetry.asPolicy()};
    var pipeline = core.http.HttpPipeline.init(
        core.http.HttpRuntime.init(backend.transport, crypto.asProvider()),
        &policies,
    );
    var request = core.http.Request.init(allocator, .GET, backend.url);
    defer request.deinit();
    var response = try pipeline.send(&request);
    defer response.deinit();
    try backend.finish();
    try std.testing.expectEqualStrings("pipeline", response.body);
    try std.testing.expectEqualStrings(
        "azsdk-zig-conformance/0.3.0",
        request.getHeader("User-Agent").?,
    );
}

fn runRedirectContracts(allocator: std.mem.Allocator) !void {
    var sequence = core.http.SequenceMockTransport.init(allocator, &.{
        .{
            .status = 307,
            .body = "",
            .headers = &.{.{ .name = "Location", .value = "https://storage.example/blob#fragment" }},
        },
        .{ .status = 200, .body = "ok" },
    });
    var request = core.http.Request.init(
        allocator,
        .POST,
        "https://registry.example/upload",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "******");
    try request.setHeader("Cookie", "secret");
    try request.setHeader("Proxy-Authorization", "secret");
    try request.setHeader("Host", "registry.example");
    var replay = core.http.ReplayableBytes.init("payload");
    var operation = try sequence.asTransport().open(
        &request,
        .{ .body = replay.body() },
    );
    defer operation.deinit();
    try std.testing.expectEqual(@as(usize, 2), sequence.call_count);
    try std.testing.expect(sequence.captured_authorization[0]);
    try std.testing.expect(!sequence.captured_authorization[1]);
    try std.testing.expect(sequence.captured_cookie[0]);
    try std.testing.expect(!sequence.captured_cookie[1]);
    try std.testing.expect(sequence.captured_proxy_authorization[0]);
    try std.testing.expect(!sequence.captured_proxy_authorization[1]);
    try std.testing.expect(sequence.captured_host[0]);
    try std.testing.expect(!sequence.captured_host[1]);
    try std.testing.expectEqualStrings("payload", sequence.capturedBody(0));
    try std.testing.expectEqualStrings("payload", sequence.capturedBody(1));
    try std.testing.expectEqualStrings(
        "https://storage.example/blob",
        sequence.capturedUrl(1),
    );
    try operation.finish();

    var one_shot_sequence = core.http.SequenceMockTransport.init(allocator, &.{
        .{
            .status = 308,
            .body = "",
            .headers = &.{.{ .name = "Location", .value = "/continued" }},
        },
        .{ .status = 200, .body = "unexpected" },
    });
    var one_shot_request = core.http.Request.init(
        allocator,
        .PUT,
        "https://registry.example/upload",
    );
    defer one_shot_request.deinit();
    var source = std.Io.Reader.fixed("one-shot");
    var one_shot = try one_shot_sequence.asTransport().open(
        &one_shot_request,
        .{
            .body = core.http.StreamingRequestBody.knownLength(
                &source,
                "one-shot".len,
            ),
        },
    );
    defer one_shot.deinit();
    try std.testing.expectEqual(@as(u16, 308), one_shot.status_code);
    try std.testing.expectEqual(@as(usize, 1), one_shot_sequence.call_count);
    one_shot.abort();
}

fn runRetryContracts(allocator: std.mem.Allocator) !void {
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var retry = core.http.RetryPolicy.init();
    retry.initial_delay_ms = 0;
    var policies = [_]*core.http.HttpPolicy{retry.asPolicy()};

    var sequence = core.http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 503, .body = "retry" },
        .{ .status = 200, .body = "ok" },
    });
    var pipeline = core.http.HttpPipeline.init(
        core.http.HttpRuntime.init(sequence.asTransport(), crypto.asProvider()),
        &policies,
    );
    var request = core.http.Request.init(
        allocator,
        .POST,
        "https://example.com/upload",
    );
    defer request.deinit();
    var replay = core.http.ReplayableBytes.init("replayable");
    var operation = try pipeline.open(&request, .{ .body = replay.body() });
    defer operation.deinit();
    try std.testing.expectEqual(@as(u16, 200), operation.status_code);
    try std.testing.expectEqual(@as(usize, 2), sequence.call_count);
    try std.testing.expectEqualStrings("replayable", sequence.capturedBody(0));
    try std.testing.expectEqualStrings("replayable", sequence.capturedBody(1));
    try operation.finish();

    var one_shot_sequence = core.http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 503, .body = "retry" },
        .{ .status = 200, .body = "unexpected" },
    });
    var one_shot_pipeline = core.http.HttpPipeline.init(
        core.http.HttpRuntime.init(one_shot_sequence.asTransport(), crypto.asProvider()),
        &policies,
    );
    var one_shot_request = core.http.Request.init(
        allocator,
        .POST,
        "https://example.com/upload",
    );
    defer one_shot_request.deinit();
    var source = std.Io.Reader.fixed("one-shot");
    var one_shot = try one_shot_pipeline.open(&one_shot_request, .{
        .body = core.http.StreamingRequestBody.chunked(&source),
    });
    defer one_shot.deinit();
    try std.testing.expectEqual(@as(u16, 503), one_shot.status_code);
    try std.testing.expectEqual(@as(usize, 1), one_shot_sequence.call_count);
    one_shot.abort();
}

fn runPipelineDecompressionContract(
    allocator: std.mem.Allocator,
    io: std.Io,
    factory: BackendFactory,
) !void {
    const headers = [_]scripted.Header{
        .{ .name = "Content-Encoding", .value = "gzip" },
    };
    var backend = try factory.create(allocator, io, .{
        .response = .{ .headers = &headers, .body = gzip_conformance_body },
    });
    defer backend.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(io);
    var decompression = core.http.DecompressionPolicy.init();
    var policies = [_]*core.http.HttpPolicy{decompression.asPolicy()};
    var pipeline = core.http.HttpPipeline.init(
        core.http.HttpRuntime.init(backend.transport, crypto.asProvider()),
        &policies,
    );
    var request = core.http.Request.init(allocator, .GET, backend.url);
    defer request.deinit();
    var response = try pipeline.send(&request);
    defer response.deinit();
    try backend.finish();
    try std.testing.expectEqualStrings("conformance", response.body);
    try std.testing.expectEqualStrings(
        "gzip, deflate",
        request.getHeader("Accept-Encoding").?,
    );
}

fn mockStreamingAllocationFixture(allocator: std.mem.Allocator) !void {
    var mock = core.http.MockTransport.init(allocator, 200, "response");
    defer mock.deinit();
    mock.response_headers_list = &.{.{ .name = "x-test", .value = "value" }};
    var request = core.http.Request.init(allocator, .POST, "https://example.com");
    defer request.deinit();
    try request.setHeader("content-type", "application/octet-stream");
    var source = std.Io.Reader.fixed("request");
    var operation = try mock.asTransport().open(&request, .{
        .body = core.http.StreamingRequestBody.knownLength(&source, 7),
    });
    defer operation.deinit();
    try operation.finish();
}

fn redirectAllocationFixture(allocator: std.mem.Allocator) !void {
    var sequence = core.http.SequenceMockTransport.init(allocator, &.{
        .{
            .status = 307,
            .body = "",
            .headers = &.{.{ .name = "Location", .value = "https://storage.example/blob" }},
        },
        .{ .status = 200, .body = "ok" },
    });
    var request = core.http.Request.init(
        allocator,
        .PUT,
        "https://registry.example/upload",
    );
    defer request.deinit();
    request.body = "body";
    try request.setHeader("Authorization", "******");
    var response = sequence.asTransport().send(&request) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => |other| return other,
    };
    defer response.deinit();
}

fn retryAllocationFixture(allocator: std.mem.Allocator) !void {
    var sequence = core.http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 503, .body = "retry" },
        .{ .status = 200, .body = "ok" },
    });
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var retry = core.http.RetryPolicy.init();
    retry.initial_delay_ms = 0;
    var policies = [_]*core.http.HttpPolicy{retry.asPolicy()};
    var pipeline = core.http.HttpPipeline.init(
        core.http.HttpRuntime.init(sequence.asTransport(), crypto.asProvider()),
        &policies,
    );
    var request = core.http.Request.init(allocator, .GET, "https://example.com");
    defer request.deinit();
    var response = try pipeline.send(&request);
    defer response.deinit();
}

const StdBackendState = struct {
    allocator: std.mem.Allocator,
    transport: core.http.StdHttpTransport,
    server: scripted.ScriptedHttpServer = undefined,
    server_started: bool = false,
    server_joined: bool = false,
    url: []u8,

    fn finish(context: *anyopaque) !void {
        const self: *StdBackendState = @ptrCast(@alignCast(context));
        if (self.server_started and !self.server_joined) {
            try self.server.join();
            self.server_joined = true;
        }
    }

    fn observe(context: *anyopaque) Observation {
        const self: *StdBackendState = @ptrCast(@alignCast(context));
        if (!self.server_started) return .{};
        return .{
            .request_count = if (self.server.request_line.len > 0) 1 else 0,
            .body = self.server.body(),
            .body_length = self.server.body_length,
            .user_agent_count = self.server.headerCount("user-agent"),
            .accept_encoding_count = self.server.headerCount("accept-encoding"),
            .host_count = self.server.headerCount("host"),
            .connection_count = self.server.headerCount("connection"),
            .accept_count = self.server.headerCount("accept"),
        };
    }

    fn destroy(context: *anyopaque) void {
        const self: *StdBackendState = @ptrCast(@alignCast(context));
        if (self.server_started) {
            self.server.deinit();
        }
        self.transport.deinit();
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

fn createStdBackend(
    _: ?*anyopaque,
    allocator: std.mem.Allocator,
    io: std.Io,
    options: BackendOptions,
) !BackendInstance {
    const state = try allocator.create(StdBackendState);
    errdefer allocator.destroy(state);
    state.* = .{
        .allocator = allocator,
        .transport = core.http.StdHttpTransport.init(allocator, io),
        .url = undefined,
    };
    errdefer state.transport.deinit();
    if (options.max_response_body) |limit| {
        state.transport.max_response_body = .limited(limit);
    }
    if (options.expect_request) {
        state.server = try scripted.ScriptedHttpServer.init(
            allocator,
            io,
            options.response,
        );
        state.server.allow_peer_failure = options.allow_peer_failure;
        errdefer state.server.deinit();
        try state.server.start();
        state.server_started = true;
        state.url = try state.server.allocUrl(allocator, "/conformance");
    } else {
        state.url = try allocator.dupe(u8, "http://127.0.0.1:1/conformance");
    }
    return .{
        .transport = state.transport.asTransport(),
        .url = state.url,
        .context = state,
        .finishFn = &StdBackendState.finish,
        .observeFn = &StdBackendState.observe,
        .deinitFn = &StdBackendState.destroy,
    };
}

pub fn standardBackendFactory() BackendFactory {
    return .{
        .name = "std.http.Client",
        .capabilities = .{
            .response_framing_validation = true,
            .response_body_limit = true,
            .decompression = true,
            .cancellation = .cooperative_upload,
            .automatic_request_headers = true,
            .bounded_memory_logical_large_upload = true,
        },
        .createFn = &createStdBackend,
    };
}

const MockBackendState = struct {
    allocator: std.mem.Allocator,
    transport: core.http.MockTransport,
    response_headers: []core.http.MockTransport.HeaderPair,
    url: []u8,

    fn finish(_: *anyopaque) !void {}

    fn observe(context: *anyopaque) Observation {
        const self: *MockBackendState = @ptrCast(@alignCast(context));
        return .{
            .request_count = self.transport.call_count,
            .body = self.transport.last_body orelse "",
            .body_length = if (self.transport.last_body) |body| body.len else 0,
            .user_agent_count = if (self.transport.last_headers.get("User-Agent") != null) 1 else 0,
            .accept_encoding_count = if (self.transport.last_headers.get("Accept-Encoding") != null) 1 else 0,
            .accept_count = if (self.transport.last_headers.get("Accept") != null) 1 else 0,
            .finish_count = self.transport.stream_finish_count,
            .abort_count = self.transport.stream_abort_count,
            .cancel_count = self.transport.stream_cancel_count,
            .deinit_count = self.transport.stream_deinit_count,
        };
    }

    fn destroy(context: *anyopaque) void {
        const self: *MockBackendState = @ptrCast(@alignCast(context));
        self.transport.deinit();
        self.allocator.free(self.response_headers);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

fn createMockBackend(
    _: ?*anyopaque,
    allocator: std.mem.Allocator,
    _: std.Io,
    options: BackendOptions,
) !BackendInstance {
    const state = try allocator.create(MockBackendState);
    errdefer allocator.destroy(state);
    const pairs = try allocator.alloc(
        core.http.MockTransport.HeaderPair,
        options.response.headers.len,
    );
    errdefer allocator.free(pairs);
    for (options.response.headers, pairs) |header, *pair| {
        pair.* = .{ .name = header.name, .value = header.value };
    }
    const url = try allocator.dupe(u8, "https://example.com/conformance");
    errdefer allocator.free(url);
    state.* = .{
        .allocator = allocator,
        .transport = core.http.MockTransport.init(
            allocator,
            options.response.status_code,
            options.response.body,
        ),
        .response_headers = pairs,
        .url = url,
    };
    state.transport.response_headers_list = pairs;
    return .{
        .transport = state.transport.asTransport(),
        .url = state.url,
        .context = state,
        .finishFn = &MockBackendState.finish,
        .observeFn = &MockBackendState.observe,
        .deinitFn = &MockBackendState.destroy,
    };
}

pub fn mockBackendFactory() BackendFactory {
    return .{
        .name = "MockTransport",
        .capabilities = .{
            .cancellation = .cooperative_upload,
            .lifecycle_observable = true,
        },
        .createFn = &createMockBackend,
    };
}

test "standard HTTP transport conforms" {
    try runRawTransportContracts(
        std.testing.allocator,
        std.testing.io,
        standardBackendFactory(),
    );
}

test "mock HTTP transport conforms" {
    try runRawTransportContracts(
        std.testing.allocator,
        std.testing.io,
        mockBackendFactory(),
    );
}

test "Core pipeline contracts conform through standard transport" {
    try runPipelineContracts(
        std.testing.allocator,
        std.testing.io,
        standardBackendFactory(),
    );
}

test "Core pipeline contracts conform through mock transport" {
    try runPipelineContracts(
        std.testing.allocator,
        std.testing.io,
        mockBackendFactory(),
    );
}

test "HTTP conformance allocation failures are leak-free" {
    try runAllocationFailureContracts();
}
