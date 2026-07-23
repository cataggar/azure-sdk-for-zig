//! Table-backed Kusto queued-ingestion status tracking.
//!
//! This is intentionally a narrow complete-SAS Table adapter. It does not
//! accept credentials or a caller pipeline, so a Kusto bearer token cannot be
//! sent to Storage.
const std = @import("std");
const serde = @import("serde");
const core = @import("azure_sdk_core");
const storage_common = @import("azure_sdk_storage_common");

const sas = storage_common.sas;

pub const storage_api_version = "2024-11-04";
pub const max_status_entity_bytes = 1024 * 1024;

/// The owned state returned by the service status-table entity. `unknown`
/// preserves an unrecognized future wire value in `raw_status`.
pub const QueuedIngestionStatus = enum {
    pending,
    succeeded,
    failed,
    queued,
    skipped,
    partially_succeeded,
    unknown,

    pub fn isTerminal(self: QueuedIngestionStatus) bool {
        return self != .pending;
    }
};

/// Service-provided failure classification. `transient` and `exhausted`
/// describe failures for which a later ingestion retry can be useful.
pub const IngestionFailureDisposition = enum {
    unknown,
    permanent,
    transient,
    exhausted,

    pub fn isRetryable(self: IngestionFailureDisposition) bool {
        return self == .transient or self == .exhausted;
    }
};

/// An owned Kusto ingestion status decoded from one Azure Table entity.
pub const IngestionStatusResult = struct {
    status: QueuedIngestionStatus,
    /// Owned service wire value, including unknown future status strings.
    raw_status: ?[]u8 = null,
    ingestion_source_id: ?[]u8 = null,
    ingestion_source_path: ?[]u8 = null,
    operation_id: ?[]u8 = null,
    activity_id: ?[]u8 = null,
    database: ?[]u8 = null,
    table: ?[]u8 = null,
    updated_on: ?[]u8 = null,
    error_code: ?[]u8 = null,
    details: ?[]u8 = null,
    failure_status: ?[]u8 = null,
    failure_disposition: IngestionFailureDisposition = .unknown,
    originates_from_update_policy: ?bool = null,

    pub fn deinit(self: *IngestionStatusResult, allocator: std.mem.Allocator) void {
        freeOptional(allocator, &self.raw_status);
        freeOptional(allocator, &self.ingestion_source_id);
        freeOptional(allocator, &self.ingestion_source_path);
        freeOptional(allocator, &self.operation_id);
        freeOptional(allocator, &self.activity_id);
        freeOptional(allocator, &self.database);
        freeOptional(allocator, &self.table);
        freeOptional(allocator, &self.updated_on);
        freeOptional(allocator, &self.error_code);
        freeOptional(allocator, &self.details);
        freeOptional(allocator, &self.failure_status);
        self.* = undefined;
    }
};

pub const StatusPollingStopReason = enum {
    timeout,
    cancelled,
    permanent_storage_error,
    transient_storage_error,
    malformed_response,
};

/// A stopped poll is not an ingestion result: no terminal Kusto outcome was
/// observed. For received status-resource failures `http_status` is present.
pub const StatusPollingStopped = struct {
    reason: StatusPollingStopReason,
    http_status: ?u16 = null,
    cause: ?anyerror = null,
};

pub const StatusPollOutcome = union(enum) {
    status: IngestionStatusResult,
    stopped: StatusPollingStopped,

    pub fn deinit(self: *StatusPollOutcome, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .status => |*result| result.deinit(allocator),
            .stopped => {},
        }
        self.* = undefined;
    }
};

pub const StatusClock = struct {
    context: *anyopaque,
    now_ms_fn: *const fn (context: *anyopaque) i64,

    pub fn nowMs(self: StatusClock) i64 {
        return self.now_ms_fn(self.context);
    }
};

pub const StatusSleeper = struct {
    context: *anyopaque,
    sleep_ms_fn: *const fn (context: *anyopaque, milliseconds: u64) anyerror!void,

    pub fn sleepMs(self: StatusSleeper, milliseconds: u64) !void {
        return self.sleep_ms_fn(self.context, milliseconds);
    }
};

pub const StatusRandom = struct {
    context: *anyopaque,
    /// Return a value in `[0, upper_exclusive)`. Values outside that range are
    /// clamped by the caller so a test seam cannot produce unbounded jitter.
    below_fn: *const fn (context: *anyopaque, upper_exclusive: u64) u64,

    pub fn below(self: StatusRandom, upper_exclusive: u64) u64 {
        if (upper_exclusive == 0) return 0;
        return @min(self.below_fn(self.context, upper_exclusive), upper_exclusive - 1);
    }
};

/// Poll configuration. Clocks use a monotonic-style millisecond domain; the
/// defaults use Zig 0.16 `std.Io` awake time and sleep APIs.
pub const StatusPollOptions = struct {
    poll_interval_ms: u64 = 10_000,
    timeout_ms: u64 = 10 * 60 * 1_000,
    transient_retry_initial_delay_ms: u64 = 1_000,
    transient_retry_max_delay_ms: u64 = 60_000,
    max_transient_retries: u32 = 3,
    max_jitter_ms: u64 = 500,
    immediate_first: bool = true,
    cancellation: ?*const core.http.CancellationToken = null,
    clock: ?StatusClock = null,
    sleeper: ?StatusSleeper = null,
    random: ?StatusRandom = null,
};

