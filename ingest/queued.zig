//! Kusto queued ingestion through temporary Blob Storage and Azure Queue.
const std = @import("std");
const serde = @import("serde");
const core = @import("azure_core");
const blobs = @import("azure_storage_blobs");
const queues = @import("azure_storage_queues");
const storage_common = @import("azure_storage_common");
const kusto_common = @import("azure_kusto_common");
const data_result = @import("azure_kusto_data");
const resources = @import("resources.zig");
const streaming = @import("streaming.zig");
const status = @import("status.zig");

pub const StreamingIngestSource = streaming.StreamingIngestSource;
pub const StreamingIngestTarget = streaming.StreamingIngestTarget;
pub const SourceKind = streaming.SourceKind;
pub const IngestOptions = streaming.IngestOptions;
pub const QueuedCompression = streaming.QueuedCompression;
pub const IngestionProperties = kusto_common.IngestionProperties;
pub const IngestionResult = streaming.IngestionResult;
pub const KustoResult = kusto_common.KustoResult;
pub const QueuedIngestionStatus = status.QueuedIngestionStatus;
pub const IngestionFailureDisposition = status.IngestionFailureDisposition;
pub const IngestionStatusResult = status.IngestionStatusResult;
pub const StatusPollOptions = status.StatusPollOptions;
pub const StatusPollOutcome = status.StatusPollOutcome;
pub const StatusPollingStopped = status.StatusPollingStopped;
pub const StatusPollingStopReason = status.StatusPollingStopReason;
pub const StatusClock = status.StatusClock;
pub const StatusSleeper = status.StatusSleeper;
pub const StatusRandom = status.StatusRandom;
pub const StatusTrackingHandle = status.StatusTrackingHandle;

/// The final state of one queued submission. `queue_accepted` means only that
/// Queue Storage accepted the message; it never represents ingestion
/// completion.
pub const QueuedSubmissionOutcome = enum {
    queue_accepted,
    queue_unknown,
    queue_rejected,
    pre_queue_failed,
};

pub const QueuedResourceOperation = enum {
    temporary_blob,
    status_table,
    queue,
};

pub const QueuedResourceAttemptOutcome = enum {
    uploaded,
    upload_rejected,
    upload_unknown,
    upload_incomplete,
    status_table_created,
    status_table_rejected,
    status_table_unknown,
    queue_accepted,
    queue_rejected,
    queue_unknown,
    local_failure,
};

/// Owned diagnostic context for a selected resource. It deliberately retains
/// only the safe account name and generation, never a SAS URI or token.
pub const QueuedResourceAttempt = struct {
    attempt: resources.ResourceAttempt,
    operation: QueuedResourceOperation,
    outcome: QueuedResourceAttemptOutcome = .local_failure,
    status_code: ?u16 = null,

    fn deinit(self: *QueuedResourceAttempt, allocator: std.mem.Allocator) void {
        self.attempt.deinit(allocator);
        self.* = undefined;
    }
};

/// Owned result of a queued submission. Call `deinit` once finished.
///
/// A queue rejection is a received, known-not-accepted outcome. A missing
/// queue response is `queue_unknown` and is never retried automatically.
/// `pre_queue_failed` covers local resource, source, and Blob failures before
/// a Queue Storage request was accepted.
pub const QueuedIngestionResult = struct {
    outcome: QueuedSubmissionOutcome,
    /// Allocator-owned stable logical source ID.
    ingestion_id: []u8,
    source_kind: SourceKind,
    raw_size: ?u64,
    attempts: []QueuedResourceAttempt,
    attempt_count: usize = 0,
    failure: ?anyerror = null,
    resource_failure: ?kusto_common.KustoError = null,
    /// Present only after a known accepted Queue submission whose requested
    /// table-reporting entity was successfully created before that POST.
    tracking: ?StatusTrackingHandle = null,

    pub fn deinit(self: *QueuedIngestionResult, allocator: std.mem.Allocator) void {
        allocator.free(self.ingestion_id);
        for (self.attempts[0..self.attempt_count]) |*attempt| attempt.deinit(allocator);
        allocator.free(self.attempts);
        if (self.resource_failure) |*failure| failure.deinit();
        if (self.tracking) |*tracking| tracking.deinit();
        self.* = undefined;
    }

    /// Transfers the optional polling handle from this result. The result no
    /// longer owns it; callers must deinitialize the returned handle.
    pub fn takeTracking(self: *QueuedIngestionResult) ?StatusTrackingHandle {
        const tracking = self.tracking;
        self.tracking = null;
        return tracking;
    }
};

