//! Managed Kusto ingestion selects direct streaming or queued ingestion.
//!
//! It deliberately buffers only `threshold + 1` bytes when classifying an
//! unknown one-shot reader. A small reader becomes a replayable byte source;
//! a larger reader is uploaded once through Queue using its consumed prefix
//! followed by the same reader, preserving any internal reader buffering.
const std = @import("std");
const core = @import("azure_sdk_core");
const kusto_common = @import("azure_sdk_kusto_common");
const data_result = @import("azure_sdk_kusto_data");
const streaming = @import("streaming.zig");
const queued = @import("queued.zig");
const resources = @import("resources.zig");

pub const StreamingIngestTarget = streaming.StreamingIngestTarget;
pub const StreamingIngestSource = streaming.StreamingIngestSource;
pub const SourceKind = streaming.SourceKind;
pub const IngestOptions = streaming.IngestOptions;
pub const IngestionResult = streaming.IngestionResult;
pub const KustoResult = kusto_common.KustoResult;
pub const KustoOperationOutcome = kusto_common.KustoOperationOutcome;
pub const QueuedIngestionResult = queued.QueuedIngestionResult;
pub const StatusTrackingHandle = queued.StatusTrackingHandle;

/// The route selected for an ingestion operation.
pub const ManagedIngestionRoute = enum {
    streaming,
    queued,
};

/// Owned managed-ingestion result. Call `deinit` exactly once.
///
/// A queued result is retained whole, including its resource diagnostics and
/// optional `StatusTrackingHandle`. Queue Storage acceptance/rejection/
/// ambiguity therefore remains distinct from Kusto/resource-manager errors,
/// which are returned in `KustoResult.err`.
pub const ManagedIngestionResult = union(enum) {
    streaming: IngestionResult,
    queued: QueuedIngestionResult,

    pub fn route(self: *const ManagedIngestionResult) ManagedIngestionRoute {
        return switch (self.*) {
            .streaming => .streaming,
            .queued => .queued,
        };
    }

    pub fn deinit(self: *ManagedIngestionResult, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .streaming => |*result| result.deinit(allocator),
            .queued => |*result| result.deinit(allocator),
        }
        self.* = undefined;
    }

    /// Transfers the optional queued status-tracking handle. Streaming
    /// results never have one.
    pub fn takeTracking(self: *ManagedIngestionResult) ?StatusTrackingHandle {
        return switch (self.*) {
            .streaming => null,
            .queued => |*result| result.takeTracking(),
        };
    }

    fn intoCompatibility(
        self: *ManagedIngestionResult,
        allocator: std.mem.Allocator,
    ) IngestionResult {
        return switch (self.*) {
            .streaming => |result| blk: {
                self.* = undefined;
                break :blk result;
            },
            .queued => |*result| blk: {
                const compatibility = queued.compatibilityResult(allocator, result);
                self.* = undefined;
                break :blk compatibility;
            },
        };
    }
};

