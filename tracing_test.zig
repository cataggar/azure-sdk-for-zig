const std = @import("std");
const core = @import("azure_sdk_core");
const clients = @import("client.zig");
const service_clients = @import("service_client.zig");
const options = @import("options.zig");
const protocol_clients = @import("protocol_client.zig");
const auth = @import("auth.zig");
const transaction = @import("transaction.zig");

const required_headers = [_]core.http.MockTransport.HeaderPair{
    .{ .name = "x-ms-version", .value = "2019-02-02" },
    .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
};
const json_headers = required_headers ++ [_]core.http.MockTransport.HeaderPair{
    .{ .name = "Content-Type", .value = "application/json" },
};
const xml_headers = required_headers ++ [_]core.http.MockTransport.HeaderPair{
    .{ .name = "Content-Type", .value = "application/xml" },
};

const Probe = struct {
    exporter: core.tracing.SpanExporter = .{ .exportFn = exportSpans },
    expected: [16]?core.tracing.TraceContext = @splat(null),
    errors: [16]bool = @splat(false),
    count: usize = 0,
    exported: usize = 0,

    fn parent() core.tracing.TraceContext {
        var context = core.tracing.TraceContext.parseTraceparent(
            "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01",
        ).?;
        context.trace_state = "vendor=tables";
        return context;
    }

    fn instrumentation(provider: *core.tracing.TracerProvider) core.tracing.InstrumentationOptions {
        return .{
            .provider = provider,
            .scope_name = "caller.tables",
            .scope_version = "caller-version",
            .namespace = "Caller.Tables",
            .parent_context = parent(),
        };
    }

    fn dispatched(self: *Probe, mock: *core.http.MockTransport, enabled: bool, failed: bool) !void {
        if (!enabled) {
            try std.testing.expect(mock.last_headers.get("traceparent") == null);
            try std.testing.expect(mock.last_headers.get("tracestate") == null);
            return;
        }
        const context = core.tracing.TraceContext.parseTraceparent(
            mock.last_headers.get("traceparent") orelse return error.MissingTraceparent,
        ) orelse return error.InvalidTraceparent;
        try std.testing.expectEqualStrings("vendor=tables", mock.last_headers.get("tracestate").?);
        for (self.expected[0..self.count]) |previous| {
            if (previous) |value| try std.testing.expect(!std.mem.eql(u8, &value.span_id, &context.span_id));
        }
        self.expected[self.count] = context;
        self.errors[self.count] = failed;
        self.count += 1;
    }

    fn beforeDispatchFailure(self: *Probe, enabled: bool) void {
        if (!enabled) return;
        self.errors[self.count] = true;
        self.count += 1;
    }

    fn exportSpans(
        exporter: *core.tracing.SpanExporter,
        spans: []const core.tracing.SpanData,
        _: core.tracing.ExportContext,
    ) anyerror!void {
        const self: *Probe = @fieldParentPtr("exporter", exporter);
        for (spans) |span| {
            try std.testing.expect(self.exported < self.count);
            const index = self.exported;
            try std.testing.expectEqualStrings("caller.tables", span.scope_name);
            try std.testing.expectEqualStrings("caller-version", span.scope_version);
            try std.testing.expectEqual(core.tracing.SpanKind.client, span.kind);
            try std.testing.expectEqual(
                if (self.errors[index]) core.tracing.SpanStatus.@"error" else .unset,
                span.status,
            );
            try std.testing.expectEqualStrings(&parent().trace_id, &span.context.trace_id);
            try std.testing.expectEqualStrings(&parent().span_id, &span.parent_span_id.?);
            try std.testing.expectEqualStrings("vendor=tables", span.context.trace_state orelse "");
            if (self.expected[index]) |wire| {
                try std.testing.expectEqualStrings(&wire.trace_id, &span.context.trace_id);
                try std.testing.expectEqualStrings(&wire.span_id, &span.context.span_id);
            }
            var found_namespace = false;
            for (span.attributes) |attribute| {
                try std.testing.expect(!std.mem.eql(u8, "url.full", attribute.key));
                if (attribute.value == .string) {
                    try std.testing.expect(std.mem.indexOf(u8, attribute.value.string, "sig=") == null);
                    try std.testing.expect(std.mem.indexOf(u8, attribute.value.string, "Bearer fixed-token") == null);
                    try std.testing.expect(std.mem.indexOf(u8, attribute.value.string, "SharedKeyLite ") == null);
                }
                if (std.mem.eql(u8, attribute.key, "az.namespace")) {
                    try std.testing.expectEqualStrings("Caller.Tables", attribute.value.string);
                    found_namespace = true;
                }
            }
            try std.testing.expect(found_namespace);
            self.exported += 1;
        }
    }

    fn flushAndCheck(self: *Probe, provider: *core.tracing.ExportingTracerProvider) !void {
        try std.testing.expectEqual(@as(usize, 0), self.exported);
        try std.testing.expectEqual(@as(usize, 0), provider.stats().active_spans);
        try std.testing.expectEqual(self.count, provider.stats().queued_spans);
        try std.testing.expect(!provider.closed);
        try provider.forceFlush(1000);
        try std.testing.expectEqual(self.count, self.exported);
        try provider.shutdown(1000);
    }
};