/// Queued ingestion using ResourceManager-discovered, credential-isolated
/// storage SAS resources.
///
/// An injected ResourceManager is borrowed, as is the transport. The manager,
/// its executor, transport, and any shared KustoConnection must outlive this
/// client and all calls. ResourceManager may synchronize its own cache, but a
/// DataManagementCommandExecutor backed by KustoConnection is not concurrent
/// safe; callers must serialize those uses.
pub const QueuedIngestClient = struct {
    manager: ?*resources.ResourceManager = null,
    connection: ?*kusto_common.KustoConnection = null,
    transport: *core.http.HttpTransport,

    /// Compatibility constructor. It cannot discover authenticated resources;
    /// use `initWithResourceManager` or
    /// `initWithConnectionAndResourceManager` before submitting ingestion.
    pub fn init(
        _: kusto_common.ConnectionProperties,
        transport: *core.http.HttpTransport,
    ) QueuedIngestClient {
        return .{ .transport = transport };
    }

    /// Creates a client borrowing a shared connection. Calls create a
    /// short-lived ResourceManager when no injected manager is available;
    /// inject one to retain discovery cache and ranking state across calls.
    pub fn initWithConnection(connection: *kusto_common.KustoConnection) QueuedIngestClient {
        return .{ .connection = connection, .transport = connection.transport };
    }

    /// Creates a queued client borrowing a ResourceManager and raw transport.
    /// The transport is used only by complete-SAS Blob and Queue clients, so
    /// Kusto bearer policies cannot attach to those storage requests.
    pub fn initWithResourceManager(
        manager: *resources.ResourceManager,
        transport: *core.http.HttpTransport,
    ) QueuedIngestClient {
        return .{ .manager = manager, .transport = transport };
    }

    /// Creates a queued client borrowing a shared connection and a manager
    /// whose executor normally borrows that same connection.
    pub fn initWithConnectionAndResourceManager(
        connection: *kusto_common.KustoConnection,
        manager: *resources.ResourceManager,
    ) QueuedIngestClient {
        return .{
            .manager = manager,
            .connection = connection,
            .transport = connection.transport,
        };
    }

    /// Submits a shared runtime source to Kusto queued ingestion.
    pub fn ingest(
        self: *QueuedIngestClient,
        allocator: std.mem.Allocator,
        target: StreamingIngestTarget,
        source: StreamingIngestSource,
        options: IngestOptions,
    ) !QueuedIngestionResult {
        try checkCancelled(options.cancellation);
        var threaded: std.Io.Threaded = .init_single_threaded;
        var executor: resources.DataManagementCommandExecutor = undefined;
        var owned_manager: ?resources.ResourceManager = null;
        const manager = if (self.manager) |injected|
            injected
        else if (self.connection) |connection| blk: {
            executor = resources.DataManagementCommandExecutor.initWithConnection(connection);
            owned_manager = try resources.ResourceManager.init(
                allocator,
                threaded.io(),
                executor.asExecutor(),
                resources.default_resource_database,
                .{},
            );
            break :blk &owned_manager.?;
        } else return error.QueuedIngestionResourceManagerRequired;
        defer if (owned_manager) |*owned| owned.deinit();
        try validateTargetAndOptions(target, source, options);
        const source_info = try sourceInfo(source, options);
        try checkCancelled(options.cancellation);

        const source_id = try makeLogicalSourceId(allocator, options.source_id);
        const attempt_capacity = attemptCapacity(options.queued_max_resource_attempts) catch |err| {
            allocator.free(source_id);
            return err;
        };
        const attempts = allocator.alloc(QueuedResourceAttempt, attempt_capacity) catch |err| {
            allocator.free(source_id);
            return err;
        };
        var result = QueuedIngestionResult{
            .outcome = .pre_queue_failed,
            .ingestion_id = source_id,
            .source_kind = source.kind(),
            .raw_size = source_info.raw_size,
            .attempts = attempts,
        };
        errdefer result.deinit(allocator);

        const blob_uri = switch (source) {
            .blob_uri => |blob| try allocator.dupe(u8, blob.uri),
            else => try self.uploadTemporaryBlob(
                allocator,
                manager,
                source,
                source_info,
                options,
                &result,
            ) orelse return result,
        };
        defer allocator.free(blob_uri);
        try checkCancelled(options.cancellation);

        // This is Queue submission time, not user-provided extent creation
        // time. It remains stable if a received Queue rejection is retried.
        const source_message_creation_time_ms = currentUnixMs();
        if (shouldTrackInStatusTable(options)) {
            const tracking = try self.prepareStatusTracking(
                allocator,
                manager,
                target,
                blob_uri,
                source_message_creation_time_ms,
                options,
                &result,
            ) orelse return result;
            // Every allocation and the status-table write finish before Queue
            // submission. From here an accepted Queue response cannot be
            // replaced by local setup or cleanup work.
            result.tracking = tracking;
            try checkCancelled(options.cancellation);
        }

        try checkCancelled(options.cancellation);
        return self.submitToQueue(
            allocator,
            manager,
            target,
            source_info.raw_size,
            options,
            blob_uri,
            source_message_creation_time_ms,
            &result,
        );
    }

    /// Alias mirroring the direct-ingestion runtime-source entry point.
    pub fn ingestResult(
        self: *QueuedIngestClient,
        allocator: std.mem.Allocator,
        target: StreamingIngestTarget,
        source: StreamingIngestSource,
        options: IngestOptions,
    ) !QueuedIngestionResult {
        return self.ingest(allocator, target, source, options);
    }

    /// Existing blob API retained for compatibility. Use `ingest` to inspect
    /// Queue-specific acceptance, rejection, and ambiguity. A returned result
    /// whose status is `.failed` is not queue acceptance.
    pub fn ingestFromBlob(
        self: *QueuedIngestClient,
        allocator: std.mem.Allocator,
        properties: IngestionProperties,
        blob_url: []const u8,
    ) !IngestionResult {
        var queued = try self.ingest(
            allocator,
            .{ .database = properties.database, .table = properties.table },
            .{ .blob_uri = .{ .uri = blob_url, .raw_size = properties.raw_size } },
            optionsFromProperties(properties),
        );
        return compatibilityResult(allocator, &queued);
    }

    /// Existing structured API retained for source compatibility. A returned
    /// `.ok` means this wrapper completed; inspect `ok.outcome` because Queue
    /// Storage rejection or ambiguity cannot be represented as a Kusto error.
    /// Resource-manager Kusto failures are transferred as `.err`.
    pub fn ingestFromBlobResult(
        self: *QueuedIngestClient,
        allocator: std.mem.Allocator,
        properties: IngestionProperties,
        blob_url: []const u8,
    ) !KustoResult(IngestionResult) {
        var queued = try self.ingest(
            allocator,
            .{ .database = properties.database, .table = properties.table },
            .{ .blob_uri = .{ .uri = blob_url, .raw_size = properties.raw_size } },
            optionsFromProperties(properties),
        );
        if (queued.resource_failure) |failure| {
            queued.resource_failure = null;
            queued.deinit(allocator);
            return .{ .err = failure };
        }
        return .{ .ok = compatibilityResult(allocator, &queued) };
    }

    /// No allocations are owned by this borrowing client. Retained for source
    /// compatibility with the former placeholder API.
    pub fn deinit(_: *QueuedIngestClient, _: std.mem.Allocator) void {}

    fn uploadTemporaryBlob(
        self: *QueuedIngestClient,
        allocator: std.mem.Allocator,
        manager: *resources.ResourceManager,
        source: StreamingIngestSource,
        source_info: SourceInfo,
        options: IngestOptions,
        result: *QueuedIngestionResult,
    ) !?[]u8 {
        const blob_name = try temporaryBlobName(
            allocator,
            result.ingestion_id,
            temporaryBlobExtension(source_info, options),
        );
        defer allocator.free(blob_name);

        const first_attempt = result.attempt_count;
        var attempt_number: u32 = 0;
        while (attempt_number < options.queued_max_resource_attempts) : (attempt_number += 1) {
            try checkCancelled(options.cancellation);
            var selection_result = selectResourceForOperation(
                allocator,
                manager,
                .temporary_blob_container,
                result,
                first_attempt,
            ) catch |err| {
                if (err == error.OutOfMemory) return err;
                try checkCancelled(options.cancellation);
                result.failure = err;
                return null;
            };
            var selection = switch (selection_result) {
                .ok => |value| value,
                .err => |failure| {
                    selection_result = undefined;
                    result.resource_failure = failure;
                    return null;
                },
            };
            selection_result = undefined;
            defer manager.deinitSelection(&selection);
            try checkCancelled(options.cancellation);

            const result_attempt = try appendAttempt(
                allocator,
                result,
                &selection,
                .temporary_blob,
            );
            var container_uri = storage_common.sas.CompleteSasUri.init(
                allocator,
                selection.resource.uri(),
            ) catch |err| {
                if (err == error.OutOfMemory) return err;
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                return null;
            };
            defer container_uri.deinit();
            const blob_uri = container_uri.appendPathSegment(allocator, blob_name) catch |err| {
                if (err == error.OutOfMemory) return err;
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                return null;
            };
            var blob_uri_owned = true;
            defer if (blob_uri_owned) allocator.free(blob_uri);

            var blob_client = blobs.SasBlobClient.init(
                allocator,
                blob_uri,
                self.transport,
            ) catch |err| {
                if (err == error.OutOfMemory) return err;
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                return null;
            };
            defer blob_client.deinit();

            try checkCancelled(options.cancellation);
            var opened = OpenedSource.init(allocator, source, source_info.upload_size) catch |err| {
                if (err == error.OutOfMemory) return err;
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                return null;
            };
            defer opened.deinit();
            try checkCancelled(options.cancellation);

            const upload = blk: {
                if (shouldGzip(source_info, options)) {
                    var gzip: GzipReader = undefined;
                    gzip.init(opened.sourceReader(), source_info.upload_size) catch |err| {
                        if (err == error.OutOfMemory) return err;
                        result.attempts[result_attempt].outcome = .local_failure;
                        result.failure = err;
                        return null;
                    };
                    break :blk blob_client.uploadBlockStream(&gzip.interface, .{}) catch |err| {
                        if (err == error.OutOfMemory) return err;
                        try checkCancelled(options.cancellation);
                        result.attempts[result_attempt].outcome = .local_failure;
                        result.failure = err;
                        return null;
                    };
                }
                if (source_info.upload_size) |upload_size| {
                    break :blk blob_client.uploadReader(
                        opened.sourceReader(),
                        upload_size,
                        .{},
                    ) catch |err| {
                        if (err == error.OutOfMemory) return err;
                        try checkCancelled(options.cancellation);
                        result.attempts[result_attempt].outcome = .local_failure;
                        result.failure = err;
                        return null;
                    };
                }
                break :blk blob_client.uploadBlockStream(opened.sourceReader(), .{}) catch |err| {
                    if (err == error.OutOfMemory) return err;
                    try checkCancelled(options.cancellation);
                    result.attempts[result_attempt].outcome = .local_failure;
                    result.failure = err;
                    return null;
                };
            };
            try checkCancelled(options.cancellation);
            switch (upload) {
                .accepted => {
                    result.attempts[result_attempt].outcome = .uploaded;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        true,
                    );
                    blob_uri_owned = false;
                    return blob_uri;
                },
                .rejected => |rejected| {
                    result.attempts[result_attempt].outcome = .upload_rejected;
                    result.attempts[result_attempt].status_code = rejected.status_code;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        false,
                    );
                    if (!source.isReplayable()) return null;
                },
                .unknown => |unknown| {
                    result.attempts[result_attempt].outcome = .upload_unknown;
                    result.failure = unknown.cause;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        false,
                    );
                    return null;
                },
                .incomplete => |incomplete| {
                    result.attempts[result_attempt].outcome = .upload_incomplete;
                    result.failure = incomplete.cause;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        false,
                    );
                    if (!source.isReplayable()) return null;
                },
            }
            try checkCancelled(options.cancellation);
        }
        return null;
    }

    /// Selects a service-issued status-table SAS URI and inserts the initial
    /// reference entity before Queue submission, matching the Java and Go
    /// queued-ingestion protocols. A table write with no received response is
    /// not retried: the entity may exist and this submission has not yet
    /// reached the Queue.
    fn prepareStatusTracking(
        self: *QueuedIngestClient,
        allocator: std.mem.Allocator,
        manager: *resources.ResourceManager,
        target: StreamingIngestTarget,
        blob_uri: []const u8,
        source_message_creation_time_ms: i64,
        options: IngestOptions,
        result: *QueuedIngestionResult,
    ) !?StatusTrackingHandle {
        const first_attempt = result.attempt_count;
        var attempt_number: u32 = 0;
        while (attempt_number < options.queued_max_resource_attempts) : (attempt_number += 1) {
            try checkCancelled(options.cancellation);
            var selection_result = selectResourceForOperation(
                allocator,
                manager,
                .ingestion_status_table,
                result,
                first_attempt,
            ) catch |err| {
                if (err == error.OutOfMemory) return err;
                try checkCancelled(options.cancellation);
                result.failure = err;
                return null;
            };
            var selection = switch (selection_result) {
                .ok => |value| value,
                .err => |failure| {
                    selection_result = undefined;
                    result.resource_failure = failure;
                    return null;
                },
            };
            selection_result = undefined;
            defer manager.deinitSelection(&selection);
            try checkCancelled(options.cancellation);

            const result_attempt = try appendAttempt(
                allocator,
                result,
                &selection,
                .status_table,
            );
            var tracking = status.StatusTrackingHandle.init(
                allocator,
                selection.resource.uri(),
                self.transport,
                result.ingestion_id,
                target.database,
                target.table,
            ) catch |err| {
                if (err == error.OutOfMemory) return err;
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                return null;
            };
            var tracking_owned = true;
            defer if (tracking_owned) tracking.deinit();

            var timestamp_buffer: [32]u8 = undefined;
            const timestamp = formatRfc3339Millis(
                source_message_creation_time_ms,
                &timestamp_buffer,
            ) catch |err| {
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                return null;
            };
            try checkCancelled(options.cancellation);
            const table_write = tracking.createInitialEntity(blob_uri, timestamp) catch |err| {
                if (err == error.OutOfMemory) return err;
                try checkCancelled(options.cancellation);
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                return null;
            };
            switch (table_write) {
                .accepted => {
                    result.attempts[result_attempt].outcome = .status_table_created;
                    result.attempts[result_attempt].status_code = table_write.accepted.status_code;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        true,
                    );
                    tracking_owned = false;
                    return tracking;
                },
                .rejected => |rejected| {
                    result.attempts[result_attempt].outcome = .status_table_rejected;
                    result.attempts[result_attempt].status_code = rejected.status_code;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        false,
                    );
                },
                .unknown => |unknown| {
                    result.attempts[result_attempt].outcome = .status_table_unknown;
                    result.failure = unknown.cause;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        false,
                    );
                    return null;
                },
            }
            try checkCancelled(options.cancellation);
        }
        return null;
    }

    fn submitToQueue(
        self: *QueuedIngestClient,
        allocator: std.mem.Allocator,
        manager: *resources.ResourceManager,
        target: StreamingIngestTarget,
        raw_size: ?u64,
        options: IngestOptions,
        blob_uri: []const u8,
        source_message_creation_time_ms: i64,
        result: *QueuedIngestionResult,
    ) !QueuedIngestionResult {
        const first_attempt = result.attempt_count;
        var attempt_number: u32 = 0;
        while (attempt_number < options.queued_max_resource_attempts) : (attempt_number += 1) {
            try checkCancelled(options.cancellation);
            var selection_result = selectResourceForOperation(
                allocator,
                manager,
                .secured_ready_for_aggregation_queue,
                result,
                first_attempt,
            ) catch |err| {
                if (err == error.OutOfMemory) return err;
                try checkCancelled(options.cancellation);
                result.failure = err;
                result.outcome = .pre_queue_failed;
                discardTracking(result);
                return result.*;
            };
            var selection = switch (selection_result) {
                .ok => |value| value,
                .err => |failure| {
                    selection_result = undefined;
                    result.resource_failure = failure;
                    result.outcome = .pre_queue_failed;
                    discardTracking(result);
                    return result.*;
                },
            };
            selection_result = undefined;
            defer manager.deinitSelection(&selection);
            try checkCancelled(options.cancellation);

            const result_attempt = try appendAttempt(
                allocator,
                result,
                &selection,
                .queue,
            );
            const message = buildQueueMessage(
                allocator,
                target,
                options,
                result.ingestion_id,
                raw_size,
                blob_uri,
                selection.authorization_context.token(),
                source_message_creation_time_ms,
                if (result.tracking) |*tracking| tracking.queueReference() else null,
            ) catch |err| {
                if (err == error.OutOfMemory) return err;
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                result.outcome = .pre_queue_failed;
                discardTracking(result);
                return result.*;
            };
            defer allocator.free(message);

            var queue_client = queues.SasQueueClient.init(
                allocator,
                selection.resource.uri(),
                self.transport,
            ) catch |err| {
                if (err == error.OutOfMemory) return err;
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                result.outcome = .pre_queue_failed;
                discardTracking(result);
                return result.*;
            };
            defer queue_client.deinit();
            try checkCancelled(options.cancellation);
            const queue = queue_client.sendMessage(message) catch |err| {
                if (err == error.OutOfMemory) return err;
                try checkCancelled(options.cancellation);
                result.attempts[result_attempt].outcome = .local_failure;
                result.failure = err;
                result.outcome = .pre_queue_failed;
                discardTracking(result);
                return result.*;
            };
            switch (queue) {
                .accepted => |accepted| {
                    result.attempts[result_attempt].outcome = .queue_accepted;
                    result.attempts[result_attempt].status_code = accepted.status_code;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        true,
                    );
                    result.outcome = .queue_accepted;
                    return result.*;
                },
                .rejected => |rejected| {
                    result.attempts[result_attempt].outcome = .queue_rejected;
                    result.attempts[result_attempt].status_code = rejected.status_code;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        false,
                    );
                },
                .unknown => |unknown| {
                    result.attempts[result_attempt].outcome = .queue_unknown;
                    result.failure = unknown.cause;
                    manager.reportAttemptNoAlloc(
                        &result.attempts[result_attempt].attempt,
                        false,
                    );
                    result.outcome = .queue_unknown;
                    discardTracking(result);
                    return result.*;
                },
            }
            try checkCancelled(options.cancellation);
        }
        result.outcome = .queue_rejected;
        discardTracking(result);
        return result.*;
    }
};

