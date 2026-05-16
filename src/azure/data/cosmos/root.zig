///! Azure Cosmos DB (NoSQL) client.
///!
///! Provides `CosmosClient`, `DatabaseClient`, and `ContainerClient`
///! for account, database, and container/item operations via REST API.
const std = @import("std");
const core = @import("azure_core");

// ─────────────────────── Enums ───────────────────────

pub const ConsistencyLevel = enum {
    strong,
    bounded_staleness,
    session,
    consistent_prefix,
    eventual,

    pub fn toString(self: ConsistencyLevel) []const u8 {
        return switch (self) {
            .strong => "Strong",
            .bounded_staleness => "BoundedStaleness",
            .session => "Session",
            .consistent_prefix => "ConsistentPrefix",
            .eventual => "Eventual",
        };
    }
};

// ─────────────────────── Models ───────────────────────

pub const Database = struct {
    id: []const u8,
    rid: ?[]const u8 = null,
    self_link: ?[]const u8 = null,
    etag: ?[]const u8 = null,
};

pub const ContainerProperties = struct {
    id: []const u8,
    partition_key_paths: []const []const u8 = &.{},
    rid: ?[]const u8 = null,
    self_link: ?[]const u8 = null,
    etag: ?[]const u8 = null,
};

pub const CosmosItem = struct {
    id: []const u8,
    partition_key: []const u8,
    body: []const u8,
};

pub const QueryResult = struct {
    documents: []const []const u8,
    continuation_token: ?[]const u8 = null,
};

pub const ThroughputProperties = struct {
    max_throughput: ?u32 = null,
};

// ─────────────────── CosmosClient ────────────────────

pub const CosmosClientOptions = struct {
    api_version: []const u8 = "2018-12-31",
    consistency_level: ?ConsistencyLevel = null,
};

/// Account-level client for Azure Cosmos DB.
pub const CosmosClient = struct {
    endpoint: []const u8,
    api_version: []const u8,
    consistency_level: ?ConsistencyLevel,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        endpoint: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: CosmosClientOptions,
    ) CosmosClient {
        _ = credential;
        return .{
            .endpoint = endpoint,
            .api_version = options.api_version,
            .consistency_level = options.consistency_level,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// Get a DatabaseClient for a specific database.
    pub fn database(self: *CosmosClient, database_id: []const u8) DatabaseClient {
        return .{
            .endpoint = self.endpoint,
            .database_id = database_id,
            .api_version = self.api_version,
            .consistency_level = self.consistency_level,
            .pipeline = self.pipeline,
        };
    }

    /// Create a new database.
    pub fn createDatabase(self: *CosmosClient, allocator: std.mem.Allocator, database_id: []const u8) !Database {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs", .{self.endpoint});
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator, "{{\"id\":\"{s}\"}}", .{database_id});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try self.setCommonHeaders(&req);
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.CreateDatabaseFailed;
        }

        return parseDatabaseResponse(database_id, resp.body);
    }

    /// Delete a database.
    pub fn deleteDatabase(self: *CosmosClient, allocator: std.mem.Allocator, database_id: []const u8) !void {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs/{s}", .{ self.endpoint, database_id });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();
        try self.setCommonHeaders(&req);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.DeleteDatabaseFailed;
        }
    }

    /// List all databases.
    pub fn listDatabases(self: *CosmosClient, allocator: std.mem.Allocator) ![]Database {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs", .{self.endpoint});
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try self.setCommonHeaders(&req);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.ListDatabasesFailed;
        }

        return parseDatabaseList(allocator, resp.body);
    }

    fn setCommonHeaders(self: *CosmosClient, req: *core.http.Request) !void {
        try req.setHeader("x-ms-version", self.api_version);
        if (self.consistency_level) |cl| {
            try req.setHeader("x-ms-consistency-level", cl.toString());
        }
    }
};

// ─────────────────── DatabaseClient ──────────────────

