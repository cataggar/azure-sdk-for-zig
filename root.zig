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
/// request built-in inspection of a supported textual body, or allow an
/// otherwise opaque/unsupported body that the caller knows is safe.
///
/// Every non-empty body requires a configured policy. Built-in recognizable
/// credentials and private-key markers are checked before default rejection;
/// the callback is the explicit trust boundary for persistence.
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
/// `inspect` applies the built-in known-safe header-name allowlist, volatile
/// request-header rules, and value scanning; unknown names and recognizable
/// credentials are redacted.
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
/// descriptor copies and open operations are deinitialized. Redirect chains
/// commit atomically at the final buffered response or successful streaming
/// `finish`; failed allocation, abort, or cancellation leaves the original
/// exchange retryable.
pub const PlaybackTransport = struct {
    recordings: []const RecordedExchange,
    index: usize = 0,
    pending_redirect: ?usize = null,
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

    fn matchNext(
        self: *PlaybackTransport,
        request: *const core.http.Request,
        body: ?[]const u8,
    ) !struct { exchange: RecordedExchange, index: usize } {
        if (self.pending_redirect) |pending| {
            const redirected = pending + 1;
            if (redirected < self.recordings.len and
                try requestMatches(
                    self.recordings[redirected],
                    request,
                    body,
                ))
            {
                return .{
                    .exchange = self.recordings[redirected],
                    .index = redirected,
                };
            }
            if (try requestMatches(
                self.recordings[self.index],
                request,
                body,
            )) {
                self.pending_redirect = null;
                return .{
                    .exchange = self.recordings[self.index],
                    .index = self.index,
                };
            }
            if (pending != self.index and
                try requestMatches(
                    self.recordings[pending],
                    request,
                    body,
                ))
            {
                return .{
                    .exchange = self.recordings[pending],
                    .index = pending,
                };
            }
            const expected = if (redirected < self.recordings.len)
                redirected
            else
                pending;
            try matchRequest(self.recordings[expected], request, body);
            unreachable;
        }
        if (self.index >= self.recordings.len) return error.NoMoreRecordings;
        const exchange = self.recordings[self.index];
        try matchRequest(exchange, request, body);
        return .{ .exchange = exchange, .index = self.index };
    }

    fn commit(self: *PlaybackTransport, exchange_index: usize) void {
        self.pending_redirect = null;
        self.index = exchange_index + 1;
    }

    fn sendImpl(
        context: *anyopaque,
        request: *core.http.Request,
    ) !core.http.Response {
        const self: *PlaybackTransport = @ptrCast(@alignCast(context));
        const matched = try self.matchNext(request, request.body);
        const response = try responseFromExchange(
            self.allocator,
            matched.exchange,
        );
        if (responseRecordsRedirect(request, response)) {
            self.pending_redirect = matched.index;
        } else {
            self.commit(matched.index);
        }
        return response;
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

        const matched = try self.matchNext(request, body);
        const operation = try PlaybackOperation.create(
            self,
            matched.exchange,
            matched.index,
        );
        if (recordsRedirect(request, options, operation)) {
            self.pending_redirect = matched.index;
        }
        self.open_count += 1;
        return operation;
    }
};

