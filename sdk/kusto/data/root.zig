///! Azure Kusto (Data Explorer) data client — queries and management commands.
///!
///! Provides `KustoClient` for executing KQL queries via `/v2/rest/query`
///! and management commands via `/v1/rest/mgmt`.
const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");
const kusto_common = @import("azure_kusto_common");

pub const ConnectionProperties = kusto_common.ConnectionProperties;
pub const ClientRequestProperties = kusto_common.ClientRequestProperties;
pub const KustoConnection = kusto_common.KustoConnection;
pub const KustoConnectionOptions = kusto_common.KustoConnectionOptions;
pub const KustoMetadataMode = kusto_common.KustoMetadataMode;
pub const KustoCloudInfo = kusto_common.KustoCloudInfo;
pub const KustoCloudInfoCache = kusto_common.KustoCloudInfoCache;
pub const KustoRetryOptions = kusto_common.KustoRetryOptions;
pub const KustoRequestKind = kusto_common.KustoRequestKind;
pub const QueryConsistency = kusto_common.QueryConsistency;
pub const RequestProperty = kusto_common.RequestProperty;

// ─────────────────── Response Types ──────────────────

pub const KustoResultColumn = struct {
    name: []const u8,
    column_type: []const u8,

    pub fn deinit(self: KustoResultColumn, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.column_type);
    }
};

pub const KustoResultRow = struct {
    values: []const []const u8,
    columns: []const KustoResultColumn,

    pub fn deinit(self: KustoResultRow, allocator: std.mem.Allocator) void {
        for (self.values) |value| allocator.free(value);
        allocator.free(self.values);
    }

    /// Get a value by column name.
    pub fn getByName(self: KustoResultRow, name: []const u8) ?[]const u8 {
        for (self.columns, 0..) |col, i| {
            if (std.mem.eql(u8, col.name, name)) {
                return if (i < self.values.len) self.values[i] else null;
            }
        }
        return null;
    }
};

pub const KustoResultTable = struct {
    name: []const u8,
    columns: []const KustoResultColumn,
    rows: []const KustoResultRow,

    pub fn deinit(self: *KustoResultTable, allocator: std.mem.Allocator) void {
        for (self.rows) |row| row.deinit(allocator);
        allocator.free(self.rows);
        for (self.columns) |column| column.deinit(allocator);
        allocator.free(self.columns);
        allocator.free(self.name);
        self.* = .{ .name = "", .columns = &.{}, .rows = &.{} };
    }
};

pub const KustoResponseDataSet = struct {
    tables: []KustoResultTable,
    client_request_id: ?[]u8 = null,
    activity_id: ?[]u8 = null,

    pub fn deinit(self: *KustoResponseDataSet, allocator: std.mem.Allocator) void {
        for (self.tables) |*table| table.deinit(allocator);
        allocator.free(self.tables);
        if (self.client_request_id) |value| allocator.free(value);
        if (self.activity_id) |value| allocator.free(value);
        self.tables = &.{};
        self.client_request_id = null;
        self.activity_id = null;
    }

    /// Get the primary result table (first table named "PrimaryResult" or index 0).
    pub fn primaryTable(self: KustoResponseDataSet) ?KustoResultTable {
        for (self.tables) |t| {
            if (std.mem.eql(u8, t.name, "PrimaryResult")) return t;
        }
        return if (self.tables.len > 0) self.tables[0] else null;
    }
};

// ─────────────────── KustoClient ─────────────────────

pub const KustoClientOptions = struct {
    application_name: []const u8 = "azure-sdk-zig",
    client_version: []const u8 = "azsdk-zig-kusto/0.1.0",
};

