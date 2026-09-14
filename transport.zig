const std = @import("std");
const core = @import("azure_sdk_core");
const httpx = @import("httpx");
const http = core.http;

pub const Options = struct {
    /// Borrowed configuration owners (including resolver, trust/provider and
    /// backend state) must stay stable until transport deinit closes its pool.
    client: httpx.ClientConfig = .{ .max_request_size = 0, .max_response_size = 0 },
    /// Wire options copied per attempt. Request/auth/body overrides are rejected;
    /// only Core may supply them. Policy is always embedding-owned.
    operation: httpx.OpenOptions = .{ .require_interruptible_dns = true },
    /// Explicit transport content decoding, matching Core's standard backend.
    /// Does not synthesize Accept-Encoding or inherit HTTPX client policy.
    decompression: httpx.DecompressionPolicy = .enabled,
    /// Buffered send only; does not replace the caller's streaming response_limit.
    max_buffered_response: std.Io.Limit = .limited(16 * 1024 * 1024),
};

/// Caller-serialized, move-only owner. Keep its address stable after
/// asTransport(), and deinit all operations before deinit(). Descriptor copies
/// borrow this owner. Only cancellation tokens may be signalled concurrently;
/// HttpOperation methods (including cancel/deinit) remain owner-thread calls.
pub const HttpxTransport = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    client: httpx.Client,
    options: Options,
    live_operations: usize = 0,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: Options) !HttpxTransport {
        try validateOptions(options);
        var config = options.client;
        config.policy = httpx.ClientPolicy.embeddingOwned();
        return .{
            .allocator = allocator,
            .io = io,
            .client = try httpx.Client.tryInitWithConfig(allocator, config),
            .options = options,
        };
    }

    pub fn deinit(self: *HttpxTransport) void {
        std.debug.assert(self.live_operations == 0);
        self.client.deinit();
        self.* = undefined;
    }

    pub fn asTransport(self: *HttpxTransport) http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    pub fn poolStats(self: *HttpxTransport) httpx.PoolStats {
        return self.client.poolStats();
    }

    /// Optional adapter extension; Core has no trailer field. Values borrow
    /// canonical HTTPX storage until operation deinit. Read after EOF/finish.
    pub fn trailers(self: *const HttpxTransport, operation: *const http.HttpOperation) !?*const httpx.Headers {
        if (operation.deinitFn != Operation.deinit) return error.ForeignHttpOperation;
        const state: *const Operation = @fieldParentPtr("operation", operation);
        if (state.owner != self) return error.ForeignHttpOperation;
        return state.native.trailers();
    }

    const vtable: http.HttpTransport.VTable = .{ .send = send, .open = open };

    fn send(context: *anyopaque, request: *http.Request) !http.Response {
        const self: *HttpxTransport = @ptrCast(@alignCast(context));
        const operation = try open(context, request, .{});
        defer operation.deinit();
        const body = operation.body_reader.allocRemaining(self.allocator, self.options.max_buffered_response) catch |err| {
            return if (err == error.ReadFailed) operation.bodyError() orelse err else err;
        };
        errdefer self.allocator.free(body);
        try operation.finish();
        // Move owned metadata, so buffered send has no second body/header copy.
        const response: http.Response = .{
            .status_code = operation.status_code,
            .body = body,
            .headers = operation.headers,
            .response_headers = operation.response_headers,
            .allocator = self.allocator,
        };
        operation.headers = std.StringHashMap([]const u8).init(self.allocator);
        operation.response_headers = .{};
        return response;
    }

    fn open(context: *anyopaque, request: *http.Request, options: http.OpenOptions) !*http.HttpOperation {
        const self: *HttpxTransport = @ptrCast(@alignCast(context));
        if (options.body != null and request.body != null) return error.MultipleRequestBodies;
        try checkCancelled(options.cancellation);
        var wire = self.options.operation;
        wire.policy = httpx.RequestPolicyOverrides.embeddingOwned();
        wire.policy.decompression = self.options.decompression;
        wire.body_mode = bodyMode(request, options);
        if (self.options.client.http3_enabled or wire.version == .HTTP_3)
            return error.UnsupportedHttpVersion;
        if (wire.unix_socket_path != null or self.options.client.unix_socket_path != null) {
            const uri = try httpx.Uri.parse(request.url);
            if (self.options.client.http2_enabled or wire.version == .HTTP_2 or uri.isTLS())
                return error.UnsupportedStreamingTransport;
        }
        // timeout_ms is a phase override in HTTPX, not an operation budget.
        if (request.operation_timeout_ms) |budget| {
            if (budget == 0) return error.OperationTimedOut;
            var timeouts = wire.timeouts orelse self.options.client.timeouts;
            timeouts.request_ms = if (timeouts.request_ms == 0) budget else @min(budget, timeouts.request_ms);
            wire.timeouts = timeouts;
        }
        var fields: std.ArrayList([2][]const u8) = .empty;
        defer fields.deinit(self.allocator);
        var iterator = request.headers.iterator();
        while (iterator.next()) |entry| {
            if (try framingHeader(entry.key_ptr.*, entry.value_ptr.*, wire.body_mode)) continue;
            try fields.append(self.allocator, .{ entry.key_ptr.*, entry.value_ptr.* });
        }
        if (request.getHeader("Connection") == null and
            !self.options.client.http2_enabled and wire.version != .HTTP_2)
        {
            try fields.append(self.allocator, .{
                "Connection",
                if (wire.keep_alive orelse self.options.client.keep_alive) "keep-alive" else "close",
            });
        }
        wire.headers = fields.items;
        wire.expect_100_continue = if (request.getHeader("Expect")) |expect|
            std.ascii.eqlIgnoreCase(std.mem.trim(u8, expect, " \t"), "100-continue")
        else
            false;

        const state = try self.allocator.create(Operation);
        errdefer self.allocator.destroy(state);
        state.* = .{
            .owner = self,
            .native = undefined,
            .operation = undefined,
            .reader = undefined,
            .bridge = .{ .io = self.io, .core_token = options.cancellation, .external = wire.cancel_token },
        };
        try state.bridge.start();
        errdefer state.bridge.stop();
        // The stable bridge token is used only when translation is necessary.
        if (options.cancellation != null) wire.cancel_token = &state.bridge.token;
        state.native = self.client.open(toMethod(request.method), request.url, wire) catch |err|
            return mapError(err);
        errdefer state.native.deinit();
        const send_body = if (wire.expect_100_continue)
            (state.native.waitForContinue() catch |err| return mapError(err)) == .send_body
        else
            true;
        if (send_body) {
            if (options.body) |body| {
                try state.upload(body, options.cancellation);
            } else if (request.body) |body| {
                try checkCancelled(options.cancellation);
                state.native.writeAll(body) catch |err| switch (err) {
                    error.EarlyResponse => {},
                    else => return mapError(err),
                };
            }
        }
        try checkCancelled(options.cancellation);
        const head = state.native.finishRequest(null) catch |err| return mapError(err);
        var headers = try HeaderSet.copy(self.allocator, head.headers);
        errdefer headers.deinit(self.allocator);
        state.reader = .{
            .vtable = &.{ .stream = Operation.stream },
            .buffer = &state.read_buffer,
            .seek = 0,
            .end = 0,
        };
        state.operation = .{
            .status_code = head.status.code,
            .headers = headers.map,
            .response_headers = headers.ordered,
            .body_reader = &state.reader,
            .finishFn = Operation.finish,
            .abortFn = Operation.abort,
            .cancelFn = Operation.cancel,
            .deinitFn = Operation.deinit,
            .bodyErrorFn = Operation.bodyError,
        };
        self.live_operations += 1;
        return &state.operation;
    }
};

