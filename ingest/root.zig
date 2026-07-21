///! Azure Kusto (Data Explorer) ingestion clients.
///!
///! Provides experimental direct streaming ingestion via
///! `StreamingIngestClient`. Queued ingestion and managed queued fallback
///! are represented by API placeholders that return explicit
///! not-implemented errors.
const std = @import("std");
const core = @import("azure_core");
const kusto_common = @import("azure_kusto_common");

pub const ConnectionProperties = kusto_common.ConnectionProperties;
pub const DataFormat = kusto_common.DataFormat;
pub const IngestionProperties = kusto_common.IngestionProperties;
pub const KustoConnection = kusto_common.KustoConnection;
pub const KustoConnectionOptions = kusto_common.KustoConnectionOptions;
pub const KustoMetadataMode = kusto_common.KustoMetadataMode;
pub const KustoCloudInfo = kusto_common.KustoCloudInfo;
pub const KustoCloudInfoCache = kusto_common.KustoCloudInfoCache;
pub const KustoRetryOptions = kusto_common.KustoRetryOptions;
pub const KustoError = kusto_common.KustoError;
pub const KustoErrorDetail = kusto_common.KustoErrorDetail;
pub const KustoOperation = kusto_common.KustoOperation;
pub const KustoErrorSource = kusto_common.KustoErrorSource;
pub const KustoOperationOutcome = kusto_common.KustoOperationOutcome;
pub const KustoResult = kusto_common.KustoResult;

// ─────────────────── Types ───────────────────────────

pub const IngestionResult = struct {
    status: IngestionStatus,
    outcome: KustoOperationOutcome = .accepted,
    /// Allocator-owned when non-null; call `deinit` to release it.
    ingestion_id: ?[]const u8 = null,

    pub fn deinit(self: *IngestionResult, allocator: std.mem.Allocator) void {
        if (self.ingestion_id) |id| allocator.free(id);
        self.ingestion_id = null;
    }
};

pub const IngestionStatus = enum {
    success,
    queued,
    failed,

    pub fn toString(self: IngestionStatus) []const u8 {
        return switch (self) {
            .success => "Success",
            .queued => "Queued",
            .failed => "Failed",
        };
    }
};

pub const IngestOptions = struct {
    format: DataFormat = .csv,
    mapping_name: ?[]const u8 = null,
    flush_immediately: bool = false,
};

// ─────────────── StreamingIngestClient ────────────────