/// Managed direct-to-queued ingestion.
///
/// This value borrows its transport, optional `ResourceManager`, and optional
/// shared `KustoConnection`. They must outlive this client, all copies of it,
/// and all calls. A shared connection (and a manager backed by one) is not
/// concurrent-safe; callers must externally serialize use.
pub const ManagedIngestClient = struct {
    streaming: streaming.StreamingIngestClient,
    queued: queued.QueuedIngestClient,

    /// Legacy unauthenticated constructor. Queue fallback requires an
    /// injected ResourceManager or a shared connection, so a streaming
    /// fallback from this constructor reports
    /// `QueuedIngestionResourceManagerRequired`.
    pub fn init(
        connection: kusto_common.ConnectionProperties,
        transport: *core.http.HttpTransport,
    ) ManagedIngestClient {
        return .{
            .streaming = streaming.StreamingIngestClient.init(connection, transport),
            .queued = queued.QueuedIngestClient.init(connection, transport),
        };
    }

    /// Creates a client borrowing a shared authenticated connection. A
    /// short-lived resource manager is created for queue operations.
    pub fn initWithConnection(connection: *kusto_common.KustoConnection) ManagedIngestClient {
        return .{
            .streaming = streaming.StreamingIngestClient.initWithConnection(connection),
            .queued = queued.QueuedIngestClient.initWithConnection(connection),
        };
    }

    /// Creates a client with an injected ResourceManager and raw transport.
    /// The manager and transport are borrowed. The legacy streaming client
    /// cannot authenticate; use `initWithConnectionAndResourceManager` for
    /// authenticated direct ingestion.
    pub fn initWithResourceManager(
        connection: kusto_common.ConnectionProperties,
        manager: *resources.ResourceManager,
        transport: *core.http.HttpTransport,
    ) ManagedIngestClient {
        return .{
            .streaming = streaming.StreamingIngestClient.init(connection, transport),
            .queued = queued.QueuedIngestClient.initWithResourceManager(manager, transport),
        };
    }

    /// Creates a client borrowing both a shared connection and an injected
    /// resource manager. This retains resource discovery caching and ranking.
    pub fn initWithConnectionAndResourceManager(
        connection: *kusto_common.KustoConnection,
        manager: *resources.ResourceManager,
    ) ManagedIngestClient {
        return .{
            .streaming = streaming.StreamingIngestClient.initWithConnection(connection),
            .queued = queued.QueuedIngestClient.initWithConnectionAndResourceManager(
                connection,
                manager,
            ),
        };
    }

    /// Ingests a runtime source and returns the selected rich result.
    ///
    /// Streaming retries are performed by `StreamingIngestClient`. Only its
    /// final retryable, known-not-accepted failure falls back to Queue, and
    /// only when the effective source can be replayed. An unknown outcome,
    /// cancellation, or one-shot source is never queued after streaming.
    pub fn ingestResult(
        self: *ManagedIngestClient,
        allocator: std.mem.Allocator,
        target: StreamingIngestTarget,
        source: StreamingIngestSource,
        options: IngestOptions,
    ) !KustoResult(ManagedIngestionResult) {
        try validateThreshold(options);
        try checkCancelled(options.cancellation);

        // Queue may be selected before direct streaming, so IDs always obey
        // Queue's canonical UUID contract even for a streaming-only success.
        const canonical_id = try queued.makeLogicalSourceId(allocator, options.source_id);
        defer allocator.free(canonical_id);
        var normalized_options = options;
        normalized_options.source_id = canonical_id;

        if (requiresQueueBeforeStreaming(source, normalized_options)) {
            try checkCancelled(normalized_options.cancellation);
            return self.ingestQueued(
                allocator,
                target,
                source,
                normalized_options,
            );
        }

        const raw_size = try knownRawSize(source, normalized_options);
        if (raw_size) |size| {
            if (size > normalized_options.managed_streaming_threshold_bytes) {
                try checkCancelled(normalized_options.cancellation);
                return self.ingestQueued(allocator, target, source, normalized_options);
            }

            var direct_source = source;
            if (source == .reader and source.reader.raw_size == null) {
                direct_source = .{ .reader = .{
                    .reader = source.reader.reader,
                    .raw_size = size,
                } };
            }
            var direct_options = normalized_options;
            // Pin the size used for the managed decision. Streaming rechecks
            // files when it opens them and rejects a concurrently changed
            // source before entering the transport.
            if (direct_options.raw_size == null) direct_options.raw_size = size;
            if (source == .blob_uri) direct_options.compression = .none;
            return self.ingestStreamingThenMaybeQueue(
                allocator,
                target,
                direct_source,
                direct_options,
            );
        }

        // Unknown existing Blob URIs deliberately skip direct ingestion. The
        // only remaining unknown source shape is a borrowed one-shot reader.
        switch (source) {
            .reader => |reader_source| {
                var classified = try classifyUnknownReader(
                    allocator,
                    reader_source.reader,
                    normalized_options.managed_streaming_threshold_bytes,
                    normalized_options.cancellation,
                );
                defer classified.deinit(allocator);
                try checkCancelled(normalized_options.cancellation);

                switch (classified) {
                    .small => |value| {
                        const bytes = value.bytes;
                        var direct_options = normalized_options;
                        direct_options.raw_size = @intCast(bytes.len);
                        return self.ingestStreamingThenMaybeQueue(
                            allocator,
                            target,
                            .{ .bytes = bytes },
                            direct_options,
                        );
                    },
                    .large => |*prefix_tail| {
                        return self.ingestQueued(
                            allocator,
                            target,
                            .{ .reader = .{
                                .reader = &prefix_tail.interface,
                                .raw_size = null,
                            } },
                            normalized_options,
                        );
                    },
                }
            },
            .blob_uri => return self.ingestQueued(allocator, target, source, normalized_options),
            else => unreachable,
        }
    }

    /// Compatibility flattening wrapper. It intentionally discards queued
    /// attempts and status tracking; use `ingestResult` for the rich result.
    pub fn ingest(
        self: *ManagedIngestClient,
        allocator: std.mem.Allocator,
        target: StreamingIngestTarget,
        source: StreamingIngestSource,
        options: IngestOptions,
    ) !IngestionResult {
        var result = try self.ingestResult(allocator, target, source, options);
        return switch (result) {
            .ok => |value| blk: {
                var managed = value;
                break :blk managed.intoCompatibility(allocator);
            },
            .partial => unreachable,
            .err => |*failure| {
                const outcome = failure.outcome;
                failure.deinit();
                if (outcome == .unknown) return error.KustoIngestionOutcomeUnknown;
                return error.KustoIngestionFailed;
            },
        };
    }

    /// Existing slice wrapper retained for source compatibility.
    pub fn ingestFromSlice(
        self: *ManagedIngestClient,
        allocator: std.mem.Allocator,
        database: []const u8,
        table: []const u8,
        data: []const u8,
        options: IngestOptions,
    ) !IngestionResult {
        return self.ingest(
            allocator,
            .{ .database = database, .table = table },
            .{ .bytes = data },
            options,
        );
    }

    /// Existing structured slice wrapper retained for source compatibility.
    /// It intentionally flattens queued diagnostics and tracking.
    pub fn ingestFromSliceResult(
        self: *ManagedIngestClient,
        allocator: std.mem.Allocator,
        database: []const u8,
        table: []const u8,
        data: []const u8,
        options: IngestOptions,
    ) !KustoResult(IngestionResult) {
        const result = try self.ingestResult(
            allocator,
            .{ .database = database, .table = table },
            .{ .bytes = data },
            options,
        );
        return switch (result) {
            .ok => |value| blk: {
                var managed = value;
                break :blk .{ .ok = managed.intoCompatibility(allocator) };
            },
            .partial => unreachable,
            .err => |failure| .{ .err = failure },
        };
    }

    /// No allocations are owned by this borrowing client.
    pub fn deinit(self: *ManagedIngestClient, allocator: std.mem.Allocator) void {
        self.queued.deinit(allocator);
    }

    fn ingestStreamingThenMaybeQueue(
        self: *ManagedIngestClient,
        allocator: std.mem.Allocator,
        target: StreamingIngestTarget,
        source: StreamingIngestSource,
        options: IngestOptions,
    ) !KustoResult(ManagedIngestionResult) {
        try checkCancelled(options.cancellation);
        const streamed = try self.streaming.ingestResult(allocator, target, source, options);
        return switch (streamed) {
            .ok => |result| .{ .ok = .{ .streaming = result } },
            .partial => unreachable,
            .err => |failure| blk: {
                var owned_failure = failure;
                const can_fallback = source.isReplayable() and
                    owned_failure.retryable and
                    owned_failure.outcome == .known_not_accepted and
                    !isCancelled(options.cancellation);
                if (!can_fallback) break :blk .{ .err = owned_failure };

                owned_failure.deinit();
                try checkCancelled(options.cancellation);
                break :blk self.ingestQueued(allocator, target, source, options);
            },
        };
    }

    fn ingestQueued(
        self: *ManagedIngestClient,
        allocator: std.mem.Allocator,
        target: StreamingIngestTarget,
        source: StreamingIngestSource,
        options: IngestOptions,
    ) !KustoResult(ManagedIngestionResult) {
        try checkCancelled(options.cancellation);
        var submitted = try self.queued.ingest(allocator, target, source, options);
        if (submitted.resource_failure) |failure| {
            submitted.resource_failure = null;
            submitted.deinit(allocator);
            return .{ .err = failure };
        }
        return .{ .ok = .{ .queued = submitted } };
    }
};

