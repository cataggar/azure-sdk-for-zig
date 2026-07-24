//! Queued-ingestion resource discovery and selection.
//!
//! This module deliberately stops before upload, queue posting, or status
//! polling. It owns the service-issued SAS URIs and authorization context, and
//! never renders either secret in diagnostics.
const std = @import("std");
const core = @import("azure_sdk_core");
const kusto_common = @import("kusto_common_internal");
const data_result = @import("kusto_data_internal");

pub const default_cache_ttl_ms: i64 = 60 * 60 * 1_000;
pub const default_expiry_safety_skew_ms: i64 = 2 * 60 * 1_000;
pub const default_resource_database = "NetDefaultDB";

pub const ResourceService = enum {
    blob,
    queue,
    table,
};

pub const ResourceKind = enum {
    secured_ready_for_aggregation_queue,
    temporary_blob_container,
    successful_ingestion_queue,
    failed_ingestion_queue,
    ingestion_status_queue,
    ingestion_status_table,

    fn service(self: ResourceKind) ResourceService {
        return switch (self) {
            .temporary_blob_container => .blob,
            .secured_ready_for_aggregation_queue,
            .successful_ingestion_queue,
            .failed_ingestion_queue,
            .ingestion_status_queue,
            => .queue,
            .ingestion_status_table => .table,
        };
    }
};

/// An owned, complete service-issued SAS URI.
///
/// `uri()` is intentionally the only way to obtain the secret URI. Callers
/// must pass it directly to an isolated SAS client and must not log it.
pub const StorageResource = struct {
    service: ResourceService,
    bytes: []u8,
    query_start: usize,
    account_name: []u8,

    pub fn init(
        allocator: std.mem.Allocator,
        service: ResourceService,
        value: []const u8,
    ) !StorageResource {
        const parsed = try parseStorageResource(value, service);
        const bytes = try allocator.dupe(u8, value);
        errdefer allocator.free(bytes);
        const account_name = try allocator.dupe(u8, parsed.account_name);
        return .{
            .service = service,
            .bytes = bytes,
            .query_start = parsed.query_start,
            .account_name = account_name,
        };
    }

    pub fn clone(self: *const StorageResource, allocator: std.mem.Allocator) !StorageResource {
        const bytes = try allocator.dupe(u8, self.bytes);
        errdefer allocator.free(bytes);
        const account_name = try allocator.dupe(u8, self.account_name);
        return .{
            .service = self.service,
            .bytes = bytes,
            .query_start = self.query_start,
            .account_name = account_name,
        };
    }

    pub fn deinit(self: *StorageResource, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        allocator.free(self.account_name);
        self.* = undefined;
    }

    /// Returns the complete SAS URI. Treat the returned slice as secret.
    pub fn uri(self: *const StorageResource) []const u8 {
        return self.bytes;
    }

    pub fn accountName(self: *const StorageResource) []const u8 {
        return self.account_name;
    }

    /// Renders only the URI origin and path; the complete SAS query is never
    /// formatted, copied to a log, or reconstructed.
    pub fn format(self: StorageResource, writer: anytype) !void {
        try writer.print(
            "StorageResource(service={s}, uri={s}?***)",
            .{ @tagName(self.service), self.bytes[0..self.query_start] },
        );
    }
};

/// A service-issued Kusto authorization context. Its value is secret.
pub const AuthorizationContext = struct {
    value: []u8,

    pub fn clone(self: *const AuthorizationContext, allocator: std.mem.Allocator) !AuthorizationContext {
        return .{ .value = try allocator.dupe(u8, self.value) };
    }

    pub fn deinit(self: *AuthorizationContext, allocator: std.mem.Allocator) void {
        if (self.value.len != 0) allocator.free(self.value);
        self.* = undefined;
    }

    /// Returns the authorization context. Treat this value as secret.
    pub fn token(self: *const AuthorizationContext) []const u8 {
        return self.value;
    }

    pub fn format(_: AuthorizationContext, writer: anytype) !void {
        try writer.writeAll("AuthorizationContext(***)");
    }
};

/// An immutable, wholly owned discovery result. Clone it before retaining it
/// beyond the owner that returned it.
pub const IngestionResourceSnapshot = struct {
    secured_ready_for_aggregation_queues: []StorageResource,
    temporary_blob_containers: []StorageResource,
    successful_ingestion_queues: []StorageResource,
    failed_ingestion_queues: []StorageResource,
    ingestion_status_queues: []StorageResource,
    ingestion_status_tables: []StorageResource,
    authorization_context: AuthorizationContext,
    expires_at_ms: i64,
    hard_expires_at_ms: ?i64 = null,
    generation: u64 = 0,

    pub fn clone(self: *const IngestionResourceSnapshot, allocator: std.mem.Allocator) !IngestionResourceSnapshot {
        var copy = IngestionResourceSnapshot{
            .secured_ready_for_aggregation_queues = &.{},
            .temporary_blob_containers = &.{},
            .successful_ingestion_queues = &.{},
            .failed_ingestion_queues = &.{},
            .ingestion_status_queues = &.{},
            .ingestion_status_tables = &.{},
            .authorization_context = .{ .value = &.{} },
            .expires_at_ms = self.expires_at_ms,
            .hard_expires_at_ms = self.hard_expires_at_ms,
            .generation = self.generation,
        };
        errdefer copy.deinit(allocator);
        copy.secured_ready_for_aggregation_queues = try cloneResources(
            allocator,
            self.secured_ready_for_aggregation_queues,
        );
        copy.temporary_blob_containers = try cloneResources(allocator, self.temporary_blob_containers);
        copy.successful_ingestion_queues = try cloneResources(allocator, self.successful_ingestion_queues);
        copy.failed_ingestion_queues = try cloneResources(allocator, self.failed_ingestion_queues);
        copy.ingestion_status_queues = try cloneResources(allocator, self.ingestion_status_queues);
        copy.ingestion_status_tables = try cloneResources(allocator, self.ingestion_status_tables);
        copy.authorization_context = try self.authorization_context.clone(allocator);
        return copy;
    }

    pub fn deinit(self: *IngestionResourceSnapshot, allocator: std.mem.Allocator) void {
        deinitResources(allocator, self.secured_ready_for_aggregation_queues);
        deinitResources(allocator, self.temporary_blob_containers);
        deinitResources(allocator, self.successful_ingestion_queues);
        deinitResources(allocator, self.failed_ingestion_queues);
        deinitResources(allocator, self.ingestion_status_queues);
        deinitResources(allocator, self.ingestion_status_tables);
        self.authorization_context.deinit(allocator);
        self.* = undefined;
    }

    /// Returns one resource category without transferring ownership.
    pub fn resources(self: *const IngestionResourceSnapshot, kind: ResourceKind) []const StorageResource {
        return switch (kind) {
            .secured_ready_for_aggregation_queue => self.secured_ready_for_aggregation_queues,
            .temporary_blob_container => self.temporary_blob_containers,
            .successful_ingestion_queue => self.successful_ingestion_queues,
            .failed_ingestion_queue => self.failed_ingestion_queues,
            .ingestion_status_queue => self.ingestion_status_queues,
            .ingestion_status_table => self.ingestion_status_tables,
        };
    }

    /// Emits counts and expiry only. Resource SAS URIs and authorization
    /// context are deliberately absent.
    pub fn format(self: IngestionResourceSnapshot, writer: anytype) !void {
        try writer.print(
            "IngestionResourceSnapshot(ready_queues={d}, containers={d}, successful_queues={d}, failed_queues={d}, status_queues={d}, status_tables={d}, expires_at_ms={d}, hard_expires_at_ms={?d}, generation={d})",
            .{
                self.secured_ready_for_aggregation_queues.len,
                self.temporary_blob_containers.len,
                self.successful_ingestion_queues.len,
                self.failed_ingestion_queues.len,
                self.ingestion_status_queues.len,
                self.ingestion_status_tables.len,
                self.expires_at_ms,
                self.hard_expires_at_ms,
                self.generation,
            },
        );
    }
};

/// A self-contained snapshot lease. It remains valid after a manager refresh
/// because it is a deep copy, not a borrowed manager pointer.
pub const ResourceSnapshotLease = struct {
    snapshot: IngestionResourceSnapshot,
    stale: bool = false,
    refresh_failure: ?kusto_common.KustoError = null,

    pub fn deinit(self: *ResourceSnapshotLease, allocator: std.mem.Allocator) void {
        self.snapshot.deinit(allocator);
        if (self.refresh_failure) |*failure| failure.deinit();
        self.* = undefined;
    }

    pub fn format(self: ResourceSnapshotLease, writer: anytype) !void {
        try writer.print(
            "ResourceSnapshotLease(snapshot={f}, stale={})",
            .{ self.snapshot, self.stale },
        );
    }
};

pub const ResourceSnapshotResult = union(enum) {
    ok: ResourceSnapshotLease,
    err: kusto_common.KustoError,

    pub fn deinit(self: *ResourceSnapshotResult, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .ok => |*lease| lease.deinit(allocator),
            .err => |*failure| failure.deinit(),
        }
    }
};

/// The attempt context is retained by a selection rather than derived later
/// from mutable manager state. It is safe to report after a snapshot refresh.
pub const ResourceAttempt = struct {
    kind: ResourceKind,
    account_name: []u8,
    generation: u64,

    pub fn deinit(self: *ResourceAttempt, allocator: std.mem.Allocator) void {
        if (self.account_name.len != 0) allocator.free(self.account_name);
        self.* = undefined;
    }
};

pub const ResourceSelection = struct {
    resource: StorageResource,
    attempt: ResourceAttempt,
    /// The service-issued identity context paired with this resource snapshot.
    /// It is secret and must be used only inside the queued-ingestion message.
    authorization_context: AuthorizationContext = .{ .value = &.{} },
    stale: bool = false,
    refresh_failure: ?kusto_common.KustoError = null,

    pub fn deinit(self: *ResourceSelection, allocator: std.mem.Allocator) void {
        self.resource.deinit(allocator);
        self.attempt.deinit(allocator);
        self.authorization_context.deinit(allocator);
        if (self.refresh_failure) |*failure| failure.deinit();
        self.* = undefined;
    }

    pub fn format(self: ResourceSelection, writer: anytype) !void {
        try writer.print(
            "ResourceSelection(resource={f}, kind={s}, account={s}, generation={d}, stale={})",
            .{
                self.resource,
                @tagName(self.attempt.kind),
                self.attempt.account_name,
                self.attempt.generation,
                self.stale,
            },
        );
    }
};