/// Client for executing KQL queries and management commands against a Kusto cluster.
///
/// Clients created with `initWithConnection` borrow their `KustoConnection` and
/// may be copied or moved. The connection must outlive every client copy. Since
/// `KustoConnection.supports_concurrent_use` is false, callers must serialize
/// requests that share one connection.
pub const KustoClient = struct {
    runtime: Runtime,
    application_name: []const u8,
    client_version: []const u8,

    const Runtime = union(enum) {
        legacy: struct {
            connection: ConnectionProperties,
            pipeline: core.pipeline.HttpPipeline,
        },
        shared: *KustoConnection,
    };

    pub fn init(
        connection: ConnectionProperties,
        transport: *core.http.HttpTransport,
        options: KustoClientOptions,
    ) KustoClient {
        return .{
            .runtime = .{ .legacy = .{
                .connection = connection,
                .pipeline = .{ .policies = &.{}, .transport_impl = transport },
            } },
            .application_name = options.application_name,
            .client_version = options.client_version,
        };
    }

    /// Create a client that borrows `connection`; this client has no deinit.
    ///
    /// The connection must outlive this client and all copies of it. Serialize
    /// their use because `KustoConnection.supports_concurrent_use` is false.
    pub fn initWithConnection(connection: *KustoConnection, options: KustoClientOptions) KustoClient {
        return .{
            .runtime = .{ .shared = connection },
            .application_name = options.application_name,
            .client_version = options.client_version,
        };
    }

    /// Execute a KQL query. Uses v2 REST endpoint.
    pub fn executeQuery(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, query: []const u8, properties: ?ClientRequestProperties) !KustoResponseDataSet {
        const url = try std.fmt.allocPrint(allocator, "{s}/v2/rest/query", .{self.engineUrl()});
        defer allocator.free(url);
        return self.executeInternal(allocator, url, database, query, properties, .query);
    }

    /// Execute a management command (starts with `.`). Uses v1 REST endpoint.
    pub fn executeMgmt(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, command: []const u8, properties: ?ClientRequestProperties) !KustoResponseDataSet {
        const url = try std.fmt.allocPrint(allocator, "{s}/v1/rest/mgmt", .{self.engineUrl()});
        defer allocator.free(url);
        return self.executeInternal(allocator, url, database, command, properties, .management);
    }

    /// Auto-routing: commands starting with `.` go to mgmt, others to query.
    pub fn execute(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, query_or_command: []const u8) !KustoResponseDataSet {
        const trimmed = std.mem.trimStart(u8, query_or_command, " \t\n\r");
        if (trimmed.len > 0 and trimmed[0] == '.') {
            return self.executeMgmt(allocator, database, query_or_command, null);
        }
        return self.executeQuery(allocator, database, query_or_command, null);
    }

    /// `Result(...)` variants of the execute methods.
    pub fn executeQueryResult(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, query: []const u8, properties: ?ClientRequestProperties) !core.errors.Result(KustoResponseDataSet) {
        const url = try std.fmt.allocPrint(allocator, "{s}/v2/rest/query", .{self.engineUrl()});
        defer allocator.free(url);
        return self.executeInternalResult(allocator, url, database, query, properties, .query);
    }
    pub fn executeMgmtResult(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, command: []const u8, properties: ?ClientRequestProperties) !core.errors.Result(KustoResponseDataSet) {
        const url = try std.fmt.allocPrint(allocator, "{s}/v1/rest/mgmt", .{self.engineUrl()});
        defer allocator.free(url);
        return self.executeInternalResult(allocator, url, database, command, properties, .management);
    }
    pub fn executeResult(self: *KustoClient, allocator: std.mem.Allocator, database: []const u8, query_or_command: []const u8) !core.errors.Result(KustoResponseDataSet) {
        const trimmed = std.mem.trimStart(u8, query_or_command, " \t\n\r");
        if (trimmed.len > 0 and trimmed[0] == '.') {
            return self.executeMgmtResult(allocator, database, query_or_command, null);
        }
        return self.executeQueryResult(allocator, database, query_or_command, null);
    }

    fn executeInternal(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        url: []const u8,
        database: []const u8,
        csl: []const u8,
        properties: ?ClientRequestProperties,
        kind: KustoRequestKind,
    ) !KustoResponseDataSet {
        var r = try self.executeInternalResult(allocator, url, database, csl, properties, kind);
        return r.unwrap(error.KustoQueryFailed);
    }

    fn executeInternalResult(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        url: []const u8,
        database: []const u8,
        csl: []const u8,
        properties: ?ClientRequestProperties,
        kind: KustoRequestKind,
    ) !core.errors.Result(KustoResponseDataSet) {
        const props: ClientRequestProperties = properties orelse ClientRequestProperties{};
        try props.validate(kind);
        const body = try serializeRequest(allocator, database, csl, props, kind);
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json; charset=utf-8");
        try req.setHeader("Accept", "application/json");
        try req.setHeader("Accept-Encoding", "gzip, deflate");
        try req.setHeader("x-ms-app", props.application orelse self.application_name);
        if (props.user) |user| try req.setHeader("x-ms-user", user);
        try req.setHeader("x-ms-client-version", props.client_version orelse self.client_version);
        try req.setHeader("x-ms-version", "2024-12-12");
        if (props.client_request_id) |request_id| {
            try req.setHeader("x-ms-client-request-id", request_id);
        }
        try core.pipeline.ensureRequestId(&req);
        req.operation_timeout_ms = try props.effectiveClientTimeoutMs(kind);
        req.body = body;
        req.retryable = kind == .query;

        var resp = try self.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        var dataset = try parseResponseDataSet(allocator, resp.body);
        errdefer dataset.deinit(allocator);
        const response_request_id = resp.getHeader("x-ms-client-request-id") orelse req.getHeader("x-ms-client-request-id");
        if (response_request_id) |request_id| {
            dataset.client_request_id = try allocator.dupe(u8, request_id);
        }
        if (resp.getHeader("x-ms-activity-id")) |activity_id| {
            dataset.activity_id = try allocator.dupe(u8, activity_id);
        }
        return .{ .ok = dataset };
    }

    fn engineUrl(self: *const KustoClient) []const u8 {
        return switch (self.runtime) {
            .legacy => |legacy| legacy.connection.cluster_url,
            .shared => |connection| connection.engineUrl(),
        };
    }

    fn send(self: *KustoClient, req: *core.http.Request) !core.http.Response {
        return switch (self.runtime) {
            .shared => |connection| connection.send(req),
            .legacy => |*legacy| {
                const connection = legacy.connection;
                if (connection.credential != null or
                    connection.authority_id != null or
                    connection.application_client_id != null or
                    connection.application_key != null)
                {
                    return error.AuthenticatedConnectionRequired;
                }
                return legacy.pipeline.send(req);
            },
        };
    }
};

