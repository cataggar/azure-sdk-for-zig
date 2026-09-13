const std = @import("std");
const core = @import("azure_sdk_core");
const queues = @import("root.zig");
const allocator = std.testing.allocator;
const Provider = core.tracing.ExportingTracerProvider;
const scope_name = "caller.queues";
const scope_version = "9.8.7";
const namespace = "Caller.Namespace";
const parent_header = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01";
const trace_state = "caller=value, ,vendor=ok,";
const endpoint = "https://account.queue.core.windows.net";
const sas_url = endpoint ++ "/private-queue?sig=private-signature";

const Capture = struct {
    mock: *core.http.MockTransport,
    count: usize = 0,
    contexts: [16]?core.tracing.TraceContext = @splat(null),
    require_sas: bool = false,
    user_agent: ?[]const u8 = null,
    fail: bool = false,
    const vtable: core.http.HttpTransport.VTable = .{ .send = send, .open = open };
    const buffered_vtable: core.http.HttpTransport.VTable = .{ .send = send };

    fn asTransport(self: *Capture) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
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
            try std.testing.expect(request.getHeader("User-Agent") == null);
        }
        if (self.user_agent) |agent| try std.testing.expectEqualStrings(agent, request.getHeader("User-Agent").?);
        self.count += 1;
        if (self.fail) return error.FixtureTransportFailure;
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
    statuses: [16]core.tracing.SpanStatus = undefined,
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
            var matches: usize = 0;
            for (self.capture.contexts[0..self.capture.count]) |context| {
                if (context) |value| {
                    if (std.mem.eql(u8, &value.span_id, &data.context.span_id)) matches += 1;
                }
            }
            if (self.require_wire) try std.testing.expectEqual(@as(usize, 1), matches);
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
        .max_batch_size = capacity,
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

fn freeMessages(messages: []queues.QueueMessage) void {
    for (messages) |message| {
        if (message.message_id) |value| allocator.free(value);
        if (message.message_text) |value| allocator.free(value);
        if (message.insertion_time) |value| allocator.free(value);
        if (message.expiration_time) |value| allocator.free(value);
    }
    allocator.free(messages);
}

test "tracing Queue service direct and copied child operations retain options and inert defaults" {
    for ([_]bool{ false, true }) |enabled| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 201, "");
        defer mock.deinit();
        var capture: Capture = .{ .mock = &mock, .user_agent = queues.user_agent_prefix };
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
            var telemetry = core.http.TelemetryPolicy.init(queues.user_agent_prefix);
            var policies = [_]*core.http.HttpPolicy{telemetry.asPolicy()};
            var pipeline = core.http.HttpPipeline.init(runtime, &policies);
            if (enabled) pipeline.setInstrumentation(.{
                .provider = provider.asProvider(),
                .scope_name = scope,
                .scope_version = version,
                .namespace = ns,
                .parent_context = core.tracing.TraceContext.extract(parent_header, state).?,
            });
            var service = queues.QueueServiceClient.init(endpoint, pipeline);
            var direct = queues.QueueClient.init(endpoint, "private-direct", pipeline, .{});
            var child = service.getQueueClient("private-child");
            var copied = child;
            pipeline.setInstrumentation(null);
            child.pipeline.setInstrumentation(null);
            try service.createQueue(allocator, "private-created");
            try service.deleteQueue(allocator, "private-deleted");
            try direct.sendMessage(allocator, "private-direct-body");
            try copied.sendMessage(allocator, "private-child-body");
            mock.response_status = 200;
            mock.response_body =
                "<QueueMessagesList><QueueMessage><MessageId>private-id</MessageId>" ++
                "<MessageText>private-response</MessageText></QueueMessage></QueueMessagesList>";
            const received = try copied.receiveMessages(allocator);
            defer freeMessages(received);
            try std.testing.expectEqual(@as(usize, 1), received.len);
            try std.testing.expectEqualStrings("private-response", received[0].message_text.?);
            const peeked = try copied.peekMessages(allocator);
            defer freeMessages(peeked);
            try std.testing.expectEqual(@as(usize, 1), peeked.len);
            try copied.deleteMessage(allocator, "private-id", "private-receipt");
            for ([_][]u8{ scope, version, ns, state }) |bytes| @memset(bytes, 'x');
        }
        try std.testing.expectEqual(@as(usize, 7), capture.count);
        try std.testing.expectEqual(@as(usize, 0), probe.calls);
        for (capture.contexts[0..capture.count]) |context|
            try std.testing.expectEqual(enabled, context != null);
        try std.testing.expectEqual(@as(usize, if (enabled) 7 else 0), try provider.drain(1000));
    }
    try std.testing.expectEqualStrings(@import("build.zig.zon").version, queues.version);
    try std.testing.expect(std.mem.endsWith(u8, queues.user_agent_prefix, queues.version));
}

const FailedCredential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = getToken },

    fn getToken(
        _: *core.credentials.TokenCredential,
        _: core.credentials.TokenRequestContext,
        _: core.context.Context,
        _: core.http.HttpRuntime,
    ) !core.credentials.AccessToken {
        return error.FixtureCredentialFailure;
    }
};