fn validateThreshold(options: IngestOptions) !void {
    if (options.managed_streaming_threshold_bytes == 0 or
        options.managed_streaming_threshold_bytes > streaming.max_streaming_payload_bytes)
        return error.InvalidManagedStreamingThreshold;
}

fn isCancelled(cancellation: ?*const core.http.CancellationToken) bool {
    return if (cancellation) |token| token.isCancelled() else false;
}

fn checkCancelled(cancellation: ?*const core.http.CancellationToken) !void {
    if (isCancelled(cancellation)) return error.OperationCancelled;
}

fn requiresQueueBeforeStreaming(source: StreamingIngestSource, options: IngestOptions) bool {
    if (!streamingFormatSupported(options.format)) return true;
    if (formatRequiresStreamingMapping(options.format) and options.mapping_name == null)
        return true;
    if (source == .file and queued.precompressedFileExtension(source.file) != null)
        return true;
    if (options.creation_time_unix_ms != null or options.validation_policy != null)
        return true;
    if (options.tags.len != 0 or options.drop_by_tags.len != 0 or
        options.ingest_if_not_exists.len != 0 or options.ignore_first_record)
        return true;
    // A direct URI has no raw payload to size locally. It is eligible only
    // when BlobUriSource supplied a known uncompressed size.
    if (source == .blob_uri and source.blob_uri.raw_size == null) return true;
    return false;
}

