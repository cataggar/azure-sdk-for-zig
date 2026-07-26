const std = @import("std");
const core = @import("azure_sdk_core");
const errors = @import("errors.zig");
const protocol = @import("azure_rest_data_tables");
const serde = @import("serde");
const options = @import("options.zig");
const pipeline_mod = @import("pipeline.zig");
const request = @import("request.zig");
const responses = @import("responses.zig");

const ProtocolTable = @typeInfo(@TypeOf(protocol.TablesClient.table)).@"fn".return_type.?;

pub const QueryTablesResponse = ProtocolTable.QueryResult;
pub const QueryEntitiesResponse = ProtocolTable.QueryEntitiesResult;
pub const CreateTableResponse = ProtocolTable.CreateResult;
pub const DeleteTableResponse = ProtocolTable.DeleteResult;

/// Validated bridge from SDK options to the generated Tables protocol client.
pub const ProtocolClient = struct {
    allocator: std.mem.Allocator,
    endpoint: request.NormalizedEndpoint,
    endpoint_query_is_sas: bool,
    api_version: []u8,
    pipeline: core.pipeline.HttpPipeline,

    pub const InitOptions = struct {
        api_version: []const u8 = options.latest_api_version,
        endpoint_query_is_sas: bool = false,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        http_pipeline: core.pipeline.HttpPipeline,
        init_options: InitOptions,
    ) !ProtocolClient {
        try request.validateApiVersion(init_options.api_version);
        var normalized = try request.NormalizedEndpoint.init(allocator, endpoint);
        errdefer normalized.deinit();
        return .{
            .allocator = allocator,
            .endpoint = normalized,
            .endpoint_query_is_sas = init_options.endpoint_query_is_sas,
            .api_version = try allocator.dupe(u8, init_options.api_version),
            .pipeline = http_pipeline,
        };
    }

    pub fn deinit(self: *ProtocolClient) void {
        self.endpoint.deinit();
        self.allocator.free(self.api_version);
        self.* = undefined;
    }

    /// Clones immutable request configuration while retaining the same
    /// heap-stable pipeline. The source client and its pipeline owner must
    /// outlive the clone.
    pub fn clone(self: *const ProtocolClient, allocator: std.mem.Allocator) !ProtocolClient {
        if (self.endpoint.has_query) {
            const endpoint = try std.fmt.allocPrint(
                allocator,
                "{s}?{s}",
                .{ self.endpoint.base_url, self.endpoint.raw_query },
            );
            defer allocator.free(endpoint);
            return init(allocator, endpoint, self.pipeline, .{
                .api_version = self.api_version,
                .endpoint_query_is_sas = self.endpoint_query_is_sas,
            });
        }
        return init(allocator, self.endpoint.base_url, self.pipeline, .{
            .api_version = self.api_version,
            .endpoint_query_is_sas = self.endpoint_query_is_sas,
        });
    }

    pub fn queryEntity(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        partition_key: []const u8,
        row_key: []const u8,
        query_options: options.QueryEntityOptions,
    ) !responses.SdkResponse(ProtocolTable.QueryEntityWithPartitionAndRowKeyResult) {
        try request.validateTableName(table_name);
        try request.validateEntityKey(partition_key);
        try request.validateEntityKey(row_key);
        try request.validateProtocolOptions(query_options.protocol);

        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();

        var call = try self.beginCall(arena_allocator, query_options.protocol, null);
        defer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(
            arena_allocator,
            call.pipeline,
            .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version },
        );
        var table = generated.table();
        const value = try table.queryEntityWithPartitionAndRowKey(
            arena_allocator,
            query_options.protocol.client_request_id,
            table_name,
            query_options.protocol.timeout,
            query_options.protocol.metadata,
            query_options.select,
            query_options.filter,
            partition_key,
            row_key,
        );
        const metadata = try call.takeResponse();
        return .{
            .value = value,
            .status = metadata.status,
            .headers = metadata.headers,
            .arena = arena,
            .allocator = allocator,
        };
    }

    pub fn queryEntities(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        query_options: options.QueryEntitiesOptions,
    ) !responses.SdkResponse(QueryEntitiesResponse) {
        try request.validateTableName(table_name);
        try request.validateProtocolOptions(query_options.protocol);
        if (query_options.top) |top| {
            if (top <= 0) return error.InvalidTop;
        }

        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();

        var call = try self.beginCall(arena_allocator, query_options.protocol, null);
        defer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(
            arena_allocator,
            call.pipeline,
            .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version },
        );
        var table = generated.table();
        const value = try table.queryEntities(
            arena_allocator,
            query_options.protocol.client_request_id,
            table_name,
            query_options.protocol.metadata,
            query_options.top,
            query_options.select,
            query_options.filter,
            query_options.protocol.timeout,
            query_options.next_partition_key,
            query_options.next_row_key,
        );
        const metadata = try call.takeResponse();
        return .{
            .value = value,
            .status = metadata.status,
            .headers = metadata.headers,
            .arena = arena,
            .allocator = allocator,
        };
    }

    /// Result-preserving counterpart to `queryEntities`. HTTP failures retain
    /// structured Tables error details for pagers and advanced callers.
    pub fn queryEntitiesResult(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        query_options: options.QueryEntitiesOptions,
    ) !responses.TableResult(responses.SdkResponse(ProtocolTable.QueryEntitiesResult)) {
        try request.validateTableName(table_name);
        try request.validateProtocolOptions(query_options.protocol);
        if (query_options.top) |top| {
            if (top <= 0) return error.InvalidTop;
        }

        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();

        var call = try self.beginEntityCall(arena_allocator, query_options.protocol);
        errdefer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(
            arena_allocator,
            call.pipeline,
            .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version },
        );
        var table = generated.table();
        const value = table.queryEntities(
            arena_allocator,
            query_options.protocol.client_request_id,
            table_name,
            query_options.protocol.metadata,
            query_options.top,
            query_options.select,
            query_options.filter,
            query_options.protocol.timeout,
            query_options.next_partition_key,
            query_options.next_row_key,
        ) catch |operation_error| {
            if (operation_error != error.AzureRequestFailed) return operation_error;
            var metadata = try call.takeResponse();
            const table_error = try errorsFromMetadata(allocator, &metadata);
            metadata.deinit();
            call.deinit();
            arena.deinit();
            allocator.destroy(arena);
            return .{ .failure = table_error };
        };
        const metadata = try call.takeResponse();
        call.deinit();
        return .{ .success = .{
            .value = value,
            .status = metadata.status,
            .headers = metadata.headers,
            .body = metadata.body,
            .arena = arena,
            .allocator = allocator,
        } };
    }

    pub fn queryTables(self: *ProtocolClient, allocator: std.mem.Allocator, query_options: options.ListTablesOptions) !responses.TableResult(responses.SdkResponse(QueryTablesResponse)) {
        try request.validateProtocolOptions(query_options.protocol);
        if (query_options.top) |top| if (top <= 0) return error.InvalidTop;
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();
        var call = try self.beginCall(
            arena_allocator,
            query_options.protocol,
            query_options.protocol.timeout,
        );
        errdefer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(arena_allocator, call.pipeline, .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version });
        var table = generated.table();
        const value = table.query(arena_allocator, query_options.protocol.client_request_id, query_options.protocol.metadata, query_options.top, query_options.select, query_options.filter, query_options.continuation_token) catch |err| {
            const table_error = try self.tableErrorFromGeneratedFailure(allocator, &call, err);
            call.deinit();
            arena.deinit();
            allocator.destroy(arena);
            return .{ .failure = table_error };
        };
        const metadata = try call.takeResponse();
        call.deinit();
        return .{ .success = .{ .value = value, .status = metadata.status, .headers = metadata.headers, .arena = arena, .allocator = allocator } };
    }

    pub fn createTable(self: *ProtocolClient, allocator: std.mem.Allocator, table_name: []const u8, create_options: options.CreateTableOptions) !responses.TableResult(responses.SdkResponse(CreateTableResponse)) {
        try request.validateTableName(table_name);
        try request.validateProtocolOptions(create_options.protocol);
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();
        var call = try self.beginCall(arena_allocator, create_options.protocol, create_options.protocol.timeout);
        errdefer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(arena_allocator, call.pipeline, .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version });
        var table = generated.table();
        const value = table.create(arena_allocator, create_options.protocol.client_request_id, create_options.protocol.metadata, .{ .table_name = table_name }, create_options.prefer) catch |err| {
            const table_error = try self.tableErrorFromGeneratedFailure(allocator, &call, err);
            call.deinit();
            arena.deinit();
            allocator.destroy(arena);
            return .{ .failure = table_error };
        };
        const metadata = try call.takeResponse();
        call.deinit();
        return .{ .success = .{ .value = value, .status = metadata.status, .headers = metadata.headers, .arena = arena, .allocator = allocator } };
    }

    pub fn deleteTable(self: *ProtocolClient, allocator: std.mem.Allocator, table_name: []const u8, delete_options: options.DeleteTableOptions) !responses.TableResult(responses.SdkResponse(DeleteTableResponse)) {
        try request.validateTableName(table_name);
        try request.validateProtocolOptions(delete_options.protocol);
        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();
        var call = try self.beginCall(arena_allocator, delete_options.protocol, delete_options.protocol.timeout);
        errdefer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(arena_allocator, call.pipeline, .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version });
        var table = generated.table();
        const value = table.delete(arena_allocator, delete_options.protocol.client_request_id, table_name) catch |err| {
            const table_error = try self.tableErrorFromGeneratedFailure(allocator, &call, err);
            call.deinit();
            arena.deinit();
            allocator.destroy(arena);
            return .{ .failure = table_error };
        };
        const metadata = try call.takeResponse();
        call.deinit();
        return .{ .success = .{ .value = value, .status = metadata.status, .headers = metadata.headers, .arena = arena, .allocator = allocator } };
    }

    /// Adapts the generated insert operation into an SDK result without
    /// discarding non-2xx response details.
    pub fn insertEntityResult(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        entity_json: []const u8,
        add_options: options.AddEntityOptions,
    ) !responses.TableResult(responses.SdkResponse(ProtocolTable.InsertEntityResult)) {
        try request.validateTableName(table_name);
        try request.validateProtocolOptions(add_options.protocol);
        if (entity_json.len == 0 or entity_json.len > 1024 * 1024)
            return error.InvalidEntity;

        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();
        const properties = try serde.json.fromSlice(
            std.json.ArrayHashMap(protocol.models.JsonValue),
            arena_allocator,
            entity_json,
        );

        const body_policy = try arena_allocator.create(BodyOverridePolicy);
        body_policy.* = .{ .body = entity_json };
        const call_policies = try arena_allocator.alloc(
            *core.pipeline.HttpPolicy,
            add_options.protocol.policies.len + 1,
        );
        @memcpy(call_policies[0..add_options.protocol.policies.len], add_options.protocol.policies);
        call_policies[call_policies.len - 1] = &body_policy.policy;
        var protocol_options = add_options.protocol;
        protocol_options.policies = call_policies;
        var call = try self.beginEntityCall(arena_allocator, protocol_options);
        errdefer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(
            arena_allocator,
            call.pipeline,
            .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version },
        );
        var table = generated.table();
        const value = table.insertEntity(
            arena_allocator,
            table_name,
            add_options.protocol.timeout,
            add_options.protocol.metadata,
            add_options.protocol.client_request_id,
            .return_content,
            properties,
        ) catch |operation_error| {
            if (operation_error != error.AzureRequestFailed) return operation_error;
            var metadata = try call.takeResponse();
            const table_error = try errorsFromMetadata(allocator, &metadata);
            metadata.deinit();
            call.deinit();
            arena.deinit();
            allocator.destroy(arena);
            return .{ .failure = table_error };
        };
        const metadata = try call.takeResponse();
        call.deinit();
        return .{ .success = .{
            .value = value,
            .status = metadata.status,
            .headers = metadata.headers,
            .body = metadata.body,
            .arena = arena,
            .allocator = allocator,
        } };
    }

    /// Result-preserving counterpart to `queryEntity`.
    pub fn queryEntityResult(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        partition_key: []const u8,
        row_key: []const u8,
        query_options: options.QueryEntityOptions,
    ) !responses.TableResult(responses.SdkResponse(ProtocolTable.QueryEntityWithPartitionAndRowKeyResult)) {
        try request.validateTableName(table_name);
        try request.validateEntityKey(partition_key);
        try request.validateEntityKey(row_key);
        try request.validateProtocolOptions(query_options.protocol);

        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();

        var call = try self.beginEntityCall(arena_allocator, query_options.protocol);
        errdefer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(
            arena_allocator,
            call.pipeline,
            .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version },
        );
        var table = generated.table();
        const value = table.queryEntityWithPartitionAndRowKey(
            arena_allocator,
            query_options.protocol.client_request_id,
            table_name,
            query_options.protocol.timeout,
            query_options.protocol.metadata,
            query_options.select,
            query_options.filter,
            partition_key,
            row_key,
        ) catch |operation_error| {
            if (operation_error != error.AzureRequestFailed) return operation_error;
            var metadata = try call.takeResponse();
            const table_error = try errorsFromMetadata(allocator, &metadata);
            metadata.deinit();
            call.deinit();
            arena.deinit();
            allocator.destroy(arena);
            return .{ .failure = table_error };
        };
        const metadata = try call.takeResponse();
        call.deinit();
        return .{ .success = .{
            .value = value,
            .status = metadata.status,
            .headers = metadata.headers,
            .body = metadata.body,
            .arena = arena,
            .allocator = allocator,
        } };
    }

    /// Adapts the generated delete operation, including conditional failures.
    pub fn deleteEntityResult(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        table_name: []const u8,
        partition_key: []const u8,
        row_key: []const u8,
        delete_options: options.DeleteEntityOptions,
    ) !responses.TableResult(responses.SdkResponse(ProtocolTable.DeleteEntityResult)) {
        try request.validateTableName(table_name);
        try request.validateEntityKey(partition_key);
        try request.validateEntityKey(row_key);
        try request.validateIfMatch(delete_options.if_match);
        try request.validateProtocolOptions(delete_options.protocol);

        const arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(arena);
        arena.* = .init(allocator);
        errdefer arena.deinit();
        const arena_allocator = arena.allocator();

        var call = try self.beginEntityCall(arena_allocator, delete_options.protocol);
        errdefer call.deinit();
        var generated = protocol.TablesClient.initWithPipeline(
            arena_allocator,
            call.pipeline,
            .{ .endpoint = self.endpoint.base_url, .api_version = self.api_version },
        );
        var table = generated.table();
        const value = table.deleteEntity(
            arena_allocator,
            delete_options.protocol.client_request_id,
            table_name,
            delete_options.protocol.timeout,
            delete_options.if_match,
            partition_key,
            row_key,
        ) catch |operation_error| {
            if (operation_error != error.AzureRequestFailed) return operation_error;
            var metadata = try call.takeResponse();
            const table_error = try errorsFromMetadata(allocator, &metadata);
            metadata.deinit();
            call.deinit();
            arena.deinit();
            allocator.destroy(arena);
            return .{ .failure = table_error };
        };
        const metadata = try call.takeResponse();
        call.deinit();
        return .{ .success = .{
            .value = value,
            .status = metadata.status,
            .headers = metadata.headers,
            .body = metadata.body,
            .arena = arena,
            .allocator = allocator,
        } };
    }

    fn beginEntityCall(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        call_options: options.ProtocolOptions,
    ) !pipeline_mod.CallContext {
        return pipeline_mod.CallContext.initWithResponseBody(
            allocator,
            self.pipeline,
            if (self.endpoint.has_query) self.endpoint.raw_query else null,
            self.endpoint_query_is_sas,
            call_options.operation_timeout_ms,
            // Generated entity operations write the `timeout` query parameter.
            // Adding it through the shared pipeline would duplicate it.
            null,
            call_options.policies,
        );
    }

    pub fn send(
        self: *ProtocolClient,
        req: *core.http.Request,
        call_options: options.ProtocolOptions,
    ) !core.http.Response {
        var call = try self.beginCallNoCapture(req.allocator, call_options);
        defer call.deinit();
        return call.pipeline.send(req);
    }

    fn beginCallNoCapture(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        call_options: options.ProtocolOptions,
    ) !pipeline_mod.CallContext {
        return pipeline_mod.CallContext.initNoCapture(
            allocator,
            self.pipeline,
            if (self.endpoint.has_query) self.endpoint.raw_query else null,
            self.endpoint_query_is_sas,
            call_options.operation_timeout_ms,
            call_options.timeout,
            call_options.policies,
        );
    }

    fn tableErrorFromGeneratedFailure(self: *ProtocolClient, allocator: std.mem.Allocator, call: *pipeline_mod.CallContext, generated_error: anyerror) !errors.TableError {
        _ = self;
        if (generated_error != error.AzureRequestFailed) return generated_error;
        var metadata = call.takeResponse() catch return generated_error;
        defer metadata.deinit();
        return errors.TableError.fromResponse(allocator, metadata.status, metadata.headers.getFirst("Content-Type"), metadata.headers.getFirst("x-ms-request-id"), null, metadata.body orelse "");
    }

    fn beginCall(
        self: *ProtocolClient,
        allocator: std.mem.Allocator,
        call_options: options.ProtocolOptions,
        server_timeout: ?i32,
    ) !pipeline_mod.CallContext {
        return pipeline_mod.CallContext.init(
            allocator,
            self.pipeline,
            if (self.endpoint.has_query) self.endpoint.raw_query else null,
            self.endpoint_query_is_sas,
            call_options.operation_timeout_ms,
            server_timeout,
            call_options.policies,
        );
    }
};