const CallPolicy = struct {
    policy: core.http.HttpPolicy = .{ .processFn = process },
    calls: usize = 0,
    fail: bool = false,

    fn process(
        policy: *core.http.HttpPolicy,
        request: *core.http.Request,
        next: []*core.http.HttpPolicy,
        runtime: core.http.HttpRuntime,
    ) anyerror!core.http.Response {
        const self: *CallPolicy = @fieldParentPtr("policy", policy);
        self.calls += 1;
        if (self.fail) return error.CallerPolicyFailure;
        try request.setHeader("x-call-policy", "present");
        if (next.len == 0) return runtime.transport.send(request);
        return next[0].process(request, next[1..], runtime);
    }
};

test "canonical Tables clients preserve tracing through auth branches descendants and pagers" {
    const allocator = std.testing.allocator;
    const TypedEntity = struct { partition_key: []const u8, row_key: []const u8 };
    for ([_]bool{ true, false }) |enabled| {
        for ([_]enum { token, shared_key, sas, connection_key, connection_sas, development }{
            .token, .shared_key, .sas, .connection_key, .connection_sas, .development,
        }) |mode| {
            var mock = core.http.MockTransport.init(allocator, 200, "");
            defer mock.deinit();
            mock.response_headers_list = &json_headers;
            var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
            const runtime = core.http.HttpRuntime.init(mock.asTransport(), crypto.asProvider());
            var probe = Probe{};
            var provider = try core.tracing.ExportingTracerProvider.init(
                allocator,
                std.testing.io,
                runtime.crypto,
                &probe.exporter,
                .{},
            );
            defer provider.deinit() catch unreachable;
            var credential = core.env_token.EnvTokenCredential.init(allocator, "fixed-token");
            var key = try auth.SharedKeyCredential.init(allocator, "account", "YWNjb3VudC1rZXk=");
            defer key.deinit();
            const authentication: options.ClientAuthentication = switch (mode) {
                .token => .{ .token = .{ .endpoint = "https://account.table.core.windows.net", .credential = credential.asCredential() } },
                .shared_key => .{ .shared_key = .{ .endpoint = "https://account.table.core.windows.net", .credential = &key } },
                .sas => .{ .sas_url = "https://account.table.core.windows.net?sv=1%2F2&sig=a+b%3D&sp=r" },
                .connection_key => .{ .connection_string = "AccountName=account;AccountKey=YWNjb3VudC1rZXk=;TableEndpoint=https://account.table.core.windows.net" },
                .connection_sas => .{ .connection_string = "TableEndpoint=https://account.table.core.windows.net;SharedAccessSignature=sv=1%2F2&sig=a+b%3D&sp=r" },
                .development => .{ .connection_string = "UseDevelopmentStorage=true" },
            };
            var per_call = CallPolicy{};
            const client_options: options.TableClientOptions = .{
                .instrumentation = if (enabled) Probe.instrumentation(provider.asProvider()) else null,
            };
            {
                var service = try service_clients.TableServiceClient.init(allocator, runtime, .{
                    .authentication = authentication,
                    .options = client_options,
                });
                defer service.deinit();
                var direct = try clients.TableClient.init(allocator, runtime, .{
                    .authentication = authentication,
                    .table_name = "People",
                    .options = client_options,
                });
                defer direct.deinit();
                var derived = try service.getTableClient("People");
                defer derived.deinit();

                mock.response_status = 204;
                var deleted = try service.deleteTable(allocator, "People", .{});
                defer deleted.deinit();
                try probe.dispatched(&mock, enabled, false);
                mock.response_status = 200;
                mock.response_body = "{\"PartitionKey\":\"p\",\"RowKey\":\"r\"}";
                {
                    var response = try direct.getEntityRaw(allocator, "p", "r");
                    defer response.deinit();
                    try probe.dispatched(&mock, enabled, false);
                    switch (mode) {
                        .token => try std.testing.expectEqualStrings("Bearer fixed-token", mock.last_headers.get("Authorization").?),
                        .shared_key, .connection_key, .development => try std.testing.expect(std.mem.startsWith(u8, mock.last_headers.get("Authorization").?, "SharedKeyLite ")),
                        .sas, .connection_sas => {
                            try std.testing.expect(mock.last_headers.get("Authorization") == null);
                            try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "sig=a+b%3D") != null);
                        },
                    }
                }
                {
                    var response = try derived.getEntityRaw(allocator, "p", "r");
                    defer response.deinit();
                    try probe.dispatched(&mock, enabled, false);
                }

                var tables = try service.listTables(allocator, .{
                    .protocol = .{ .policies = &.{&per_call.policy} },
                });
                defer tables.deinit();
                mock.response_body = "{\"value\":[{\"TableName\":\"People\"}]}";
                mock.response_headers_list = &(json_headers ++ [_]core.http.MockTransport.HeaderPair{
                    .{ .name = "x-ms-continuation-NextTableName", .value = "Next" },
                });
                try std.testing.expect((try tables.next()) != null);
                try probe.dispatched(&mock, enabled, false);
                mock.response_headers_list = &json_headers;
                try std.testing.expect((try tables.next()) != null);
                try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "NextTableName=Next") != null);
                try probe.dispatched(&mock, enabled, false);
                try std.testing.expect((try tables.next()) == null);

                var entities = try derived.queryEntities(TypedEntity, allocator, .{
                    .protocol = .{ .policies = &.{&per_call.policy} },
                });
                defer entities.deinit();
                mock.response_body = "{\"value\":[{\"PartitionKey\":\"p\",\"RowKey\":\"r\"}]}";
                mock.response_headers_list = &(json_headers ++ [_]core.http.MockTransport.HeaderPair{
                    .{ .name = "x-ms-continuation-NextPartitionKey", .value = "next" },
                    .{ .name = "x-ms-continuation-NextRowKey", .value = "row" },
                });
                const page = (try entities.next()).?;
                try std.testing.expectEqual(@as(usize, 1), page.values.len);
                try probe.dispatched(&mock, enabled, false);
                mock.response_headers_list = &json_headers;
                try std.testing.expect((try entities.next()) != null);
                try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "NextPartitionKey=next") != null);
                try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "NextRowKey=row") != null);
                try probe.dispatched(&mock, enabled, false);
                try std.testing.expect((try entities.next()) == null);
                try std.testing.expectEqual(@as(usize, 4), per_call.calls);

                mock.response_body = "<SignedIdentifiers/>";
                mock.response_headers_list = &xml_headers;
                var access = try direct.getAccessPolicy(allocator, .{});
                defer access.deinit();
                try probe.dispatched(&mock, enabled, false);
                mock.response_body = "<StorageServiceProperties/>";
                var properties = try service.getServiceProperties(allocator, .{});
                defer properties.deinit();
                try probe.dispatched(&mock, enabled, false);

                mock.response_status = 204;
                mock.response_body = "";
                mock.response_headers_list = &(json_headers ++ [_]core.http.MockTransport.HeaderPair{
                    .{ .name = "ETag", .value = "W/\"updated\"" },
                });
                const updated_entity: TypedEntity = .{ .partition_key = "p", .row_key = "r" };
                var updated = try direct.updateEntity(allocator, updated_entity, .{ .mode = .replace });
                defer updated.deinit();
                try std.testing.expectEqualStrings("W/\"updated\"", updated.etag);
                try probe.dispatched(&mock, enabled, false);

                var batch = transaction.TransactionBuilder.init(allocator);
                defer batch.deinit();
                try batch.delete("p", "r", "*");
                mock.response_status = 202;
                mock.response_headers_list = &.{.{ .name = "Content-Type", .value = "multipart/mixed; boundary=batchresponse" }};
                mock.response_body =
                    "--batchresponse\r\nContent-Type: multipart/mixed; boundary=changesetresponse\r\n\r\n" ++
                    "--changesetresponse\r\nContent-Type: application/http\r\nContent-Transfer-Encoding: binary\r\n\r\n" ++
                    "HTTP/1.1 204 No Content\r\nContent-ID: 1\r\n\r\n\r\n" ++
                    "--changesetresponse--\r\n--batchresponse--\r\n";
                var submitted = try derived.submitTransaction(allocator, &batch, .{});
                defer submitted.deinit();
                try std.testing.expectEqual(@as(usize, 1), submitted.operations.len);
                try std.testing.expectEqual(@as(u16, 204), submitted.operations[0].status);
                try probe.dispatched(&mock, enabled, false);
                try std.testing.expectEqual(@as(usize, 11), mock.call_count);
                // Per-call policies never become part of the reusable base pipeline.
                try std.testing.expectEqual(@as(usize, 4), per_call.calls);
            }
            try probe.flushAndCheck(&provider);
        }
    }
}

