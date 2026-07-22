const std = @import("std");
const core = @import("azure_sdk_core");

/// A single table entity (row) — key/value pairs.
pub const TableEntity = struct {
    partition_key: []const u8,
    row_key: []const u8,
    properties: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, partition_key: []const u8, row_key: []const u8) TableEntity {
        return .{
            .partition_key = partition_key,
            .row_key = row_key,
            .properties = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn put(self: *TableEntity, key: []const u8, value: []const u8) !void {
        try self.properties.put(key, value);
    }

    pub fn deinit(self: *TableEntity) void {
        self.properties.deinit();
    }
};

/// Client for Azure Table Storage REST operations.
pub const TableClient = struct {
    endpoint: []const u8,
    table_name: []const u8,
    credential: *core.credentials.TokenCredential,
    pipeline: core.pipeline.HttpPipeline,

    pub const Options = struct {
        api_version: []const u8 = "2019-02-02",
    };

    pub fn init(
        endpoint: []const u8,
        table_name: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: Options,
    ) TableClient {
        _ = options;
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
        entity: TableEntity,
    ) !core.http.Response {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{ self.endpoint, self.table_name },
        );
        defer allocator.free(url);

        // Build JSON body with proper escaping.
        var body_buf: std.ArrayList(u8) = .empty;
        defer body_buf.deinit(allocator);
        const writer = body_buf.writer(allocator);
        try writer.writeAll("{\"PartitionKey\":\"");
        try writeJsonEscaped(writer, entity.partition_key);
        try writer.writeAll("\",\"RowKey\":\"");
        try writeJsonEscaped(writer, entity.row_key);
        try writer.writeByte('"');
        var it = entity.properties.iterator();
        while (it.next()) |entry| {
            try writer.writeAll(",\"");
            try writeJsonEscaped(writer, entry.key_ptr.*);
            try writer.writeAll("\":\"");
            try writeJsonEscaped(writer, entry.value_ptr.*);
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

/// Client for Azure Table Service operations (list/create/delete tables).
pub const TableServiceClient = struct {
    endpoint: []const u8,
    credential: *core.credentials.TokenCredential,
    transport: *core.http.HttpTransport,

    pub fn init(
        endpoint: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
    ) TableServiceClient {
        return .{
            .endpoint = endpoint,
            .credential = credential,
            .transport = transport,
        };
    }

    pub fn getTableClient(self: *TableServiceClient, table_name: []const u8) TableClient {
        return TableClient.init(self.endpoint, table_name, self.credential, self.transport, .{});
    }
};

/// Write a JSON-escaped string (without surrounding quotes).
fn writeJsonEscaped(writer: anytype, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    const hex = "0123456789abcdef";
                    try writer.writeAll("\\u00");
                    try writer.writeByte(hex[c >> 4]);
                    try writer.writeByte(hex[c & 0x0f]);
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
}

test "TableEntity init and put" {
    const allocator = std.testing.allocator;
    var entity = TableEntity.init(allocator, "pk1", "rk1");
    defer entity.deinit();
    try entity.put("Name", "Alice");
    try std.testing.expectEqualStrings("Alice", entity.properties.get("Name").?);
}

test "TableClient getEntity builds correct URL" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const client_secret = @import("azure_sdk_core").identity.client_secret;
    var inner_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer inner_mock.deinit();
    var cred = client_secret.ClientSecretCredential.init(allocator, inner_mock.asTransport(), "t", "c", "s");

    var tc = TableClient.init(
        "https://myaccount.table.core.windows.net",
        "mytable",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );
    var resp = try tc.getEntity(allocator, "pk1", "rk1");
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "mytable(PartitionKey='pk1',RowKey='rk1')") != null);
}