const BodyOverridePolicy = struct {
    body: []const u8,
    policy: core.pipeline.HttpPolicy = .{ .processFn = &process },

    // The generated open JSON model cannot retain property annotations during
    // serialization, so the SDK codec's validated bytes are authoritative.
    fn process(
        policy: *core.pipeline.HttpPolicy,
        req: *core.http.Request,
        next: []*core.pipeline.HttpPolicy,
        transport: *core.http.HttpTransport,
    ) anyerror!core.http.Response {
        const self: *BodyOverridePolicy = @alignCast(@fieldParentPtr("policy", policy));
        req.body = self.body;
        if (next.len == 0) return transport.send(req);
        return next[0].process(req, next[1..], transport);
    }
};

fn errorsFromMetadata(
    allocator: std.mem.Allocator,
    metadata: *responses.ResponseMetadata,
) !@import("errors.zig").TableError {
    const content_type = metadata.headers.getFirst("Content-Type");
    const request_id = metadata.headers.getFirst("x-ms-request-id");
    return @import("errors.zig").TableError.fromResponse(
        allocator,
        metadata.status,
        content_type,
        request_id,
        null,
        metadata.body orelse "",
    );
}

const HeaderPolicy = struct {
    policy: core.pipeline.HttpPolicy = .{ .processFn = &process },

    fn process(
        policy: *core.pipeline.HttpPolicy,
        req: *core.http.Request,
        next: []*core.pipeline.HttpPolicy,
        transport: *core.http.HttpTransport,
    ) anyerror!core.http.Response {
        _ = policy;
        try req.setHeader("x-test-policy", "applied");
        if (next.len == 0) return transport.send(req);
        return next[0].process(req, next[1..], transport);
    }
};

