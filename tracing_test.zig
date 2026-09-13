const std = @import("std");
const core = @import("azure_sdk_core");
const kusto = @import("azure_sdk_kusto");
const common = kusto.common;
const data = kusto.data;
const ingest = kusto.ingest;
const allocator = std.testing.allocator;
const Provider = core.tracing.ExportingTracerProvider;
const scope_name = "caller.kusto";
const scope_version = "9.8.7";
const namespace = "Caller.Kusto.Namespace";
const parent_header = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01";
const trace_state = "caller=value, ,vendor=ok,";
const source_id = "abababab-abab-4bab-8bab-abababababab";
const target: ingest.StreamingIngestTarget = .{ .database = "private-db", .table = "private-table" };
const resource_body =
    \\{"Tables":[{"TableName":"Resources","Columns":[{"ColumnName":"ResourceTypeName","DataType":"String"},{"ColumnName":"StorageRoot","DataType":"String"}],"Rows":[
    \\["SecuredReadyForAggregationQueue","https://account.queue.core.windows.net/private-queue?sig=private-queue-token"],
    \\["TempStorage","https://account.blob.core.windows.net/private-container?sig=private-blob-token"],
    \\["IngestionStatusTable","https://account.table.core.windows.net/private-status?sig=private-table-token"]
    \\]}]}
;
const identity_body =
    \\{"Tables":[{"TableName":"Token","Columns":[{"ColumnName":"AuthorizationContext","DataType":"String"}],"Rows":[["private-identity-context"]]}]}
;
const query_body =
    \\[{"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},{"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}]
;
const progressive_body =
    \\[{"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":true},{"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}]
;

const Credential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = getToken },
    calls: usize = 0,
    fail: bool = false,

    fn getToken(
        credential: *core.credentials.TokenCredential,
        _: core.credentials.TokenRequestContext,
        _: core.context.Context,
        _: core.http.HttpRuntime,
    ) !core.credentials.AccessToken {
        const self: *Credential = @fieldParentPtr("credential", credential);
        self.calls += 1;
        if (self.fail) return error.FixtureCredentialFailure;
        return .{ .token = "fixture-token", .expires_on = 7_258_118_400 };
    }
};

const Stage = enum { discovery, query, management, resources, identity, streaming, blob, status_write, queue, status_read };