const PlaybackOperation = struct {
    operation: core.http.HttpOperation,
    allocator: std.mem.Allocator,
    owner: *PlaybackTransport,
    exchange_index: usize,
    committed: bool = false,
    response_body: []u8,
    reader_impl: std.Io.Reader,

    fn create(
        owner: *PlaybackTransport,
        exchange: RecordedExchange,
        exchange_index: usize,
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
            .exchange_index = exchange_index,
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
        if (!self.committed) {
            self.owner.commit(self.exchange_index);
            self.committed = true;
        }
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
        if (!self.committed and
            self.owner.pending_redirect != null)
        {
            self.owner.pending_redirect = null;
        }
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
    /// Every non-empty body requires a configured `bodyPolicyFn`. Returning
    /// `.inspect` explicitly opts supported text into built-in checks;
    /// `.allow_opaque` is the caller's trust boundary for known-safe opaque
    /// content.
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

fn responseRecordsRedirect(
    request: *const core.http.Request,
    response: core.http.Response,
) bool {
    if (request.redirect_policy == .not_allowed or
        response.getHeader("Location") == null)
    {
        return false;
    }
    return switch (response.status_code) {
        301, 302, 303, 307, 308 => true,
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

fn requestMatches(
    exchange: RecordedExchange,
    request: *const core.http.Request,
    body: ?[]const u8,
) !bool {
    matchRequest(exchange, request, body) catch |err| switch (err) {
        error.MethodMismatch,
        error.UrlMismatch,
        error.BodyMismatch,
        error.HeaderMismatch,
        => return false,
        else => return err,
    };
    return true;
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
        if (std.mem.eql(u8, parameter[equals + 1 ..], redacted_value)) {
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
    "primarymasterkey",
    "secondarymasterkey",
    "primaryreadonlymasterkey",
    "secondaryreadonlymasterkey",
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
    "id_token",
    "identity_token",
    "sas_token",
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

const known_safe_headers = [_][]const u8{
    "accept",
    "accept-charset",
    "accept-encoding",
    "accept-language",
    "cache-control",
    "connection",
    "content-encoding",
    "content-language",
    "content-length",
    "content-range",
    "content-type",
    "date",
    "etag",
    "expires",
    "host",
    "if-match",
    "if-modified-since",
    "if-none-match",
    "if-unmodified-since",
    "last-modified",
    "location",
    "content-location",
    "operation-location",
    "azure-asyncoperation",
    "pragma",
    "range",
    "retry-after",
    "server",
    "traceparent",
    "tracestate",
    "transfer-encoding",
    "user-agent",
    "vary",
    "x-ms-client-request-id",
    "x-ms-continuation-token",
    "x-ms-date",
    "x-ms-error-code",
    "x-ms-request-id",
    "x-ms-return-client-request-id",
    "x-ms-version",
};

const volatile_request_headers = [_][]const u8{
    "date",
    "x-ms-date",
    "x-ms-client-request-id",
    "client-request-id",
    "request-id",
    "x-request-id",
    "x-ms-request-id",
    "correlation-id",
    "x-correlation-id",
    "x-ms-correlation-request-id",
    "x-ms-routing-request-id",
    "traceparent",
    "tracestate",
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

fn isKnownSafeHeader(name: []const u8) bool {
    for (known_safe_headers) |safe| {
        if (std.ascii.eqlIgnoreCase(name, safe)) return true;
    }
    return false;
}

fn isVolatileRequestHeader(name: []const u8) bool {
    for (volatile_request_headers) |header_name| {
        if (std.ascii.eqlIgnoreCase(name, header_name)) return true;
    }
    return false;
}

fn shouldRedactHeader(
    allocator: std.mem.Allocator,
    direction: BodyDirection,
    name: []const u8,
    value: []const u8,
) !bool {
    return (direction == .request and isVolatileRequestHeader(name)) or
        isSensitiveHeader(name) or
        try containsSensitiveScalar(allocator, value) or
        !isKnownSafeHeader(name);
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
    const policy = options.bodyPolicyFn orelse {
        try ensureBodySafe(allocator, context, false);
        return error.BodyPolicyRequired;
    };
    const decision = policy(options.body_policy_context, context);
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
    if (try containsSensitiveScalar(allocator, bytes))
        return error.SensitiveBodyRequiresSanitization;

    const content_type = context.content_type orelse "";
    const content_encoding = context.content_encoding orelse "";
    const multipart = containsIgnoreCase(content_type, "multipart/") or
        (containsIgnoreCase(bytes, "content-disposition:") and
            containsIgnoreCase(bytes, "form-data"));
    if (multipart) {
        if (try containsSensitiveMultipartContent(
            allocator,
            content_type,
            bytes,
            0,
        ))
            return error.SensitiveBodyRequiresSanitization;
        if (!allow_opaque) return error.UnsupportedBodySanitization;
        return;
    }

    const valid_text = !hasUnicodeBom(bytes) and
        std.mem.indexOfScalar(u8, bytes, 0) == null and
        std.unicode.utf8ValidateSlice(bytes);
    const identity_encoding = content_encoding.len == 0 or
        std.ascii.eqlIgnoreCase(
            std.mem.trim(u8, content_encoding, " \t"),
            "identity",
        );
    const json = valid_text and identity_encoding and
        (isJsonContentType(content_type) or looksLikeStructuredJson(bytes));
    if (json) {
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
        if (try jsonContainsSensitiveField(allocator, parsed.value) or
            jsonContainsExchangeSensitiveSchema(parsed.value, context))
        {
            return error.SensitiveBodyRequiresSanitization;
        }
    }

    const xml = valid_text and identity_encoding and
        (containsIgnoreCase(content_type, "xml") or looksLikeXml(bytes));
    if (xml and
        (containsSensitiveXml(bytes) or
            containsSensitiveAssignment(bytes) or
            (isStorageUserDelegationKeyExchange(context) and
                containsIgnoreCase(bytes, "<UserDelegationKey") and
                containsIgnoreCase(bytes, "<Value"))))
    {
        return error.SensitiveBodyRequiresSanitization;
    }

    if (!valid_text or
        std.mem.indexOfScalar(u8, bytes, 0) != null or
        declaresWideCharset(content_type) or
        !isSupportedTextContentType(content_type) or
        !identity_encoding)
    {
        if (!allow_opaque) return error.OpaqueBodyNotAllowed;
        return;
    }

    if (xml or json) return;
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

fn containsSensitiveMultipartContent(
    allocator: std.mem.Allocator,
    content_type: []const u8,
    body: []const u8,
    depth: usize,
) anyerror!bool {
    if (depth >= 8) return error.UnsupportedBodySanitization;
    if (containsSensitiveMultipartField(body)) return true;
    if (try containsSensitiveHttpHeaderLine(allocator, body)) return true;

    const boundary = try multipartBoundary(content_type);
    const delimiter = try std.fmt.allocPrint(allocator, "--{s}", .{boundary});
    defer allocator.free(delimiter);
    const first = try findMultipartBoundaryLine(body, delimiter, 0) orelse
        return error.UnsupportedBodySanitization;
    if (first.closing) return error.UnsupportedBodySanitization;
    if (try containsSensitiveLoosePayload(
        allocator,
        body[0..first.start],
    )) return true;

    var part_start = first.after;
    var saw_part = false;
    while (true) {
        const next = try findMultipartBoundaryLine(
            body,
            delimiter,
            part_start,
        ) orelse return error.UnsupportedBodySanitization;
        const part = std.mem.trim(
            u8,
            body[part_start..next.start],
            " \t\r\n",
        );
        if (part.len == 0) return error.UnsupportedBodySanitization;
        saw_part = true;
        if (try containsSensitiveMultipartPart(
            allocator,
            part,
            depth,
        )) return true;
        if (next.closing) {
            const epilogue = body[next.after..];
            if (try findMultipartBoundaryLine(
                epilogue,
                delimiter,
                0,
            ) != null) return error.UnsupportedBodySanitization;
            if (try containsSensitiveLoosePayload(
                allocator,
                epilogue,
            )) return true;
            break;
        }
        part_start = next.after;
    }
    if (!saw_part) return error.UnsupportedBodySanitization;
    return false;
}

fn containsSensitiveMultipartPart(
    allocator: std.mem.Allocator,
    part: []const u8,
    depth: usize,
) anyerror!bool {
    const outer_separator = findHeaderSeparator(part) orelse
        return error.UnsupportedBodySanitization;
    const outer_headers = part[0..outer_separator.start];
    var payload = part[outer_separator.end..];
    var payload_content_type = headerValueFromBlock(
        outer_headers,
        "Content-Type",
    );
    if (looksLikeHttpMessage(payload)) {
        const inner_separator = findHeaderSeparator(payload) orelse
            return error.UnsupportedBodySanitization;
        const inner_headers = payload[0..inner_separator.start];
        payload_content_type = headerValueFromBlock(
            inner_headers,
            "Content-Type",
        );
        payload = payload[inner_separator.end..];
    }
    payload = std.mem.trim(u8, payload, " \t\r\n");
    if (payload.len == 0) return false;
    if (payload_content_type) |part_type| {
        if (containsIgnoreCase(part_type, "multipart/")) {
            return containsSensitiveMultipartContent(
                allocator,
                part_type,
                payload,
                depth + 1,
            );
        }
    }
    return containsSensitiveLoosePayload(allocator, payload);
}

fn containsSensitiveLoosePayload(
    allocator: std.mem.Allocator,
    raw_payload: []const u8,
) !bool {
    const payload = std.mem.trim(u8, raw_payload, " \t\r\n");
    if (payload.len == 0) return false;
    if (try containsSensitiveScalar(allocator, payload)) return true;
    if (looksLikeStructuredJson(payload)) {
        const parsed = std.json.parseFromSlice(
            std.json.Value,
            allocator,
            payload,
            .{},
        ) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return error.UnsupportedBodySanitization,
        };
        defer parsed.deinit();
        if (try jsonContainsSensitiveField(allocator, parsed.value))
            return true;
    }
    if (looksLikeXml(payload) and
        (containsSensitiveXml(payload) or
            containsSensitiveAssignment(payload)))
    {
        return true;
    }
    return false;
}

const MultipartBoundaryLine = struct {
    start: usize,
    after: usize,
    closing: bool,
};

fn findMultipartBoundaryLine(
    body: []const u8,
    delimiter: []const u8,
    start: usize,
) !?MultipartBoundaryLine {
    var search_start = start;
    while (std.mem.indexOfPos(u8, body, search_start, delimiter)) |index| {
        if (index != 0 and body[index - 1] != '\n') {
            search_start = index + delimiter.len;
            continue;
        }
        var suffix = index + delimiter.len;
        var closing = false;
        if (std.mem.startsWith(u8, body[suffix..], "--")) {
            closing = true;
            suffix += 2;
        }
        const after = if (suffix == body.len)
            suffix
        else if (std.mem.startsWith(u8, body[suffix..], "\r\n"))
            suffix + 2
        else if (body[suffix] == '\n')
            suffix + 1
        else
            return error.UnsupportedBodySanitization;
        return .{ .start = index, .after = after, .closing = closing };
    }
    return null;
}

fn multipartBoundary(content_type: []const u8) ![]const u8 {
    var parameters = std.mem.splitScalar(u8, content_type, ';');
    const media_type = std.mem.trim(u8, parameters.next() orelse "", " \t");
    if (!std.ascii.startsWithIgnoreCase(media_type, "multipart/"))
        return error.UnsupportedBodySanitization;
    while (parameters.next()) |raw_parameter| {
        const parameter = std.mem.trim(u8, raw_parameter, " \t");
        const equals = std.mem.indexOfScalar(u8, parameter, '=') orelse
            continue;
        const name = std.mem.trim(u8, parameter[0..equals], " \t");
        if (!std.ascii.eqlIgnoreCase(name, "boundary")) continue;
        const raw_value = std.mem.trim(
            u8,
            parameter[equals + 1 ..],
            " \t",
        );
        var boundary = raw_value;
        if (raw_value.len != 0 and
            (raw_value[0] == '"' or raw_value[0] == '\''))
        {
            if (raw_value.len < 2 or
                raw_value[raw_value.len - 1] != raw_value[0])
            {
                return error.UnsupportedBodySanitization;
            }
            boundary = raw_value[1 .. raw_value.len - 1];
        } else if (std.mem.indexOfAny(u8, raw_value, "\"'") != null) {
            return error.UnsupportedBodySanitization;
        }
        if (boundary.len == 0 or boundary.len > 70)
            return error.UnsupportedBodySanitization;
        for (boundary) |byte| {
            if (byte <= 0x20 or byte >= 0x7f)
                return error.UnsupportedBodySanitization;
        }
        return boundary;
    }
    return error.UnsupportedBodySanitization;
}

fn headerValueFromBlock(
    headers: []const u8,
    expected_name: []const u8,
) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, headers, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const name = std.mem.trim(u8, line[0..colon], " \t");
        if (std.ascii.eqlIgnoreCase(name, expected_name))
            return std.mem.trim(u8, line[colon + 1 ..], " \t");
    }
    return null;
}

fn containsSensitiveHttpHeaderLine(
    allocator: std.mem.Allocator,
    body: []const u8,
) !bool {
    var lines = std.mem.splitScalar(u8, body, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const name = std.mem.trim(u8, line[0..colon], " \t");
        if (name.len == 0 or std.mem.indexOfScalar(u8, name, ' ') != null)
            continue;
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (isSensitiveHeader(name) or
            try containsSensitiveScalar(allocator, value))
        {
            return true;
        }
    }
    return false;
}

const HeaderSeparator = struct {
    start: usize,
    end: usize,
};

fn findHeaderSeparator(bytes: []const u8) ?HeaderSeparator {
    if (std.mem.indexOf(u8, bytes, "\r\n\r\n")) |index|
        return .{ .start = index, .end = index + 4 };
    if (std.mem.indexOf(u8, bytes, "\n\n")) |index|
        return .{ .start = index, .end = index + 2 };
    return null;
}

fn looksLikeHttpMessage(bytes: []const u8) bool {
    const trimmed = std.mem.trimStart(u8, bytes, " \t\r\n");
    const line_end = std.mem.indexOfAny(u8, trimmed, "\r\n") orelse
        trimmed.len;
    const first_line = trimmed[0..line_end];
    return std.ascii.startsWithIgnoreCase(first_line, "HTTP/") or
        std.mem.indexOf(u8, first_line, " HTTP/") != null;
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
            (jsonRootHasField(value, "value") or
                jsonContainsJwkPrivateField(value)))
        {
            return true;
        }
    }
    if (isKustoHost(target.host) and
        jsonContainsField(value, "sourceuri"))
    {
        return true;
    }
    if (isAzureManagementHost(target.host) and
        isAzureKeyManagementPath(target.path) and
        (jsonRootHasField(value, "key1") or
            jsonRootHasField(value, "key2")))
    {
        return true;
    }
    if (isAzureManagementHost(target.host) and
        pathHasResource(target.path, "Microsoft.DocumentDB") and
        (pathHasResource(target.path, "listKeys") or
            pathHasResource(target.path, "listReadOnlyKeys")) and
        (jsonContainsField(value, "primarymasterkey") or
            jsonContainsField(value, "secondarymasterkey") or
            jsonContainsField(value, "primaryreadonlymasterkey") or
            jsonContainsField(value, "secondaryreadonlymasterkey")))
    {
        return true;
    }
    if (isAzureManagementHost(target.host) and
        pathHasResource(target.path, "Microsoft.ContainerRegistry") and
        pathHasResource(target.path, "listCredentials") and
        jsonContainsField(value, "passwords"))
    {
        return true;
    }
    if (isAzureManagementHost(target.host) and
        pathHasResource(target.path, "Microsoft.Batch") and
        pathHasResource(target.path, "listKeys") and
        (jsonRootHasField(value, "primary") or
            jsonRootHasField(value, "secondary")))
    {
        return true;
    }
    if (isAzureManagementHost(target.host) and
        pathHasResource(target.path, "Microsoft.Search") and
        pathHasResource(target.path, "listQueryKeys") and
        jsonContainsField(value, "key"))
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

fn isAzureManagementHost(host: []const u8) bool {
    return std.ascii.eqlIgnoreCase(host, "management.azure.com") or
        std.ascii.eqlIgnoreCase(host, "management.usgovcloudapi.net") or
        std.ascii.eqlIgnoreCase(host, "management.chinacloudapi.cn") or
        std.ascii.eqlIgnoreCase(host, "management.microsoftazure.de");
}

fn isStorageBlobHost(host: []const u8) bool {
    return hostMatches(host, "blob.core.windows.net") or
        hostMatches(host, "blob.core.usgovcloudapi.net") or
        hostMatches(host, "blob.core.chinacloudapi.cn") or
        hostMatches(host, "blob.core.cloudapi.de");
}

fn isStorageUserDelegationKeyExchange(context: BodySafetyContext) bool {
    if (context.direction != .response) return false;
    const target = parseUrlTarget(context.url) orelse return false;
    if (!isStorageBlobHost(target.host)) return false;
    const query_start = std.mem.indexOfScalar(u8, context.url, '?') orelse
        return false;
    const fragment_start = std.mem.indexOfPos(
        u8,
        context.url,
        query_start,
        "#",
    ) orelse context.url.len;
    var fields = std.mem.splitScalar(
        u8,
        context.url[query_start + 1 .. fragment_start],
        '&',
    );
    while (fields.next()) |field| {
        const equals = std.mem.indexOfScalar(u8, field, '=') orelse continue;
        if (std.ascii.eqlIgnoreCase(field[0..equals], "comp") and
            std.ascii.eqlIgnoreCase(field[equals + 1 ..], "userdelegationkey"))
        {
            return true;
        }
    }
    return false;
}

fn isAzureKeyManagementPath(path: []const u8) bool {
    const recognized_provider =
        pathHasResource(path, "Microsoft.EventGrid") or
        pathHasResource(path, "Microsoft.CognitiveServices");
    const recognized_action =
        pathHasResource(path, "listKeys") or
        pathHasResource(path, "regenerateKey") or
        pathHasResource(path, "regenerateKeys");
    return recognized_provider and recognized_action;
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

fn isSupportedTextContentType(content_type: []const u8) bool {
    const trimmed = std.mem.trim(u8, content_type, " \t");
    if (trimmed.len == 0) return true;
    return std.ascii.startsWithIgnoreCase(trimmed, "text/") or
        isJsonContentType(trimmed) or
        containsIgnoreCase(trimmed, "/xml") or
        containsIgnoreCase(trimmed, "+xml") or
        std.ascii.startsWithIgnoreCase(
            trimmed,
            "application/x-www-form-urlencoded",
        ) or
        std.ascii.startsWithIgnoreCase(trimmed, "application/javascript") or
        std.ascii.startsWithIgnoreCase(trimmed, "application/ecmascript") or
        std.ascii.startsWithIgnoreCase(trimmed, "application/graphql");
}

fn jsonContainsSensitiveField(
    allocator: std.mem.Allocator,
    value: std.json.Value,
) !bool {
    return jsonContainsSensitiveFieldInContext(allocator, value, false);
}

fn jsonContainsSensitiveFieldInContext(
    allocator: std.mem.Allocator,
    value: std.json.Value,
    sensitive_container: bool,
) !bool {
    switch (value) {
        .object => |object| {
            var iterator = object.iterator();
            while (iterator.next()) |entry| {
                if (isSensitiveBodyField(entry.key_ptr.*) or
                    (sensitive_container and
                        normalizedFieldEquals(entry.key_ptr.*, "value")) or
                    try jsonContainsSensitiveFieldInContext(
                        allocator,
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
                if (try jsonContainsSensitiveFieldInContext(
                    allocator,
                    item,
                    sensitive_container,
                )) return true;
            }
        },
        .string => |string| return containsSensitiveScalar(allocator, string),
        else => {},
    }
    return false;
}

fn containsSensitiveScalar(
    allocator: std.mem.Allocator,
    value: []const u8,
) !bool {
    return containsPrivateKeyMarker(value) or
        containsSensitiveAssignment(value) or
        containsSasCredential(value) or
        containsIgnoreCase(value, "Bearer ") or
        containsIgnoreCase(value, "SharedKey ") or
        containsIgnoreCase(value, "SharedKeyLite ") or
        try containsJwtToken(allocator, value);
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

fn looksLikeJwt(
    allocator: std.mem.Allocator,
    value: []const u8,
) !bool {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    var segments = std.mem.splitScalar(u8, trimmed, '.');
    const encoded_header = segments.next() orelse return false;
    const encoded_payload = segments.next() orelse return false;
    const encoded_signature = segments.next() orelse return false;
    if (segments.next() != null or
        encoded_header.len == 0 or
        encoded_payload.len == 0 or
        encoded_signature.len < 16)
    {
        return false;
    }

    const signature = decodeJwtSegment(
        allocator,
        encoded_signature,
    ) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    defer allocator.free(signature);
    if (signature.len < 12) return false;

    const header = decodeJwtSegment(allocator, encoded_header) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    defer allocator.free(header);
    const payload = decodeJwtSegment(allocator, encoded_payload) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    defer allocator.free(payload);
    return try isPlausibleJwtObject(allocator, header, true) and
        try isPlausibleJwtObject(allocator, payload, false);
}

fn containsJwtToken(
    allocator: std.mem.Allocator,
    value: []const u8,
) !bool {
    var tokens = std.mem.tokenizeAny(
        u8,
        value,
        " \t\r\n\"'[](){},;:=<>",
    );
    while (tokens.next()) |token| {
        if (try looksLikeJwt(allocator, token)) return true;
    }
    return false;
}

fn decodeJwtSegment(
    allocator: std.mem.Allocator,
    encoded: []const u8,
) ![]u8 {
    const size = std.base64.url_safe_no_pad.Decoder.calcSizeForSlice(
        encoded,
    ) catch return error.InvalidBase64;
    const decoded = try allocator.alloc(u8, size);
    errdefer allocator.free(decoded);
    std.base64.url_safe_no_pad.Decoder.decode(
        decoded,
        encoded,
    ) catch return error.InvalidBase64;
    return decoded;
}

fn isPlausibleJwtObject(
    allocator: std.mem.Allocator,
    value: []const u8,
    require_alg: bool,
) !bool {
    const trimmed = std.mem.trim(u8, value, " \t\r\n");
    const parsed = std.json.parseFromSlice(
        std.json.Value,
        allocator,
        trimmed,
        .{},
    ) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return false,
    };
    defer parsed.deinit();
    const object = switch (parsed.value) {
        .object => |result| result,
        else => return false,
    };
    if (!require_alg) return true;
    const alg = object.get("alg") orelse return false;
    return switch (alg) {
        .string => |name| name.len != 0,
        else => false,
    };
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
        normalizedFieldEndsWith(name, "masterkey") or
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
        var sanitized_url: ?[]u8 = null;
        defer if (sanitized_url) |url| allocator.free(url);
        var redact = header.redacted;
        if (!redact) switch (decision) {
            .redact => redact = true,
            .preserve => {},
            .inspect => if (isSanitizedUrlHeader(header.name)) {
                sanitized_url = sanitizeUrlAlloc(
                    allocator,
                    header.value,
                ) catch |err| switch (err) {
                    error.SensitiveUrlRequiresSanitization => null,
                    else => return err,
                };
                redact = sanitized_url == null;
            } else {
                redact = try shouldRedactHeader(
                    allocator,
                    direction,
                    header.name,
                    header.value,
                );
            },
        };
        if (redact) {
            try writeJsonString(writer, redacted_value);
        } else if (sanitized_url) |url| {
            try writeJsonString(writer, url);
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
    return sanitizeUrlAllocDepth(allocator, url, 0);
}

const max_url_decode_depth = 3;
const max_nested_url_depth = 4;
const max_sanitized_url_length = 256 * 1024;

fn sanitizeUrlAllocDepth(
    allocator: std.mem.Allocator,
    url: []const u8,
    nesting: usize,
) anyerror![]u8 {
    if (nesting > max_nested_url_depth or
        url.len == 0 or
        url.len > max_sanitized_url_length or
        std.mem.indexOfAny(u8, url, "\x00\r\n") != null)
    {
        return error.SensitiveUrlRequiresSanitization;
    }

    const fragment = std.mem.indexOfScalar(u8, url, '#');
    const reference_end = fragment orelse url.len;
    const question = std.mem.indexOfScalar(u8, url[0..reference_end], '?');
    var path_start: usize = 0;
    const scheme_end_value = schemeEndAtReferenceStart(url, reference_end);
    if (scheme_end_value) |scheme_end| {
        const scheme = url[0..scheme_end];
        if (!std.ascii.eqlIgnoreCase(scheme, "https") and
            !std.ascii.eqlIgnoreCase(scheme, "http"))
        {
            return error.SensitiveUrlRequiresSanitization;
        }
        if (!std.mem.startsWith(u8, url[scheme_end + 1 ..], "//"))
            return error.SensitiveUrlRequiresSanitization;
        const authority_start = scheme_end + 3;
        const slash = std.mem.indexOfScalarPos(
            u8,
            url,
            authority_start,
            '/',
        );
        const authority_end = if (slash) |index|
            @min(index, reference_end)
        else
            reference_end;
        const authority = url[authority_start..authority_end];
        if (authority.len == 0 or
            std.mem.indexOfScalar(u8, authority, '@') != null)
        {
            return error.SensitiveUrlRequiresSanitization;
        }
        path_start = authority_end;
    } else if (std.mem.startsWith(u8, url, "//")) {
        return error.SensitiveUrlRequiresSanitization;
    }

    const query_start = question orelse reference_end;
    if (try encodedComponentIsSensitive(
        allocator,
        url[path_start..query_start],
        false,
        false,
        nesting,
    )) return error.SensitiveUrlRequiresSanitization;
    if (fragment) |fragment_start| {
        if (try encodedComponentIsSensitive(
            allocator,
            url[fragment_start + 1 ..],
            false,
            true,
            nesting,
        )) return error.SensitiveUrlRequiresSanitization;
    }

    if (question == null) return allocator.dupe(u8, url);
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.writeAll(url[0 .. query_start + 1]);
    var first = true;
    var iterator = std.mem.splitScalar(
        u8,
        url[query_start + 1 .. reference_end],
        '&',
    );
    while (iterator.next()) |parameter| {
        if (!first) try output.writer.writeByte('&');
        first = false;
        const equals = std.mem.indexOfScalar(u8, parameter, '=') orelse {
            const decoded = try percentDecodeAlloc(
                allocator,
                parameter,
                true,
            );
            defer allocator.free(decoded);
            if (isSensitiveQueryField(decoded) or
                try encodedComponentIsSensitive(
                    allocator,
                    parameter,
                    true,
                    true,
                    nesting,
                ))
            {
                try output.writer.writeAll(parameter);
                try output.writer.writeAll("=");
                try output.writer.writeAll(redacted_value);
            } else {
                try output.writer.writeAll(parameter);
            }
            continue;
        };
        const encoded_name = parameter[0..equals];
        const encoded_value = parameter[equals + 1 ..];
        const decoded_name = try percentDecodeAlloc(
            allocator,
            encoded_name,
            true,
        );
        defer allocator.free(decoded_name);
        const redact = isSensitiveQueryField(decoded_name) or
            try encodedComponentIsSensitive(
                allocator,
                encoded_value,
                true,
                true,
                nesting,
            );
        try output.writer.writeAll(encoded_name);
        try output.writer.writeByte('=');
        try output.writer.writeAll(if (redact) redacted_value else encoded_value);
    }
    if (fragment) |fragment_start| {
        try output.writer.writeAll(url[fragment_start..]);
    }
    return output.toOwnedSlice();
}

fn encodedComponentIsSensitive(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    plus_as_space: bool,
    inspect_uri: bool,
    nesting: usize,
) anyerror!bool {
    if (encoded.len > max_sanitized_url_length) return true;
    var current = try allocator.dupe(u8, encoded);
    defer allocator.free(current);
    var decode_count: usize = 0;
    while (decode_count < max_url_decode_depth) : (decode_count += 1) {
        const decoded = try percentDecodeAlloc(
            allocator,
            current,
            plus_as_space and decode_count == 0,
        );
        const changed = !std.mem.eql(u8, current, decoded);
        allocator.free(current);
        current = decoded;
        if (try containsSensitiveScalar(allocator, current)) return true;
        if (inspect_uri and looksLikeNestedUriReference(current)) {
            if (nesting >= max_nested_url_depth) return true;
            const sanitized = sanitizeUrlAllocDepth(
                allocator,
                current,
                nesting + 1,
            ) catch |err| switch (err) {
                error.SensitiveUrlRequiresSanitization => return true,
                else => return err,
            };
            defer allocator.free(sanitized);
            if (!std.mem.eql(u8, current, sanitized)) return true;
        }
        if (!changed) return false;
    }
    return containsPercentEscape(current);
}

fn looksLikeNestedUriReference(value: []const u8) bool {
    if (value.len == 0) return false;
    return value[0] == '/' or
        std.mem.indexOfAny(u8, value, "?#") != null or
        schemeEndAtReferenceStart(value, value.len) != null;
}

fn containsPercentEscape(value: []const u8) bool {
    var index: usize = 0;
    while (std.mem.indexOfScalarPos(u8, value, index, '%')) |percent| {
        if (percent + 2 < value.len) {
            _ = std.fmt.charToDigit(value[percent + 1], 16) catch {
                index = percent + 1;
                continue;
            };
            _ = std.fmt.charToDigit(value[percent + 2], 16) catch {
                index = percent + 1;
                continue;
            };
            return true;
        }
        index = percent + 1;
    }
    return false;
}

fn schemeEndAtReferenceStart(url: []const u8, reference_end: usize) ?usize {
    const colon = std.mem.indexOfScalar(u8, url[0..reference_end], ':') orelse
        return null;
    const first_delimiter = std.mem.indexOfAny(u8, url[0..reference_end], "/") orelse
        reference_end;
    if (colon > first_delimiter or colon == 0 or
        !std.ascii.isAlphabetic(url[0]))
    {
        return null;
    }
    for (url[1..colon]) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and
            byte != '+' and byte != '-' and byte != '.')
        {
            return null;
        }
    }
    return colon;
}

fn percentDecodeAlloc(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    plus_as_space: bool,
) ![]u8 {
    const decoded = try allocator.alloc(u8, encoded.len);
    errdefer allocator.free(decoded);
    var input_index: usize = 0;
    var output_index: usize = 0;
    while (input_index < encoded.len) {
        if (encoded[input_index] == '%') {
            if (input_index + 2 >= encoded.len)
                return error.SensitiveUrlRequiresSanitization;
            const high = std.fmt.charToDigit(
                encoded[input_index + 1],
                16,
            ) catch return error.SensitiveUrlRequiresSanitization;
            const low = std.fmt.charToDigit(
                encoded[input_index + 2],
                16,
            ) catch return error.SensitiveUrlRequiresSanitization;
            decoded[output_index] = high * 16 + low;
            input_index += 3;
        } else {
            decoded[output_index] = if (plus_as_space and
                encoded[input_index] == '+')
                ' '
            else
                encoded[input_index];
            input_index += 1;
        }
        output_index += 1;
    }
    return allocator.realloc(decoded, output_index);
}

fn isSensitiveQueryField(name: []const u8) bool {
    var decoded_buffer: [256]u8 = undefined;
    const candidate = percentDecodeFieldName(name, &decoded_buffer) orelse
        name;
    for (sensitive_query_fields) |sensitive| {
        if (std.ascii.eqlIgnoreCase(candidate, sensitive)) return true;
    }
    return isSensitiveBodyField(candidate);
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

fn inspectKnownSafeBody(
    _: ?*anyopaque,
    _: BodySafetyContext,
) BodyPolicyDecision {
    return .inspect;
}

fn allowOpaqueBody(
    _: ?*anyopaque,
    _: BodySafetyContext,
) BodyPolicyDecision {
    return .allow_opaque;
}

fn preserveKnownSafeMetadata(
    _: ?*anyopaque,
    header: HeaderSafetyContext,
) HeaderPolicyDecision {
    if (std.ascii.eqlIgnoreCase(header.name, "x-ms-meta-pwd"))
        return .preserve;
    if (std.ascii.eqlIgnoreCase(header.name, "x-stable"))
        return .preserve;
    if (std.ascii.eqlIgnoreCase(header.name, "x-application-auth-material"))
        return .redact;
    return .inspect;
}

fn preserveRequestDate(
    _: ?*anyopaque,
    header: HeaderSafetyContext,
) HeaderPolicyDecision {
    return if (std.ascii.eqlIgnoreCase(header.name, "x-ms-date"))
        .preserve
    else
        .inspect;
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
    try std.testing.expectEqual(@as(usize, 0), playback.index);
    var abort_retry = try playback.asTransport().open(&abort_request, .{});
    try abort_retry.finish();
    abort_retry.deinit();

    var cancel_request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com/cancel",
    );
    defer cancel_request.deinit();
    var cancelled = try playback.asTransport().open(&cancel_request, .{});
    cancelled.cancel();
    cancelled.deinit();
    try std.testing.expectEqual(@as(usize, 1), playback.index);
    var cancel_retry = try playback.asTransport().open(&cancel_request, .{});
    try cancel_retry.finish();
    cancel_retry.deinit();
    try std.testing.expectEqual(@as(usize, 1), playback.abort_count);
    try std.testing.expectEqual(@as(usize, 1), playback.cancel_count);
    try std.testing.expectEqual(@as(usize, 2), playback.finish_count);
    try std.testing.expectEqual(@as(usize, 4), playback.deinit_count);
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

test "playback allocation failures do not consume buffered exchanges" {
    const recordings = [_]RecordedExchange{.{
        .request_method = .GET,
        .request_url = "https://example.test/retry",
        .response_status = 200,
        .response_body = "response",
        .response_headers = &.{
            .{ .name = "Content-Type", .value = "text/plain" },
        },
    }};
    var no_memory: [0]u8 = .{};
    var fixed = std.heap.FixedBufferAllocator.init(&no_memory);
    var playback = PlaybackTransport.init(fixed.allocator(), &recordings);
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.test/retry",
    );
    defer request.deinit();
    try std.testing.expectError(
        error.OutOfMemory,
        playback.asTransport().send(&request),
    );
    try std.testing.expectEqual(@as(usize, 0), playback.index);

    playback.allocator = std.testing.allocator;
    var response = try playback.asTransport().send(&request);
    defer response.deinit();
    try std.testing.expectEqualStrings("response", response.body);
    try std.testing.expectEqual(@as(usize, 1), playback.index);
}

test "playback allocation failures do not consume streaming exchanges" {
    const recordings = [_]RecordedExchange{.{
        .request_method = .GET,
        .request_url = "https://example.test/retry-stream",
        .response_status = 200,
        .response_body = "stream-response",
    }};
    var no_memory: [0]u8 = .{};
    var fixed = std.heap.FixedBufferAllocator.init(&no_memory);
    var playback = PlaybackTransport.init(fixed.allocator(), &recordings);
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.test/retry-stream",
    );
    defer request.deinit();
    try std.testing.expectError(
        error.OutOfMemory,
        playback.asTransport().open(&request, .{}),
    );
    try std.testing.expectEqual(@as(usize, 0), playback.index);
    try std.testing.expectEqual(@as(usize, 0), playback.open_count);

    playback.allocator = std.testing.allocator;
    var operation = try playback.asTransport().open(&request, .{});
    defer operation.deinit();
    const body = try (try operation.reader()).allocRemaining(
        std.testing.allocator,
        .unlimited,
    );
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("stream-response", body);
    try operation.finish();
    try std.testing.expectEqual(@as(usize, 1), playback.index);
    try std.testing.expectEqual(@as(usize, 1), playback.open_count);
}

test "Core buffered redirect allocation failure leaves playback retryable" {
    const recordings = [_]RecordedExchange{
        .{
            .request_method = .GET,
            .request_url = "https://example.test/start",
            .response_status = 302,
            .response_body = "",
            .response_headers = &.{
                .{ .name = "Location", .value = "/final" },
            },
        },
        .{
            .request_method = .GET,
            .request_url = "https://example.test/final",
            .response_status = 200,
            .response_body = "done",
        },
    };
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        &recordings,
    );
    var failing = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 0 },
    );
    var request = core.http.Request.init(
        failing.allocator(),
        .GET,
        "https://example.test/start",
    );
    defer request.deinit();
    try std.testing.expectError(
        error.OutOfMemory,
        playback.asTransport().send(&request),
    );
    try std.testing.expectEqual(@as(usize, 0), playback.index);
    try std.testing.expectEqual(@as(?usize, 0), playback.pending_redirect);

    failing.fail_index = std.math.maxInt(usize);
    var response = try playback.asTransport().send(&request);
    defer response.deinit();
    try std.testing.expectEqualStrings("done", response.body);
    try std.testing.expectEqual(@as(usize, 2), playback.index);
    try std.testing.expectEqual(@as(?usize, null), playback.pending_redirect);
}

test "Core streaming redirect allocation failure leaves playback retryable" {
    const recordings = [_]RecordedExchange{
        .{
            .request_method = .GET,
            .request_url = "https://example.test/start-stream",
            .response_status = 302,
            .response_body = "",
            .response_headers = &.{
                .{ .name = "Location", .value = "/final-stream" },
            },
        },
        .{
            .request_method = .GET,
            .request_url = "https://example.test/final-stream",
            .response_status = 200,
            .response_body = "stream-done",
        },
    };
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        &recordings,
    );
    var failing = std.testing.FailingAllocator.init(
        std.testing.allocator,
        .{ .fail_index = 0 },
    );
    var request = core.http.Request.init(
        failing.allocator(),
        .GET,
        "https://example.test/start-stream",
    );
    defer request.deinit();
    try std.testing.expectError(
        error.OutOfMemory,
        playback.asTransport().open(&request, .{}),
    );
    try std.testing.expectEqual(@as(usize, 0), playback.index);
    try std.testing.expectEqual(@as(?usize, 0), playback.pending_redirect);
    try std.testing.expectEqual(@as(usize, 1), playback.abort_count);

    failing.fail_index = std.math.maxInt(usize);
    var operation = try playback.asTransport().open(&request, .{});
    defer operation.deinit();
    const body = try (try operation.reader()).allocRemaining(
        std.testing.allocator,
        .unlimited,
    );
    defer std.testing.allocator.free(body);
    try std.testing.expectEqualStrings("stream-done", body);
    try operation.finish();
    try std.testing.expectEqual(@as(usize, 2), playback.index);
    try std.testing.expectEqual(@as(?usize, null), playback.pending_redirect);
}

test "every Core redirect-chain request allocation failure rolls back playback" {
    const recordings = [_]RecordedExchange{
        .{
            .request_method = .GET,
            .request_url = "https://example.test/start-chain",
            .response_status = 302,
            .response_body = "",
            .response_headers = &.{
                .{ .name = "Location", .value = "/middle-chain" },
            },
        },
        .{
            .request_method = .GET,
            .request_url = "https://example.test/middle-chain",
            .response_status = 307,
            .response_body = "",
            .response_headers = &.{
                .{ .name = "Location", .value = "/final-chain" },
            },
        },
        .{
            .request_method = .GET,
            .request_url = "https://example.test/final-chain",
            .response_status = 200,
            .response_body = "complete",
        },
    };
    var saw_later_redirect_failure = false;
    for (0..64) |fail_index| {
        var playback = PlaybackTransport.init(
            std.testing.allocator,
            &recordings,
        );
        var failing = std.testing.FailingAllocator.init(
            std.testing.allocator,
            .{ .fail_index = fail_index },
        );
        var request = core.http.Request.init(
            failing.allocator(),
            .GET,
            "https://example.test/start-chain",
        );
        defer request.deinit();
        const transport = playback.asTransport();
        if (transport.send(&request)) |response_value| {
            var response = response_value;
            response.deinit();
            break;
        } else |err| {
            if (err != error.OutOfMemory and err != error.WriteFailed)
                return err;
            saw_later_redirect_failure = saw_later_redirect_failure or
                playback.pending_redirect == 1;
            try std.testing.expectEqual(@as(usize, 0), playback.index);
            failing.fail_index = std.math.maxInt(usize);
            var retry = try transport.send(&request);
            defer retry.deinit();
            try std.testing.expectEqualStrings("complete", retry.body);
            try std.testing.expectEqual(@as(usize, 3), playback.index);
        }
    }
    try std.testing.expect(saw_later_redirect_failure);
}

test "every Core streaming redirect-chain allocation failure rolls back playback" {
    const recordings = [_]RecordedExchange{
        .{
            .request_method = .GET,
            .request_url = "https://example.test/start-open-chain",
            .response_status = 302,
            .response_body = "",
            .response_headers = &.{
                .{ .name = "Location", .value = "/middle-open-chain" },
            },
        },
        .{
            .request_method = .GET,
            .request_url = "https://example.test/middle-open-chain",
            .response_status = 307,
            .response_body = "",
            .response_headers = &.{
                .{ .name = "Location", .value = "/final-open-chain" },
            },
        },
        .{
            .request_method = .GET,
            .request_url = "https://example.test/final-open-chain",
            .response_status = 200,
            .response_body = "complete",
        },
    };
    var saw_later_redirect_failure = false;
    for (0..64) |fail_index| {
        var playback = PlaybackTransport.init(
            std.testing.allocator,
            &recordings,
        );
        var failing = std.testing.FailingAllocator.init(
            std.testing.allocator,
            .{ .fail_index = fail_index },
        );
        var request = core.http.Request.init(
            failing.allocator(),
            .GET,
            "https://example.test/start-open-chain",
        );
        defer request.deinit();
        const transport = playback.asTransport();
        if (transport.open(&request, .{})) |operation_value| {
            var operation = operation_value;
            try operation.finish();
            operation.deinit();
            break;
        } else |err| {
            if (err != error.OutOfMemory and err != error.WriteFailed)
                return err;
            saw_later_redirect_failure = saw_later_redirect_failure or
                playback.pending_redirect == 1;
            try std.testing.expectEqual(@as(usize, 0), playback.index);
            failing.fail_index = std.math.maxInt(usize);
            var retry = try transport.open(&request, .{});
            try retry.finish();
            retry.deinit();
            try std.testing.expectEqual(@as(usize, 3), playback.index);
        }
    }
    try std.testing.expect(saw_later_redirect_failure);
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
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
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
    const jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" ++
        "." ++
        "eyJzdWIiOiJoZWFkZXIiLCJleHAiOjQxMDI0NDQ4MDB9" ++
        "." ++
        "c2lnbmF0dXJlLWJ5dGVzLXZhbHVl";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "response",
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "X-MS-META-PASSWORD", .value = "response-password-value" },
        .{ .name = "x-ms-meta-private-key", .value = "cmVzcG9uc2Uta2V5" },
        .{
            .name = "x-ms-meta-source-uri",
            .value = "https://storage.example/blob?sig=response-source-sas",
        },
        .{ .name = "ETag", .value = jwt },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{
            .bodyPolicyFn = &inspectKnownSafeBody,
            .headerPolicyFn = &preserveKnownSafeMetadata,
        },
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
        "x-ms-meta-source-uri",
        "https://storage.example/blob?sig=request-source-sas",
    );
    try request.setHeader("x-ms-meta-label", "unknown-metadata-value");
    try request.setHeader("ETag", jwt);
    try request.setHeader(
        "Content-Language",
        "Endpoint=https://example;AccountKey=header-account-key",
    );
    try request.setHeader("User-Agent", "service.production.contoso");
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
        "response-source-sas",
        "request-source-sas",
        "unknown-metadata-value",
        "header-account-key",
        jwt,
    }) |secret| {
        try std.testing.expect(std.mem.indexOf(u8, json, secret) == null);
    }
    try std.testing.expect(
        std.mem.indexOf(u8, json, "known-safe-label") != null,
    );

    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    for (parsed.asSlice()[0].request_headers) |header| {
        if (header.redacted) {
            try std.testing.expectEqualStrings(redacted_value, header.value);
        } else {
            try std.testing.expect(
                std.mem.eql(u8, header.value, "known-safe-label") or
                    std.mem.eql(
                        u8,
                        header.value,
                        "service.production.contoso",
                    ),
            );
        }
    }
    for (parsed.asSlice()[0].response_headers) |header| {
        try std.testing.expect(header.redacted);
        try std.testing.expectEqualStrings(redacted_value, header.value);
    }
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
    try live.setHeader(
        "x-ms-meta-source-uri",
        "https://storage.example/blob?sig=rotated-source-sas",
    );
    try live.setHeader("x-ms-meta-label", "rotated-metadata");
    try live.setHeader("ETag", "rotated-jwt");
    try live.setHeader(
        "Content-Language",
        "Endpoint=https://example;AccountKey=rotated-account-key",
    );
    try live.setHeader("User-Agent", "service.production.contoso");
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