/// Database-level client for container operations.
pub const DatabaseClient = struct {
    endpoint: []const u8,
    database_id: []const u8,
    api_version: []const u8,
    consistency_level: ?ConsistencyLevel,
    pipeline: core.pipeline.HttpPipeline,

    /// Get a ContainerClient for a specific container.
    pub fn container(self: *DatabaseClient, container_id: []const u8) ContainerClient {
        return .{
            .endpoint = self.endpoint,
            .database_id = self.database_id,
            .container_id = container_id,
            .api_version = self.api_version,
            .consistency_level = self.consistency_level,
            .pipeline = self.pipeline,
        };
    }

    /// Create a new container.
    pub fn createContainer(self: *DatabaseClient, allocator: std.mem.Allocator, container_id: []const u8, partition_key_path: []const u8) !ContainerProperties {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs/{s}/colls", .{ self.endpoint, self.database_id });
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator,
            \\{{"id":"{s}","partitionKey":{{"paths":["{s}"],"kind":"Hash"}}}}
        , .{ container_id, partition_key_path });
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try self.setCommonHeaders(&req);
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.CreateContainerFailed;
        }

        return .{ .id = container_id, .partition_key_paths = &.{partition_key_path} };
    }

    /// Delete a container.
    pub fn deleteContainer(self: *DatabaseClient, allocator: std.mem.Allocator, container_id: []const u8) !void {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs/{s}/colls/{s}", .{ self.endpoint, self.database_id, container_id });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();
        try self.setCommonHeaders(&req);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.DeleteContainerFailed;
        }
    }

    /// List all containers in this database.
    pub fn listContainers(self: *DatabaseClient, allocator: std.mem.Allocator) ![]ContainerProperties {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs/{s}/colls", .{ self.endpoint, self.database_id });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try self.setCommonHeaders(&req);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.ListContainersFailed;
        }

        return parseContainerList(allocator, resp.body);
    }

    /// Get a specific container.
    pub fn getContainer(self: *DatabaseClient, allocator: std.mem.Allocator, container_id: []const u8) !ContainerProperties {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs/{s}/colls/{s}", .{ self.endpoint, self.database_id, container_id });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try self.setCommonHeaders(&req);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.GetContainerFailed;
        }

        return parseContainerResponse(container_id, resp.body);
    }

    fn setCommonHeaders(self: *DatabaseClient, req: *core.http.Request) !void {
        try req.setHeader("x-ms-version", self.api_version);
        if (self.consistency_level) |cl| {
            try req.setHeader("x-ms-consistency-level", cl.toString());
        }
    }
};

// ─────────────────── ContainerClient ─────────────────