const Capture = struct {
    mock: *core.http.MockTransport,
    count: usize = 0,
    counts: [10]usize = @splat(0),
    stages: [64]Stage = undefined,
    contexts: [64]?core.tracing.TraceContext = @splat(null),
    fail_stage: ?Stage = null,
    override_stage: ?Stage = null,
    override_status: u16 = 403,
    query_retry: bool = false,
    first_status_pending: bool = false,
    fail_status_body: bool = false,

    const vtable: core.http.HttpTransport.VTable = .{ .send = send, .open = open };

    fn asTransport(self: *Capture) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    fn stageCount(self: *const Capture, stage: Stage) usize {
        return self.counts[@intFromEnum(stage)];
    }

    fn record(self: *Capture, request: *core.http.Request) !void {
        const stage: Stage = if (contains(request.url, "/auth/metadata")) .discovery else if (contains(request.url, ".blob.core.windows.net")) .blob else if (contains(request.url, ".queue.core.windows.net")) .queue else if (contains(request.url, ".table.core.windows.net"))
            (if (request.method == .POST) .status_write else .status_read)
        else if (contains(request.url, "/rest/ingest")) .streaming else if (contains(request.url, "/rest/query")) .query else if (contains(request.body orelse "", ".get ingestion resources")) .resources else if (contains(request.body orelse "", ".get kusto identity token")) .identity else .management;
        const storage = switch (stage) {
            .blob, .status_write, .queue, .status_read => true,
            else => false,
        };
        try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, request.redirect_policy);
        if (storage or stage == .discovery) {
            try std.testing.expect(!request.retryable);
            try std.testing.expect(request.getHeader("Authorization") == null);
            try std.testing.expect(request.getHeader("Cookie") == null);
        } else {
            try std.testing.expectEqualStrings("Bearer fixture-token", request.getHeader("Authorization").?);
            try std.testing.expectEqualStrings(kusto.user_agent_prefix, request.getHeader("User-Agent").?);
            if (request.getHeader("x-ms-client-version")) |value|
                try std.testing.expectEqualStrings(kusto.user_agent_prefix, value);
        }
        try std.testing.expect(self.count < self.stages.len);
        self.stages[self.count] = stage;
        if (request.getHeader("traceparent")) |header| {
            self.contexts[self.count] = core.tracing.TraceContext.parseTraceparent(header).?;
            try std.testing.expectEqualStrings(parent_header[3..35], &self.contexts[self.count].?.trace_id);
            try std.testing.expectEqualStrings(trace_state, request.getHeader("tracestate").?);
        } else try std.testing.expect(request.getHeader("tracestate") == null);
        self.count += 1;
        self.counts[@intFromEnum(stage)] += 1;
        if (self.fail_stage == stage) return error.FixtureTransportFailure;
        self.mock.response_headers_list = &.{};
        self.mock.stream_fail_response_after = if (stage == .status_read and self.fail_status_body) 0 else null;
        self.mock.response_status = switch (stage) {
            .blob, .queue => 201,
            .status_write => 204,
            else => 200,
        };
        self.mock.response_body = switch (stage) {
            .discovery =>
            \\{"AzureAD":{"LoginEndpoint":"https://login.microsoftonline.com","KustoServiceResourceId":"https://kusto.kusto.windows.net"}}
            ,
            .query => if (contains(request.body orelse "", "results_progressive_enabled")) progressive_body else query_body,
            .management => "{\"Tables\":[]}",
            .resources => resource_body,
            .identity => identity_body,
            .streaming => "{}",
            .status_read => if (self.first_status_pending and self.stageCount(.status_read) == 1)
                "{\"Status\":\"Pending\"}"
            else
                "{\"Status\":\"Succeeded\",\"OperationId\":\"private-operation\"}",
            else => "",
        };
        if (self.override_stage == stage) self.mock.response_status = self.override_status;
        if (stage == .query and self.query_retry and self.stageCount(.query) == 1)
            self.mock.response_status = 500;
        if (self.mock.response_status >= 300) {
            self.mock.response_body = "{\"error\":{\"code\":\"FixtureFailure\",\"message\":\"private-error\"}}";
            if (self.mock.response_status == 307)
                self.mock.response_headers_list = &.{.{ .name = "Location", .value = "https://other.test/private-redirect" }};
        }
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
    exporter: core.tracing.SpanExporter = .{
        .exportFn = exportBatch,
        .forceFlushFn = flush,
        .shutdownFn = shutdown,
    },
    capture: *Capture,
    count: usize = 0,
    calls: usize = 0,
    management_calls: usize = 0,
    statuses: [64]core.tracing.SpanStatus = undefined,
    require_wire: bool = true,
    fail: bool = false,

    fn exportBatch(exporter: *core.tracing.SpanExporter, batch: []const core.tracing.SpanData, _: core.tracing.ExportContext) !void {
        const self: *Probe = @fieldParentPtr("exporter", exporter);
        self.calls += 1;
        if (self.fail) return error.FixtureExportFailure;
        for (batch) |span| {
            try std.testing.expect(!contains(span.name, "private-"));
            try std.testing.expectEqualStrings(scope_name, span.scope_name);
            try std.testing.expectEqualStrings(scope_version, span.scope_version);
            try std.testing.expectEqualStrings(parent_header[3..35], &span.context.trace_id);
            try std.testing.expectEqualStrings(parent_header[36..52], &span.parent_span_id.?);
            try std.testing.expectEqualStrings(trace_state, span.context.trace_state.?);
            try std.testing.expect(span.end_time_unix_nano >= span.start_time_unix_nano);
            var matched = false;
            for (self.capture.contexts[0..self.capture.count]) |context| {
                if (context) |value| {
                    if (std.mem.eql(u8, &value.span_id, &span.context.span_id)) matched = true;
                }
            }
            if (self.require_wire) try std.testing.expect(matched);
            var has_namespace = false;
            for (span.attributes) |attribute| {
                try std.testing.expect(
                    std.mem.eql(u8, attribute.key, "http.request.method") or
                        std.mem.eql(u8, attribute.key, "server.address") or
                        std.mem.eql(u8, attribute.key, "az.namespace") or
                        std.mem.eql(u8, attribute.key, "http.response.status_code") or
                        std.mem.eql(u8, attribute.key, "error.type"),
                );
                if (attribute.value == .string) try std.testing.expect(!contains(attribute.value.string, "private-"));
                if (std.mem.eql(u8, attribute.key, "az.namespace")) {
                    has_namespace = true;
                    try std.testing.expectEqualStrings(namespace, attribute.value.string);
                }
            }
            try std.testing.expect(has_namespace);
            self.statuses[self.count] = span.status;
            self.count += 1;
        }
    }

    fn flush(exporter: *core.tracing.SpanExporter, _: core.tracing.ExportContext) !void {
        const self: *Probe = @fieldParentPtr("exporter", exporter);
        self.management_calls += 1;
    }

    fn shutdown(exporter: *core.tracing.SpanExporter, _: core.tracing.ExportContext) !void {
        const self: *Probe = @fieldParentPtr("exporter", exporter);
        self.management_calls += 1;
    }

    fn expectUnmanaged(self: *const Probe) !void {
        try std.testing.expectEqual(@as(usize, 0), self.calls);
        try std.testing.expectEqual(@as(usize, 0), self.management_calls);
    }
};