/// Direct streaming ingestion via the engine endpoint.
///
/// Data is sent directly to the Kusto engine via `POST /v1/rest/ingest/{db}/{table}`.
/// Fast but limited to small payloads (<4MB). Queued ingestion for larger or
/// more reliable payloads is planned but not implemented.
pub const StreamingIngestClient = struct {
    runtime: Runtime,

    const Runtime = union(enum) {
        legacy: struct {
            connection: ConnectionProperties,
            pipeline: core.pipeline.HttpPipeline,
        },
        shared: *KustoConnection,
    };

    pub fn init(connection: ConnectionProperties, transport: *core.http.HttpTransport) StreamingIngestClient {
        return .{
            .runtime = .{ .legacy = .{
                .connection = connection,
                .pipeline = .{ .policies = &.{}, .transport_impl = transport },
            } },
        };
    }

    /// Creates a client borrowing `connection`.
    ///
    /// The connection must outlive this client and all copies of it. Shared
    /// clients are not thread-safe; serialize use of the client and connection.
    /// This client does not deinitialize the borrowed connection.
    pub fn initWithConnection(connection: *KustoConnection) StreamingIngestClient {
        return .{ .runtime = .{ .shared = connection } };
    }

    /// Ingest data from a byte slice.
    ///
    /// Returns `IngestionResult{ .status = .failed }` on any Azure-side
    /// error (and logs the error). Use `ingestFromSliceResult` to receive
    /// the structured Kusto failure and operation outcome instead.
    pub fn ingestFromSlice(self: *StreamingIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, data: []const u8, options: IngestOptions) !IngestionResult {
        var r = try self.ingestFromSliceResult(allocator, database, table, data, options);
        return switch (r) {
            .ok => |v| v,
            .partial => unreachable,
            .err => blk: {
                const outcome = r.err.outcome;
                std.log.warn("{f}", .{r.err});
                r.err.deinit();
                break :blk .{ .status = .failed, .outcome = outcome };
            },
        };
    }

    /// Same as `ingestFromSlice` but exposes Kusto-side failures as `.err`.
    /// A send failure after transport entry has `.outcome = .unknown`; a
    /// non-2xx response is known not to have been accepted.
    pub fn ingestFromSliceResult(self: *StreamingIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, data: []const u8, options: IngestOptions) !KustoResult(IngestionResult) {
        const url = try self.buildIngestUrl(allocator, database, table, options);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Content-Encoding", "utf-8");
        try req.setHeader("x-ms-app", "azure-sdk-zig");
        try core.pipeline.ensureRequestId(&req);
        req.body = data;
        req.retryable = false;

        var resp = self.send(&req) catch |err| {
            if (req.transport_started) {
                return .{ .err = try kusto_common.errors.transportUnknown(
                    allocator,
                    err,
                    req.getHeader("x-ms-client-request-id"),
                ) };
            }
            return err;
        };
        defer resp.deinit();

        if (!resp.isSuccess()) {
            var failure = try kusto_common.errors.fromHttpResponse(
                allocator,
                .streaming_ingest,
                &resp,
                .known_not_accepted,
            );
            errdefer failure.deinit();
            try kusto_common.errors.applyResponseCorrelation(
                &failure,
                &resp,
                req.getHeader("x-ms-client-request-id"),
            );
            return .{ .err = failure };
        }

        return .{ .ok = .{ .status = .success } };
    }

    fn buildIngestUrl(self: *StreamingIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, options: IngestOptions) ![]u8 {
        const encoded_database = try core.url.percentEncode(allocator, database);
        defer allocator.free(encoded_database);
        const encoded_table = try core.url.percentEncode(allocator, table);
        defer allocator.free(encoded_table);

        const cluster_url = switch (self.runtime) {
            .legacy => |legacy| legacy.connection.cluster_url,
            .shared => |connection| connection.engineUrl(),
        };

        if (options.mapping_name) |mapping| {
            const encoded_mapping = try core.url.percentEncode(allocator, mapping);
            defer allocator.free(encoded_mapping);
            return std.fmt.allocPrint(allocator, "{s}/v1/rest/ingest/{s}/{s}?streamFormat={s}&mappingName={s}", .{
                cluster_url, encoded_database, encoded_table, options.format.toString(), encoded_mapping,
            });
        }
        return std.fmt.allocPrint(allocator, "{s}/v1/rest/ingest/{s}/{s}?streamFormat={s}", .{
            cluster_url, encoded_database, encoded_table, options.format.toString(),
        });
    }

    fn send(self: *StreamingIngestClient, request: *core.http.Request) !core.http.Response {
        return switch (self.runtime) {
            .shared => |connection| connection.send(request),
            .legacy => |*legacy| {
                if (connectionHasAuthentication(legacy.connection)) {
                    return error.AuthenticatedConnectionRequired;
                }
                return legacy.pipeline.send(request);
            },
        };
    }
};

// ─────────────── QueuedIngestClient ──────────────────