test "Core request ID pipeline replays with changed volatile headers" {
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "",
    );
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var recording_crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var recording_request_id = core.http.RequestIdPolicy.init();
    var recording_policies = [_]*core.http.HttpPolicy{
        recording_request_id.asPolicy(),
    };
    var recording_pipeline = core.http.HttpPipeline.init(
        initHttpRuntime(
            recorder.asTransport(),
            recording_crypto.asProvider(),
        ),
        &recording_policies,
    );
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.test/volatile",
    );
    defer request.deinit();
    try request.setHeader("x-ms-date", "Sat, 29 Aug 2026 05:00:00 GMT");
    try request.setHeader("Date", "Sat, 29 Aug 2026 05:00:00 GMT");
    try request.setHeader(
        "traceparent",
        "00-11111111111111111111111111111111-2222222222222222-01",
    );
    try request.setHeader("tracestate", "vendor=first");
    try request.setHeader("x-correlation-id", "first-correlation");
    var response = try recording_pipeline.send(&request);
    response.deinit();
    const recorded_id = try std.testing.allocator.dupe(
        u8,
        request.getHeader("x-ms-client-request-id").?,
    );
    defer std.testing.allocator.free(recorded_id);

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    for (parsed.asSlice()[0].request_headers) |header| {
        try std.testing.expect(header.redacted);
        try std.testing.expectEqualStrings(redacted_value, header.value);
    }

    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var playback_crypto = core.crypto.StdCryptoProvider.init(std.testing.io);
    var playback_request_id = core.http.RequestIdPolicy.init();
    var playback_policies = [_]*core.http.HttpPolicy{
        playback_request_id.asPolicy(),
    };
    var playback_pipeline = core.http.HttpPipeline.init(
        initHttpRuntime(
            playback.asTransport(),
            playback_crypto.asProvider(),
        ),
        &playback_policies,
    );
    var live = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.test/volatile",
    );
    defer live.deinit();
    try live.setHeader("x-ms-date", "Sat, 29 Aug 2026 06:00:00 GMT");
    try live.setHeader("Date", "Sat, 29 Aug 2026 06:00:00 GMT");
    try live.setHeader(
        "traceparent",
        "00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-01",
    );
    try live.setHeader("tracestate", "vendor=second");
    try live.setHeader("x-correlation-id", "second-correlation");
    var replayed = try playback_pipeline.send(&live);
    replayed.deinit();
    try std.testing.expect(!std.mem.eql(
        u8,
        recorded_id,
        live.getHeader("x-ms-client-request-id").?,
    ));

    var exact_mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "",
    );
    defer exact_mock.deinit();
    var exact_recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        exact_mock.asTransport(),
        .{ .headerPolicyFn = &preserveRequestDate },
    );
    defer exact_recorder.deinit();
    var exact_request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.test/exact-date",
    );
    defer exact_request.deinit();
    try exact_request.setHeader(
        "x-ms-date",
        "Sat, 29 Aug 2026 05:00:00 GMT",
    );
    var exact_response = try exact_recorder.asTransport().send(&exact_request);
    exact_response.deinit();
    const exact_json = try exact_recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(exact_json);
    var exact_parsed = try parseJson(std.testing.allocator, exact_json);
    defer exact_parsed.deinit();
    var exact_playback = PlaybackTransport.init(
        std.testing.allocator,
        exact_parsed.asSlice(),
    );
    try exact_request.setHeader(
        "x-ms-date",
        "Sat, 29 Aug 2026 06:00:00 GMT",
    );
    try std.testing.expectError(
        error.HeaderMismatch,
        exact_playback.asTransport().send(&exact_request),
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
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
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
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
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
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
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

test "URL sanitization inspects decoded query path and fragment components" {
    const recorded_jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" ++
        "." ++
        "eyJzdWIiOiJyZWNvcmRlZCIsImV4cCI6NDEwMjQ0NDgwMH0" ++
        "." ++
        "c2lnbmF0dXJlLWJ5dGVzLXZhbHVl";
    const live_jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" ++
        "." ++
        "eyJzdWIiOiJsaXZlIiwiZXhwIjo0MTAyNDQ0ODAwfQ" ++
        "." ++
        "cm90YXRlZC1zaWduYXR1cmUtdmFsdWU";
    const recorded_url = try std.fmt.allocPrint(
        std.testing.allocator,
        "https://example.test/callback?token={s}&payload=Endpoint%3Dhttps%3A%2F%2Fexample%3BAccountKey%3Dquery-key&return=https%3A%2F%2Fsafe.example%2Fnext",
        .{recorded_jwt},
    );
    defer std.testing.allocator.free(recorded_url);
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "",
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
        recorded_url,
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, recorded_jwt) == null);
    try std.testing.expect(std.mem.indexOf(u8, json, "query-key") == null);
    try std.testing.expect(
        std.mem.indexOf(u8, json, "token=REDACTED") != null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, json, "payload=REDACTED") != null,
    );
    try std.testing.expect(
        std.mem.indexOf(
            u8,
            json,
            "return=https%3A%2F%2Fsafe.example%2Fnext",
        ) != null,
    );

    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    const live_url = try std.fmt.allocPrint(
        std.testing.allocator,
        "https://example.test/callback?token={s}&payload=Endpoint%3Dhttps%3A%2F%2Fexample%3BAccountKey%3Drotated-key&return=https%3A%2F%2Fsafe.example%2Fnext",
        .{live_jwt},
    );
    defer std.testing.allocator.free(live_url);
    var live = core.http.Request.init(
        std.testing.allocator,
        .GET,
        live_url,
    );
    defer live.deinit();
    var replayed = try playback.asTransport().send(&live);
    replayed.deinit();

    for ([_][]const u8{
        "https://example.test/callback/Bearer%20path-secret",
        "https://example.test/callback#access_token=fragment-secret",
    }) |unsafe_url| {
        var unsafe_mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "",
        );
        defer unsafe_mock.deinit();
        var unsafe_recorder = RecordingTransport.init(
            std.testing.allocator,
            unsafe_mock.asTransport(),
        );
        defer unsafe_recorder.deinit();
        var unsafe_request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            unsafe_url,
        );
        defer unsafe_request.deinit();
        var unsafe_response =
            try unsafe_recorder.asTransport().send(&unsafe_request);
        unsafe_response.deinit();
        try expectRejectedSerializationExcludes(
            &unsafe_recorder,
            error.SensitiveUrlRequiresSanitization,
            &.{ "path-secret", "fragment-secret" },
        );
    }
}

