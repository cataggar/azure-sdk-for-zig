//! Pull-based, bounded-memory progressive Kusto query streaming.
const std = @import("std");
const core = @import("azure_core");
const kusto_common = @import("azure_kusto_common");
const result = @import("result.zig");

/// Controls progressive response parsing. `deadline_ms` is a best-effort
/// budget checked before and after pulls; it cannot interrupt a blocking
/// `std.Io.Reader` read.
pub const ProgressiveQueryOptions = struct {
    /// Maximum bytes in one complete V2 frame object. The stream reuses a
    /// buffer of at most this size and an outstanding event owns one frame.
    max_frame_bytes: usize = 4 * 1024 * 1024,
    /// Maximum distinct table IDs retained for frame-order validation.
    max_table_count: usize = 1024,
    /// Best-effort duration from successful stream creation until a pull fails
    /// with `OperationTimedOut`.
    deadline_ms: ?u64 = null,
    /// Checked by core while opening and by this stream between pulls. It
    /// cannot interrupt a reader already blocked in the transport.
    cancellation: ?*const core.http.CancellationToken = null,
};

pub const ProgressiveFrame = result.ProgressiveFrame;
pub const ProgressiveTableAction = result.ProgressiveTableAction;
pub const ProgressiveTableBatch = result.ProgressiveTableBatch;
pub const ProgressiveTableProgress = result.ProgressiveTableProgress;
pub const ProgressiveTableCompletion = result.ProgressiveTableCompletion;
pub const ProgressiveDataSetCompletion = result.ProgressiveDataSetCompletion;

const CancelFn = *const fn (
    context: *anyopaque,
    allocator: std.mem.Allocator,
    database: []const u8,
    request_id: []const u8,
) anyerror!kusto_common.KustoResult(result.KustoResponseDataSet);

const ArrayState = enum {
    begin,
    expect_first_value,
    expect_next_value,
    after_value,
    after_array,
    complete,
    closed,
};

const Consumer = enum {
    none,
    frames,
    tables,
    rows,
};

