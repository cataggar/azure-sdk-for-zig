//! Tests for `DevOpsClient` that exercise the pipeline against a stub
//! transport rather than the service.

const std = @import("std");
const core = @import("azure_sdk_core");
const root = @import("root.zig");

const DevOpsClient = root.DevOpsClient;

test "every area is reachable from one authenticated client" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .credential = .fromPat("secret-pat"),
        .runtime = runtime,
    });
    defer client.deinit();

    const git = client.git();
    const build = client.build();
    const work_item_tracking = client.workItemTracking();
    const test_management = client.testManagement();

    try std.testing.expect(@hasDecl(@TypeOf(git), "repositories"));
    try std.testing.expect(@hasDecl(@TypeOf(build), "builds"));
    try std.testing.expect(@hasDecl(@TypeOf(work_item_tracking), "workItems"));
    try std.testing.expect(@hasDecl(@TypeOf(test_management), "runs"));
}

test "areas keep their own hosts unless the caller overrides the endpoint" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .runtime = runtime,
    });
    defer client.deinit();

    const git = client.git();
    const graph = client.graph();
    const notification = client.notification();
    try std.testing.expectEqualStrings("https://dev.azure.com", git.endpoint);
    try std.testing.expectEqualStrings("https://vssps.dev.azure.com", graph.endpoint);
    try std.testing.expectEqualStrings("https://dev.azure.com", notification.endpoint);

    // Azure DevOps Server serves every area from one collection URL.
    var server = try DevOpsClient.init(allocator, .{
        .organization = "DefaultCollection",
        .runtime = runtime,
        .endpoint = "https://tfs.contoso.com/tfs",
    });
    defer server.deinit();
    const server_git = server.git();
    const server_graph = server.graph();
    const server_notification = server.notification();
    try std.testing.expectEqualStrings("https://tfs.contoso.com/tfs", server_git.endpoint);
    try std.testing.expectEqualStrings("https://tfs.contoso.com/tfs", server_graph.endpoint);
    try std.testing.expectEqualStrings("https://tfs.contoso.com/tfs", server_notification.endpoint);
}

test "requests carry the PAT and the SDK user agent" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(
        allocator,
        200,
        "{\"count\":0,\"value\":[]}",
    );
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .credential = .fromPat("secret-pat"),
        .runtime = runtime,
    });
    defer client.deinit();

    var status = client.status();
    var health = status.health();
    const result = health.get(allocator, null, null) catch |err| switch (err) {
        error.AzureRequestFailed => return error.SkipZigTest,
        else => return err,
    };
    _ = result;

    try std.testing.expectStringStartsWith(
        transport.last_headers.get("Authorization").?,
        "Basic ",
    );
    try std.testing.expectEqualStrings(
        root.user_agent,
        transport.last_headers.get("User-Agent").?,
    );
}

test "the api-version is pinned to the generated 7.2 contract" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .runtime = runtime,
    });
    defer client.deinit();

    const git = client.git();
    try std.testing.expectStringStartsWith(git.api_version, "7.2");
}

test "derived operation clients preserve the selected runtime" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try DevOpsClient.init(allocator, .{
        .organization = "contoso",
        .runtime = runtime,
    });
    defer client.deinit();

    var git = client.git();
    const repositories = git.repositories();
    try std.testing.expectEqual(
        runtime.transport.context,
        repositories.pipeline.runtime.transport.context,
    );
    try std.testing.expectEqual(
        runtime.transport.vtable,
        repositories.pipeline.runtime.transport.vtable,
    );
    try std.testing.expectEqual(
        runtime.crypto.context,
        repositories.pipeline.runtime.crypto.context,
    );
    try std.testing.expectEqual(
        runtime.crypto.vtable,
        repositories.pipeline.runtime.crypto.vtable,
    );
}

