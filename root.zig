//! Azure SDK testing helpers for recording and playback.
//!
//! `PlaybackTransport` and `RecordingTransport` expose copyable Core 0.3
//! transport descriptors whose opaque contexts borrow the transport values.
//! The values and any wrapped backend contexts must outlive every descriptor
//! copy and open operation. Both transports are caller-serialized.
const std = @import("std");
const core = @import("azure_sdk_core");

pub const HeaderPair = struct {
    name: []const u8,
    value: []const u8,
};

/// A borrowed HTTP exchange used by playback.
///
/// Method, URL, and body are matched exactly, including whether a body is
/// present. Every request header listed here must occur with the same value;
/// additional live headers are allowed. Response headers retain wire order
/// and duplicate values.
pub const RecordedExchange = struct {
    request_method: core.http.Method,
    request_url: []const u8,
    request_headers: []const HeaderPair = &.{},
    request_body: ?[]const u8 = null,
    response_status: u16,
    response_body: []const u8,
    response_headers: []const HeaderPair = &.{},
};

/// An allocator-owned exchange captured by `RecordingTransport`.
pub const OwnedExchange = struct {
    request_method: core.http.Method,
    request_url: []u8,
    request_headers: []HeaderPair,
    request_body: ?[]u8,
    response_status: u16,
    response_body: []u8,
    response_headers: []HeaderPair,

    fn deinit(self: *OwnedExchange, allocator: std.mem.Allocator) void {
        allocator.free(self.request_url);
        deinitHeaderPairs(allocator, self.request_headers);
        if (self.request_body) |body| allocator.free(body);
        allocator.free(self.response_body);
        deinitHeaderPairs(allocator, self.response_headers);
        self.* = undefined;
    }
};

/// Construct the canonical Core runtime while selecting transport and crypto
/// independently. Both descriptors are copied and borrow their contexts.
pub fn initHttpRuntime(
    transport: core.http.HttpTransport,
    crypto_provider: core.crypto.CryptoProvider,
) core.http.HttpRuntime {
    return core.http.HttpRuntime.init(transport, crypto_provider);
}

/// Caller-serialized playback transport.
///
/// The returned descriptor borrows this value. Keep it alive until all
/// descriptor copies and open operations are deinitialized.
pub const PlaybackTransport = struct {
    recordings: []const RecordedExchange,
    index: usize = 0,
    allocator: std.mem.Allocator,
    open_count: usize = 0,
    finish_count: usize = 0,
    abort_count: usize = 0,
    cancel_count: usize = 0,
    deinit_count: usize = 0,

    const vtable: core.http.HttpTransport.VTable = .{
        .send = &sendImpl,
        .open = &openImpl,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        recordings: []const RecordedExchange,
    ) PlaybackTransport {
        return .{ .recordings = recordings, .allocator = allocator };
    }

    pub fn asTransport(self: *PlaybackTransport) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    fn next(self: *PlaybackTransport) !RecordedExchange {
        if (self.index >= self.recordings.len) return error.NoMoreRecordings;
        return self.recordings[self.index];
    }

    fn matchAndAdvance(
        self: *PlaybackTransport,
        request: *const core.http.Request,
        body: ?[]const u8,
    ) !RecordedExchange {
        const exchange = try self.next();
        try matchRequest(exchange, request, body);
        self.index += 1;
        return exchange;
    }

    fn sendImpl(
        context: *anyopaque,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *PlaybackTransport = @ptrCast(@alignCast(context));
        const exchange = try self.matchAndAdvance(request, request.body);
        return responseFromExchange(self.allocator, exchange);
    }

    fn openImpl(
        context: *anyopaque,
        request: *core.http.Request,
        options: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *PlaybackTransport = @ptrCast(@alignCast(context));
        if (options.body != null and request.body != null)
            return error.MultipleRequestBodies;
        try checkCancelled(options.cancellation);
        try validateRequestFraming(request, options);

        var captured: ?[]u8 = null;
        defer if (captured) |body| self.allocator.free(body);
        const body: ?[]const u8 = if (options.body) |streaming| blk: {
            captured = try readRequestBody(
                self.allocator,
                streaming,
                options.cancellation,
            );
            break :blk captured.?;
        } else request.body;

        const exchange = try self.matchAndAdvance(request, body);
        const operation = try PlaybackOperation.create(self, exchange);
        self.open_count += 1;
        return operation;
    }
};

const PlaybackOperation = struct {
    operation: core.http.HttpOperation,
    allocator: std.mem.Allocator,
    owner: *PlaybackTransport,
    response_body: []u8,
    reader_impl: std.Io.Reader,

    fn create(
        owner: *PlaybackTransport,
        exchange: RecordedExchange,
    ) !*core.http.HttpOperation {
        const self = try owner.allocator.create(PlaybackOperation);
        errdefer owner.allocator.destroy(self);
        const body = try owner.allocator.dupe(u8, exchange.response_body);
        errdefer owner.allocator.free(body);
        var header_set = try responseHeaderSet(
            owner.allocator,
            exchange.response_headers,
        );
        errdefer header_set.deinit(owner.allocator);

        self.* = .{
            .operation = undefined,
            .allocator = owner.allocator,
            .owner = owner,
            .response_body = body,
            .reader_impl = std.Io.Reader.fixed(body),
        };
        self.operation = .{
            .status_code = exchange.response_status,
            .headers = header_set.map,
            .response_headers = header_set.ordered,
            .body_reader = &self.reader_impl,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &cancelImpl,
            .deinitFn = &deinitImpl,
        };
        return &self.operation;
    }

    fn finishImpl(operation: *core.http.HttpOperation) !void {
        const self: *PlaybackOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        _ = try self.reader_impl.discardRemaining();
        self.owner.finish_count += 1;
    }

    fn abortImpl(operation: *core.http.HttpOperation) void {
        const self: *PlaybackOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.abort_count += 1;
    }

    fn cancelImpl(operation: *core.http.HttpOperation) void {
        const self: *PlaybackOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.cancel_count += 1;
    }

    fn deinitImpl(operation: *core.http.HttpOperation) void {
        const self: *PlaybackOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.owner.deinit_count += 1;
        deinitResponseStorage(
            self.allocator,
            &self.operation.headers,
            &self.operation.response_headers,
        );
        self.allocator.free(self.response_body);
        self.allocator.destroy(self);
    }
};