/// A complete-SAS Azure Table client restricted to the entity operations
/// required by Kusto status tracking. The SAS query remains opaque and all
/// requests disable redirects and generic retries.
pub const SasStatusTableClient = struct {
    allocator: std.mem.Allocator,
    uri: sas.CompleteSasUri,
    transport: *core.http.HttpTransport,

    pub fn init(
        allocator: std.mem.Allocator,
        complete_table_sas_uri: []const u8,
        transport: *core.http.HttpTransport,
    ) !SasStatusTableClient {
        var uri = try sas.CompleteSasUri.init(allocator, complete_table_sas_uri);
        errdefer uri.deinit();
        if (!uri.hasAzureStorageServiceHost("table"))
            return error.UnexpectedTableSasHost;
        return .{ .allocator = allocator, .uri = uri, .transport = transport };
    }

    pub fn deinit(self: *SasStatusTableClient) void {
        self.uri.deinit();
        self.* = undefined;
    }

    pub fn format(self: SasStatusTableClient, writer: anytype) !void {
        try writer.print("SasStatusTableClient({f})", .{self.uri});
    }

    /// Writes the reference-compatible initial `Pending` entity before Queue
    /// submission. A 204 means Table Storage accepted that write; it says
    /// nothing about eventual Kusto ingestion.
    pub fn createInitialEntity(
        self: *SasStatusTableClient,
        partition_key: []const u8,
        row_key: []const u8,
        ingestion_source_id: []const u8,
        database: []const u8,
        table: []const u8,
        source_path_without_query: []const u8,
        updated_on: []const u8,
    ) !sas.RequestOutcome {
        const body = try serializeInitialEntity(
            self.allocator,
            partition_key,
            row_key,
            ingestion_source_id,
            database,
            table,
            source_path_without_query,
            updated_on,
        );
        defer self.allocator.free(body);
        var request = core.http.Request.init(self.allocator, .POST, self.uri.bytes);
        defer request.deinit();
        try request.setHeader("Content-Type", "application/json");
        try request.setHeader("Accept", "application/json;odata=nometadata");
        try request.setHeader("Prefer", "return-no-content");
        try request.setHeader("x-ms-version", storage_api_version);
        request.body = body;
        const outcome = try sas.send(self.transport, &request, null);
        return switch (outcome) {
            .accepted => |value| if (value.status_code == 204)
                outcome
            else
                .{ .rejected = .{ .status_code = value.status_code } },
            .rejected, .unknown => outcome,
        };
    }

    /// Reads one entity. This GET is idempotent, so callers may retry an
    /// `.unknown` transport outcome within their local polling budget.
    pub fn readEntity(
        self: *SasStatusTableClient,
        partition_key: []const u8,
        row_key: []const u8,
    ) !StatusTableReadOutcome {
        const url = try entityUrl(self.allocator, &self.uri, partition_key, row_key);
        defer self.allocator.free(url);
        var request = core.http.Request.init(self.allocator, .GET, url);
        defer request.deinit();
        try request.setHeader("Accept", "application/json;odata=nometadata");
        try request.setHeader("x-ms-version", storage_api_version);
        request.retryable = false;
        request.redirect_policy = .not_allowed;

        var pipeline = core.pipeline.HttpPipeline{
            .policies = &.{},
            .transport_impl = self.transport,
        };
        const operation = pipeline.open(&request, .{}) catch |err| {
            if (request.transport_started) return .{ .unknown = .{ .cause = err } };
            return err;
        };
        defer operation.deinit();
        const status_code = operation.status_code;
        if (status_code != 200) {
            _ = operation.finish() catch {};
            return .{ .rejected = .{ .status_code = status_code } };
        }

        const reader = operation.reader() catch unreachable;
        const body = reader.allocRemaining(
            self.allocator,
            .limited(max_status_entity_bytes),
        ) catch |err| {
            if (err == error.OutOfMemory) return err;
            if (err == error.StreamTooLong) {
                _ = operation.finish() catch {};
                return .malformed_response;
            }
            return .{ .unknown = .{ .cause = err } };
        };
        // EOF establishes the complete entity. A later connection-release
        // failure cannot make this idempotent read ambiguous.
        _ = operation.finish() catch {};
        return .{ .accepted = .{ .body = body } };
    }
};

pub const StatusTableReadOutcome = union(enum) {
    accepted: struct { body: []u8 },
    rejected: struct { status_code: u16 },
    unknown: struct { cause: anyerror },
    malformed_response,

    pub fn deinit(self: *StatusTableReadOutcome, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .accepted => |value| allocator.free(value.body),
            .rejected, .unknown, .malformed_response => {},
        }
        self.* = undefined;
    }
};