const SpanProbe = struct {
    exporter: core.tracing.SpanExporter = .{ .exportFn = exportBatch },
    wire_ids: [4][16]u8 = undefined,
    statuses: [4]u16 = @splat(200),
    count: usize = 0,

    fn exportBatch(exporter: *core.tracing.SpanExporter, spans: []const core.tracing.SpanData, _: core.tracing.ExportContext) !void {
        const self: *@This() = @fieldParentPtr("exporter", exporter);
        for (spans) |span| {
            try std.testing.expectEqualStrings("caller.devops", span.scope_name);
            try std.testing.expectEqualStrings("custom-1", span.scope_version);
            try std.testing.expectEqualStrings("HTTP", span.name);
            try std.testing.expectEqual(core.tracing.SpanKind.client, span.kind);
            try std.testing.expectEqual(
                if (self.statuses[self.count] >= 400) core.tracing.SpanStatus.@"error" else .unset,
                span.status,
            );
            try std.testing.expectEqualStrings("b7ad6b7169203331", &span.parent_span_id.?);
            try std.testing.expectEqualStrings("0af7651916cd43dd8448eb211c80319c", &span.context.trace_id);
            try std.testing.expectEqualStrings(&self.wire_ids[self.count], &span.context.span_id);
            var namespace = false;
            var status = false;
            for (span.attributes) |attribute| {
                if (std.mem.eql(u8, attribute.key, "az.namespace")) {
                    try std.testing.expectEqualStrings("Caller.Namespace", attribute.value.string);
                    namespace = true;
                }
                if (std.mem.eql(u8, attribute.key, "http.response.status_code")) {
                    try std.testing.expectEqual(@as(i64, self.statuses[self.count]), attribute.value.int);
                    status = true;
                }
                try std.testing.expect(!std.mem.eql(u8, attribute.key, "url.full"));
                if (attribute.value == .string)
                    try std.testing.expect(std.mem.indexOf(u8, attribute.value.string, "test-pat") == null);
            }
            try std.testing.expect(namespace and status);
            self.count += 1;
        }
    }

    fn capture(self: *@This(), transport: *core.http.MockTransport, index: usize) !void {
        const context = core.tracing.TraceContext.parseTraceparent(transport.last_headers.get("traceparent").?).?;
        self.wire_ids[index] = context.span_id;
        try std.testing.expectEqualStrings("vendor=caller", transport.last_headers.get("tracestate").?);
    }
};

fn instrumentation(provider: *core.tracing.ExportingTracerProvider) core.tracing.InstrumentationOptions {
    var parent = core.tracing.TraceContext.parseTraceparent("00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01").?;
    parent.trace_state = "vendor=caller";
    return .{
        .provider = provider.asProvider(),
        .scope_name = "caller.devops",
        .scope_version = "custom-1",
        .namespace = "Caller.Namespace",
        .parent_context = parent,
    };
}

fn expectEveryPipeline(client: *DevOpsClient) !void {
    @setEvalBranchQuota(500_000);
    var areas: usize = 0;
    var groups: usize = 0;
    inline for (comptime std.meta.declarations(DevOpsClient)) |decl| {
        const accessor = @field(DevOpsClient, decl.name);
        const info = @typeInfo(@TypeOf(accessor));
        if (info == .@"fn" and info.@"fn".params.len == 1 and
            info.@"fn".params[0].type == *DevOpsClient)
        {
            const Area = info.@"fn".return_type.?;
            if (@typeInfo(Area) == .@"struct" and @hasField(Area, "pipeline")) {
                var area = @call(.auto, accessor, .{client});
                try std.testing.expectEqualDeep(client.pipeline, area.pipeline);
                areas += 1;
                inline for (comptime std.meta.declarations(Area)) |group_decl| {
                    const group_accessor = @field(Area, group_decl.name);
                    const group_info = @typeInfo(@TypeOf(group_accessor));
                    if (group_info == .@"fn" and group_info.@"fn".params.len == 1 and
                        group_info.@"fn".params[0].type == *Area)
                    {
                        const Group = group_info.@"fn".return_type.?;
                        if (@typeInfo(Group) == .@"struct" and @hasField(Group, "pipeline")) {
                            const group = @call(.auto, group_accessor, .{&area});
                            try std.testing.expectEqualDeep(client.pipeline, group.pipeline);
                            groups += 1;
                        }
                    }
                }
            }
        }
    }
    try std.testing.expectEqual(@as(usize, 44), areas);
    try std.testing.expectEqual(@as(usize, 371), groups);
}