/// Caller-serialized recording transport wrapping a full Core descriptor.
///
/// The inner descriptor is copied by value. Its context, this recording
/// transport, and the recording allocator must outlive every open operation.
/// `deinit` does not deinitialize the borrowed inner transport.
pub const RecordingTransport = struct {
    inner: core.http.HttpTransport,
    exchanges: std.ArrayList(OwnedExchange) = .empty,
    allocator: std.mem.Allocator,

    const vtable: core.http.HttpTransport.VTable = .{
        .send = &sendImpl,
        .open = &openImpl,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        inner: core.http.HttpTransport,
    ) RecordingTransport {
        return .{ .inner = inner, .allocator = allocator };
    }

    pub fn asTransport(self: *RecordingTransport) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    pub fn deinit(self: *RecordingTransport) void {
        for (self.exchanges.items) |*exchange| {
            exchange.deinit(self.allocator);
        }
        self.exchanges.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn getExchanges(self: *const RecordingTransport) []const OwnedExchange {
        return self.exchanges.items;
    }

    /// Serialize recordings while redacting sensitive header values and
    /// sensitive URL query parameters.
    ///
    /// Recognized credential-bearing body fields cause
    /// `error.SensitiveBodyRequiresSanitization`; bodies are never silently
    /// emitted under a false sanitization guarantee.
    pub fn toJson(
        self: *const RecordingTransport,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        errdefer output.deinit();
        const writer = &output.writer;
        try writer.writeAll("[");
        for (self.exchanges.items, 0..) |exchange, index| {
            try ensureBodySafe(exchange.request_body);
            try ensureBodySafe(exchange.response_body);
            if (index != 0) try writer.writeAll(",");
            try writer.writeAll("\n  {\"request_method\":");
            try writeJsonString(writer, methodToString(exchange.request_method));
            try writer.writeAll(",\"request_url\":");
            try writeSanitizedUrl(writer, allocator, exchange.request_url);
            try writer.writeAll(",\"request_headers\":");
            try writeHeaders(writer, exchange.request_headers);
            try writer.writeAll(",\"request_body\":");
            try writeOptionalJsonString(writer, exchange.request_body);
            try writer.writeAll(",\"response_status\":");
            try writer.print("{d}", .{exchange.response_status});
            try writer.writeAll(",\"response_headers\":");
            try writeHeaders(writer, exchange.response_headers);
            try writer.writeAll(",\"response_body\":");
            try writeJsonString(writer, exchange.response_body);
            try writer.writeAll("}");
        }
        try writer.writeAll("\n]\n");
        return output.toOwnedSlice();
    }

    fn sendImpl(
        context: *anyopaque,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *RecordingTransport = @ptrCast(@alignCast(context));
        var response = try self.inner.vtable.send(self.inner.context, request);
        errdefer response.deinit();
        var exchange = try ownedExchangeFromResponse(
            self.allocator,
            request,
            request.body,
            &response,
            response.body,
        );
        errdefer exchange.deinit(self.allocator);
        try self.exchanges.append(self.allocator, exchange);
        return response;
    }

    fn openImpl(
        context: *anyopaque,
        request: *core.http.Request,
        options: core.http.OpenOptions,
    ) !*core.http.HttpOperation {
        const self: *RecordingTransport = @ptrCast(@alignCast(context));
        if (options.body != null and request.body != null)
            return error.MultipleRequestBodies;
        try checkCancelled(options.cancellation);

        var pending = try PendingRequest.init(
            self.allocator,
            request,
            request.body,
        );
        errdefer pending.deinit(self.allocator);

        const open_fn = self.inner.vtable.open orelse
            return error.WrappedTransportDoesNotSupportOpen;
        var inner_options = options;
        var request_capture: CapturingReader = undefined;
        var has_capture = false;
        if (options.body) |streaming| {
            request_capture.init(
                self.allocator,
                streaming.reader,
                null,
            );
            has_capture = true;
            inner_options.body.?.reader = &request_capture.interface;
        }
        defer if (has_capture) request_capture.deinit();

        const inner_operation = open_fn(
            self.inner.context,
            request,
            inner_options,
        ) catch |err| {
            if (has_capture) {
                if (request_capture.failure) |failure| return failure;
            }
            return err;
        };
        errdefer {
            inner_operation.abort();
            inner_operation.deinit();
        }

        if (has_capture) {
            pending.body = try request_capture.toOwnedSlice();
        }
        return RecordingOperation.create(
            self,
            inner_operation,
            pending,
            recordsRedirect(request, options, inner_operation),
        );
    }
};

const PendingRequest = struct {
    method: core.http.Method,
    url: []u8,
    headers: []HeaderPair,
    body: ?[]u8,

    fn init(
        allocator: std.mem.Allocator,
        request: *const core.http.Request,
        body: ?[]const u8,
    ) !PendingRequest {
        const url = try allocator.dupe(u8, request.url);
        errdefer allocator.free(url);
        const headers = try cloneRequestHeaders(allocator, &request.headers);
        errdefer deinitHeaderPairs(allocator, headers);
        const owned_body = if (body) |bytes|
            try allocator.dupe(u8, bytes)
        else
            null;
        return .{
            .method = request.method,
            .url = url,
            .headers = headers,
            .body = owned_body,
        };
    }

    fn deinit(self: *PendingRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        deinitHeaderPairs(allocator, self.headers);
        if (self.body) |body| allocator.free(body);
        self.* = undefined;
    }
};

const RecordingOperation = struct {
    operation: core.http.HttpOperation,
    allocator: std.mem.Allocator,
    owner: *RecordingTransport,
    inner: *core.http.HttpOperation,
    pending: ?PendingRequest,
    redirect_exchange: ?OwnedExchange,
    response_reader: CapturingReader,

    fn create(
        owner: *RecordingTransport,
        inner: *core.http.HttpOperation,
        pending_value: PendingRequest,
        record_redirect: bool,
    ) !*core.http.HttpOperation {
        const self = try owner.allocator.create(RecordingOperation);
        errdefer owner.allocator.destroy(self);
        var header_set = try cloneOperationHeaders(owner.allocator, inner);
        errdefer header_set.deinit(owner.allocator);
        const inner_reader = try inner.reader();
        var redirect_headers: ?[]HeaderPair = null;
        errdefer if (redirect_headers) |headers|
            deinitHeaderPairs(owner.allocator, headers);
        var redirect_body: ?[]u8 = null;
        errdefer if (redirect_body) |body| owner.allocator.free(body);
        if (record_redirect) {
            try owner.exchanges.ensureUnusedCapacity(owner.allocator, 1);
            redirect_headers = try cloneResponseHeaders(
                owner.allocator,
                &inner.headers,
                &inner.response_headers,
            );
            redirect_body = try owner.allocator.dupe(u8, "");
        }

        self.* = .{
            .operation = undefined,
            .allocator = owner.allocator,
            .owner = owner,
            .inner = inner,
            .pending = if (record_redirect) null else pending_value,
            .redirect_exchange = if (record_redirect) .{
                .request_method = pending_value.method,
                .request_url = pending_value.url,
                .request_headers = pending_value.headers,
                .request_body = pending_value.body,
                .response_status = inner.status_code,
                .response_body = redirect_body.?,
                .response_headers = redirect_headers.?,
            } else null,
            .response_reader = undefined,
        };
        self.response_reader.init(owner.allocator, inner_reader, inner);
        self.operation = .{
            .status_code = inner.status_code,
            .headers = header_set.map,
            .response_headers = header_set.ordered,
            .body_reader = &self.response_reader.interface,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &cancelImpl,
            .deinitFn = &deinitImpl,
            .bodyErrorFn = &bodyErrorImpl,
        };
        return &self.operation;
    }

    fn finishImpl(operation: *core.http.HttpOperation) !void {
        const self: *RecordingOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        _ = self.response_reader.interface.discardRemaining() catch |err| {
            if (self.response_reader.failure) |failure| return failure;
            if (self.inner.bodyError()) |failure| return failure;
            return err;
        };
        try self.inner.finish();
        if (self.response_reader.failure) |failure| return failure;

        const body = try self.response_reader.toOwnedSlice();
        const response_headers = cloneResponseHeaders(
            self.allocator,
            &self.operation.headers,
            &self.operation.response_headers,
        ) catch |err| {
            self.allocator.free(body);
            return err;
        };
        const pending = self.pending orelse {
            self.allocator.free(body);
            deinitHeaderPairs(self.allocator, response_headers);
            return error.RecordingAlreadyFinalized;
        };
        self.pending = null;
        var exchange = OwnedExchange{
            .request_method = pending.method,
            .request_url = pending.url,
            .request_headers = pending.headers,
            .request_body = pending.body,
            .response_status = self.operation.status_code,
            .response_body = body,
            .response_headers = response_headers,
        };
        self.owner.exchanges.append(self.allocator, exchange) catch |err| {
            exchange.deinit(self.allocator);
            return err;
        };
    }

    fn abortImpl(operation: *core.http.HttpOperation) void {
        const self: *RecordingOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.inner.abort();
        if (self.redirect_exchange) |exchange| {
            self.owner.exchanges.appendAssumeCapacity(exchange);
            self.redirect_exchange = null;
        }
    }

    fn cancelImpl(operation: *core.http.HttpOperation) void {
        const self: *RecordingOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.inner.cancel();
    }

    fn bodyErrorImpl(operation: *const core.http.HttpOperation) ?anyerror {
        const self: *const RecordingOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        if (self.response_reader.failure) |failure| return failure;
        return self.inner.bodyError();
    }

    fn deinitImpl(operation: *core.http.HttpOperation) void {
        const self: *RecordingOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        self.inner.deinit();
        if (self.pending) |*pending| pending.deinit(self.allocator);
        if (self.redirect_exchange) |*exchange| {
            exchange.deinit(self.allocator);
        }
        self.response_reader.deinit();
        deinitResponseStorage(
            self.allocator,
            &self.operation.headers,
            &self.operation.response_headers,
        );
        self.allocator.destroy(self);
    }
};

fn recordsRedirect(
    request: *const core.http.Request,
    options: core.http.OpenOptions,
    operation: *const core.http.HttpOperation,
) bool {
    if (request.redirect_policy == .not_allowed or
        operation.getHeader("Location") == null)
    {
        return false;
    }
    return switch (operation.status_code) {
        301, 302 => request.method == .POST or options.isReplayable(),
        303 => true,
        307, 308 => options.isReplayable(),
        else => false,
    };
}

const CapturingReader = struct {
    interface: std.Io.Reader,
    source: *std.Io.Reader,
    captured: std.Io.Writer.Allocating,
    source_operation: ?*core.http.HttpOperation,
    failure: ?anyerror = null,
    reader_buffer: [64]u8 = undefined,
    scratch: [4096]u8 = undefined,

    fn init(
        self: *CapturingReader,
        allocator: std.mem.Allocator,
        source: *std.Io.Reader,
        source_operation: ?*core.http.HttpOperation,
    ) void {
        self.* = .{
            .interface = undefined,
            .source = source,
            .captured = .init(allocator),
            .source_operation = source_operation,
        };
        self.interface = .{
            .vtable = &.{ .stream = &stream },
            .buffer = &self.reader_buffer,
            .seek = 0,
            .end = 0,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *CapturingReader =
            @alignCast(@fieldParentPtr("interface", interface));
        const length = limit.minInt(self.scratch.len);
        if (length == 0) return 0;
        const count = self.source.readSliceShort(self.scratch[0..length]) catch |err| {
            self.failure = if (self.source_operation) |operation|
                operation.bodyError() orelse err
            else
                err;
            return error.ReadFailed;
        };
        if (count == 0) return error.EndOfStream;
        self.captured.writer.writeAll(self.scratch[0..count]) catch {
            self.failure = error.OutOfMemory;
            return error.ReadFailed;
        };
        try writer.writeAll(self.scratch[0..count]);
        return count;
    }

    fn toOwnedSlice(self: *CapturingReader) ![]u8 {
        const result = try self.captured.toOwnedSlice();
        self.captured = .init(self.captured.allocator);
        return result;
    }

    fn deinit(self: *CapturingReader) void {
        self.captured.deinit();
    }
};

const ResponseHeaderSet = struct {
    map: std.StringHashMap([]const u8),
    ordered: core.http.ResponseHeaders,

    fn deinit(self: *ResponseHeaderSet, allocator: std.mem.Allocator) void {
        deinitOwnedHeaderMap(allocator, &self.map);
        self.ordered.deinit();
    }
};

fn responseFromExchange(
    allocator: std.mem.Allocator,
    exchange: RecordedExchange,
) !core.http.Response {
    const body = try allocator.dupe(u8, exchange.response_body);
    errdefer allocator.free(body);
    var header_set = try responseHeaderSet(allocator, exchange.response_headers);
    errdefer header_set.deinit(allocator);
    return .{
        .status_code = exchange.response_status,
        .headers = header_set.map,
        .body = body,
        .allocator = allocator,
        .response_headers = header_set.ordered,
    };
}

fn responseHeaderSet(
    allocator: std.mem.Allocator,
    headers: []const HeaderPair,
) !ResponseHeaderSet {
    var result = ResponseHeaderSet{
        .map = std.StringHashMap([]const u8).init(allocator),
        .ordered = core.http.ResponseHeaders.init(allocator),
    };
    errdefer result.deinit(allocator);
    for (headers) |header| {
        try result.ordered.append(header.name, header.value);
        try putOwnedHeader(allocator, &result.map, header.name, header.value);
    }
    return result;
}

fn cloneOperationHeaders(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
) !ResponseHeaderSet {
    const pairs = try cloneResponseHeaders(
        allocator,
        &operation.headers,
        &operation.response_headers,
    );
    defer deinitHeaderPairs(allocator, pairs);
    return responseHeaderSet(allocator, pairs);
}

fn cloneResponseHeaders(
    allocator: std.mem.Allocator,
    map: *const std.StringHashMap([]const u8),
    ordered: *const core.http.ResponseHeaders,
) ![]HeaderPair {
    if (ordered.entries.items.len != 0) {
        const result = try allocator.alloc(HeaderPair, ordered.entries.items.len);
        var initialized: usize = 0;
        errdefer {
            for (result[0..initialized]) |header| {
                allocator.free(header.name);
                allocator.free(header.value);
            }
            allocator.free(result);
        }
        for (ordered.entries.items, result) |header, *pair| {
            pair.* = .{
                .name = try allocator.dupe(u8, header.name),
                .value = undefined,
            };
            errdefer allocator.free(pair.name);
            pair.value = try allocator.dupe(u8, header.value);
            initialized += 1;
        }
        return result;
    }

    const result = try allocator.alloc(HeaderPair, map.count());
    var initialized: usize = 0;
    errdefer {
        for (result[0..initialized]) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        allocator.free(result);
    }
    var iterator = map.iterator();
    while (iterator.next()) |entry| {
        result[initialized] = .{
            .name = try allocator.dupe(u8, entry.key_ptr.*),
            .value = undefined,
        };
        errdefer allocator.free(result[initialized].name);
        result[initialized].value = try allocator.dupe(u8, entry.value_ptr.*);
        initialized += 1;
    }
    return result;
}

fn ownedExchangeFromResponse(
    allocator: std.mem.Allocator,
    request: *const core.http.Request,
    request_body: ?[]const u8,
    response: *const core.http.Response,
    response_body: []const u8,
) !OwnedExchange {
    var pending = try PendingRequest.init(allocator, request, request_body);
    errdefer pending.deinit(allocator);
    const body = try allocator.dupe(u8, response_body);
    errdefer allocator.free(body);
    const headers = try cloneResponseHeaders(
        allocator,
        &response.headers,
        &response.response_headers,
    );
    return .{
        .request_method = pending.method,
        .request_url = pending.url,
        .request_headers = pending.headers,
        .request_body = pending.body,
        .response_status = response.status_code,
        .response_body = body,
        .response_headers = headers,
    };
}

fn matchRequest(
    exchange: RecordedExchange,
    request: *const core.http.Request,
    body: ?[]const u8,
) !void {
    if (exchange.request_method != request.method) return error.MethodMismatch;
    if (!std.mem.eql(u8, exchange.request_url, request.url))
        return error.UrlMismatch;
    if ((exchange.request_body == null) != (body == null))
        return error.BodyMismatch;
    if (exchange.request_body) |expected| {
        if (!std.mem.eql(u8, expected, body.?)) return error.BodyMismatch;
    }
    for (exchange.request_headers) |expected| {
        const actual = getHeader(&request.headers, expected.name) orelse
            return error.HeaderMismatch;
        if (!std.mem.eql(u8, expected.value, actual))
            return error.HeaderMismatch;
    }
}

fn validateRequestFraming(
    request: *const core.http.Request,
    options: core.http.OpenOptions,
) !void {
    const content_length = getHeader(&request.headers, "Content-Length");
    const transfer_encoding = getHeader(&request.headers, "Transfer-Encoding");
    const framing: union(enum) {
        none,
        content_length: u64,
        chunked,
    } = if (options.body) |body|
        if (body.content_length) |length|
            .{ .content_length = length }
        else
            .chunked
    else if (request.body) |body|
        .{ .content_length = body.len }
    else if (request.method.toStd().requestHasBody())
        .{ .content_length = 0 }
    else
        .none;

    switch (framing) {
        .content_length => |length| {
            if (transfer_encoding != null) return error.ConflictingRequestFraming;
            if (content_length) |value| {
                const parsed = std.fmt.parseInt(u64, std.mem.trim(u8, value, " \t"), 10) catch
                    return error.ConflictingRequestFraming;
                if (parsed != length) return error.ConflictingRequestFraming;
            }
        },
        .chunked => {
            if (content_length != null) return error.ConflictingRequestFraming;
            if (transfer_encoding) |value| {
                if (!std.ascii.eqlIgnoreCase(
                    std.mem.trim(u8, value, " \t"),
                    "chunked",
                )) return error.ConflictingRequestFraming;
            }
        },
        .none => if (content_length != null or transfer_encoding != null)
            return error.ConflictingRequestFraming,
    }
}

fn readRequestBody(
    allocator: std.mem.Allocator,
    body: core.http.StreamingRequestBody,
    cancellation: ?*const core.http.CancellationToken,
) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    var buffer: [4096]u8 = undefined;
    if (body.content_length) |length| {
        var remaining = length;
        while (remaining != 0) {
            try checkCancelled(cancellation);
            const read_length: usize = @intCast(@min(remaining, buffer.len));
            const count = try body.reader.readSliceShort(buffer[0..read_length]);
            try checkCancelled(cancellation);
            if (count == 0) return error.RequestBodyTooShort;
            try output.writer.writeAll(buffer[0..count]);
            remaining -= count;
        }
        var extra: [1]u8 = undefined;
        if (try body.reader.readSliceShort(&extra) != 0)
            return error.RequestBodyTooLong;
    } else {
        while (true) {
            try checkCancelled(cancellation);
            const count = try body.reader.readSliceShort(&buffer);
            try checkCancelled(cancellation);
            if (count == 0) break;
            try output.writer.writeAll(buffer[0..count]);
        }
    }
    return output.toOwnedSlice();
}

fn checkCancelled(token: ?*const core.http.CancellationToken) !void {
    if (token) |value| {
        if (value.isCancelled()) return error.OperationCancelled;
    }
}

fn cloneRequestHeaders(
    allocator: std.mem.Allocator,
    headers: *const std.StringHashMap([]const u8),
) ![]HeaderPair {
    const result = try allocator.alloc(HeaderPair, headers.count());
    var initialized: usize = 0;
    errdefer {
        for (result[0..initialized]) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        allocator.free(result);
    }
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        result[initialized] = .{
            .name = try allocator.dupe(u8, entry.key_ptr.*),
            .value = undefined,
        };
        errdefer allocator.free(result[initialized].name);
        result[initialized].value = try allocator.dupe(u8, entry.value_ptr.*);
        initialized += 1;
    }
    return result;
}