fn discardTracking(result: *QueuedIngestionResult) void {
    if (result.tracking) |*tracking| tracking.deinit();
    result.tracking = null;
}

fn checkCancelled(cancellation: ?*const core.http.CancellationToken) !void {
    if (cancellation) |token| {
        if (token.isCancelled()) return error.OperationCancelled;
    }
}

fn selectResourceForOperation(
    allocator: std.mem.Allocator,
    manager: *resources.ResourceManager,
    kind: resources.ResourceKind,
    result: *const QueuedIngestionResult,
    first_attempt: usize,
) !resources.ResourceSelectionResult {
    const prior = result.attempts[first_attempt..result.attempt_count];
    if (prior.len == 0) return manager.selectResource(kind);
    const excluded = try allocator.alloc(resources.ResourceAttempt, prior.len);
    defer allocator.free(excluded);
    for (prior, excluded) |attempt, *item| item.* = attempt.attempt;
    return manager.selectResourceExcluding(kind, excluded);
}

fn appendAttempt(
    allocator: std.mem.Allocator,
    result: *QueuedIngestionResult,
    selection: *const resources.ResourceSelection,
    operation: QueuedResourceOperation,
) !usize {
    std.debug.assert(result.attempt_count < result.attempts.len);
    const index = result.attempt_count;
    result.attempts[index] = .{
        .attempt = .{
            .kind = selection.attempt.kind,
            .account_name = try allocator.dupe(u8, selection.attempt.account_name),
            .generation = selection.attempt.generation,
        },
        .operation = operation,
    };
    result.attempt_count += 1;
    return index;
}

/// Flattens a rich queued result for legacy APIs, deliberately discarding
/// resource attempts and any optional status-tracking handle.
pub fn compatibilityResult(
    allocator: std.mem.Allocator,
    queued: *QueuedIngestionResult,
) IngestionResult {
    const ingestion_id = queued.ingestion_id;
    queued.ingestion_id = &.{};
    const outcome = queued.outcome;
    const source_kind = queued.source_kind;
    queued.deinit(allocator);
    return .{
        .status = if (outcome == .queue_accepted) .queued else .failed,
        .outcome = switch (outcome) {
            .queue_accepted => .accepted,
            .queue_unknown => .unknown,
            .queue_rejected, .pre_queue_failed => .known_not_accepted,
        },
        .ingestion_id = ingestion_id,
        .source_kind = source_kind,
    };
}

fn attemptCapacity(max_attempts: u32) !usize {
    if (max_attempts == 0) return error.InvalidQueuedResourceAttemptLimit;
    // Blob, status-table, and Queue phases can each select a resource.
    return std.math.mul(usize, @as(usize, max_attempts), 3) catch
        error.InvalidQueuedResourceAttemptLimit;
}

fn optionsFromProperties(properties: IngestionProperties) IngestOptions {
    return .{
        .format = properties.format,
        .mapping_name = properties.mapping_name,
        .source_id = properties.source_id,
        .raw_size = properties.raw_size,
        .flush_immediately = properties.flush_immediately,
        .creation_time_unix_ms = properties.creation_time_unix_ms,
        .validation_policy = properties.validation_policy,
        .tags = properties.tags,
        .drop_by_tags = properties.drop_by_tags orelse &.{},
        .ingest_if_not_exists = properties.ingest_if_not_exists,
        .ignore_first_record = properties.ignore_first_record,
        .report_level = properties.report_level,
        .report_method = properties.report_method,
    };
}

fn validateTargetAndOptions(
    target: StreamingIngestTarget,
    source: StreamingIngestSource,
    options: IngestOptions,
) !void {
    if (target.database.len == 0 or !std.unicode.utf8ValidateSlice(target.database))
        return error.InvalidQueuedDatabase;
    if (target.table.len == 0 or !std.unicode.utf8ValidateSlice(target.table))
        return error.InvalidQueuedTable;
    if (options.mapping_name) |name| {
        if (name.len == 0 or !std.unicode.utf8ValidateSlice(name))
            return error.InvalidQueuedMappingName;
    }
    if (options.source_id) |source_id| try validateQueuedSourceId(source_id);
    if (options.validation_policy) |policy| {
        const validation_options = policy.validation_options orelse
            return error.InvalidQueuedValidationOptions;
        const validation_implications = policy.validation_implications orelse
            return error.InvalidQueuedValidationImplications;
        if (validation_options > 2) return error.InvalidQueuedValidationOptions;
        if (validation_implications > 1) return error.InvalidQueuedValidationImplications;
    }

    if (source == .blob_uri) {
        const uri = source.blob_uri.uri;
        if (uri.len == 0 or !std.unicode.utf8ValidateSlice(uri))
            return error.InvalidQueuedSourceUri;
        // Existing blobs are queued as-is; there is no upload step at which
        // an explicit compression mode could be honored.
        if (options.queued_compression != .automatic)
            return error.QueuedBlobUriCompressionUnsupported;
    }
}

fn shouldTrackInStatusTable(options: IngestOptions) bool {
    return options.report_level != .none and options.report_method != .queue;
}