fn serializeRequest(
    allocator: std.mem.Allocator,
    database: []const u8,
    csl: []const u8,
    properties: ClientRequestProperties,
    kind: KustoRequestKind,
) ![]u8 {
    return kusto_common.serializeRequestBody(allocator, database, csl, properties, kind);
}

// ─────────────────── Response Parsing ────────────────

/// Wire shape of a single column descriptor inside a Kusto v2 DataTable frame.
const KustoColumnSchema = struct {
    ColumnName: []const u8,
    ColumnType: ?[]const u8 = null,
};

const KustoFrameTypeSchema = struct {
    FrameType: ?[]const u8 = null,
};

/// Wire shape of frame metadata. Rows are scanned separately because they
/// contain dynamically typed JSON values.
const KustoFrameSchema = struct {
    FrameType: []const u8,
    TableName: ?[]const u8 = null,
    Columns: ?[]const KustoColumnSchema = null,
};

fn parseResponseDataSet(allocator: std.mem.Allocator, body: []const u8) !KustoResponseDataSet {
    if (!try std.json.validate(allocator, body)) return error.MalformedKustoResponse;

    var deserializer = serde.json.Deserializer.init(body);
    const scanner = &deserializer.scanner;
    const first = scanner.next() catch return error.MalformedKustoResponse;
    if (first != .array_begin) return error.MalformedKustoResponse;

    var tables = std.ArrayList(KustoResultTable).empty;
    errdefer {
        for (tables.items) |*table| table.deinit(allocator);
        tables.deinit(allocator);
    }

    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const frame_slice = captureValue(scanner, body) catch return error.MalformedKustoResponse;
            if (try parseFrame(allocator, frame_slice)) |parsed| {
                var table = parsed;
                errdefer table.deinit(allocator);
                try tables.append(allocator, table);
            }
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }

    scanner.skipWhitespace();
    if (scanner.pos != body.len) return error.MalformedKustoResponse;
    return .{ .tables = try tables.toOwnedSlice(allocator) };
}

fn captureValue(scanner: anytype, input: []const u8) ![]const u8 {
    scanner.skipWhitespace();
    const start = scanner.pos;
    try scanner.skipValue();
    return input[start..scanner.pos];
}