fn streamingFormatSupported(format: streaming.DataFormat) bool {
    return switch (format) {
        .csv, .tsv, .scsv, .sohsv, .psv, .json, .multi_json, .avro => true,
        .parquet, .orc => false,
    };
}

fn formatRequiresStreamingMapping(format: streaming.DataFormat) bool {
    return switch (format) {
        .json, .multi_json, .avro => true,
        else => false,
    };
}

fn knownRawSize(source: StreamingIngestSource, options: IngestOptions) !?u64 {
    return switch (source) {
        .bytes => |bytes| @intCast(bytes.len),
        .reader => |reader| reader.raw_size orelse options.raw_size,
        .replay_reader => |factory| factory.raw_size,
        .blob_uri => |blob| blob.raw_size,
        .file => |path| try fileSize(path),
    };
}

fn fileSize(path: []const u8) !u64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    var file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    if (stat.kind != .file) return error.ManagedSourceNotFile;
    return stat.size;
}

const ClassifiedReader = union(enum) {
    small: struct {
        allocation: []u8,
        bytes: []u8,
    },
    large: PrefixTailReader,

    fn deinit(self: *ClassifiedReader, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .small => |value| allocator.free(value.allocation),
            .large => |*prefix_tail| allocator.free(prefix_tail.prefix),
        }
        self.* = undefined;
    }
};

fn classifyUnknownReader(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
    threshold: u64,
    cancellation: ?*const core.http.CancellationToken,
) !ClassifiedReader {
    const max_prefix: usize = std.math.cast(usize, threshold + 1) orelse
        return error.InvalidManagedStreamingThreshold;
    const prefix = try allocator.alloc(u8, max_prefix);
    errdefer allocator.free(prefix);

    var used: usize = 0;
    while (used != prefix.len) {
        try checkCancelled(cancellation);
        const count = try reader.readSliceShort(prefix[used..@min(prefix.len, used + 16 * 1024)]);
        try checkCancelled(cancellation);
        if (count == 0) return .{ .small = .{
            .allocation = prefix,
            .bytes = prefix[0..used],
        } };
        used += count;
    }

    return .{ .large = PrefixTailReader.init(prefix, reader, cancellation) };
}

/// A bounded buffered reader that returns an already-classified prefix before
/// delegating to the original reader. It does not rewind or replace the tail,
/// so internal buffered state remains intact.
const PrefixTailReader = struct {
    interface: std.Io.Reader,
    prefix: []const u8,
    prefix_offset: usize = 0,
    tail: *std.Io.Reader,
    cancellation: ?*const core.http.CancellationToken,
    tail_buffer: [16 * 1024]u8 = undefined,
    tail_start: usize = 0,
    tail_end: usize = 0,

    fn init(
        prefix: []const u8,
        tail: *std.Io.Reader,
        cancellation: ?*const core.http.CancellationToken,
    ) PrefixTailReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .prefix = prefix,
            .tail = tail,
            .cancellation = cancellation,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *PrefixTailReader = @alignCast(@fieldParentPtr("interface", interface));
        if (isCancelled(self.cancellation)) return error.ReadFailed;

        while (true) {
            const prefix_remaining = self.prefix[self.prefix_offset..];
            if (prefix_remaining.len != 0) {
                const count = writer.write(
                    prefix_remaining[0..limit.minInt(prefix_remaining.len)],
                ) catch return error.WriteFailed;
                self.prefix_offset += count;
                return count;
            }

            const pending = self.tail_buffer[self.tail_start..self.tail_end];
            if (pending.len != 0) {
                const count = writer.write(limit.slice(pending)) catch return error.WriteFailed;
                self.tail_start += count;
                return count;
            }

            if (limit.minInt(std.math.maxInt(usize)) == 0) return 0;
            const count = self.tail.readSliceShort(&self.tail_buffer) catch return error.ReadFailed;
            if (count == 0) return error.EndOfStream;
            self.tail_start = 0;
            self.tail_end = count;
        }
    }
};