/// An owned, pollable reference to the entity pre-created for an accepted
/// queued submission. It borrows only `transport`; the manager and any Kusto
/// connection need not remain alive after submission, but the transport must.
/// It is single-owner and not safe for concurrent polling.
pub const StatusTrackingHandle = struct {
    allocator: std.mem.Allocator,
    table: SasStatusTableClient,
    partition_key: []u8,
    row_key: []u8,
    ingestion_source_id: []u8,
    database: []u8,
    target_table: []u8,

    pub fn init(
        allocator: std.mem.Allocator,
        complete_table_sas_uri: []const u8,
        transport: *core.http.HttpTransport,
        ingestion_source_id: []const u8,
        database: []const u8,
        target_table: []const u8,
    ) !StatusTrackingHandle {
        try validateTrackingKey(ingestion_source_id);
        var handle = StatusTrackingHandle{
            .allocator = allocator,
            .table = try SasStatusTableClient.init(allocator, complete_table_sas_uri, transport),
            .partition_key = &.{},
            .row_key = &.{},
            .ingestion_source_id = &.{},
            .database = &.{},
            .target_table = &.{},
        };
        errdefer handle.deinit();
        // Java's current implementation uses the source UUID for both keys;
        // Kusto's queue message must carry these exact same values.
        handle.partition_key = try allocator.dupe(u8, ingestion_source_id);
        handle.row_key = try allocator.dupe(u8, ingestion_source_id);
        handle.ingestion_source_id = try allocator.dupe(u8, ingestion_source_id);
        handle.database = try allocator.dupe(u8, database);
        handle.target_table = try allocator.dupe(u8, target_table);
        return handle;
    }

    pub fn deinit(self: *StatusTrackingHandle) void {
        self.table.deinit();
        self.allocator.free(self.partition_key);
        self.allocator.free(self.row_key);
        self.allocator.free(self.ingestion_source_id);
        self.allocator.free(self.database);
        self.allocator.free(self.target_table);
        self.* = undefined;
    }

    pub fn format(self: StatusTrackingHandle, writer: anytype) !void {
        try writer.print(
            "StatusTrackingHandle(table={f}, partition_key={s}, row_key={s})",
            .{ self.table, self.partition_key, self.row_key },
        );
    }

    /// Creates the initial reference entity. The caller must do this before
    /// sending the Queue message which contains `queueReference()`.
    pub fn createInitialEntity(
        self: *StatusTrackingHandle,
        source_path: []const u8,
        updated_on: []const u8,
    ) !sas.RequestOutcome {
        return self.table.createInitialEntity(
            self.partition_key,
            self.row_key,
            self.ingestion_source_id,
            self.database,
            self.target_table,
            withoutQuery(source_path),
            updated_on,
        );
    }

    pub fn queueReference(self: *const StatusTrackingHandle) StatusTableReference {
        return .{
            .table_connection_string = self.table.uri.bytes,
            .partition_key = self.partition_key,
            .row_key = self.row_key,
        };
    }

    /// Polls the service-issued Table resource. The handle never turns a
    /// status-table read success into ingestion success: only `Succeeded` in
    /// the decoded entity is terminal success.
    pub fn poll(
        self: *StatusTrackingHandle,
        allocator: std.mem.Allocator,
        options: StatusPollOptions,
    ) !StatusPollOutcome {
        try validatePollOptions(options);
        const started_at = pollNow(options);
        const deadline = saturatingAdd(started_at, options.timeout_ms);
        var delay_ms: u64 = if (options.immediate_first) 0 else options.poll_interval_ms;
        var transient_retries: u32 = 0;

        while (true) {
            if (isCancelled(options)) return .{ .stopped = .{ .reason = .cancelled } };
            if (pollNow(options) >= deadline) return .{ .stopped = .{ .reason = .timeout } };

            if (delay_ms != 0) {
                const now = pollNow(options);
                if (now >= deadline) return .{ .stopped = .{ .reason = .timeout } };
                const remaining: u64 = @intCast(deadline - now);
                if (delay_ms > remaining) return .{ .stopped = .{ .reason = .timeout } };
                try pollSleep(options, delay_ms);
                if (isCancelled(options)) return .{ .stopped = .{ .reason = .cancelled } };
                if (pollNow(options) >= deadline)
                    return .{ .stopped = .{ .reason = .timeout } };
            }

            var read = try self.table.readEntity(self.partition_key, self.row_key);
            defer read.deinit(self.table.allocator);
            if (isCancelled(options)) return .{ .stopped = .{ .reason = .cancelled } };
            if (pollNow(options) >= deadline)
                return .{ .stopped = .{ .reason = .timeout } };

            switch (read) {
                .accepted => |value| {
                    const decoded = decodeStatusEntity(allocator, value.body) catch |err| {
                        if (err == error.OutOfMemory) return err;
                        return .{ .stopped = .{ .reason = .malformed_response, .cause = err } };
                    };
                    transient_retries = 0;
                    if (decoded.status.isTerminal()) return .{ .status = decoded };
                    var pending = decoded;
                    pending.deinit(allocator);
                    delay_ms = options.poll_interval_ms;
                },
                .rejected => |value| {
                    if (!isTransientStorageStatus(value.status_code)) {
                        return .{ .stopped = .{
                            .reason = .permanent_storage_error,
                            .http_status = value.status_code,
                        } };
                    }
                    if (transient_retries >= options.max_transient_retries) {
                        return .{ .stopped = .{
                            .reason = .transient_storage_error,
                            .http_status = value.status_code,
                        } };
                    }
                    transient_retries += 1;
                    delay_ms = retryDelay(options, transient_retries);
                },
                .unknown => |value| {
                    // GET is idempotent: the server cannot ingest data because
                    // it only reads the pre-created entity, so retrying this
                    // ambiguous transport outcome is safe within the budget.
                    if (transient_retries >= options.max_transient_retries) {
                        return .{ .stopped = .{
                            .reason = .transient_storage_error,
                            .cause = value.cause,
                        } };
                    }
                    transient_retries += 1;
                    delay_ms = retryDelay(options, transient_retries);
                },
                .malformed_response => return .{ .stopped = .{
                    .reason = .malformed_response,
                } },
            }
        }
    }
};

/// Queue-wire reference shape used by Kusto's `IngestionStatusInTable`.
pub const StatusTableReference = struct {
    table_connection_string: []const u8,
    partition_key: []const u8,
    row_key: []const u8,
};

const InitialEntityWire = struct {
    PartitionKey: []const u8,
    RowKey: []const u8,
    Status: []const u8 = "Pending",
    @"IngestionSourceId@odata.type": []const u8 = "Edm.Guid",
    IngestionSourceId: []const u8,
    IngestionSourcePath: []const u8,
    Database: []const u8,
    Table: []const u8,
    @"UpdatedOn@odata.type": []const u8 = "Edm.DateTime",
    UpdatedOn: []const u8,
};

const StatusEntityWire = struct {
    Status: ?[]const u8 = null,
    IngestionSourceId: ?[]const u8 = null,
    IngestionSourcePath: ?[]const u8 = null,
    OperationId: ?[]const u8 = null,
    ActivityId: ?[]const u8 = null,
    Database: ?[]const u8 = null,
    Table: ?[]const u8 = null,
    UpdatedOn: ?[]const u8 = null,
    ErrorCode: ?[]const u8 = null,
    FailureStatus: ?[]const u8 = null,
    Details: ?[]const u8 = null,
    OriginatesFromUpdatePolicy: ?bool = null,
};

