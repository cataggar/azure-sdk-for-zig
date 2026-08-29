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
    redacted: bool = false,
};

/// A borrowed HTTP exchange used by playback.
///
/// Method, URL, and body are matched exactly, including whether a body is
/// present. Every request header listed here must occur with the same value;
/// additional live headers are allowed. `REDACTED` values produced by
/// `toJson` wildcard only recognized sensitive header values and sensitive
/// URL query values; nonsensitive fields remain exact. Response headers retain
/// wire order and duplicate values.
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

/// Allocator-owned recordings parsed from `RecordingTransport.toJson`.
///
/// `asSlice` borrows this value. Keep it alive until playback and all open
/// playback operations are finished.
pub const ParsedRecordings = struct {
    allocator: std.mem.Allocator,
    owned: []OwnedExchange,
    recordings: []RecordedExchange,

    pub fn asSlice(self: *const ParsedRecordings) []const RecordedExchange {
        return self.recordings;
    }

    pub fn deinit(self: *ParsedRecordings) void {
        for (self.owned) |*exchange| exchange.deinit(self.allocator);
        self.allocator.free(self.owned);
        self.allocator.free(self.recordings);
        self.* = undefined;
    }
};

pub const BodyDirection = enum {
    request,
    response,
};

/// Exchange-aware input for an optional recording body policy.
pub const BodySafetyContext = struct {
    direction: BodyDirection,
    method: core.http.Method,
    url: []const u8,
    content_type: ?[]const u8,
    content_encoding: ?[]const u8,
    body: []const u8,
};

/// A caller body policy may add a schema-specific rejection or explicitly
/// allow an otherwise opaque/unsupported body that the caller knows is safe.
///
/// Built-in recognized credentials and private-key markers are never bypassed
/// by `allow_opaque`.
pub const BodyPolicyDecision = enum {
    inspect,
    reject_sensitive,
    allow_opaque,
};

/// Exchange-aware input for an optional recording header policy.
pub const HeaderSafetyContext = struct {
    direction: BodyDirection,
    method: core.http.Method,
    url: []const u8,
    name: []const u8,
    value: []const u8,
};

/// Header policy decisions are serialized into structured matching metadata.
///
/// `preserve` is an explicit escape hatch for application headers that the
/// built-in conservative name rules classify as sensitive. The caller is
/// responsible for proving that the value is safe to persist.
pub const HeaderPolicyDecision = enum {
    inspect,
    redact,
    preserve,
};

/// Recording safety policy callbacks and their borrowed contexts.
///
/// Callback contexts must outlive every `toJson` call on the transport.
pub const RecordingOptions = struct {
    body_policy_context: ?*anyopaque = null,
    bodyPolicyFn: ?*const fn (
        context: ?*anyopaque,
        body: BodySafetyContext,
    ) BodyPolicyDecision = null,
    header_policy_context: ?*anyopaque = null,
    headerPolicyFn: ?*const fn (
        context: ?*anyopaque,
        header: HeaderSafetyContext,
    ) HeaderPolicyDecision = null,
};