fn parseFrame(allocator: std.mem.Allocator, frame_slice: []const u8) !?KustoResultTable {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const frame_type_schema = serde.json.fromSlice(KustoFrameTypeSchema, arena.allocator(), frame_slice) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return error.MalformedKustoResponse;
    };
    const frame_type = frame_type_schema.FrameType orelse return null;
    if (!std.mem.eql(u8, frame_type, "DataTable")) return null;

    const frame = serde.json.fromSlice(KustoFrameSchema, arena.allocator(), frame_slice) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return error.MalformedKustoResponse;
    };
    const table_name_src = frame.TableName orelse return error.MalformedKustoResponse;
    const columns_src = frame.Columns orelse return error.MalformedKustoResponse;
    const rows_slice = try findRowsSlice(arena.allocator(), frame_slice);

    const table_name = try allocator.dupe(u8, table_name_src);
    errdefer allocator.free(table_name);

    var columns = std.ArrayList(KustoResultColumn).empty;
    errdefer {
        for (columns.items) |column| column.deinit(allocator);
        columns.deinit(allocator);
    }
    for (columns_src) |column_src| {
        {
            var column = KustoResultColumn{
                .name = try allocator.dupe(u8, column_src.ColumnName),
                .column_type = undefined,
            };
            errdefer allocator.free(column.name);
            column.column_type = try allocator.dupe(u8, column_src.ColumnType orelse "string");
            errdefer allocator.free(column.column_type);
            try columns.append(allocator, column);
        }
    }
    const columns_slice = try columns.toOwnedSlice(allocator);
    errdefer {
        for (columns_slice) |column| column.deinit(allocator);
        allocator.free(columns_slice);
    }

    const rows = try parseRows(allocator, rows_slice, columns_slice);
    return .{
        .name = table_name,
        .columns = columns_slice,
        .rows = rows,
    };
}

fn findRowsSlice(allocator: std.mem.Allocator, frame_slice: []const u8) ![]const u8 {
    var deserializer = serde.json.Deserializer.init(frame_slice);
    const scanner = &deserializer.scanner;
    const first = scanner.next() catch return error.MalformedKustoResponse;
    if (first != .object_begin) return error.MalformedKustoResponse;

    var rows_slice: ?[]const u8 = null;
    if (scanner.isContainerEmpty('}') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            scanner.skipWhitespace();
            const key_start = scanner.pos;
            const key_token = scanner.next() catch return error.MalformedKustoResponse;
            if (key_token != .string) return error.MalformedKustoResponse;
            const key_slice = frame_slice[key_start..scanner.pos];
            const key = serde.json.fromSlice([]const u8, allocator, key_slice) catch |err| {
                if (err == error.OutOfMemory) return error.OutOfMemory;
                return error.MalformedKustoResponse;
            };
            scanner.expectColon() catch return error.MalformedKustoResponse;
            const value_slice = captureValue(scanner, frame_slice) catch return error.MalformedKustoResponse;
            if (std.mem.eql(u8, key, "Rows")) {
                if (rows_slice != null) return error.MalformedKustoResponse;
                rows_slice = value_slice;
            }
            switch (scanner.finishContainer('}') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    scanner.skipWhitespace();
    if (scanner.pos != frame_slice.len) return error.MalformedKustoResponse;
    return rows_slice orelse error.MalformedKustoResponse;
}

fn parseRows(
    allocator: std.mem.Allocator,
    rows_slice: []const u8,
    columns: []const KustoResultColumn,
) ![]KustoResultRow {
    var deserializer = serde.json.Deserializer.init(rows_slice);
    const scanner = &deserializer.scanner;
    const first = scanner.next() catch return error.MalformedKustoResponse;
    if (first != .array_begin) return error.MalformedKustoResponse;

    var rows = std.ArrayList(KustoResultRow).empty;
    errdefer {
        for (rows.items) |row| row.deinit(allocator);
        rows.deinit(allocator);
    }
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const row_slice = captureValue(scanner, rows_slice) catch return error.MalformedKustoResponse;
            const values = try parseRowValues(allocator, row_slice);
            {
                var row = KustoResultRow{ .values = values, .columns = columns };
                errdefer row.deinit(allocator);
                try rows.append(allocator, row);
            }
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    scanner.skipWhitespace();
    if (scanner.pos != rows_slice.len) return error.MalformedKustoResponse;
    return rows.toOwnedSlice(allocator);
}

fn parseRowValues(allocator: std.mem.Allocator, row_slice: []const u8) ![]const []const u8 {
    var deserializer = serde.json.Deserializer.init(row_slice);
    const scanner = &deserializer.scanner;
    const first = scanner.next() catch return error.MalformedKustoResponse;
    if (first != .array_begin) return error.MalformedKustoResponse;

    var values = std.ArrayList([]const u8).empty;
    errdefer {
        for (values.items) |value| allocator.free(value);
        values.deinit(allocator);
    }
    if (scanner.isContainerEmpty(']') catch return error.MalformedKustoResponse) {
        _ = scanner.next() catch return error.MalformedKustoResponse;
    } else {
        while (true) {
            const cell_slice = captureValue(scanner, row_slice) catch return error.MalformedKustoResponse;
            const value = try decodeCell(allocator, cell_slice);
            {
                errdefer allocator.free(value);
                try values.append(allocator, value);
            }
            switch (scanner.finishContainer(']') catch return error.MalformedKustoResponse) {
                .end => break,
                .more => {},
            }
        }
    }
    scanner.skipWhitespace();
    if (scanner.pos != row_slice.len) return error.MalformedKustoResponse;
    return values.toOwnedSlice(allocator);
}

fn decodeCell(allocator: std.mem.Allocator, cell_slice: []const u8) ![]const u8 {
    var deserializer = serde.json.Deserializer.init(cell_slice);
    const token = deserializer.scanner.peek() catch return error.MalformedKustoResponse;
    if (token == .string) {
        return serde.json.fromSlice([]const u8, allocator, cell_slice) catch |err| {
            if (err == error.OutOfMemory) return error.OutOfMemory;
            return error.MalformedKustoResponse;
        };
    }
    return allocator.dupe(u8, std.mem.trim(u8, cell_slice, " \t\n\r"));
}

// ─────────────────────── Tests ───────────────────────

const TestTokenCredential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = &getToken },
    call_count: usize = 0,
    last_scope: ?[]const u8 = null,

    fn asCredential(self: *TestTokenCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *TestTokenCredential = @alignCast(@fieldParentPtr("credential", credential));
        self.call_count += 1;
        self.last_scope = request_context.scopes[0];
        return .{
            .token = "data-client-test-token",
            .expires_on = std.math.maxInt(i64),
        };
    }
};