test "URL sanitization recursively decodes nested URI credentials" {
    const recorded_url =
        "https://example.test/callback?return=" ++
        "https%253A%252F%252Fstorage.example%252Fblob%253F" ++
        "%252573%252569%252567%253Dnested-sas-secret&stable=one";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "",
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
        recorded_url,
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    try std.testing.expect(
        std.mem.indexOf(u8, json, "nested-sas-secret") == null,
    );
    try std.testing.expect(
        std.mem.indexOf(u8, json, "return=REDACTED") != null,
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
        "https://example.test/callback?return=" ++
            "https%253A%252F%252Fstorage.example%252Fblob%253F" ++
            "%252573%252569%252567%253Drotated-sas-secret&stable=one",
    );
    defer live.deinit();
    var replayed = try playback.asTransport().send(&live);
    replayed.deinit();

    for ([_][]const u8{
        "https://example.test/callback?return=%ZZ",
        "https://example.test/callback?return=%2525252573%2525252569%2525252567%253Ddecode-depth-secret",
    }) |unsafe_url| {
        var unsafe_mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "",
        );
        defer unsafe_mock.deinit();
        var unsafe_recorder = RecordingTransport.init(
            std.testing.allocator,
            unsafe_mock.asTransport(),
        );
        defer unsafe_recorder.deinit();
        var unsafe_request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            unsafe_url,
        );
        defer unsafe_request.deinit();
        var unsafe_response =
            try unsafe_recorder.asTransport().send(&unsafe_request);
        unsafe_response.deinit();
        if (std.mem.indexOf(u8, unsafe_url, "%ZZ") != null) {
            try std.testing.expectError(
                error.SensitiveUrlRequiresSanitization,
                unsafe_recorder.toJson(std.testing.allocator),
            );
        } else {
            const unsafe_json =
                try unsafe_recorder.toJson(std.testing.allocator);
            defer std.testing.allocator.free(unsafe_json);
            try std.testing.expect(
                std.mem.indexOf(u8, unsafe_json, "decode-depth-secret") ==
                    null,
            );
            try std.testing.expect(
                std.mem.indexOf(u8, unsafe_json, "return=REDACTED") != null,
            );
        }
    }
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
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{
            .bodyPolicyFn = &inspectKnownSafeBody,
            .headerPolicyFn = &preserveKnownSafeMetadata,
        },
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