fn validateOptions(options: Options) !void {
    const wire = options.operation;
    if (!options.client.verify_ssl or wire.verify_ssl == false) return error.TlsVerificationRequired;
    if (comptime @hasField(httpx.ClientConfig, "server_authentication")) {
        if (options.client.server_authentication) |authentication| {
            if (authentication != .verify) return error.TlsVerificationRequired;
        }
    }
    // Ambient request defaults could restore a credential after Core strips it
    // on a redirect, or alter bytes/framing after an Azure signing policy.
    if (options.client.default_headers != null or options.client.base_url != null or
        options.client.request_compression != null or wire.headers != null or
        wire.query_params != null or wire.bearer_token != null or wire.basic_auth != null or
        wire.api_key_header != null or wire.api_key_value != null or wire.range_header != null or
        wire.custom_method != null or wire.body_mode != .none or wire.expect_100_continue)
        return error.AzureOwnsRequestOptions;
}

fn toMethod(method: http.Method) httpx.Method {
    return switch (method) {
        inline else => |value| @field(httpx.Method, @tagName(value)),
    };
}

fn bodyMode(request: *const http.Request, options: http.OpenOptions) httpx.BodyMode {
    if (options.body) |body| return if (body.content_length) |length| .{ .content_length = length } else .chunked;
    if (request.body) |body| return .{ .content_length = body.len };
    return if (request.method.toStd().requestHasBody()) .{ .content_length = 0 } else .none;
}