/// Parse the versioned, lossless JSON format emitted by `toJson`.
///
/// All returned strings and decoded bodies are allocator-owned. Invalid JSON,
/// unsupported versions or encodings, and invalid base64 are distinct errors.
pub fn parseJson(
    allocator: std.mem.Allocator,
    json: []const u8,
) !ParsedRecordings {
    const parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json,
        .{},
    ) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return error.InvalidRecordingJson,
    };
    defer parsed.deinit();

    const root = switch (parsed.value) {
        .object => |value| value,
        else => return error.InvalidRecordingJson,
    };
    const version = root.get("version") orelse return error.InvalidRecordingJson;
    if (version != .integer or version.integer != recording_format_version)
        return error.UnsupportedRecordingVersion;
    const exchanges_value = root.get("exchanges") orelse
        return error.InvalidRecordingJson;
    const exchange_values = switch (exchanges_value) {
        .array => |value| value.items,
        else => return error.InvalidRecordingJson,
    };

    const owned = try allocator.alloc(OwnedExchange, exchange_values.len);
    var initialized: usize = 0;
    errdefer {
        for (owned[0..initialized]) |*exchange| exchange.deinit(allocator);
        allocator.free(owned);
    }
    for (exchange_values, owned) |value, *exchange| {
        exchange.* = try parseExchange(allocator, value);
        initialized += 1;
    }

    const recordings = try allocator.alloc(RecordedExchange, owned.len);
    for (owned, recordings) |exchange, *recording| {
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
    return .{
        .allocator = allocator,
        .owned = owned,
        .recordings = recordings,
    };
}

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
/// A configured body-policy context is also borrowed and must outlive calls to
/// `toJson`. `deinit` does not deinitialize either borrowed context.
pub const RecordingTransport = struct {
    inner: core.http.HttpTransport,
    exchanges: std.ArrayList(OwnedExchange) = .empty,
    allocator: std.mem.Allocator,
    options: RecordingOptions,

    const vtable: core.http.HttpTransport.VTable = .{
        .send = &sendImpl,
        .open = &openImpl,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        inner: core.http.HttpTransport,
    ) RecordingTransport {
        return initWithOptions(allocator, inner, .{});
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        inner: core.http.HttpTransport,
        options: RecordingOptions,
    ) RecordingTransport {
        return .{
            .inner = inner,
            .allocator = allocator,
            .options = options,
        };
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

    /// Serialize version 2 recordings with lossless base64 bodies while
    /// redacting sensitive header values and sensitive URL query parameters.
    ///
    /// Structurally recognized credential-bearing JSON, form, connection
    /// string, XML, and private-key bodies cause
    /// `error.SensitiveBodyRequiresSanitization`. Malformed JSON-like bodies
    /// and unapproved opaque encodings cause an explicit error; neither is
    /// silently emitted under a false sanitization guarantee.
    pub fn toJson(
        self: *const RecordingTransport,
        allocator: std.mem.Allocator,
    ) ![]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        errdefer output.deinit();
        const writer = &output.writer;
        self.writeJson(writer, allocator) catch |err| switch (err) {
            error.WriteFailed => return error.OutOfMemory,
            else => return err,
        };
        return output.toOwnedSlice();
    }

    fn writeJson(
        self: *const RecordingTransport,
        writer: *std.Io.Writer,
        allocator: std.mem.Allocator,
    ) !void {
        try writer.print(
            "{{\"version\":{d},\"exchanges\":[",
            .{recording_format_version},
        );
        for (self.exchanges.items, 0..) |exchange, index| {
            try ensureExchangeBodySafe(
                allocator,
                self.options,
                exchange,
                .request,
            );
            try ensureExchangeBodySafe(
                allocator,
                self.options,
                exchange,
                .response,
            );
            if (index != 0) try writer.writeAll(",");
            try writer.writeAll("\n  {\"request_method\":");
            try writeJsonString(writer, methodToString(exchange.request_method));
            try writer.writeAll(",\"request_url\":");
            try writeSanitizedUrl(writer, allocator, exchange.request_url);
            try writer.writeAll(",\"request_headers\":");
            try writeHeaders(
                writer,
                allocator,
                self.options,
                exchange,
                .request,
            );
            try writer.writeAll(",\"request_body\":");
            try writeOptionalBody(writer, allocator, exchange.request_body);
            try writer.writeAll(",\"response_status\":");
            try writer.print("{d}", .{exchange.response_status});
            try writer.writeAll(",\"response_headers\":");
            try writeHeaders(
                writer,
                allocator,
                self.options,
                exchange,
                .response,
            );
            try writer.writeAll(",\"response_body\":");
            try writeBody(writer, allocator, exchange.response_body);
            try writer.writeAll("}");
        }
        try writer.writeAll("\n]}\n");
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
        const open_fn = self.inner.vtable.open;
        if (open_fn == null and options.body != null)
            return error.StreamingRequestUnsupported;

        var pending = try PendingRequest.init(
            self.allocator,
            request,
            request.body,
        );
        errdefer pending.deinit(self.allocator);

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

        const inner_operation = if (open_fn) |call_open|
            call_open(
                self.inner.context,
                request,
                inner_options,
            ) catch |err| {
                if (has_capture) {
                    if (request_capture.failure) |failure| return failure;
                }
                return err;
            }
        else
            try BufferedInnerOperation.create(
                try self.inner.vtable.send(self.inner.context, request),
            );
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

const BufferedInnerOperation = struct {
    operation: core.http.HttpOperation,
    response: core.http.Response,
    reader_impl: std.Io.Reader,

    fn create(
        response_value: core.http.Response,
    ) !*core.http.HttpOperation {
        var response = response_value;
        errdefer response.deinit();
        const self = try response.allocator.create(BufferedInnerOperation);
        self.* = .{
            .operation = undefined,
            .response = response,
            .reader_impl = std.Io.Reader.fixed(response.body),
        };
        self.operation = .{
            .status_code = response.status_code,
            .headers = response.headers,
            .response_headers = response.response_headers,
            .body_reader = &self.reader_impl,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &abortImpl,
            .deinitFn = &deinitImpl,
        };
        return &self.operation;
    }

    fn finishImpl(operation: *core.http.HttpOperation) !void {
        const self: *BufferedInnerOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        _ = try self.reader_impl.discardRemaining();
    }

    fn abortImpl(_: *core.http.HttpOperation) void {}

    fn deinitImpl(operation: *core.http.HttpOperation) void {
        const self: *BufferedInnerOperation =
            @alignCast(@fieldParentPtr("operation", operation));
        const allocator = self.response.allocator;
        self.response.deinit();
        allocator.destroy(self);
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

fn parseExchange(
    allocator: std.mem.Allocator,
    value: std.json.Value,
) !OwnedExchange {
    const object = switch (value) {
        .object => |result| result,
        else => return error.InvalidRecordingJson,
    };
    const method_value = object.get("request_method") orelse
        return error.InvalidRecordingJson;
    const request_url_value = object.get("request_url") orelse
        return error.InvalidRecordingJson;
    const request_headers_value = object.get("request_headers") orelse
        return error.InvalidRecordingJson;
    const request_body_value = object.get("request_body") orelse
        return error.InvalidRecordingJson;
    const response_status_value = object.get("response_status") orelse
        return error.InvalidRecordingJson;
    const response_headers_value = object.get("response_headers") orelse
        return error.InvalidRecordingJson;
    const response_body_value = object.get("response_body") orelse
        return error.InvalidRecordingJson;

    const method = try parseMethod(try jsonString(method_value));
    const request_url = try allocator.dupe(u8, try jsonString(request_url_value));
    errdefer allocator.free(request_url);
    const request_headers = try parseHeaders(allocator, request_headers_value);
    errdefer deinitHeaderPairs(allocator, request_headers);
    const request_body = try parseOptionalBody(allocator, request_body_value);
    errdefer if (request_body) |body| allocator.free(body);

    const response_status_integer = switch (response_status_value) {
        .integer => |result| result,
        else => return error.InvalidRecordingJson,
    };
    if (response_status_integer < 0 or response_status_integer > 65535)
        return error.InvalidRecordingJson;
    const response_headers = try parseHeaders(allocator, response_headers_value);
    errdefer deinitHeaderPairs(allocator, response_headers);
    const response_body = try parseBody(allocator, response_body_value);
    errdefer allocator.free(response_body);

    return .{
        .request_method = method,
        .request_url = request_url,
        .request_headers = request_headers,
        .request_body = request_body,
        .response_status = @intCast(response_status_integer),
        .response_body = response_body,
        .response_headers = response_headers,
    };
}

fn parseHeaders(
    allocator: std.mem.Allocator,
    value: std.json.Value,
) ![]HeaderPair {
    const values = switch (value) {
        .array => |result| result.items,
        else => return error.InvalidRecordingJson,
    };
    const headers = try allocator.alloc(HeaderPair, values.len);
    var initialized: usize = 0;
    errdefer {
        for (headers[0..initialized]) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        allocator.free(headers);
    }
    for (values, headers) |header_value, *header| {
        const object = switch (header_value) {
            .object => |result| result,
            else => return error.InvalidRecordingJson,
        };
        const name_value = object.get("name") orelse
            return error.InvalidRecordingJson;
        const field_value = object.get("value") orelse
            return error.InvalidRecordingJson;
        const redacted_value_json = object.get("redacted");
        const redacted = if (redacted_value_json) |flag| switch (flag) {
            .bool => |result| result,
            else => return error.InvalidRecordingJson,
        } else false;
        header.name = try allocator.dupe(u8, try jsonString(name_value));
        errdefer allocator.free(header.name);
        header.value = try allocator.dupe(u8, try jsonString(field_value));
        header.redacted = redacted;
        initialized += 1;
    }
    return headers;
}

fn parseOptionalBody(
    allocator: std.mem.Allocator,
    value: std.json.Value,
) !?[]u8 {
    return switch (value) {
        .null => null,
        else => try parseBody(allocator, value),
    };
}

fn parseBody(
    allocator: std.mem.Allocator,
    value: std.json.Value,
) ![]u8 {
    const object = switch (value) {
        .object => |result| result,
        else => return error.InvalidRecordingJson,
    };
    const encoding_value = object.get("encoding") orelse
        return error.InvalidRecordingJson;
    const data_value = object.get("data") orelse
        return error.InvalidRecordingJson;
    if (!std.mem.eql(u8, try jsonString(encoding_value), "base64"))
        return error.UnsupportedBodyEncoding;
    const encoded = try jsonString(data_value);
    const length = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch
        return error.InvalidRecordingBody;
    const decoded = try allocator.alloc(u8, length);
    errdefer allocator.free(decoded);
    std.base64.standard.Decoder.decode(decoded, encoded) catch
        return error.InvalidRecordingBody;
    return decoded;
}

fn jsonString(value: std.json.Value) ![]const u8 {
    return switch (value) {
        .string => |result| result,
        else => error.InvalidRecordingJson,
    };
}

fn parseMethod(value: []const u8) !core.http.Method {
    inline for (std.meta.fields(core.http.Method)) |field| {
        if (std.mem.eql(u8, value, field.name)) return @enumFromInt(field.value);
    }
    return error.InvalidRecordingMethod;
}

fn matchRequest(
    exchange: RecordedExchange,
    request: *const core.http.Request,
    body: ?[]const u8,
) !void {
    if (exchange.request_method != request.method) return error.MethodMismatch;
    if (!try urlMatches(request.allocator, exchange.request_url, request.url))
        return error.UrlMismatch;
    if ((exchange.request_body == null) != (body == null))
        return error.BodyMismatch;
    if (exchange.request_body) |expected| {
        if (!std.mem.eql(u8, expected, body.?)) return error.BodyMismatch;
    }
    for (exchange.request_headers) |expected| {
        const actual = getHeader(&request.headers, expected.name) orelse
            return error.HeaderMismatch;
        if (!try headerValueMatches(
            request.allocator,
            expected,
            actual,
        ))
            return error.HeaderMismatch;
    }
}

fn headerValueMatches(
    allocator: std.mem.Allocator,
    expected: HeaderPair,
    actual: []const u8,
) !bool {
    if (expected.redacted) return true;
    if (isSanitizedUrlHeader(expected.name)) {
        return urlMatches(allocator, expected.value, actual);
    }
    return std.mem.eql(u8, expected.value, actual);
}

fn urlMatches(
    allocator: std.mem.Allocator,
    expected: []const u8,
    actual: []const u8,
) !bool {
    if (!hasRedactedSensitiveQuery(expected))
        return std.mem.eql(u8, expected, actual);
    const sanitized = try sanitizeUrlAlloc(allocator, actual);
    defer allocator.free(sanitized);
    return std.mem.eql(u8, expected, sanitized);
}

fn hasRedactedSensitiveQuery(url: []const u8) bool {
    const question = std.mem.indexOfScalar(u8, url, '?') orelse return false;
    const fragment = std.mem.indexOfScalarPos(u8, url, question + 1, '#') orelse
        url.len;
    var iterator = std.mem.splitScalar(u8, url[question + 1 .. fragment], '&');
    while (iterator.next()) |parameter| {
        const equals = std.mem.indexOfScalar(u8, parameter, '=') orelse continue;
        if (isSensitiveQueryField(parameter[0..equals]) and
            std.mem.eql(u8, parameter[equals + 1 ..], redacted_value))
        {
            return true;
        }
    }
    return false;
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

pub const redacted_value = "REDACTED";
const recording_format_version = 2;

const explicitly_sensitive_headers = [_][]const u8{
    "authorization",
    "proxy-authorization",
    "x-ms-authorization-auxiliary",
    "x-ms-copy-source-authorization",
    "x-ms-source-authorization",
    "x-ms-file-rename-source-authorization",
    "cookie",
    "set-cookie",
    "x-ms-client-secret",
    "x-ms-client-principal",
    "x-ms-encryption-key",
    "x-ms-encryption-key-sha256",
    "x-ms-sas-token",
    "aeg-sas-key",
    "aeg-sas-token",
    "aad-token",
    "identity-token",
    "lock-token",
    "x-auth-token",
    "ocp-apim-subscription-key",
    "api-key",
    "x-api-key",
    "x-functions-key",
    "subscription-key",
    "x-subscription-key",
};

const fully_redacted_url_headers = [_][]const u8{
    "x-ms-copy-source",
    "x-ms-copy-source-url",
    "x-ms-rename-source",
    "x-ms-file-rename-source",
};

const sanitized_url_headers = [_][]const u8{
    "location",
    "content-location",
    "operation-location",
    "azure-asyncoperation",
};

const sensitive_body_fields = [_][]const u8{
    "accesstoken",
    "refreshtoken",
    "clientsecret",
    "clientassertion",
    "password",
    "pwd",
    "secret",
    "credential",
    "credentials",
    "applicationsecret",
    "apikey",
    "connectionstring",
    "aliassecondaryconnectionstring",
    "primaryconnectionstring",
    "secondaryconnectionstring",
    "primarykey",
    "secondarykey",
    "accountkey",
    "sharedaccesskey",
    "sharedaccesssignature",
    "sshpassword",
    "adminpassword",
    "administratorloginpassword",
    "runaspassword",
    "accesssas",
    "websiteauthencryptionkey",
    "decryptionkey",
    "privatekey",
    "certificatepassword",
    "sasuri",
    "containerurl",
    "containeruri",
    "inputdatauri",
    "outputdatauri",
    "urlsource",
    "token",
    "aadtoken",
    "identitytoken",
    "oidctoken",
    "assertiontoken",
    "sastoken",
    "aegsaskey",
    "aegsastoken",
    "authorization",
};

const sensitive_body_containers = [_][]const u8{
    "keys",
    "listkeys",
    "accesskeys",
    "secrets",
    "connectionstrings",
};

const sensitive_query_fields = [_][]const u8{
    "sig",
    "signature",
    "access_token",
    "refresh_token",
    "client_secret",
    "client_assertion",
    "password",
    "api_key",
    "api-key",
    "subscription-key",
    "aeg-sas-key",
    "aeg-sas-token",
    "account-key",
    "shared-access-key",
    "code",
};

pub fn isSensitiveHeader(name: []const u8) bool {
    for (explicitly_sensitive_headers) |sensitive| {
        if (std.ascii.eqlIgnoreCase(name, sensitive)) return true;
    }
    if (containsIgnoreCase(name, "authorization") or
        containsIgnoreCase(name, "authentication") or
        containsIgnoreCase(name, "credential") or
        containsIgnoreCase(name, "secret") or
        containsIgnoreCase(name, "signature") or
        containsIgnoreCase(name, "auth-token") or
        containsIgnoreCase(name, "access-token") or
        containsIgnoreCase(name, "refresh-token") or
        containsIgnoreCase(name, "sas-token") or
        containsIgnoreCase(name, "encryption-key") or
        containsIgnoreCase(name, "api-key") or
        containsIgnoreCase(name, "apikey") or
        containsIgnoreCase(name, "subscription-key") or
        containsIgnoreCase(name, "functions-key") or
        containsIgnoreCase(name, "account-key") or
        containsIgnoreCase(name, "access-key") or
        containsIgnoreCase(name, "secret-key") or
        containsIgnoreCase(name, "shared-key") or
        normalizedFieldEndsWith(name, "password") or
        normalizedFieldEndsWith(name, "pwd") or
        normalizedFieldEndsWith(name, "privatekey") or
        normalizedFieldEndsWith(name, "connectionstring"))
    {
        return true;
    }
    return isFullyRedactedUrlHeader(name);
}

fn ensureExchangeBodySafe(
    allocator: std.mem.Allocator,
    options: RecordingOptions,
    exchange: OwnedExchange,
    direction: BodyDirection,
) !void {
    const body = switch (direction) {
        .request => exchange.request_body,
        .response => exchange.response_body,
    };
    const bytes = body orelse return;
    if (bytes.len == 0) return;
    const headers = switch (direction) {
        .request => exchange.request_headers,
        .response => exchange.response_headers,
    };
    const context = BodySafetyContext{
        .direction = direction,
        .method = exchange.request_method,
        .url = exchange.request_url,
        .content_type = getHeaderPair(headers, "Content-Type"),
        .content_encoding = getHeaderPair(headers, "Content-Encoding"),
        .body = bytes,
    };
    const decision = if (options.bodyPolicyFn) |policy|
        policy(options.body_policy_context, context)
    else
        .inspect;
    if (decision == .reject_sensitive)
        return error.SensitiveBodyRequiresSanitization;
    return ensureBodySafe(
        allocator,
        context,
        decision == .allow_opaque,
    );
}

fn ensureBodySafe(
    allocator: std.mem.Allocator,
    context: BodySafetyContext,
    allow_opaque: bool,
) !void {
    const bytes = context.body;
    if (containsPrivateKeyMarker(bytes))
        return error.SensitiveBodyRequiresSanitization;

    const content_type = context.content_type orelse "";
    const content_encoding = context.content_encoding orelse "";
    const multipart = containsIgnoreCase(content_type, "multipart/") or
        (containsIgnoreCase(bytes, "content-disposition:") and
            containsIgnoreCase(bytes, "form-data"));
    if (multipart) {
        if (containsSensitiveMultipartField(bytes))
            return error.SensitiveBodyRequiresSanitization;
        if (!allow_opaque) return error.UnsupportedBodySanitization;
        return;
    }

    if (hasUnicodeBom(bytes) or
        std.mem.indexOfScalar(u8, bytes, 0) != null or
        declaresWideCharset(content_type) or
        isBinaryContentType(content_type) or
        (content_encoding.len != 0 and
            !std.ascii.eqlIgnoreCase(
                std.mem.trim(u8, content_encoding, " \t"),
                "identity",
            )) or
        !std.unicode.utf8ValidateSlice(bytes))
    {
        if (!allow_opaque) return error.OpaqueBodyNotAllowed;
        return;
    }

    const xml = containsIgnoreCase(content_type, "xml") or looksLikeXml(bytes);
    if (xml) {
        if (containsSensitiveXml(bytes) or containsSensitiveAssignment(bytes))
            return error.SensitiveBodyRequiresSanitization;
        if (!allow_opaque) return error.UnsupportedBodySanitization;
        return;
    }

    if (isJsonContentType(content_type) or looksLikeStructuredJson(bytes)) {
        const parsed = std.json.parseFromSlice(
            std.json.Value,
            allocator,
            bytes,
            .{},
        ) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return error.UnsupportedBodySanitization,
        };
        defer parsed.deinit();
        if (jsonContainsSensitiveField(parsed.value) or
            jsonContainsExchangeSensitiveSchema(parsed.value, context))
        {
            return error.SensitiveBodyRequiresSanitization;
        }
    }
    if (containsSensitiveAssignment(bytes) or
        containsSensitiveXml(bytes))
    {
        return error.SensitiveBodyRequiresSanitization;
    }
}

fn getHeaderPair(headers: []const HeaderPair, name: []const u8) ?[]const u8 {
    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
    }
    return null;
}

fn containsPrivateKeyMarker(body: []const u8) bool {
    return containsIgnoreCase(body, "-----BEGIN PRIVATE KEY-----") or
        containsIgnoreCase(body, "-----BEGIN RSA PRIVATE KEY-----") or
        containsIgnoreCase(body, "-----BEGIN EC PRIVATE KEY-----") or
        containsIgnoreCase(body, "-----BEGIN ENCRYPTED PRIVATE KEY-----") or
        containsIgnoreCase(body, "-----BEGIN OPENSSH PRIVATE KEY-----") or
        (containsIgnoreCase(body, "-----BEGIN ") and
            containsIgnoreCase(body, "PRIVATE KEY-----"));
}

fn containsSensitiveMultipartField(body: []const u8) bool {
    var search_start: usize = 0;
    while (indexOfIgnoreCasePos(body, search_start, "content-disposition:")) |start| {
        const line_end = std.mem.indexOfAnyPos(
            u8,
            body,
            start,
            "\r\n",
        ) orelse body.len;
        var parameters = std.mem.splitScalar(u8, body[start..line_end], ';');
        _ = parameters.next();
        while (parameters.next()) |parameter| {
            const equals = std.mem.indexOfScalar(u8, parameter, '=') orelse
                continue;
            const name = std.mem.trim(u8, parameter[0..equals], " \t");
            if (!std.ascii.eqlIgnoreCase(name, "name")) continue;
            const value = std.mem.trim(
                u8,
                parameter[equals + 1 ..],
                " \t\"'",
            );
            if (isSensitiveBodyField(value)) return true;
        }
        search_start = line_end;
    }
    return false;
}

fn looksLikeXml(body: []const u8) bool {
    const trimmed = std.mem.trim(u8, body, " \t\r\n");
    return trimmed.len != 0 and trimmed[0] == '<';
}

fn jsonContainsExchangeSensitiveSchema(
    value: std.json.Value,
    context: BodySafetyContext,
) bool {
    const target = parseUrlTarget(context.url) orelse return false;
    if (isKeyVaultHost(target.host)) {
        if ((pathHasResource(target.path, "secrets") or
            pathHasResource(target.path, "certificates")) and
            jsonRootHasField(value, "value"))
        {
            return true;
        }
        if (pathHasResource(target.path, "keys") and
            jsonContainsJwkPrivateField(value))
        {
            return true;
        }
    }
    if (isKustoHost(target.host) and
        jsonContainsField(value, "sourceuri"))
    {
        return true;
    }
    return false;
}

fn jsonRootHasField(value: std.json.Value, field: []const u8) bool {
    const object = switch (value) {
        .object => |result| result,
        else => return false,
    };
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        if (normalizedFieldEquals(entry.key_ptr.*, field)) return true;
    }
    return false;
}

fn jsonContainsField(value: std.json.Value, field: []const u8) bool {
    switch (value) {
        .object => |object| {
            var iterator = object.iterator();
            while (iterator.next()) |entry| {
                if (normalizedFieldEquals(entry.key_ptr.*, field) or
                    jsonContainsField(entry.value_ptr.*, field))
                {
                    return true;
                }
            }
        },
        .array => |array| {
            for (array.items) |item| {
                if (jsonContainsField(item, field)) return true;
            }
        },
        else => {},
    }
    return false;
}

fn jsonContainsJwkPrivateField(value: std.json.Value) bool {
    switch (value) {
        .object => |object| {
            var iterator = object.iterator();
            while (iterator.next()) |entry| {
                const name = entry.key_ptr.*;
                if (normalizedFieldEquals(name, "d") or
                    normalizedFieldEquals(name, "p") or
                    normalizedFieldEquals(name, "q") or
                    normalizedFieldEquals(name, "dp") or
                    normalizedFieldEquals(name, "dq") or
                    normalizedFieldEquals(name, "qi") or
                    jsonContainsJwkPrivateField(entry.value_ptr.*))
                {
                    return true;
                }
            }
        },
        .array => |array| {
            for (array.items) |item| {
                if (jsonContainsJwkPrivateField(item)) return true;
            }
        },
        else => {},
    }
    return false;
}

const UrlTarget = struct {
    host: []const u8,
    path: []const u8,
};

fn parseUrlTarget(url: []const u8) ?UrlTarget {
    const scheme = std.mem.indexOf(u8, url, "://") orelse return null;
    if (!std.ascii.eqlIgnoreCase(url[0..scheme], "https")) return null;
    const authority_start = scheme + 3;
    const path_start = std.mem.indexOfAnyPos(
        u8,
        url,
        authority_start,
        "/?#",
    ) orelse url.len;
    var authority = url[authority_start..path_start];
    if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| {
        authority = authority[at + 1 ..];
    }
    var host = authority;
    if (host.len != 0 and host[0] == '[') {
        const close = std.mem.indexOfScalar(u8, host, ']') orelse return null;
        host = host[0 .. close + 1];
    } else if (std.mem.lastIndexOfScalar(u8, host, ':')) |colon| {
        host = host[0..colon];
    }
    const path_end = std.mem.indexOfAnyPos(
        u8,
        url,
        path_start,
        "?#",
    ) orelse url.len;
    return .{
        .host = host,
        .path = if (path_start < url.len and url[path_start] == '/')
            url[path_start..path_end]
        else
            "",
    };
}

fn hostMatches(host: []const u8, suffix: []const u8) bool {
    if (std.ascii.eqlIgnoreCase(host, suffix)) return true;
    if (host.len <= suffix.len or host[host.len - suffix.len - 1] != '.')
        return false;
    return std.ascii.eqlIgnoreCase(
        host[host.len - suffix.len ..],
        suffix,
    );
}

fn isKeyVaultHost(host: []const u8) bool {
    return hostMatches(host, "vault.azure.net") or
        hostMatches(host, "vault.azure.cn") or
        hostMatches(host, "vault.usgovcloudapi.net") or
        hostMatches(host, "vault.microsoftazure.de") or
        hostMatches(host, "vaultcore.azure.net") or
        hostMatches(host, "managedhsm.azure.net") or
        hostMatches(host, "managedhsm.azure.cn") or
        hostMatches(host, "managedhsm.usgovcloudapi.net");
}

fn isKustoHost(host: []const u8) bool {
    return hostMatches(host, "kusto.windows.net") or
        hostMatches(host, "kusto.chinacloudapi.cn") or
        hostMatches(host, "kusto.usgovcloudapi.net") or
        hostMatches(host, "kusto.cloudapi.de") or
        hostMatches(host, "kusto.fabric.microsoft.com");
}

fn pathHasResource(path: []const u8, resource: []const u8) bool {
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (std.ascii.eqlIgnoreCase(segment, resource)) return true;
    }
    return false;
}

fn looksLikeStructuredJson(body: []const u8) bool {
    const trimmed = std.mem.trim(u8, body, " \t\r\n");
    return trimmed.len != 0 and (trimmed[0] == '{' or trimmed[0] == '[');
}

fn hasUnicodeBom(body: []const u8) bool {
    return std.mem.startsWith(u8, body, "\xef\xbb\xbf") or
        std.mem.startsWith(u8, body, "\xff\xfe") or
        std.mem.startsWith(u8, body, "\xfe\xff") or
        std.mem.startsWith(u8, body, "\xff\xfe\x00\x00") or
        std.mem.startsWith(u8, body, "\x00\x00\xfe\xff");
}

fn declaresWideCharset(content_type: []const u8) bool {
    return containsIgnoreCase(content_type, "charset=utf-16") or
        containsIgnoreCase(content_type, "charset=\"utf-16") or
        containsIgnoreCase(content_type, "charset=utf-32") or
        containsIgnoreCase(content_type, "charset=\"utf-32");
}

fn isJsonContentType(content_type: []const u8) bool {
    return containsIgnoreCase(content_type, "/json") or
        containsIgnoreCase(content_type, "+json");
}

fn isBinaryContentType(content_type: []const u8) bool {
    return containsIgnoreCase(content_type, "application/octet-stream") or
        containsIgnoreCase(content_type, "application/pkcs12") or
        containsIgnoreCase(content_type, "application/x-pkcs12") or
        containsIgnoreCase(content_type, "application/pkcs8") or
        containsIgnoreCase(content_type, "application/x-pem-file") or
        containsIgnoreCase(content_type, "application/zip") or
        containsIgnoreCase(content_type, "application/gzip") or
        containsIgnoreCase(content_type, "application/x-gzip") or
        containsIgnoreCase(content_type, "image/") or
        containsIgnoreCase(content_type, "audio/") or
        containsIgnoreCase(content_type, "video/") or
        containsIgnoreCase(content_type, "font/");
}

fn jsonContainsSensitiveField(value: std.json.Value) bool {
    return jsonContainsSensitiveFieldInContext(value, false);
}

fn jsonContainsSensitiveFieldInContext(
    value: std.json.Value,
    sensitive_container: bool,
) bool {
    switch (value) {
        .object => |object| {
            var iterator = object.iterator();
            while (iterator.next()) |entry| {
                if (isSensitiveBodyField(entry.key_ptr.*) or
                    (sensitive_container and
                        normalizedFieldEquals(entry.key_ptr.*, "value")) or
                    jsonContainsSensitiveFieldInContext(
                        entry.value_ptr.*,
                        sensitive_container or
                            isSensitiveBodyContainer(entry.key_ptr.*),
                    ))
                {
                    return true;
                }
            }
        },
        .array => |array| {
            for (array.items) |item| {
                if (jsonContainsSensitiveFieldInContext(
                    item,
                    sensitive_container,
                )) return true;
            }
        },
        .string => |string| return containsSensitiveScalar(string),
        else => {},
    }
    return false;
}

fn containsSensitiveScalar(value: []const u8) bool {
    return containsPrivateKeyMarker(value) or
        containsSensitiveAssignment(value) or
        containsSasCredential(value) or
        looksLikeJwt(value);
}

fn containsSasCredential(value: []const u8) bool {
    return containsIgnoreCase(value, "SharedAccessSignature") or
        containsIgnoreCase(value, "?sig=") or
        containsIgnoreCase(value, "&sig=") or
        containsIgnoreCase(value, ";sig=") or
        containsIgnoreCase(value, "&amp;sig=") or
        containsIgnoreCase(value, "?aeg-sas-key=") or
        containsIgnoreCase(value, "&aeg-sas-key=") or
        containsIgnoreCase(value, "?aeg-sas-token=") or
        containsIgnoreCase(value, "&aeg-sas-token=") or
        containsIgnoreCase(value, "sig%3d") or
        containsIgnoreCase(value, "sig%253d") or
        (containsIgnoreCase(value, "&e=") and
            containsIgnoreCase(value, "&s="));
}

fn looksLikeJwt(value: []const u8) bool {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    var dots: usize = 0;
    for (trimmed) |byte| {
        if (byte == '.') {
            dots += 1;
        } else if (!std.ascii.isAlphanumeric(byte) and
            byte != '-' and
            byte != '_')
        {
            return false;
        }
    }
    return dots == 2 and trimmed.len >= 24;
}

fn isSensitiveBodyContainer(name: []const u8) bool {
    for (sensitive_body_containers) |field| {
        if (normalizedFieldEquals(name, field)) return true;
    }
    return false;
}

fn isSensitiveBodyField(name: []const u8) bool {
    for (sensitive_body_fields) |field| {
        if (normalizedFieldEquals(name, field)) return true;
    }
    return normalizedFieldEndsWith(name, "password") or
        normalizedFieldEndsWith(name, "secret") or
        normalizedFieldEndsWith(name, "connectionstring") or
        normalizedFieldEndsWith(name, "apikey") or
        normalizedFieldEndsWith(name, "accountkey") or
        normalizedFieldEndsWith(name, "accesskey") or
        normalizedFieldEndsWith(name, "encryptionkey") or
        normalizedFieldEndsWith(name, "privatekey") or
        normalizedFieldEndsWith(name, "sharedkey") or
        normalizedFieldEndsWith(name, "secretkey");
}

fn normalizedFieldEquals(name: []const u8, normalized: []const u8) bool {
    var normalized_index: usize = 0;
    var index: usize = 0;
    while (index < name.len) : (index += 1) {
        const byte = name[index];
        if (!std.ascii.isAlphanumeric(byte)) continue;
        if (normalized_index >= normalized.len or
            std.ascii.toLower(byte) != normalized[normalized_index])
        {
            return false;
        }
        normalized_index += 1;
    }
    return normalized_index == normalized.len;
}

fn normalizedFieldEndsWith(name: []const u8, suffix: []const u8) bool {
    var name_index = name.len;
    var suffix_index = suffix.len;
    while (suffix_index != 0) {
        while (name_index != 0 and
            !std.ascii.isAlphanumeric(name[name_index - 1]))
        {
            name_index -= 1;
        }
        if (name_index == 0) return false;
        name_index -= 1;
        suffix_index -= 1;
        if (std.ascii.toLower(name[name_index]) != suffix[suffix_index])
            return false;
    }
    return true;
}

fn containsSensitiveAssignment(body: []const u8) bool {
    var start: usize = 0;
    var index: usize = 0;
    while (index <= body.len) : (index += 1) {
        if (index != body.len and
            body[index] != '&' and
            body[index] != ';' and
            body[index] != ',' and
            body[index] != '\n' and
            body[index] != '\r')
        {
            continue;
        }
        const field = body[start..index];
        start = index + 1;
        const equals = std.mem.indexOfScalar(u8, field, '=') orelse continue;
        var name = std.mem.trim(u8, field[0..equals], " \t\"'{}[]");
        if (std.mem.lastIndexOfScalar(u8, name, ':')) |colon| {
            name = name[colon + 1 ..];
        }
        var decoded_buffer: [256]u8 = undefined;
        const decoded = percentDecodeFieldName(name, &decoded_buffer) orelse
            continue;
        if (isSensitiveBodyField(decoded)) return true;
    }
    return false;
}

fn percentDecodeFieldName(
    encoded: []const u8,
    buffer: []u8,
) ?[]const u8 {
    var input_index: usize = 0;
    var output_index: usize = 0;
    while (input_index < encoded.len) {
        if (output_index >= buffer.len) return null;
        if (encoded[input_index] == '%' and input_index + 2 < encoded.len) {
            const high = std.fmt.charToDigit(encoded[input_index + 1], 16) catch
                return null;
            const low = std.fmt.charToDigit(encoded[input_index + 2], 16) catch
                return null;
            buffer[output_index] = high * 16 + low;
            input_index += 3;
        } else {
            buffer[output_index] = encoded[input_index];
            input_index += 1;
        }
        output_index += 1;
    }
    return buffer[0..output_index];
}

fn containsSensitiveXml(body: []const u8) bool {
    var index: usize = 0;
    while (std.mem.indexOfScalarPos(u8, body, index, '<')) |open| {
        index = open + 1;
        if (index >= body.len) break;
        if (body[index] == '/' or body[index] == '?' or body[index] == '!') {
            index += 1;
        }
        const name_start = index;
        while (index < body.len and
            body[index] != '>' and
            body[index] != '/' and
            body[index] != ' ' and
            body[index] != '\t' and
            body[index] != '\r' and
            body[index] != '\n')
        {
            index += 1;
        }
        var name = body[name_start..index];
        if (std.mem.lastIndexOfScalar(u8, name, ':')) |colon| {
            name = name[colon + 1 ..];
        }
        if (isSensitiveBodyField(name)) return true;

        while (index < body.len and body[index] != '>') {
            while (index < body.len and
                (body[index] == ' ' or
                    body[index] == '\t' or
                    body[index] == '\r' or
                    body[index] == '\n' or
                    body[index] == '/'))
            {
                index += 1;
            }
            if (index >= body.len or body[index] == '>') break;
            const attribute_start = index;
            while (index < body.len and
                body[index] != '=' and
                body[index] != '>' and
                body[index] != ' ' and
                body[index] != '\t' and
                body[index] != '\r' and
                body[index] != '\n')
            {
                index += 1;
            }
            var attribute_name = body[attribute_start..index];
            if (std.mem.lastIndexOfScalar(u8, attribute_name, ':')) |colon| {
                attribute_name = attribute_name[colon + 1 ..];
            }
            while (index < body.len and
                (body[index] == ' ' or
                    body[index] == '\t' or
                    body[index] == '\r' or
                    body[index] == '\n'))
            {
                index += 1;
            }
            if (index >= body.len or body[index] != '=') continue;
            index += 1;
            while (index < body.len and
                (body[index] == ' ' or
                    body[index] == '\t' or
                    body[index] == '\r' or
                    body[index] == '\n'))
            {
                index += 1;
            }
            if (index >= body.len) break;
            const quote = if (body[index] == '"' or body[index] == '\'')
                body[index]
            else
                0;
            if (quote != 0) index += 1;
            const value_start = index;
            while (index < body.len and
                if (quote != 0)
                    body[index] != quote
                else
                    body[index] != ' ' and
                        body[index] != '\t' and
                        body[index] != '\r' and
                        body[index] != '\n' and
                        body[index] != '>')
            {
                index += 1;
            }
            const attribute_value = body[value_start..index];
            if (isSensitiveBodyField(attribute_name) or
                ((normalizedFieldEquals(attribute_name, "key") or
                    normalizedFieldEquals(attribute_name, "name") or
                    normalizedFieldEquals(attribute_name, "field") or
                    normalizedFieldEquals(attribute_name, "property")) and
                    isSensitiveBodyField(attribute_value)) or
                containsSensitiveAssignment(attribute_value) or
                containsPrivateKeyMarker(attribute_value))
            {
                return true;
            }
            if (quote != 0 and index < body.len) index += 1;
        }
    }
    return false;
}

fn writeHeaders(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    options: RecordingOptions,
    exchange: OwnedExchange,
    direction: BodyDirection,
) !void {
    const headers = switch (direction) {
        .request => exchange.request_headers,
        .response => exchange.response_headers,
    };
    try writer.writeByte('[');
    for (headers, 0..) |header, index| {
        if (index != 0) try writer.writeByte(',');
        try writer.writeAll("{\"name\":");
        try writeJsonString(writer, header.name);
        try writer.writeAll(",\"value\":");
        const context = HeaderSafetyContext{
            .direction = direction,
            .method = exchange.request_method,
            .url = exchange.request_url,
            .name = header.name,
            .value = header.value,
        };
        const decision = if (options.headerPolicyFn) |policy|
            policy(options.header_policy_context, context)
        else
            .inspect;
        const redact = header.redacted or switch (decision) {
            .redact => true,
            .preserve => false,
            .inspect => isSensitiveHeader(header.name),
        };
        if (redact) {
            try writeJsonString(writer, redacted_value);
        } else if (isSanitizedUrlHeader(header.name)) {
            try writeSanitizedUrl(writer, allocator, header.value);
        } else {
            try writeJsonString(writer, header.value);
        }
        try writer.print(",\"redacted\":{}", .{redact});
        try writer.writeByte('}');
    }
    try writer.writeByte(']');
}

fn writeSanitizedUrl(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    url: []const u8,
) !void {
    const sanitized = try sanitizeUrlAlloc(allocator, url);
    defer allocator.free(sanitized);
    try writeJsonString(writer, sanitized);
}

fn sanitizeUrlAlloc(
    allocator: std.mem.Allocator,
    url: []const u8,
) ![]u8 {
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
    errdefer output.deinit();
    const question = std.mem.indexOfScalar(u8, url, '?') orelse {
        return allocator.dupe(u8, url);
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
                redacted_value
            else
                parameter[equals + 1 ..],
        );
    }
    try output.writer.writeAll(url[fragment..]);
    return output.toOwnedSlice();
}