fn deinitHeaderPairs(
    allocator: std.mem.Allocator,
    headers: []const HeaderPair,
) void {
    for (headers) |header| {
        allocator.free(header.name);
        allocator.free(header.value);
    }
    allocator.free(headers);
}

fn getHeader(
    headers: *const std.StringHashMap([]const u8),
    name: []const u8,
) ?[]const u8 {
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, name))
            return entry.value_ptr.*;
    }
    return null;
}

fn putOwnedHeader(
    allocator: std.mem.Allocator,
    headers: *std.StringHashMap([]const u8),
    name: []const u8,
    value: []const u8,
) !void {
    const owned_value = try allocator.dupe(u8, value);
    errdefer allocator.free(owned_value);
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, name)) {
            allocator.free(entry.value_ptr.*);
            entry.value_ptr.* = owned_value;
            return;
        }
    }
    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    try headers.put(owned_name, owned_value);
}

fn deinitOwnedHeaderMap(
    allocator: std.mem.Allocator,
    headers: *std.StringHashMap([]const u8),
) void {
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    headers.deinit();
}

fn deinitResponseStorage(
    allocator: std.mem.Allocator,
    headers: *std.StringHashMap([]const u8),
    ordered: *core.http.ResponseHeaders,
) void {
    ordered.deinit();
    deinitOwnedHeaderMap(allocator, headers);
}