test "generated query receives SDK options and preserves SAS bytes" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "ETag", .value = "etag-value" },
        .{ .name = "x-ms-version", .value = "2020-test" },
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
        .{ .name = "Content-Type", .value = "application/json" },
        .{ .name = "x-extra", .value = "first" },
        .{ .name = "x-extra", .value = "second" },
    };
    const base_pipeline: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = mock.asTransport(),
    };
    var client = try ProtocolClient.init(
        allocator,
        "https://account.table.core.windows.net/?sv=1%2F2&sig=a+b%3D&sp=r",
        base_pipeline,
        .{ .api_version = "2020-test", .endpoint_query_is_sas = true },
    );
    defer client.deinit();
    var header_policy = HeaderPolicy{};
    var response = try client.queryEntity(
        allocator,
        "Table123",
        "O'Brien",
        "雪 & row",
        .{
            .protocol = .{
                .metadata = .full_metadata,
                .client_request_id = "client-id",
                .timeout = 30,
                .operation_timeout_ms = 5000,
                .policies = &.{&header_policy.policy},
            },
            .select = "Name,Price",
        },
    );
    defer response.deinit();

    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/Table123(PartitionKey='O%27%27Brien',RowKey='%E9%9B%AA%20%26%20row')?sv=1%2F2&sig=a+b%3D&sp=r&timeout=30&$format=application%2Fjson%3Bodata%3Dfullmetadata&$select=Name%2CPrice",
        mock.last_url.?,
    );
    try std.testing.expectEqualStrings("2020-test", mock.last_headers.get("x-ms-version").?);
    try std.testing.expectEqualStrings("client-id", mock.last_headers.get("x-ms-client-request-id").?);
    try std.testing.expectEqualStrings("applied", mock.last_headers.get("x-test-policy").?);
    try std.testing.expectEqual(@as(?u64, 5000), mock.last_operation_timeout_ms);
    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("etag-value", response.headers.getFirst("ETag").?);
    try std.testing.expectEqual(@as(usize, 6), response.headers.entries.items.len);
}