/// A heap-owned, single-consumer progressive V2 query stream.
///
/// The stream owns the HTTP operation, decoder state, query database, and
/// original `x-ms-client-request-id`. It borrows the client context supplied
/// by the data client, which must outlive the stream. Call `finish` to drain
/// and validate a response, or `deinit` to deterministically abort without
/// draining.
pub const ProgressiveQueryStream = struct {
    allocator: std.mem.Allocator,
    operation: ?*core.http.HttpOperation,
    reader: ?*std.Io.Reader,
    decoder: result.ProgressiveDecoder,
    options: ProgressiveQueryOptions,
    deadline_ns: ?i128,
    original_request_id: []u8,
    database: []u8,
    cancel_context: *anyopaque,
    cancel_fn: CancelFn,
    frame_buffer: std.ArrayList(u8) = .empty,
    array_state: ArrayState = .begin,
    consumer: Consumer = .none,

    pub fn create(
        allocator: std.mem.Allocator,
        operation: *core.http.HttpOperation,
        options: ProgressiveQueryOptions,
        decode_options: result.DecodeOptions,
        original_request_id: []const u8,
        database: []const u8,
        cancel_context: *anyopaque,
        cancel_fn: CancelFn,
    ) !*ProgressiveQueryStream {
        if (options.max_frame_bytes == 0) return error.InvalidProgressiveFrameLimit;
        if (options.max_table_count == 0) return error.InvalidProgressiveTableLimit;
        const reader = try operation.reader();
        const request_id = try allocator.dupe(u8, original_request_id);
        errdefer allocator.free(request_id);
        const database_copy = try allocator.dupe(u8, database);
        errdefer allocator.free(database_copy);
        const self = try allocator.create(ProgressiveQueryStream);
        errdefer allocator.destroy(self);
        var decoder = result.ProgressiveDecoder.init(allocator, decode_options, .query);
        decoder.max_table_count = options.max_table_count;
        self.* = .{
            .allocator = allocator,
            .operation = operation,
            .reader = reader,
            .decoder = decoder,
            .options = options,
            .deadline_ns = deadlineFromNow(options.deadline_ms),
            .original_request_id = request_id,
            .database = database_copy,
            .cancel_context = cancel_context,
            .cancel_fn = cancel_fn,
        };
        return self;
    }

    /// Stops without draining. This is the deterministic early-exit path and
    /// does not submit a server-side cancellation command.
    pub fn abort(self: *ProgressiveQueryStream) void {
        self.closeOperation(.abort);
    }

    /// Cancels the active local operation first, then sends non-retryable
    /// `.cancel query "<original request id>"` through the owning client.
    pub fn cancel(self: *ProgressiveQueryStream) !kusto_common.KustoResult(result.KustoResponseDataSet) {
        if (self.operation == null or self.decoder.saw_completion)
            return error.ProgressiveQueryNotActive;
        self.closeOperation(.cancel);
        return self.cancel_fn(
            self.cancel_context,
            self.allocator,
            self.database,
            self.original_request_id,
        );
    }

    /// Returns the original query request ID used as the server cancellation
    /// target. It is not the response activity ID.
    pub fn clientRequestId(self: *const ProgressiveQueryStream) []const u8 {
        return self.original_request_id;
    }

    /// Pulls the next owned V2 event. The caller owns a non-null event and
    /// must call `deinit`; no event remains retained by the stream.
    pub fn next(self: *ProgressiveQueryStream) !?ProgressiveFrame {
        try self.claim(.frames);
        return self.nextInternal();
    }

    /// Returns a thin exclusive iterator over all frames.
    pub fn frameIterator(self: *ProgressiveQueryStream) !ProgressiveFrameIterator {
        try self.claim(.frames);
        return .{ .stream = self };
    }

    /// Returns an exclusive iterator over table data, progress, and completion
    /// events. Dataset completion is also retained so partial failure remains
    /// visible. Other frames are deinitialized.
    pub fn tableIterator(self: *ProgressiveQueryStream) !ProgressiveTableIterator {
        try self.claim(.tables);
        return .{ .stream = self };
    }

    /// Returns an exclusive iterator over rows and completion events. Borrowed
    /// payloads become invalid on its next call or `deinit`. A `replace` batch
    /// with a null row resets the table before subsequent append rows.
    pub fn rowIterator(self: *ProgressiveQueryStream) !ProgressiveRowIterator {
        try self.claim(.rows);
        return .{ .stream = self };
    }

    /// Drains remaining frames, validates closing array punctuation and V2
    /// completion state, and finishes the HTTP operation. Drained events are
    /// discarded; use `next` when individual partial failures are required.
    pub fn finish(self: *ProgressiveQueryStream) !void {
        while (try self.nextInternal()) |*frame| frame.deinit(self.allocator);
    }

    /// Does not auto-drain. An active operation is aborted before its storage
    /// is released, and the stream allocation must be deinitialized exactly
    /// once by its owner.
    pub fn deinit(self: *ProgressiveQueryStream) void {
        self.closeOperation(.abort);
        self.decoder.deinit();
        self.frame_buffer.deinit(self.allocator);
        self.allocator.free(self.original_request_id);
        self.allocator.free(self.database);
        self.allocator.destroy(self);
    }

    fn nextInternal(self: *ProgressiveQueryStream) !?ProgressiveFrame {
        errdefer self.closeOperation(.abort);
        try self.checkInterruption();
        while (true) {
            switch (self.array_state) {
                .begin => {
                    const byte = (try self.nextNonWhitespace()) orelse return error.MalformedKustoResponse;
                    if (byte != '[') return error.MalformedKustoResponse;
                    self.array_state = .expect_first_value;
                },
                .expect_first_value, .expect_next_value => {
                    const byte = (try self.nextNonWhitespace()) orelse return error.MalformedKustoResponse;
                    if (byte == ']') {
                        if (self.array_state == .expect_next_value)
                            return error.MalformedKustoResponse;
                        self.array_state = .after_array;
                        continue;
                    }
                    if (byte != '{') return error.MalformedKustoResponse;
                    const raw_json = try self.readObject(byte);
                    self.array_state = .after_value;
                    var frame = try self.decoder.decodeOwnedFrame(raw_json);
                    errdefer frame.deinit(self.allocator);
                    try self.applyFrameCorrelation(&frame);
                    try self.checkInterruption();
                    return frame;
                },
                .after_value => {
                    const byte = (try self.nextNonWhitespace()) orelse return error.MalformedKustoResponse;
                    switch (byte) {
                        ',' => self.array_state = .expect_next_value,
                        ']' => self.array_state = .after_array,
                        else => return error.MalformedKustoResponse,
                    }
                },
                .after_array => {
                    while (try self.readByte()) |byte| {
                        if (!std.ascii.isWhitespace(byte))
                            return error.MalformedKustoResponse;
                    }
                    try self.decoder.finish();
                    const operation = self.operation orelse return error.ProgressiveQueryClosed;
                    try operation.finish();
                    operation.deinit();
                    self.operation = null;
                    self.reader = null;
                    self.array_state = .complete;
                    try self.checkInterruption();
                    return null;
                },
                .complete => return null,
                .closed => return error.ProgressiveQueryClosed,
            }
        }
    }

    fn readObject(self: *ProgressiveQueryStream, first: u8) ![]u8 {
        self.frame_buffer.clearRetainingCapacity();
        try self.appendFrameByte(first);
        var depth: usize = 1;
        var in_string = false;
        var escaped = false;
        while (true) {
            const byte = (try self.readByte()) orelse return error.MalformedKustoResponse;
            try self.appendFrameByte(byte);
            if (in_string) {
                if (escaped) {
                    escaped = false;
                } else if (byte == '\\') {
                    escaped = true;
                } else if (byte == '"') {
                    in_string = false;
                }
                continue;
            }
            switch (byte) {
                '"' => in_string = true,
                '{' => depth += 1,
                '}' => {
                    depth -= 1;
                    if (depth == 0)
                        return self.allocator.dupe(u8, self.frame_buffer.items);
                },
                else => {},
            }
        }
    }

    fn appendFrameByte(self: *ProgressiveQueryStream, byte: u8) !void {
        if (self.frame_buffer.items.len >= self.options.max_frame_bytes)
            return error.KustoProgressiveFrameTooLarge;
        try self.frame_buffer.append(self.allocator, byte);
    }

    fn nextNonWhitespace(self: *ProgressiveQueryStream) !?u8 {
        while (try self.readByte()) |byte| {
            if (!std.ascii.isWhitespace(byte)) return byte;
        }
        return null;
    }

    fn readByte(self: *ProgressiveQueryStream) !?u8 {
        const reader = self.reader orelse return error.ProgressiveQueryClosed;
        var byte: [1]u8 = undefined;
        const count = reader.readSliceShort(&byte) catch |err| return err;
        if (count == 0) return null;
        return byte[0];
    }

    fn claim(self: *ProgressiveQueryStream, consumer: Consumer) !void {
        if (self.consumer == .none) {
            self.consumer = consumer;
            return;
        }
        if (self.consumer != consumer) return error.ProgressiveIteratorInUse;
    }

    fn checkInterruption(self: *ProgressiveQueryStream) !void {
        if (self.options.cancellation) |token| {
            if (token.isCancelled()) {
                self.closeOperation(.cancel);
                return error.OperationCancelled;
            }
        }
        if (self.deadline_ns) |deadline| {
            if (monotonicNs() >= deadline) {
                self.closeOperation(.abort);
                return error.OperationTimedOut;
            }
        }
    }

    fn applyFrameCorrelation(
        self: *ProgressiveQueryStream,
        frame: *ProgressiveFrame,
    ) !void {
        const operation = self.operation orelse return error.ProgressiveQueryClosed;
        const response_request_id = operation.getHeader("x-ms-client-request-id");
        const response_activity_id = operation.getHeader("x-ms-activity-id");
        const failure = switch (frame.payload) {
            .data_table, .table_fragment => |*batch| if (batch.failure) |*value| value else null,
            .table_completion => |*completion| if (completion.failure) |*value| value else null,
            .data_set_completion => |*completion| if (completion.failure) |*value| value else null,
            else => null,
        };
        if (failure) |value|
            try kusto_common.errors.applyCorrelation(
                value,
                response_request_id,
                response_activity_id,
                self.original_request_id,
            );
    }

    fn closeOperation(self: *ProgressiveQueryStream, action: enum { abort, cancel }) void {
        const operation = self.operation orelse return;
        switch (action) {
            .abort => operation.abort(),
            .cancel => operation.cancel(),
        }
        operation.deinit();
        self.operation = null;
        self.reader = null;
        if (self.array_state != .complete)
            self.array_state = .closed;
    }
};