pub const ResourceSelectionResult = union(enum) {
    ok: ResourceSelection,
    err: kusto_common.KustoError,

    pub fn deinit(self: *ResourceSelectionResult, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .ok => |*selection| selection.deinit(allocator),
            .err => |*failure| failure.deinit(),
        }
    }
};

/// Supplies an already serialized-safe execution path for resource discovery.
///
/// ResourceManager coalesces its own calls but performs an executor invocation
/// outside its state lock. Therefore the executor must be safe for concurrent
/// calls, or the caller must serialize it with every other user of its
/// connection. `DataManagementCommandExecutor` borrows a KustoConnection and
/// is explicitly *not* concurrent-safe because KustoConnection is not.
pub const ResourceCommandExecutor = struct {
    context: *anyopaque,
    executeFn: *const fn (
        context: *anyopaque,
        allocator: std.mem.Allocator,
        database: []const u8,
        command: []const u8,
    ) anyerror!kusto_common.KustoResult(data_result.KustoResponseDataSet),

    pub fn execute(
        self: ResourceCommandExecutor,
        allocator: std.mem.Allocator,
        database: []const u8,
        command: []const u8,
    ) !kusto_common.KustoResult(data_result.KustoResponseDataSet) {
        return self.executeFn(self.context, allocator, database, command);
    }
};

