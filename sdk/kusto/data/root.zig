///! Azure Kusto (Data Explorer) data client — queries and management commands.
///!
///! Provides `KustoClient` for executing KQL queries via `/v2/rest/query`
///! and management commands via `/v1/rest/mgmt`.
const std = @import("std");
const core = @import("azure_core");
const serde = @import("serde");
const kusto_common = @import("azure_kusto_common");
const result = @import("result.zig");

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
pub const KustoError = kusto_common.KustoError;
pub const KustoErrorDetail = kusto_common.KustoErrorDetail;
pub const KustoOperation = kusto_common.KustoOperation;
pub const KustoErrorSource = kusto_common.KustoErrorSource;
pub const KustoOperationOutcome = kusto_common.KustoOperationOutcome;
pub const KustoResult = kusto_common.KustoResult;

pub const DecodeOptions = result.DecodeOptions;
pub const KustoResponseProtocol = result.KustoResponseProtocol;
pub const KustoScalarKind = result.KustoScalarKind;
pub const KustoTableKind = result.KustoTableKind;
pub const KustoValue = result.KustoValue;
pub const KustoResultColumn = result.KustoResultColumn;
pub const KustoResultRow = result.KustoResultRow;
pub const KustoResultTable = result.KustoResultTable;
pub const KustoFramePayload = result.KustoFramePayload;
pub const KustoUnknownFrame = result.KustoUnknownFrame;
pub const KustoFrame = result.KustoFrame;
pub const RowIterator = result.RowIterator;
pub const TableIterator = result.TableIterator;
pub const FrameIterator = result.FrameIterator;
pub const KustoResponseDataSet = result.KustoResponseDataSet;
pub const DecodeOutcome = result.DecodeOutcome;
pub const decodeResponseDataSet = result.decode;

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
    pub fn initWithConnection(connection: *KustoConnection, options: KustoClientOptions) KustoClient {
        return .{
            .runtime = .{ .shared = connection },
            .application_name = options.application_name,
            .client_version = options.client_version,
        };
    }

    /// Execute a KQL query. Uses the V2 REST endpoint.
    pub fn executeQuery(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        database: []const u8,
        query: []const u8,
        properties: ?ClientRequestProperties,
    ) !KustoResponseDataSet {
        const url = try std.fmt.allocPrint(allocator, "{s}/v2/rest/query", .{self.engineUrl()});
        defer allocator.free(url);
        return self.executeInternal(allocator, url, database, query, properties, .query);
    }

    /// Execute a management command (starts with `.`). Uses the V1 REST endpoint.
    pub fn executeMgmt(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        database: []const u8,
        command: []const u8,
        properties: ?ClientRequestProperties,
    ) !KustoResponseDataSet {
        const url = try std.fmt.allocPrint(allocator, "{s}/v1/rest/mgmt", .{self.engineUrl()});
        defer allocator.free(url);
        return self.executeInternal(allocator, url, database, command, properties, .management);
    }

    /// Auto-routing: commands starting with `.` go to management, others to query.
    pub fn execute(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        database: []const u8,
        query_or_command: []const u8,
    ) !KustoResponseDataSet {
        const trimmed = std.mem.trimStart(u8, query_or_command, " \t\n\r");
        if (trimmed.len > 0 and trimmed[0] == '.')
            return self.executeMgmt(allocator, database, query_or_command, null);
        return self.executeQuery(allocator, database, query_or_command, null);
    }

    pub fn executeQueryResult(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        database: []const u8,
        query: []const u8,
        properties: ?ClientRequestProperties,
    ) !KustoResult(KustoResponseDataSet) {
        const url = try std.fmt.allocPrint(allocator, "{s}/v2/rest/query", .{self.engineUrl()});
        defer allocator.free(url);
        return self.executeInternalResult(allocator, url, database, query, properties, .query);
    }

    pub fn executeMgmtResult(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        database: []const u8,
        command: []const u8,
        properties: ?ClientRequestProperties,
    ) !KustoResult(KustoResponseDataSet) {
        const url = try std.fmt.allocPrint(allocator, "{s}/v1/rest/mgmt", .{self.engineUrl()});
        defer allocator.free(url);
        return self.executeInternalResult(allocator, url, database, command, properties, .management);
    }

    pub fn executeResult(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        database: []const u8,
        query_or_command: []const u8,
    ) !KustoResult(KustoResponseDataSet) {
        const trimmed = std.mem.trimStart(u8, query_or_command, " \t\n\r");
        if (trimmed.len > 0 and trimmed[0] == '.')
            return self.executeMgmtResult(allocator, database, query_or_command, null);
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
        var response_result = try self.executeInternalResult(allocator, url, database, csl, properties, kind);
        return switch (response_result) {
            .ok => |value| value,
            .partial => |*partial| {
                std.log.warn("{f}", .{partial.failure});
                partial.failure.deinit();
                partial.value.deinit(allocator);
                return error.KustoQueryFailed;
            },
            .err => |*failure| {
                std.log.warn("{f}", .{failure.*});
                failure.deinit();
                return error.KustoQueryFailed;
            },
        };
    }

    fn executeInternalResult(
        self: *KustoClient,
        allocator: std.mem.Allocator,
        url: []const u8,
        database: []const u8,
        csl: []const u8,
        properties: ?ClientRequestProperties,
        kind: KustoRequestKind,
    ) !KustoResult(KustoResponseDataSet) {
        const props: ClientRequestProperties = properties orelse ClientRequestProperties{};
        try props.validate(kind);
        const body = try serializeRequest(allocator, database, csl, props, kind);
        defer allocator.free(body);

        var request = core.http.Request.init(allocator, .POST, url);
        defer request.deinit();
        try request.setHeader("Content-Type", "application/json; charset=utf-8");
        try request.setHeader("Accept", "application/json");
        try request.setHeader("Accept-Encoding", "gzip, deflate");
        try request.setHeader("x-ms-app", props.application orelse self.application_name);
        if (props.user) |user| try request.setHeader("x-ms-user", user);
        try request.setHeader("x-ms-client-version", props.client_version orelse self.client_version);
        try request.setHeader("x-ms-version", "2024-12-12");
        if (props.client_request_id) |request_id|
            try request.setHeader("x-ms-client-request-id", request_id);
        try core.pipeline.ensureRequestId(&request);
        request.operation_timeout_ms = try props.effectiveClientTimeoutMs(kind);
        request.body = body;
        request.retryable = kind == .query;

        var response = try self.send(&request);
        defer response.deinit();
        const operation: KustoOperation = if (kind == .query) .query else .management;
        if (!response.isSuccess()) {
            var failure = try kusto_common.errors.fromHttpResponse(
                allocator,
                operation,
                &response,
                .known_not_accepted,
            );
            errdefer failure.deinit();
            try kusto_common.errors.applyResponseCorrelation(
                &failure,
                &response,
                request.getHeader("x-ms-client-request-id"),
            );
            return .{ .err = failure };
        }

        const decoded = try result.decode(
            allocator,
            response.body,
            .{ .allow_varying_row_widths = try props.allowVaryingRowWidths() },
            operation,
        );
        var dataset = decoded.dataset;
        errdefer dataset.deinit(allocator);
        var in_band_failure = decoded.failure;
        errdefer if (in_band_failure) |*failure| failure.deinit();
        const response_request_id = response.getHeader("x-ms-client-request-id") orelse request.getHeader("x-ms-client-request-id");
        if (response_request_id) |request_id|
            dataset.client_request_id = try allocator.dupe(u8, request_id);
        if (response.getHeader("x-ms-activity-id")) |activity_id|
            dataset.activity_id = try allocator.dupe(u8, activity_id);
        if (in_band_failure) |*failure| {
            try kusto_common.errors.applyResponseCorrelation(
                failure,
                &response,
                request.getHeader("x-ms-client-request-id"),
            );
            const owned_failure = failure.*;
            in_band_failure = null;
            return .{ .partial = .{ .value = dataset, .failure = owned_failure } };
        }
        return .{ .ok = dataset };
    }

    fn engineUrl(self: *const KustoClient) []const u8 {
        return switch (self.runtime) {
            .legacy => |legacy| legacy.connection.cluster_url,
            .shared => |connection| connection.engineUrl(),
        };
    }

    fn send(self: *KustoClient, request: *core.http.Request) !core.http.Response {
        return switch (self.runtime) {
            .shared => |connection| connection.send(request),
            .legacy => |*legacy| {
                const connection = legacy.connection;
                if (connection.credential != null or
                    connection.authority_id != null or
                    connection.application_client_id != null or
                    connection.application_key != null)
                {
                    return error.AuthenticatedConnectionRequired;
                }
                return legacy.pipeline.send(request);
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

const empty_v2_response =
    \\[
    \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
    \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
    \\]
;

test "KustoClient executes a normal V2 query" {
    const allocator = std.testing.allocator;
    const response_body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"PrimaryResult","Columns":[{"ColumnName":"Count","ColumnType":"long"}],"Rows":[[42]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );

    var dataset = try client.executeQuery(allocator, "TestDB", "StormEvents | count", null);
    defer dataset.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "/v2/rest/query") != null);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
    const request_id = mock.last_headers.get("x-ms-client-request-id").?;
    try std.testing.expectEqual(@as(usize, 36), request_id.len);
    try std.testing.expectEqualStrings(request_id, dataset.client_request_id.?);
    try std.testing.expectEqual(
        @as(?i64, 42),
        dataset.primaryTable().?.rows[0].getByName("Count").?.asI64(),
    );
}

test "shared KustoClient authenticates queries" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, empty_v2_response);
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
    var dataset = try client.executeQuery(
        allocator,
        "db",
        "print 1",
        .{ .client_request_id = "kusto-test-request-id" },
    );
    defer dataset.deinit(allocator);

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