/// Pull wrapper for full owned progressive frames.
pub const ProgressiveFrameIterator = struct {
    stream: *ProgressiveQueryStream,

    pub fn next(self: *ProgressiveFrameIterator) !?ProgressiveFrame {
        return self.stream.next();
    }
};

/// Pull wrapper that returns only table-shaped frames. The caller owns each
/// returned frame and must deinitialize it.
pub const ProgressiveTableIterator = struct {
    stream: *ProgressiveQueryStream,

    pub fn next(self: *ProgressiveTableIterator) !?ProgressiveFrame {
        while (try self.stream.nextInternal()) |frame| {
            switch (frame.payload) {
                .data_table,
                .table_header,
                .table_fragment,
                .table_progress,
                .table_completion,
                .data_set_completion,
                => return frame,
                else => {
                    var discarded = frame;
                    discarded.deinit(self.stream.allocator);
                },
            }
        }
        return null;
    }
};

/// A borrowed row-level event. A batch with `replace` and a null row resets
/// the table before subsequent append rows. Completion events keep partial
/// failures and cancellation visible to row consumers.
pub const ProgressiveRowEvent = union(enum) {
    batch: struct {
        action: ProgressiveTableAction,
        table_id: i64,
        row: ?*const result.KustoResultRow,
        failure: ?*const kusto_common.KustoError = null,
    },
    table_completion: *const result.ProgressiveTableCompletion,
    data_set_completion: *const result.ProgressiveDataSetCompletion,
};