test "invalid generated call inputs fail before transport" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    const base_pipeline: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = mock.asTransport(),
    };
    var client = try ProtocolClient.init(
        allocator,
        "https://account.table.core.windows.net",
        base_pipeline,
        .{},
    );
    defer client.deinit();
    try std.testing.expectEqualStrings(options.latest_api_version, client.api_version);
    try std.testing.expectError(
        error.InvalidTableName,
        client.queryEntity(allocator, "bad-name", "pk", "rk", .{}),
    );
    try std.testing.expectError(
        error.InvalidEntityKey,
        client.queryEntity(allocator, "Table123", "bad/key", "rk", .{}),
    );
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}

test "queryEntities retains its source-compatible raw response signature" {
    const QueryEntitiesFn = fn (
        *ProtocolClient,
        std.mem.Allocator,
        []const u8,
        options.QueryEntitiesOptions,
    ) anyerror!responses.SdkResponse(QueryEntitiesResponse);
    const query_entities: QueryEntitiesFn = ProtocolClient.queryEntities;

    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"value":[]}
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "x-ms-version", .value = "2019-02-02" },
        .{ .name = "Date", .value = "Sun, 26 Jul 2026 00:00:00 GMT" },
        .{ .name = "Content-Type", .value = "application/json" },
    };
    const base_pipeline: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = mock.asTransport(),
    };
    var client = try ProtocolClient.init(
        allocator,
        "https://account.table.core.windows.net",
        base_pipeline,
        .{},
    );
    defer client.deinit();

    var response = try query_entities(&client, allocator, "Table123", .{
        .top = 1,
        .next_partition_key = "p /%?",
        .next_row_key = "r /%?",
    });
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expect(std.mem.indexOf(
        u8,
        mock.last_url.?,
        "NextPartitionKey=p%20%2F%25%3F&NextRowKey=r%20%2F%25%3F",
    ) != null);
}