const sensitive_headers = [_][]const u8{
    "authorization",
    "proxy-authorization",
    "cookie",
    "set-cookie",
    "x-ms-client-secret",
    "ocp-apim-subscription-key",
    "api-key",
};

const sensitive_body_fields = [_][]const u8{
    "access_token",
    "accesstoken",
    "refresh_token",
    "refreshtoken",
    "client_secret",
    "clientsecret",
    "client_assertion",
    "clientassertion",
    "password",
    "shared_access_signature",
    "sharedaccesssignature",
};

const sensitive_query_fields = [_][]const u8{
    "sig",
    "signature",
    "token",
    "access_token",
    "key",
    "secret",
    "code",
};

pub fn isSensitiveHeader(name: []const u8) bool {
    for (sensitive_headers) |sensitive| {
        if (std.ascii.eqlIgnoreCase(name, sensitive)) return true;
    }
    return false;
}

fn ensureBodySafe(body: ?[]const u8) !void {
    const bytes = body orelse return;
    for (sensitive_body_fields) |field| {
        if (containsIgnoreCase(bytes, field))
            return error.SensitiveBodyRequiresSanitization;
    }
}

fn writeHeaders(
    writer: *std.Io.Writer,
    headers: []const HeaderPair,
) !void {
    try writer.writeByte('[');
    for (headers, 0..) |header, index| {
        if (index != 0) try writer.writeByte(',');
        try writer.writeAll("{\"name\":");
        try writeJsonString(writer, header.name);
        try writer.writeAll(",\"value\":");
        try writeJsonString(
            writer,
            if (isSensitiveHeader(header.name)) "REDACTED" else header.value,
        );
        try writer.writeByte('}');
    }
    try writer.writeByte(']');
}