test "shared KustoClient uses an explicit engine endpoint" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, empty_v2_response);
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
    var dataset = try client.executeQuery(allocator, "db", "print 1", null);
    defer dataset.deinit(allocator);
    try std.testing.expectEqualStrings(
        "https://query-engine.kusto.windows.net/v2/rest/query",
        mock.last_url.?,
    );
}

test "copied shared KustoClient remains usable" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, empty_v2_response);
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
    var dataset = try moved.executeQuery(allocator, "db", "print 1", null);
    defer dataset.deinit(allocator);
    try std.testing.expect(mock.last_url != null);
    try std.testing.expectEqual(@as(usize, 1), credential.call_count);
}

test "legacy authenticated KustoClient fails before transport" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, empty_v2_response);
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

test "shared KustoClient retries queries but not management commands" {
    const allocator = std.testing.allocator;
    var query_credential = TestTokenCredential{};
    const query_responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 500, .body = "server error" },
        .{ .status = 200, .body = empty_v2_response },
    };
    var query_sequence = core.http.SequenceMockTransport.init(allocator, &query_responses);
    const query_connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = query_credential.asCredential(),
        },
        query_sequence.asTransport(),
        .{
            .metadata_mode = .disabled,
            .retry = .{ .max_retries = 1, .initial_delay_ms = 0, .max_delay_ms = 0 },
        },
    );
    defer query_connection.deinit();
    var query_client = KustoClient.initWithConnection(query_connection, .{});
    var dataset = try query_client.executeQuery(allocator, "db", "print 1", null);
    defer dataset.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), query_sequence.call_count);

    var management_credential = TestTokenCredential{};
    const management_responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 500, .body = "{\"error\":{\"code\":\"ServerError\",\"message\":\"failed\"}}" },
        .{ .status = 200, .body = empty_v2_response },
    };
    var management_sequence = core.http.SequenceMockTransport.init(allocator, &management_responses);
    const management_connection = try KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = management_credential.asCredential(),
        },
        management_sequence.asTransport(),
        .{
            .metadata_mode = .disabled,
            .retry = .{ .max_retries = 1, .initial_delay_ms = 0, .max_delay_ms = 0 },
        },
    );
    defer management_connection.deinit();
    var management_client = KustoClient.initWithConnection(management_connection, .{});
    try std.testing.expectError(
        error.KustoQueryFailed,
        management_client.executeMgmt(allocator, "db", ".show tables", null),
    );
    try std.testing.expectEqual(@as(usize, 1), management_sequence.call_count);
}

