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

// ─────────────────── Types ───────────────────────────

pub const IngestionResult = struct {
    status: IngestionStatus,
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
    connection: ConnectionProperties,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(connection: ConnectionProperties, transport: *core.http.HttpTransport) StreamingIngestClient {
        return .{
            .connection = connection,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    /// Ingest data from a byte slice.
    ///
    /// Returns `IngestionResult{ .status = .failed }` on any Azure-side
    /// error (and logs the error). Use `ingestFromSliceResult` to receive
    /// the structured `AzureError` instead.
    pub fn ingestFromSlice(self: *StreamingIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, data: []const u8, options: IngestOptions) !IngestionResult {
        var r = try self.ingestFromSliceResult(allocator, database, table, data, options);
        return switch (r) {
            .ok => |v| v,
            .err => blk: {
                std.log.warn("{f}", .{r.err});
                r.err.deinit();
                break :blk .{ .status = .failed };
            },
        };
    }

    /// Same as `ingestFromSlice` but exposes Azure-side failures as the
    /// `.err` variant of `Result` instead of collapsing them into
    /// `IngestionResult{ .status = .failed }`.
    pub fn ingestFromSliceResult(self: *StreamingIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, data: []const u8, options: IngestOptions) !core.errors.Result(IngestionResult) {
        const url = try self.buildIngestUrl(allocator, database, table, options);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Content-Encoding", "utf-8");
        try req.setHeader("x-ms-app", "azure-sdk-zig");
        req.body = data;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, resp)) |az_err| {
                return .{ .err = az_err };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = .{ .status = .success } };
    }

    fn buildIngestUrl(self: *StreamingIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, options: IngestOptions) ![]u8 {
        const encoded_database = try core.url.percentEncode(allocator, database);
        defer allocator.free(encoded_database);
        const encoded_table = try core.url.percentEncode(allocator, table);
        defer allocator.free(encoded_table);

        if (options.mapping_name) |mapping| {
            const encoded_mapping = try core.url.percentEncode(allocator, mapping);
            defer allocator.free(encoded_mapping);
            return std.fmt.allocPrint(allocator, "{s}/v1/rest/ingest/{s}/{s}?streamFormat={s}&mappingName={s}", .{
                self.connection.cluster_url, encoded_database, encoded_table, options.format.toString(), encoded_mapping,
            });
        }
        return std.fmt.allocPrint(allocator, "{s}/v1/rest/ingest/{s}/{s}?streamFormat={s}", .{
            self.connection.cluster_url, encoded_database, encoded_table, options.format.toString(),
        });
    }
};

// ─────────────── QueuedIngestClient ──────────────────

/// Queued ingestion is planned but not implemented.
pub const QueuedIngestClient = struct {
    connection: ConnectionProperties,
    pipeline: core.pipeline.HttpPipeline,
    dm_url: ?[]u8 = null,

    pub fn init(connection: ConnectionProperties, transport: *core.http.HttpTransport) QueuedIngestClient {
        return .{
            .connection = connection,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    pub fn ingestFromBlob(self: *QueuedIngestClient, allocator: std.mem.Allocator, properties: IngestionProperties, blob_url: []const u8) !IngestionResult {
        _ = self;
        _ = allocator;
        _ = properties;
        _ = blob_url;
        return error.QueuedIngestionNotImplemented;
    }

    pub fn ingestFromBlobResult(self: *QueuedIngestClient, allocator: std.mem.Allocator, properties: IngestionProperties, blob_url: []const u8) !core.errors.Result(IngestionResult) {
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

    /// Ingest data through direct streaming.
    ///
    /// Returns `error.ManagedIngestionFallbackNotImplemented` if streaming
    /// fails because queued fallback would be required.
    pub fn ingestFromSlice(self: *ManagedIngestClient, allocator: std.mem.Allocator, database: []const u8, table: []const u8, data: []const u8, options: IngestOptions) !IngestionResult {
        var streaming_result = try self.streaming.ingestFromSliceResult(allocator, database, table, data, options);
        return switch (streaming_result) {
            .ok => |result| result,
            .err => |*azure_error| {
                azure_error.deinit();
                return error.ManagedIngestionFallbackNotImplemented;
            },
        };
    }

    pub fn deinit(self: *ManagedIngestClient, allocator: std.mem.Allocator) void {
        self.queued.deinit(allocator);
    }
};

// ─────────────────────── Tests ───────────────────────

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
}

test "IngestionResult deinit through Result" {
    const allocator = std.testing.allocator;
    var result: core.errors.Result(IngestionResult) = .{ .ok = .{
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