const SourceInfo = struct {
    /// The uncompressed source size advertised to Kusto. It is unavailable
    /// for a pass-through precompressed file unless the caller supplies it.
    raw_size: ?u64,
    /// The exact byte length supplied to Blob Storage.
    upload_size: ?u64,
    /// Retained only for an automatic/none precompressed-file upload.
    precompressed_extension: ?[]const u8 = null,
};

fn sourceInfo(source: StreamingIngestSource, options: IngestOptions) !SourceInfo {
    var info: SourceInfo = switch (source) {
        .bytes => |bytes| .{
            .raw_size = @intCast(bytes.len),
            .upload_size = @intCast(bytes.len),
        },
        .file => |path| blk: {
            const size = try fileSize(path);
            const extension = precompressedFileExtension(path);
            // A caller who explicitly asks for gzip is compressing this file
            // as an opaque source again, so its on-disk byte count is raw for
            // the outer gzip layer.
            if (extension != null and options.queued_compression != .gzip) {
                break :blk .{
                    .raw_size = options.raw_size,
                    .upload_size = size,
                    .precompressed_extension = extension,
                };
            }
            break :blk .{ .raw_size = size, .upload_size = size };
        },
        .reader => |reader| blk: {
            if (reader.raw_size) |reader_size| {
                if (options.raw_size) |expected| {
                    if (expected != reader_size) return error.QueuedRawSizeMismatch;
                }
            }
            const size = reader.raw_size orelse options.raw_size;
            break :blk .{ .raw_size = size, .upload_size = size };
        },
        .replay_reader => |factory| .{
            .raw_size = factory.raw_size,
            .upload_size = factory.raw_size,
        },
        .blob_uri => |blob| .{ .raw_size = blob.raw_size, .upload_size = null },
    };
    if (info.precompressed_extension == null) {
        if (options.raw_size) |expected| {
            if (info.raw_size == null or info.raw_size.? != expected)
                return error.QueuedRawSizeMismatch;
        }
    } else if (options.raw_size == null) {
        // RawDataSize must not claim that the compressed upload byte length is
        // the original raw-data length.
        info.raw_size = null;
    }
    return info;
}

pub fn precompressedFileExtension(path: []const u8) ?[]const u8 {
    if (path.len >= 3 and std.ascii.eqlIgnoreCase(path[path.len - 3 ..], ".gz"))
        return path[path.len - 3 ..];
    if (path.len >= 4 and std.ascii.eqlIgnoreCase(path[path.len - 4 ..], ".zip"))
        return path[path.len - 4 ..];
    return null;
}

fn shouldGzip(info: SourceInfo, options: IngestOptions) bool {
    return switch (options.queued_compression) {
        .gzip => true,
        .none => false,
        .automatic => info.precompressed_extension == null and
            options.format.shouldGzipForQueuedIngestion(),
    };
}

fn temporaryBlobExtension(info: SourceInfo, options: IngestOptions) []const u8 {
    if (info.precompressed_extension) |extension| return extension[1..];
    return if (shouldGzip(info, options)) "gz" else options.format.toQueuedString();
}

/// Creates a secure nonzero canonical UUID for Queue-compatible ingestion.
/// Managed ingestion shares this helper so a streaming attempt and a fallback
/// queue submission always use the exact same normalized ID.
pub fn makeLogicalSourceId(allocator: std.mem.Allocator, provided: ?[]const u8) ![]u8 {
    const output = try allocator.alloc(u8, 36);
    errdefer allocator.free(output);
    if (provided) |source_id| {
        try canonicalizeQueuedSourceId(source_id, output);
        return output;
    }
    var threaded: std.Io.Threaded = .init_single_threaded;
    var seed: [std.Random.DefaultCsprng.secret_seed_length]u8 = undefined;
    try threaded.io().randomSecure(&seed);
    var csprng = std.Random.DefaultCsprng.init(seed);
    const uuid = core.uuid.Uuid.init(csprng.random()).toString();
    @memcpy(output, &uuid);
    return output;
}

fn validateQueuedSourceId(source_id: []const u8) !void {
    var ignored: [36]u8 = undefined;
    try canonicalizeQueuedSourceId(source_id, &ignored);
}

fn canonicalizeQueuedSourceId(source_id: []const u8, output: []u8) !void {
    if (source_id.len != 36 or output.len != 36)
        return error.InvalidQueuedSourceId;
    var nonzero = false;
    for (source_id, 0..) |byte, index| {
        if (index == 8 or index == 13 or index == 18 or index == 23) {
            if (byte != '-') return error.InvalidQueuedSourceId;
            output[index] = '-';
            continue;
        }
        output[index] = switch (byte) {
            '0'...'9' => byte,
            'a'...'f' => byte,
            'A'...'F' => byte + ('a' - 'A'),
            else => return error.InvalidQueuedSourceId,
        };
        nonzero = nonzero or output[index] != '0';
    }
    if (!nonzero) return error.InvalidQueuedSourceId;
}

fn temporaryBlobName(
    allocator: std.mem.Allocator,
    source_id: []const u8,
    extension: []const u8,
) ![]u8 {
    const encoded = try core.url.percentEncode(allocator, source_id);
    defer allocator.free(encoded);
    return std.fmt.allocPrint(allocator, "kusto-{s}.{s}", .{ encoded, extension });
}

fn fileSize(path: []const u8) !u64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    if (stat.kind != .file) return error.QueuedSourceNotFile;
    return stat.size;
}

const FileSourceHandle = struct {
    allocator: std.mem.Allocator,
    threaded: std.Io.Threaded,
    file: std.Io.File,
    reader_impl: std.Io.File.Reader,
    buffer: [16 * 1024]u8 = undefined,

    fn deinit(self: *FileSourceHandle) void {
        self.file.close(self.threaded.io());
        self.allocator.destroy(self);
    }
};

const OpenedSource = union(enum) {
    bytes: std.Io.Reader,
    file: *FileSourceHandle,
    borrowed: *std.Io.Reader,
    replay_reader: streaming.ReplayReader,

    fn init(
        allocator: std.mem.Allocator,
        source: StreamingIngestSource,
        expected_raw_size: ?u64,
    ) !OpenedSource {
        return switch (source) {
            .bytes => |bytes| .{ .bytes = std.Io.Reader.fixed(bytes) },
            .reader => |source_reader| .{ .borrowed = source_reader.reader },
            .replay_reader => |factory| .{ .replay_reader = try factory.open() },
            .blob_uri => error.QueuedTemporaryBlobNotRequired,
            .file => |path| blk: {
                const handle = try allocator.create(FileSourceHandle);
                errdefer allocator.destroy(handle);
                handle.* = .{
                    .allocator = allocator,
                    .threaded = .init_single_threaded,
                    .file = undefined,
                    .reader_impl = undefined,
                };
                const io = handle.threaded.io();
                handle.file = try std.Io.Dir.cwd().openFile(io, path, .{});
                errdefer handle.file.close(io);
                const stat = try handle.file.stat(io);
                if (stat.kind != .file) return error.QueuedSourceNotFile;
                if (expected_raw_size) |expected| {
                    if (stat.size != expected) return error.QueuedSourceChanged;
                }
                handle.reader_impl = handle.file.readerStreaming(io, &handle.buffer);
                break :blk .{ .file = handle };
            },
        };
    }

    fn sourceReader(self: *OpenedSource) *std.Io.Reader {
        return switch (self.*) {
            .bytes => |*fixed_reader| fixed_reader,
            .file => |file| &file.reader_impl.interface,
            .borrowed => |source_reader| source_reader,
            .replay_reader => |*replay| replay.reader,
        };
    }

    fn deinit(self: *OpenedSource) void {
        switch (self.*) {
            .file => |file| file.deinit(),
            .replay_reader => |*replay| replay.deinit(),
            .bytes, .borrowed => {},
        }
    }
};

/// Incremental gzip reader with fixed working buffers. It verifies that the
/// advertised raw length is exact without accumulating source bytes.
const GzipReader = struct {
    interface: std.Io.Reader,
    source: *std.Io.Reader,
    raw_remaining: ?u64,
    source_checked: bool = false,
    finished: bool = false,
    source_buffer: [16 * 1024]u8 = undefined,
    output_buffer: [128 * 1024]u8 = undefined,
    output_writer: std.Io.Writer = undefined,
    output_pos: usize = 0,
    compressor_buffer: [std.compress.flate.max_window_len]u8 = undefined,
    compressor: std.compress.flate.Compress = undefined,

    fn init(self: *GzipReader, source: *std.Io.Reader, raw_size: ?u64) !void {
        self.* = .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .source = source,
            .raw_remaining = raw_size,
        };
        self.output_writer = .fixed(&self.output_buffer);
        self.compressor = try std.compress.flate.Compress.init(
            &self.output_writer,
            &self.compressor_buffer,
            .gzip,
            .fastest,
        );
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *GzipReader = @alignCast(@fieldParentPtr("interface", interface));
        while (true) {
            const pending = self.output_writer.buffer[self.output_pos..self.output_writer.end];
            if (pending.len != 0) {
                const count = writer.write(limit.slice(pending)) catch return error.WriteFailed;
                self.output_pos += count;
                if (self.output_pos == self.output_writer.end) {
                    self.output_pos = 0;
                    self.output_writer.end = 0;
                }
                return count;
            }
            if (self.finished) return error.EndOfStream;
            self.produce() catch return error.ReadFailed;
        }
    }

    fn produce(self: *GzipReader) !void {
        if (self.raw_remaining) |remaining| {
            if (remaining != 0) {
                const wanted: usize = @intCast(@min(remaining, self.source_buffer.len));
                const count = try self.source.readSliceShort(self.source_buffer[0..wanted]);
                if (count == 0) return error.RequestBodyTooShort;
                self.raw_remaining = remaining - count;
                try self.compressor.writer.writeAll(self.source_buffer[0..count]);
                return;
            }
            if (!self.source_checked) {
                var extra: [1]u8 = undefined;
                if (try self.source.readSliceShort(&extra) != 0) return error.RequestBodyTooLong;
                self.source_checked = true;
            }
        } else {
            const count = try self.source.readSliceShort(&self.source_buffer);
            if (count != 0) {
                try self.compressor.writer.writeAll(self.source_buffer[0..count]);
                return;
            }
            self.source_checked = true;
        }
        if (!self.source_checked) {
            var extra: [1]u8 = undefined;
            if (try self.source.readSliceShort(&extra) != 0) return error.RequestBodyTooLong;
            self.source_checked = true;
        }
        try self.compressor.finish();
        self.finished = true;
    }
};