/// Authenticated, non-retryable data-management command executor.
///
/// It always targets `KustoConnection.dataManagementUrl()` rather than the
/// engine endpoint. The borrowed connection and everything it borrows must
/// outlive this executor. It has no deinit method.
pub const DataManagementCommandExecutor = struct {
    connection: *kusto_common.KustoConnection,
    application_name: []const u8 = "azure-sdk-zig",
    client_version: []const u8 = "azsdk-zig-kusto/0.1.0",

    pub const supports_concurrent_use = false;

    pub fn initWithConnection(connection: *kusto_common.KustoConnection) DataManagementCommandExecutor {
        return .{ .connection = connection };
    }

    pub fn asExecutor(self: *DataManagementCommandExecutor) ResourceCommandExecutor {
        return .{ .context = self, .executeFn = &execute };
    }

    fn execute(
        context: *anyopaque,
        allocator: std.mem.Allocator,
        database: []const u8,
        command: []const u8,
    ) !kusto_common.KustoResult(data_result.KustoResponseDataSet) {
        const self: *DataManagementCommandExecutor = @ptrCast(@alignCast(context));
        const dm_url = self.connection.dataManagementUrl() orelse
            return error.KustoDataManagementEndpointUnavailable;
        const url = try std.fmt.allocPrint(allocator, "{s}/v1/rest/mgmt", .{dm_url});
        defer allocator.free(url);

        const properties = kusto_common.ClientRequestProperties{};
        const body = try kusto_common.serializeRequestBody(
            allocator,
            database,
            command,
            properties,
            .management,
        );
        defer allocator.free(body);

        var request = core.http.Request.init(allocator, .POST, url);
        defer request.deinit();
        try request.setHeader("Content-Type", "application/json; charset=utf-8");
        try request.setHeader("Accept", "application/json");
        try request.setHeader("Accept-Encoding", "gzip, deflate");
        try request.setHeader("x-ms-app", self.application_name);
        try request.setHeader("x-ms-client-version", self.client_version);
        try request.setHeader("x-ms-version", "2024-12-12");
        try core.pipeline.ensureRequestId(&request);
        request.operation_timeout_ms = try properties.effectiveClientTimeoutMs(.management);
        request.body = body;
        // Discovery commands are read-only but intentionally non-retryable:
        // resource-manager policy decides when to retry a failed refresh.
        request.retryable = false;

        var response = try self.connection.send(&request);
        defer response.deinit();
        if (!response.isSuccess()) {
            var failure = try kusto_common.errors.fromHttpResponse(
                allocator,
                .management,
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

        var decoded = try data_result.decodeResponseDataSet(
            allocator,
            response.body,
            .{},
            .management,
        );
        errdefer decoded.deinit(allocator);
        const response_request_id = response.getHeader("x-ms-client-request-id") orelse
            request.getHeader("x-ms-client-request-id");
        if (response_request_id) |request_id|
            decoded.dataset.client_request_id = try allocator.dupe(u8, request_id);
        if (response.getHeader("x-ms-activity-id")) |activity_id|
            decoded.dataset.activity_id = try allocator.dupe(u8, activity_id);
        if (decoded.failure) |*failure| {
            try kusto_common.errors.applyResponseCorrelation(
                failure,
                &response,
                request.getHeader("x-ms-client-request-id"),
            );
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

pub const TimeSource = struct {
    context: *anyopaque,
    nowMsFn: *const fn (context: *anyopaque) i64,

    /// Concurrent manager use requires this callback and its context to be
    /// safe for concurrent calls.
    pub fn nowMs(self: TimeSource) i64 {
        return self.nowMsFn(self.context);
    }
};

pub const ResourceManagerOptions = struct {
    /// Default maximum lifetime when the service does not provide an earlier
    /// SAS `se` expiry. Must be positive.
    cache_ttl_ms: i64 = default_cache_ttl_ms,
    /// Subtracted from parsed SAS expirations. Must be nonnegative.
    expiry_safety_skew_ms: i64 = default_expiry_safety_skew_ms,
    /// A deterministic clock is useful for tests. The default is wall clock.
    time_source: ?TimeSource = null,
};

const AccountScore = struct {
    account_name: []u8,
    score: i32 = 0,

    fn deinit(self: *AccountScore, allocator: std.mem.Allocator) void {
        allocator.free(self.account_name);
        self.* = undefined;
    }
};

/// Synchronized cache, coalescing refresh coordinator, and deterministic
/// resource selector. Concurrent use requires concurrent-safe allocator and
/// clock dependencies. Do not move or deinitialize it while calls are active.
pub const ResourceManager = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    executor: ResourceCommandExecutor,
    database: []u8,
    cache_ttl_ms: i64,
    expiry_safety_skew_ms: i64,
    time_source: ?TimeSource,
    mutex: std.Io.Mutex = .init,
    refresh_finished: std.Io.Condition = .init,
    refreshing: bool = false,
    waiting_callers: usize = 0,
    refresh_epoch: u64 = 0,
    snapshot: ?IngestionResourceSnapshot = null,
    last_refresh_failure: ?kusto_common.KustoError = null,
    last_refresh_local_error: ?anyerror = null,
    account_scores: std.ArrayList(AccountScore) = .empty,
    cursors: [resource_kind_count]u64 = [_]u64{0} ** resource_kind_count,
    next_generation: u64 = 1,

    /// Manager methods may be called concurrently only when the supplied
    /// allocator and optional TimeSource are also concurrent-safe. Leases are
    /// deinitialized by callers and therefore retain the same requirement.
    pub const supports_concurrent_use_with_thread_safe_dependencies = true;

    /// `allocator` and `options.time_source`, when present, must support
    /// concurrent calls if the returned manager will be used concurrently.
    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        executor: ResourceCommandExecutor,
        database: []const u8,
        options: ResourceManagerOptions,
    ) !ResourceManager {
        if (database.len == 0) return error.KustoDatabaseRequired;
        if (options.cache_ttl_ms <= 0) return error.InvalidResourceCacheTtl;
        if (options.expiry_safety_skew_ms < 0) return error.InvalidResourceExpirySafetySkew;
        return .{
            .allocator = allocator,
            .io = io,
            .executor = executor,
            .database = try allocator.dupe(u8, database),
            .cache_ttl_ms = options.cache_ttl_ms,
            .expiry_safety_skew_ms = options.expiry_safety_skew_ms,
            .time_source = options.time_source,
        };
    }

    /// Requires that no callers are using or waiting on this manager.
    pub fn deinit(self: *ResourceManager) void {
        self.mutex.lockUncancelable(self.io);
        std.debug.assert(!self.refreshing);
        std.debug.assert(self.waiting_callers == 0);
        if (self.snapshot) |*snapshot| snapshot.deinit(self.allocator);
        if (self.last_refresh_failure) |*failure| failure.deinit();
        for (self.account_scores.items) |*entry| entry.deinit(self.allocator);
        self.account_scores.deinit(self.allocator);
        self.allocator.free(self.database);
        self.mutex.unlock(self.io);
        self.* = undefined;
    }

    /// Returns a deep-copy lease of a valid cached snapshot. Expired snapshots
    /// are returned only after a classified transient service refresh failure.
    pub fn getSnapshot(self: *ResourceManager) !ResourceSnapshotResult {
        var waited_epoch: ?u64 = null;
        while (true) {
            const now_ms = self.nowMs();
            self.mutex.lockUncancelable(self.io);
            if (self.snapshot) |*snapshot| {
                if (snapshot.expires_at_ms > now_ms) {
                    const lease = snapshotLease(self.allocator, snapshot, false, null) catch |err| {
                        self.mutex.unlock(self.io);
                        return err;
                    };
                    self.mutex.unlock(self.io);
                    return .{ .ok = lease };
                }
            }
            if (waited_epoch) |epoch| {
                if (self.refresh_epoch != epoch) {
                    if (self.last_refresh_local_error) |err| {
                        self.mutex.unlock(self.io);
                        return err;
                    }
                    if (self.last_refresh_failure) |*failure| {
                        if (failure.retryable and self.snapshot != null) {
                            if (!canUseStale(&self.snapshot.?, now_ms)) {
                                const failure_copy = cloneKustoError(self.allocator, failure) catch |err| {
                                    self.mutex.unlock(self.io);
                                    return err;
                                };
                                self.mutex.unlock(self.io);
                                return .{ .err = failure_copy };
                            }
                            const lease = snapshotLease(
                                self.allocator,
                                &self.snapshot.?,
                                true,
                                failure,
                            ) catch |err| {
                                self.mutex.unlock(self.io);
                                return err;
                            };
                            self.mutex.unlock(self.io);
                            return .{ .ok = lease };
                        }
                        const failure_copy = cloneKustoError(self.allocator, failure) catch |err| {
                            self.mutex.unlock(self.io);
                            return err;
                        };
                        self.mutex.unlock(self.io);
                        return .{ .err = failure_copy };
                    }
                    if (self.snapshot) |*snapshot| {
                        const lease = snapshotLease(self.allocator, snapshot, false, null) catch |err| {
                            self.mutex.unlock(self.io);
                            return err;
                        };
                        self.mutex.unlock(self.io);
                        return .{ .ok = lease };
                    }
                }
            }
            if (self.refreshing) {
                waited_epoch = self.refresh_epoch;
                self.waiting_callers += 1;
                self.refresh_finished.waitUncancelable(self.io, &self.mutex);
                self.waiting_callers -= 1;
                self.mutex.unlock(self.io);
                continue;
            }
            self.refreshing = true;
            self.mutex.unlock(self.io);

            var refresh_result = self.refresh() catch |err| {
                self.finishLocalRefresh(err);
                return err;
            };
            switch (refresh_result) {
                .ok => |*new_snapshot| {
                    const completed_now_ms = self.nowMs();
                    if (new_snapshot.expires_at_ms <= completed_now_ms) {
                        new_snapshot.deinit(self.allocator);
                        self.finishLocalRefresh(error.IngestionResourceSnapshotExpired);
                        return error.IngestionResourceSnapshotExpired;
                    }
                    self.mutex.lockUncancelable(self.io);
                    new_snapshot.generation = self.next_generation;
                    self.next_generation +%= 1;
                    ensureAccountScores(self, new_snapshot) catch |err| {
                        self.mutex.unlock(self.io);
                        new_snapshot.deinit(self.allocator);
                        self.finishLocalRefresh(err);
                        return err;
                    };
                    if (self.snapshot) |*old| old.deinit(self.allocator);
                    self.snapshot = new_snapshot.*;
                    refresh_result = undefined;
                    clearLastRefreshFailure(self);
                    self.last_refresh_local_error = null;
                    self.completeRefreshLocked();
                    const lease = snapshotLease(self.allocator, &self.snapshot.?, false, null) catch |err| {
                        self.mutex.unlock(self.io);
                        return err;
                    };
                    self.mutex.unlock(self.io);
                    return .{ .ok = lease };
                },
                .service_failure => |*failure| {
                    const failure_now_ms = self.nowMs();
                    self.mutex.lockUncancelable(self.io);
                    const stored = cloneKustoError(self.allocator, failure) catch |err| {
                        self.mutex.unlock(self.io);
                        failure.deinit();
                        self.finishLocalRefresh(err);
                        return err;
                    };
                    clearLastRefreshFailure(self);
                    self.last_refresh_failure = stored;
                    self.last_refresh_local_error = null;
                    self.completeRefreshLocked();
                    const can_use_stale = failure.retryable and
                        self.snapshot != null and
                        canUseStale(&self.snapshot.?, failure_now_ms);
                    if (can_use_stale) {
                        const lease = snapshotLease(
                            self.allocator,
                            &self.snapshot.?,
                            true,
                            failure,
                        ) catch |err| {
                            self.mutex.unlock(self.io);
                            failure.deinit();
                            return err;
                        };
                        self.mutex.unlock(self.io);
                        failure.deinit();
                        return .{ .ok = lease };
                    }
                    self.mutex.unlock(self.io);
                    const owned_failure = failure.*;
                    refresh_result = undefined;
                    return .{ .err = owned_failure };
                },
            }
        }
    }

    /// Returns a copy of the most recent refresh service failure, including a
    /// transient failure that produced a stale lease.
    pub fn lastRefreshFailure(self: *ResourceManager) !?kusto_common.KustoError {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        if (self.last_refresh_failure) |*failure|
            return try cloneKustoError(self.allocator, failure);
        return null;
    }

    /// Select a resource without wrapping it in a snapshot. This is the
    /// selection API intended for queued-ingestion work once it is added.
    pub fn selectResource(self: *ResourceManager, kind: ResourceKind) !ResourceSelectionResult {
        return self.selectResourceExcluding(kind, &.{});
    }

    /// Selects a resource while preferring accounts not already attempted by
    /// the current logical operation. If every available account is excluded,
    /// selection falls back to the ranked set so a single-account deployment
    /// can still retry a received rejection.
    pub fn selectResourceExcluding(
        self: *ResourceManager,
        kind: ResourceKind,
        excluded_attempts: []const ResourceAttempt,
    ) !ResourceSelectionResult {
        var lease_result = try self.getSnapshot();
        switch (lease_result) {
            .err => |*failure| {
                const owned_failure = failure.*;
                lease_result = undefined;
                return .{ .err = owned_failure };
            },
            .ok => |*lease| {
                var owned_lease = lease.*;
                lease_result = undefined;
                defer owned_lease.deinit(self.allocator);
                const choices = owned_lease.snapshot.resources(kind);
                if (choices.len == 0) return error.NoUsableIngestionResource;

                self.mutex.lockUncancelable(self.io);
                defer self.mutex.unlock(self.io);
                const choice_index = try self.nextSelectionIndex(
                    kind,
                    choices,
                    excluded_attempts,
                );
                const resource = try choices[choice_index].clone(self.allocator);
                errdefer {
                    var mutable_resource = resource;
                    mutable_resource.deinit(self.allocator);
                }
                const account_name = try self.allocator.dupe(u8, choices[choice_index].account_name);
                errdefer self.allocator.free(account_name);
                var refresh_failure = if (owned_lease.refresh_failure) |*failure|
                    try cloneKustoError(self.allocator, failure)
                else
                    null;
                errdefer if (refresh_failure) |*failure| failure.deinit();
                const authorization_context = try owned_lease.snapshot.authorization_context.clone(
                    self.allocator,
                );
                errdefer {
                    var mutable_context = authorization_context;
                    mutable_context.deinit(self.allocator);
                }
                return .{ .ok = .{
                    .resource = resource,
                    .attempt = .{
                        .kind = kind,
                        .account_name = account_name,
                        .generation = owned_lease.snapshot.generation,
                    },
                    .authorization_context = authorization_context,
                    .stale = owned_lease.stale,
                    .refresh_failure = refresh_failure,
                } };
            },
        }
    }

    /// Records a resource attempt by its retained context. Scores saturate,
    /// and an account remains score-tracked after a snapshot replacement.
    pub fn reportAttempt(
        self: *ResourceManager,
        attempt: *const ResourceAttempt,
        success: bool,
    ) !void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        const score = try self.scoreForAccount(attempt.account_name);
        if (success) {
            score.score = std.math.add(i32, score.score, 1) catch std.math.maxInt(i32);
        } else {
            score.score = std.math.sub(i32, score.score, 1) catch std.math.minInt(i32);
        }
    }

    /// Records an attempt known to have selected one of this manager's
    /// resources without allocating. This is for post-acceptance paths where
    /// an allocation failure must not replace an already accepted operation.
    pub fn reportAttemptNoAlloc(
        self: *ResourceManager,
        attempt: *const ResourceAttempt,
        success: bool,
    ) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        for (self.account_scores.items) |*score| {
            if (!std.mem.eql(u8, score.account_name, attempt.account_name)) continue;
            if (success) {
                score.score = std.math.add(i32, score.score, 1) catch std.math.maxInt(i32);
            } else {
                score.score = std.math.sub(i32, score.score, 1) catch std.math.minInt(i32);
            }
            return;
        }
        std.debug.assert(false);
    }

    /// Releases a selection using the allocator that owns every selection
    /// member. Callers using a different per-operation allocator must use this
    /// method instead of `ResourceSelection.deinit` directly.
    pub fn deinitSelection(
        self: *ResourceManager,
        selection: *ResourceSelection,
    ) void {
        selection.deinit(self.allocator);
    }

    fn refresh(self: *ResourceManager) !RefreshResult {
        var resources_result = try self.executor.execute(
            self.allocator,
            self.database,
            ".get ingestion resources",
        );
        var resource_dataset = switch (resources_result) {
            .ok => |dataset| dataset,
            .partial => |*partial| {
                var dataset = partial.value;
                dataset.deinit(self.allocator);
                const failure = partial.failure;
                resources_result = undefined;
                return .{ .service_failure = failure };
            },
            .err => |*failure| {
                const owned_failure = failure.*;
                resources_result = undefined;
                return .{ .service_failure = owned_failure };
            },
        };
        resources_result = undefined;
        defer resource_dataset.deinit(self.allocator);

        var token_result = try self.executor.execute(
            self.allocator,
            self.database,
            ".get kusto identity token",
        );
        var token_dataset = switch (token_result) {
            .ok => |dataset| dataset,
            .partial => |*partial| {
                var dataset = partial.value;
                dataset.deinit(self.allocator);
                const failure = partial.failure;
                token_result = undefined;
                return .{ .service_failure = failure };
            },
            .err => |*failure| {
                const owned_failure = failure.*;
                token_result = undefined;
                return .{ .service_failure = owned_failure };
            },
        };
        token_result = undefined;
        defer token_dataset.deinit(self.allocator);

        const now_ms = self.nowMs();
        return .{ .ok = try decodeSnapshot(
            self.allocator,
            &resource_dataset,
            &token_dataset,
            now_ms,
            self.cache_ttl_ms,
            self.expiry_safety_skew_ms,
        ) };
    }

    fn finishLocalRefresh(self: *ResourceManager, err: anyerror) void {
        self.mutex.lockUncancelable(self.io);
        clearLastRefreshFailure(self);
        self.last_refresh_local_error = err;
        self.completeRefreshLocked();
        self.mutex.unlock(self.io);
    }

    fn completeRefreshLocked(self: *ResourceManager) void {
        self.refresh_epoch +%= 1;
        self.refreshing = false;
        self.refresh_finished.broadcast(self.io);
    }

    fn nowMs(self: *const ResourceManager) i64 {
        if (self.time_source) |source| return source.nowMs();
        var threaded: std.Io.Threaded = .init_single_threaded;
        const milliseconds = @divFloor(
            std.Io.Timestamp.now(threaded.io(), .real).toNanoseconds(),
            std.time.ns_per_ms,
        );
        return std.math.cast(i64, milliseconds) orelse
            if (milliseconds < 0) std.math.minInt(i64) else std.math.maxInt(i64);
    }

    fn nextSelectionIndex(
        self: *ResourceManager,
        kind: ResourceKind,
        choices: []const StorageResource,
        excluded_attempts: []const ResourceAttempt,
    ) !usize {
        if (choices.len == 0) return error.NoUsableIngestionResource;
        const ordered = try self.allocator.alloc(usize, choices.len);
        defer self.allocator.free(ordered);
        for (ordered, 0..) |*item, index| item.* = index;
        std.mem.sort(usize, ordered, SelectionOrder{
            .choices = choices,
            .scores = self.account_scores.items,
        }, SelectionOrder.lessThan);
        const cursor_index = @intFromEnum(kind);
        const cursor = self.cursors[cursor_index];
        self.cursors[cursor_index] +%= 1;

        var account_count: usize = 0;
        var eligible_account_count: usize = 0;
        var previous_account: ?[]const u8 = null;
        for (ordered) |choice_index| {
            const account_name = choices[choice_index].account_name;
            if (previous_account == null or !std.mem.eql(u8, previous_account.?, account_name)) {
                account_count += 1;
                if (!accountWasAttempted(account_name, excluded_attempts))
                    eligible_account_count += 1;
                previous_account = account_name;
            }
        }
        std.debug.assert(account_count != 0);
        const use_exclusions = eligible_account_count != 0;
        const selection_account_count = if (use_exclusions)
            eligible_account_count
        else
            account_count;
        const target_account = cursor % selection_account_count;
        const resource_round = cursor / selection_account_count;
        var account_index: usize = 0;
        var ordered_index: usize = 0;
        while (ordered_index < ordered.len) {
            const first_choice = ordered[ordered_index];
            const account_name = choices[first_choice].account_name;
            var group_end = ordered_index + 1;
            while (group_end < ordered.len and
                std.mem.eql(u8, account_name, choices[ordered[group_end]].account_name))
            {
                group_end += 1;
            }
            if (use_exclusions and accountWasAttempted(account_name, excluded_attempts)) {
                ordered_index = group_end;
                continue;
            }
            if (account_index == target_account) {
                const group_len = group_end - ordered_index;
                const resource_offset = resource_round % group_len;
                return ordered[ordered_index + @as(usize, @intCast(resource_offset))];
            }
            account_index += 1;
            ordered_index = group_end;
        }
        unreachable;
    }

    fn scoreForAccount(self: *ResourceManager, account_name: []const u8) !*AccountScore {
        for (self.account_scores.items) |*entry| {
            if (std.mem.eql(u8, entry.account_name, account_name)) return entry;
        }
        const name = try self.allocator.dupe(u8, account_name);
        errdefer self.allocator.free(name);
        try self.account_scores.append(self.allocator, .{ .account_name = name });
        return &self.account_scores.items[self.account_scores.items.len - 1];
    }
};

fn accountWasAttempted(
    account_name: []const u8,
    attempts: []const ResourceAttempt,
) bool {
    for (attempts) |attempt| {
        if (std.mem.eql(u8, account_name, attempt.account_name)) return true;
    }
    return false;
}

const resource_kind_count = @typeInfo(ResourceKind).@"enum".fields.len;

const SelectionOrder = struct {
    choices: []const StorageResource,
    scores: []const AccountScore,

    fn lessThan(self: SelectionOrder, left: usize, right: usize) bool {
        const left_resource = self.choices[left];
        const right_resource = self.choices[right];
        const left_score = scoreFor(self.scores, left_resource.account_name);
        const right_score = scoreFor(self.scores, right_resource.account_name);
        if (left_score != right_score) return left_score > right_score;
        const account_order = std.mem.order(u8, left_resource.account_name, right_resource.account_name);
        if (account_order != .eq) return account_order == .lt;
        return left < right;
    }
};

const RefreshResult = union(enum) {
    ok: IngestionResourceSnapshot,
    service_failure: kusto_common.KustoError,
};

const ParsedStorageResource = struct {
    query_start: usize,
    account_name: []const u8,
};

fn parseStorageResource(value: []const u8, expected_service: ResourceService) !ParsedStorageResource {
    if (value.len == 0) return error.InvalidIngestionResourceUri;
    for (value) |byte| {
        if (byte <= 0x20 or byte >= 0x7f)
            return error.InvalidIngestionResourceUri;
    }
    _ = std.Uri.parse(value) catch return error.InvalidIngestionResourceUri;
    const scheme_end = std.mem.indexOfScalar(u8, value, ':') orelse
        return error.InvalidIngestionResourceUri;
    if (!std.ascii.eqlIgnoreCase(value[0..scheme_end], "https"))
        return error.IngestionResourceUriMustUseHttps;
    if (value.len < scheme_end + 3 or !std.mem.eql(u8, value[scheme_end .. scheme_end + 3], "://"))
        return error.InvalidIngestionResourceUri;
    if (std.mem.indexOfScalar(u8, value, '#') != null)
        return error.IngestionResourceUriFragmentNotAllowed;

    const authority_start = scheme_end + 3;
    const authority_end = authority_start + (std.mem.indexOfAny(
        u8,
        value[authority_start..],
        "/?",
    ) orelse value.len - authority_start);
    if (authority_start == authority_end or
        std.mem.indexOfScalar(u8, value[authority_start..authority_end], '@') != null)
        return error.InvalidIngestionResourceUri;
    const host_port = value[authority_start..authority_end];
    const host = if (std.mem.lastIndexOfScalar(u8, host_port, ':')) |port_start|
        host_port[0..port_start]
    else
        host_port;
    if (!isStorageServiceHost(host, expected_service))
        return error.InvalidIngestionResourceService;
    const account_end = std.mem.indexOfScalar(u8, host, '.') orelse
        return error.InvalidIngestionResourceUri;
    if (account_end == 0) return error.InvalidIngestionResourceUri;
    const query_start = std.mem.indexOfScalar(u8, value, '?') orelse
        return error.IngestionResourceSasRequired;
    if (query_start + 1 == value.len)
        return error.IngestionResourceSasRequired;
    if (query_start <= authority_end + 1)
        return error.InvalidIngestionResourceUri;
    return .{
        .query_start = query_start,
        .account_name = host[0..account_end],
    };
}

fn isStorageServiceHost(host: []const u8, service: ResourceService) bool {
    const service_name = @tagName(service);
    const suffixes = [_][]const u8{
        ".core.windows.net",
        ".core.usgovcloudapi.net",
        ".core.chinacloudapi.cn",
        ".core.cloudapi.de",
    };
    for (suffixes) |suffix| {
        var service_suffix_buffer: [64]u8 = undefined;
        const service_suffix = std.fmt.bufPrint(
            &service_suffix_buffer,
            ".{s}{s}",
            .{ service_name, suffix },
        ) catch return false;
        if (endsWithIgnoreCase(host, service_suffix)) return true;
    }
    return false;
}

fn endsWithIgnoreCase(value: []const u8, suffix: []const u8) bool {
    return value.len >= suffix.len and
        std.ascii.eqlIgnoreCase(value[value.len - suffix.len ..], suffix);
}

fn cloneResources(allocator: std.mem.Allocator, source: []const StorageResource) ![]StorageResource {
    if (source.len == 0) return &.{};
    const result = try allocator.alloc(StorageResource, source.len);
    var initialized: usize = 0;
    errdefer {
        for (result[0..initialized]) |*resource| resource.deinit(allocator);
        allocator.free(result);
    }
    for (source, 0..) |item, index| {
        result[index] = try item.clone(allocator);
        initialized += 1;
    }
    return result;
}

fn deinitResources(allocator: std.mem.Allocator, resources: []StorageResource) void {
    for (resources) |*resource| resource.deinit(allocator);
    if (resources.len != 0) allocator.free(resources);
}

fn decodeSnapshot(
    allocator: std.mem.Allocator,
    resources_dataset: *const data_result.KustoResponseDataSet,
    token_dataset: *const data_result.KustoResponseDataSet,
    now_ms: i64,
    cache_ttl_ms: i64,
    expiry_safety_skew_ms: i64,
) !IngestionResourceSnapshot {
    var snapshot = IngestionResourceSnapshot{
        .secured_ready_for_aggregation_queues = &.{},
        .temporary_blob_containers = &.{},
        .successful_ingestion_queues = &.{},
        .failed_ingestion_queues = &.{},
        .ingestion_status_queues = &.{},
        .ingestion_status_tables = &.{},
        .authorization_context = .{ .value = &.{} },
        .expires_at_ms = try expirationFromDefault(now_ms, cache_ttl_ms),
        .hard_expires_at_ms = null,
    };
    errdefer snapshot.deinit(allocator);
    try decodeResourceRows(allocator, resources_dataset, &snapshot, expiry_safety_skew_ms);
    snapshot.authorization_context = try decodeAuthorizationContext(allocator, token_dataset);
    if (snapshot.secured_ready_for_aggregation_queues.len == 0)
        return error.MissingSecuredReadyForAggregationQueue;
    if (snapshot.temporary_blob_containers.len == 0)
        return error.MissingTemporaryStorage;
    if (snapshot.authorization_context.value.len == 0)
        return error.MissingKustoAuthorizationContext;
    if (snapshot.expires_at_ms <= now_ms)
        return error.IngestionResourceSnapshotExpired;
    return snapshot;
}

fn decodeResourceRows(
    allocator: std.mem.Allocator,
    dataset: *const data_result.KustoResponseDataSet,
    snapshot: *IngestionResourceSnapshot,
    expiry_safety_skew_ms: i64,
) !void {
    var found_schema = false;
    for (dataset.tables) |*table| {
        const type_index = findColumn(table, &.{
            "ResourceTypeName",
            "ResourceType",
            "Type",
        }) orelse continue;
        const uri_index = findColumn(table, &.{
            "StorageRoot",
            "StorageUri",
            "ResourceUri",
            "Uri",
        }) orelse continue;
        found_schema = true;
        for (table.rows) |*row| {
            const type_value = row.get(type_index) orelse return error.MalformedIngestionResourceResponse;
            const uri_value = row.get(uri_index) orelse return error.MalformedIngestionResourceResponse;
            const type_name = stringValue(type_value) orelse return error.MalformedIngestionResourceResponse;
            const uri = stringValue(uri_value) orelse return error.MalformedIngestionResourceResponse;
            const kind = resourceKind(type_name) orelse continue;
            var resource = try StorageResource.init(allocator, kind.service(), uri);
            errdefer resource.deinit(allocator);
            if (try sasExpirationMs(resource.uri())) |sas_expiry| {
                const safe_expiry = saturatingSub(sas_expiry, expiry_safety_skew_ms);
                snapshot.expires_at_ms = @min(snapshot.expires_at_ms, safe_expiry);
                snapshot.hard_expires_at_ms = if (snapshot.hard_expires_at_ms) |current|
                    @min(current, sas_expiry)
                else
                    sas_expiry;
            }
            try appendUniqueResource(allocator, snapshot, kind, resource);
            resource = undefined;
        }
    }
    if (!found_schema) return error.MissingIngestionResourceColumns;
}

fn decodeAuthorizationContext(
    allocator: std.mem.Allocator,
    dataset: *const data_result.KustoResponseDataSet,
) !AuthorizationContext {
    var found_column = false;
    var value: ?[]const u8 = null;
    for (dataset.tables) |*table| {
        const token_index = findColumn(table, &.{
            "AuthorizationContext",
            "KustoIdentityToken",
            "IdentityToken",
            "Token",
        }) orelse continue;
        found_column = true;
        for (table.rows) |*row| {
            const token_value = row.get(token_index) orelse return error.MalformedKustoAuthorizationContext;
            const token = stringValue(token_value) orelse return error.MalformedKustoAuthorizationContext;
            if (token.len == 0) return error.MalformedKustoAuthorizationContext;
            if (value != null) return error.AmbiguousKustoAuthorizationContext;
            value = token;
        }
    }
    if (!found_column) return error.MissingKustoAuthorizationContextColumn;
    return .{ .value = try allocator.dupe(u8, value orelse return error.MissingKustoAuthorizationContext) };
}

fn findColumn(
    table: *const data_result.KustoResultTable,
    aliases: []const []const u8,
) ?usize {
    var found: ?usize = null;
    for (table.columns, 0..) |column, index| {
        for (aliases) |alias| {
            if (std.ascii.eqlIgnoreCase(column.name, alias)) {
                if (found != null) return null;
                found = index;
            }
        }
    }
    return found;
}

fn stringValue(value: *const data_result.KustoValue) ?[]const u8 {
    return value.asString() orelse value.lexical();
}

fn resourceKind(type_name: []const u8) ?ResourceKind {
    if (std.ascii.eqlIgnoreCase(type_name, "SecuredReadyForAggregationQueue"))
        return .secured_ready_for_aggregation_queue;
    if (std.ascii.eqlIgnoreCase(type_name, "TempStorage") or
        std.ascii.eqlIgnoreCase(type_name, "TemporaryStorage"))
        return .temporary_blob_container;
    if (std.ascii.eqlIgnoreCase(type_name, "SuccessfulIngestionsQueue"))
        return .successful_ingestion_queue;
    if (std.ascii.eqlIgnoreCase(type_name, "FailedIngestionsQueue"))
        return .failed_ingestion_queue;
    if (std.ascii.eqlIgnoreCase(type_name, "IngestionsStatusQueue") or
        std.ascii.eqlIgnoreCase(type_name, "IngestionStatusQueue"))
        return .ingestion_status_queue;
    if (std.ascii.eqlIgnoreCase(type_name, "IngestionsStatusTable") or
        std.ascii.eqlIgnoreCase(type_name, "IngestionStatusTable"))
        return .ingestion_status_table;
    return null;
}

fn appendUniqueResource(
    allocator: std.mem.Allocator,
    snapshot: *IngestionResourceSnapshot,
    kind: ResourceKind,
    resource: StorageResource,
) !void {
    const list = switch (kind) {
        .secured_ready_for_aggregation_queue => &snapshot.secured_ready_for_aggregation_queues,
        .temporary_blob_container => &snapshot.temporary_blob_containers,
        .successful_ingestion_queue => &snapshot.successful_ingestion_queues,
        .failed_ingestion_queue => &snapshot.failed_ingestion_queues,
        .ingestion_status_queue => &snapshot.ingestion_status_queues,
        .ingestion_status_table => &snapshot.ingestion_status_tables,
    };
    for (list.*) |existing| {
        if (std.mem.eql(u8, existing.bytes, resource.bytes)) {
            var duplicate = resource;
            duplicate.deinit(allocator);
            return;
        }
    }
    const old = list.*;
    const next = if (old.len == 0)
        try allocator.alloc(StorageResource, 1)
    else
        try allocator.realloc(old, old.len + 1);
    next[old.len] = resource;
    list.* = next;
}

fn sasExpirationMs(uri: []const u8) !?i64 {
    const query_start = std.mem.indexOfScalar(u8, uri, '?') orelse return null;
    var parameter_iterator = std.mem.splitScalar(u8, uri[query_start + 1 ..], '&');
    while (parameter_iterator.next()) |parameter| {
        const equals = std.mem.indexOfScalar(u8, parameter, '=') orelse continue;
        if (!std.ascii.eqlIgnoreCase(parameter[0..equals], "se")) continue;
        var decoded: [64]u8 = undefined;
        const value = try percentDecode(parameter[equals + 1 ..], &decoded);
        return try parseRfc3339Milliseconds(value);
    }
    return null;
}

fn percentDecode(value: []const u8, output: []u8) ![]const u8 {
    var input_index: usize = 0;
    var output_index: usize = 0;
    while (input_index < value.len) {
        if (output_index == output.len) return error.InvalidSasExpiration;
        if (value[input_index] != '%') {
            output[output_index] = value[input_index];
            input_index += 1;
        } else {
            if (input_index + 2 >= value.len) return error.InvalidSasExpiration;
            output[output_index] = (try hexDigit(value[input_index + 1])) << 4 |
                try hexDigit(value[input_index + 2]);
            input_index += 3;
        }
        output_index += 1;
    }
    return output[0..output_index];
}

fn hexDigit(value: u8) !u8 {
    return switch (value) {
        '0'...'9' => value - '0',
        'a'...'f' => value - 'a' + 10,
        'A'...'F' => value - 'A' + 10,
        else => error.InvalidSasExpiration,
    };
}

fn parseRfc3339Milliseconds(value: []const u8) !i64 {
    if (value.len < 20 or value[4] != '-' or value[7] != '-' or value[10] != 'T' or
        value[13] != ':' or value[16] != ':')
        return error.InvalidSasExpiration;
    const year = std.fmt.parseInt(i64, value[0..4], 10) catch return error.InvalidSasExpiration;
    const month_number = std.fmt.parseInt(u8, value[5..7], 10) catch return error.InvalidSasExpiration;
    const day = std.fmt.parseInt(u8, value[8..10], 10) catch return error.InvalidSasExpiration;
    const hour = std.fmt.parseInt(u8, value[11..13], 10) catch return error.InvalidSasExpiration;
    const minute = std.fmt.parseInt(u8, value[14..16], 10) catch return error.InvalidSasExpiration;
    const second = std.fmt.parseInt(u8, value[17..19], 10) catch return error.InvalidSasExpiration;
    if (year < 1 or hour > 23 or minute > 59 or second > 59)
        return error.InvalidSasExpiration;
    const month = std.enums.fromInt(std.time.epoch.Month, month_number) orelse
        return error.InvalidSasExpiration;
    if (day == 0 or day > std.time.epoch.getDaysInMonth(@intCast(year), month))
        return error.InvalidSasExpiration;

    var index: usize = 19;
    var milliseconds: i64 = 0;
    if (index < value.len and value[index] == '.') {
        index += 1;
        const fraction_start = index;
        var multiplier: i64 = 100;
        while (index < value.len and std.ascii.isDigit(value[index])) : (index += 1) {
            if (multiplier > 0) {
                milliseconds += @as(i64, value[index] - '0') * multiplier;
                multiplier = @divTrunc(multiplier, 10);
            }
        }
        if (index == fraction_start) return error.InvalidSasExpiration;
    }
    var offset_seconds: i64 = 0;
    if (index < value.len and value[index] == 'Z') {
        if (index + 1 != value.len) return error.InvalidSasExpiration;
    } else {
        if (index + 6 != value.len or (value[index] != '+' and value[index] != '-') or
            value[index + 3] != ':')
            return error.InvalidSasExpiration;
        const offset_hour = std.fmt.parseInt(u8, value[index + 1 .. index + 3], 10) catch
            return error.InvalidSasExpiration;
        const offset_minute = std.fmt.parseInt(u8, value[index + 4 .. index + 6], 10) catch
            return error.InvalidSasExpiration;
        if (offset_hour > 23 or offset_minute > 59) return error.InvalidSasExpiration;
        const magnitude = @as(i64, offset_hour) * std.time.s_per_hour +
            @as(i64, offset_minute) * std.time.s_per_min;
        offset_seconds = if (value[index] == '+') magnitude else -magnitude;
    }

    const adjusted_year = year - @intFromBool(month_number <= 2);
    const era = @divFloor(adjusted_year, 400);
    const year_of_era = adjusted_year - era * 400;
    const adjusted_month = @as(i64, month_number) +
        (if (month_number > 2) @as(i64, -3) else @as(i64, 9));
    const day_of_year = @divFloor(153 * adjusted_month + 2, 5) + day - 1;
    const day_of_era = year_of_era * 365 + @divFloor(year_of_era, 4) -
        @divFloor(year_of_era, 100) + day_of_year;
    const seconds = (era * 146_097 + day_of_era - 719_468) * std.time.s_per_day +
        @as(i64, hour) * std.time.s_per_hour +
        @as(i64, minute) * std.time.s_per_min +
        @as(i64, second) - offset_seconds;
    return std.math.add(i64, std.math.mul(i64, seconds, 1_000) catch return error.InvalidSasExpiration, milliseconds) catch
        return error.InvalidSasExpiration;
}

fn expirationFromDefault(now_ms: i64, ttl_ms: i64) !i64 {
    return std.math.add(i64, now_ms, ttl_ms) catch std.math.maxInt(i64);
}

fn saturatingSub(value: i64, amount: i64) i64 {
    return std.math.sub(i64, value, amount) catch std.math.minInt(i64);
}

fn canUseStale(snapshot: *const IngestionResourceSnapshot, now_ms: i64) bool {
    return if (snapshot.hard_expires_at_ms) |expires_at_ms|
        expires_at_ms > now_ms
    else
        true;
}

fn snapshotLease(
    allocator: std.mem.Allocator,
    snapshot: *const IngestionResourceSnapshot,
    stale: bool,
    refresh_failure: ?*const kusto_common.KustoError,
) !ResourceSnapshotLease {
    const snapshot_copy = try snapshot.clone(allocator);
    errdefer {
        var mutable_snapshot = snapshot_copy;
        mutable_snapshot.deinit(allocator);
    }
    const failure_copy = if (refresh_failure) |failure|
        try cloneKustoError(allocator, failure)
    else
        null;
    return .{
        .snapshot = snapshot_copy,
        .stale = stale,
        .refresh_failure = failure_copy,
    };
}

fn ensureAccountScores(
    manager: *ResourceManager,
    snapshot: *const IngestionResourceSnapshot,
) !void {
    const ranked_kinds = [_]ResourceKind{
        .secured_ready_for_aggregation_queue,
        .temporary_blob_container,
    };
    for (ranked_kinds) |kind| {
        for (snapshot.resources(kind)) |resource|
            _ = try manager.scoreForAccount(resource.account_name);
    }
}

fn clearLastRefreshFailure(manager: *ResourceManager) void {
    if (manager.last_refresh_failure) |*failure| failure.deinit();
    manager.last_refresh_failure = null;
}

fn cloneKustoError(
    allocator: std.mem.Allocator,
    source: *const kusto_common.KustoError,
) !kusto_common.KustoError {
    var copy = kusto_common.KustoError{
        .allocator = allocator,
        .operation = source.operation,
        .source = source.source,
        .outcome = source.outcome,
        .http_status = source.http_status,
        .transport_error = source.transport_error,
        .retry_after_ms = source.retry_after_ms,
        .permanent = source.permanent,
        .cancelled = source.cancelled,
        .retryable = source.retryable,
    };
    errdefer copy.deinit();
    copy.detail = try cloneKustoErrorDetail(allocator, &source.detail);
    if (source.client_request_id) |value|
        copy.client_request_id = try allocator.dupe(u8, value);
    if (source.activity_id) |value|
        copy.activity_id = try allocator.dupe(u8, value);
    return copy;
}

fn cloneKustoErrorDetail(
    allocator: std.mem.Allocator,
    source: *const kusto_common.KustoErrorDetail,
) !kusto_common.KustoErrorDetail {
    var copy = kusto_common.KustoErrorDetail{ .permanent = source.permanent };
    errdefer copy.deinit(allocator);
    if (source.code) |value| copy.code = try allocator.dupe(u8, value);
    if (source.message) |value| copy.message = try allocator.dupe(u8, value);
    if (source.error_type) |value| copy.error_type = try allocator.dupe(u8, value);
    if (source.description) |value| copy.description = try allocator.dupe(u8, value);
    if (source.inner_error) |inner| {
        const owned_inner = try allocator.create(kusto_common.KustoErrorDetail);
        errdefer allocator.destroy(owned_inner);
        owned_inner.* = try cloneKustoErrorDetail(allocator, inner);
        copy.inner_error = owned_inner;
    }
    return copy;
}

fn scoreFor(scores: []const AccountScore, account_name: []const u8) i32 {
    for (scores) |entry| {
        if (std.mem.eql(u8, entry.account_name, account_name)) return entry.score;
    }
    return 0;
}

const test_resource_body =
    \\{"Tables":[{"TableName":"Resources","Columns":[
    \\{"ColumnName":"storageRoot","DataType":"String"},
    \\{"ColumnName":"Ignored","DataType":"String"},
    \\{"ColumnName":"resourceTypeName","DataType":"String"}
    \\],"Rows":[
    \\["https://accounta.queue.core.windows.net/ready-a?se=2030-01-02T00%3A00%3A00Z&sig=secret-ready-a","x","SecuredReadyForAggregationQueue"],
    \\["https://accounta.queue.core.windows.net/ready-a?se=2030-01-02T00%3A00%3A00Z&sig=secret-ready-a","x","securedreadyforaggregationqueue"],
    \\["https://accountb.queue.core.windows.net/ready-b?se=2030-01-02T00%3A00%3A00Z&sig=secret-ready-b","x","SecuredReadyForAggregationQueue"],
    \\["https://accounta.blob.core.windows.net/temp-a?se=2030-01-02T00%3A00%3A00Z&sig=secret-blob-a","x","TempStorage"],
    \\["https://accountb.blob.core.windows.net/temp-b?se=2030-01-02T00%3A00%3A00Z&sig=secret-blob-b","x","TemporaryStorage"],
    \\["https://accounta.queue.core.windows.net/success?sig=secret-success","x","SuccessfulIngestionsQueue"],
    \\["https://accounta.queue.core.windows.net/failure?sig=secret-failure","x","FailedIngestionsQueue"],
    \\["https://accounta.queue.core.windows.net/status?sig=secret-status","x","IngestionsStatusQueue"],
    \\["https://accounta.table.core.windows.net/ingestionstatus?sig=secret-table","x","IngestionsStatusTable"],
    \\["https://accounta.queue.core.windows.net/future?sig=secret-future","x","FutureResource"]
    \\]}]}
;

const test_new_resource_body =
    \\{"Tables":[{"TableName":"Resources","Columns":[{"ColumnName":"ResourceTypeName","DataType":"String"},{"ColumnName":"StorageRoot","DataType":"String"}],"Rows":[
    \\["SecuredReadyForAggregationQueue","https://accountc.queue.core.windows.net/ready-c?sig=secret-new-ready"],
    \\["TempStorage","https://accountc.blob.core.windows.net/temp-c?sig=secret-new-blob"]
    \\]}]}
;

const test_token_body =
    \\{"Tables":[{"TableName":"Token","Columns":[{"ColumnName":"authorizationcontext","DataType":"String"}],"Rows":[["secret-authorization-context"]]}]}
;

const hard_expiry_resource_body =
    \\{"Tables":[{"TableName":"Resources","Columns":[{"ColumnName":"ResourceTypeName","DataType":"String"},{"ColumnName":"StorageRoot","DataType":"String"}],"Rows":[
    \\["SecuredReadyForAggregationQueue","https://accounta.queue.core.windows.net/ready?se=1970-01-01T00%3A00%3A00.200Z&sig=secret-ready"],
    \\["TempStorage","https://accounta.blob.core.windows.net/temp?se=1970-01-01T00%3A00%3A00.200Z&sig=secret-blob"]
    \\]}]}
;

const TestClock = struct {
    now_ms: i64 = 0,

    fn source(self: *TestClock) TimeSource {
        return .{ .context = self, .nowMsFn = &now };
    }

    fn now(context: *anyopaque) i64 {
        const self: *TestClock = @ptrCast(@alignCast(context));
        return self.now_ms;
    }
};

const TestResponse = union(enum) {
    body: []const u8,
    service_failure: struct {
        status: u16,
        retryable: bool,
        permanent: ?bool = null,
    },
};

const TestExecutor = struct {
    io: std.Io,
    responses: []const TestResponse,
    mutex: std.Io.Mutex = .init,
    calls: usize = 0,
    commands: [8]?[]const u8 = [_]?[]const u8{null} ** 8,
    block_first: bool = false,
    entered: std.Io.Semaphore = .{},
    release: std.Io.Semaphore = .{},

    fn asExecutor(self: *TestExecutor) ResourceCommandExecutor {
        return .{ .context = self, .executeFn = &execute };
    }

    fn callCount(self: *TestExecutor) usize {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        return self.calls;
    }

    fn execute(
        context: *anyopaque,
        allocator: std.mem.Allocator,
        _: []const u8,
        command: []const u8,
    ) !kusto_common.KustoResult(data_result.KustoResponseDataSet) {
        const self: *TestExecutor = @ptrCast(@alignCast(context));
        self.mutex.lockUncancelable(self.io);
        const index = self.calls;
        self.calls += 1;
        if (index < self.commands.len) self.commands[index] = command;
        self.mutex.unlock(self.io);
        if (index >= self.responses.len) return error.UnexpectedResourceCommand;
        if (self.block_first and index == 0) {
            self.entered.post(self.io);
            self.release.waitUncancelable(self.io);
        }
        return switch (self.responses[index]) {
            .body => |body| makeDatasetResult(allocator, body),
            .service_failure => |spec| .{ .err = .{
                .allocator = allocator,
                .operation = .management,
                .source = .http,
                .outcome = .known_not_accepted,
                .http_status = spec.status,
                .permanent = spec.permanent,
                .retryable = spec.retryable,
            } },
        };
    }
};

fn makeDatasetResult(
    allocator: std.mem.Allocator,
    body: []const u8,
) !kusto_common.KustoResult(data_result.KustoResponseDataSet) {
    var decoded = try data_result.decodeResponseDataSet(allocator, body, .{}, .management);
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

fn initTestManager(
    allocator: std.mem.Allocator,
    executor: *TestExecutor,
    clock: *TestClock,
    ttl_ms: i64,
) !ResourceManager {
    return ResourceManager.init(
        allocator,
        executor.io,
        executor.asExecutor(),
        "db",
        .{ .cache_ttl_ms = ttl_ms, .time_source = clock.source() },
    );
}

fn expectLease(result: *ResourceSnapshotResult) !*ResourceSnapshotLease {
    return switch (result.*) {
        .ok => |*lease| lease,
        .err => |*failure| {
            failure.deinit();
            result.* = undefined;
            return error.TestExpectedResourceLease;
        },
    };
}

test "resource manager decodes complete V1 resources by names and redacts secrets" {
    const allocator = std.testing.allocator;
    var clock = TestClock{};
    const responses = [_]TestResponse{
        .{ .body = test_resource_body },
        .{ .body = test_token_body },
    };
    var executor = TestExecutor{ .io = std.testing.io, .responses = &responses };
    var manager = try initTestManager(allocator, &executor, &clock, 1_000);
    defer manager.deinit();

    var result = try manager.getSnapshot();
    defer result.deinit(allocator);
    const lease = try expectLease(&result);
    try std.testing.expect(!lease.stale);
    try std.testing.expectEqual(@as(usize, 2), lease.snapshot.secured_ready_for_aggregation_queues.len);
    try std.testing.expectEqual(@as(usize, 2), lease.snapshot.temporary_blob_containers.len);
    try std.testing.expectEqual(@as(usize, 1), lease.snapshot.successful_ingestion_queues.len);
    try std.testing.expectEqual(@as(usize, 1), lease.snapshot.failed_ingestion_queues.len);
    try std.testing.expectEqual(@as(usize, 1), lease.snapshot.ingestion_status_queues.len);
    try std.testing.expectEqual(@as(usize, 1), lease.snapshot.ingestion_status_tables.len);
    try std.testing.expectEqualStrings(
        "secret-authorization-context",
        lease.snapshot.authorization_context.token(),
    );
    try std.testing.expectEqual(@as(i64, 1_000), lease.snapshot.expires_at_ms);
    try std.testing.expectEqualStrings(".get ingestion resources", executor.commands[0].?);
    try std.testing.expectEqualStrings(".get kusto identity token", executor.commands[1].?);

    var buffer: [1_024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try writer.print("{f} {f} {f}", .{
        lease.snapshot,
        lease.snapshot.secured_ready_for_aggregation_queues[0],
        lease.snapshot.authorization_context,
    });
    try std.testing.expect(std.mem.indexOf(u8, buffer[0..writer.end], "secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, buffer[0..writer.end], "?***") != null);
}

fn resourceTestToken(
    _: *core.credentials.TokenCredential,
    _: core.credentials.TokenRequestContext,
    _: core.context.Context,
) anyerror!core.credentials.AccessToken {
    return .{ .token = "resource-manager-test-token", .expires_on = std.math.maxInt(i64) };
}

test "data-management executor authenticates requests at the DM endpoint without retry" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, test_resource_body);
    defer mock.deinit();
    var credential = core.credentials.TokenCredential{ .getTokenFn = &resourceTestToken };
    const connection = try kusto_common.KustoConnection.init(
        allocator,
        .{
            .cluster_url = "https://cluster.kusto.windows.net",
            .credential = &credential,
        },
        mock.asTransport(),
        .{
            .metadata_mode = .disabled,
            .data_management_endpoint = "https://ingest-dm.kusto.windows.net",
        },
    );
    defer connection.deinit();
    var command_executor = DataManagementCommandExecutor.initWithConnection(connection);
    var result = try command_executor.asExecutor().execute(
        allocator,
        "db",
        ".get ingestion resources",
    );
    defer result.deinit(allocator);
    switch (result) {
        .ok => {},
        else => return error.TestUnexpectedResourceFailure,
    }
    try std.testing.expectEqualStrings(
        "https://ingest-dm.kusto.windows.net/v1/rest/mgmt",
        mock.last_url.?,
    );
    try std.testing.expect(mock.last_headers.get("Authorization") != null);
    try std.testing.expectEqual(false, mock.last_retryable.?);
    try std.testing.expect(std.mem.indexOf(
        u8,
        mock.last_body.?,
        "\"csl\":\".get ingestion resources\"",
    ) != null);
}

test "resource manager caches leases, expires safely, and preserves old leases" {
    const allocator = std.testing.allocator;
    var clock = TestClock{};
    const responses = [_]TestResponse{
        .{ .body = test_resource_body },
        .{ .body = test_token_body },
        .{ .body = test_new_resource_body },
        .{ .body = test_token_body },
    };
    var executor = TestExecutor{ .io = std.testing.io, .responses = &responses };
    var manager = try initTestManager(allocator, &executor, &clock, 100);
    defer manager.deinit();

    var first = try manager.getSnapshot();
    defer first.deinit(allocator);
    const first_lease = try expectLease(&first);
    try std.testing.expectEqual(@as(usize, 2), executor.callCount());

    var hit = try manager.getSnapshot();
    defer hit.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), executor.callCount());

    clock.now_ms = 100;
    var refreshed = try manager.getSnapshot();
    defer refreshed.deinit(allocator);
    const refreshed_lease = try expectLease(&refreshed);
    try std.testing.expectEqual(@as(usize, 4), executor.callCount());
    try std.testing.expect(std.mem.indexOf(
        u8,
        refreshed_lease.snapshot.secured_ready_for_aggregation_queues[0].uri(),
        "ready-c",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        first_lease.snapshot.secured_ready_for_aggregation_queues[0].uri(),
        "ready-a",
    ) != null);
}

test "resource manager retries expired snapshots after transient failures and marks stale" {
    const allocator = std.testing.allocator;
    var clock = TestClock{};
    const responses = [_]TestResponse{
        .{ .body = test_resource_body },
        .{ .body = test_token_body },
        .{ .service_failure = .{ .status = 503, .retryable = true } },
        .{ .body = test_new_resource_body },
        .{ .body = test_token_body },
    };
    var executor = TestExecutor{ .io = std.testing.io, .responses = &responses };
    var manager = try initTestManager(allocator, &executor, &clock, 100);
    defer manager.deinit();

    var initial = try manager.getSnapshot();
    defer initial.deinit(allocator);
    clock.now_ms = 100;
    var stale = try manager.getSnapshot();
    defer stale.deinit(allocator);
    const stale_lease = try expectLease(&stale);
    try std.testing.expect(stale_lease.stale);
    try std.testing.expect(stale_lease.refresh_failure != null);
    try std.testing.expectEqual(@as(?u16, 503), stale_lease.refresh_failure.?.http_status);
    try std.testing.expectEqual(@as(usize, 3), executor.callCount());

    var last_failure = (try manager.lastRefreshFailure()).?;
    defer last_failure.deinit();
    try std.testing.expect(last_failure.retryable);

    var retried = try manager.getSnapshot();
    defer retried.deinit(allocator);
    const fresh_lease = try expectLease(&retried);
    try std.testing.expect(!fresh_lease.stale);
    try std.testing.expectEqual(@as(usize, 5), executor.callCount());
}

test "resource manager never serves stale resources after hard SAS expiration" {
    const allocator = std.testing.allocator;
    var clock = TestClock{};
    const responses = [_]TestResponse{
        .{ .body = hard_expiry_resource_body },
        .{ .body = test_token_body },
        .{ .service_failure = .{ .status = 503, .retryable = true } },
        .{ .service_failure = .{ .status = 503, .retryable = true } },
    };
    var executor = TestExecutor{ .io = std.testing.io, .responses = &responses };
    var manager = try ResourceManager.init(
        allocator,
        executor.io,
        executor.asExecutor(),
        "db",
        .{
            .cache_ttl_ms = 100,
            .expiry_safety_skew_ms = 0,
            .time_source = clock.source(),
        },
    );
    defer manager.deinit();

    var initial = try manager.getSnapshot();
    defer initial.deinit(allocator);
    const initial_lease = try expectLease(&initial);
    try std.testing.expectEqual(@as(?i64, 200), initial_lease.snapshot.hard_expires_at_ms);

    clock.now_ms = 150;
    var stale = try manager.getSnapshot();
    defer stale.deinit(allocator);
    try std.testing.expect((try expectLease(&stale)).stale);

    clock.now_ms = 200;
    var expired = try manager.getSnapshot();
    defer expired.deinit(allocator);
    switch (expired) {
        .err => |failure| try std.testing.expectEqual(@as(?u16, 503), failure.http_status),
        .ok => return error.TestUnexpectedStaleLease,
    }
}

test "permanent, malformed, and authorization refresh failures never use stale resources" {
    const allocator = std.testing.allocator;
    var clock = TestClock{};
    const permanent_responses = [_]TestResponse{
        .{ .body = test_resource_body },
        .{ .body = test_token_body },
        .{ .service_failure = .{ .status = 401, .retryable = false, .permanent = true } },
    };
    var permanent_executor = TestExecutor{ .io = std.testing.io, .responses = &permanent_responses };
    var permanent_manager = try initTestManager(allocator, &permanent_executor, &clock, 10);
    defer permanent_manager.deinit();
    var initial = try permanent_manager.getSnapshot();
    defer initial.deinit(allocator);
    clock.now_ms = 10;
    var permanent = try permanent_manager.getSnapshot();
    defer permanent.deinit(allocator);
    switch (permanent) {
        .err => |failure| {
            try std.testing.expectEqual(@as(?u16, 401), failure.http_status);
            try std.testing.expect(!failure.retryable);
        },
        .ok => return error.TestUnexpectedStaleLease,
    }

    clock.now_ms = 0;
    const malformed_responses = [_]TestResponse{
        .{ .body = test_resource_body },
        .{ .body = test_token_body },
        .{ .body = "{not json" },
    };
    var malformed_executor = TestExecutor{ .io = std.testing.io, .responses = &malformed_responses };
    var malformed_manager = try initTestManager(allocator, &malformed_executor, &clock, 10);
    defer malformed_manager.deinit();
    var valid = try malformed_manager.getSnapshot();
    defer valid.deinit(allocator);
    clock.now_ms = 10;
    try std.testing.expectError(error.MalformedKustoResponse, malformed_manager.getSnapshot());

    clock.now_ms = 0;
    const auth_responses = [_]TestResponse{
        .{ .body = test_resource_body },
        .{ .body = test_token_body },
        .{ .body = test_new_resource_body },
        .{ .service_failure = .{ .status = 403, .retryable = false, .permanent = true } },
    };
    var auth_executor = TestExecutor{ .io = std.testing.io, .responses = &auth_responses };
    var auth_manager = try initTestManager(allocator, &auth_executor, &clock, 10);
    defer auth_manager.deinit();
    var auth_valid = try auth_manager.getSnapshot();
    defer auth_valid.deinit(allocator);
    clock.now_ms = 10;
    var auth_failure = try auth_manager.getSnapshot();
    defer auth_failure.deinit(allocator);
    switch (auth_failure) {
        .err => |failure| try std.testing.expectEqual(@as(?u16, 403), failure.http_status),
        .ok => return error.TestUnexpectedStaleLease,
    }
}

test "resource selection is deterministic, score-ranked, and safe for empty kinds" {
    const allocator = std.testing.allocator;
    var clock = TestClock{};
    const responses = [_]TestResponse{
        .{ .body = test_resource_body },
        .{ .body = test_token_body },
    };
    var executor = TestExecutor{ .io = std.testing.io, .responses = &responses };
    var manager = try initTestManager(allocator, &executor, &clock, 1_000);
    defer manager.deinit();

    var first = try manager.selectResource(.secured_ready_for_aggregation_queue);
    defer first.deinit(allocator);
    const first_selection = switch (first) {
        .ok => |*selection| selection,
        .err => return error.TestUnexpectedResourceFailure,
    };
    try std.testing.expectEqualStrings("accounta", first_selection.attempt.account_name);
    try manager.reportAttempt(&first_selection.attempt, true);

    var second = try manager.selectResource(.secured_ready_for_aggregation_queue);
    defer second.deinit(allocator);
    const second_selection = switch (second) {
        .ok => |*selection| selection,
        .err => return error.TestUnexpectedResourceFailure,
    };
    try std.testing.expectEqualStrings("accountb", second_selection.attempt.account_name);
    try manager.reportAttempt(&second_selection.attempt, false);
    try std.testing.expectEqual(@as(i32, -1), scoreFor(manager.account_scores.items, "accountb"));

    var third = try manager.selectResource(.secured_ready_for_aggregation_queue);
    defer third.deinit(allocator);
    const third_selection = switch (third) {
        .ok => |*selection| selection,
        .err => return error.TestUnexpectedResourceFailure,
    };
    try std.testing.expectEqualStrings("accounta", third_selection.attempt.account_name);

    const empty_kind_responses = [_]TestResponse{
        .{ .body = test_new_resource_body },
        .{ .body = test_token_body },
    };
    var empty_kind_executor = TestExecutor{
        .io = std.testing.io,
        .responses = &empty_kind_responses,
    };
    var empty_kind_manager = try initTestManager(
        allocator,
        &empty_kind_executor,
        &clock,
        1_000,
    );
    defer empty_kind_manager.deinit();
    try std.testing.expectError(
        error.NoUsableIngestionResource,
        empty_kind_manager.selectResource(.ingestion_status_table),
    );
}

const ConcurrentGetContext = struct {
    manager: *ResourceManager,
    result: ?ResourceSnapshotResult = null,
    failure: ?anyerror = null,

    fn run(self: *ConcurrentGetContext) void {
        self.result = self.manager.getSnapshot() catch |err| {
            self.failure = err;
            return;
        };
    }
};

fn waitForManagerWaiter(manager: *ResourceManager) !void {
    for (0..1_000) |_| {
        manager.mutex.lockUncancelable(std.testing.io);
        const waiting = manager.waiting_callers != 0;
        manager.mutex.unlock(std.testing.io);
        if (waiting) return;
        std.testing.io.sleep(.fromMilliseconds(1), .awake) catch {};
    }
    return error.TestExpectedResourceManagerWaiter;
}

test "resource manager coalesces concurrent refreshes" {
    if (@import("builtin").single_threaded) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    var clock = TestClock{};
    const responses = [_]TestResponse{
        .{ .body = test_resource_body },
        .{ .body = test_token_body },
    };
    var executor = TestExecutor{
        .io = std.testing.io,
        .responses = &responses,
        .block_first = true,
    };
    var manager = try initTestManager(allocator, &executor, &clock, 1_000);
    defer manager.deinit();

    var first = ConcurrentGetContext{ .manager = &manager };
    var second = ConcurrentGetContext{ .manager = &manager };
    const first_thread = try std.Thread.spawn(.{}, ConcurrentGetContext.run, .{&first});
    executor.entered.waitUncancelable(std.testing.io);
    const second_thread = std.Thread.spawn(.{}, ConcurrentGetContext.run, .{&second}) catch |err| {
        executor.release.post(std.testing.io);
        first_thread.join();
        return err;
    };
    waitForManagerWaiter(&manager) catch |err| {
        executor.release.post(std.testing.io);
        first_thread.join();
        second_thread.join();
        return err;
    };
    executor.release.post(std.testing.io);
    first_thread.join();
    second_thread.join();
    defer if (first.result) |*result| result.deinit(allocator);
    defer if (second.result) |*result| result.deinit(allocator);
    try std.testing.expect(first.failure == null);
    try std.testing.expect(second.failure == null);
    try std.testing.expectEqual(@as(usize, 2), executor.callCount());
    try std.testing.expect(first.result != null);
    try std.testing.expect(second.result != null);
}

test "resource manager coalesces concurrent service and local refresh failures" {
    if (@import("builtin").single_threaded) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    var clock = TestClock{};

    const service_responses = [_]TestResponse{
        .{ .service_failure = .{ .status = 503, .retryable = true } },
    };
    var service_executor = TestExecutor{
        .io = std.testing.io,
        .responses = &service_responses,
        .block_first = true,
    };
    var service_manager = try initTestManager(allocator, &service_executor, &clock, 1_000);
    defer service_manager.deinit();
    var service_first = ConcurrentGetContext{ .manager = &service_manager };
    var service_second = ConcurrentGetContext{ .manager = &service_manager };
    const service_first_thread = try std.Thread.spawn(
        .{},
        ConcurrentGetContext.run,
        .{&service_first},
    );
    service_executor.entered.waitUncancelable(std.testing.io);
    const service_second_thread = std.Thread.spawn(
        .{},
        ConcurrentGetContext.run,
        .{&service_second},
    ) catch |err| {
        service_executor.release.post(std.testing.io);
        service_first_thread.join();
        return err;
    };
    waitForManagerWaiter(&service_manager) catch |err| {
        service_executor.release.post(std.testing.io);
        service_first_thread.join();
        service_second_thread.join();
        return err;
    };
    service_executor.release.post(std.testing.io);
    service_first_thread.join();
    service_second_thread.join();
    defer if (service_first.result) |*result| result.deinit(allocator);
    defer if (service_second.result) |*result| result.deinit(allocator);
    try std.testing.expect(service_first.failure == null);
    try std.testing.expect(service_second.failure == null);
    try std.testing.expectEqual(@as(usize, 1), service_executor.callCount());
    switch (service_first.result.?) {
        .err => |failure| try std.testing.expectEqual(@as(?u16, 503), failure.http_status),
        .ok => return error.TestUnexpectedResourceLease,
    }
    switch (service_second.result.?) {
        .err => |failure| try std.testing.expectEqual(@as(?u16, 503), failure.http_status),
        .ok => return error.TestUnexpectedResourceLease,
    }

    const malformed_responses = [_]TestResponse{
        .{ .body = "{not json" },
    };
    var malformed_executor = TestExecutor{
        .io = std.testing.io,
        .responses = &malformed_responses,
        .block_first = true,
    };
    var malformed_manager = try initTestManager(allocator, &malformed_executor, &clock, 1_000);
    defer malformed_manager.deinit();
    var malformed_first = ConcurrentGetContext{ .manager = &malformed_manager };
    var malformed_second = ConcurrentGetContext{ .manager = &malformed_manager };
    const malformed_first_thread = try std.Thread.spawn(
        .{},
        ConcurrentGetContext.run,
        .{&malformed_first},
    );
    malformed_executor.entered.waitUncancelable(std.testing.io);
    const malformed_second_thread = std.Thread.spawn(
        .{},
        ConcurrentGetContext.run,
        .{&malformed_second},
    ) catch |err| {
        malformed_executor.release.post(std.testing.io);
        malformed_first_thread.join();
        return err;
    };
    waitForManagerWaiter(&malformed_manager) catch |err| {
        malformed_executor.release.post(std.testing.io);
        malformed_first_thread.join();
        malformed_second_thread.join();
        return err;
    };
    malformed_executor.release.post(std.testing.io);
    malformed_first_thread.join();
    malformed_second_thread.join();
    try std.testing.expectEqual(error.MalformedKustoResponse, malformed_first.failure.?);
    try std.testing.expectEqual(error.MalformedKustoResponse, malformed_second.failure.?);
    try std.testing.expectEqual(@as(usize, 1), malformed_executor.callCount());
}

test "resource snapshot decoding releases allocations on every failure path" {
    const Fixture = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var resource = try data_result.decodeResponseDataSet(
                allocator,
                test_resource_body,
                .{},
                .management,
            );
            defer resource.deinit(allocator);
            var token = try data_result.decodeResponseDataSet(
                allocator,
                test_token_body,
                .{},
                .management,
            );
            defer token.deinit(allocator);
            var snapshot = try decodeSnapshot(
                allocator,
                &resource.dataset,
                &token.dataset,
                0,
                1_000,
                default_expiry_safety_skew_ms,
            );
            defer snapshot.deinit(allocator);
            var cloned = try snapshot.clone(allocator);
            defer cloned.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Fixture.run, .{});
}

test "resource manager releases its mutex after cached lease allocation failures" {
    const Fixture = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var clock = TestClock{};
            const responses = [_]TestResponse{
                .{ .body = test_resource_body },
                .{ .body = test_token_body },
            };
            var executor = TestExecutor{ .io = std.testing.io, .responses = &responses };
            var manager = try initTestManager(allocator, &executor, &clock, 1_000);
            defer manager.deinit();
            var first = try manager.getSnapshot();
            defer first.deinit(allocator);
            var cached = try manager.getSnapshot();
            defer cached.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Fixture.run, .{});
}