fn isSensitiveQueryField(name: []const u8) bool {
    for (sensitive_query_fields) |sensitive| {
        if (std.ascii.eqlIgnoreCase(name, sensitive)) return true;
    }
    return false;
}

fn isFullyRedactedUrlHeader(name: []const u8) bool {
    for (fully_redacted_url_headers) |header| {
        if (std.ascii.eqlIgnoreCase(name, header)) return true;
    }
    return false;
}

fn isSanitizedUrlHeader(name: []const u8) bool {
    for (sanitized_url_headers) |header| {
        if (std.ascii.eqlIgnoreCase(name, header)) return true;
    }
    return false;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    return indexOfIgnoreCasePos(haystack, 0, needle) != null;
}

fn indexOfIgnoreCasePos(
    haystack: []const u8,
    start: usize,
    needle: []const u8,
) ?usize {
    if (needle.len > haystack.len or start > haystack.len) return null;
    var index = start;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (std.ascii.eqlIgnoreCase(
            haystack[index .. index + needle.len],
            needle,
        )) return index;
    }
    return null;
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

fn writeOptionalBody(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    value: ?[]const u8,
) !void {
    if (value) |bytes| {
        try writeBody(writer, allocator, bytes);
    } else {
        try writer.writeAll("null");
    }
}

