const std = @import("std");
const core = @import("azure_sdk_core");
const entity = @import("entity.zig");
const options = @import("options.zig");
const pipeline = @import("pipeline.zig");
const protocol_client = @import("protocol_client.zig");
const request = @import("request.zig");

/// Client for Azure Table Storage REST operations.
///
/// A direct token client owns stable pipeline state. A client returned by
/// `TableServiceClient.getTableClient` borrows that state and must be
/// deinitialized before its parent. The credential, transport, and caller
/// policy objects are always borrowed. Calls sharing pipeline state must be
/// serialized because the token cache and standard transport are mutable.
pub const TableClient = struct {
    allocator: std.mem.Allocator,
    protocol: protocol_client.ProtocolClient,
    table_name: []u8,
    pipeline_state: *pipeline.PipelineState,
    owns_pipeline_state: bool,

    pub const Options = options.TableClientOptions;

    pub fn initWithToken(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        table_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) !TableClient {
        try request.validateTableName(table_name);
        try request.validateTokenEndpoint(endpoint);
        const state = try pipeline.PipelineState.create(
            allocator,
            credential,
            transport,
            init_options,
        );
        errdefer state.deinit();
        return initWithState(
            allocator,
            endpoint,
            table_name,
            init_options.api_version,
            state,
            true,
        );
    }

    /// Internal constructor for service-derived clients.
    pub fn initBorrowed(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        table_name: []const u8,
        api_version: []const u8,
        state: *pipeline.PipelineState,
    ) !TableClient {
        try request.validateTableName(table_name);
        return initWithState(
            allocator,
            endpoint,
            table_name,
            api_version,
            state,
            false,
        );
    }

    fn initWithState(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        table_name: []const u8,
        api_version: []const u8,
        state: *pipeline.PipelineState,
        owns_state: bool,
    ) !TableClient {
        var protocol = try protocol_client.ProtocolClient.init(
            allocator,
            endpoint,
            state.pipeline,
            .{ .api_version = api_version },
        );
        errdefer protocol.deinit();
        return .{
            .allocator = allocator,
            .protocol = protocol,
            .table_name = try allocator.dupe(u8, table_name),
            .pipeline_state = state,
            .owns_pipeline_state = owns_state,
        };
    }

    pub fn deinit(self: *TableClient) void {
        self.protocol.deinit();
        self.allocator.free(self.table_name);
        if (self.owns_pipeline_state) self.pipeline_state.deinit();
        self.* = undefined;
    }

    /// GET `{endpoint}/{tableName}(PartitionKey='{pk}',RowKey='{rk}')`.
    pub fn getEntity(
        self: *TableClient,
        allocator: std.mem.Allocator,
        partition_key: []const u8,
        row_key: []const u8,
    ) !core.http.Response {
        const url = try request.buildEntityUrl(
            allocator,
            self.protocol.endpoint.base_url,
            self.table_name,
            partition_key,
            row_key,
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json;odata=nometadata");
        try req.setHeader("x-ms-version", self.protocol.api_version);
        return self.protocol.pipeline.send(&req);
    }

    /// POST `{endpoint}/{tableName}` with JSON entity body.
    pub fn createEntity(
        self: *TableClient,
        allocator: std.mem.Allocator,
        table_entity: entity.TableEntity,
    ) !core.http.Response {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{ self.protocol.endpoint.base_url, self.table_name },
        );
        defer allocator.free(url);

        var body_buf: std.ArrayList(u8) = .empty;
        defer body_buf.deinit(allocator);
        const writer = body_buf.writer(allocator);
        try writer.writeAll("{\"PartitionKey\":\"");
        try request.writeJsonEscaped(writer, table_entity.partition_key);
        try writer.writeAll("\",\"RowKey\":\"");
        try request.writeJsonEscaped(writer, table_entity.row_key);
        try writer.writeByte('"');
        var it = table_entity.properties.iterator();
        while (it.next()) |entry| {
            try writer.writeAll(",\"");
            try request.writeJsonEscaped(writer, entry.key_ptr.*);
            try writer.writeAll("\":\"");
            try request.writeJsonEscaped(writer, entry.value_ptr.*);
            try writer.writeByte('"');
        }
        try writer.writeAll("}");

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Accept", "application/json;odata=nometadata");
        try req.setHeader("x-ms-version", self.protocol.api_version);
        req.body = body_buf.items;
        return self.protocol.pipeline.send(&req);
    }

    /// DELETE `{endpoint}/{tableName}(PartitionKey='{pk}',RowKey='{rk}')`.
    pub fn deleteEntity(
        self: *TableClient,
        allocator: std.mem.Allocator,
        partition_key: []const u8,
        row_key: []const u8,
    ) !core.http.Response {
        const url = try request.buildEntityUrl(
            allocator,
            self.protocol.endpoint.base_url,
            self.table_name,
            partition_key,
            row_key,
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();
        try req.setHeader("If-Match", "*");
        try req.setHeader("x-ms-version", self.protocol.api_version);
        return self.protocol.pipeline.send(&req);
    }
};

const TestCredential = struct {
    calls: usize = 0,
    credential: core.credentials.TokenCredential = .{ .getTokenFn = &getToken },

    fn asCredential(self: *TestCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        _: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *TestCredential = @alignCast(
            @fieldParentPtr("credential", credential),
        );
        self.calls += 1;
        return .{ .token = "table-token", .expires_on = std.math.maxInt(i64) };
    }
};

fn moveClient(client: TableClient) TableClient {
    return client;
}

test "token client survives moves and applies all client options" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = TestCredential{};

    var table_client = moveClient(try TableClient.initWithToken(
        allocator,
        "https://myaccount.table.core.windows.net",
        "MyTable",
        credential.asCredential(),
        mock.asTransport(),
        .{
            .api_version = "2020-test",
            .telemetry = .{ .application_id = "my-app/1.0" },
            .client_request_id = "fixed-request-id",
            .operation_timeout_ms = 4321,
        },
    ));
    defer table_client.deinit();
    const stable_address = table_client.pipeline_state;
    table_client = moveClient(table_client);
    try std.testing.expect(table_client.pipeline_state == stable_address);

    var response = try table_client.getEntity(allocator, "pk1", "rk1");
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expect(mock.last_headers.get("Authorization") != null);
    try std.testing.expectEqualStrings(
        "fixed-request-id",
        mock.last_headers.get("x-ms-client-request-id").?,
    );
    try std.testing.expectEqualStrings(
        "my-app/1.0 azsdk-zig-data-tables/0.1.0",
        mock.last_headers.get("User-Agent").?,
    );
    try std.testing.expectEqualStrings(
        "2020-test",
        mock.last_headers.get("x-ms-version").?,
    );
    try std.testing.expectEqual(@as(?u64, 4321), mock.last_operation_timeout_ms);
}