test "location headers preserve replayable URLs and rotated SAS next exchanges" {
    var sequence = core.http.SequenceMockTransport.init(
        std.testing.allocator,
        &.{
            .{
                .status = 302,
                .body = "",
                .headers = &.{
                    .{
                        .name = "Location",
                        .value = "https://example.test/final?sig=first-location-sas&mode=one",
                    },
                    .{
                        .name = "Content-Location",
                        .value = "/content/item?%73ig=content-sas&view=full",
                    },
                    .{
                        .name = "Operation-Location",
                        .value = "https://user:userinfo-secret@example.test/unsafe",
                    },
                },
            },
            .{
                .status = 202,
                .body = "",
                .headers = &.{
                    .{
                        .name = "Operation-Location",
                        .value = "https://example.test/operations/1?sig=operation-sas&api-version=1",
                    },
                    .{
                        .name = "Azure-AsyncOperation",
                        .value = "/operations/1/status?sig=async-sas&api-version=1",
                    },
                    .{
                        .name = "Content-Location",
                        .value = "/callback?return=https://safe.example/next&mode=one",
                    },
                },
            },
            .{ .status = 200, .body = "" },
        },
    );
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        sequence.asTransport(),
    );
    defer recorder.deinit();
    for ([_][]const u8{
        "https://example.test/start",
        "https://example.test/final?sig=first-location-sas&mode=one",
        "https://example.test/operations/1?sig=operation-sas&api-version=1",
    }) |url| {
        var request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            url,
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
    }

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    for ([_][]const u8{
        "first-location-sas",
        "content-sas",
        "operation-sas",
        "async-sas",
        "userinfo-secret",
    }) |secret| {
        try std.testing.expect(std.mem.indexOf(u8, json, secret) == null);
    }
    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    const recordings = parsed.asSlice();
    try std.testing.expectEqualStrings(
        "https://example.test/final?sig=REDACTED&mode=one",
        getHeaderPair(recordings[0].response_headers, "Location").?,
    );
    try std.testing.expectEqualStrings(
        "/content/item?%73ig=REDACTED&view=full",
        getHeaderPair(recordings[0].response_headers, "Content-Location").?,
    );
    try std.testing.expectEqualStrings(
        redacted_value,
        getHeaderPair(recordings[0].response_headers, "Operation-Location").?,
    );
    try std.testing.expectEqualStrings(
        "https://example.test/operations/1?sig=REDACTED&api-version=1",
        getHeaderPair(
            recordings[1].response_headers,
            "Operation-Location",
        ).?,
    );
    try std.testing.expectEqualStrings(
        "/operations/1/status?sig=REDACTED&api-version=1",
        getHeaderPair(
            recordings[1].response_headers,
            "Azure-AsyncOperation",
        ).?,
    );
    try std.testing.expectEqualStrings(
        "/callback?return=https://safe.example/next&mode=one",
        getHeaderPair(
            recordings[1].response_headers,
            "Content-Location",
        ).?,
    );
    for (recordings[0].response_headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, "Operation-Location")) {
            try std.testing.expect(header.redacted);
        } else {
            try std.testing.expect(!header.redacted);
        }
    }
    for (recordings[1].response_headers) |header| {
        try std.testing.expect(!header.redacted);
    }

    var playback = PlaybackTransport.init(
        std.testing.allocator,
        recordings,
    );
    for ([_][]const u8{
        "https://example.test/start",
        "https://example.test/final?sig=rotated-location-sas&mode=one",
        "https://example.test/operations/1?sig=rotated-operation-sas&api-version=1",
    }) |url| {
        var request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            url,
        );
        defer request.deinit();
        var response = try playback.asTransport().send(&request);
        response.deinit();
    }
}