test "managed routing decisions honor threshold formats properties and blob size" {
    const options = IngestOptions{ .managed_streaming_threshold_bytes = 4 };
    try std.testing.expect(!requiresQueueBeforeStreaming(.{ .bytes = "four" }, options));
    inline for ([_]streaming.DataFormat{ .json, .multi_json, .avro }) |format| {
        try std.testing.expect(requiresQueueBeforeStreaming(
            .{ .bytes = "four" },
            .{ .format = format },
        ));
        try std.testing.expect(!requiresQueueBeforeStreaming(
            .{ .bytes = "four" },
            .{ .format = format, .mapping_name = "Map" },
        ));
    }
    try std.testing.expect(requiresQueueBeforeStreaming(
        .{ .bytes = "four" },
        .{ .format = .parquet },
    ));
    try std.testing.expect(requiresQueueBeforeStreaming(
        .{ .bytes = "four" },
        .{ .tags = &.{"queued-only"} },
    ));
    try std.testing.expect(requiresQueueBeforeStreaming(
        .{ .blob_uri = .{ .uri = "https://blob.example/c/a" } },
        options,
    ));
    try std.testing.expect(!requiresQueueBeforeStreaming(
        .{ .blob_uri = .{ .uri = "https://blob.example/c/a", .raw_size = 4 } },
        options,
    ));
    try std.testing.expect(requiresQueueBeforeStreaming(
        .{ .file = "input.csv.gz" },
        options,
    ));
    var known_reader = std.Io.Reader.fixed("four");
    try std.testing.expect(!requiresQueueBeforeStreaming(
        .{ .reader = .{ .reader = &known_reader, .raw_size = 4 } },
        options,
    ));
    try std.testing.expectError(
        error.InvalidManagedStreamingThreshold,
        validateThreshold(.{ .managed_streaming_threshold_bytes = 0 }),
    );
    try std.testing.expectError(
        error.InvalidManagedStreamingThreshold,
        validateThreshold(.{
            .managed_streaming_threshold_bytes = streaming.max_streaming_payload_bytes + 1,
        }),
    );
}

test "managed buffers small unknown readers and preserves large prefix tails" {
    const allocator = std.testing.allocator;

    {
        var source = std.Io.Reader.fixed("four");
        var classified = try classifyUnknownReader(allocator, &source, 4, null);
        defer classified.deinit(allocator);
        switch (classified) {
            .small => |value| try std.testing.expectEqualStrings("four", value.bytes),
            .large => return error.TestUnexpectedResult,
        }
    }

    {
        var source = std.Io.Reader.fixed("five!");
        var classified = try classifyUnknownReader(allocator, &source, 4, null);
        defer classified.deinit(allocator);
        switch (classified) {
            .small => return error.TestUnexpectedResult,
            .large => |*prefix_tail| {
                const bytes = try prefix_tail.interface.allocRemaining(allocator, .unlimited);
                defer allocator.free(bytes);
                try std.testing.expectEqualStrings("five!", bytes);
                var extra: [1]u8 = undefined;
                try std.testing.expectEqual(
                    @as(usize, 0),
                    try source.readSliceShort(&extra),
                );
            },
        }
    }
}

test "managed small unknown reader streams as replayable bytes with canonical ID" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var client = ManagedIngestClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        transport.asTransport(),
    );
    var reader = std.Io.Reader.fixed("tiny");

    var result = try client.ingestResult(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .reader = .{ .reader = &reader } },
        .{
            .compression = .none,
            .source_id = "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA",
            .managed_streaming_threshold_bytes = 4,
        },
    );
    defer result.deinit(allocator);
    switch (result) {
        .ok => |*managed_result| switch (managed_result.*) {
            .streaming => |*ingestion| {
                try std.testing.expectEqual(SourceKind.bytes, ingestion.source_kind.?);
                try std.testing.expectEqualStrings(
                    "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                    ingestion.ingestion_id.?,
                );
            },
            .queued => return error.TestUnexpectedResult,
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    try std.testing.expectEqualStrings("tiny", transport.last_body.?);
    try std.testing.expectEqualStrings(
        "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        transport.last_headers.get("x-ms-client-request-id").?,
    );
}

test "managed preflight queue does not enter direct transport" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var client = ManagedIngestClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        transport.asTransport(),
    );

    try std.testing.expectError(
        error.QueuedIngestionResourceManagerRequired,
        client.ingestResult(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .bytes = "large" },
            .{ .managed_streaming_threshold_bytes = 4 },
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

test "managed small blob streams with direct URI compression normalized" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var client = ManagedIngestClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        transport.asTransport(),
    );
    var result = try client.ingestResult(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .blob_uri = .{
            .uri = "https://existing.blob.core.windows.net/c/small.csv?sig=source",
            .raw_size = 4,
        } },
        .{},
    );
    defer result.deinit(allocator);
    try std.testing.expectEqual(ManagedIngestionRoute.streaming, result.ok.route());
    try std.testing.expect(
        std.mem.indexOf(u8, transport.last_url.?, "sourceKind=uri") != null,
    );
    try std.testing.expect(transport.last_headers.get("Content-Encoding") == null);
}