fn writeBody(
    writer: *std.Io.Writer,
    allocator: std.mem.Allocator,
    value: []const u8,
) !void {
    const encoded_length = std.base64.standard.Encoder.calcSize(value.len);
    const encoded = try allocator.alloc(u8, encoded_length);
    defer allocator.free(encoded);
    const result = std.base64.standard.Encoder.encode(encoded, value);
    try writer.writeAll("{\"encoding\":\"base64\",\"data\":");
    try writeJsonString(writer, result);
    try writer.writeByte('}');
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

const BufferedOnlyTransport = struct {
    inner: *core.http.MockTransport,

    const vtable: core.http.HttpTransport.VTable = .{
        .send = &send,
    };

    fn asTransport(self: *BufferedOnlyTransport) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    fn send(
        context: *anyopaque,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *BufferedOnlyTransport = @ptrCast(@alignCast(context));
        const transport = self.inner.asTransport();
        return transport.vtable.send(transport.context, request);
    }
};

fn allowKnownSafeOpaqueBody(
    _: ?*anyopaque,
    body: BodySafetyContext,
) BodyPolicyDecision {
    return if (containsIgnoreCase(body.url, "example.com/invalid") or
        containsIgnoreCase(body.url, "example.com/nul"))
        .allow_opaque
    else
        .inspect;
}

fn preserveKnownSafeMetadata(
    _: ?*anyopaque,
    header: HeaderSafetyContext,
) HeaderPolicyDecision {
    if (std.ascii.eqlIgnoreCase(header.name, "x-ms-meta-pwd"))
        return .preserve;
    if (std.ascii.eqlIgnoreCase(header.name, "x-application-auth-material"))
        return .redact;
    return .inspect;
}

fn expectRejectedSerializationExcludes(
    recorder: *const RecordingTransport,
    expected_error: anyerror,
    secrets: []const []const u8,
) !void {
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try std.testing.expectError(
        expected_error,
        recorder.writeJson(&output.writer, std.testing.allocator),
    );
    for (secrets) |secret| {
        try std.testing.expect(
            std.mem.indexOf(u8, output.written(), secret) == null,
        );
    }
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

test "recording preserves buffered open fallback" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "buffered-response",
    );
    defer mock.deinit();
    var buffered_only = BufferedOnlyTransport{ .inner = &mock };
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        buffered_only.asTransport(),
    );
    defer recorder.deinit();

    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/buffered",
    );
    defer request.deinit();
    request.body = "buffered-request";
    var operation = try recorder.asTransport().open(&request, .{});
    const response = try (try operation.reader()).allocRemaining(
        std.testing.allocator,
        .unlimited,
    );
    defer std.testing.allocator.free(response);
    try std.testing.expectEqualStrings("buffered-response", response);
    try operation.finish();
    operation.deinit();
    try std.testing.expectEqual(@as(usize, 1), recorder.getExchanges().len);
    try std.testing.expectEqualStrings(
        "buffered-request",
        recorder.getExchanges()[0].request_body.?,
    );

    var streamed_request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/streamed",
    );
    defer streamed_request.deinit();
    var source = std.Io.Reader.fixed("streamed");
    try std.testing.expectError(
        error.StreamingRequestUnsupported,
        recorder.asTransport().open(&streamed_request, .{
            .body = core.http.StreamingRequestBody.chunked(&source),
        }),
    );
    try std.testing.expectEqual(@as(usize, 1), mock.call_count);
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