fn contains(value: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, value, needle) != null;
}

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

fn connectionFor(runtime: core.http.HttpRuntime, credential: *Credential, options: common.KustoConnectionOptions) !*common.KustoConnection {
    return common.KustoConnection.init(allocator, .{
        .cluster_url = "https://cluster.kusto.windows.net",
        .credential = &credential.credential,
    }, runtime, options);
}

test "tracing covers discovery query progressive ingestion and retained status with inert defaults" {
    for ([_]bool{ false, true }) |enabled| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        var capture: Capture = .{ .mock = &mock, .first_status_pending = true };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 32);
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
            const config: ?core.tracing.InstrumentationOptions = if (enabled) .{
                .provider = provider.asProvider(),
                .scope_name = scope,
                .scope_version = version,
                .namespace = ns,
                .parent_context = core.tracing.TraceContext.extract(parent_header, state).?,
            } else null;
            var credential: Credential = .{};
            var tracking = blk: {
                const connection = try connectionFor(runtime, &credential, .{
                    .instrumentation = config,
                    .retry = .{ .max_retries = 0 },
                });
                defer connection.deinit();
                var client = data.KustoClient.init(connection, .{});
                var copied = client;
                var query = try copied.executeQueryResult(allocator, "private-db", "print 'private-query'", null);
                defer query.deinit(allocator);
                try std.testing.expect(query == .ok);
                var management = try client.executeMgmtResult(allocator, "private-db", ".show private-command", null);
                defer management.deinit(allocator);
                try std.testing.expect(management == .ok);
                const opened = try copied.executeProgressiveQuery(allocator, "private-db", "print 1", null, .{});
                const stream = opened.ok;
                defer stream.deinit();
                try stream.finish();
                var direct = ingest.StreamingIngestClient.init(connection);
                var direct_result = try direct.ingestResult(allocator, target, .{ .bytes = "private-body" }, .{
                    .source_id = source_id,
                    .compression = .none,
                    .retry = .{ .max_retries = 0 },
                });
                defer direct_result.deinit(allocator);
                try std.testing.expect(direct_result == .ok);
                var queued = ingest.QueuedIngestClient.init(runtime, .{ .connection = connection });
                var copied_queued = queued;
                queued.setInstrumentation(null);
                var result = try copied_queued.ingest(allocator, target, .{ .bytes = "private-body" }, .{
                    .source_id = source_id,
                    .queued_compression = .none,
                    .queued_max_resource_attempts = 1,
                    .report_level = .failures_and_successes,
                    .report_method = .queue_and_table,
                });
                defer result.deinit(allocator);
                try std.testing.expectEqual(ingest.QueuedSubmissionOutcome.queue_accepted, result.outcome);
                break :blk result.takeTracking().?;
            };
            defer tracking.deinit();
            // Connection, initiating clients, result and owned resource manager
            // have been destroyed. Only explicit external borrows remain.
            var status = try tracking.poll(allocator, .{
                .poll_interval_ms = 1,
                .timeout_ms = 1000,
                .max_transient_retries = 0,
                .max_jitter_ms = 0,
            });
            defer status.deinit(allocator);
            try std.testing.expectEqual(ingest.QueuedIngestionStatus.succeeded, status.status.status);
            try std.testing.expectEqual(@as(usize, 1), credential.calls);
            for ([_][]u8{ scope, version, ns, state }) |bytes| @memset(bytes, 'x');
        }
        try std.testing.expectEqual(@as(usize, 12), capture.count);
        inline for (std.enums.values(Stage)) |stage| try std.testing.expect(capture.stageCount(stage) != 0);
        for (capture.contexts[0..capture.count]) |context| try std.testing.expectEqual(enabled, context != null);
        try probe.expectUnmanaged();
        try std.testing.expectEqual(@as(usize, if (enabled) 12 else 0), try provider.drain(1000));
    }
    try std.testing.expectEqualStrings(@import("build.zig.zon").version, kusto.version);
    try std.testing.expect(std.mem.endsWith(u8, kusto.user_agent_prefix, kusto.version));
}