/// Queued ingestion is planned but not implemented.
pub const QueuedIngestClient = struct {
    runtime: Runtime,
    dm_url: ?[]u8 = null,

    const Runtime = union(enum) {
        legacy: struct {
            connection: ConnectionProperties,
            pipeline: core.pipeline.HttpPipeline,
        },
        shared: *KustoConnection,
    };

    pub fn init(connection: ConnectionProperties, transport: *core.http.HttpTransport) QueuedIngestClient {
        return .{
            .runtime = .{ .legacy = .{
                .connection = connection,
                .pipeline = .{ .policies = &.{}, .transport_impl = transport },
            } },
        };
    }

    /// Creates a client borrowing `connection`.
    ///
    /// The connection must outlive this client and all copies of it. Shared
    /// clients are not thread-safe; serialize use of the client and connection.
    /// This client does not deinitialize the borrowed connection.
    pub fn initWithConnection(connection: *KustoConnection) QueuedIngestClient {
        return .{ .runtime = .{ .shared = connection } };
    }

    pub fn ingestFromBlob(self: *QueuedIngestClient, allocator: std.mem.Allocator, properties: IngestionProperties, blob_url: []const u8) !IngestionResult {
        _ = self;
        _ = allocator;
        _ = properties;
        _ = blob_url;
        return error.QueuedIngestionNotImplemented;
    }

    pub fn ingestFromBlobResult(self: *QueuedIngestClient, allocator: std.mem.Allocator, properties: IngestionProperties, blob_url: []const u8) !KustoResult(IngestionResult) {
        _ = self;
        _ = allocator;
        _ = properties;
        _ = blob_url;
        return error.QueuedIngestionNotImplemented;
    }

    pub fn deinit(self: *QueuedIngestClient, allocator: std.mem.Allocator) void {
        if (self.dm_url) |url| allocator.free(url);
    }
};

// ─────────────── ManagedIngestClient ─────────────────

/// Tries direct streaming ingestion; queued fallback is not implemented.
pub const ManagedIngestClient = struct {
    streaming: StreamingIngestClient,
    queued: QueuedIngestClient,

    pub fn init(connection: ConnectionProperties, transport: *core.http.HttpTransport) ManagedIngestClient {
        return .{
            .streaming = StreamingIngestClient.init(connection, transport),
            .queued = QueuedIngestClient.init(connection, transport),
        };
    }

    /// Creates a client whose streaming and queued clients borrow `connection`.
    ///
    /// The connection must outlive this client and all copies of it. Shared
    /// clients are not thread-safe; serialize use of the client and connection.
    /// This client does not deinitialize the borrowed connection.
    pub fn initWithConnection(connection: *KustoConnection) ManagedIngestClient {
        return .{
            .streaming = StreamingIngestClient.initWithConnection(connection),
            .queued = QueuedIngestClient.initWithConnection(connection),
        };
    }

    /// Ingest data through direct streaming.
    ///
    /// Returns `error.ManagedIngestionFallbackNotImplemented` if streaming
    /// fails because queued fallback would be required.
    pub fn ingestFromSlice(self: *ManagedIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, data: []const u8, options: IngestOptions) !IngestionResult {
        var result = try self.ingestFromSliceResult(allocator, database, table, data, options);
        return switch (result) {
            .ok => |ingestion| ingestion,
            .partial => unreachable,
            .err => |*failure| {
                const outcome = failure.outcome;
                failure.deinit();
                if (outcome == .unknown) return error.KustoIngestionOutcomeUnknown;
                return error.ManagedIngestionFallbackNotImplemented;
            },
        };
    }

    /// Structured managed-ingestion result. Until queued fallback is
    /// implemented, this preserves the direct-streaming failure and outcome.
    pub fn ingestFromSliceResult(self: *ManagedIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, data: []const u8, options: IngestOptions) !KustoResult(IngestionResult) {
        return self.streaming.ingestFromSliceResult(allocator, database, table, data, options);
    }

    pub fn deinit(self: *ManagedIngestClient, allocator: std.mem.Allocator) void {
        self.queued.deinit(allocator);
    }
};

fn connectionHasAuthentication(connection: ConnectionProperties) bool {
    return connection.credential != null or
        connection.application_client_id != null or
        connection.application_key != null or
        connection.authority_id != null;
}

// ─────────────────────── Tests ───────────────────────

const TransportFailure = struct {
    transport: core.http.HttpTransport = .{ .sendFn = &send },

    fn asTransport(self: *TransportFailure) *core.http.HttpTransport {
        return &self.transport;
    }

    fn send(_: *core.http.HttpTransport, _: *core.http.Request) anyerror!core.http.Response {
        return error.ConnectionResetByPeer;
    }
};