test "supplied Tables protocol pipeline preserves tracing policy rebinding and service failures" {
    const allocator = std.testing.allocator;
    for ([_]bool{ true, false }) |enabled| {
        var mock = core.http.MockTransport.init(allocator, 200, "");
        defer mock.deinit();
        mock.response_headers_list = &json_headers;
        var crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
        const runtime = core.http.HttpRuntime.init(mock.asTransport(), crypto.asProvider());
        var probe = Probe{};
        var provider = try core.tracing.ExportingTracerProvider.init(
            allocator,
            std.testing.io,
            runtime.crypto,
            &probe.exporter,
            .{},
        );
        defer provider.deinit() catch unreachable;
        var base_policy = CallPolicy{};
        var per_call = CallPolicy{};
        var base_policies = [_]*core.http.HttpPolicy{&base_policy.policy};
        var pipeline = core.http.HttpPipeline.init(runtime, &base_policies);
        pipeline.setInstrumentation(if (enabled) Probe.instrumentation(provider.asProvider()) else null);
        {
            var protocol = try protocol_clients.ProtocolClient.init(
                allocator,
                "https://account.table.core.windows.net",
                pipeline,
                .{},
            );
            defer protocol.deinit();
            mock.response_status = 204;
            var success = try protocol.deleteTable(allocator, "People", .{
                .protocol = .{ .policies = &.{&per_call.policy} },
            });
            defer success.deinit(allocator);
            try std.testing.expect(success == .success);
            try probe.dispatched(&mock, enabled, false);
            per_call.fail = true;
            try std.testing.expectError(error.CallerPolicyFailure, protocol.deleteTable(allocator, "People", .{
                .protocol = .{ .policies = &.{&per_call.policy} },
            }));
            probe.beforeDispatchFailure(enabled);
            try std.testing.expectEqual(@as(usize, 1), mock.call_count);

            mock.response_status = 404;
            mock.response_body = "{\"odata.error\":{\"code\":\"TableNotFound\",\"message\":{\"lang\":\"en-US\",\"value\":\"missing\"}}}";
            var failure = try protocol.deleteTable(allocator, "People", .{});
            defer failure.deinit(allocator);
            try std.testing.expect(failure == .failure);
            try std.testing.expectEqual(@as(u16, 404), failure.failure.status);
            try std.testing.expectEqualStrings("TableNotFound", failure.failure.code);
            try probe.dispatched(&mock, enabled, true);
            try std.testing.expectEqual(@as(usize, 2), per_call.calls);
            try std.testing.expectEqual(@as(usize, 3), base_policy.calls);
            try std.testing.expectEqual(@as(usize, 1), protocol.pipeline.policies.len);
            try std.testing.expectEqual(&base_policy.policy, protocol.pipeline.policies[0]);
        }
        try probe.flushAndCheck(&provider);
    }
}