test "KustoClient executes management and auto-routes requests" {
    const allocator = std.testing.allocator;
    const response_body =
        \\{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"DatabaseName","ColumnType":"string"}],"Rows":[["TestDB"]]}]}
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );

    var management = try client.executeMgmt(allocator, "TestDB", ".show databases", null);
    defer management.deinit(allocator);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "/v1/rest/mgmt") != null);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_body.?, "\"servertimeout\":\"00:10:00.000\"") != null);
    try std.testing.expectEqual(@as(?u64, 630_000), mock.last_operation_timeout_ms);

    var auto_management = try client.execute(allocator, "db", " \t.show databases");
    defer auto_management.deinit(allocator);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "/v1/rest/mgmt") != null);

    mock.response_body = empty_v2_response;
    var auto_query = try client.execute(allocator, "db", "StormEvents | count");
    defer auto_query.deinit(allocator);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "/v2/rest/query") != null);
}

test "KustoClient returns query HTTP failures" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 400,
        \\{"error":{"code":"BadRequest","message":"Invalid query"}}
    );
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );
    try std.testing.expectError(
        error.KustoQueryFailed,
        client.executeQuery(allocator, "db", "INVALID", null),
    );
}

test "Kusto request bodies round trip caller strings" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, empty_v2_response);
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );
    const database = "db\"\\\n\t\x01";
    const query = "print value = \"a\\\\b\"\n\t\r";
    var query_dataset = try client.executeQuery(
        allocator,
        database,
        query,
        .{ .client_request_id = "ignored-for-now", .application = "ignored-for-now" },
    );
    defer query_dataset.deinit(allocator);
    var query_arena = std.heap.ArenaAllocator.init(allocator);
    defer query_arena.deinit();
    const query_wire = try serde.json.fromSlice(
        struct { db: []const u8, csl: []const u8 },
        query_arena.allocator(),
        mock.last_body.?,
    );
    try std.testing.expectEqualStrings(database, query_wire.db);
    try std.testing.expectEqualStrings(query, query_wire.csl);
    try std.testing.expect(std.mem.indexOf(
        u8,
        mock.last_body.?,
        "\"properties\":{\"Options\":{\"servertimeout\":\"00:04:00.000\"},\"Parameters\":{}}",
    ) != null);
    try std.testing.expectEqual(@as(?u64, 270_000), mock.last_operation_timeout_ms);

    const command = ".show table [a\"b\\\\c]\n\t";
    mock.response_body =
        \\{"Tables":[]}
    ;
    var management_dataset = try client.executeMgmt(
        allocator,
        database,
        command,
        .{ .server_timeout_ms = 300000 },
    );
    defer management_dataset.deinit(allocator);
    var management_arena = std.heap.ArenaAllocator.init(allocator);
    defer management_arena.deinit();
    const management_wire = try serde.json.fromSlice(
        struct { db: []const u8, csl: []const u8 },
        management_arena.allocator(),
        mock.last_body.?,
    );
    try std.testing.expectEqualStrings(database, management_wire.db);
    try std.testing.expectEqualStrings(command, management_wire.csl);
    try std.testing.expect(std.mem.indexOf(
        u8,
        mock.last_body.?,
        "\"properties\":{\"Options\":{\"servertimeout\":\"00:05:00.000\"},\"Parameters\":{}}",
    ) != null);
    try std.testing.expectEqual(@as(?u64, 330_000), mock.last_operation_timeout_ms);
}