test "sensitive Azure headers are classified case-insensitively" {
    for ([_][]const u8{
        "Authorization",
        "X-MS-AUTHORIZATION-AUXILIARY",
        "x-ms-copy-source-authorization",
        "X-MS-SOURCE-AUTHORIZATION",
        "x-ms-encryption-key",
        "X-MS-SOURCE-ENCRYPTION-KEY-SHA256",
        "X-MS-COPY-SOURCE",
        "X-MS-FILE-RENAME-SOURCE",
        "x-ms-file-rename-source-authorization",
        "OCP-APIM-SUBSCRIPTION-KEY",
        "x-functions-key",
        "X-Auth-Token",
        "AeG-SaS-KeY",
        "aEg-SaS-ToKeN",
        "Set-Cookie",
    }) |name| {
        try std.testing.expect(isSensitiveHeader(name));
    }
    try std.testing.expect(!isSensitiveHeader("Content-Type"));
    try std.testing.expect(!isSensitiveHeader("x-opt-partition-key"));
    try std.testing.expect(!isSensitiveHeader("x-ms-documentdb-partitionkey"));
    try std.testing.expect(!isSensitiveHeader("x-ms-continuation-token"));
}

test "sensitive metadata headers redact with configurable exact overrides" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "response",
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "X-MS-META-PASSWORD", .value = "response-password-value" },
        .{ .name = "x-ms-meta-private-key", .value = "cmVzcG9uc2Uta2V5" },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .headerPolicyFn = &preserveKnownSafeMetadata },
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://storage.example/container/blob",
    );
    defer request.deinit();
    try request.setHeader("x-Ms-MeTa-PaSsWoRd", "request-password-value");
    try request.setHeader("X-MS-META-PRIVATE-KEY", "cmVxdWVzdC1rZXk=");
    try request.setHeader(
        "x-ms-meta-connection-string",
        "RW5kcG9pbnQ9eDtBY2NvdW50S2V5PXk=",
    );
    try request.setHeader("X-MS-META-PWD", "known-safe-label");
    try request.setHeader(
        "X-Application-Auth-Material",
        "custom-sensitive-value",
    );
    var response = try recorder.asTransport().send(&request);
    response.deinit();

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    for ([_][]const u8{
        "response-password-value",
        "cmVzcG9uc2Uta2V5",
        "request-password-value",
        "cmVxdWVzdC1rZXk=",
        "RW5kcG9pbnQ9eDtBY2NvdW50S2V5PXk=",
        "custom-sensitive-value",
    }) |secret| {
        try std.testing.expect(std.mem.indexOf(u8, json, secret) == null);
    }
    try std.testing.expect(
        std.mem.indexOf(u8, json, "known-safe-label") != null,
    );

    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var live = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://storage.example/container/blob",
    );
    defer live.deinit();
    try live.setHeader("x-ms-meta-password", "rotated-password");
    try live.setHeader("x-ms-meta-private-key", "rotated-private-key");
    try live.setHeader(
        "x-ms-meta-connection-string",
        "rotated-connection-string",
    );
    try live.setHeader("x-ms-meta-pwd", "known-safe-label");
    try live.setHeader("x-application-auth-material", "rotated-custom-value");
    var replayed = try playback.asTransport().send(&live);
    replayed.deinit();

    var mismatch = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    try live.setHeader("x-ms-meta-pwd", "different-safe-label");
    try std.testing.expectError(
        error.HeaderMismatch,
        mismatch.asTransport().send(&live),
    );
}