fn testAllocationFailures(allocator: std.mem.Allocator) !void {
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = TestCredential{};
    var table_client = try TableClient.initWithToken(
        allocator,
        "https://myaccount.table.core.windows.net",
        "MyTable",
        credential.asCredential(),
        mock.asTransport(),
        .{
            .telemetry = .{ .application_id = "allocation-test" },
            .client_request_id = "allocation-request-id",
        },
    );
    table_client.deinit();
}

test "token client construction failure paths are leak-free" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testAllocationFailures,
        .{},
    );
}

test "token client rejects HTTP before credential and transport use" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = TestCredential{};

    try std.testing.expectError(
        error.TokenAuthenticationRequiresHttps,
        TableClient.initWithToken(
            allocator,
            "http://127.0.0.1:10002/devstoreaccount1",
            "MyTable",
            credential.asCredential(),
            mock.asTransport(),
            .{},
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), credential.calls);
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}

test "token client accepts HTTPS custom private endpoint" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = TestCredential{};

    var table_client = try TableClient.initWithToken(
        allocator,
        "HTTPS://tables.internal.example:8443/private/path",
        "MyTable",
        credential.asCredential(),
        mock.asTransport(),
        .{},
    );
    defer table_client.deinit();

    try std.testing.expectEqualStrings(
        "HTTPS://tables.internal.example:8443/private/path",
        table_client.protocol.endpoint.base_url,
    );
    try std.testing.expectEqual(@as(usize, 0), credential.calls);
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}