test "safe Location fragments remain replayable through Core redirects" {
    var sequence = core.http.SequenceMockTransport.init(
        std.testing.allocator,
        &.{
            .{
                .status = 302,
                .body = "",
                .headers = &.{
                    .{ .name = "Location", .value = "/final#section" },
                },
            },
            .{ .status = 200, .body = "" },
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
        "https://example.test/start",
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status_code);

    const json = try recorder.toJson(std.testing.allocator);
    defer std.testing.allocator.free(json);
    var parsed = try parseJson(std.testing.allocator, json);
    defer parsed.deinit();
    try std.testing.expectEqualStrings(
        "/final#section",
        getHeaderPair(
            parsed.asSlice()[0].response_headers,
            "Location",
        ).?,
    );
    try std.testing.expectEqualStrings(
        "https://example.test/final",
        parsed.asSlice()[1].request_url,
    );

    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var replayed = try playback.asTransport().send(&request);
    defer replayed.deinit();
    try std.testing.expectEqual(@as(u16, 200), replayed.status_code);
    try std.testing.expectEqual(@as(usize, 2), playback.index);
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
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
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
        var recorder = RecordingTransport.initWithOptions(
            std.testing.allocator,
            mock.asTransport(),
            .{ .bodyPolicyFn = &inspectKnownSafeBody },
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

test "Key Vault key operation root values are rejected" {
    for ([_][]const u8{
        "/keys/name/version/encrypt",
        "/keys/name/version/decrypt",
        "/keys/name/version/wrapkey",
        "/keys/name/version/unwrapkey",
        "/keys/name/backup",
        "/keys/restore",
        "/keys/name/version/release",
    }) |path| {
        const url = try std.fmt.allocPrint(
            std.testing.allocator,
            "https://example.vault.azure.net{s}?api-version=7.6",
            .{path},
        );
        defer std.testing.allocator.free(url);
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "{\"value\":\"operation-secret-value\"}",
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
            url,
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            &.{"operation-secret-value"},
        );
    }

    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "",
    );
    defer mock.deinit();
    var recorder = RecordingTransport.init(
        std.testing.allocator,
        mock.asTransport(),
    );
    defer recorder.deinit();
    var restore = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.vault.azure.net/keys/restore?api-version=7.6",
    );
    defer restore.deinit();
    restore.body = "{\"value\":\"backup-blob-secret\"}";
    var response = try recorder.asTransport().send(&restore);
    response.deinit();
    try expectRejectedSerializationExcludes(
        &recorder,
        error.SensitiveBodyRequiresSanitization,
        &.{"backup-blob-secret"},
    );

    var opaque_mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "{\"value\":\"mislabelled-backup-secret\"}",
    );
    defer opaque_mock.deinit();
    opaque_mock.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "application/pdf" },
    };
    var opaque_recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        opaque_mock.asTransport(),
        .{ .bodyPolicyFn = &allowOpaqueBody },
    );
    defer opaque_recorder.deinit();
    var backup = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.vault.azure.net/keys/name/backup?api-version=7.6",
    );
    defer backup.deinit();
    var opaque_response = try opaque_recorder.asTransport().send(&backup);
    opaque_response.deinit();
    try expectRejectedSerializationExcludes(
        &opaque_recorder,
        error.SensitiveBodyRequiresSanitization,
        &.{"mislabelled-backup-secret"},
    );
}