const ValidationPolicyWire = struct {
    ValidationOptions: u32,
    ValidationImplications: u32,
};

const AdditionalPropertiesWire = struct {
    authorizationContext: []const u8,
    format: []const u8,
    ingestionMappingReference: ?[]const u8 = null,
    ingestionMappingType: ?[]const u8 = null,
    validationPolicy: ?[]const u8 = null,
    tags: ?[]const u8 = null,
    ingestIfNotExists: ?[]const u8 = null,
    creationTime: ?[]const u8 = null,
    ignoreFirstRecord: bool,
};

const IngestionStatusInTableWire = struct {
    TableConnectionString: []const u8,
    PartitionKey: []const u8,
    RowKey: []const u8,
};

const IngestionMessageWire = struct {
    Id: []const u8,
    BlobPath: []const u8,
    DatabaseName: []const u8,
    TableName: []const u8,
    RawDataSize: ?u64 = null,
    RetainBlobOnSuccess: bool = true,
    FlushImmediately: bool,
    ReportLevel: []const u8,
    ReportMethod: []const u8,
    SourceMessageCreationTime: []const u8,
    AdditionalProperties: AdditionalPropertiesWire,
    IngestionStatusInTable: ?IngestionStatusInTableWire = null,
};

const IngestionMessageWithoutRawSizeWire = struct {
    Id: []const u8,
    BlobPath: []const u8,
    DatabaseName: []const u8,
    TableName: []const u8,
    RetainBlobOnSuccess: bool = true,
    FlushImmediately: bool,
    ReportLevel: []const u8,
    ReportMethod: []const u8,
    SourceMessageCreationTime: []const u8,
    AdditionalProperties: AdditionalPropertiesWire,
    IngestionStatusInTable: ?IngestionStatusInTableWire = null,
};

fn buildQueueMessage(
    allocator: std.mem.Allocator,
    target: StreamingIngestTarget,
    options: IngestOptions,
    source_id: []const u8,
    raw_size: ?u64,
    blob_uri: []const u8,
    authorization_context: []const u8,
    source_message_creation_time_ms: i64,
    tracking: ?status.StatusTableReference,
) ![]u8 {
    const tags = try serializedTags(allocator, options.tags, options.drop_by_tags);
    defer if (tags) |value| allocator.free(value);
    const dedup = if (options.ingest_if_not_exists.len == 0)
        null
    else
        try serializeJson(allocator, options.ingest_if_not_exists);
    defer if (dedup) |value| allocator.free(value);

    const validation = if (options.validation_policy) |policy|
        try serializeJson(allocator, ValidationPolicyWire{
            .ValidationOptions = policy.validation_options orelse
                return error.InvalidQueuedValidationOptions,
            .ValidationImplications = policy.validation_implications orelse
                return error.InvalidQueuedValidationImplications,
        })
    else
        null;
    defer if (validation) |value| allocator.free(value);

    var source_creation_buffer: [32]u8 = undefined;
    const source_creation = try formatRfc3339Millis(
        source_message_creation_time_ms,
        &source_creation_buffer,
    );
    var creation_buffer: [32]u8 = undefined;
    const creation = if (options.creation_time_unix_ms) |time|
        try formatRfc3339Millis(time, &creation_buffer)
    else
        null;

    const mapping_type: ?[]const u8 = if (options.mapping_name != null)
        options.format.toIngestionMappingKind()
    else
        null;
    const additional_properties = AdditionalPropertiesWire{
        .authorizationContext = authorization_context,
        .format = options.format.toQueuedString(),
        .ingestionMappingReference = options.mapping_name,
        .ingestionMappingType = mapping_type,
        .validationPolicy = validation,
        .tags = tags,
        .ingestIfNotExists = dedup,
        .creationTime = creation,
        .ignoreFirstRecord = options.ignore_first_record,
    };
    const status_reference = if (tracking) |value| IngestionStatusInTableWire{
        .TableConnectionString = value.table_connection_string,
        .PartitionKey = value.partition_key,
        .RowKey = value.row_key,
    } else null;
    return if (raw_size) |size|
        try serializeJson(allocator, IngestionMessageWire{
            .Id = source_id,
            .BlobPath = blob_uri,
            .DatabaseName = target.database,
            .TableName = target.table,
            .RawDataSize = size,
            .FlushImmediately = options.flush_immediately,
            .ReportLevel = options.report_level.toString(),
            .ReportMethod = options.report_method.toString(),
            .SourceMessageCreationTime = source_creation,
            .AdditionalProperties = additional_properties,
            .IngestionStatusInTable = status_reference,
        })
    else
        try serializeJson(allocator, IngestionMessageWithoutRawSizeWire{
            .Id = source_id,
            .BlobPath = blob_uri,
            .DatabaseName = target.database,
            .TableName = target.table,
            .FlushImmediately = options.flush_immediately,
            .ReportLevel = options.report_level.toString(),
            .ReportMethod = options.report_method.toString(),
            .SourceMessageCreationTime = source_creation,
            .AdditionalProperties = additional_properties,
            .IngestionStatusInTable = status_reference,
        });
}

fn serializedTags(
    allocator: std.mem.Allocator,
    tags: []const []const u8,
    drop_by_tags: []const []const u8,
) !?[]u8 {
    if (tags.len == 0 and drop_by_tags.len == 0) return null;
    const values = try allocator.alloc([]const u8, tags.len + drop_by_tags.len);
    defer allocator.free(values);
    @memcpy(values[0..tags.len], tags);
    var generated = std.ArrayList([]u8).empty;
    defer {
        for (generated.items) |value| allocator.free(value);
        generated.deinit(allocator);
    }
    for (drop_by_tags, 0..) |tag, index| {
        const prefixed = try std.fmt.allocPrint(allocator, "drop-by:{s}", .{tag});
        errdefer allocator.free(prefixed);
        try generated.append(allocator, prefixed);
        values[tags.len + index] = prefixed;
    }
    return try serializeJson(allocator, values);
}

/// serde's allocating JSON writer reports its allocator failure as
/// `WriteFailed`; preserve the normal allocator contract for callers.
fn serializeJson(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    // Keep serde's intermediate writer in an arena so every allocation is
    // released when serialization or the final owned copy fails.
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const serialized = serde.json.toSlice(arena.allocator(), value) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => return err,
    };
    return allocator.dupe(u8, serialized);
}

fn currentUnixMs() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const nanoseconds = std.Io.Timestamp.now(threaded.io(), .real).toNanoseconds();
    const milliseconds = @divFloor(nanoseconds, std.time.ns_per_ms);
    return std.math.cast(i64, milliseconds) orelse
        if (milliseconds < 0) std.math.minInt(i64) else std.math.maxInt(i64);
}

fn formatRfc3339Millis(milliseconds: i64, buffer: *[32]u8) ![]const u8 {
    const seconds = @divFloor(milliseconds, 1_000);
    const fraction: u16 = @intCast(@mod(milliseconds, 1_000));
    const days = @divFloor(seconds, std.time.s_per_day);
    const seconds_of_day: u32 = @intCast(@mod(seconds, std.time.s_per_day));
    const date = civilFromDays(days);
    if (date.year < 0 or date.year > 9_999)
        return error.InvalidQueuedCreationTime;
    const year: u16 = @intCast(date.year);
    return std.fmt.bufPrint(
        buffer,
        "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z",
        .{
            year,
            date.month,
            date.day,
            seconds_of_day / std.time.s_per_hour,
            (seconds_of_day % std.time.s_per_hour) / std.time.s_per_min,
            seconds_of_day % std.time.s_per_min,
            fraction,
        },
    );
}

const CivilDate = struct { year: i64, month: u8, day: u8 };

fn civilFromDays(days_since_epoch: i64) CivilDate {
    const z = days_since_epoch + 719_468;
    const era = @divFloor(if (z >= 0) z else z - 146_096, 146_097);
    const day_of_era = z - era * 146_097;
    const year_of_era = @divFloor(
        day_of_era - @divFloor(day_of_era, 1_460) + @divFloor(day_of_era, 36_524) -
            @divFloor(day_of_era, 146_096),
        365,
    );
    const year = year_of_era + era * 400;
    const day_of_year = day_of_era -
        (365 * year_of_era + @divFloor(year_of_era, 4) - @divFloor(year_of_era, 100));
    const month_prime = @divFloor(5 * day_of_year + 2, 153);
    const day: u8 = @intCast(day_of_year - @divFloor(153 * month_prime + 2, 5) + 1);
    const month: u8 = @intCast(
        month_prime + @as(i64, if (month_prime < 10) 3 else -9),
    );
    return .{ .year = year + @intFromBool(month <= 2), .month = month, .day = day };
}