fn framingHeader(name: []const u8, value: []const u8, mode: httpx.BodyMode) !bool {
    if (std.ascii.eqlIgnoreCase(name, "Content-Length")) {
        if (mode != .content_length) return error.ConflictingRequestFraming;
        const trimmed = std.mem.trim(u8, value, " \t");
        if (trimmed.len == 0) return error.ConflictingRequestFraming;
        for (trimmed) |byte| if (!std.ascii.isDigit(byte)) return error.ConflictingRequestFraming;
        const length = std.fmt.parseInt(u64, trimmed, 10) catch return error.ConflictingRequestFraming;
        if (length != mode.content_length) return error.ConflictingRequestFraming;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(name, "Transfer-Encoding")) {
        if (mode != .chunked or !std.ascii.eqlIgnoreCase(std.mem.trim(u8, value, " \t"), "chunked"))
            return error.ConflictingRequestFraming;
        return true;
    }
    return false;
}

fn mapError(err: anyerror) anyerror {
    return switch (err) {
        error.Cancelled => error.OperationCancelled,
        error.Timeout, error.RequestTimeout => error.OperationTimedOut,
        error.RequestBodyUnderrun => error.RequestBodyTooShort,
        error.RequestBodyOverrun => error.RequestBodyTooLong,
        error.ResponseBodyUnderrun => error.HttpContentLengthTruncated,
        error.InvalidContentLength, error.ConflictingFramingHeaders, error.InvalidHeader, error.InvalidResponse, error.DuplicateFramingHeader => error.HttpHeadersInvalid,
        error.ResponseTooLarge => error.StreamTooLong,
        else => err,
    };
}

fn checkCancelled(token: ?*const http.CancellationToken) !void {
    if (token) |value| if (value.isCancelled()) return error.OperationCancelled;
}

const CancellationBridge = struct {
    io: std.Io,
    core_token: ?*const http.CancellationToken,
    external: ?*const httpx.CancellationToken,
    token: httpx.CancellationToken = .{},
    done: std.Io.Event = .unset,
    thread: ?std.Thread = null,

    fn start(self: *CancellationBridge) !void {
        if (self.core_token == null) return;
        self.poll();
        self.thread = try std.Thread.spawn(.{}, run, .{self});
    }

    fn poll(self: *CancellationBridge) void {
        if (self.core_token) |token| if (token.isCancelled()) self.token.cancel();
        if (self.external) |token| if (token.isCancelled()) self.token.cancel();
    }

    fn run(self: *CancellationBridge) void {
        while (true) {
            self.poll();
            self.done.waitTimeout(self.io, .{ .duration = .{ .raw = .fromMilliseconds(1), .clock = .awake } }) catch |err| {
                if (err == error.Timeout) continue;
                self.token.cancel();
            };
            return;
        }
    }

    fn stop(self: *CancellationBridge) void {
        if (self.thread) |thread| {
            self.done.set(self.io);
            thread.join();
            self.thread = null;
        }
    }
};