test "StreamingIngestClient ingestFromSlice" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" };
    var client = StreamingIngestClient.init(conn, mock.asTransport());

    const result = try client.ingestFromSlice(allocator, "TestDB", "Logs", "{\"ts\":\"2024-01-01\"}\n", .{ .format = .json });
    try std.testing.expectEqual(IngestionStatus.success, result.status);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v1/rest/ingest/TestDB/Logs") != null);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "streamFormat=Json") != null);
    try std.testing.expectEqual(false, mock.last_retryable.?);
}

test "StreamingIngestClient with mapping name" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = StreamingIngestClient.init(conn, mock.asTransport());

    const result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{
        .format = .csv,
        .mapping_name = "MyMapping",
    });
    try std.testing.expectEqual(IngestionStatus.success, result.status);
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "mappingName=MyMapping") != null);
}

test "shared StreamingIngestClient authenticates through KustoConnection" {
    const allocator = std.testing.allocator;
    var token_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"shared-token","expires_in":3600}
    );
    defer token_mock.deinit();
    var service_mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer service_mock.deinit();

    const identity = core.identity;
    var credential = identity.ClientSecretCredential.init(
        allocator,
        token_mock.asTransport(),
        "tenant",
        "client",
        "secret",
    );
    const properties = ConnectionProperties{
        .cluster_url = "https://cluster.kusto.windows.net",
        .credential = credential.asCredential(),
    };
    const connection = try KustoConnection.init(
        allocator,
        properties,
        service_mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer connection.deinit();

    var client = StreamingIngestClient.initWithConnection(connection);
    const result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    try std.testing.expectEqual(IngestionStatus.success, result.status);
    try std.testing.expect(token_mock.last_url != null);
    try std.testing.expect(service_mock.last_headers.get("Authorization") != null);
    try std.testing.expectEqual(false, service_mock.last_retryable.?);
}

test "shared StreamingIngestClient uses explicit engine endpoint" {
    const allocator = std.testing.allocator;
    var service_mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer service_mock.deinit();

    var credential = core.credentials.TokenCredential{ .getTokenFn = &successfulTokenRequest };
    const properties = ConnectionProperties{
        .cluster_url = "https://cluster.kusto.windows.net",
        .credential = &credential,
    };
    const connection = try KustoConnection.init(
        allocator,
        properties,
        service_mock.asTransport(),
        .{
            .metadata_mode = .disabled,
            .engine_endpoint = "https://streaming-engine.kusto.windows.net",
            .data_management_endpoint = "https://ingest-dm.kusto.windows.net",
        },
    );
    defer connection.deinit();

    var client = StreamingIngestClient.initWithConnection(connection);
    _ = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});

    try std.testing.expectEqualStrings(
        "https://streaming-engine.kusto.windows.net/v1/rest/ingest/DB/Table?streamFormat=Csv",
        service_mock.last_url.?,
    );
    try std.testing.expect(std.mem.find(u8, service_mock.last_url.?, "ingest-dm") == null);
}