const queued_test_resource_body =
    \\{"Tables":[{"TableName":"Resources","Columns":[{"ColumnName":"ResourceTypeName","DataType":"String"},{"ColumnName":"StorageRoot","DataType":"String"}],"Rows":[
    \\["SecuredReadyForAggregationQueue","https://accounta.queue.core.windows.net/ready-a?sig=queue-a"],
    \\["SecuredReadyForAggregationQueue","https://accountb.queue.core.windows.net/ready-b?sig=queue-b"],
    \\["TempStorage","https://accounta.blob.core.windows.net/temp-a?sig=blob-a"],
    \\["TempStorage","https://accountb.blob.core.windows.net/temp-b?sig=blob-b"],
    \\["IngestionStatusTable","https://accounta.table.core.windows.net/ingestion-status?sig=table-a"]
    \\]}]}
;

const queued_test_token_body =
    \\{"Tables":[{"TableName":"Token","Columns":[{"ColumnName":"AuthorizationContext","DataType":"String"}],"Rows":[["identity-context"]]}]}
;

const QueuedTestExecutor = struct {
    calls: usize = 0,

    fn asExecutor(self: *QueuedTestExecutor) resources.ResourceCommandExecutor {
        return .{ .context = self, .executeFn = &execute };
    }

    fn execute(
        context: *anyopaque,
        allocator: std.mem.Allocator,
        _: []const u8,
        command: []const u8,
    ) !kusto_common.KustoResult(data_result.KustoResponseDataSet) {
        const self: *QueuedTestExecutor = @ptrCast(@alignCast(context));
        self.calls += 1;
        const body = if (std.mem.eql(u8, command, ".get ingestion resources"))
            queued_test_resource_body
        else if (std.mem.eql(u8, command, ".get kusto identity token"))
            queued_test_token_body
        else
            return error.UnexpectedResourceCommand;
        var decoded = try data_result.decodeResponseDataSet(
            allocator,
            body,
            .{},
            .management,
        );
        errdefer decoded.deinit(allocator);
        if (decoded.failure) |*failure| {
            const owned_failure = failure.*;
            decoded.failure = null;
            const dataset = decoded.dataset;
            decoded.dataset = undefined;
            return .{ .partial = .{ .value = dataset, .failure = owned_failure } };
        }
        const dataset = decoded.dataset;
        decoded.dataset = undefined;
        return .{ .ok = dataset };
    }
};

const QueuedOutcomeTransport = struct {
    const Step = union(enum) {
        status: u16,
        unknown,
    };

    allocator: std.mem.Allocator,
    steps: []const Step,
    call_count: usize = 0,
    capture_body: bool = false,
    last_body: ?[]u8 = null,
    transport: core.http.HttpTransport = .{ .sendFn = &send },

    fn asTransport(self: *QueuedOutcomeTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn deinit(self: *QueuedOutcomeTransport) void {
        if (self.last_body) |body| self.allocator.free(body);
        self.last_body = null;
    }

    fn send(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *QueuedOutcomeTransport = @alignCast(@fieldParentPtr("transport", transport));
        const index = @min(self.call_count, self.steps.len - 1);
        self.call_count += 1;
        if (self.capture_body) {
            if (self.last_body) |body| self.allocator.free(body);
            self.last_body = try self.allocator.dupe(u8, request.body orelse "");
        }
        return switch (self.steps[index]) {
            .unknown => error.ConnectionResetByPeer,
            .status => |status_code| .{
                .status_code = status_code,
                .headers = std.StringHashMap([]const u8).init(self.allocator),
                .body = try self.allocator.dupe(u8, ""),
                .allocator = self.allocator,
            },
        };
    }
};

fn initQueuedTestManager(
    allocator: std.mem.Allocator,
    executor: *QueuedTestExecutor,
) !resources.ResourceManager {
    return resources.ResourceManager.init(
        allocator,
        std.testing.io,
        executor.asExecutor(),
        "db",
        .{ .cache_ttl_ms = 60_000 },
    );
}

fn queueMessageJson(allocator: std.mem.Allocator, xml: []const u8) ![]u8 {
    const prefix = "<QueueMessage><MessageText>";
    const suffix = "</MessageText></QueueMessage>";
    if (!std.mem.startsWith(u8, xml, prefix) or !std.mem.endsWith(u8, xml, suffix))
        return error.InvalidQueueXml;
    const outer = xml[prefix.len .. xml.len - suffix.len];
    return core.base64.decode(allocator, outer);
}

test "queued bytes upload uses gzip message envelope and isolated SAS requests" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());

    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .bytes = "hello\n" },
        .{
            .format = .json,
            .mapping_name = "Map",
            .source_id = "11111111-1111-4111-8111-111111111111",
            .tags = &.{"tag"},
            .drop_by_tags = &.{"expired"},
            .ingest_if_not_exists = &.{"dedup"},
            .validation_policy = .{
                .validation_options = 1,
                .validation_implications = 1,
            },
            .creation_time_unix_ms = 0,
            .ignore_first_record = true,
            .flush_immediately = true,
            .report_level = .failures_and_successes,
            .report_method = .queue,
        },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
    try std.testing.expectEqualStrings("11111111-1111-4111-8111-111111111111", result.ingestion_id);
    try std.testing.expectEqual(@as(?u64, 6), result.raw_size);
    try std.testing.expectEqual(@as(usize, 2), result.attempt_count);
    try std.testing.expectEqual(QueuedResourceOperation.temporary_blob, result.attempts[0].operation);
    try std.testing.expectEqual(QueuedResourceOperation.queue, result.attempts[1].operation);
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expect(std.mem.indexOf(u8, transport.last_url.?, "ready-") != null);
    try std.testing.expect(transport.last_headers.get("Authorization") == null);

    const json = try queueMessageJson(allocator, transport.last_body.?);
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"Id\":\"11111111-1111-4111-8111-111111111111\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"RawDataSize\":6") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"authorizationContext\":\"identity-context\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"format\":\"json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"ingestionMappingType\":\"Json\"") != null);
    try std.testing.expect(
        std.mem.indexOf(
            u8,
            json,
            "\"validationPolicy\":\"{\\\"ValidationOptions\\\":1,\\\"ValidationImplications\\\":1}\"",
        ) != null,
    );
    try std.testing.expect(std.mem.indexOf(u8, json, "\"tags\":\"[\\\"tag\\\",\\\"drop-by:expired\\\"]\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"ingestIfNotExists\":\"[\\\"dedup\\\"]\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"SourceMessageCreationTime\":\"1970-") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"creationTime\":\"1970-01-01T00:00:00.000Z\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"BlobPath\":\"https://account") != null);
}

test "queued existing blob does not upload and keeps raw size optional" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());

    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .blob_uri = .{ .uri = "https://existing.blob.core.windows.net/c/a.csv?sig=source" } },
        .{ .source_id = "22222222-2222-4222-8222-222222222222" },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    try std.testing.expectEqual(QueuedResourceOperation.queue, result.attempts[0].operation);
    const json = try queueMessageJson(allocator, transport.last_body.?);
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "https://existing.blob.core.windows.net/c/a.csv?sig=source") != null);
}

test "queued unknown-length readers block upload and omit raw data size" {
    const allocator = std.testing.allocator;

    inline for ([_]QueuedCompression{ .none, .gzip }) |compression| {
        var executor = QueuedTestExecutor{};
        var manager = try initQueuedTestManager(allocator, &executor);
        defer manager.deinit();
        var transport = core.http.MockTransport.init(allocator, 201, "");
        defer transport.deinit();
        var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
        var reader = std.Io.Reader.fixed("unknown reader\n");

        var result = try client.ingest(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .reader = .{ .reader = &reader } },
            .{
                .source_id = "31313131-3131-4131-8131-313131313131",
                .queued_compression = compression,
            },
        );
        defer result.deinit(allocator);

        try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
        try std.testing.expectEqual(@as(?u64, null), result.raw_size);
        // One staged block, its commit, and Queue submission prove an
        // unknown-length plain or gzip stream did not use exact uploadReader.
        try std.testing.expectEqual(@as(usize, 3), transport.call_count);
        const json = try queueMessageJson(allocator, transport.last_body.?);
        defer allocator.free(json);
        try std.testing.expect(std.mem.indexOf(u8, json, "\"RawDataSize\"") == null);
    }
}