test "Event Grid key and SAS token redactions roundtrip" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "response",
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "aEg-SaS-KeY", .value = "response-event-grid-key" },
        .{ .name = "AEG-SAS-TOKEN", .value = "response-event-grid-token" },
    };
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://topic.eventgrid.azure.net/api/events?AeG-SaS-KeY=query-event-grid-key&AeG-SaS-ToKeN=query-event-grid-token&mode=one",
    );
    defer request.deinit();
    request.body = "event";
    try request.setHeader("AeG-SaS-KeY", "header-event-grid-key");
    try request.setHeader("aEg-SaS-ToKeN", "header-event-grid-token");
    var response = try recorder.asTransport().send(&request);
    response.deinit();

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    for ([_][]const u8{
        "query-event-grid-key",
        "query-event-grid-token",
        "header-event-grid-key",
        "header-event-grid-token",
        "response-event-grid-key",
        "response-event-grid-token",
    }) |credential| {
        try std.testing.expect(std.mem.indexOf(u8, json, credential) == null);
    }

    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var live = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://topic.eventgrid.azure.net/api/events?AeG-SaS-KeY=live-query-key&AeG-SaS-ToKeN=live-query-token&mode=one",
    );
    defer live.deinit();
    live.body = "event";
    try live.setHeader("aeg-sas-key", "live-header-key");
    try live.setHeader("AEG-SAS-TOKEN", "live-header-token");
    var replayed = try playback.asTransport().send(&live);
    replayed.deinit();
}

test "Azure Files rename source URL redactions roundtrip" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        202,
        "accepted",
    );
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .PUT,
        "https://account.file.core.windows.net/share/destination",
    );
    defer request.deinit();
    try request.setHeader(
        "X-Ms-FiLe-ReNaMe-SoUrCe",
        "https://account.file.core.windows.net/share/source?sig=file-rename-secret&sv=2026-01-01",
    );
    try request.setHeader(
        "x-ms-file-rename-source-authorization",
        "Bearer file-rename-auth-secret",
    );
    var response = try recorder.asTransport().send(&request);
    response.deinit();

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(
        std.mem.indexOf(u8, json, "file-rename-secret") == null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, json, "file-rename-auth-secret") == null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, json, "account.file.core.windows.net/share/source") == null,
    );

    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var live = core.http.Request.init(
        std.testing.allocator,
        .PUT,
        "https://account.file.core.windows.net/share/destination",
    );
    defer live.deinit();
    try live.setHeader(
        "x-ms-file-rename-source",
        "https://rotated.file.core.windows.net/other/source?sig=rotated-key",
    );
    try live.setHeader(
        "X-MS-FILE-RENAME-SOURCE-AUTHORIZATION",
        "Bearer rotated-auth-key",
    );
    var replayed = try playback.asTransport().send(&live);
    replayed.deinit();
}

test "App Configuration key query remains exact" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "setting",
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
        "https://config.azconfig.io/kv?key=prod*&api-version=1.0",
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "key=prod*") != null);

    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var different = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://config.azconfig.io/kv?key=dev*&api-version=1.0",
    );
    defer different.deinit();
    try std.testing.expectError(
        error.UrlMismatch,
        playback.asTransport().send(&different),
    );
}

test "authenticated recording JSON roundtrips with structured redactions" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "response",
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "Set-Cookie", .value = "session=response-cookie-secret" },
        .{ .name = "X-MS-ENCRYPTION-KEY", .value = "response-key-secret" },
        .{
            .name = "x-ms-copy-source-authorization",
            .value = "Bearer response-copy-auth-secret",
        },
        .{
            .name = "Location",
            .value = "https://example.com/next?sig=response-sas-secret&next=1",
        },
        .{
            .name = "x-ms-copy-source",
            .value = "https://storage.example/source?sig=response-copy-secret",
        },
    };
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/items?sig=request-sas-secret&version=1",
    );
    defer request.deinit();
    request.body = "safe request";
    try request.setHeader("Authorization", "Bearer bearer-secret");
    try request.setHeader("X-MS-ENCRYPTION-KEY", "encryption-secret");
    try request.setHeader(
        "x-ms-source-encryption-key",
        "source-encryption-secret",
    );
    try request.setHeader(
        "x-ms-source-encryption-key-sha256",
        "source-encryption-hash",
    );
    try request.setHeader(
        "x-ms-source-authorization",
        "Bearer source-auth-secret",
    );
    try request.setHeader(
        "x-Ms-CoPy-SoUrCe-AuThOrIzAtIoN",
        "Bearer copy-auth-secret",
    );
    try request.setHeader(
        "X-MS-COPY-SOURCE",
        "https://storage.example/source?sig=copy-sas-secret&sp=r",
    );
    try request.setHeader(
        "Ocp-Apim-Subscription-Key",
        "subscription-secret",
    );
    try request.setHeader("x-functions-key", "function-secret");
    try request.setHeader("X-Stable", "stable-value");
    var response = try recorder.asTransport().send(&request);
    response.deinit();

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    for ([_][]const u8{
        "request-sas-secret",
        "bearer-secret",
        "encryption-secret",
        "copy-auth-secret",
        "copy-sas-secret",
        "subscription-secret",
        "function-secret",
        "response-cookie-secret",
        "response-key-secret",
        "response-copy-auth-secret",
        "response-sas-secret",
        "response-copy-secret",
        "source-encryption-secret",
        "source-encryption-hash",
        "source-auth-secret",
    }) |secret| {
        try std.testing.expect(std.mem.indexOf(u8, json, secret) == null);
    }
    try std.testing.expect(
        std.mem.indexOf(u8, json, "https://storage.example/source") == null,
    );
    try std.testing.expect(std.mem.indexOf(u8, json, "sp=r") == null);

    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var live = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/items?sig=different-sas&version=1",
    );
    defer live.deinit();
    live.body = "safe request";
    try live.setHeader("Authorization", "Bearer different-bearer");
    try live.setHeader("x-ms-encryption-key", "different-key");
    try live.setHeader(
        "X-MS-SOURCE-ENCRYPTION-KEY",
        "different-source-key",
    );
    try live.setHeader(
        "X-MS-SOURCE-ENCRYPTION-KEY-SHA256",
        "different-source-key-hash",
    );
    try live.setHeader(
        "X-MS-SOURCE-AUTHORIZATION",
        "Bearer different-source-auth",
    );
    try live.setHeader(
        "X-MS-COPY-SOURCE-AUTHORIZATION",
        "Bearer different-copy-auth",
    );
    try live.setHeader(
        "x-ms-copy-source",
        "https://elsewhere.example/object?sig=different-copy-sas",
    );
    try live.setHeader("ocp-apim-subscription-key", "different-subscription");
    try live.setHeader("X-FUNCTIONS-KEY", "different-function-key");
    try live.setHeader("X-Stable", "stable-value");
    var replayed = try playback.asTransport().send(&live);
    replayed.deinit();

    var header_mismatch = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    try live.setHeader("X-Stable", "changed");
    try std.testing.expectError(
        error.HeaderMismatch,
        header_mismatch.asTransport().send(&live),
    );

    var url_mismatch = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    try live.setHeader("X-Stable", "stable-value");
    live.url = "https://example.com/items?sig=different-sas&version=2";
    try std.testing.expectError(
        error.UrlMismatch,
        url_mismatch.asTransport().send(&live),
    );

    var body_mismatch = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    live.url = "https://example.com/items?sig=different-sas&version=1";
    live.body = "changed request";
    try std.testing.expectError(
        error.BodyMismatch,
        body_mismatch.asTransport().send(&live),
    );
}