fn writeSanitizedUrl(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    url: []const u8,
) !void {
    const scheme = std.mem.indexOf(u8, url, "://");
    if (scheme) |index| {
        const authority_start = index + 3;
        const authority_end = std.mem.indexOfScalarPos(
            u8,
            url,
            authority_start,
            '/',
        ) orelse std.mem.indexOfScalarPos(
            u8,
            url,
            authority_start,
            '?',
        ) orelse url.len;
        if (std.mem.indexOfScalar(
            u8,
            url[authority_start..authority_end],
            '@',
        ) != null) return error.SensitiveUrlRequiresSanitization;
    }

    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    const question = std.mem.indexOfScalar(u8, url, '?') orelse {
        return writeJsonString(writer, url);
    };
    try output.writer.writeAll(url[0 .. question + 1]);
    const fragment = std.mem.indexOfScalarPos(u8, url, question + 1, '#') orelse
        url.len;
    var first = true;
    var iterator = std.mem.splitScalar(u8, url[question + 1 .. fragment], '&');
    while (iterator.next()) |parameter| {
        if (!first) try output.writer.writeByte('&');
        first = false;
        const equals = std.mem.indexOfScalar(u8, parameter, '=') orelse {
            try output.writer.writeAll(parameter);
            continue;
        };
        const name = parameter[0..equals];
        try output.writer.writeAll(name);
        try output.writer.writeByte('=');
        try output.writer.writeAll(
            if (isSensitiveQueryField(name))
                "REDACTED"
            else
                parameter[equals + 1 ..],
        );
    }
    try output.writer.writeAll(url[fragment..]);
    try writeJsonString(writer, output.writer.buffered());
}