test "KustoClient executeQuery" {
    const allocator = std.testing.allocator;
    const response_body =
        \\[{"FrameType":"DataTable","TableName":"PrimaryResult","Columns":[{"ColumnName":"Count","ColumnType":"long"}],"Rows":[[42]]}]
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    var result = try client.executeQuery(allocator, "TestDB", "StormEvents | count", null);
    defer result.deinit(allocator);

    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v2/rest/query") != null);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    const request_id = mock.last_headers.get("x-ms-client-request-id").?;
    try std.testing.expectEqual(@as(usize, 36), request_id.len);
    try std.testing.expectEqualStrings(request_id, result.client_request_id.?);

    const primary = result.primaryTable().?;
    try std.testing.expectEqualStrings("PrimaryResult", primary.name);
    try std.testing.expectEqual(@as(usize, 1), primary.columns.len);
    try std.testing.expectEqualStrings("Count", primary.columns[0].name);
    try std.testing.expectEqual(@as(usize, 1), primary.rows.len);
    try std.testing.expectEqualStrings("42", primary.rows[0].values[0]);
}

test "shared KustoClient authenticates queries" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();
    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net/",
            .credential = credential.asCredential(),
        },
        mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer connection.deinit();

    var client = KustoClient.initWithConnection(connection, .{});
    var result = try client.executeQuery(
        allocator,
        "db",
        "print 1",
        .{ .client_request_id = "kusto-test-request-id" },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), credential.call_count);
    try std.testing.expectEqualStrings(
        "https://kusto.kusto.windows.net/.default",
        credential.last_scope.?,
    );
    try std.testing.expect(mock.last_headers.get("Authorization") != null);
    try std.testing.expectEqualStrings(
        "kusto-test-request-id",
        mock.last_headers.get("x-ms-client-request-id").?,
    );
    try std.testing.expectEqualStrings(
        "https://cluster.kusto.windows.net/v2/rest/query",
        mock.last_url.?,
    );
}

test "shared KustoClient uses explicit engine endpoint for queries" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();
    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = credential.asCredential(),
        },
        mock.asTransport(),
        .{
            .metadata_mode = .disabled,
            .engine_endpoint = "https://query-engine.kusto.windows.net",
            .data_management_endpoint = "https://ingest-dm.kusto.windows.net",
        },
    );
    defer connection.deinit();

    var client = KustoClient.initWithConnection(connection, .{});
    var result = try client.executeQuery(allocator, "db", "print 1", null);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings(
        "https://query-engine.kusto.windows.net/v2/rest/query",
        mock.last_url.?,
    );
}

test "copied shared KustoClient remains usable" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();
    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = credential.asCredential(),
        },
        mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer connection.deinit();

    const copied = KustoClient.initWithConnection(connection, .{});
    var moved = copied;
    var result = try moved.executeQuery(allocator, "db", "print 1", null);
    defer result.deinit(allocator);

    try std.testing.expect(mock.last_url != null);
    try std.testing.expectEqual(@as(usize, 1), credential.call_count);
}

test "legacy authenticated KustoClient fails before transport" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();
    var client = KustoClient.init(
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = credential.asCredential(),
        },
        mock.asTransport(),
        .{},
    );

    try std.testing.expectError(
        error.AuthenticatedConnectionRequired,
        client.executeQuery(allocator, "db", "print 1", null),
    );
    try std.testing.expect(mock.last_url == null);
    try std.testing.expectEqual(@as(usize, 0), credential.call_count);
}