test "tracing managed direct queued and fallback routes preserve Kusto scope" {
    const Route = enum { direct, queued, fallback };
    for (std.enums.values(Route)) |route| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        var capture: Capture = .{
            .mock = &mock,
            .override_stage = if (route == .fallback) .streaming else null,
            .override_status = 503,
        };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 16);
        defer provider.deinit() catch unreachable;
        var credential: Credential = .{};
        {
            const connection = try connectionFor(runtime, &credential, .{
                .metadata_mode = .disabled,
                .instrumentation = instrumentation(&provider),
                .retry = .{ .max_retries = 0 },
            });
            defer connection.deinit();
            const client = ingest.ManagedIngestClient.init(connection, null);
            var copied = client;
            var result = try copied.ingestResult(allocator, target, .{ .bytes = "private-body" }, .{
                .source_id = source_id,
                .compression = .none,
                .retry = .{ .max_retries = 0 },
                .managed_streaming_threshold_bytes = if (route == .queued) 1 else 1024,
                .queued_max_resource_attempts = 1,
            });
            defer result.deinit(allocator);
            try std.testing.expect(result == .ok);
            if (route == .direct) {
                try std.testing.expect(result.ok == .streaming);
            } else {
                try std.testing.expectEqual(ingest.QueuedSubmissionOutcome.queue_accepted, result.ok.queued.outcome);
            }
        }
        try std.testing.expectEqual(@as(usize, if (route == .queued) 0 else 1), capture.stageCount(.streaming));
        try std.testing.expectEqual(@as(usize, if (route == .direct) 0 else 1), capture.stageCount(.queue));
        try probe.expectUnmanaged();
        try std.testing.expectEqual(capture.count, try provider.drain(1000));
    }
}

const Executor = struct {
    fn asExecutor(self: *Executor) ingest.ResourceCommandExecutor {
        return .{ .context = self, .executeFn = execute };
    }

    fn execute(_: *anyopaque, alloc: std.mem.Allocator, _: []const u8, command: []const u8) !common.KustoResult(data.KustoResponseDataSet) {
        const body = if (std.mem.eql(u8, command, ".get ingestion resources")) resource_body else identity_body;
        const decoded = try data.decodeResponseDataSet(alloc, body, .{}, .management);
        return .{ .ok = decoded.dataset };
    }
};

