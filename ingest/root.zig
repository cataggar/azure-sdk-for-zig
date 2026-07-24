///! Azure Kusto (Data Explorer) ingestion clients.
///!
///! Provides experimental direct streaming, queued, and managed ingestion.
const std = @import("std");
const core = @import("azure_sdk_core");
const kusto_common = @import("kusto_common_internal");
const streaming = @import("streaming.zig");
const resources = @import("resources.zig");
const queued = @import("queued.zig");
const managed = @import("managed.zig");

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

pub const max_streaming_payload_bytes = streaming.max_streaming_payload_bytes;
pub const StreamingIngestTarget = streaming.StreamingIngestTarget;
pub const RequestCompression = streaming.RequestCompression;
pub const ReplayReader = streaming.ReplayReader;
pub const ReplayReaderFactory = streaming.ReplayReaderFactory;
pub const BorrowedReaderSource = streaming.BorrowedReaderSource;
pub const BlobUriSource = streaming.BlobUriSource;
pub const SourceKind = streaming.SourceKind;
pub const StreamingIngestSource = streaming.StreamingIngestSource;
pub const ValidationPolicy = streaming.ValidationPolicy;
pub const IngestionReportLevel = streaming.IngestionReportLevel;
pub const IngestionReportMethod = streaming.IngestionReportMethod;
pub const QueuedCompression = streaming.QueuedCompression;
pub const StreamingRetryOptions = streaming.StreamingRetryOptions;
pub const IngestionResult = streaming.IngestionResult;
pub const IngestionStatus = streaming.IngestionStatus;
pub const IngestOptions = streaming.IngestOptions;
pub const StreamingIngestClient = streaming.StreamingIngestClient;
pub const JsonRows = streaming.JsonRows;
pub const ResourceService = resources.ResourceService;
pub const ResourceKind = resources.ResourceKind;
pub const StorageResource = resources.StorageResource;
pub const AuthorizationContext = resources.AuthorizationContext;
pub const IngestionResourceSnapshot = resources.IngestionResourceSnapshot;
pub const ResourceSnapshotLease = resources.ResourceSnapshotLease;
pub const ResourceSnapshotResult = resources.ResourceSnapshotResult;
pub const ResourceAttempt = resources.ResourceAttempt;
pub const ResourceSelection = resources.ResourceSelection;
pub const ResourceSelectionResult = resources.ResourceSelectionResult;
pub const ResourceCommandExecutor = resources.ResourceCommandExecutor;
pub const DataManagementCommandExecutor = resources.DataManagementCommandExecutor;
pub const ResourceManagerOptions = resources.ResourceManagerOptions;
pub const ResourceManager = resources.ResourceManager;
pub const TimeSource = resources.TimeSource;
pub const default_resource_database = resources.default_resource_database;
pub const QueuedSubmissionOutcome = queued.QueuedSubmissionOutcome;
pub const QueuedResourceOperation = queued.QueuedResourceOperation;
pub const QueuedResourceAttemptOutcome = queued.QueuedResourceAttemptOutcome;
pub const QueuedResourceAttempt = queued.QueuedResourceAttempt;
pub const QueuedIngestionResult = queued.QueuedIngestionResult;
pub const QueuedIngestionStatus = queued.QueuedIngestionStatus;
pub const IngestionFailureDisposition = queued.IngestionFailureDisposition;
pub const IngestionStatusResult = queued.IngestionStatusResult;
pub const StatusPollOptions = queued.StatusPollOptions;
pub const StatusPollOutcome = queued.StatusPollOutcome;
pub const StatusPollingStopped = queued.StatusPollingStopped;
pub const StatusPollingStopReason = queued.StatusPollingStopReason;
pub const StatusClock = queued.StatusClock;
pub const StatusSleeper = queued.StatusSleeper;
pub const StatusRandom = queued.StatusRandom;
pub const StatusTrackingHandle = queued.StatusTrackingHandle;

test {
    _ = @import("resources.zig");
}

// ─────────────── QueuedIngestClient ──────────────────

pub const QueuedIngestClient = queued.QueuedIngestClient;

// ─────────────── ManagedIngestClient ─────────────────