test "shared KustoClient retries queries" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 500, .body = "server error" },
        .{ .status = 200, .body = "[]" },
    };
    var sequence = core.http.SequenceMockTransport.init(allocator, &responses);
    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = credential.asCredential(),
        },
        sequence.asTransport(),
        .{
            .metadata_mode = .disabled,
            .retry = .{
                .max_retries = 1,
                .initial_delay_ms = 0,
                .max_delay_ms = 0,
            },
        },
    );
    defer connection.deinit();

    var client = KustoClient.initWithConnection(connection, .{});
    var result = try client.executeQuery(allocator, "db", "print 1", null);
    defer result.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), sequence.call_count);
}

test "shared KustoClient does not retry management commands" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{
            .status = 500,
            .body = "{\"error\":{\"code\":\"ServerError\",\"message\":\"failed\"}}",
        },
        .{ .status = 200, .body = "[]" },
    };
    var sequence = core.http.SequenceMockTransport.init(allocator, &responses);
    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = credential.asCredential(),
        },
        sequence.asTransport(),
        .{
            .metadata_mode = .disabled,
            .retry = .{
                .max_retries = 1,
                .initial_delay_ms = 0,
                .max_delay_ms = 0,
            },
        },
    );
    defer connection.deinit();

    var client = KustoClient.initWithConnection(connection, .{});
    try std.testing.expectError(
        error.KustoQueryFailed,
        client.executeMgmt(allocator, "db", ".show tables", null),
    );
    try std.testing.expectEqual(@as(usize, 1), sequence.call_count);
}

test "KustoClient executeMgmt" {
    const allocator = std.testing.allocator;
    const response_body =
        \\[{"FrameType":"DataTable","TableName":"Table_0","Columns":[{"ColumnName":"DatabaseName","ColumnType":"string"}],"Rows":[["TestDB"]]}]
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    var result = try client.executeMgmt(allocator, "TestDB", ".show databases", null);
    defer result.deinit(allocator);

    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v1/rest/mgmt") != null);
    try std.testing.expect(std.mem.find(u8, mock.last_body.?, "\"servertimeout\":\"00:10:00.000\"") != null);
    try std.testing.expectEqual(@as(?u64, 630_000), mock.last_operation_timeout_ms);
    const table = result.tables[0];
    try std.testing.expectEqualStrings("TestDB", table.rows[0].values[0]);
}

test "KustoClient execute auto-routes to mgmt" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    var result = try client.execute(allocator, "db", ".show databases");
    defer result.deinit(allocator);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v1/rest/mgmt") != null);
}

test "KustoClient execute auto-routes to query" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    var result = try client.execute(allocator, "db", "StormEvents | count");
    defer result.deinit(allocator);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v2/rest/query") != null);
}

test "KustoClient query failure returns error" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 400,
        \\{"error":{"code":"BadRequest","message":"Invalid query"}}
    );
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    const result = client.executeQuery(allocator, "db", "INVALID", null);
    try std.testing.expectError(error.KustoQueryFailed, result);
}

test "KustoResultRow getByName" {
    const cols = [_]KustoResultColumn{
        .{ .name = "Name", .column_type = "string" },
        .{ .name = "Age", .column_type = "long" },
    };
    const vals = [_][]const u8{ "Alice", "30" };
    const row = KustoResultRow{ .values = &vals, .columns = &cols };
    try std.testing.expectEqualStrings("Alice", row.getByName("Name").?);
    try std.testing.expectEqualStrings("30", row.getByName("Age").?);
    try std.testing.expect(row.getByName("Missing") == null);
}