fn isSensitiveQueryField(name: []const u8) bool {
    for (sensitive_query_fields) |sensitive| {
        if (std.ascii.eqlIgnoreCase(name, sensitive)) return true;
    }
    return false;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (std.ascii.eqlIgnoreCase(
            haystack[index .. index + needle.len],
            needle,
        )) return true;
    }
    return false;
}

fn methodToString(method: core.http.Method) []const u8 {
    return switch (method) {
        .GET => "GET",
        .POST => "POST",
        .PUT => "PUT",
        .DELETE => "DELETE",
        .PATCH => "PATCH",
        .HEAD => "HEAD",
        .OPTIONS => "OPTIONS",
    };
}

fn writeOptionalJsonString(
    writer: *std.Io.Writer,
    value: ?[]const u8,
) !void {
    if (value) |bytes| {
        try writeJsonString(writer, bytes);
    } else {
        try writer.writeAll("null");
    }
}

fn writeJsonString(writer: *std.Io.Writer, value: []const u8) !void {
    try writer.writeByte('"');
    for (value) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => if (byte < 0x20) {
                const hex = "0123456789abcdef";
                try writer.writeAll("\\u00");
                try writer.writeByte(hex[byte >> 4]);
                try writer.writeByte(hex[byte & 0x0f]);
            } else {
                try writer.writeByte(byte);
            },
        }
    }
    try writer.writeByte('"');
}

pub fn expectSuccess(response: core.http.Response) !void {
    if (!response.isSuccess()) return error.UnexpectedStatus;
}

pub fn expectStatus(response: core.http.Response, expected: u16) !void {
    try std.testing.expectEqual(expected, response.status_code);
}

test "playback validates request and preserves duplicate response headers" {
    const recordings = [_]RecordedExchange{.{
        .request_method = .POST,
        .request_url = "https://example.com/items",
        .request_headers = &.{.{ .name = "Content-Type", .value = "application/json" }},
        .request_body = "{}",
        .response_status = 201,
        .response_body = "created",
        .response_headers = &.{
            .{ .name = "X-Value", .value = "first" },
            .{ .name = "x-value", .value = "second" },
        },
    }};
    var playback = PlaybackTransport.init(std.testing.allocator, &recordings);
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/items",
    );
    defer request.deinit();
    request.body = "{}";
    try request.setHeader("Content-Type", "application/json");
    try request.setHeader("User-Agent", "volatile");

    var response = try playback.asTransport().send(&request);
    defer response.deinit();
    const values = try response.getHeaderValues(std.testing.allocator, "X-VALUE");
    defer std.testing.allocator.free(values);
    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expectEqualStrings("first", values[0]);
    try std.testing.expectEqualStrings("second", values[1]);
}

test "playback supports streaming upload and response lifecycle" {
    const recordings = [_]RecordedExchange{.{
        .request_method = .PUT,
        .request_url = "https://example.com/stream",
        .request_body = "streaming",
        .response_status = 200,
        .response_body = "response",
    }};
    var playback = PlaybackTransport.init(std.testing.allocator, &recordings);
    var request = core.http.Request.init(
        std.testing.allocator,
        .PUT,
        "https://example.com/stream",
    );
    defer request.deinit();
    var source = std.Io.Reader.fixed("streaming");
    var operation = try playback.asTransport().open(&request, .{
        .body = core.http.StreamingRequestBody.knownLength(&source, 9),
    });
    const response = try (try operation.reader()).allocRemaining(
        std.testing.allocator,
        .unlimited,
    );
    defer std.testing.allocator.free(response);
    try std.testing.expectEqualStrings("response", response);
    try operation.finish();
    operation.deinit();
    try std.testing.expectEqual(@as(usize, 1), playback.finish_count);
    try std.testing.expectEqual(@as(usize, 1), playback.deinit_count);
}

test "playback preserves abort and cancellation semantics" {
    const recordings = [_]RecordedExchange{
        .{
            .request_method = .GET,
            .request_url = "https://example.com/abort",
            .response_status = 200,
            .response_body = "abort",
        },
        .{
            .request_method = .GET,
            .request_url = "https://example.com/cancel",
            .response_status = 200,
            .response_body = "cancel",
        },
    };
    var playback = PlaybackTransport.init(std.testing.allocator, &recordings);
    var abort_request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/abort",
    );
    defer abort_request.deinit();
    var aborted = try playback.asTransport().open(&abort_request, .{});
    aborted.abort();
    aborted.deinit();

    var cancel_request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/cancel",
    );
    defer cancel_request.deinit();
    var cancelled = try playback.asTransport().open(&cancel_request, .{});
    cancelled.cancel();
    cancelled.deinit();
    try std.testing.expectEqual(@as(usize, 1), playback.abort_count);
    try std.testing.expectEqual(@as(usize, 1), playback.cancel_count);
    try std.testing.expectEqual(@as(usize, 2), playback.deinit_count);
}

test "playback follows redirects and cleans intermediate operations" {
    const recordings = [_]RecordedExchange{
        .{
            .request_method = .GET,
            .request_url = "https://example.com/start",
            .response_status = 302,
            .response_body = "",
            .response_headers = &.{
                .{ .name = "Location", .value = "/final" },
            },
        },
        .{
            .request_method = .GET,
            .request_url = "https://example.com/final",
            .response_status = 200,
            .response_body = "done",
        },
    };
    var playback = PlaybackTransport.init(std.testing.allocator, &recordings);
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/start",
    );
    defer request.deinit();
    var operation = try playback.asTransport().open(&request, .{});
    const body = try (try operation.reader()).allocRemaining(
        std.testing.allocator,
        .unlimited,
    );
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("done", body);
    try operation.finish();
    operation.deinit();
    try std.testing.expectEqual(@as(usize, 2), playback.index);
    try std.testing.expectEqual(@as(usize, 1), playback.abort_count);
    try std.testing.expectEqual(@as(usize, 1), playback.finish_count);
    try std.testing.expectEqual(@as(usize, 2), playback.deinit_count);
}