test "recording JSON base64 bodies roundtrip arbitrary bytes" {
    const urls = [_][]const u8{
        "https://example.com/invalid",
        "https://example.com/nul",
        "https://example.com/empty",
        "https://example.com/utf8",
    };
    const request_bodies = [_][]const u8{
        "\xff\xfe\x80",
        "\x00request\x00",
        "",
        "snowman: \xe2\x98\x83",
    };
    const response_bodies = [_][]const u8{
        "\x80\xff\x00",
        "response\x00body",
        "",
        "lambda: \xce\xbb",
    };
    var sequence = core.http.SequenceMockTransport.init(
        std.testing.allocator,
        &.{
            .{ .status = 200, .body = response_bodies[0] },
            .{ .status = 200, .body = response_bodies[1] },
            .{ .status = 200, .body = response_bodies[2] },
            .{ .status = 200, .body = response_bodies[3] },
        },
    );
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        sequence.asTransport(),
        .{ .bodyPolicyFn = &allowKnownSafeOpaqueBody },
    );
    defer recorder.deinit();
    for (urls, request_bodies) |url, body| {
        var request = core.http.Request.init(std.testing.allocator, .POST, url);
        defer request.deinit();
        request.body = body;
        var response = try recorder.asTransport().send(&request);
        response.deinit();
    }

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.unicode.utf8ValidateSlice(json));
    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    for (urls, request_bodies, response_bodies) |url, request_body, expected| {
        var request = core.http.Request.init(std.testing.allocator, .POST, url);
        defer request.deinit();
        request.body = request_body;
        var response = try playback.asTransport().send(&request);
        defer response.deinit();
        try std.testing.expectEqualSlices(u8, expected, response.body);
    }
}

fn expectSensitiveResponseBodyRejected(body: []const u8) !void {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        body,
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
    try expectRejectedSerializationExcludes(
        &recorder,
        error.SensitiveBodyRequiresSanitization,
        &.{body},
    );
}

fn expectSensitiveRequestBodyRejected(body: []const u8) !void {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "{\"message\":\"safe\"}",
    );
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/request",
    );
    defer request.deinit();
    request.body = body;
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    try expectRejectedSerializationExcludes(
        &recorder,
        error.SensitiveBodyRequiresSanitization,
        &.{body},
    );
}

test "recording JSON rejects structural JSON form XML and connection secrets" {
    for ([_][]const u8{
        "{\"primaryKey\":\"primary-value\"}",
        "{\"listKeys\":{\"Secondary_Key\":{\"value\":\"secondary-value\"}}}",
        "{\"keys\":[{\"name\":\"primary\",\"value\":\"nested-key-value\"}]}",
        "{\"List-Keys\":{\"value\":\"nested-list-key-value\"}}",
        "{\"result\":{\"connectionString\":\"Endpoint=x;SharedAccessKey=y\"}}",
        "{\"outer\":[{\"Api-Key\":{\"value\":\"api-value\"}}]}",
        "{\"applicationSecret\":\"application-value\"}",
        "{\"properties\":{\"vCenterPassword\":\"vcenter-value\",\"NSXT-PASSWORD\":{\"value\":\"nsxt-value\"}}}",
        "client_secret=form-value&grant_type=client_credentials",
        "Endpoint=https://example;AccountKey=account-value",
        "<ListKeys><PrimaryKey>xml-value</PrimaryKey></ListKeys>",
        "<ns:Credentials><ns:Value>nested-value</ns:Value></ns:Credentials>",
        "-----BEGIN PRIVATE KEY-----\nprivate-value\n-----END PRIVATE KEY-----",
    }) |body| {
        try expectSensitiveResponseBodyRejected(body);
    }
    try expectSensitiveRequestBodyRejected(
        "{\"outer\":{\"CLIENT-ASSERTION\":{\"value\":\"request-value\"}}}",
    );
}

test "Key Vault root value bodies are endpoint-sensitive" {
    {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "{\"value\":\"response-key-vault-value\"}",
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
            "https://example.vault.azure.net/secrets/name?api-version=7.6",
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            &.{"response-key-vault-value"},
        );
    }
    {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "{\"id\":\"safe\"}",
        );
        defer mock.deinit();
        var recorder = RecordingTransport.init(
            std.testing.allocator,
            mock.asTransport(),
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .PUT,
            "https://example.vault.azure.net/secrets/name?api-version=7.6",
        );
        defer request.deinit();
        request.body = "{\"VaLuE\":\"request-key-vault-value\"}";
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            &.{"request-key-vault-value"},
        );
    }
}

test "Key Vault path text on App Configuration hosts stays recordable and exact" {
    const body = "{\"key\":\"team/vault/secrets/name\",\"value\":\"ordinary-setting\"}";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        body,
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "application/json" },
    };
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://store.azconfig.io/kv/team/vault/secrets/name?api-version=1.0",
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    response.deinit();

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "ordinary-setting") == null);
    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqualSlices(
        u8,
        body,
        parsed.asSlice()[0].response_body,
    );

    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var replayed = try playback.asTransport().send(&request);
    defer replayed.deinit();
    try std.testing.expectEqualSlices(u8, body, replayed.body);

    var mismatch = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var different = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://store.azconfig.io/kv/team/vault/secrets/other?api-version=1.0",
    );
    defer different.deinit();
    try std.testing.expectError(
        error.UrlMismatch,
        mismatch.asTransport().send(&different),
    );
}

test "Key Vault exchange rules ignore untrusted origins" {
    for ([_][]const u8{
        "https://example.vault.azure.net.attacker.test/secrets/name",
        "https://vault.azure.cn.attacker.test/certificates/name",
        "http://example.vault.azure.net/secrets/name",
    }) |url| {
        const body = "{\"value\":\"ordinary-non-vault-value\"}";
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            body,
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
            url,
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        const json = try recorder.toJson(std.testing.allocator);
        defer std.testing.allocator.free(json);
        var parsed = try parseJson(std.testing.allocator, json);
        defer parsed.deinit();
        try std.testing.expectEqualSlices(
            u8,
            body,
            parsed.asSlice()[0].response_body,
        );
    }
}

test "Key Vault private JWK and certificate import schemas are rejected" {
    {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "{\"key\":{\"kty\":\"RSA\",\"n\":\"public\",\"e\":\"AQAB\",\"D\":\"ZC1wcml2YXRl\",\"p\":\"cA==\",\"q\":\"cQ==\",\"dP\":\"ZHA=\",\"dq\":\"ZHE=\",\"QI\":\"cWk=\"}}",
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
            "https://example.vault.azure.net/keys/name/version?api-version=7.6",
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            &.{ "ZC1wcml2YXRl", "ZHA=", "cWk=" },
        );
    }
    {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "{\"id\":\"safe\"}",
        );
        defer mock.deinit();
        var recorder = RecordingTransport.init(
            std.testing.allocator,
            mock.asTransport(),
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .POST,
            "https://example.vault.azure.net/certificates/name/import?api-version=7.6",
        );
        defer request.deinit();
        request.body =
            "{\"value\":\"UEZYLUJBU0U2NC1WQUxVRQ==\",\"PwD\":\"certificate-password\"}";
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            &.{ "UEZYLUJBU0U2NC1WQUxVRQ==", "certificate-password" },
        );
    }
}

test "Kusto source URIs and tabular credential scalars are rejected" {
    for ([_][]const u8{
        "{\"sourceUri\":\"https://storage.example/container?sig=kusto-source-sas\"}",
        "{\"Tables\":[{\"Rows\":[[\"https://storage.example/blob?sig=row-sas\"]]}]}",
        "{\"Tables\":[{\"Rows\":[[\"https%3A%2F%2Fstorage.example%2Fblob%3Fsv%3D1%26sig%3Dencoded-sas\"]]}]}",
        "{\"Tables\":[{\"Rows\":[[\"aaaaaaaa.bbbbbbbb.cccccccc\"]]}]}",
    }) |body| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            body,
        );
        defer mock.deinit();
        var recorder = RecordingTransport.init(
            std.testing.allocator,
            mock.asTransport(),
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .POST,
            "https://cluster.kusto.windows.net/v2/rest/query",
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            &.{
                "kusto-source-sas",
                "row-sas",
                "encoded-sas",
                "aaaaaaaa.bbbbbbbb.cccccccc",
            },
        );
    }
}

test "multipart token fields and XML credential attributes are rejected" {
    {
        const multipart_body =
            "--boundary\r\n" ++
            "Content-Disposition: form-data; name=\"refreshToken\"\r\n\r\n" ++
            "registry-refresh-value\r\n" ++
            "--boundary\r\n" ++
            "Content-Disposition: form-data; name=\"accessToken\"\r\n\r\n" ++
            "registry-access-value\r\n" ++
            "--boundary--\r\n";
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "{\"message\":\"safe\"}",
        );
        defer mock.deinit();
        var recorder = RecordingTransport.init(
            std.testing.allocator,
            mock.asTransport(),
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .POST,
            "https://registry.azurecr.io/oauth2/exchange",
        );
        defer request.deinit();
        request.body = multipart_body;
        try request.setHeader(
            "Content-Type",
            "multipart/form-data; boundary=boundary",
        );
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try std.testing.expectError(
            error.SensitiveBodyRequiresSanitization,
            recorder.toJson(std.testing.allocator),
        );
    }
    {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "<settings><add key=\"Password\" value=\"xml-attribute-value\"/></settings>",
        );
        defer mock.deinit();
        mock.response_headers_list = &.{
            .{ .name = "Content-Type", .value = "application/xml" },
        };
        var recorder = RecordingTransport.init(
            std.testing.allocator,
            mock.asTransport(),
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            "https://example.com/settings",
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try std.testing.expectError(
            error.SensitiveBodyRequiresSanitization,
            recorder.toJson(std.testing.allocator),
        );
    }
}

