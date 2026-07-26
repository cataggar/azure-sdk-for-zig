const std = @import("std");
const core = @import("azure_sdk_core");
const entity = @import("entity.zig");
const options = @import("options.zig");
const request = @import("request.zig");

/// Client for Azure Table Storage REST operations.
///
/// This compatibility client borrows its endpoint, table name, credential, and
/// transport. Each borrowed value must outlive the client.
pub const TableClient = struct {
    endpoint: []const u8,
    table_name: []const u8,
    credential: *core.credentials.TokenCredential,
    pipeline: core.pipeline.HttpPipeline,

    pub const Options = options.TableClientOptions;

    pub fn init(
        endpoint: []const u8,
        table_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        init_options: Options,
    ) TableClient {
        _ = init_options;
        return .{
            .endpoint = endpoint,
            .table_name = table_name,
            .credential = credential,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// GET `{endpoint}/{tableName}(PartitionKey='{pk}',RowKey='{rk}')`
    pub fn getEntity(
        self: *TableClient,
        allocator: std.mem.Allocator,
        partition_key: []const u8,
        row_key: []const u8,
    ) !core.http.Response {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}(PartitionKey='{s}',RowKey='{s}')",
            .{ self.endpoint, self.table_name, partition_key, row_key },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json;odata=nometadata");
        return self.pipeline.send(&req);
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
            .{ self.endpoint, self.table_name },
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
        req.body = body_buf.items;
        return self.pipeline.send(&req);
    }

    /// DELETE `{endpoint}/{tableName}(PartitionKey='{pk}',RowKey='{rk}')`
    pub fn deleteEntity(
        self: *TableClient,
        allocator: std.mem.Allocator,
        partition_key: []const u8,
        row_key: []const u8,
    ) !core.http.Response {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}(PartitionKey='{s}',RowKey='{s}')",
            .{ self.endpoint, self.table_name, partition_key, row_key },
        );
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();
        try req.setHeader("If-Match", "*");
        return self.pipeline.send(&req);
    }
};

test "TableClient getEntity builds correct URL" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const client_secret = core.identity.client_secret;
    var inner_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer inner_mock.deinit();
    var cred = client_secret.ClientSecretCredential.init(allocator, inner_mock.asTransport(), "t", "c", "s");

    var table_client = TableClient.init(
        "https://myaccount.table.core.windows.net",
        "mytable",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );
    var response = try table_client.getEntity(allocator, "pk1", "rk1");
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "mytable(PartitionKey='pk1',RowKey='rk1')") != null);
}