test "playback cancellation does not consume a recording" {
    const recordings = [_]RecordedExchange{.{
        .request_method = .POST,
        .request_url = "https://example.com/cancel",
        .request_body = "part",
        .response_status = 200,
        .response_body = "",
    }};
    var playback = PlaybackTransport.init(std.testing.allocator, &recordings);
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/cancel",
    );
    defer request.deinit();
    var token = core.http.CancellationToken{};
    const CancellingReader = struct {
        interface: std.Io.Reader,
        token: *core.http.CancellationToken,
        emitted: bool = false,

        fn init(value: *@This(), cancellation: *core.http.CancellationToken) void {
            value.* = .{
                .interface = .{
                    .vtable = &.{ .stream = &stream },
                    .buffer = &.{},
                    .seek = 0,
                    .end = 0,
                },
                .token = cancellation,
            };
        }

        fn stream(
            interface: *std.Io.Reader,
            writer: *std.Io.Writer,
            limit: std.Io.Limit,
        ) std.Io.Reader.StreamError!usize {
            const self: *@This() =
                @alignCast(@fieldParentPtr("interface", interface));
            if (self.emitted) return error.EndOfStream;
            const bytes = limit.sliceConst("part");
            try writer.writeAll(bytes);
            self.emitted = true;
            self.token.cancel();
            return bytes.len;
        }
    };
    var source: CancellingReader = undefined;
    source.init(&token);
    try std.testing.expectError(
        error.OperationCancelled,
        playback.asTransport().open(&request, .{
            .body = core.http.StreamingRequestBody.chunked(&source.interface),
            .cancellation = &token,
        }),
    );
    try std.testing.expectEqual(@as(usize, 0), playback.index);
}

test "playback detects URL body and header mismatches without advancing" {
    const recordings = [_]RecordedExchange{.{
        .request_method = .POST,
        .request_url = "https://example.com/expected",
        .request_headers = &.{.{ .name = "X-Expected", .value = "yes" }},
        .request_body = "expected",
        .response_status = 200,
        .response_body = "",
    }};
    var playback = PlaybackTransport.init(std.testing.allocator, &recordings);
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/wrong",
    );
    defer request.deinit();
    request.body = "expected";
    try std.testing.expectError(
        error.UrlMismatch,
        playback.asTransport().send(&request),
    );
    request.url = "https://example.com/expected";
    request.body = "wrong";
    try std.testing.expectError(
        error.BodyMismatch,
        playback.asTransport().send(&request),
    );
    request.body = "expected";
    try std.testing.expectError(
        error.HeaderMismatch,
        playback.asTransport().send(&request),
    );
    try std.testing.expectEqual(@as(usize, 0), playback.index);
}

test "recording wraps streaming operations and copies descriptor by value" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        202,
        "stream-response",
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "X-Duplicate", .value = "first" },
        .{ .name = "x-duplicate", .value = "second" },
    };
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    const copied = recorder.asTransport();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/record",
    );
    defer request.deinit();
    var source = std.Io.Reader.fixed("stream-request");
    var operation = try copied.open(&request, .{
        .body = core.http.StreamingRequestBody.chunked(&source),
    });
    var first: [6]u8 = undefined;
    try (try operation.reader()).readSliceAll(&first);
    try operation.finish();
    operation.deinit();

    const exchanges = recorder.getExchanges();
    try std.testing.expectEqual(@as(usize, 1), exchanges.len);
    try std.testing.expectEqualStrings("stream-request", exchanges[0].request_body.?);
    try std.testing.expectEqualStrings("stream-response", exchanges[0].response_body);
    try std.testing.expectEqual(@as(usize, 2), exchanges[0].response_headers.len);
    try std.testing.expectEqual(@as(usize, 1), mock.stream_finish_count);
    try std.testing.expectEqual(@as(usize, 1), mock.stream_deinit_count);
}

test "recording forwards abort and cancel without recording partial responses" {
    var mock = core.http.MockTransport.init(std.testing.allocator, 200, "body");
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();

    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/abort",
    );
    defer request.deinit();
    var aborted = try recorder.asTransport().open(&request, .{});
    aborted.abort();
    aborted.deinit();
    var cancelled = try recorder.asTransport().open(&request, .{});
    cancelled.cancel();
    cancelled.deinit();
    try std.testing.expectEqual(@as(usize, 0), recorder.getExchanges().len);
    try std.testing.expectEqual(@as(usize, 1), mock.stream_abort_count);
    try std.testing.expectEqual(@as(usize, 1), mock.stream_cancel_count);
    try std.testing.expectEqual(@as(usize, 2), mock.stream_deinit_count);
}

test "recording and playback preserve streaming redirect sequences" {
    var sequence = core.http.SequenceMockTransport.init(
        std.testing.allocator,
        &.{
            .{
                .status = 302,
                .body = "ignored",
                .headers = &.{.{ .name = "Location", .value = "/final" }},
            },
            .{ .status = 200, .body = "done" },
        },
    );
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        sequence.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/start",
    );
    defer request.deinit();
    var operation = try recorder.asTransport().open(&request, .{});
    try operation.finish();
    operation.deinit();
    try std.testing.expectEqual(@as(usize, 2), recorder.getExchanges().len);

    const owned = recorder.getExchanges();
    var recordings: [2]RecordedExchange = undefined;
    for (owned, &recordings) |exchange, *recording| {
        recording.* = .{
            .request_method = exchange.request_method,
            .request_url = exchange.request_url,
            .request_headers = exchange.request_headers,
            .request_body = exchange.request_body,
            .response_status = exchange.response_status,
            .response_body = exchange.response_body,
            .response_headers = exchange.response_headers,
        };
    }
    var playback = PlaybackTransport.init(std.testing.allocator, &recordings);
    var replay_request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/start",
    );
    defer replay_request.deinit();
    var replay = try playback.asTransport().open(&replay_request, .{});
    const body = try (try replay.reader()).allocRemaining(
        std.testing.allocator,
        .unlimited,
    );
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("done", body);
    try replay.finish();
    replay.deinit();
}