test "tracing standalone and overridden queued options and retained setters remain tracing-only" {
    for ([_]bool{ false, true }) |with_connection| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        var capture: Capture = .{ .mock = &mock };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 8);
        defer provider.deinit() catch unreachable;
        var credential: Credential = .{};
        var handle = blk: {
            var inherited = instrumentation(&provider);
            inherited.scope_name = "ignored.connection.scope";
            inherited.scope_version = "0.0.0";
            inherited.namespace = "Ignored.Connection.Namespace";
            inherited.parent_context = null;
            const connection = if (with_connection) try connectionFor(runtime, &credential, .{
                .metadata_mode = .disabled,
                .instrumentation = inherited,
            }) else null;
            defer if (connection) |value| value.deinit();
            var executor: Executor = .{};
            var manager = try ingest.ResourceManager.init(allocator, std.testing.io, executor.asExecutor(), ingest.default_resource_database, .{});
            defer manager.deinit();
            var client = ingest.QueuedIngestClient.init(runtime, .{
                .connection = connection,
                .resource_manager = &manager,
                .instrumentation = instrumentation(&provider),
            });
            var result = try client.ingest(allocator, target, .{ .blob_uri = .{ .uri = "https://existing.blob.core.windows.net/private-source?sig=private-sas" } }, .{
                .source_id = source_id,
                .report_level = .failures_and_successes,
                .report_method = .queue_and_table,
                .queued_max_resource_attempts = 1,
            });
            defer result.deinit(allocator);
            try std.testing.expectEqual(ingest.QueuedSubmissionOutcome.queue_accepted, result.outcome);
            break :blk result.takeTracking().?;
        };
        defer handle.deinit();
        handle.setInstrumentation(null);
        var disabled = try handle.table.readEntity(source_id, source_id);
        disabled.deinit(allocator);
        try std.testing.expect(capture.contexts[2] == null);
        handle.setInstrumentation(instrumentation(&provider));
        var enabled = try handle.table.readEntity(source_id, source_id);
        enabled.deinit(allocator);
        try std.testing.expect(capture.contexts[3] != null);
        try probe.expectUnmanaged();
        try std.testing.expectEqual(@as(usize, 3), try provider.drain(1000));
        try std.testing.expectEqual(@as(usize, 4), capture.count);
        try std.testing.expectEqual(@as(usize, 0), credential.calls);
        try std.testing.expectEqual(@as(usize, 0), capture.stageCount(.blob));
    }
}

test "tracing preserves queued storage rejections unknown outcomes and pre-dispatch validation" {
    const Failure = enum { blob_rejected, blob_unknown, table_rejected, table_unknown, queue_rejected, queue_unknown, redirect, pre_dispatch };
    for (std.enums.values(Failure)) |failure| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        var capture: Capture = .{
            .mock = &mock,
            .fail_stage = switch (failure) {
                .blob_unknown => .blob,
                .table_unknown => .status_write,
                .queue_unknown => .queue,
                else => null,
            },
            .override_stage = switch (failure) {
                .blob_rejected => .blob,
                .table_rejected => .status_write,
                .queue_rejected, .redirect => .queue,
                else => null,
            },
            .override_status = if (failure == .redirect) 307 else 403,
        };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 8);
        defer provider.deinit() catch unreachable;
        var credential: Credential = .{};
        {
            const connection = try connectionFor(runtime, &credential, .{
                .metadata_mode = .disabled,
                .instrumentation = instrumentation(&provider),
                .retry = .{ .max_retries = 0 },
            });
            defer connection.deinit();
            var client = ingest.QueuedIngestClient.init(runtime, .{ .connection = connection });
            const result = client.ingest(allocator, target, .{ .bytes = "private-body" }, .{
                .source_id = if (failure == .pre_dispatch) "invalid" else source_id,
                .queued_compression = .none,
                .queued_max_resource_attempts = 1,
                .report_level = .failures_and_successes,
                .report_method = .queue_and_table,
            });
            if (failure == .pre_dispatch) {
                try std.testing.expectError(error.InvalidQueuedSourceId, result);
            } else {
                var submission = try result;
                defer submission.deinit(allocator);
                try std.testing.expectEqual(switch (failure) {
                    .queue_unknown => ingest.QueuedSubmissionOutcome.queue_unknown,
                    .queue_rejected, .redirect => ingest.QueuedSubmissionOutcome.queue_rejected,
                    else => ingest.QueuedSubmissionOutcome.pre_queue_failed,
                }, submission.outcome);
                try std.testing.expect(submission.tracking == null);
                if (failure == .queue_unknown) try std.testing.expectEqual(error.FixtureTransportFailure, submission.failure.?);
            }
        }
        const expected: usize = switch (failure) {
            .pre_dispatch => 0,
            .blob_rejected, .blob_unknown => 3,
            .table_rejected, .table_unknown => 4,
            else => 5,
        };
        try std.testing.expectEqual(expected, capture.count);
        try probe.expectUnmanaged();
        try std.testing.expectEqual(expected, try provider.drain(1000));
    }
}