pub const ManagedIngestionRoute = managed.ManagedIngestionRoute;
pub const ManagedIngestionResult = managed.ManagedIngestionResult;
pub const ManagedIngestClient = managed.ManagedIngestClient;

// ─────────────────────── Tests ───────────────────────

const TransportFailure = struct {
    transport: core.http.HttpTransport = .{ .sendFn = &send, .openFn = &open },

    fn asTransport(self: *TransportFailure) *core.http.HttpTransport {
        return &self.transport;
    }

    fn send(_: *core.http.HttpTransport, _: *core.http.Request) anyerror!core.http.Response {
        return error.ConnectionResetByPeer;
    }

    fn open(
        _: *core.http.HttpTransport,
        _: *core.http.Request,
        _: core.http.OpenOptions,
    ) anyerror!*core.http.HttpOperation {
        return error.ConnectionResetByPeer;
    }
};

test "StreamingIngestClient ingestFromSlice" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://mycluster.eastus.kusto.windows.net" };
    var client = StreamingIngestClient.init(conn, mock.asTransport());

    var result = try client.ingestFromSlice(allocator, "TestDB", "Logs", "{\"ts\":\"2024-01-01\"}\n", .{
        .format = .json,
        .mapping_name = "LogsMapping",
    });
    defer result.deinit(allocator);
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

    var result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{
        .format = .csv,
        .mapping_name = "MyMapping",
    });
    defer result.deinit(allocator);
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
    var result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    defer result.deinit(allocator);
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
    var result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    defer result.deinit(allocator);

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
    var result = try copied.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    defer result.deinit(allocator);
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
    var result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    defer result.deinit(allocator);
    try std.testing.expectEqual(IngestionStatus.success, result.status);
    try std.testing.expect(service_mock.last_headers.get("Authorization") != null);
}

test "shared connection retries replayable streaming bytes outside generic pipeline" {
    const allocator = std.testing.allocator;
    var service_mock = core.http.MockTransport.init(allocator, 500,
        \\{"error":{"code":"ServerError","message":"retry me"}}
    );
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

    var client = StreamingIngestClient.initWithConnection(connection);
    const result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{
        .retry = .{ .initial_delay_ms = 0 },
    });
    try std.testing.expectEqual(
        IngestionStatus.failed,
        result.status,
    );
    try std.testing.expectEqual(@as(usize, 2), service_mock.call_count);
}

test "StreamingIngestClient percent-encodes URL components independently" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = StreamingIngestClient.init(conn, mock.asTransport());

    var result = try client.ingestFromSlice(allocator, "DB /&?=+", "Table /&?=+", "data", .{
        .mapping_name = "Mapping /&?=+",
    });
    defer result.deinit(allocator);
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

test "QueuedIngestClient requires a resource manager" {
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
        error.QueuedIngestionResourceManagerRequired,
        client.ingestFromBlob(allocator, properties, "https://storage.blob.core.windows.net/container/blob.json"),
    );
    try std.testing.expect(mock.last_url == null);
    try std.testing.expectError(
        error.QueuedIngestionResourceManagerRequired,
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

    var result = try client.ingestFromSlice(allocator, "DB", "Table", "data", .{});
    defer result.deinit(allocator);
    try std.testing.expectEqual(IngestionStatus.success, result.status);
}

test "ManagedIngestClient no longer returns unimplemented fallback" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 400,
        \\{"error":{"code":"BadRequest","message":"Invalid data"}}
    );
    defer mock.deinit();

    const conn = ConnectionProperties{ .cluster_url = "https://cluster.kusto.windows.net" };
    var client = ManagedIngestClient.init(conn, mock.asTransport());
    defer client.deinit(allocator);

    try std.testing.expectError(
        error.KustoIngestionFailed,
        client.ingestFromSlice(allocator, "DB", "Table", "bad", .{}),
    );
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "/v1/rest/ingest/DB/Table") != null);
}

test "IngestionStatus toString" {
    try std.testing.expectEqualStrings("Success", IngestionStatus.success.toString());
    try std.testing.expectEqualStrings("Queued", IngestionStatus.queued.toString());
    try std.testing.expectEqualStrings("Failed", IngestionStatus.failed.toString());
}