/// Container-level client for item CRUD and queries.
pub const ContainerClient = struct {
    endpoint: []const u8,
    database_id: []const u8,
    container_id: []const u8,
    api_version: []const u8,
    consistency_level: ?ConsistencyLevel,
    pipeline: core.pipeline.HttpPipeline,

    /// Create (insert) an item.
    pub fn createItem(self: *ContainerClient, allocator: std.mem.Allocator, item: CosmosItem) !void {
        const url = try self.buildDocsUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try self.setCommonHeaders(&req);
        try req.setHeader("x-ms-documentdb-partitionkey", item.partition_key);
        req.body = item.body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.CreateItemFailed;
        }
    }

    /// Read an item by id and partition key.
    pub fn readItem(self: *ContainerClient, allocator: std.mem.Allocator, item_id: []const u8, partition_key: []const u8) ![]const u8 {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs/{s}/colls/{s}/docs/{s}", .{ self.endpoint, self.database_id, self.container_id, item_id });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();
        try self.setCommonHeaders(&req);
        try req.setHeader("x-ms-documentdb-partitionkey", partition_key);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.ReadItemFailed;
        }

        return allocator.dupe(u8, resp.body);
    }

    /// Replace (update) an item.
    pub fn replaceItem(self: *ContainerClient, allocator: std.mem.Allocator, item: CosmosItem) !void {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs/{s}/colls/{s}/docs/{s}", .{ self.endpoint, self.database_id, self.container_id, item.id });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try self.setCommonHeaders(&req);
        try req.setHeader("x-ms-documentdb-partitionkey", item.partition_key);
        req.body = item.body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.ReplaceItemFailed;
        }
    }

    /// Upsert (create or replace) an item.
    pub fn upsertItem(self: *ContainerClient, allocator: std.mem.Allocator, item: CosmosItem) !void {
        const url = try self.buildDocsUrl(allocator);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try self.setCommonHeaders(&req);
        try req.setHeader("x-ms-documentdb-partitionkey", item.partition_key);
        try req.setHeader("x-ms-documentdb-is-upsert", "true");
        req.body = item.body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.UpsertItemFailed;
        }
    }

    /// Delete an item.
    pub fn deleteItem(self: *ContainerClient, allocator: std.mem.Allocator, item_id: []const u8, partition_key: []const u8) !void {
        const url = try std.fmt.allocPrint(allocator, "{s}/dbs/{s}/colls/{s}/docs/{s}", .{ self.endpoint, self.database_id, self.container_id, item_id });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();
        try self.setCommonHeaders(&req);
        try req.setHeader("x-ms-documentdb-partitionkey", partition_key);

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.DeleteItemFailed;
        }
    }

    /// Execute a SQL query against the container.
    pub fn queryItems(self: *ContainerClient, allocator: std.mem.Allocator, query: []const u8) !QueryResult {
        const url = try self.buildDocsUrl(allocator);
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator, "{{\"query\":\"{s}\"}}", .{query});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/query+json");
        try self.setCommonHeaders(&req);
        try req.setHeader("x-ms-documentdb-isquery", "true");
        try req.setHeader("x-ms-max-item-count", "100");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.QueryFailed;
        }

        return parseQueryResult(allocator, resp.body);
    }

    fn buildDocsUrl(self: *ContainerClient, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}/dbs/{s}/colls/{s}/docs", .{ self.endpoint, self.database_id, self.container_id });
    }

    fn setCommonHeaders(self: *ContainerClient, req: *core.http.Request) !void {
        try req.setHeader("x-ms-version", self.api_version);
        if (self.consistency_level) |cl| {
            try req.setHeader("x-ms-consistency-level", cl.toString());
        }
    }
};

// ─────────────────── JSON Parsing ────────────────────

fn parseDatabaseResponse(id: []const u8, body: []const u8) Database {
    var db = Database{ .id = id };
    db.rid = parseJsonString(body, "\"_rid\":\"");
    db.etag = parseJsonString(body, "\"_etag\":\"");
    return db;
}

fn parseDatabaseList(allocator: std.mem.Allocator, body: []const u8) ![]Database {
    return parseIdList(allocator, body, Database);
}

fn parseContainerResponse(id: []const u8, body: []const u8) ContainerProperties {
    var props = ContainerProperties{ .id = id };
    props.rid = parseJsonString(body, "\"_rid\":\"");
    props.etag = parseJsonString(body, "\"_etag\":\"");
    return props;
}

fn parseContainerList(allocator: std.mem.Allocator, body: []const u8) ![]ContainerProperties {
    return parseIdList(allocator, body, ContainerProperties);
}

fn parseQueryResult(allocator: std.mem.Allocator, body: []const u8) !QueryResult {
    // Parse document bodies from {"Documents":[...], "_count": N}
    var docs = std.ArrayList([]const u8).empty;
    errdefer docs.deinit(allocator);

    // Simple extraction: find each document object in the Documents array.
    const docs_start = std.mem.find(u8, body, "\"Documents\":[") orelse
        return .{ .documents = &.{} };
    const array_start = docs_start + "\"Documents\":[".len;
    const array_end = std.mem.findScalarPos(u8, body, array_start, ']') orelse
        return .{ .documents = &.{} };
    const array_content = body[array_start..array_end];

    // Split by top-level objects (simplified: find matching braces)
    var depth: u32 = 0;
    var obj_start: ?usize = null;
    for (array_content, 0..) |ch, i| {
        if (ch == '{') {
            if (depth == 0) obj_start = i;
            depth += 1;
        } else if (ch == '}') {
            depth -= 1;
            if (depth == 0) {
                if (obj_start) |start| {
                    try docs.append(allocator, try allocator.dupe(u8, array_content[start .. i + 1]));
                }
                obj_start = null;
            }
        }
    }

    return .{
        .documents = try docs.toOwnedSlice(allocator),
        .continuation_token = parseJsonString(body, "\"_continuation\":\""),
    };
}