test "tracing discovery errors query retry and credential pre-dispatch failure retain outcomes" {
    const Mode = enum { discovery_http, discovery_transport, credential, query_retry };
    for (std.enums.values(Mode)) |mode| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        var capture: Capture = .{
            .mock = &mock,
            .override_stage = if (mode == .discovery_http) .discovery else null,
            .fail_stage = if (mode == .discovery_transport) .discovery else null,
            .query_retry = mode == .query_retry,
        };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture, .require_wire = mode != .credential };
        var provider = try makeProvider(runtime, &probe, 2);
        defer provider.deinit() catch unreachable;
        var credential: Credential = .{ .fail = mode == .credential };
        const connected = connectionFor(runtime, &credential, .{
            .metadata_mode = if (mode == .credential or mode == .query_retry) .disabled else .discover,
            .instrumentation = instrumentation(&provider),
            .retry = .{ .max_retries = 1, .initial_delay_ms = 0, .max_delay_ms = 0 },
        });
        if (mode == .discovery_http) {
            try std.testing.expectError(error.KustoMetadataRequestFailed, connected);
        } else if (mode == .discovery_transport) {
            try std.testing.expectError(error.FixtureTransportFailure, connected);
        } else {
            const connection = try connected;
            defer connection.deinit();
            var client = data.KustoClient.init(connection, .{});
            const result = client.executeQueryResult(allocator, "private-db", "print 1", null);
            if (mode == .credential) {
                try std.testing.expectError(error.FixtureCredentialFailure, result);
            } else {
                var query = try result;
                defer query.deinit(allocator);
                try std.testing.expect(query == .ok);
                try std.testing.expectEqualStrings(&capture.contexts[0].?.span_id, &capture.contexts[1].?.span_id);
            }
        }
        try std.testing.expectEqual(@as(usize, if (mode == .credential) 0 else if (mode == .query_retry) 2 else 1), capture.count);
        try probe.expectUnmanaged();
        try std.testing.expectEqual(@as(usize, 1), try provider.drain(1000));
    }
}