test "optional tracing survives SDK and area copies without changing auth results or provider lifetime" {
    const Mode = enum { default, enabled, disabled, forbidden };
    for ([_]Mode{ .default, .enabled, .disabled, .forbidden }) |mode| {
        const traced = mode == .enabled or mode == .forbidden;
        const status: u16 = if (mode == .forbidden) 403 else 200;
        var transport = core.http.MockTransport.init(std.testing.allocator, status, "{}");
        defer transport.deinit();
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        const runtime = core.http.HttpRuntime.init(transport.asTransport(), crypto.asProvider());
        var probe: SpanProbe = .{};
        probe.statuses[0] = status;
        var provider = try core.tracing.ExportingTracerProvider.init(
            std.testing.allocator,
            std.testing.io,
            runtime.crypto,
            &probe.exporter,
            .{},
        );
        defer provider.deinit() catch unreachable;
        {
            var options: root.ClientOptions = .{
                .organization = "contoso",
                .credential = .fromPat("test-pat"),
                .runtime = runtime,
            };
            try std.testing.expect(options.instrumentation == null);
            if (mode != .default) options.instrumentation = instrumentation(&provider);
            if (mode == .disabled) options.instrumentation = null;
            var client = try DevOpsClient.init(std.testing.allocator, options);
            defer client.deinit();
            try std.testing.expectEqualDeep(options.instrumentation, client.pipeline.instrumentation);
            try std.testing.expectEqualStrings(root.devops_scope, client.credential_policy.scope);
            options.instrumentation = null;
            try expectEveryPipeline(&client);
            var git = client.git();
            var repositories = git.repositories();
            if (mode == .forbidden) {
                try std.testing.expectError(error.AzureRequestFailed, repositories.delete(
                    std.testing.allocator,
                    client.organization,
                    "repository",
                    "project",
                ));
            } else {
                try repositories.delete(std.testing.allocator, client.organization, "repository", "project");
            }
            try std.testing.expectEqualStrings("azsdk-zig-devops/0.2.0", transport.last_headers.get("User-Agent").?);
            try std.testing.expectStringStartsWith(transport.last_headers.get("Authorization").?, "Basic ");
            try std.testing.expectEqual(traced, transport.last_headers.contains("traceparent"));
            if (traced) try probe.capture(&transport, 0) else try std.testing.expect(!transport.last_headers.contains("tracestate"));
            try std.testing.expectEqual(@as(usize, 1), transport.call_count);
        }
        // The client's policies and request storage are gone; the provider still belongs to us.
        const expected: u64 = if (traced) 1 else 0;
        try std.testing.expectEqual(expected, provider.stats().started);
        try std.testing.expectEqual(expected, provider.stats().ended);
        try std.testing.expectEqual(@as(usize, 0), provider.stats().active_spans);
        try std.testing.expectEqual(@as(usize, 0), probe.count);
        try std.testing.expect(!provider.closed);
        try provider.forceFlush(1000);
        try std.testing.expectEqual(@as(usize, @intCast(expected)), probe.count);
        try provider.shutdown(1000);
    }
}

const AuditFetcher = struct {
    log: root.protocol.audit.AuditLog,
    arena: std.mem.Allocator,

    pub fn fetch(self: *@This(), allocator: std.mem.Allocator, token: ?[]const u8) !root.Page(root.protocol.audit.models.DecoratedAuditLogEntry) {
        const response = try self.log.query(self.arena, "contoso", null, null, 1, token, null);
        return .{
            .items = try allocator.dupe(root.protocol.audit.models.DecoratedAuditLogEntry, response.decorated_audit_log_entries orelse &.{}),
            .continuation_token = if (response.has_more orelse false) response.continuation_token else null,
        };
    }
};

test "continuation pager uses the copied instrumented area pipeline for each real page" {
    var transport = core.http.MockTransport.init(std.testing.allocator, 200,
        \\{"decoratedAuditLogEntries":[{"actionId":"first"}],"hasMore":true,"continuationToken":"next"}
    );
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(transport.asTransport(), crypto.asProvider());
    var probe: SpanProbe = .{};
    var provider = try core.tracing.ExportingTracerProvider.init(
        std.testing.allocator,
        std.testing.io,
        runtime.crypto,
        &probe.exporter,
        .{},
    );
    defer provider.deinit() catch unreachable;
    {
        var client = try DevOpsClient.init(std.testing.allocator, .{
            .organization = "contoso",
            .credential = .fromPat("test-pat"),
            .runtime = runtime,
            .instrumentation = instrumentation(&provider),
        });
        defer client.deinit();
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var audit = client.audit();
        var fetcher: AuditFetcher = .{ .log = audit.auditLog(), .arena = arena.allocator() };
        try std.testing.expectEqualDeep(client.pipeline, fetcher.log.pipeline);
        var pager = root.ContinuationPager(root.protocol.audit.models.DecoratedAuditLogEntry, AuditFetcher).init(&fetcher);
        const first = (try pager.next(std.testing.allocator)).?;
        defer std.testing.allocator.free(first);
        try std.testing.expectEqualStrings("first", first[0].action_id.?);
        try probe.capture(&transport, 0);
        transport.response_body =
            \\{"decoratedAuditLogEntries":[{"actionId":"second"}],"hasMore":false}
        ;
        const second = (try pager.next(std.testing.allocator)).?;
        defer std.testing.allocator.free(second);
        try std.testing.expectEqualStrings("second", second[0].action_id.?);
        try std.testing.expect(std.mem.indexOf(u8, transport.last_url.?, "continuationToken=next") != null);
        try probe.capture(&transport, 1);
        try std.testing.expect(!std.mem.eql(u8, &probe.wire_ids[0], &probe.wire_ids[1]));
        try std.testing.expect((try pager.next(std.testing.allocator)) == null);
        try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    }
    try std.testing.expectEqual(@as(u64, 2), provider.stats().ended);
    try std.testing.expectEqual(@as(usize, 0), probe.count);
    try std.testing.expect(!provider.closed);
    try provider.forceFlush(1000);
    try std.testing.expectEqual(@as(usize, 2), probe.count);
    try provider.shutdown(1000);
}