fn parseJsonString(body: []const u8, prefix: []const u8) ?[]const u8 {
    const start = (std.mem.find(u8, body, prefix) orelse return null) + prefix.len;
    const end = std.mem.findScalarPos(u8, body, start, '"') orelse return null;
    return body[start..end];
}

fn parseIdList(allocator: std.mem.Allocator, body: []const u8, comptime T: type) ![]T {
    // Parse {"<Collection>":[{"id":"..."},...],...}
    var result = std.ArrayList(T).empty;
    errdefer result.deinit(allocator);

    const id_key = "\"id\":\"";
    var pos: usize = 0;
    while (std.mem.findPos(u8, body, pos, id_key)) |start| {
        const val_start = start + id_key.len;
        const val_end = std.mem.findScalarPos(u8, body, val_start, '"') orelse break;
        const id = try allocator.dupe(u8, body[val_start..val_end]);
        try result.append(allocator, .{ .id = id });
        pos = val_end + 1;
    }

    return result.toOwnedSlice(allocator);
}

// ─────────────────────── Tests ───────────────────────

test "ConsistencyLevel toString" {
    try std.testing.expectEqualStrings("Strong", ConsistencyLevel.strong.toString());
    try std.testing.expectEqualStrings("Session", ConsistencyLevel.session.toString());
    try std.testing.expectEqualStrings("Eventual", ConsistencyLevel.eventual.toString());
}

fn createTestClient(mock: *core.http.MockTransport) CosmosClient {
    const identity = @import("azure_identity");
    // Use a stack-allocated mock for credential — not actually called in tests.
    var cred_mock = core.http.MockTransport.init(mock.allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    var cred = identity.ClientSecretCredential.init(mock.allocator, cred_mock.asTransport(), "t", "c", "s");
    return CosmosClient.init(
        "https://myaccount.documents.azure.com",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );
}

test "CosmosClient createDatabase" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201,
        \\{"id":"testdb","_rid":"abc","_etag":"\"00000000-0000-0000-0000-000000000000\""}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    const db = try client.createDatabase(allocator, "testdb");
    try std.testing.expectEqualStrings("testdb", db.id);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    try std.testing.expect(std.mem.endsWith(u8, mock.last_url.?, "/dbs"));
}

test "CosmosClient deleteDatabase" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 204, "");
    defer mock.deinit();
    var client = createTestClient(&mock);
    try client.deleteDatabase(allocator, "testdb");
    try std.testing.expectEqual(core.http.Method.DELETE, mock.last_method.?);
    try std.testing.expect(std.mem.endsWith(u8, mock.last_url.?, "/dbs/testdb"));
}

test "CosmosClient listDatabases" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"Databases":[{"id":"db1"},{"id":"db2"}],"_count":2}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    const dbs = try client.listDatabases(allocator);
    defer {
        for (dbs) |db| allocator.free(db.id);
        allocator.free(dbs);
    }
    try std.testing.expectEqual(@as(usize, 2), dbs.len);
    try std.testing.expectEqualStrings("db1", dbs[0].id);
    try std.testing.expectEqualStrings("db2", dbs[1].id);
}

test "CosmosClient database returns DatabaseClient" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db_client = client.database("mydb");
    try std.testing.expectEqualStrings("mydb", db_client.database_id);

    // Verify DatabaseClient can create a ContainerClient.
    const ctr_client = db_client.container("myctr");
    try std.testing.expectEqualStrings("myctr", ctr_client.container_id);
    try std.testing.expectEqualStrings("mydb", ctr_client.database_id);
}