test "tracing status read outcomes remain independent of completed header spans" {
    const Mode = enum { write_rejected, write_unknown, read_rejected, read_unknown, read_body_failure };
    for (std.enums.values(Mode)) |mode| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        var capture: Capture = .{
            .mock = &mock,
            .override_stage = switch (mode) {
                .write_rejected => .status_write,
                .read_rejected => .status_read,
                else => null,
            },
            .fail_stage = switch (mode) {
                .write_unknown => .status_write,
                .read_unknown => .status_read,
                else => null,
            },
            .fail_status_body = mode == .read_body_failure,
        };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 1);
        defer provider.deinit() catch unreachable;
        var handle = try ingest.StatusTrackingHandle.init(allocator, "https://account.table.core.windows.net/private-status?sig=private-sas", runtime, source_id, "private-db", "private-table");
        defer handle.deinit();
        handle.setInstrumentation(instrumentation(&provider));
        if (mode == .write_rejected or mode == .write_unknown) {
            const written = try handle.createInitialEntity("https://account.blob.core.windows.net/private-source?sig=private-sas", "2026-01-01T00:00:00Z");
            if (mode == .write_rejected) {
                try std.testing.expectEqual(@as(u16, 403), written.rejected.status_code);
            } else try std.testing.expectEqual(error.FixtureTransportFailure, written.unknown.cause);
        } else {
            var read = try handle.table.readEntity(source_id, source_id);
            defer read.deinit(allocator);
            if (mode == .read_rejected) {
                try std.testing.expectEqual(@as(u16, 403), read.rejected.status_code);
            } else try std.testing.expect(read == .unknown);
        }

        try std.testing.expectEqual(@as(usize, 1), capture.count);
        try probe.expectUnmanaged();
        try std.testing.expectEqual(@as(usize, 1), try provider.drain(1000));
        try std.testing.expectEqual(
            if (mode == .read_body_failure) core.tracing.SpanStatus.unset else .@"error",
            probe.statuses[0],
        );
    }
}

test "tracing allocation drops and explicit export failure preserve Kusto submission" {
    var propagation_failures: usize = 0;
    for (0..40) |offset| {
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        var capture: Capture = .{ .mock = &mock };
        const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
        var probe: Probe = .{ .capture = &capture };
        var provider = try makeProvider(runtime, &probe, 1);
        defer provider.deinit() catch unreachable;
        var failing = std.testing.FailingAllocator.init(allocator, .{});
        {
            var handle = try ingest.StatusTrackingHandle.init(
                failing.allocator(),
                "https://account.table.core.windows.net/private-status?sig=private-sas",
                runtime,
                source_id,
                "private-db",
                "private-table",
            );
            defer handle.deinit();
            handle.setInstrumentation(instrumentation(&provider));
            failing.fail_index = failing.alloc_index + offset;
            if (handle.createInitialEntity("https://account.blob.core.windows.net/private-source?sig=private-sas", "2026-01-01T00:00:00Z")) |outcome| {
                try std.testing.expectEqual(@as(u16, 204), outcome.accepted.status_code);
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
        try probe.expectUnmanaged();
        _ = try provider.drain(1000);
    }
    try std.testing.expectEqual(@as(usize, 4), propagation_failures);

    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    var capture: Capture = .{ .mock = &mock };
    const runtime = core.http.HttpRuntime.init(capture.asTransport(), crypto.asProvider());
    var probe: Probe = .{ .capture = &capture, .fail = true };
    var provider = try makeProvider(runtime, &probe, 1);
    defer provider.deinit() catch unreachable;
    var credential: Credential = .{};
    {
        const connection = try connectionFor(runtime, &credential, .{
            .metadata_mode = .disabled,
            .instrumentation = instrumentation(&provider),
        });
        defer connection.deinit();
        var client = ingest.QueuedIngestClient.init(runtime, .{ .connection = connection });
        var result = try client.ingest(allocator, target, .{ .bytes = "private-body" }, .{
            .source_id = source_id,
            .queued_compression = .none,
            .queued_max_resource_attempts = 1,
            .report_level = .failures_and_successes,
            .report_method = .queue_and_table,
        });
        defer result.deinit(allocator);
        try std.testing.expectEqual(ingest.QueuedSubmissionOutcome.queue_accepted, result.outcome);
        try std.testing.expectEqual(@as(usize, 5), capture.count);
        try std.testing.expectEqual(@as(u64, 4), provider.stats().dropped_spans);
        try probe.expectUnmanaged();
        try std.testing.expectError(error.FixtureExportFailure, provider.forceFlush(1000));
        try std.testing.expectEqual(@as(u64, 1), provider.stats().export_errors);
        try std.testing.expectEqual(ingest.QueuedSubmissionOutcome.queue_accepted, result.outcome);
        try std.testing.expectEqual(@as(usize, 5), capture.count);
    }
}