fn serializeInitialEntity(
    allocator: std.mem.Allocator,
    partition_key: []const u8,
    row_key: []const u8,
    ingestion_source_id: []const u8,
    database: []const u8,
    table: []const u8,
    source_path_without_query: []const u8,
    updated_on: []const u8,
) ![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const bytes = serde.json.toSlice(arena.allocator(), InitialEntityWire{
        .PartitionKey = partition_key,
        .RowKey = row_key,
        .IngestionSourceId = ingestion_source_id,
        .IngestionSourcePath = source_path_without_query,
        .Database = database,
        .Table = table,
        .UpdatedOn = updated_on,
    }) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => return err,
    };
    return allocator.dupe(u8, bytes);
}

fn decodeStatusEntity(allocator: std.mem.Allocator, bytes: []const u8) !IngestionStatusResult {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const wire = serde.json.fromSlice(StatusEntityWire, arena.allocator(), bytes) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.MalformedIngestionStatusEntity,
    };
    const status_string = wire.Status orelse return error.MalformedIngestionStatusEntity;
    var result = IngestionStatusResult{
        .status = statusFromWire(status_string),
        .failure_disposition = failureDisposition(wire.FailureStatus),
        .originates_from_update_policy = wire.OriginatesFromUpdatePolicy,
    };
    errdefer result.deinit(allocator);
    result.raw_status = try allocator.dupe(u8, status_string);
    result.ingestion_source_id = try cloneOptional(allocator, wire.IngestionSourceId);
    result.ingestion_source_path = if (wire.IngestionSourcePath) |value|
        try allocator.dupe(u8, withoutQuery(value))
    else
        null;
    result.operation_id = try cloneOptional(allocator, wire.OperationId);
    result.activity_id = try cloneOptional(allocator, wire.ActivityId);
    result.database = try cloneOptional(allocator, wire.Database);
    result.table = try cloneOptional(allocator, wire.Table);
    result.updated_on = try cloneOptional(allocator, wire.UpdatedOn);
    result.error_code = try cloneOptional(allocator, wire.ErrorCode);
    result.details = try cloneOptional(allocator, wire.Details);
    result.failure_status = try cloneOptional(allocator, wire.FailureStatus);
    return result;
}

fn cloneOptional(allocator: std.mem.Allocator, value: ?[]const u8) !?[]u8 {
    return if (value) |bytes| try allocator.dupe(u8, bytes) else null;
}

fn freeOptional(allocator: std.mem.Allocator, value: *?[]u8) void {
    if (value.*) |bytes| allocator.free(bytes);
    value.* = null;
}

fn statusFromWire(value: []const u8) QueuedIngestionStatus {
    if (std.ascii.eqlIgnoreCase(value, "Pending")) return .pending;
    if (std.ascii.eqlIgnoreCase(value, "Succeeded")) return .succeeded;
    if (std.ascii.eqlIgnoreCase(value, "Failed")) return .failed;
    if (std.ascii.eqlIgnoreCase(value, "Queued")) return .queued;
    if (std.ascii.eqlIgnoreCase(value, "Skipped")) return .skipped;
    if (std.ascii.eqlIgnoreCase(value, "PartiallySucceeded")) return .partially_succeeded;
    return .unknown;
}

fn failureDisposition(value: ?[]const u8) IngestionFailureDisposition {
    const string = value orelse return .unknown;
    if (std.ascii.eqlIgnoreCase(string, "Permanent")) return .permanent;
    if (std.ascii.eqlIgnoreCase(string, "Transient")) return .transient;
    if (std.ascii.eqlIgnoreCase(string, "Exhausted")) return .exhausted;
    return .unknown;
}

fn entityUrl(
    allocator: std.mem.Allocator,
    uri: *const sas.CompleteSasUri,
    partition_key: []const u8,
    row_key: []const u8,
) ![]u8 {
    try validateTrackingKey(partition_key);
    try validateTrackingKey(row_key);
    var path_end = uri.query_start;
    while (path_end > 0 and uri.bytes[path_end - 1] == '/') path_end -= 1;
    return std.fmt.allocPrint(
        allocator,
        "{s}(PartitionKey='{s}',RowKey='{s}'){s}",
        .{ uri.bytes[0..path_end], partition_key, row_key, uri.bytes[uri.query_start..] },
    );
}

fn validateTrackingKey(value: []const u8) !void {
    if (value.len != 36) return error.InvalidStatusTrackingKey;
    for (value, 0..) |byte, index| {
        if (index == 8 or index == 13 or index == 18 or index == 23) {
            if (byte != '-') return error.InvalidStatusTrackingKey;
        } else if (!std.ascii.isHex(byte)) return error.InvalidStatusTrackingKey;
    }
}

fn withoutQuery(uri: []const u8) []const u8 {
    const end = std.mem.indexOfAny(u8, uri, "?;#") orelse uri.len;
    return uri[0..end];
}

fn validatePollOptions(options: StatusPollOptions) !void {
    if (options.poll_interval_ms == 0) return error.InvalidStatusPollInterval;
    if (options.timeout_ms == 0) return error.InvalidStatusPollTimeout;
    if (options.max_jitter_ms == std.math.maxInt(u64))
        return error.InvalidStatusPollJitter;
    if (options.transient_retry_max_delay_ms < options.transient_retry_initial_delay_ms)
        return error.InvalidStatusPollRetryDelay;
}