test "queued table reporting creates a reference entity before queue acceptance" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    const steps = [_]QueuedOutcomeTransport.Step{
        .{ .status = 204 },
        .{ .status = 201 },
    };
    var transport = QueuedOutcomeTransport{
        .allocator = allocator,
        .steps = &steps,
        .capture_body = true,
    };
    defer transport.deinit();
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());

    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .blob_uri = .{ .uri = "https://existing.blob.core.windows.net/c/a.csv?sig=source" } },
        .{
            .source_id = "abababab-abab-4bab-8bab-abababababab",
            .report_level = .failures_and_successes,
            .report_method = .queue_and_table,
        },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
    try std.testing.expect(result.tracking != null);
    try std.testing.expectEqual(@as(usize, 2), result.attempt_count);
    try std.testing.expectEqual(QueuedResourceOperation.status_table, result.attempts[0].operation);
    try std.testing.expectEqual(
        QueuedResourceAttemptOutcome.status_table_created,
        result.attempts[0].outcome,
    );
    try std.testing.expectEqual(QueuedResourceOperation.queue, result.attempts[1].operation);
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);

    const json = try queueMessageJson(allocator, transport.last_body.?);
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(
        u8,
        json,
        "\"IngestionStatusInTable\":{\"TableConnectionString\":\"https://accounta.table.core.windows.net/ingestion-status?sig=table-a\",\"PartitionKey\":\"abababab-abab-4bab-8bab-abababababab\",\"RowKey\":\"abababab-abab-4bab-8bab-abababababab\"}",
    ) != null);

    var tracking = result.takeTracking() orelse return error.TestUnexpectedResult;
    defer tracking.deinit();
    try std.testing.expect(result.tracking == null);
}

test "queued unknown queue outcome never exposes a tracking handle" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    const steps = [_]QueuedOutcomeTransport.Step{
        .{ .status = 204 },
        .unknown,
    };
    var transport = QueuedOutcomeTransport{ .allocator = allocator, .steps = &steps };
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .blob_uri = .{ .uri = "https://existing.blob.core.windows.net/c/a.csv?sig=source" } },
        .{
            .source_id = "acacacac-acac-4cac-8cac-acacacacacac",
            .report_method = .table,
        },
    );
    defer result.deinit(allocator);
    try std.testing.expectEqual(QueuedSubmissionOutcome.queue_unknown, result.outcome);
    try std.testing.expect(result.tracking == null);
}

test "queued file reader and replay reader sources submit through temporary blobs" {
    const allocator = std.testing.allocator;
    const path = ".queued-ingest-source-test";
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();
    var file = try cwd.createFile(io, path, .{});
    {
        var buffer: [32]u8 = undefined;
        var writer = file.writerStreaming(io, &buffer);
        try writer.interface.writeAll("file\n");
        try writer.interface.flush();
    }
    file.close(io);
    defer cwd.deleteFile(io, path) catch {};

    const Replay = struct {
        const Self = @This();

        bytes: []const u8,
        reader: std.Io.Reader = undefined,
        opens: usize = 0,

        fn open(context: *anyopaque) !streaming.ReplayReader {
            const self: *Self = @ptrCast(@alignCast(context));
            self.opens += 1;
            self.reader = std.Io.Reader.fixed(self.bytes);
            return .{ .reader = &self.reader };
        }
    };

    var reader = std.Io.Reader.fixed("reader\n");
    var replay = Replay{ .bytes = "replay\n" };
    const sources = [_]StreamingIngestSource{
        .{ .file = path },
        .{ .reader = .{ .reader = &reader, .raw_size = 7 } },
        .{ .replay_reader = .{
            .context = @ptrCast(&replay),
            .openFn = &Replay.open,
            .raw_size = 7,
        } },
    };

    for (sources, 0..) |source, index| {
        var executor = QueuedTestExecutor{};
        var manager = try initQueuedTestManager(allocator, &executor);
        defer manager.deinit();
        var transport = core.http.MockTransport.init(allocator, 201, "");
        defer transport.deinit();
        var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
        var result = try client.ingest(
            allocator,
            .{ .database = "DB", .table = "Table" },
            source,
            .{ .source_id = if (index == 0)
                "33333333-3333-4333-8333-333333333333"
            else if (index == 1)
                "44444444-4444-4444-8444-444444444444"
            else
                "55555555-5555-4555-8555-555555555555" },
        );
        defer result.deinit(allocator);
        try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
        try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    }
    try std.testing.expectEqual(@as(usize, 1), replay.opens);
}

test "queued gzip reader preserves raw length and uses bounded source reads" {
    const allocator = std.testing.allocator;
    const bytes = [_]u8{'x'} ** (128 * 1024);
    var source = std.Io.Reader.fixed(&bytes);
    var gzip: GzipReader = undefined;
    try gzip.init(&source, bytes.len);
    const compressed = try gzip.interface.allocRemaining(allocator, .unlimited);
    defer allocator.free(compressed);
    var compressed_reader = std.Io.Reader.fixed(compressed);
    var inflate_buffer: [std.compress.flate.max_window_len]u8 = undefined;
    var inflater = std.compress.flate.Decompress.init(
        &compressed_reader,
        .gzip,
        &inflate_buffer,
    );
    const restored = try inflater.reader.allocRemaining(allocator, .unlimited);
    defer allocator.free(restored);
    try std.testing.expectEqualSlices(u8, &bytes, restored);
}

test "queued retries known blob rejection with a stable ID and reports resources" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    const steps = [_]QueuedOutcomeTransport.Step{
        .{ .status = 403 },
        .{ .status = 201 },
        .{ .status = 201 },
        .{ .status = 201 },
    };
    var transport = QueuedOutcomeTransport{ .allocator = allocator, .steps = &steps };
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());

    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .bytes = "retry\n" },
        .{ .source_id = "66666666-6666-4666-8666-666666666666", .queued_max_resource_attempts = 2 },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
    try std.testing.expectEqualStrings("66666666-6666-4666-8666-666666666666", result.ingestion_id);
    try std.testing.expectEqual(@as(usize, 3), result.attempt_count);
    try std.testing.expectEqual(QueuedResourceAttemptOutcome.upload_rejected, result.attempts[0].outcome);
    try std.testing.expectEqual(QueuedResourceAttemptOutcome.uploaded, result.attempts[1].outcome);
    try std.testing.expectEqualStrings("accounta", result.attempts[0].attempt.account_name);
    try std.testing.expectEqualStrings("accountb", result.attempts[1].attempt.account_name);
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
}

test "queued one-shot reader does not retry after a Blob request" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    const steps = [_]QueuedOutcomeTransport.Step{
        .{ .status = 403 },
        .{ .status = 201 },
    };
    var transport = QueuedOutcomeTransport{ .allocator = allocator, .steps = &steps };
    var reader = std.Io.Reader.fixed("reader\n");
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());

    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .reader = .{ .reader = &reader, .raw_size = 7 } },
        .{ .source_id = "77777777-7777-4777-8777-777777777777", .queued_max_resource_attempts = 2 },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(QueuedSubmissionOutcome.pre_queue_failed, result.outcome);
    try std.testing.expectEqual(@as(usize, 1), result.attempt_count);
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    try std.testing.expectEqual(QueuedResourceAttemptOutcome.upload_rejected, result.attempts[0].outcome);
}

test "queued queue rejection is known and queue transport ambiguity is never duplicated" {
    const allocator = std.testing.allocator;

    {
        var executor = QueuedTestExecutor{};
        var manager = try initQueuedTestManager(allocator, &executor);
        defer manager.deinit();
        const steps = [_]QueuedOutcomeTransport.Step{
            .{ .status = 201 },
            .{ .status = 201 },
            .{ .status = 403 },
        };
        var transport = QueuedOutcomeTransport{ .allocator = allocator, .steps = &steps };
        var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
        var result = try client.ingest(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .bytes = "known\n" },
            .{ .source_id = "88888888-8888-4888-8888-888888888888", .queued_max_resource_attempts = 1 },
        );
        defer result.deinit(allocator);
        try std.testing.expectEqual(QueuedSubmissionOutcome.queue_rejected, result.outcome);
        try std.testing.expectEqual(@as(usize, 3), transport.call_count);
        try std.testing.expectEqual(QueuedResourceAttemptOutcome.queue_rejected, result.attempts[1].outcome);
        try std.testing.expectEqual(@as(?u16, 403), result.attempts[1].status_code);
    }

    {
        var executor = QueuedTestExecutor{};
        var manager = try initQueuedTestManager(allocator, &executor);
        defer manager.deinit();
        const steps = [_]QueuedOutcomeTransport.Step{
            .{ .status = 201 },
            .{ .status = 201 },
            .unknown,
            .{ .status = 201 },
        };
        var transport = QueuedOutcomeTransport{ .allocator = allocator, .steps = &steps };
        var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
        var result = try client.ingest(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .bytes = "unknown\n" },
            .{ .source_id = "99999999-9999-4999-8999-999999999999", .queued_max_resource_attempts = 2 },
        );
        defer result.deinit(allocator);
        try std.testing.expectEqual(QueuedSubmissionOutcome.queue_unknown, result.outcome);
        try std.testing.expectEqual(@as(usize, 3), transport.call_count);
        try std.testing.expectEqual(QueuedResourceAttemptOutcome.queue_unknown, result.attempts[1].outcome);
    }
}

test "queued source IDs are canonical nonzero UUIDs" {
    const allocator = std.testing.allocator;
    const normalized = try makeLogicalSourceId(
        allocator,
        "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",
    );
    defer allocator.free(normalized);
    try std.testing.expectEqualStrings(
        "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        normalized,
    );
    try std.testing.expectError(
        error.InvalidQueuedSourceId,
        makeLogicalSourceId(allocator, "not-a-uuid"),
    );
    try std.testing.expectError(
        error.InvalidQueuedSourceId,
        makeLogicalSourceId(allocator, "00000000-0000-0000-0000-000000000000"),
    );

    const generated = try makeLogicalSourceId(allocator, null);
    defer allocator.free(generated);
    try validateQueuedSourceId(generated);
    try std.testing.expectEqual(@as(u8, '4'), generated[14]);
}