const Operation = struct {
    owner: *HttpxTransport,
    native: httpx.ClientOperation,
    operation: http.HttpOperation,
    reader: std.Io.Reader,
    read_buffer: [16 * 1024]u8 = undefined,
    bridge: CancellationBridge,
    failure: ?anyerror = null,

    fn upload(self: *Operation, body: http.StreamingRequestBody, token: ?*const http.CancellationToken) !void {
        var buffer: [16 * 1024]u8 = undefined;
        while (true) {
            try checkCancelled(token);
            const count = try body.reader.readSliceShort(&buffer);
            try checkCancelled(token);
            if (count == 0) return;
            self.native.writeAll(buffer[0..count]) catch |err| switch (err) {
                error.EarlyResponse => return,
                else => return mapError(err),
            };
        }
    }

    fn record(self: *Operation, err: anyerror) anyerror {
        if (self.failure == null) self.failure = mapError(err);
        return self.failure.?;
    }

    fn stream(reader: *std.Io.Reader, writer: *std.Io.Writer, limit: std.Io.Limit) std.Io.Reader.StreamError!usize {
        const self: *Operation = @fieldParentPtr("reader", reader);
        if (self.failure != null or self.operation.state != .active) return error.ReadFailed;
        // Acquire writable space before reading: writer failure cannot lose
        // already-consumed HTTP bytes. No storage proportional to body size.
        const output = limit.slice(try writer.writableSliceGreedy(1));
        if (output.len == 0) return 0;
        checkCancelled(self.bridge.core_token) catch |err| {
            self.failure = self.record(err);
            self.native.abort();
            return error.ReadFailed;
        };
        const count = self.native.read(output) catch |err| {
            self.failure = self.record(err);
            return error.ReadFailed;
        };
        if (count == 0) return error.EndOfStream;
        writer.advance(count);
        return count;
    }

    fn finish(operation: *http.HttpOperation) !void {
        const self: *Operation = @fieldParentPtr("operation", operation);
        defer self.bridge.stop();
        if (self.failure) |err| return err;
        try checkCancelled(self.bridge.core_token);
        self.native.finish(.{}) catch |err| return self.record(err);
    }

    fn abort(operation: *http.HttpOperation) void {
        const self: *Operation = @fieldParentPtr("operation", operation);
        self.native.abort();
        self.bridge.stop();
    }

    fn cancel(operation: *http.HttpOperation) void {
        const self: *Operation = @fieldParentPtr("operation", operation);
        self.native.cancel();
        self.bridge.stop();
    }

    fn bodyError(operation: *const http.HttpOperation) ?anyerror {
        const self: *const Operation = @fieldParentPtr("operation", operation);
        return self.failure;
    }

    fn deinit(operation: *http.HttpOperation) void {
        const self: *Operation = @fieldParentPtr("operation", operation);
        self.bridge.stop();
        self.native.deinit();
        var headers: HeaderSet = .{ .map = operation.headers, .ordered = operation.response_headers };
        headers.deinit(self.owner.allocator);
        self.owner.live_operations -= 1;
        self.owner.allocator.destroy(self);
    }
};

const HeaderSet = struct {
    map: std.StringHashMap([]const u8),
    ordered: http.ResponseHeaders,

    fn copy(allocator: std.mem.Allocator, source: *const httpx.Headers) !HeaderSet {
        var self: HeaderSet = .{
            .map = std.StringHashMap([]const u8).init(allocator),
            .ordered = http.ResponseHeaders.init(allocator),
        };
        errdefer self.deinit(allocator);
        for (source.iterator()) |header| {
            try self.ordered.append(header.name, header.value);
            const name = try allocator.dupe(u8, header.name);
            errdefer allocator.free(name);
            const value = try allocator.dupe(u8, header.value);
            errdefer allocator.free(value);
            const entry = try self.map.getOrPut(name);
            if (entry.found_existing) {
                allocator.free(name);
                allocator.free(entry.value_ptr.*);
            } else {
                entry.key_ptr.* = name;
            }
            entry.value_ptr.* = value;
        }
        return self;
    }

    fn deinit(self: *HeaderSet, allocator: std.mem.Allocator) void {
        var iterator = self.map.iterator();
        while (iterator.next()) |header| {
            allocator.free(header.key_ptr.*);
            allocator.free(header.value_ptr.*);
        }
        self.map.deinit();
        self.ordered.deinit();
    }
};