test "DatabaseClient createContainer" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201,
        \\{"id":"myctr","_rid":"xyz"}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db = client.database("mydb");
    const ctr = try db.createContainer(allocator, "myctr", "/pk");
    try std.testing.expectEqualStrings("myctr", ctr.id);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/dbs/mydb/colls") != null);
}

test "DatabaseClient listContainers" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"DocumentCollections":[{"id":"c1"},{"id":"c2"},{"id":"c3"}],"_count":3}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db = client.database("mydb");
    const containers = try db.listContainers(allocator);
    defer {
        for (containers) |c| allocator.free(c.id);
        allocator.free(containers);
    }
    try std.testing.expectEqual(@as(usize, 3), containers.len);
    try std.testing.expectEqualStrings("c1", containers[0].id);
}

test "ContainerClient createItem" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201,
        \\{"id":"item1"}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db = client.database("mydb");
    var ctr = db.container("myctr");
    try ctr.createItem(allocator, .{
        .id = "item1",
        .partition_key = "[\"pk1\"]",
        .body =
        \\{"id":"item1","pk":"pk1","name":"test"}
        ,
    });
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    try std.testing.expect(std.mem.endsWith(u8, mock.last_url.?, "/docs"));
}

test "ContainerClient readItem" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"id":"item1","pk":"pk1","name":"test"}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db = client.database("mydb");
    var ctr = db.container("myctr");
    const body = try ctr.readItem(allocator, "item1", "[\"pk1\"]");
    defer allocator.free(body);
    try std.testing.expect(std.mem.find(u8, body, "\"name\":\"test\"") != null);
}

test "ContainerClient upsertItem" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"id":"item1"}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db = client.database("mydb");
    var ctr = db.container("myctr");
    try ctr.upsertItem(allocator, .{
        .id = "item1",
        .partition_key = "[\"pk1\"]",
        .body =
        \\{"id":"item1","pk":"pk1"}
        ,
    });
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
}

test "ContainerClient deleteItem" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 204, "");
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db = client.database("mydb");
    var ctr = db.container("myctr");
    try ctr.deleteItem(allocator, "item1", "[\"pk1\"]");
    try std.testing.expectEqual(core.http.Method.DELETE, mock.last_method.?);
    try std.testing.expect(std.mem.endsWith(u8, mock.last_url.?, "/docs/item1"));
}

test "ContainerClient queryItems" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"Documents":[{"id":"a","val":1},{"id":"b","val":2}],"_count":2}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db = client.database("mydb");
    var ctr = db.container("myctr");
    const result = try ctr.queryItems(allocator, "SELECT * FROM c");
    defer {
        for (result.documents) |d| allocator.free(d);
        allocator.free(result.documents);
    }
    try std.testing.expectEqual(@as(usize, 2), result.documents.len);
    try std.testing.expect(std.mem.find(u8, result.documents[0], "\"id\":\"a\"") != null);
}

test "ContainerClient readItem 404" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 404,
        \\{"code":"NotFound","message":"Entity not found"}
    );
    defer mock.deinit();
    var client = createTestClient(&mock);
    var db = client.database("mydb");
    var ctr = db.container("myctr");
    const result = ctr.readItem(allocator, "missing", "[\"pk\"]");
    try std.testing.expectError(error.ReadItemFailed, result);
}

test "CosmosClient with consistency level" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"Databases":[],"_count":0}
    );
    defer mock.deinit();
    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var client = CosmosClient.init(
        "https://myaccount.documents.azure.com",
        cred.asCredential(),
        mock.asTransport(),
        .{ .consistency_level = .session },
    );
    const dbs = try client.listDatabases(allocator);
    defer allocator.free(dbs);
    try std.testing.expectEqual(@as(usize, 0), dbs.len);
}