fn pollNow(options: StatusPollOptions) i64 {
    if (options.clock) |clock| return clock.nowMs();
    var threaded: std.Io.Threaded = .init_single_threaded;
    const nanoseconds = std.Io.Timestamp.now(threaded.io(), .awake).toNanoseconds();
    const milliseconds = @divFloor(nanoseconds, std.time.ns_per_ms);
    return std.math.cast(i64, milliseconds) orelse
        if (milliseconds < 0) std.math.minInt(i64) else std.math.maxInt(i64);
}

fn pollSleep(options: StatusPollOptions, milliseconds: u64) !void {
    if (options.sleeper) |sleeper| return sleeper.sleepMs(milliseconds);
    var threaded: std.Io.Threaded = .init_single_threaded;
    const signed_milliseconds = std.math.cast(i64, milliseconds) orelse std.math.maxInt(i64);
    try std.Io.sleep(threaded.io(), .fromMilliseconds(signed_milliseconds), .awake);
}

fn isCancelled(options: StatusPollOptions) bool {
    return if (options.cancellation) |token| token.isCancelled() else false;
}

fn saturatingAdd(base: i64, milliseconds: u64) i64 {
    const value = std.math.cast(i64, milliseconds) orelse return std.math.maxInt(i64);
    return std.math.add(i64, base, value) catch std.math.maxInt(i64);
}

fn retryDelay(options: StatusPollOptions, retry: u32) u64 {
    var delay = options.transient_retry_initial_delay_ms;
    var exponent: u32 = 1;
    while (exponent < retry) : (exponent += 1) {
        delay = std.math.mul(u64, delay, 2) catch options.transient_retry_max_delay_ms;
        if (delay >= options.transient_retry_max_delay_ms) {
            delay = options.transient_retry_max_delay_ms;
            break;
        }
    }
    const jitter = if (options.max_jitter_ms == 0)
        0
    else if (options.random) |random|
        random.below(options.max_jitter_ms + 1)
    else blk: {
        var threaded: std.Io.Threaded = .init_single_threaded;
        var seed: [std.Random.DefaultCsprng.secret_seed_length]u8 = undefined;
        threaded.io().randomSecure(&seed) catch break :blk 0;
        var random = std.Random.DefaultCsprng.init(seed);
        break :blk random.random().uintLessThan(u64, options.max_jitter_ms + 1);
    };
    return std.math.add(u64, delay, jitter) catch std.math.maxInt(u64);
}

fn isTransientStorageStatus(status_code: u16) bool {
    return status_code == 404 or status_code == 408 or status_code == 429 or
        status_code == 500 or status_code == 502 or status_code == 503 or status_code == 504;
}

test "status table initial entity uses opaque SAS without authorization" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 204, "");
    defer transport.deinit();
    var handle = try StatusTrackingHandle.init(
        allocator,
        "https://account.table.core.windows.net/status?sig=a%2Bb%3D&sp=raud",
        transport.asTransport(),
        "11111111-1111-4111-8111-111111111111",
        "DB",
        "Table",
    );
    defer handle.deinit();
    const outcome = try handle.createInitialEntity(
        "https://account.blob.core.windows.net/container/blob?sig=secret",
        "2026-07-21T11:13:42.817Z",
    );
    try std.testing.expect(outcome.isAccepted());
    try std.testing.expectEqual(core.http.Method.POST, transport.last_method.?);
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/status?sig=a%2Bb%3D&sp=raud",
        transport.last_url.?,
    );
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
    try std.testing.expectEqualStrings(
        "return-no-content",
        transport.last_headers.get("Prefer").?,
    );
    try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, transport.last_redirect_policy.?);
    try std.testing.expect(std.mem.indexOf(u8, transport.last_body.?, "\"PartitionKey\":\"11111111-1111-4111-8111-111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, transport.last_body.?, "\"RowKey\":\"11111111-1111-4111-8111-111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, transport.last_body.?, "\"Status\":\"Pending\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, transport.last_body.?, "\"IngestionSourceId@odata.type\":\"Edm.Guid\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, transport.last_body.?, "\"UpdatedOn@odata.type\":\"Edm.DateTime\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, transport.last_body.?, "sig=secret") == null);
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try writer.print("{f}", .{handle});
    try std.testing.expect(std.mem.indexOf(u8, buffer[0..writer.end], "a%2Bb%3D") == null);
}

test "status table reads encode reference keys without authorization" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{\"Status\":\"Succeeded\"}");
    defer transport.deinit();
    var client = try SasStatusTableClient.init(
        allocator,
        "https://account.table.core.windows.net/status?sig=a%2Bb%3D&sp=r",
        transport.asTransport(),
    );
    defer client.deinit();
    var outcome = try client.readEntity(
        "11111111-1111-4111-8111-111111111111",
        "11111111-1111-4111-8111-111111111111",
    );
    defer outcome.deinit(allocator);
    switch (outcome) {
        .accepted => |value| try std.testing.expectEqualStrings("{\"Status\":\"Succeeded\"}", value.body),
        .rejected, .unknown, .malformed_response => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(core.http.Method.GET, transport.last_method.?);
    try std.testing.expectEqualStrings(
        "https://account.table.core.windows.net/status(PartitionKey='11111111-1111-4111-8111-111111111111',RowKey='11111111-1111-4111-8111-111111111111')?sig=a%2Bb%3D&sp=r",
        transport.last_url.?,
    );
    try std.testing.expect(transport.last_headers.get("Authorization") == null);
    try std.testing.expectEqual(core.http.RedirectPolicy.not_allowed, transport.last_redirect_policy.?);
}

test "oversized status entities stop as malformed without retry classification" {
    const allocator = std.testing.allocator;
    const oversized = try allocator.alloc(u8, max_status_entity_bytes + 1);
    defer allocator.free(oversized);
    @memset(oversized, 'x');
    var transport = core.http.MockTransport.init(allocator, 200, oversized);
    defer transport.deinit();
    var client = try SasStatusTableClient.init(
        allocator,
        "https://account.table.core.windows.net/status?sig=opaque",
        transport.asTransport(),
    );
    defer client.deinit();

    var outcome = try client.readEntity(
        "11111111-1111-4111-8111-111111111111",
        "11111111-1111-4111-8111-111111111111",
    );
    defer outcome.deinit(allocator);
    switch (outcome) {
        .malformed_response => {},
        .accepted, .rejected, .unknown => return error.TestUnexpectedResult,
    }
}

test "status setup strips query and account-key credentials from source paths" {
    const allocator = std.testing.allocator;
    const entity = try serializeInitialEntity(
        allocator,
        "11111111-1111-4111-8111-111111111111",
        "11111111-1111-4111-8111-111111111111",
        "11111111-1111-4111-8111-111111111111",
        "DB",
        "T",
        withoutQuery(
            "https://account.blob.core.windows.net/c/b;AccountKey=secret?sig=also-secret",
        ),
        "2026-07-21T11:13:42.817Z",
    );
    defer allocator.free(entity);
    try std.testing.expect(std.mem.indexOf(u8, entity, "AccountKey") == null);
    try std.testing.expect(std.mem.indexOf(u8, entity, "also-secret") == null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        entity,
        "\"IngestionSourcePath\":\"https://account.blob.core.windows.net/c/b\"",
    ) != null);
}