test "Kusto request bodies round trip caller strings" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();

    const conn = kusto_common.ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    const database = "db\"\\\n\t\x01";
    const query = "print value = \"a\\\\b\"\n\t\r";
    var query_result = try client.executeQuery(
        allocator,
        database,
        query,
        .{ .client_request_id = "ignored-for-now", .application = "ignored-for-now" },
    );
    defer query_result.deinit(allocator);

    var query_arena = std.heap.ArenaAllocator.init(allocator);
    defer query_arena.deinit();
    const query_wire = try serde.json.fromSlice(
        struct { db: []const u8, csl: []const u8 },
        query_arena.allocator(),
        mock.last_body.?,
    );
    try std.testing.expectEqualStrings(database, query_wire.db);
    try std.testing.expectEqualStrings(query, query_wire.csl);
    try std.testing.expect(std.mem.find(u8, mock.last_body.?, "\"properties\":{\"Options\":{\"servertimeout\":\"00:04:00.000\"},\"Parameters\":{}}") != null);
    try std.testing.expectEqual(@as(?u64, 270_000), mock.last_operation_timeout_ms);

    const command = ".show table [a\"b\\\\c]\n\t";
    var mgmt_result = try client.executeMgmt(
        allocator,
        database,
        command,
        .{ .server_timeout_ms = 300000 },
    );
    defer mgmt_result.deinit(allocator);

    var mgmt_arena = std.heap.ArenaAllocator.init(allocator);
    defer mgmt_arena.deinit();
    const mgmt_wire = try serde.json.fromSlice(
        struct { db: []const u8, csl: []const u8 },
        mgmt_arena.allocator(),
        mock.last_body.?,
    );
    try std.testing.expectEqualStrings(database, mgmt_wire.db);
    try std.testing.expectEqualStrings(command, mgmt_wire.csl);
    try std.testing.expect(std.mem.find(u8, mock.last_body.?, "\"properties\":{\"Options\":{\"servertimeout\":\"00:05:00.000\"},\"Parameters\":{}}") != null);
    try std.testing.expectEqual(@as(?u64, 330_000), mock.last_operation_timeout_ms);
}

test "KustoClient applies diagnostic headers and owns response correlation" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    mock.response_headers_list = &.{
        .{ .name = "X-MS-Client-Request-Id", .value = "echoed-request-id" },
        .{ .name = "x-ms-activity-id", .value = "activity-id" },
    };
    defer mock.deinit();
    const connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = credential.asCredential(),
        },
        mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer connection.deinit();

    var properties = ClientRequestProperties{
        .client_request_id = "caller-request-id",
        .application = "caller-app",
        .user = "caller-user",
        .client_version = "caller-version",
        .server_timeout_ms = 90_001,
        .client_timeout_ms = 120_000,
    };
    defer properties.deinit(allocator);
    try properties.setOption(allocator, "best_effort", true);
    try properties.setParameter(allocator, "limit", @as(i64, 5));

    var client = KustoClient.initWithConnection(connection, .{
        .application_name = "default-app",
        .client_version = "default-version",
    });
    var result = try client.executeQuery(allocator, "db", "print 1", properties);
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("caller-request-id", mock.last_headers.get("x-ms-client-request-id").?);
    try std.testing.expectEqualStrings("caller-app", mock.last_headers.get("x-ms-app").?);
    try std.testing.expectEqualStrings("caller-user", mock.last_headers.get("x-ms-user").?);
    try std.testing.expectEqualStrings("caller-version", mock.last_headers.get("x-ms-client-version").?);
    try std.testing.expectEqualStrings("2024-12-12", mock.last_headers.get("x-ms-version").?);
    try std.testing.expectEqualStrings("gzip, deflate", mock.last_headers.get("Accept-Encoding").?);
    try std.testing.expectEqual(@as(?u64, 120_000), mock.last_operation_timeout_ms);
    try std.testing.expect(std.mem.find(u8, mock.last_body.?, "\"servertimeout\":\"00:01:30.001\"") != null);
    try std.testing.expect(std.mem.find(u8, mock.last_body.?, "\"best_effort\":true") != null);
    try std.testing.expect(std.mem.find(u8, mock.last_body.?, "\"limit\":5") != null);
    try std.testing.expectEqualStrings("echoed-request-id", result.client_request_id.?);
    try std.testing.expectEqualStrings("activity-id", result.activity_id.?);
}

test "KustoClient rejects invalid request properties before transport" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "[]");
    defer mock.deinit();
    const conn = ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = KustoClient.init(conn, mock.asTransport(), .{});

    try std.testing.expectError(
        error.InvalidServerTimeout,
        client.executeQuery(allocator, "db", "print 1", .{ .server_timeout_ms = 999 }),
    );
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}