test "shared StreamingIngestClient can be copied" {
    const allocator = std.testing.allocator;
    var service_mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer service_mock.deinit();

    var credential = core.credentials.TokenCredential{ .getTokenFn = &successfulTokenRequest };
    const properties = ConnectionProperties{
        .cluster_url = "https://cluster.kusto.windows.net",
        .credential = &credential,
    };
    const connection = try KustoConnection.init(
        allocator,
        properties,
        service_mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer connection.deinit();

    const original = StreamingIngestClient.initWithConnection(connection);
    var copied = original;
    _ = try copied.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    try std.testing.expect(service_mock.last_url != null);
}

test "ManagedIngestClient shared initialization composes borrowed clients" {
    const allocator = std.testing.allocator;
    var service_mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer service_mock.deinit();

    var credential = core.credentials.TokenCredential{ .getTokenFn = &successfulTokenRequest };
    const properties = ConnectionProperties{
        .cluster_url = "https://cluster.kusto.windows.net",
        .credential = &credential,
    };
    const connection = try KustoConnection.init(
        allocator,
        properties,
        service_mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer connection.deinit();

    var client = ManagedIngestClient.initWithConnection(connection);
    defer client.deinit(allocator);
    const result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    try std.testing.expectEqual(IngestionStatus.success, result.status);
    try std.testing.expect(service_mock.last_headers.get("Authorization") != null);
}

test "configured shared connection does not retry streaming writes" {
    const allocator = std.testing.allocator;
    var service_mock = core.http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 500, .body =
        \\{"error":{"code":"ServerError","message":"retry me"}}
        },
        .{ .status = 200, .body = "{}" },
    });

    var credential = core.credentials.TokenCredential{ .getTokenFn = &successfulTokenRequest };
    const properties = ConnectionProperties{
        .cluster_url = "https://cluster.kusto.windows.net",
        .credential = &credential,
    };
    const connection = try KustoConnection.init(
        allocator,
        properties,
        service_mock.asTransport(),
        .{ .metadata_mode = .disabled },
    );
    defer connection.deinit();

    var client = StreamingIngestClient.initWithConnection(connection);
    const result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    try std.testing.expectEqual(
        IngestionStatus.failed,
        result.status,
    );
    try std.testing.expectEqual(@as(usize, 1), service_mock.call_count);
}

test "StreamingIngestClient percent-encodes URL components independently" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = StreamingIngestClient.init(conn, mock.asTransport());

    _ = try client.ingestFromSlice(allocator, "DB /&?=+", "Table /&?=+", "data", .{
        .mapping_name = "Mapping /&?=+",
    });
    try std.testing.expectEqualStrings(
        "https://cluster.kusto.windows.net/v1/rest/ingest/DB%20%2F%26%3F%3D%2B/Table%20%2F%26%3F%3D%2B?streamFormat=Csv&mappingName=Mapping%20%2F%26%3F%3D%2B",
        mock.last_url.?,
    );
}

test "StreamingIngestClient failure" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 400,
        \\{"error":{"code":"BadRequest","message":"Invalid data"}}
    );
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = StreamingIngestClient.init(conn, mock.asTransport());

    const result = try client.ingestFromSlice(allocator, "DB", "Table", "bad", .{});
    try std.testing.expectEqual(IngestionStatus.failed, result.status);
    try std.testing.expectEqual(KustoOperationOutcome.known_not_accepted, result.outcome);
}

test "streaming non-2xx is known not accepted" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 400,
        \\{"error":{"code":"BadRequest","message":"Invalid data"}}
    );
    defer mock.deinit();
    var client = StreamingIngestClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        mock.asTransport(),
    );

    var result = try client.ingestFromSliceResult(allocator, "DB", "Table", "bad", .{});
    defer result.deinit(allocator);
    switch (result) {
        .err => |failure| {
            try std.testing.expectEqual(KustoOperationOutcome.known_not_accepted, failure.outcome);
            try std.testing.expect(!failure.retryable);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn unexpectedTokenRequest(
    _: *core.credentials.TokenCredential,
    _: core.credentials.TokenRequestContext,
    _: core.context.Context,
) anyerror!core.credentials.AccessToken {
    return error.UnexpectedTokenRequest;
}

fn successfulTokenRequest(
    _: *core.credentials.TokenCredential,
    _: core.credentials.TokenRequestContext,
    _: core.context.Context,
) anyerror!core.credentials.AccessToken {
    return .{
        .token = "shared-token",
        .expires_on = std.math.maxInt(i64),
    };
}

test "legacy authenticated StreamingIngestClient requires shared connection" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    var credential = core.credentials.TokenCredential{ .getTokenFn = &unexpectedTokenRequest };
    const conn = ConnectionProperties{
        .cluster_url = "https://cluster.kusto.windows.net",
        .credential = &credential,
    };
    var client = StreamingIngestClient.init(conn, mock.asTransport());

    try std.testing.expectError(
        error.AuthenticatedConnectionRequired,
        client.ingestFromSliceResult(allocator, "DB", "Table", "data", .{}),
    );
    try std.testing.expect(mock.last_url == null);
}

test "streaming transport failure has unknown outcome after transport entry" {
    const allocator = std.testing.allocator;
    var failing_transport = TransportFailure{};
    var client = StreamingIngestClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        failing_transport.asTransport(),
    );

    var result = try client.ingestFromSliceResult(allocator, "DB", "Table", "data", .{});
    defer result.deinit(allocator);
    switch (result) {
        .err => |failure| {
            try std.testing.expectEqual(KustoErrorSource.transport, failure.source);
            try std.testing.expectEqual(KustoOperationOutcome.unknown, failure.outcome);
            try std.testing.expectEqual(error.ConnectionResetByPeer, failure.transport_error.?);
            try std.testing.expectEqual(@as(usize, 36), failure.client_request_id.?.len);
            try std.testing.expect(!failure.retryable);
        },
        else => return error.TestUnexpectedResult,
    }
}