test "status entity decoding preserves terminal details and future states" {
    const allocator = std.testing.allocator;
    var failed = try decodeStatusEntity(allocator,
        \\{"Status":"Failed","IngestionSourceId":"id","IngestionSourcePath":"https://account.blob.core.windows.net/c/b;AccountKey=secret","OperationId":"op","ActivityId":"activity","Database":"DB","Table":"T","UpdatedOn":"2026-07-21T11:13:42.817Z","ErrorCode":"BadInput","FailureStatus":"Permanent","Details":"invalid row","OriginatesFromUpdatePolicy":true}
    );
    defer failed.deinit(allocator);
    try std.testing.expectEqual(QueuedIngestionStatus.failed, failed.status);
    try std.testing.expectEqual(IngestionFailureDisposition.permanent, failed.failure_disposition);
    try std.testing.expect(!failed.failure_disposition.isRetryable());
    try std.testing.expectEqualStrings(
        "https://account.blob.core.windows.net/c/b",
        failed.ingestion_source_path.?,
    );
    try std.testing.expectEqualStrings("op", failed.operation_id.?);
    try std.testing.expectEqualStrings("invalid row", failed.details.?);

    var partial = try decodeStatusEntity(allocator, "{\"Status\":\"PartiallySucceeded\"}");
    defer partial.deinit(allocator);
    try std.testing.expectEqual(QueuedIngestionStatus.partially_succeeded, partial.status);

    var future = try decodeStatusEntity(allocator, "{\"Status\":\"FutureStatus\"}");
    defer future.deinit(allocator);
    try std.testing.expectEqual(QueuedIngestionStatus.unknown, future.status);
    try std.testing.expectEqualStrings("FutureStatus", future.raw_status.?);
}

test "status tracking rejects unsafe SAS and status keys" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    try std.testing.expectError(
        error.UnexpectedTableSasHost,
        StatusTrackingHandle.init(
            allocator,
            "https://account.queue.core.windows.net/status?sig=x",
            transport.asTransport(),
            "11111111-1111-4111-8111-111111111111",
            "DB",
            "T",
        ),
    );
    try std.testing.expectError(
        error.InvalidStatusTrackingKey,
        StatusTrackingHandle.init(
            allocator,
            "https://account.table.core.windows.net/status?sig=x",
            transport.asTransport(),
            "not-a-status-key",
            "DB",
            "T",
        ),
    );
}