test "Azure key management key1 and key2 responses are rejected" {
    for ([_][]const u8{
        "https://management.azure.com/subscriptions/s/resourceGroups/r/providers/Microsoft.EventGrid/topics/t/listKeys?api-version=2025-02-15",
        "https://management.azure.com/subscriptions/s/resourceGroups/r/providers/Microsoft.CognitiveServices/accounts/a/regenerateKey?api-version=2024-10-01",
    }) |url| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            "{\"KeY1\":\"first-service-key\",\"key2\":\"second-service-key\"}",
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
            url,
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            &.{ "first-service-key", "second-service-key" },
        );
    }
}

test "Cosmos and Container Registry credential schemas are rejected" {
    const cases = [_]struct {
        url: []const u8,
        body: []const u8,
        secrets: []const []const u8,
    }{
        .{
            .url = "https://management.azure.com/subscriptions/s/resourceGroups/r/providers/Microsoft.DocumentDB/databaseAccounts/a/listKeys?api-version=2025-04-15",
            .body = "{\"primaryMasterKey\":\"cosmos-primary\",\"secondaryMasterKey\":\"cosmos-secondary\",\"primaryReadonlyMasterKey\":\"cosmos-read-primary\",\"secondaryReadonlyMasterKey\":\"cosmos-read-secondary\"}",
            .secrets = &.{
                "cosmos-primary",
                "cosmos-secondary",
                "cosmos-read-primary",
                "cosmos-read-secondary",
            },
        },
        .{
            .url = "https://management.azure.com/subscriptions/s/resourceGroups/r/providers/Microsoft.ContainerRegistry/registries/a/listCredentials?api-version=2025-04-01",
            .body = "{\"username\":\"registry-user\",\"passwords\":[{\"name\":\"password\",\"value\":\"registry-password-one\"},{\"name\":\"password2\",\"value\":\"registry-password-two\"}]}",
            .secrets = &.{ "registry-password-one", "registry-password-two" },
        },
    };
    for (cases) |case| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            case.body,
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
            case.url,
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            case.secrets,
        );
    }
}

test "ARM credential schemas cover every trusted sovereign management host" {
    const hosts = [_][]const u8{
        "management.azure.com",
        "management.usgovcloudapi.net",
        "management.chinacloudapi.cn",
        "management.microsoftazure.de",
    };
    const schemas = [_]struct {
        path: []const u8,
        body: []const u8,
        secrets: []const []const u8,
    }{
        .{
            .path = "/subscriptions/s/resourceGroups/r/providers/Microsoft.Batch/batchAccounts/a/listKeys?api-version=2024-07-01",
            .body = "{\"primary\":\"batch-primary\",\"secondary\":\"batch-secondary\"}",
            .secrets = &.{ "batch-primary", "batch-secondary" },
        },
        .{
            .path = "/subscriptions/s/resourceGroups/r/providers/Microsoft.Search/searchServices/a/listQueryKeys?api-version=2024-03-01-preview",
            .body = "{\"value\":[{\"name\":\"query-key\",\"key\":\"search-query-secret\"}]}",
            .secrets = &.{"search-query-secret"},
        },
        .{
            .path = "/subscriptions/s/resourceGroups/r/providers/Microsoft.EventGrid/topics/t/listKeys?api-version=2025-02-15",
            .body = "{\"key1\":\"event-grid-one\",\"key2\":\"event-grid-two\"}",
            .secrets = &.{ "event-grid-one", "event-grid-two" },
        },
        .{
            .path = "/subscriptions/s/resourceGroups/r/providers/Microsoft.DocumentDB/databaseAccounts/a/listKeys?api-version=2025-04-15",
            .body = "{\"primaryMasterKey\":\"cosmos-one\",\"secondaryMasterKey\":\"cosmos-two\"}",
            .secrets = &.{ "cosmos-one", "cosmos-two" },
        },
        .{
            .path = "/subscriptions/s/resourceGroups/r/providers/Microsoft.ContainerRegistry/registries/a/listCredentials?api-version=2025-04-01",
            .body = "{\"passwords\":[{\"name\":\"password\",\"value\":\"acr-secret\"}]}",
            .secrets = &.{"acr-secret"},
        },
    };
    for (hosts) |host| {
        for (schemas) |schema| {
            const url = try std.fmt.allocPrint(
                std.testing.allocator,
                "https://{s}{s}",
                .{ host, schema.path },
            );
            defer std.testing.allocator.free(url);
            var mock = core.http.MockTransport.init(
                std.testing.allocator,
                200,
                schema.body,
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
                .POST,
                url,
            );
            defer request.deinit();
            var response = try recorder.asTransport().send(&request);
            response.deinit();
            try expectRejectedSerializationExcludes(
                &recorder,
                error.SensitiveBodyRequiresSanitization,
                schema.secrets,
            );
        }
    }
}

test "legacy China management hostname does not activate ARM schemas" {
    const body = "{\"primary\":\"ordinary\",\"secondary\":\"setting\"}";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        body,
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "application/json" },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://management.azure.cn/subscriptions/s/providers/Microsoft.Batch/batchAccounts/a/listKeys",
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

test "ARM key-shaped fields remain safe outside trusted credential actions" {
    const body =
        "{\"primary\":\"one\",\"secondary\":\"two\"," ++
        "\"value\":[{\"name\":\"setting\",\"key\":\"ordinary\"}]}";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        body,
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "application/json" },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://store.azconfig.io/kv/schema-regression?api-version=1.0",
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

test "Storage user delegation key XML is rejected on trusted blob hosts" {
    const hosts = [_][]const u8{
        "account.blob.core.windows.net",
        "account.blob.core.usgovcloudapi.net",
        "account.blob.core.chinacloudapi.cn",
        "account.blob.core.cloudapi.de",
    };
    const body =
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>" ++
        "<UserDelegationKey><SignedOid>oid</SignedOid>" ++
        "<Value>delegation-key-secret</Value></UserDelegationKey>";
    for (hosts) |host| {
        const url = try std.fmt.allocPrint(
            std.testing.allocator,
            "https://{s}/?restype=service&comp=userdelegationkey",
            .{host},
        );
        defer std.testing.allocator.free(url);
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            body,
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
            .POST,
            url,
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try expectRejectedSerializationExcludes(
            &recorder,
            error.SensitiveBodyRequiresSanitization,
            &.{"delegation-key-secret"},
        );
    }
}

test "Storage delegation XML schema ignores untrusted hosts" {
    const body =
        "<UserDelegationKey><Value>ordinary-value</Value>" ++
        "</UserDelegationKey>";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        body,
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "application/xml" },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://account.blob.core.windows.net.attacker.test/" ++
            "?restype=service&comp=userdelegationkey",
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

test "Kusto source URIs and tabular credential scalars are rejected" {
    const jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" ++
        "." ++
        "eyJzdWIiOiJpZGVudGl0eSIsImV4cCI6NDEwMjQ0NDgwMH0" ++
        "." ++
        "c2lnbmF0dXJlLWJ5dGVzLXZhbHVl";
    const jwt_body = try std.fmt.allocPrint(
        std.testing.allocator,
        "{{\"Tables\":[{{\"Rows\":[[\"{s}\"]]}}]}}",
        .{jwt},
    );
    defer std.testing.allocator.free(jwt_body);
    for ([_][]const u8{
        "{\"sourceUri\":\"https://storage.example/container?sig=kusto-source-sas\"}",
        "{\"Tables\":[{\"Rows\":[[\"https://storage.example/blob?sig=row-sas\"]]}]}",
        "{\"Tables\":[{\"Rows\":[[\"https%3A%2F%2Fstorage.example%2Fblob%3Fsv%3D1%26sig%3Dencoded-sas\"]]}]}",
        jwt_body,
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
                jwt,
            },
        );
    }
}