test "managed ingestion does not fall back after an unknown outcome" {
    const allocator = std.testing.allocator;
    var failing_transport = TransportFailure{};
    var client = ManagedIngestClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        failing_transport.asTransport(),
    );
    defer client.deinit(allocator);

    var result = try client.ingestFromSliceResult(allocator, "DB", "Table", "data", .{});
    defer result.deinit(allocator);
    switch (result) {
        .err => |failure| {
            try std.testing.expectEqual(KustoOperationOutcome.unknown, failure.outcome);
            try std.testing.expectEqual(error.ConnectionResetByPeer, failure.transport_error.?);
        },
        else => return error.TestUnexpectedResult,
    }

    try std.testing.expectError(
        error.KustoIngestionOutcomeUnknown,
        client.ingestFromSlice(allocator, "DB", "Table", "data", .{}),
    );
}

test "IngestionResult deinit through Result" {
    const allocator = std.testing.allocator;
    var result: KustoResult(IngestionResult) = .{ .ok = .{
        .status = .success,
        .ingestion_id = try allocator.dupe(u8, "ingestion-id"),
    } };
    defer result.deinit(allocator);

    try std.testing.expectEqualStrings("ingestion-id", result.ok.ingestion_id.?);
}

test "QueuedIngestClient does not send placeholder requests" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" };
    var client = QueuedIngestClient.init(conn, mock.asTransport());
    defer client.deinit(allocator);

    const properties = IngestionProperties{
        .database = "TestDB",
        .table = "Logs",
        .format = .json,
    };
    try std.testing.expectError(
        error.QueuedIngestionNotImplemented,
        client.ingestFromBlob(allocator, properties, "https://storage.blob.core.windows.net/container/blob.json"),
    );
    try std.testing.expect(mock.last_url == null);
    try std.testing.expectError(
        error.QueuedIngestionNotImplemented,
        client.ingestFromBlobResult(allocator, properties, "https://storage.blob.core.windows.net/container/blob.json"),
    );
    try std.testing.expect(mock.last_url == null);
}

test "ManagedIngestClient ingestFromSlice success" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = ManagedIngestClient.init(conn, mock.asTransport());
    defer client.deinit(allocator);

    const result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    try std.testing.expectEqual(IngestionStatus.success, result.status);
}

test "ManagedIngestClient does not attempt unimplemented queued fallback" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 400,
        \\{"error":{"code":"BadRequest","message":"Invalid data"}}
    );
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = ManagedIngestClient.init(conn, mock.asTransport());
    defer client.deinit(allocator);

    try std.testing.expectError(
        error.ManagedIngestionFallbackNotImplemented,
        client.ingestFromSlice(allocator, "DB", "Table", "bad", .{}),
    );
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v1/rest/ingest/DB/Table") != null);
}

test "IngestionStatus toString" {
    try std.testing.expectEqualStrings("Success", IngestionStatus.success.toString());
    try std.testing.expectEqualStrings("Queued", IngestionStatus.queued.toString());
    try std.testing.expectEqualStrings("Failed", IngestionStatus.failed.toString());
}