test "KustoClient applies diagnostic headers and owns response correlation" {
    const allocator = std.testing.allocator;
    var credential = TestTokenCredential{};
    var mock = core.http.MockTransport.init(allocator, 200, empty_v2_response);
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
    var dataset = try client.executeQuery(allocator, "db", "print 1", properties);
    defer dataset.deinit(allocator);
    try std.testing.expectEqualStrings("caller-request-id", mock.last_headers.get("x-ms-client-request-id").?);
    try std.testing.expectEqualStrings("caller-app", mock.last_headers.get("x-ms-app").?);
    try std.testing.expectEqualStrings("caller-user", mock.last_headers.get("x-ms-user").?);
    try std.testing.expectEqualStrings("caller-version", mock.last_headers.get("x-ms-client-version").?);
    try std.testing.expectEqualStrings("2024-12-12", mock.last_headers.get("x-ms-version").?);
    try std.testing.expectEqualStrings("gzip, deflate", mock.last_headers.get("Accept-Encoding").?);
    try std.testing.expectEqual(@as(?u64, 120_000), mock.last_operation_timeout_ms);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_body.?, "\"servertimeout\":\"00:01:30.001\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_body.?, "\"best_effort\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, mock.last_body.?, "\"limit\":5") != null);
    try std.testing.expectEqualStrings("echoed-request-id", dataset.client_request_id.?);
    try std.testing.expectEqualStrings("activity-id", dataset.activity_id.?);
}

test "KustoClient rejects invalid request properties before transport" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, empty_v2_response);
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );
    try std.testing.expectError(
        error.InvalidServerTimeout,
        client.executeQuery(allocator, "db", "print 1", .{ .server_timeout_ms = 999 }),
    );
    try std.testing.expectEqual(@as(usize, 0), mock.call_count);
}

test "Kusto non-2xx malformed body is a structured HTTP failure" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 502, "gateway said no");
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );
    var response_result = try client.executeQueryResult(allocator, "db", "print 1", null);
    defer response_result.deinit(allocator);
    switch (response_result) {
        .err => |failure| {
            try std.testing.expectEqual(@as(?u16, 502), failure.http_status);
            try std.testing.expectEqual(KustoErrorSource.http, failure.source);
            try std.testing.expectEqual(KustoOperationOutcome.known_not_accepted, failure.outcome);
            try std.testing.expect(failure.retryable);
            try std.testing.expect(failure.detail.code == null);
            try std.testing.expectEqual(@as(usize, 36), failure.client_request_id.?.len);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "KustoClient decodes V1 management responses" {
    const allocator = std.testing.allocator;
    const response_body =
        \\{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"DatabaseName","ColumnType":"string"},{"ColumnName":"Count","ColumnType":"long"}],"Rows":[["TestDB",42]]}]}
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );

    var dataset = try client.executeMgmt(allocator, "db", ".show databases", null);
    defer dataset.deinit(allocator);
    try std.testing.expect(std.mem.endsWith(u8, mock.last_url.?, "/v1/rest/mgmt"));
    const table = dataset.primaryTable().?;
    try std.testing.expectEqualStrings("TestDB", table.rows[0].getByName("DatabaseName").?.asString().?);
    try std.testing.expectEqual(@as(?i64, 42), table.rows[0].getByName("Count").?.asI64());
}