test "recording JSON redacts headers and URL query credentials" {
    var mock = core.http.MockTransport.init(std.testing.allocator, 200, "ok");
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/items?sig=secret&version=1",
    );
    defer request.deinit();
    try request.setHeader("Authorization", "Bearer secret");
    var response = try recorder.asTransport().send(&request);
    response.deinit();

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "REDACTED") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Bearer secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "sig=secret") == null);
}

test "recording JSON refuses recognized credential bodies" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "{\"access_token\":\"secret\"}",
    );
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/token",
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    try std.testing.expectError(
        error.SensitiveBodyRequiresSanitization,
        recorder.toJson(std.testing.allocator),
    );
}

fn playbackAllocationFixture(allocator: std.mem.Allocator) !void {
    const recordings = [_]RecordedExchange{.{
        .request_method = .GET,
        .request_url = "https://example.com",
        .response_status = 200,
        .response_body = "response",
        .response_headers = &.{.{ .name = "X-Test", .value = "value" }},
    }};
    var playback = PlaybackTransport.init(allocator, &recordings);
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com",
    );
    defer request.deinit();
    var operation = try playback.asTransport().open(&request, .{});
    defer operation.deinit();
    try operation.finish();
}

fn recordingAllocationFixture(allocator: std.mem.Allocator) !void {
    var mock = core.http.MockTransport.init(allocator, 200, "response");
    defer mock.deinit();
    var recorder = RecordingTransport.init(allocator, mock.asTransport());
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com",
    );
    defer request.deinit();
    var source = std.Io.Reader.fixed("request");
    var operation = try recorder.asTransport().open(&request, .{
        .body = core.http.StreamingRequestBody.chunked(&source),
    });
    defer operation.deinit();
    try operation.finish();
}

fn recordingRedirectAllocationFixture(allocator: std.mem.Allocator) !void {
    var sequence = core.http.SequenceMockTransport.init(
        allocator,
        &.{
            .{
                .status = 302,
                .body = "ignored",
                .headers = &.{.{ .name = "Location", .value = "/final" }},
            },
            .{ .status = 200, .body = "done" },
        },
    );
    var recorder = RecordingTransport.init(allocator, sequence.asTransport());
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/start",
    );
    defer request.deinit();
    var operation = try recorder.asTransport().open(&request, .{});
    defer operation.deinit();
    try operation.finish();
}

test "transport allocation failures clean up" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        playbackAllocationFixture,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        recordingAllocationFixture,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        recordingRedirectAllocationFixture,
        .{},
    );
}

test "initHttpRuntime preserves selected transport and crypto provider" {
    var playback = PlaybackTransport.init(std.testing.allocator, &.{});
    const Spy = struct {
        fn random(_: *anyopaque, out: []u8) !void {
            @memset(out, 0x5a);
        }
        fn md5(_: *anyopaque, _: []const u8, out: *core.crypto.Md5Digest) !void {
            @memset(out, 0x5a);
        }
        fn sha256(
            _: *anyopaque,
            _: []const u8,
            out: *core.crypto.Sha256Digest,
        ) !void {
            @memset(out, 0x5a);
        }
        fn hmac(
            _: *anyopaque,
            _: []const u8,
            _: []const u8,
            out: *core.crypto.HmacSha256Digest,
        ) !void {
            @memset(out, 0x5a);
        }
        fn sha256Init(
            _: *anyopaque,
            _: std.mem.Allocator,
        ) !core.crypto.Sha256Operation {
            return error.Unused;
        }
        const vtable: core.crypto.CryptoProvider.VTable = .{
            .random_bytes = &random,
            .md5 = &md5,
            .sha256 = &sha256,
            .hmac_sha256 = &hmac,
            .sha256_init = &sha256Init,
        };
    };
    var context: u8 = 0;
    const provider = core.crypto.CryptoProvider{
        .context = &context,
        .vtable = &Spy.vtable,
    };
    const runtime = initHttpRuntime(playback.asTransport(), provider);
    var bytes: [2]u8 = undefined;
    try runtime.crypto.randomBytes(&bytes);
    try std.testing.expectEqualSlices(u8, &.{ 0x5a, 0x5a }, &bytes);
    try std.testing.expectEqual(
        playback.asTransport().context,
        runtime.transport.context,
    );
}

test "initHttpRuntime propagates selected provider failures" {
    var playback = PlaybackTransport.init(std.testing.allocator, &.{});
    const Fault = struct {
        fn failRandom(_: *anyopaque, _: []u8) !void {
            return error.ProviderFailure;
        }
        fn failMd5(
            _: *anyopaque,
            _: []const u8,
            _: *core.crypto.Md5Digest,
        ) !void {
            return error.ProviderFailure;
        }
        fn failSha256(
            _: *anyopaque,
            _: []const u8,
            _: *core.crypto.Sha256Digest,
        ) !void {
            return error.ProviderFailure;
        }
        fn failHmac(
            _: *anyopaque,
            _: []const u8,
            _: []const u8,
            _: *core.crypto.HmacSha256Digest,
        ) !void {
            return error.ProviderFailure;
        }
        fn failSha256Init(
            _: *anyopaque,
            _: std.mem.Allocator,
        ) !core.crypto.Sha256Operation {
            return error.ProviderFailure;
        }
        const vtable: core.crypto.CryptoProvider.VTable = .{
            .random_bytes = &failRandom,
            .md5 = &failMd5,
            .sha256 = &failSha256,
            .hmac_sha256 = &failHmac,
            .sha256_init = &failSha256Init,
        };
    };
    var context: u8 = 0;
    const runtime = initHttpRuntime(playback.asTransport(), .{
        .context = &context,
        .vtable = &Fault.vtable,
    });
    var bytes: [1]u8 = undefined;
    try std.testing.expectError(
        error.ProviderFailure,
        runtime.crypto.randomBytes(&bytes),
    );
}