const StatusPollTransport = struct {
    const Step = union(enum) {
        response: struct { status_code: u16, body: []const u8 },
        unknown,
    };

    allocator: std.mem.Allocator,
    steps: []const Step,
    call_count: usize = 0,
    seams: ?*PollSeams = null,
    advance_on_send_ms: u64 = 0,
    cancel_on_send: bool = false,
    transport: core.http.HttpTransport = .{ .sendFn = &send },

    fn asTransport(self: *StatusPollTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn send(
        transport: *core.http.HttpTransport,
        _: *core.http.Request,
    ) !core.http.Response {
        const self: *StatusPollTransport = @alignCast(@fieldParentPtr("transport", transport));
        const index = @min(self.call_count, self.steps.len - 1);
        self.call_count += 1;
        if (self.seams) |seams| {
            seams.now_ms = saturatingAdd(seams.now_ms, self.advance_on_send_ms);
            if (self.cancel_on_send) {
                if (seams.cancellation) |token| token.cancel();
            }
        }
        return switch (self.steps[index]) {
            .unknown => error.ConnectionResetByPeer,
            .response => |response| .{
                .status_code = response.status_code,
                .headers = std.StringHashMap([]const u8).init(self.allocator),
                .body = try self.allocator.dupe(u8, response.body),
                .allocator = self.allocator,
            },
        };
    }
};

const PollSeams = struct {
    now_ms: i64 = 0,
    sleep_calls: std.ArrayList(u64) = .empty,
    cancellation: ?*core.http.CancellationToken = null,
    cancel_on_sleep: bool = false,
    clock_calls: usize = 0,
    timeout_on_second_clock: bool = false,

    fn deinit(self: *PollSeams, allocator: std.mem.Allocator) void {
        self.sleep_calls.deinit(allocator);
    }

    fn now(context: *anyopaque) i64 {
        const self: *PollSeams = @ptrCast(@alignCast(context));
        self.clock_calls += 1;
        if (self.timeout_on_second_clock and self.clock_calls >= 2)
            return self.now_ms + 1;
        return self.now_ms;
    }

    fn sleep(context: *anyopaque, milliseconds: u64) !void {
        const self: *PollSeams = @ptrCast(@alignCast(context));
        try self.sleep_calls.append(std.testing.allocator, milliseconds);
        self.now_ms = saturatingAdd(self.now_ms, milliseconds);
        if (self.cancel_on_sleep) {
            if (self.cancellation) |token| token.cancel();
        }
    }

    fn random(_: *anyopaque, upper_exclusive: u64) u64 {
        return if (upper_exclusive > 2) 2 else 0;
    }

    fn options(self: *PollSeams) StatusPollOptions {
        return .{
            .poll_interval_ms = 10,
            .timeout_ms = 100,
            .transient_retry_initial_delay_ms = 5,
            .transient_retry_max_delay_ms = 20,
            .max_transient_retries = 2,
            .max_jitter_ms = 3,
            .clock = .{ .context = self, .now_ms_fn = &now },
            .sleeper = .{ .context = self, .sleep_ms_fn = &sleep },
            .random = .{ .context = self, .below_fn = &random },
        };
    }
};

fn testTrackingHandle(
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
) !StatusTrackingHandle {
    return StatusTrackingHandle.init(
        allocator,
        "https://account.table.core.windows.net/status?sig=opaque",
        transport,
        "11111111-1111-4111-8111-111111111111",
        "DB",
        "Table",
    );
}

test "status polling retries pending and transient reads with bounded jitter" {
    const allocator = std.testing.allocator;
    const steps = [_]StatusPollTransport.Step{
        .{ .response = .{ .status_code = 200, .body = "{\"Status\":\"Pending\"}" } },
        .{ .response = .{ .status_code = 503, .body = "busy" } },
        .{ .response = .{ .status_code = 200, .body = "{\"Status\":\"Succeeded\",\"OperationId\":\"op\"}" } },
    };
    var transport = StatusPollTransport{ .allocator = allocator, .steps = &steps };
    var tracking = try testTrackingHandle(allocator, transport.asTransport());
    defer tracking.deinit();
    var seams = PollSeams{};
    defer seams.deinit(allocator);

    var outcome = try tracking.poll(allocator, seams.options());
    defer outcome.deinit(allocator);
    switch (outcome) {
        .status => |value| {
            try std.testing.expectEqual(QueuedIngestionStatus.succeeded, value.status);
            try std.testing.expectEqualStrings("op", value.operation_id.?);
        },
        .stopped => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expectEqualSlices(u64, &.{ 10, 7 }, seams.sleep_calls.items);
}

test "status polling retries idempotent transport ambiguity" {
    const allocator = std.testing.allocator;
    const steps = [_]StatusPollTransport.Step{
        .unknown,
        .{ .response = .{ .status_code = 200, .body = "{\"Status\":\"Failed\",\"FailureStatus\":\"Transient\"}" } },
    };
    var transport = StatusPollTransport{ .allocator = allocator, .steps = &steps };
    var tracking = try testTrackingHandle(allocator, transport.asTransport());
    defer tracking.deinit();
    var seams = PollSeams{};
    defer seams.deinit(allocator);

    var outcome = try tracking.poll(allocator, seams.options());
    defer outcome.deinit(allocator);
    switch (outcome) {
        .status => |value| {
            try std.testing.expectEqual(QueuedIngestionStatus.failed, value.status);
            try std.testing.expect(value.failure_disposition.isRetryable());
        },
        .stopped => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expectEqualSlices(u64, &.{7}, seams.sleep_calls.items);
}

test "status polling stops on permanent auth and malformed table responses" {
    const allocator = std.testing.allocator;
    {
        const steps = [_]StatusPollTransport.Step{
            .{ .response = .{ .status_code = 403, .body = "denied" } },
        };
        var transport = StatusPollTransport{ .allocator = allocator, .steps = &steps };
        var tracking = try testTrackingHandle(allocator, transport.asTransport());
        defer tracking.deinit();
        var seams = PollSeams{};
        defer seams.deinit(allocator);
        var outcome = try tracking.poll(allocator, seams.options());
        defer outcome.deinit(allocator);
        switch (outcome) {
            .stopped => |value| {
                try std.testing.expectEqual(StatusPollingStopReason.permanent_storage_error, value.reason);
                try std.testing.expectEqual(@as(?u16, 403), value.http_status);
            },
            .status => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    }
    {
        const steps = [_]StatusPollTransport.Step{
            .{ .response = .{ .status_code = 200, .body = "{\"Status\":" } },
        };
        var transport = StatusPollTransport{ .allocator = allocator, .steps = &steps };
        var tracking = try testTrackingHandle(allocator, transport.asTransport());
        defer tracking.deinit();
        var seams = PollSeams{};
        defer seams.deinit(allocator);
        var outcome = try tracking.poll(allocator, seams.options());
        defer outcome.deinit(allocator);
        switch (outcome) {
            .stopped => |value| try std.testing.expectEqual(
                StatusPollingStopReason.malformed_response,
                value.reason,
            ),
            .status => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    }
}

test "status polling does not request or sleep after timeout or cancellation" {
    const allocator = std.testing.allocator;
    const steps = [_]StatusPollTransport.Step{
        .{ .response = .{ .status_code = 200, .body = "{\"Status\":\"Succeeded\"}" } },
    };
    {
        var transport = StatusPollTransport{ .allocator = allocator, .steps = &steps };
        var tracking = try testTrackingHandle(allocator, transport.asTransport());
        defer tracking.deinit();
        var seams = PollSeams{ .timeout_on_second_clock = true };
        defer seams.deinit(allocator);
        var options = seams.options();
        options.timeout_ms = 1;
        var outcome = try tracking.poll(allocator, options);
        defer outcome.deinit(allocator);
        switch (outcome) {
            .stopped => |value| try std.testing.expectEqual(StatusPollingStopReason.timeout, value.reason),
            .status => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 0), transport.call_count);
        try std.testing.expectEqual(@as(usize, 0), seams.sleep_calls.items.len);
    }
    {
        var transport = StatusPollTransport{ .allocator = allocator, .steps = &steps };
        var tracking = try testTrackingHandle(allocator, transport.asTransport());
        defer tracking.deinit();
        var seams = PollSeams{};
        defer seams.deinit(allocator);
        var options = seams.options();
        options.immediate_first = false;
        options.timeout_ms = 5;
        var outcome = try tracking.poll(allocator, options);
        defer outcome.deinit(allocator);
        switch (outcome) {
            .stopped => |value| try std.testing.expectEqual(StatusPollingStopReason.timeout, value.reason),
            .status => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 0), transport.call_count);
        try std.testing.expectEqual(@as(usize, 0), seams.sleep_calls.items.len);
    }
    {
        var transport = StatusPollTransport{ .allocator = allocator, .steps = &steps };
        var tracking = try testTrackingHandle(allocator, transport.asTransport());
        defer tracking.deinit();
        var cancellation = core.http.CancellationToken{};
        cancellation.cancel();
        var seams = PollSeams{};
        defer seams.deinit(allocator);
        var options = seams.options();
        options.cancellation = &cancellation;
        var outcome = try tracking.poll(allocator, options);
        defer outcome.deinit(allocator);
        switch (outcome) {
            .stopped => |value| try std.testing.expectEqual(StatusPollingStopReason.cancelled, value.reason),
            .status => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 0), transport.call_count);
    }
    {
        var transport = StatusPollTransport{ .allocator = allocator, .steps = &steps };
        var tracking = try testTrackingHandle(allocator, transport.asTransport());
        defer tracking.deinit();
        var cancellation = core.http.CancellationToken{};
        var seams = PollSeams{ .cancellation = &cancellation, .cancel_on_sleep = true };
        defer seams.deinit(allocator);
        var options = seams.options();
        options.immediate_first = false;
        options.cancellation = &cancellation;
        var outcome = try tracking.poll(allocator, options);
        defer outcome.deinit(allocator);
        switch (outcome) {
            .stopped => |value| try std.testing.expectEqual(StatusPollingStopReason.cancelled, value.reason),
            .status => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 0), transport.call_count);
        try std.testing.expectEqualSlices(u64, &.{10}, seams.sleep_calls.items);
    }
    {
        var cancellation = core.http.CancellationToken{};
        var seams = PollSeams{ .cancellation = &cancellation };
        defer seams.deinit(allocator);
        var transport = StatusPollTransport{
            .allocator = allocator,
            .steps = &steps,
            .seams = &seams,
            .cancel_on_send = true,
        };
        var tracking = try testTrackingHandle(allocator, transport.asTransport());
        defer tracking.deinit();
        var options = seams.options();
        options.cancellation = &cancellation;
        var outcome = try tracking.poll(allocator, options);
        defer outcome.deinit(allocator);
        switch (outcome) {
            .stopped => |value| try std.testing.expectEqual(
                StatusPollingStopReason.cancelled,
                value.reason,
            ),
            .status => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    }
    {
        var seams = PollSeams{};
        defer seams.deinit(allocator);
        var transport = StatusPollTransport{
            .allocator = allocator,
            .steps = &steps,
            .seams = &seams,
            .advance_on_send_ms = 5,
        };
        var tracking = try testTrackingHandle(allocator, transport.asTransport());
        defer tracking.deinit();
        var options = seams.options();
        options.timeout_ms = 5;
        var outcome = try tracking.poll(allocator, options);
        defer outcome.deinit(allocator);
        switch (outcome) {
            .stopped => |value| try std.testing.expectEqual(
                StatusPollingStopReason.timeout,
                value.reason,
            ),
            .status => return error.TestUnexpectedResult,
        }
        try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    }
}

fn statusEntityAllocationTest(allocator: std.mem.Allocator) !void {
    const value = try serializeInitialEntity(
        allocator,
        "11111111-1111-4111-8111-111111111111",
        "11111111-1111-4111-8111-111111111111",
        "11111111-1111-4111-8111-111111111111",
        "DB",
        "T",
        "https://account.blob.core.windows.net/c/b",
        "2026-07-21T11:13:42.817Z",
    );
    defer allocator.free(value);
}

fn statusHandleAllocationTest(allocator: std.mem.Allocator) !void {
    const NoopTransport = struct {
        transport: core.http.HttpTransport = .{ .sendFn = &send },

        fn send(_: *core.http.HttpTransport, _: *core.http.Request) !core.http.Response {
            return error.UnexpectedRequest;
        }
    };
    var transport = NoopTransport{};
    var handle = try StatusTrackingHandle.init(
        allocator,
        "https://account.table.core.windows.net/status?sig=opaque",
        &transport.transport,
        "11111111-1111-4111-8111-111111111111",
        "DB",
        "Table",
    );
    defer handle.deinit();
}

test "status entity setup releases every allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        statusEntityAllocationTest,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        statusHandleAllocationTest,
        .{},
    );
}

fn statusDecodeAllocationTest(allocator: std.mem.Allocator) !void {
    var result = try decodeStatusEntity(allocator,
        \\{"Status":"Failed","IngestionSourceId":"id","OperationId":"op","ActivityId":"activity","Database":"DB","Table":"T","UpdatedOn":"2026-07-21T11:13:42.817Z","ErrorCode":"BadInput","FailureStatus":"Permanent","Details":"invalid row","OriginatesFromUpdatePolicy":true}
    );
    defer result.deinit(allocator);
}

test "status entity decoding releases every allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        statusDecodeAllocationTest,
        .{},
    );
}