test "managed permanent ambiguous and one-shot streaming failures never queue" {
    const allocator = std.testing.allocator;

    {
        var transport = core.http.MockTransport.init(
            allocator,
            400,
            "{\"error\":{\"code\":\"BadRequest\",\"message\":\"permanent\"}}",
        );
        defer transport.deinit();
        var client = ManagedIngestClient.init(
            .{ .cluster_url = "https://cluster.kusto.windows.net" },
            transport.asTransport(),
        );
        var result = try client.ingestResult(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .bytes = "body" },
            .{ .compression = .none },
        );
        defer result.deinit(allocator);
        try std.testing.expectEqual(KustoOperationOutcome.known_not_accepted, result.err.outcome);
        try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    }

    {
        var transport = core.http.MockTransport.init(allocator, 200, "{}");
        transport.stream_fail_upload_after = 0;
        defer transport.deinit();
        var client = ManagedIngestClient.init(
            .{ .cluster_url = "https://cluster.kusto.windows.net" },
            transport.asTransport(),
        );
        var result = try client.ingestResult(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .bytes = "body" },
            .{ .compression = .none },
        );
        defer result.deinit(allocator);
        try std.testing.expectEqual(KustoOperationOutcome.unknown, result.err.outcome);
        try std.testing.expectEqual(@as(usize, 0), transport.call_count);
    }

    {
        var transport = core.http.MockTransport.init(
            allocator,
            503,
            "{\"error\":{\"code\":\"ServiceUnavailable\",\"message\":\"retry\"}}",
        );
        defer transport.deinit();
        var client = ManagedIngestClient.init(
            .{ .cluster_url = "https://cluster.kusto.windows.net" },
            transport.asTransport(),
        );
        var reader = std.Io.Reader.fixed("body");
        var result = try client.ingestResult(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .reader = .{ .reader = &reader, .raw_size = 4 } },
            .{ .compression = .none, .retry = .{ .initial_delay_ms = 0, .max_delay_ms = 0 } },
        );
        defer result.deinit(allocator);
        try std.testing.expectEqual(KustoOperationOutcome.known_not_accepted, result.err.outcome);
        try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    }
}