test "Kusto response preserves dynamic JSON cells" {
    const response_body =
        \\[
        \\  {"FrameType":"DataSetHeader","Version":"v2.0"},
        \\  {"FrameType":"DataTable","TableName":"PrimaryResult","Columns":[
        \\    {"ColumnName":"Text","ColumnType":"string"},
        \\    {"ColumnName":"Object","ColumnType":"dynamic"},
        \\    {"ColumnName":"Array","ColumnType":"dynamic"},
        \\    {"ColumnName":"Null","ColumnType":"string"},
        \\    {"ColumnName":"Boolean","ColumnType":"bool"},
        \\    {"ColumnName":"Number","ColumnType":"real"},
        \\    {"ColumnName":"EmptyArray","ColumnType":"dynamic"}
        \\  ],"Rows":[[
        \\    "line\n\"quote\" \\ slash \u2603",
        \\    {"a":[1,2],"s":"x,y"},
        \\    [1,{"nested":[true,null]}],
        \\    null,
        \\    false,
        \\    -12.5e+2,
        \\    []
        \\  ]]},
        \\  {"FrameType":"DataSetCompletion","HasErrors":false}
        \\]
    ;

    var dataset = try parseResponseDataSet(std.testing.allocator, response_body);
    defer dataset.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), dataset.tables.len);
    const values = dataset.tables[0].rows[0].values;
    try std.testing.expectEqual(@as(usize, 7), values.len);
    try std.testing.expectEqualStrings("line\n\"quote\" \\ slash \xE2\x98\x83", values[0]);
    try std.testing.expectEqualStrings("{\"a\":[1,2],\"s\":\"x,y\"}", values[1]);
    try std.testing.expectEqualStrings("[1,{\"nested\":[true,null]}]", values[2]);
    try std.testing.expectEqualStrings("null", values[3]);
    try std.testing.expectEqualStrings("false", values[4]);
    try std.testing.expectEqualStrings("-12.5e+2", values[5]);
    try std.testing.expectEqualStrings("[]", values[6]);
}

test "Kusto response accepts empty dataset and skips non-table frames" {
    var empty = try parseResponseDataSet(std.testing.allocator, "[]");
    defer empty.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), empty.tables.len);

    var frames = try parseResponseDataSet(std.testing.allocator,
        \\[{"FrameType":"DataSetHeader","nested":{"values":[1,2]}},{"FrameType":"DataSetCompletion"}]
    );
    defer frames.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), frames.tables.len);
}

test "Kusto response rejects malformed bodies and DataTable shapes" {
    const malformed = [_][]const u8{
        "not json",
        "{}",
        "[",
        "[] trailing",
        \\[{"FrameType":"DataTable","TableName":"T","Columns":[]}]
        ,
        \\[{"FrameType":"DataTable","TableName":"T","Columns":[],"Rows":{}}]
        ,
        \\[{"FrameType":"DataTable","TableName":"T","Columns":[],"Rows":[42]}]
        ,
        \\[{"FrameType":"DataTable","TableName":"T","Columns":{},"Rows":[]}]
        ,
        \\[{"FrameType":"DataTable","Columns":[],"Rows":[]}]
        ,
        \\[{"FrameType":"DataTable","TableName":"T","Columns":[],"Rows":[["\uZZZZ"]]}]
        ,
    };
    for (malformed) |body| {
        try std.testing.expectError(
            error.MalformedKustoResponse,
            parseResponseDataSet(std.testing.allocator, body),
        );
    }
}

test "Kusto dataset and Result deinit own all parsed allocations" {
    const response_body =
        \\[{"FrameType":"DataTable","TableName":"T","Columns":[{"ColumnName":"C"}],"Rows":[["value"]]}]
    ;

    var dataset = try parseResponseDataSet(std.testing.allocator, response_body);
    dataset.deinit(std.testing.allocator);

    var result: core.errors.Result(KustoResponseDataSet) = .{
        .ok = try parseResponseDataSet(std.testing.allocator, response_body),
    };
    result.deinit(std.testing.allocator);
}

fn parseAllocationFixture(allocator: std.mem.Allocator, body: []const u8) !void {
    var dataset = try parseResponseDataSet(allocator, body);
    defer dataset.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), dataset.tables.len);
    try std.testing.expectEqualStrings("escaped\nvalue", dataset.tables[0].rows[0].values[0]);
}

test "Kusto response parser handles every allocation failure" {
    const response_body =
        \\[
        \\  {"FrameType":"DataSetHeader"},
        \\  {"FrameType":"DataTable","TableName":"PrimaryResult","Columns":[
        \\    {"ColumnName":"A","ColumnType":"string"},
        \\    {"ColumnName":"B","ColumnType":"dynamic"}
        \\  ],"Rows":[["escaped\nvalue",{"nested":[1,2]}],["second",null]]},
        \\  {"FrameType":"DataTable","TableName":"SecondaryResult","Columns":[
        \\    {"ColumnName":"C","ColumnType":"long"}
        \\  ],"Rows":[[42]]}
        \\]
    ;
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        parseAllocationFixture,
        .{response_body},
    );
}