test "opaque bodies reject by default and require an explicit safe policy" {
    const opaque_bodies = [_][]const u8{
        "\x30\x82\xff\x00pkcs12-like",
        "\xff\xfeP\x00a\x00s\x00s\x00w\x00o\x00r\x00d\x00",
        "A\x00c\x00c\x00o\x00u\x00n\x00t\x00K\x00e\x00y\x00=\x00v\x00a\x00l\x00u\x00e\x00",
        "A\x00\x00\x00c\x00\x00\x00c\x00\x00\x00o\x00\x00\x00u\x00\x00\x00n\x00\x00\x00t\x00\x00\x00K\x00\x00\x00e\x00\x00\x00y\x00\x00\x00=\x00\x00\x00v\x00\x00\x00",
        "\xef\xbb\xbf{\"message\":\"utf8-bom\"}",
        "{\"message\":\"malformed\xff\"}",
    };
    for (opaque_bodies) |body| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            body,
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
            "https://example.com/opaque",
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try std.testing.expectError(
            error.OpaqueBodyNotAllowed,
            recorder.toJson(std.testing.allocator),
        );
    }
}

test "common private key markers cannot be allowed as opaque" {
    for ([_][]const u8{
        "-----BEGIN PRIVATE KEY-----\nvalue\n-----END PRIVATE KEY-----",
        "-----BEGIN RSA PRIVATE KEY-----\nvalue\n-----END RSA PRIVATE KEY-----",
        "-----BEGIN EC PRIVATE KEY-----\nvalue\n-----END EC PRIVATE KEY-----",
        "-----BEGIN ENCRYPTED PRIVATE KEY-----\nvalue\n-----END ENCRYPTED PRIVATE KEY-----",
        "-----BEGIN OPENSSH PRIVATE KEY-----\nvalue\n-----END OPENSSH PRIVATE KEY-----",
    }) |body| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            body,
        );
        defer mock.deinit();
        var recorder = RecordingTransport.initWithOptions(
            std.testing.allocator,
            mock.asTransport(),
            .{ .bodyPolicyFn = &allowKnownSafeOpaqueBody },
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            "https://example.com/invalid",
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try std.testing.expectError(
            error.SensitiveBodyRequiresSanitization,
            recorder.toJson(std.testing.allocator),
        );
    }
}

test "recording JSON rejects malformed structured bodies explicitly" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "{\"primaryKey\":\"unterminated\"",
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
        "https://example.com/malformed",
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    try std.testing.expectError(
        error.UnsupportedBodySanitization,
        recorder.toJson(std.testing.allocator),
    );
}

test "declared encodings and opaque MIME bodies require explicit approval" {
    const cases = [_]struct {
        content_type: []const u8,
        content_encoding: ?[]const u8 = null,
        body: []const u8,
        expected_error: anyerror,
    }{
        .{
            .content_type = "application/json",
            .body = "not-json",
            .expected_error = error.UnsupportedBodySanitization,
        },
        .{
            .content_type = "application/json; charset=utf-16le",
            .body = "{\x00\"\x00v\x00a\x00l\x00u\x00e\x00\"\x00:\x00\"\x00x\x00\"\x00}\x00",
            .expected_error = error.OpaqueBodyNotAllowed,
        },
        .{
            .content_type = "application/json; charset=utf-32",
            .body = "{\x00\x00\x00}\x00\x00\x00",
            .expected_error = error.OpaqueBodyNotAllowed,
        },
        .{
            .content_type = "application/octet-stream",
            .body = "printable-but-opaque",
            .expected_error = error.OpaqueBodyNotAllowed,
        },
        .{
            .content_type = "application/json",
            .content_encoding = "gzip",
            .body = "compressed-looking-body",
            .expected_error = error.OpaqueBodyNotAllowed,
        },
    };
    for (cases) |case| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            case.body,
        );
        defer mock.deinit();
        if (case.content_encoding) |encoding| {
            mock.response_headers_list = &.{
                .{ .name = "Content-Type", .value = case.content_type },
                .{ .name = "Content-Encoding", .value = encoding },
            };
        } else {
            mock.response_headers_list = &.{
                .{ .name = "Content-Type", .value = case.content_type },
            };
        }
        var recorder = RecordingTransport.init(
            std.testing.allocator,
            mock.asTransport(),
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            "https://example.test/encoding",
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try std.testing.expectError(
            case.expected_error,
            recorder.toJson(std.testing.allocator),
        );
    }
}

test "recording JSON decodes safe structured bodies losslessly" {
    const request_body =
        "{\"key\":\"prod*\",\"value\":\"nonsensitive\",\"nested\":{\"kind\":\"filter\"}}";
    const response_body =
        "{\"items\":[{\"key\":\"prod\",\"value\":\"enabled\"}],\"continuationToken\":\"next\"}";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        response_body,
    );
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://config.azconfig.io/kv?key=prod*&api-version=1.0",
    );
    defer request.deinit();
    request.body = request_body;
    var response = try recorder.asTransport().send(&request);
    response.deinit();

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.asSlice().len);
    try std.testing.expectEqualSlices(
        u8,
        request_body,
        parsed.asSlice()[0].request_body.?,
    );
    try std.testing.expectEqualSlices(
        u8,
        response_body,
        parsed.asSlice()[0].response_body,
    );

    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var replay_request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://config.azconfig.io/kv?key=prod*&api-version=1.0",
    );
    defer replay_request.deinit();
    replay_request.body = request_body;
    var replayed = try playback.asTransport().send(&replay_request);
    defer replayed.deinit();
    try std.testing.expectEqualSlices(u8, response_body, replayed.body);

    var mismatch = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    replay_request.body =
        "{\"key\":\"prod*\",\"value\":\"changed\",\"nested\":{\"kind\":\"filter\"}}";
    try std.testing.expectError(
        error.BodyMismatch,
        mismatch.asTransport().send(&replay_request),
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

fn recordingBufferedFallbackAllocationFixture(
    allocator: std.mem.Allocator,
) !void {
    var mock = core.http.MockTransport.init(allocator, 200, "response");
    defer mock.deinit();
    var buffered_only = BufferedOnlyTransport{ .inner = &mock };
    var recorder = RecordingTransport.init(
        allocator,
        buffered_only.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/buffered",
    );
    defer request.deinit();
    request.body = "request";
    var operation = try recorder.asTransport().open(&request, .{});
    defer operation.deinit();
    try operation.finish();
}

fn serializationAllocationFixture(allocator: std.mem.Allocator) !void {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "{\"message\":\"response\"}",
    );
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/items?sig=secret&version=1",
    );
    defer request.deinit();
    request.body = "{\"message\":\"request\"}";
    try request.setHeader("Authorization", "Bearer secret");
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    const json = try recorder.toJson(allocator);
    allocator.free(json);
}

const allocation_fixture_json =
    \\{"version":2,"exchanges":[{"request_method":"POST","request_url":"https://example.com","request_headers":[],"request_body":{"encoding":"base64","data":"cmVxdWVzdA=="},"response_status":200,"response_headers":[],"response_body":{"encoding":"base64","data":"cmVzcG9uc2U="}}]}
;

fn parsingAllocationFixture(allocator: std.mem.Allocator) !void {
    var parsed = try parseJson(allocator, allocation_fixture_json);
    parsed.deinit();
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
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        recordingBufferedFallbackAllocationFixture,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        serializationAllocationFixture,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        parsingAllocationFixture,
        .{},
    );
}

test "recording parser reports version encoding and base64 errors" {
    try std.testing.expectError(
        error.UnsupportedRecordingVersion,
        parseJson(
            std.testing.allocator,
            "{\"version\":1,\"exchanges\":[]}",
        ),
    );
    try std.testing.expectError(
        error.UnsupportedBodyEncoding,
        parseJson(
            std.testing.allocator,
            "{\"version\":2,\"exchanges\":[{\"request_method\":\"GET\",\"request_url\":\"https://example.com\",\"request_headers\":[],\"request_body\":null,\"response_status\":200,\"response_headers\":[],\"response_body\":{\"encoding\":\"raw\",\"data\":\"value\"}}]}",
        ),
    );
    try std.testing.expectError(
        error.InvalidRecordingBody,
        parseJson(
            std.testing.allocator,
            "{\"version\":2,\"exchanges\":[{\"request_method\":\"GET\",\"request_url\":\"https://example.com\",\"request_headers\":[],\"request_body\":null,\"response_status\":200,\"response_headers\":[],\"response_body\":{\"encoding\":\"base64\",\"data\":\"***\"}}]}",
        ),
    );
    try std.testing.expectError(
        error.InvalidRecordingJson,
        parseJson(
            std.testing.allocator,
            "{\"version\":2,\"exchanges\":[{\"request_method\":\"GET\",\"request_url\":\"https://example.com\",\"request_headers\":[{\"name\":\"x-test\",\"value\":\"value\",\"redacted\":\"yes\"}],\"request_body\":null,\"response_status\":200,\"response_headers\":[],\"response_body\":{\"encoding\":\"base64\",\"data\":\"\"}}]}",
        ),
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