/// Pulls row events while retaining no more than one table batch. Call
/// `deinit` to release a current batch before destroying its source stream.
pub const ProgressiveRowIterator = struct {
    stream: *ProgressiveQueryStream,
    current: ?ProgressiveFrame = null,
    row_index: usize = 0,
    marker_pending: bool = false,
    failure_pending: bool = false,
    completion_delivered: bool = false,

    pub fn deinit(self: *ProgressiveRowIterator) void {
        if (self.current) |*frame| frame.deinit(self.stream.allocator);
        self.current = null;
    }

    pub fn next(self: *ProgressiveRowIterator) !?ProgressiveRowEvent {
        while (true) {
            if (self.current) |*frame| {
                switch (frame.payload) {
                    .data_table, .table_fragment => |*batch| {
                        const id = batch.table.id orelse return error.MalformedKustoResponse;
                        if (self.marker_pending) {
                            self.marker_pending = false;
                            const failure = if (self.failure_pending and batch.failure != null)
                                &batch.failure.?
                            else
                                null;
                            self.failure_pending = false;
                            return .{ .batch = .{
                                .action = batch.action,
                                .table_id = id,
                                .row = null,
                                .failure = failure,
                            } };
                        }
                        if (self.row_index < batch.table.rows.len) {
                            defer self.row_index += 1;
                            const failure = if (self.failure_pending and batch.failure != null)
                                &batch.failure.?
                            else
                                null;
                            self.failure_pending = false;
                            return .{ .batch = .{
                                .action = .append,
                                .table_id = id,
                                .row = &batch.table.rows[self.row_index],
                                .failure = failure,
                            } };
                        }
                        frame.deinit(self.stream.allocator);
                        self.current = null;
                        continue;
                    },
                    .table_completion => |*completion| {
                        if (!self.completion_delivered) {
                            self.completion_delivered = true;
                            return .{ .table_completion = completion };
                        }
                        frame.deinit(self.stream.allocator);
                        self.current = null;
                        self.completion_delivered = false;
                        continue;
                    },
                    .data_set_completion => |*completion| {
                        if (!self.completion_delivered) {
                            self.completion_delivered = true;
                            return .{ .data_set_completion = completion };
                        }
                        frame.deinit(self.stream.allocator);
                        self.current = null;
                        self.completion_delivered = false;
                        continue;
                    },
                    else => unreachable,
                }
            }

            while (try self.stream.nextInternal()) |frame| {
                switch (frame.payload) {
                    .data_table, .table_fragment => |batch| {
                        const marker_pending = batch.action == .replace or
                            (batch.table.rows.len == 0 and batch.failure != null);
                        const discard_empty_append = batch.action == .append and
                            batch.table.rows.len == 0 and batch.failure == null;
                        if (discard_empty_append) {
                            var discarded = frame;
                            discarded.deinit(self.stream.allocator);
                            continue;
                        }
                        self.current = frame;
                        self.row_index = 0;
                        self.marker_pending = marker_pending;
                        self.failure_pending = batch.failure != null;
                        self.completion_delivered = false;
                        break;
                    },
                    .table_completion, .data_set_completion => {
                        self.current = frame;
                        self.completion_delivered = false;
                        break;
                    },
                    else => {
                        var discarded = frame;
                        discarded.deinit(self.stream.allocator);
                    },
                }
            } else return null;
        }
    }
};

fn monotonicNs() i128 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    return std.Io.Timestamp.now(threaded.io(), .awake).toNanoseconds();
}

fn deadlineFromNow(timeout_ms: ?u64) ?i128 {
    const timeout = timeout_ms orelse return null;
    return std.math.add(
        i128,
        monotonicNs(),
        @as(i128, timeout) * std.time.ns_per_ms,
    ) catch std.math.maxInt(i128);
}