test "tracing Queue credential and backend failures preserve original errors" {
    for ([_]bool{ false, true }) |credential_failure| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 201, "");
        defer mock.deinit();
        var capture: Capture = .{ .mock = &mock, .fail = true };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture, .require_wire = !credential_failure };
        var provider = try makeProvider(runtime, &probe, 1);
        defer provider.deinit() catch unreachable;
        var credential: FailedCredential = .{};
        var auth = core.http.BearerTokenAuthPolicy.init(allocator, &credential.credential, queues.auth_scopes);
        defer auth.deinit();
        var policies = [_]*core.http.HttpPolicy{auth.asPolicy()};
        var pipeline = core.http.HttpPipeline.init(runtime, if (credential_failure) &policies else &.{});
        pipeline.setInstrumentation(instrumentation(&provider));
        var client = queues.QueueClient.init(endpoint, "private-queue", pipeline, .{});
        try std.testing.expectError(
            if (credential_failure) error.FixtureCredentialFailure else error.FixtureTransportFailure,
            client.sendMessage(allocator, "private-body"),
        );
        try std.testing.expectEqual(@as(usize, if (credential_failure) 0 else 1), capture.count);
        try std.testing.expectEqual(@as(usize, 0), probe.calls);
        try std.testing.expectEqual(@as(usize, 1), try provider.drain(1000));
        try std.testing.expectEqual(core.tracing.SpanStatus.@"error", probe.statuses[0]);
    }
}

test "tracing SAS Queue options preserve all outcomes credentials and header-complete semantics" {
    const Mode = enum { accepted, non_protocol_success, rejected, redirect, unknown, pre_dispatch, drain_failure, buffered_only };
    for (std.enums.values(Mode)) |mode| {
        for (0..3) |configuration| {
            var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
            var mock = core.http.MockTransport.init(allocator, switch (mode) {
                .non_protocol_success => 204,
                .rejected => 403,
                .redirect => 307,
                else => 201,
            }, "private-response");
            defer mock.deinit();
            if (mode == .drain_failure) mock.stream_fail_response_after = 0;
            if (mode == .redirect)
                mock.response_headers_list = &.{.{ .name = "Location", .value = "https://other.test/private-path" }};
            var capture: Capture = .{ .mock = &mock, .require_sas = true, .fail = mode == .unknown };
            const runtime = core.http.HttpRuntime.init(if (mode == .buffered_only) .{
                .context = &capture,
                .vtable = &Capture.buffered_vtable,
            } else capture.asTransport(), crypto.asProvider());
            var probe: Probe = .{ .capture = &capture };
            var provider = try makeProvider(runtime, &probe, 1);
            defer provider.deinit() catch unreachable;
            {
                var client = try queues.CompleteSasQueueClient.init(allocator, sas_url, runtime);
                defer client.deinit();
                if (configuration != 0) client.setInstrumentation(instrumentation(&provider));
                if (configuration == 2) client.setInstrumentation(null);
                const too_large = [_]u8{0} ** (queues.max_queue_message_bytes + 1);
                const result = client.sendMessage(if (mode == .pre_dispatch) &too_large else "private-body");
                switch (mode) {
                    .accepted, .drain_failure, .buffered_only => try std.testing.expectEqual(@as(u16, 201), (try result).accepted.status_code),
                    .non_protocol_success, .rejected, .redirect => try std.testing.expectEqual(mock.response_status, (try result).rejected.status_code),
                    .unknown => try std.testing.expectEqual(error.FixtureTransportFailure, (try result).unknown.cause),
                    .pre_dispatch => try std.testing.expectError(error.QueueMessageTooLarge, result),
                }
            }
            const count: usize = if (mode == .pre_dispatch) 0 else 1;
            try std.testing.expectEqual(count, capture.count);
            try std.testing.expectEqual(@as(usize, 0), probe.calls);
            if (count != 0) try std.testing.expectEqual(configuration == 1, capture.contexts[0] != null);
            try std.testing.expectEqual(if (configuration == 1) count else 0, try provider.drain(1000));
            if (configuration == 1 and (mode == .drain_failure or mode == .non_protocol_success))
                try std.testing.expectEqual(core.tracing.SpanStatus.unset, probe.statuses[0]);
        }
    }
}

test "tracing SAS Queue allocation and exporter failures cannot change dispatch outcomes" {
    var propagation_failures: usize = 0;
    for (0..24) |offset| {
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
            var client = try queues.SasQueueClient.init(failing.allocator(), sas_url, runtime);
            defer client.deinit();
            client.setInstrumentation(instrumentation(&provider));
            failing.fail_index = failing.alloc_index + offset;
            if (client.sendMessage("private-body")) |outcome| {
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
    var client = try queues.SasQueueClient.init(allocator, sas_url, runtime);
    defer client.deinit();
    client.setInstrumentation(instrumentation(&provider));
    const accepted = try client.sendMessage("private-first");
    mock.response_status = 403;
    const rejected = try client.sendMessage("private-second");
    try std.testing.expectEqual(@as(u64, 1), provider.stats().dropped_spans);
    try std.testing.expectEqual(@as(usize, 0), probe.calls);
    try std.testing.expectError(error.FixtureExportFailure, provider.forceFlush(1000));
    try std.testing.expectEqual(@as(u64, 1), provider.stats().export_errors);
    try std.testing.expectEqual(@as(u16, 201), accepted.accepted.status_code);
    try std.testing.expectEqual(@as(u16, 403), rejected.rejected.status_code);
    try std.testing.expectEqual(@as(usize, 2), capture.count);
}