test "queued validation rejects invalid policies before requests" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
    const target: StreamingIngestTarget = .{ .database = "DB", .table = "Table" };
    const source: StreamingIngestSource = .{ .bytes = "data" };
    const source_id = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

    try std.testing.expectError(
        error.InvalidQueuedSourceId,
        client.ingest(allocator, target, source, .{ .source_id = "not-a-uuid" }),
    );
    try std.testing.expectError(
        error.InvalidQueuedValidationOptions,
        client.ingest(allocator, target, source, .{
            .source_id = source_id,
            .validation_policy = .{
                .validation_options = 3,
                .validation_implications = 0,
            },
        }),
    );
    try std.testing.expectError(
        error.InvalidQueuedValidationImplications,
        client.ingest(allocator, target, source, .{
            .source_id = source_id,
            .validation_policy = .{
                .validation_options = 0,
                .validation_implications = 2,
            },
        }),
    );
    try std.testing.expectError(
        error.QueuedBlobUriCompressionUnsupported,
        client.ingest(allocator, target, .{ .blob_uri = .{
            .uri = "https://existing.blob.core.windows.net/c/blob.gz?sig=source",
        } }, .{
            .source_id = source_id,
            .queued_compression = .gzip,
        }),
    );
    try std.testing.expectEqual(@as(usize, 0), executor.calls);
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

test "queued precompressed files preserve their extension and raw-size honesty" {
    const allocator = std.testing.allocator;
    const path = ".queued-ingest-precompressed.gz";
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();
    var file = try cwd.createFile(io, path, .{});
    {
        var buffer: [32]u8 = undefined;
        var writer = file.writerStreaming(io, &buffer);
        try writer.interface.writeAll("gzip");
        try writer.interface.flush();
    }
    file.close(io);
    defer cwd.deleteFile(io, path) catch {};

    const automatic = try sourceInfo(.{ .file = path }, .{});
    try std.testing.expect(automatic.raw_size == null);
    try std.testing.expectEqual(@as(?u64, 4), automatic.upload_size);
    try std.testing.expectEqualStrings(".gz", automatic.precompressed_extension.?);
    try std.testing.expect(!shouldGzip(automatic, .{}));
    const none = try sourceInfo(.{ .file = path }, .{ .queued_compression = .none });
    try std.testing.expect(!shouldGzip(none, .{ .queued_compression = .none }));
    const supplied = try sourceInfo(.{ .file = path }, .{ .raw_size = 123 });
    try std.testing.expectEqual(@as(?u64, 123), supplied.raw_size);
    const forced = try sourceInfo(.{ .file = path }, .{ .queued_compression = .gzip });
    try std.testing.expectEqual(@as(?u64, 4), forced.raw_size);
    try std.testing.expect(forced.precompressed_extension == null);
    try std.testing.expect(shouldGzip(forced, .{ .queued_compression = .gzip }));
    try std.testing.expectEqualStrings(".ZIP", precompressedFileExtension("input.ZIP").?);

    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .file = path },
        .{ .source_id = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb" },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
    try std.testing.expect(result.raw_size == null);
    // One Put Blob plus the Queue post proves automatic compression did not
    // stage another gzip stream.
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    const json = try queueMessageJson(allocator, transport.last_body.?);
    defer allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, ".gz?sig=blob-") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"RawDataSize\"") == null);
}

test "queued source message time is independent of extent creation time" {
    const allocator = std.testing.allocator;
    const message = try buildQueueMessage(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .creation_time_unix_ms = 0 },
        "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
        1,
        "https://account.blob.core.windows.net/container/blob?sig=opaque",
        "identity-context",
        1_000,
        null,
    );
    defer allocator.free(message);
    try std.testing.expect(
        std.mem.indexOf(
            u8,
            message,
            "\"SourceMessageCreationTime\":\"1970-01-01T00:00:01.000Z\"",
        ) != null,
    );
    try std.testing.expect(
        std.mem.indexOf(
            u8,
            message,
            "\"creationTime\":\"1970-01-01T00:00:00.000Z\"",
        ) != null,
    );
}

test "queued rejection retries without reopening a one-shot reader" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    const steps = [_]QueuedOutcomeTransport.Step{
        .{ .status = 201 },
        .{ .status = 201 },
        .{ .status = 403 },
        .{ .status = 201 },
    };
    var transport = QueuedOutcomeTransport{ .allocator = allocator, .steps = &steps };
    var reader = std.Io.Reader.fixed("reader\n");
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .reader = .{ .reader = &reader, .raw_size = 7 } },
        .{
            .source_id = "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
            .queued_max_resource_attempts = 2,
        },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
    try std.testing.expectEqual(@as(usize, 3), result.attempt_count);
    try std.testing.expectEqual(
        QueuedResourceAttemptOutcome.queue_rejected,
        result.attempts[1].outcome,
    );
    try std.testing.expectEqual(
        QueuedResourceAttemptOutcome.queue_accepted,
        result.attempts[2].outcome,
    );
    try std.testing.expectEqualStrings("accounta", result.attempts[1].attempt.account_name);
    try std.testing.expectEqualStrings("accountb", result.attempts[2].attempt.account_name);
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
}

test "queued result diagnostics use the caller allocator" {
    const allocator = std.testing.allocator;
    var manager_arena = std.heap.ArenaAllocator.init(allocator);
    defer manager_arena.deinit();
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(manager_arena.allocator(), &executor);
    defer manager.deinit();
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
    var result = try client.ingest(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .bytes = "owned\n" },
        .{ .source_id = "ffffffff-ffff-4fff-8fff-ffffffffffff" },
    );
    defer result.deinit(allocator);

    try std.testing.expectEqual(QueuedSubmissionOutcome.queue_accepted, result.outcome);
    try std.testing.expectEqual(@as(usize, 2), result.attempt_count);
}

test "queued compatibility result transfers resource-manager Kusto errors" {
    const FailingExecutor = struct {
        calls: usize = 0,

        fn asExecutor(self: *@This()) resources.ResourceCommandExecutor {
            return .{ .context = self, .executeFn = &execute };
        }

        fn execute(
            context: *anyopaque,
            allocator: std.mem.Allocator,
            _: []const u8,
            _: []const u8,
        ) !kusto_common.KustoResult(data_result.KustoResponseDataSet) {
            const self: *@This() = @ptrCast(@alignCast(context));
            self.calls += 1;
            return .{ .err = .{
                .allocator = allocator,
                .operation = .management,
                .source = .http,
                .outcome = .known_not_accepted,
                .http_status = 503,
            } };
        }
    };

    const allocator = std.testing.allocator;
    var executor = FailingExecutor{};
    var manager = try resources.ResourceManager.init(
        allocator,
        std.testing.io,
        executor.asExecutor(),
        "db",
        .{},
    );
    defer manager.deinit();
    var transport = core.http.MockTransport.init(allocator, 201, "");
    defer transport.deinit();
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
    var result = try client.ingestFromBlobResult(
        allocator,
        .{ .database = "DB", .table = "Table", .format = .json },
        "https://existing.blob.core.windows.net/c/blob?sig=source",
    );
    switch (result) {
        .err => |*failure| {
            defer failure.deinit();
            try std.testing.expectEqual(@as(?u16, 503), failure.http_status);
        },
        .ok => |*ingestion| {
            ingestion.deinit(allocator);
            return error.TestUnexpectedResult;
        },
        .partial => unreachable,
    }
    try std.testing.expectEqual(@as(usize, 1), executor.calls);
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

test "queued compatibility result keeps storage rejection explicit" {
    const allocator = std.testing.allocator;
    var executor = QueuedTestExecutor{};
    var manager = try initQueuedTestManager(allocator, &executor);
    defer manager.deinit();
    var transport = core.http.MockTransport.init(allocator, 403, "denied");
    defer transport.deinit();
    var client = QueuedIngestClient.initWithResourceManager(&manager, transport.asTransport());
    var result = try client.ingestFromBlobResult(
        allocator,
        .{
            .database = "DB",
            .table = "Table",
            .format = .json,
            .source_id = "12121212-1212-4212-8212-121212121212",
        },
        "https://existing.blob.core.windows.net/c/blob?sig=source",
    );
    switch (result) {
        .ok => |*ingestion| {
            defer ingestion.deinit(allocator);
            try std.testing.expectEqual(streaming.IngestionStatus.failed, ingestion.status);
            try std.testing.expectEqual(
                kusto_common.KustoOperationOutcome.known_not_accepted,
                ingestion.outcome,
            );
        },
        .err => |*failure| {
            failure.deinit();
            return error.TestUnexpectedResult;
        },
        .partial => unreachable,
    }
}

fn queueMessageAllocationTest(allocator: std.mem.Allocator) !void {
    const message = try buildQueueMessage(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{
            .format = .json,
            .mapping_name = "Map",
            .tags = &.{"tag"},
            .drop_by_tags = &.{"drop"},
            .ingest_if_not_exists = &.{"dedup"},
            .validation_policy = .{
                .validation_options = 1,
                .validation_implications = 1,
            },
            .creation_time_unix_ms = 0,
        },
        "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
        11,
        "https://account.blob.core.windows.net/container/blob.gz?sig=opaque",
        "identity-context",
        1_000,
        null,
    );
    defer allocator.free(message);
}

test "queued message construction cleans up every allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        queueMessageAllocationTest,
        .{},
    );
}