test "plain text signed URLs and structurally valid JWTs are rejected" {
    const jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" ++
        "." ++
        "eyJzdWIiOiJpZGVudGl0eSIsImV4cCI6NDEwMjQ0NDgwMH0" ++
        "." ++
        "c2lnbmF0dXJlLWJ5dGVzLXZhbHVl";
    const jwt_text = try std.fmt.allocPrint(
        std.testing.allocator,
        "identity token: {s}",
        .{jwt},
    );
    defer std.testing.allocator.free(jwt_text);
    for ([_][]const u8{
        "https://storage.example/container/blob?sv=2026-01-01&sig=plain-sas",
        jwt_text,
    }) |body| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            body,
        );
        defer mock.deinit();
        mock.response_headers_list = &.{
            .{ .name = "Content-Type", .value = "text/plain" },
        };
        var recorder = RecordingTransport.initWithOptions(
            std.testing.allocator,
            mock.asTransport(),
            .{ .bodyPolicyFn = &inspectKnownSafeBody },
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            "https://example.test/plain",
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

test "multipart application http credentials cannot bypass allow opaque" {
    const jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" ++
        "." ++
        "eyJzdWIiOiJiYXRjaCIsImV4cCI6NDEwMjQ0NDgwMH0" ++
        "." ++
        "c2lnbmF0dXJlLWJ5dGVzLXZhbHVl";
    const jwt_batch = try std.fmt.allocPrint(
        std.testing.allocator,
        "--batch\r\nContent-Type: application/http\r\n\r\n" ++
            "GET /table HTTP/1.1\r\nx-token: {s}\r\n\r\n--batch--\r\n",
        .{jwt},
    );
    defer std.testing.allocator.free(jwt_batch);
    for ([_][]const u8{
        "--batch\r\nContent-Type: application/http\r\n" ++
            "Content-Transfer-Encoding: binary\r\n\r\n" ++
            "GET /table HTTP/1.1\r\n" ++
            "Authorization: SharedKey account:shared-key-value\r\n\r\n" ++
            "--batch--\r\n",
        "--batch\r\nContent-Type: application/http\r\n\r\n" ++
            "GET /table HTTP/1.1\r\n" ++
            "Authorization: Bearer bearer-token-value\r\n\r\n" ++
            "--batch--\r\n",
        "--batch\r\nContent-Type: application/http\r\n\r\n" ++
            "GET https://storage.example/table?sv=1&sig=batch-sas HTTP/1.1\r\n\r\n" ++
            "--batch--\r\n",
        "legal MIME preamble\r\n" ++
            "--batch\r\nContent-Type: application/json\r\n\r\n" ++
            "{\"accessToken\":\"nested-json-token\"}\r\n" ++
            "--batch--\r\n",
        "legal MIME preamble\r\n" ++
            "--batch\r\nContent-Type: multipart/mixed; boundary=inner\r\n\r\n" ++
            "--inner\r\nContent-Type: application/json\r\n\r\n" ++
            "{\"refreshToken\":\"recursive-json-token\"}\r\n" ++
            "--inner--\r\n--batch--\r\n",
        jwt_batch,
    }) |body| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            body,
        );
        defer mock.deinit();
        mock.response_headers_list = &.{
            .{
                .name = "Content-Type",
                .value = "multipart/mixed; boundary=batch",
            },
        };
        var recorder = RecordingTransport.initWithOptions(
            std.testing.allocator,
            mock.asTransport(),
            .{ .bodyPolicyFn = &allowOpaqueBody },
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .POST,
            "https://account.table.core.windows.net/$batch",
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
}

test "safe multipart application http batch roundtrips explicitly" {
    const body =
        "legal MIME preamble\r\n" ++
        "--batch\r\nContent-Type: application/http\r\n" ++
        "Content-Transfer-Encoding: binary\r\n\r\n" ++
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n" ++
        "{\"PartitionKey\":\"p\",\"RowKey\":\"r\",\"value\":\"safe\"}\r\n" ++
        "--batch--\r\n";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        body,
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{
            .name = "Content-Type",
            .value = "multipart/mixed; charset=utf-8; boundary=\"batch\"",
        },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &allowOpaqueBody },
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://account.table.core.windows.net/$batch",
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

test "declared malformed multipart fails closed despite allow opaque" {
    for ([_]struct {
        content_type: []const u8,
        body: []const u8,
    }{
        .{
            .content_type = "multipart/mixed",
            .body = "--batch\r\nContent-Type: text/plain\r\n\r\nsafe\r\n--batch--\r\n",
        },
        .{
            .content_type = "multipart/mixed; boundary=batch",
            .body = "--batch\r\nContent-Type: text/plain\r\n\r\nsafe\r\n",
        },
        .{
            .content_type = "multipart/mixed; boundary=\"batch",
            .body = "--batch\r\nContent-Type: text/plain\r\n\r\nsafe\r\n--batch--\r\n",
        },
    }) |case| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            case.body,
        );
        defer mock.deinit();
        mock.response_headers_list = &.{
            .{ .name = "Content-Type", .value = case.content_type },
        };
        var recorder = RecordingTransport.initWithOptions(
            std.testing.allocator,
            mock.asTransport(),
            .{ .bodyPolicyFn = &allowOpaqueBody },
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            .GET,
            "https://example.test/multipart",
        );
        defer request.deinit();
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try std.testing.expectError(
            error.UnsupportedBodySanitization,
            recorder.toJson(std.testing.allocator),
        );
    }
}

test "multipart boundaries require exact delimiter line syntax" {
    const malformed =
        "--batch\r\nContent-Type: text/plain\r\n\r\nsafe\r\n" ++
        "--batch--invalid\r\n" ++
        "--batch\r\nContent-Type: text/plain\r\n\r\nlater\r\n" ++
        "--batch--\r\n";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        malformed,
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{
            .name = "Content-Type",
            .value = "multipart/mixed; boundary=batch",
        },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &allowOpaqueBody },
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://account.table.core.windows.net/$batch",
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    try expectRejectedSerializationExcludes(
        &recorder,
        error.UnsupportedBodySanitization,
        &.{"later"},
    );

    const credential_after_fake_close =
        "--batch\r\nContent-Type: text/plain\r\n\r\nsafe\r\n" ++
        "--batch--invalid\r\n" ++
        "--batch\r\nContent-Type: application/http\r\n\r\n" ++
        "GET / HTTP/1.1\r\nAuthorization: SharedKey account:later-secret\r\n\r\n" ++
        "--batch--\r\n";
    var secret_mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        credential_after_fake_close,
    );
    defer secret_mock.deinit();
    secret_mock.response_headers_list = mock.response_headers_list;
    var secret_recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        secret_mock.asTransport(),
        .{ .bodyPolicyFn = &allowOpaqueBody },
    );
    defer secret_recorder.deinit();
    var secret_response =
        try secret_recorder.asTransport().send(&request);
    secret_response.deinit();
    try expectRejectedSerializationExcludes(
        &secret_recorder,
        error.SensitiveBodyRequiresSanitization,
        &.{"later-secret"},
    );
}

test "opaque bodies reject by default and require an explicit safe policy" {
    const opaque_bodies = [_]struct {
        body: []const u8,
        expected_error: anyerror = error.OpaqueBodyNotAllowed,
    }{
        .{ .body = "\x30\x82\xff\x00pkcs12-like" },
        .{ .body = "\xff\xfeP\x00a\x00s\x00s\x00w\x00o\x00r\x00d\x00" },
        .{
            .body = "A\x00c\x00c\x00o\x00u\x00n\x00t\x00K\x00e\x00y\x00=\x00v\x00a\x00l\x00u\x00e\x00",
            .expected_error = error.SensitiveBodyRequiresSanitization,
        },
        .{
            .body = "A\x00\x00\x00c\x00\x00\x00c\x00\x00\x00o\x00\x00\x00u\x00\x00\x00n\x00\x00\x00t\x00\x00\x00K\x00\x00\x00e\x00\x00\x00y\x00\x00\x00=\x00\x00\x00v\x00\x00\x00",
            .expected_error = error.SensitiveBodyRequiresSanitization,
        },
        .{ .body = "\xef\xbb\xbf{\"message\":\"utf8-bom\"}" },
        .{ .body = "{\"message\":\"malformed\xff\"}" },
    };
    for (opaque_bodies) |case| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            case.body,
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
            case.expected_error,
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
            .content_type = "application/pdf",
            .body = "%PDF-printable-fixture",
            .expected_error = error.OpaqueBodyNotAllowed,
        },
        .{
            .content_type = "application/cbor",
            .body = "cbor-container-fixture",
            .expected_error = error.OpaqueBodyNotAllowed,
        },
        .{
            .content_type = "application/pkcs7-mime",
            .body = "pkcs7-container-fixture",
            .expected_error = error.OpaqueBodyNotAllowed,
        },
        .{
            .content_type = "application/x-protobuf",
            .body = "protobuf-container-fixture",
            .expected_error = error.OpaqueBodyNotAllowed,
        },
        .{
            .content_type = "application/vnd.contoso.binary",
            .body = "vendor-container-fixture",
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

test "non-empty bodies require an explicit caller policy" {
    for ([_]bool{ false, true }) |request_has_body| {
        var mock = core.http.MockTransport.init(
            std.testing.allocator,
            200,
            if (request_has_body) "" else "{\"message\":\"ordinary\"}",
        );
        defer mock.deinit();
        var recorder = RecordingTransport.init(
            std.testing.allocator,
            mock.asTransport(),
        );
        defer recorder.deinit();
        var request = core.http.Request.init(
            std.testing.allocator,
            if (request_has_body) .POST else .GET,
            "https://example.test/default-policy",
        );
        defer request.deinit();
        if (request_has_body) request.body = "{\"message\":\"ordinary\"}";
        var response = try recorder.asTransport().send(&request);
        response.deinit();
        try std.testing.expectError(
            error.BodyPolicyRequired,
            recorder.toJson(std.testing.allocator),
        );
    }
}

test "App Configuration dotted values are not mistaken for JWTs" {
    const body =
        "{\"key\":\"endpoint\",\"key1\":\"configuration-label\",\"value\":\"service.production.contoso\",\"passwords\":[{\"name\":\"password\",\"value\":\"ordinary-schema-example\"}]}";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        body,
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "application/json" },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .GET,
        "https://store.azconfig.io/kv/endpoint?api-version=1.0",
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

    var playback = PlaybackTransport.init(
        std.testing.allocator,
        parsed.asSlice(),
    );
    var replayed = try playback.asTransport().send(&request);
    replayed.deinit();
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
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
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
    mock.response_headers_list = &.{
        .{
            .name = "Location",
            .value = "https://example.com/next?sig=allocation-secret&mode=one",
        },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &inspectKnownSafeBody },
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

fn multipartSerializationAllocationFixture(
    allocator: std.mem.Allocator,
) !void {
    const body =
        "--batch\r\nContent-Type: application/http\r\n\r\n" ++
        "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n" ++
        "{\"PartitionKey\":\"p\",\"RowKey\":\"r\",\"value\":\"safe\"}\r\n" ++
        "--batch--\r\n";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        body,
    );
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "Content-Type", .value = "multipart/mixed; boundary=batch" },
    };
    var recorder = RecordingTransport.initWithOptions(
        std.testing.allocator,
        mock.asTransport(),
        .{ .bodyPolicyFn = &allowOpaqueBody },
    );
    defer recorder.deinit();
    var request = core.http.Request.init(
        std.testing.allocator,
        .POST,
        "https://account.table.core.windows.net/$batch",
    );
    defer request.deinit();
    var response = try recorder.asTransport().send(&request);
    response.deinit();
    const json = try recorder.toJson(allocator);
    allocator.free(json);
}

fn jwtHeaderAllocationFixture(allocator: std.mem.Allocator) !void {
    const jwt =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" ++
        "." ++
        "eyJzdWIiOiJoZWFkZXIiLCJleHAiOjQxMDI0NDQ4MDB9" ++
        "." ++
        "c2lnbmF0dXJlLWJ5dGVzLXZhbHVl";
    var mock = core.http.MockTransport.init(
        std.testing.allocator,
        200,
        "",
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
        "https://example.com",
    );
    defer request.deinit();
    try request.setHeader("ETag", jwt);
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
        multipartSerializationAllocationFixture,
        .{},
    );
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        jwtHeaderAllocationFixture,
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