test "managed cancellation prevents either route" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var token = core.http.CancellationToken{};
    token.cancel();
    var client = ManagedIngestClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        transport.asTransport(),
    );
    try std.testing.expectError(
        error.OperationCancelled,
        client.ingestResult(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .bytes = "body" },
            .{ .cancellation = &token },
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

const managed_test_resource_body =
    \\{"Tables":[{"TableName":"Resources","Columns":[{"ColumnName":"ResourceTypeName","DataType":"String"},{"ColumnName":"StorageRoot","DataType":"String"}],"Rows":[
    \\["SecuredReadyForAggregationQueue","https://accounta.queue.core.windows.net/ready-a?sig=queue-a"],
    \\["SecuredReadyForAggregationQueue","https://accountb.queue.core.windows.net/ready-b?sig=queue-b"],
    \\["TempStorage","https://accounta.blob.core.windows.net/temp-a?sig=blob-a"],
    \\["TempStorage","https://accountb.blob.core.windows.net/temp-b?sig=blob-b"],
    \\["IngestionStatusTable","https://accounta.table.core.windows.net/ingestion-status?sig=table-a"]
    \\]}]}
;

const managed_test_token_body =
    \\{"Tables":[{"TableName":"Token","Columns":[{"ColumnName":"AuthorizationContext","DataType":"String"}],"Rows":[["identity-context"]]}]}
;

const ManagedTestExecutor = struct {
    calls: usize = 0,
    cancellation: ?*core.http.CancellationToken = null,
    cancel_after_calls: ?usize = null,

    fn asExecutor(self: *ManagedTestExecutor) resources.ResourceCommandExecutor {
        return .{ .context = self, .executeFn = &execute };
    }

    fn execute(
        context: *anyopaque,
        allocator: std.mem.Allocator,
        _: []const u8,
        command: []const u8,
    ) !kusto_common.KustoResult(data_result.KustoResponseDataSet) {
        const self: *ManagedTestExecutor = @ptrCast(@alignCast(context));
        self.calls += 1;
        if (self.cancel_after_calls == self.calls) self.cancellation.?.cancel();
        const body = if (std.mem.eql(u8, command, ".get ingestion resources"))
            managed_test_resource_body
        else if (std.mem.eql(u8, command, ".get kusto identity token"))
            managed_test_token_body
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

const ManagedFallbackTransport = struct {
    direct: core.http.MockTransport,
    storage: core.http.MockTransport,
    transport: core.http.HttpTransport = .{ .sendFn = &send, .openFn = &open },

    fn init(allocator: std.mem.Allocator) ManagedFallbackTransport {
        return .{
            .direct = core.http.MockTransport.init(
                allocator,
                503,
                "{\"error\":{\"code\":\"ServiceUnavailable\",\"message\":\"retry\"}}",
            ),
            .storage = core.http.MockTransport.init(allocator, 201, ""),
        };
    }

    fn deinit(self: *ManagedFallbackTransport) void {
        self.direct.deinit();
        self.storage.deinit();
    }

    fn asTransport(self: *ManagedFallbackTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn send(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *ManagedFallbackTransport = @alignCast(
            @fieldParentPtr("transport", transport),
        );
        self.storage.response_status =
            if (std.mem.indexOf(u8, request.url, ".table.core.windows.net") != null) 204 else 201;
        return self.storage.transport.sendFn(&self.storage.transport, request);
    }

    fn open(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
        options: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *ManagedFallbackTransport = @alignCast(
            @fieldParentPtr("transport", transport),
        );
        if (std.mem.indexOf(u8, request.url, ".core.windows.net") != null) {
            self.storage.response_status =
                if (std.mem.indexOf(u8, request.url, ".table.core.windows.net") != null) 204 else 201;
            return self.storage.transport.openFn.?(&self.storage.transport, request, options);
        }
        return self.direct.transport.openFn.?(&self.direct.transport, request, options);
    }
};

const CancelOnTailReader = struct {
    interface: std.Io.Reader,
    token: *core.http.CancellationToken,
    bytes: []const u8,
    offset: usize = 0,
    cancel_after: usize,

    fn init(
        token: *core.http.CancellationToken,
        bytes: []const u8,
        cancel_after: usize,
    ) CancelOnTailReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .token = token,
            .bytes = bytes,
            .cancel_after = cancel_after,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *CancelOnTailReader = @alignCast(
            @fieldParentPtr("interface", interface),
        );
        if (self.offset >= self.cancel_after) {
            self.token.cancel();
            return error.ReadFailed;
        }
        if (self.offset == self.bytes.len) return error.EndOfStream;
        const end = @min(self.bytes.len, self.cancel_after);
        const bytes = limit.sliceConst(self.bytes[self.offset..end]);
        try writer.writeAll(bytes);
        self.offset += bytes.len;
        return bytes.len;
    }
};

test "managed retryable known failure falls back once with one canonical ID" {
    const allocator = std.testing.allocator;
    var executor = ManagedTestExecutor{};
    var manager = try resources.ResourceManager.init(
        allocator,
        std.testing.io,
        executor.asExecutor(),
        "db",
        .{ .cache_ttl_ms = 60_000 },
    );
    defer manager.deinit();
    var transport = ManagedFallbackTransport.init(allocator);
    defer transport.deinit();
    var client = ManagedIngestClient.initWithResourceManager(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        &manager,
        transport.asTransport(),
    );

    var result = try client.ingestResult(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .bytes = "retry body" },
        .{
            .compression = .none,
            .queued_compression = .none,
            .source_id = "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB",
            .retry = .{ .initial_delay_ms = 0, .max_delay_ms = 0 },
            .report_level = .failures_and_successes,
            .report_method = .queue_and_table,
        },
    );
    defer result.deinit(allocator);
    switch (result) {
        .ok => |*managed_result| switch (managed_result.*) {
            .queued => |*submission| {
                try std.testing.expectEqual(
                    queued.QueuedSubmissionOutcome.queue_accepted,
                    submission.outcome,
                );
                try std.testing.expectEqualStrings(
                    "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
                    submission.ingestion_id,
                );
                try std.testing.expect(submission.tracking != null);
            },
            .streaming => return error.TestUnexpectedResult,
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(usize, 2), transport.direct.call_count);
    try std.testing.expectEqual(@as(usize, 3), transport.storage.call_count);
    try std.testing.expectEqual(@as(usize, 2), executor.calls);
    try std.testing.expectEqualStrings(
        "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        transport.direct.last_headers.get("x-ms-client-request-id").?,
    );
}

test "managed large unknown reader queues its prefix and tail once" {
    const allocator = std.testing.allocator;
    var executor = ManagedTestExecutor{};
    var manager = try resources.ResourceManager.init(
        allocator,
        std.testing.io,
        executor.asExecutor(),
        "db",
        .{ .cache_ttl_ms = 60_000 },
    );
    defer manager.deinit();
    var transport = ManagedFallbackTransport.init(allocator);
    defer transport.deinit();
    var client = ManagedIngestClient.initWithResourceManager(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        &manager,
        transport.asTransport(),
    );
    var reader = std.Io.Reader.fixed("prefix and tail");

    var result = try client.ingestResult(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .reader = .{ .reader = &reader } },
        .{
            .compression = .none,
            .queued_compression = .none,
            .source_id = "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC",
            .managed_streaming_threshold_bytes = 4,
        },
    );
    defer result.deinit(allocator);
    switch (result) {
        .ok => |*managed_result| switch (managed_result.*) {
            .queued => |*submission| {
                try std.testing.expectEqual(
                    queued.QueuedSubmissionOutcome.queue_accepted,
                    submission.outcome,
                );
                try std.testing.expectEqual(@as(?u64, null), submission.raw_size);
            },
            .streaming => return error.TestUnexpectedResult,
        },
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expectEqual(@as(usize, 0), transport.direct.call_count);
    try std.testing.expectEqual(@as(usize, 3), transport.storage.call_count);
    try std.testing.expectEqual(@as(usize, 2), executor.calls);
}

test "managed cancellation during resource refresh starts no storage request" {
    const allocator = std.testing.allocator;
    var token = core.http.CancellationToken{};
    var executor = ManagedTestExecutor{
        .cancellation = &token,
        .cancel_after_calls = 2,
    };
    var manager = try resources.ResourceManager.init(
        allocator,
        std.testing.io,
        executor.asExecutor(),
        "db",
        .{ .cache_ttl_ms = 60_000 },
    );
    defer manager.deinit();
    var transport = ManagedFallbackTransport.init(allocator);
    defer transport.deinit();
    var client = ManagedIngestClient.initWithResourceManager(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        &manager,
        transport.asTransport(),
    );

    try std.testing.expectError(
        error.OperationCancelled,
        client.ingestResult(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .bytes = "large" },
            .{
                .managed_streaming_threshold_bytes = 4,
                .cancellation = &token,
            },
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.direct.call_count);
    try std.testing.expectEqual(@as(usize, 0), transport.storage.call_count);
}

test "managed cancellation in a classified reader surfaces as cancellation" {
    const allocator = std.testing.allocator;
    var executor = ManagedTestExecutor{};
    var manager = try resources.ResourceManager.init(
        allocator,
        std.testing.io,
        executor.asExecutor(),
        "db",
        .{ .cache_ttl_ms = 60_000 },
    );
    defer manager.deinit();
    var transport = ManagedFallbackTransport.init(allocator);
    defer transport.deinit();
    var client = ManagedIngestClient.initWithResourceManager(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        &manager,
        transport.asTransport(),
    );
    var token = core.http.CancellationToken{};
    var reader = CancelOnTailReader.init(&token, "prefix and tail", 5);

    try std.testing.expectError(
        error.OperationCancelled,
        client.ingestResult(
            allocator,
            .{ .database = "DB", .table = "Table" },
            .{ .reader = .{ .reader = &reader.interface } },
            .{
                .queued_compression = .none,
                .managed_streaming_threshold_bytes = 4,
                .cancellation = &token,
            },
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.direct.call_count);
    try std.testing.expectEqual(@as(usize, 0), transport.storage.call_count);
}

fn managedAllocationFixture(allocator: std.mem.Allocator) !void {
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var client = ManagedIngestClient.init(
        .{ .cluster_url = "https://cluster.kusto.windows.net" },
        transport.asTransport(),
    );
    var reader = std.Io.Reader.fixed("tiny");
    var result = try client.ingestResult(
        allocator,
        .{ .database = "DB", .table = "Table" },
        .{ .reader = .{ .reader = &reader } },
        .{
            .compression = .none,
            .source_id = "DDDDDDDD-DDDD-4DDD-8DDD-DDDDDDDDDDDD",
            .managed_streaming_threshold_bytes = 4,
        },
    );
    defer result.deinit(allocator);
    try std.testing.expectEqual(ManagedIngestionRoute.streaming, result.ok.route());
}

test "managed result and reader classification clean up allocation failures" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        managedAllocationFixture,
        .{},
    );
}