test "KustoClient preserves structured HTTP failures" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 400,
        \\{"error":{"code":"BadRequest","message":"Invalid query"}}
    );
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );

    var response_result = try client.executeQueryResult(allocator, "db", "bad", null);
    defer response_result.deinit(allocator);
    switch (response_result) {
        .err => |failure| {
            try std.testing.expectEqual(KustoErrorSource.http, failure.source);
            try std.testing.expectEqual(@as(?u16, 400), failure.http_status);
            try std.testing.expectEqualStrings("BadRequest", failure.detail.code.?);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "KustoClient returns completion failures with buffered V2 tables" {
    const allocator = std.testing.allocator;
    const response_body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"PrimaryResult","Columns":[{"ColumnName":"Value","ColumnType":"string"}],"Rows":[["before failure"]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":true,"Cancelled":false,"OneApiErrors":[{"error":{"code":"LimitsExceeded","message":"partial failure"}}]}
        \\]
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    mock.response_headers_list = &.{
        .{ .name = "x-ms-client-request-id", .value = "response-request" },
        .{ .name = "x-ms-activity-id", .value = "response-activity" },
    };
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );

    var response_result = try client.executeQueryResult(allocator, "db", "print 1", null);
    defer response_result.deinit(allocator);
    switch (response_result) {
        .partial => |partial| {
            try std.testing.expectEqual(KustoErrorSource.dataset_completion, partial.failure.source);
            try std.testing.expectEqualStrings("LimitsExceeded", partial.failure.detail.code.?);
            try std.testing.expectEqualStrings("response-request", partial.failure.client_request_id.?);
            try std.testing.expectEqualStrings("response-activity", partial.failure.activity_id.?);
            try std.testing.expectEqualStrings(
                "before failure",
                partial.value.primaryTable().?.rows[0].get(0).?.asString().?,
            );
        },
        else => return error.TestUnexpectedResult,
    }
}

test "KustoClient returns V1 exceptions as partial buffered results" {
    const allocator = std.testing.allocator;
    const response_body =
        \\{"Tables":[{"TableName":"Table_0","Columns":[{"ColumnName":"Value","ColumnType":"string"}],"Rows":[["before"],{"Exceptions":["partial V1 failure"]}]}]}
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );

    var response_result = try client.executeMgmtResult(allocator, "db", ".show tables", null);
    defer response_result.deinit(allocator);
    switch (response_result) {
        .partial => |partial| {
            try std.testing.expectEqual(KustoErrorSource.v1_exception, partial.failure.source);
            try std.testing.expectEqualStrings("partial V1 failure", partial.failure.detail.message.?);
            try std.testing.expectEqualStrings("before", partial.value.primaryTable().?.rows[0].get(0).?.asString().?);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "KustoClient honors varying-result-width request property" {
    const allocator = std.testing.allocator;
    const response_body =
        \\[
        \\ {"FrameType":"DataSetHeader","Version":"v2.0","IsProgressive":false},
        \\ {"FrameType":"DataTable","TableId":0,"TableKind":"PrimaryResult","TableName":"PrimaryResult","Columns":[{"ColumnName":"Value","ColumnType":"string"}],"Rows":[["one","extra"]]},
        \\ {"FrameType":"DataSetCompletion","HasErrors":false,"Cancelled":false}
        \\]
    ;
    var mock = core.http.MockTransport.init(allocator, 200, response_body);
    defer mock.deinit();
    var client = KustoClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
        .{},
    );
    var properties = ClientRequestProperties{};
    defer properties.deinit(allocator);
    try properties.setClientResultsReaderAllowVaryingRowWidths(allocator, true);

    var dataset = try client.executeQuery(allocator, "db", "print 1", properties);
    defer dataset.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), dataset.primaryTable().?.rows[0].values.len);
    try std.testing.expect(std.mem.indexOf(
        u8,
        mock.last_body.?,
        "\"client_results_reader_allow_varying_row_widths\":true",
    ) != null);
}

test {
    _ = @import("result.zig");
}
