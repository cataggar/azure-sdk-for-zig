const std = @import("std");
const url_mod = @import("../url.zig");

/// HTTP method verbs.
pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,

    /// Map to std.http.Method for the standard-library HTTP client.
    pub fn toStd(self: Method) std.http.Method {
        return switch (self) {
            .GET => .GET,
            .POST => .POST,
            .PUT => .PUT,
            .DELETE => .DELETE,
            .PATCH => .PATCH,
            .HEAD => .HEAD,
            .OPTIONS => .OPTIONS,
        };
    }
};

/// Controls whether an HTTP transport may follow redirects.
pub const RedirectPolicy = enum {
    follow,
    not_allowed,
};

/// An outgoing HTTP request.
pub const Request = struct {
    method: Method = .GET,
    url: []const u8,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8 = null,
    allocator: std.mem.Allocator,
    retryable: bool = true,
    /// Set immediately before a transport implementation is called. This lets
    /// non-idempotent clients distinguish pre-transport failures from an
    /// attempt whose server-side outcome is unknown.
    transport_started: bool = false,
    redirect_policy: RedirectPolicy = .follow,
    /// Best-effort budget checked before attempts and retry backoff. A blocking
    /// in-flight send can exceed this budget.
    operation_timeout_ms: ?u64 = null,

    pub fn init(allocator: std.mem.Allocator, method: Method, request_url: []const u8) Request {
        return .{
            .method = method,
            .url = request_url,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = null,
            .allocator = allocator,
        };
    }

    pub fn setHeader(self: *Request, key: []const u8, value: []const u8) !void {
        if (key.len == 0) return error.InvalidHttpHeaderName;
        for (key) |byte| {
            if (!isHttpTokenByte(byte)) return error.InvalidHttpHeaderName;
        }
        for (value) |byte| {
            if ((byte < 0x20 and byte != '\t') or byte == 0x7f)
                return error.InvalidHttpHeaderValue;
        }

        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        var iterator = self.headers.iterator();
        while (iterator.next()) |entry| {
            if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, key)) {
                self.allocator.free(entry.value_ptr.*);
                entry.value_ptr.* = owned_value;
                return;
            }
        }

        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        try self.headers.put(owned_key, owned_value);
    }

    pub fn getHeader(self: *const Request, key: []const u8) ?[]const u8 {
        var iterator = self.headers.iterator();
        while (iterator.next()) |entry| {
            if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, key)) {
                return entry.value_ptr.*;
            }
        }
        return null;
    }

    pub fn deinit(self: *Request) void {
        deinitOwnedHeaders(self.allocator, &self.headers);
    }
};

fn isHttpTokenByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or switch (byte) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        else => false,
    };
}

pub const ResponseHeader = struct {
    name: []const u8,
    value: []const u8,
};

/// Allocator-owned response headers in wire order.
///
/// Unlike `Response.headers`, this collection preserves duplicate field
/// values. Use `getFirst` for the first value or `getAll` for every value.
pub const ResponseHeaders = struct {
    entries: std.ArrayList(ResponseHeader) = .empty,
    allocator: ?std.mem.Allocator = null,

    pub fn init(allocator: std.mem.Allocator) ResponseHeaders {
        return .{ .allocator = allocator };
    }

    pub fn append(self: *ResponseHeaders, name: []const u8, value: []const u8) !void {
        const allocator = self.allocator orelse return error.ResponseHeadersNotInitialized;
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_value = try allocator.dupe(u8, value);
        errdefer allocator.free(owned_value);
        try self.entries.append(allocator, .{ .name = owned_name, .value = owned_value });
    }

    pub fn getFirst(self: *const ResponseHeaders, name: []const u8) ?[]const u8 {
        for (self.entries.items) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
        }
        return null;
    }

    /// Return an allocator-owned slice containing borrowed header values.
    pub fn getAll(
        self: *const ResponseHeaders,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) ![][]const u8 {
        var count: usize = 0;
        for (self.entries.items) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) count += 1;
        }
        const values = try allocator.alloc([]const u8, count);
        var index: usize = 0;
        for (self.entries.items) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, name)) {
                values[index] = header.value;
                index += 1;
            }
        }
        return values;
    }

    pub fn clone(self: *const ResponseHeaders, allocator: std.mem.Allocator) !ResponseHeaders {
        var result = ResponseHeaders.init(allocator);
        errdefer result.deinit();
        for (self.entries.items) |header| {
            try result.append(header.name, header.value);
        }
        return result;
    }

    pub fn deinit(self: *ResponseHeaders) void {
        const allocator = self.allocator orelse return;
        for (self.entries.items) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        self.entries.deinit(allocator);
        self.* = .{};
    }
};

/// An HTTP response.
pub const Response = struct {
    status_code: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,
    response_headers: ResponseHeaders = .{},

    pub fn isSuccess(self: Response) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }

    pub fn getHeader(self: *const Response, key: []const u8) ?[]const u8 {
        if (self.response_headers.getFirst(key)) |value| return value;
        var iterator = self.headers.iterator();
        while (iterator.next()) |entry| {
            if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, key)) {
                return entry.value_ptr.*;
            }
        }
        return null;
    }

    /// Return all values for a response header, preserving wire order.
    ///
    /// The returned outer slice is allocator-owned; its values borrow from
    /// this response and remain valid until `deinit`.
    pub fn getHeaderValues(
        self: *const Response,
        allocator: std.mem.Allocator,
        key: []const u8,
    ) ![][]const u8 {
        const values = try self.response_headers.getAll(allocator, key);
        if (values.len > 0) return values;
        allocator.free(values);

        const value = getHeaderFromMap(&self.headers, key) orelse
            return allocator.alloc([]const u8, 0);
        const fallback = try allocator.alloc([]const u8, 1);
        fallback[0] = value;
        return fallback;
    }

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
        self.response_headers.deinit();
        deinitOwnedHeaders(self.allocator, &self.headers);
    }
};

/// A thread-safe signal checked between streamed upload reads.
///
/// Calling `cancel` does not interrupt a blocking reader or socket operation.
pub const CancellationToken = struct {
    cancelled: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),

    pub fn cancel(self: *CancellationToken) void {
        self.cancelled.store(true, .release);
    }

    pub fn isCancelled(self: *const CancellationToken) bool {
        return self.cancelled.load(.acquire);
    }
};

/// A borrowed request-body reader. `knownLength` uses `Content-Length`;
/// `chunked` uses chunked transfer encoding.
///
/// The reader must remain valid until `HttpTransport.open` returns.
/// Redirects and retries are allowed only when both rewind fields are set.
pub const StreamingRequestBody = struct {
    reader: *std.Io.Reader,
    content_length: ?u64 = null,
    rewind_context: ?*anyopaque = null,
    rewindFn: ?*const fn (context: *anyopaque) anyerror!*std.Io.Reader = null,

    pub fn knownLength(reader: *std.Io.Reader, content_length: u64) StreamingRequestBody {
        return .{ .reader = reader, .content_length = content_length };
    }

    pub fn chunked(reader: *std.Io.Reader) StreamingRequestBody {
        return .{ .reader = reader };
    }

    pub fn withRewind(
        self: StreamingRequestBody,
        context: *anyopaque,
        rewindFn: *const fn (context: *anyopaque) anyerror!*std.Io.Reader,
    ) StreamingRequestBody {
        var replayable = self;
        replayable.rewind_context = context;
        replayable.rewindFn = rewindFn;
        return replayable;
    }

    pub fn isReplayable(self: StreamingRequestBody) bool {
        return self.rewind_context != null and self.rewindFn != null;
    }

    pub fn rewind(self: *StreamingRequestBody) !void {
        const context = self.rewind_context orelse return error.RequestBodyNotReplayable;
        const rewindFn = self.rewindFn orelse return error.RequestBodyNotReplayable;
        self.reader = try rewindFn(context);
    }
};

/// A borrowed, bounded-memory byte body that can be replayed without copying.
///
/// Keep this value and its bytes alive until `HttpPipeline.open` returns.
pub const ReplayableBytes = struct {
    bytes: []const u8,
    reader_impl: std.Io.Reader,

    pub fn init(bytes: []const u8) ReplayableBytes {
        return .{
            .bytes = bytes,
            .reader_impl = std.Io.Reader.fixed(bytes),
        };
    }

    pub fn body(self: *ReplayableBytes) StreamingRequestBody {
        return StreamingRequestBody.knownLength(
            &self.reader_impl,
            self.bytes.len,
        ).withRewind(self, &rewindImpl);
    }

    fn rewindImpl(context: *anyopaque) !*std.Io.Reader {
        const self: *ReplayableBytes = @ptrCast(@alignCast(context));
        self.reader_impl = std.Io.Reader.fixed(self.bytes);
        return &self.reader_impl;
    }
};

pub const OpenOptions = struct {
    /// When null, `Request.body` is used as a known-length body.
    body: ?StreamingRequestBody = null,
    cancellation: ?*const CancellationToken = null,

    pub fn isReplayable(self: OpenOptions) bool {
        // Buffered Request.body bytes and body-less requests are replayable.
        return if (self.body) |body| body.isReplayable() else true;
    }
};

const BodyFraming = union(enum) {
    none,
    content_length: u64,
    chunked,
};

pub const OperationState = enum {
    active,
    finished,
    aborted,
    cancelled,
};

/// Single-owner handle for an incremental HTTP response.
pub const HttpOperation = struct {
    status_code: u16,
    headers: std.StringHashMap([]const u8),
    response_headers: ResponseHeaders = .{},
    body_reader: *std.Io.Reader,
    state: OperationState = .active,
    finishFn: *const fn (self: *HttpOperation) anyerror!void,
    abortFn: *const fn (self: *HttpOperation) void,
    cancelFn: *const fn (self: *HttpOperation) void,
    deinitFn: *const fn (self: *HttpOperation) void,
    bodyErrorFn: ?*const fn (self: *const HttpOperation) ?anyerror = null,

    pub fn isSuccess(self: *const HttpOperation) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }

    pub fn getHeader(self: *const HttpOperation, name: []const u8) ?[]const u8 {
        if (self.response_headers.getFirst(name)) |value| return value;
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, name)) return entry.value_ptr.*;
        }
        return null;
    }

    /// Return all values for a response header, preserving wire order.
    pub fn getHeaderValues(
        self: *const HttpOperation,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) ![][]const u8 {
        const values = try self.response_headers.getAll(allocator, name);
        if (values.len > 0) return values;
        allocator.free(values);

        const value = getHeaderFromMap(&self.headers, name) orelse
            return allocator.alloc([]const u8, 0);
        const fallback = try allocator.alloc([]const u8, 1);
        fallback[0] = value;
        return fallback;
    }

    pub fn reader(self: *HttpOperation) !*std.Io.Reader {
        if (self.state != .active) return error.HttpOperationNotActive;
        return self.body_reader;
    }

    pub fn bodyError(self: *const HttpOperation) ?anyerror {
        if (self.state != .active) return null;
        const bodyErrorFn = self.bodyErrorFn orelse return null;
        return bodyErrorFn(self);
    }

    /// Drains the response and releases the underlying connection.
    pub fn finish(self: *HttpOperation) !void {
        if (self.state != .active) return error.HttpOperationNotActive;
        self.finishFn(self) catch |err| {
            self.abortFn(self);
            self.state = .aborted;
            return err;
        };
        self.state = .finished;
    }

    /// Stops without draining the response.
    pub fn abort(self: *HttpOperation) void {
        if (self.state != .active) return;
        self.abortFn(self);
        self.state = .aborted;
    }

    pub fn cancel(self: *HttpOperation) void {
        if (self.state != .active) return;
        self.cancelFn(self);
        self.state = .cancelled;
    }

    /// Aborts an active operation, then releases all operation storage.
    pub fn deinit(self: *HttpOperation) void {
        if (self.state == .active) self.abort();
        self.deinitFn(self);
    }
};

/// Pluggable HTTP transport interface.
///
/// Default implementation uses `std.http.Client` (TLS via `std.crypto.tls`).
/// Users may supply their own for testing or custom networking.
/// Custom implementations must honor `.not_allowed`; this is a security
/// contract for bootstrap calls.
pub const HttpTransport = struct {
    sendFn: *const fn (self: *HttpTransport, request: *Request) anyerror!Response,
    openFn: ?*const fn (
        self: *HttpTransport,
        request: *Request,
        options: OpenOptions,
    ) anyerror!*HttpOperation = null,

    pub fn send(self: *HttpTransport, request: *Request) !Response {
        request.transport_started = true;
        return sendFollowingRedirects(self, request);
    }

    pub fn open(
        self: *HttpTransport,
        request: *Request,
        options: OpenOptions,
    ) !*HttpOperation {
        request.transport_started = true;
        return openFollowingRedirects(self, request, options);
    }
};

const max_redirects = 10;

fn sendFollowingRedirects(transport: *HttpTransport, request: *Request) !Response {
    var current = request;
    var owned: ?*OwnedRedirectRequest = null;
    defer if (owned) |value| value.destroy();

    var redirect_count: usize = 0;
    while (true) {
        var response = try transport.sendFn(transport, current);
        const location = redirectLocation(response.status_code, response.getHeader("Location")) orelse
            return response;
        if (current.redirect_policy == .not_allowed) return response;
        if (redirect_count >= max_redirects) {
            response.deinit();
            return error.TooManyRedirects;
        }

        const target = resolveRedirect(current, location) catch |err| {
            response.deinit();
            return err;
        };
        response.deinit();
        const next = OwnedRedirectRequest.create(current, target.url, target.cross_origin) catch |err| {
            target.allocator.free(target.url);
            return err;
        };
        target.allocator.free(target.url);
        if (owned) |previous| previous.destroy();
        owned = next;
        current = &next.request;
        redirect_count += 1;
    }
}

fn openFollowingRedirects(
    transport: *HttpTransport,
    request: *Request,
    options: OpenOptions,
) !*HttpOperation {
    var current = request;
    var current_options = options;
    var owned: ?*OwnedRedirectRequest = null;
    defer if (owned) |value| value.destroy();

    var redirect_count: usize = 0;
    while (true) {
        var operation = try rawOpen(transport, current, current_options);
        const location = redirectLocation(operation.status_code, operation.getHeader("Location")) orelse
            return operation;
        if (current.redirect_policy == .not_allowed or !current_options.isReplayable())
            return operation;
        if (redirect_count >= max_redirects) {
            operation.abort();
            operation.deinit();
            return error.TooManyRedirects;
        }

        const target = resolveRedirect(current, location) catch |err| {
            operation.abort();
            operation.deinit();
            return err;
        };
        operation.abort();
        operation.deinit();
        if (current_options.body) |*body| body.rewind() catch |err| {
            target.allocator.free(target.url);
            return err;
        };
        const next = OwnedRedirectRequest.create(current, target.url, target.cross_origin) catch |err| {
            target.allocator.free(target.url);
            return err;
        };
        target.allocator.free(target.url);
        if (owned) |previous| previous.destroy();
        owned = next;
        current = &next.request;
        redirect_count += 1;
    }
}

fn rawOpen(
    transport: *HttpTransport,
    request: *Request,
    options: OpenOptions,
) !*HttpOperation {
    if (transport.openFn) |openFn| return openFn(transport, request, options);
    if (options.body != null) return error.StreamingRequestUnsupported;
    try checkCancelled(options.cancellation);
    return BufferedOperation.openRaw(transport, request);
}

fn redirectLocation(status_code: u16, location: ?[]const u8) ?[]const u8 {
    if (status_code != 307 and status_code != 308) return null;
    return location;
}

const ResolvedRedirect = struct {
    allocator: std.mem.Allocator,
    url: []u8,
    cross_origin: bool,
};

fn resolveRedirect(request: *const Request, location: []const u8) !ResolvedRedirect {
    const resolved = try url_mod.resolveAndValidateUrl(request.allocator, request.url, location, &.{});
    errdefer request.allocator.free(resolved);
    return .{
        .allocator = request.allocator,
        .url = resolved,
        .cross_origin = !(try url_mod.sameOrigin(request.url, resolved)),
    };
}

const OwnedRedirectRequest = struct {
    allocator: std.mem.Allocator,
    request: Request,
    url: []u8,

    fn create(
        source: *const Request,
        target_url: []const u8,
        cross_origin: bool,
    ) !*OwnedRedirectRequest {
        const self = try source.allocator.create(OwnedRedirectRequest);
        errdefer source.allocator.destroy(self);
        const owned_url = try source.allocator.dupe(u8, target_url);
        errdefer source.allocator.free(owned_url);
        self.* = .{
            .allocator = source.allocator,
            .request = Request.init(source.allocator, source.method, owned_url),
            .url = owned_url,
        };
        errdefer self.request.deinit();
        var headers = source.headers.iterator();
        while (headers.next()) |header| {
            if (cross_origin and std.ascii.eqlIgnoreCase(header.key_ptr.*, "Authorization"))
                continue;
            try self.request.setHeader(header.key_ptr.*, header.value_ptr.*);
        }
        self.request.body = source.body;
        self.request.retryable = source.retryable;
        self.request.transport_started = true;
        self.request.redirect_policy = source.redirect_policy;
        self.request.operation_timeout_ms = source.operation_timeout_ms;
        return self;
    }

    fn destroy(self: *OwnedRedirectRequest) void {
        self.request.deinit();
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

const BufferedOperation = struct {
    operation: HttpOperation,
    allocator: std.mem.Allocator,
    response: Response,
    reader_impl: std.Io.Reader,

    fn openRaw(transport: *HttpTransport, request: *Request) !*HttpOperation {
        return fromResponse(try transport.sendFn(transport, request));
    }

    fn fromResponse(response_value: Response) !*HttpOperation {
        var response = response_value;
        errdefer response.deinit();
        const self = try response.allocator.create(BufferedOperation);
        self.* = .{
            .operation = undefined,
            .allocator = response.allocator,
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
        self.response.headers = std.StringHashMap([]const u8).init(response.allocator);
        self.response.response_headers = .{};
        return &self.operation;
    }

    fn finishImpl(operation: *HttpOperation) !void {
        const self: *BufferedOperation = @alignCast(@fieldParentPtr("operation", operation));
        _ = try self.reader_impl.discardRemaining();
    }

    fn abortImpl(_: *HttpOperation) void {}

    fn deinitImpl(operation: *HttpOperation) void {
        const self: *BufferedOperation = @alignCast(@fieldParentPtr("operation", operation));
        self.operation.response_headers.deinit();
        deinitOwnedHeaders(self.allocator, &self.operation.headers);
        self.response.deinit();
        self.allocator.destroy(self);
    }
};

/// Default transport backed by `std.http.Client`.
///
/// Requires `std.Io` (threaded or evented) for TLS, DNS, and socket I/O.
/// The transport reuses one client and its connection pool across requests.
/// It is not thread-safe; callers must serialize access or provide their own
/// synchronization.
pub const StdHttpTransport = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    client: std.http.Client,
    transport: HttpTransport,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) StdHttpTransport {
        return .{
            .allocator = allocator,
            .io = io,
            .client = .{ .allocator = allocator, .io = io },
            .transport = .{ .sendFn = &sendImpl, .openFn = &openImpl },
        };
    }

    pub fn asTransport(self: *StdHttpTransport) *HttpTransport {
        return &self.transport;
    }

    pub fn deinit(self: *StdHttpTransport) void {
        self.client.deinit();
    }

    fn sendImpl(transport: *HttpTransport, request: *Request) !Response {
        const self: *StdHttpTransport = @alignCast(@fieldParentPtr("transport", transport));
        const allocator = self.allocator;

        var operation = try StdStreamingOperation.open(self, request, .{}, false);
        defer operation.deinit();

        const body = operation.body_reader.allocRemaining(
            allocator,
            .limited(16 * 1024 * 1024),
        ) catch |err| switch (err) {
            error.ReadFailed => return operation.bodyError() orelse error.ReadFailed,
            else => |other| return other,
        };
        errdefer allocator.free(body);
        try operation.finish();

        var header_set = try cloneOwnedResponseHeaderSet(
            allocator,
            &operation.headers,
            &operation.response_headers,
        );
        errdefer header_set.deinit(allocator);

        return .{
            .status_code = operation.status_code,
            .headers = header_set.map,
            .body = body,
            .allocator = allocator,
            .response_headers = header_set.values,
        };
    }

    fn openImpl(
        transport: *HttpTransport,
        request: *Request,
        options: OpenOptions,
    ) !*HttpOperation {
        const self: *StdHttpTransport = @alignCast(@fieldParentPtr("transport", transport));
        return StdStreamingOperation.open(self, request, options, true);
    }
};

const StdStreamingOperation = struct {
    operation: HttpOperation,
    allocator: std.mem.Allocator,
    client: std.http.Client,
    client_ptr: *std.http.Client,
    owns_client: bool,
    request_headers: std.StringHashMap([]const u8),
    extra_headers: []std.http.Header,
    redirect_buffer: []u8,
    decompress_buffer: []u8,
    request: std.http.Client.Request,
    request_active: bool,
    response: std.http.Client.Response,
    transfer_reader: *std.Io.Reader,
    transfer_buffer: [64]u8,
    upload_read_buffer: [16 * 1024]u8,
    upload_write_buffer: [16 * 1024]u8,
    decompress: std.http.Decompress,

    fn open(
        transport: *StdHttpTransport,
        request: *Request,
        options: OpenOptions,
        owns_client: bool,
    ) !*HttpOperation {
        if (options.body != null and request.body != null) {
            return error.MultipleRequestBodies;
        }
        if (options.cancellation) |token| {
            if (token.isCancelled()) return error.OperationCancelled;
        }

        const allocator = transport.allocator;
        const self = try allocator.create(StdStreamingOperation);
        self.* = .{
            .operation = undefined,
            .allocator = allocator,
            .client = if (owns_client)
                .{ .allocator = allocator, .io = transport.io }
            else
                undefined,
            .client_ptr = undefined,
            .owns_client = owns_client,
            .request_headers = std.StringHashMap([]const u8).init(allocator),
            .extra_headers = &.{},
            .redirect_buffer = &.{},
            .decompress_buffer = &.{},
            .request = undefined,
            .request_active = false,
            .response = undefined,
            .transfer_reader = undefined,
            .transfer_buffer = undefined,
            .upload_read_buffer = undefined,
            .upload_write_buffer = undefined,
            .decompress = undefined,
        };
        self.client_ptr = if (owns_client) &self.client else &transport.client;
        errdefer {
            self.releaseRequest(true);
            self.cleanupStorage();
            allocator.destroy(self);
        }

        const framing = requestBodyFraming(request, options);
        try copyRequestHeaders(self, request, framing);
        self.redirect_buffer = try allocator.alloc(u8, 8 * 1024);

        const uri = try std.Uri.parse(request.url);
        self.request = try self.client_ptr.request(request.method.toStd(), uri, .{
            .extra_headers = self.extra_headers,
            .redirect_behavior = .unhandled,
        });
        self.request_active = true;
        self.request.accept_encoding[@intFromEnum(std.http.ContentEncoding.zstd)] = true;

        if (options.body) |body| {
            try self.sendStream(body, options.cancellation);
        } else if (request.body) |body| {
            try self.sendBytes(body);
        } else if (request.method.toStd().requestHasBody()) {
            try self.sendBytes("");
        } else {
            try self.request.sendBodiless();
        }

        self.response = try self.request.receiveHead(self.redirect_buffer);
        const status_code: u16 = @intFromEnum(self.response.head.status);
        var header_set = try copyResponseHeaders(allocator, &self.response.head);
        errdefer header_set.deinit(allocator);

        self.decompress_buffer = switch (self.response.head.content_encoding) {
            .identity => &.{},
            .zstd => try allocator.alloc(
                u8,
                std.compress.zstd.default_window_len + std.compress.zstd.block_size_max,
            ),
            .deflate, .gzip => try allocator.alloc(u8, std.compress.flate.max_window_len),
            .compress => return error.UnsupportedCompressionMethod,
        };
        self.transfer_reader =
            if (self.response.head.transfer_encoding != .none or
            self.response.head.content_length != null)
                &self.request.reader.interface
            else
                self.request.reader.in;
        const body_reader = self.response.readerDecompressing(
            &self.transfer_buffer,
            &self.decompress,
            self.decompress_buffer,
        );
        self.operation = .{
            .status_code = status_code,
            .headers = header_set.map,
            .response_headers = header_set.values,
            .body_reader = body_reader,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &abortImpl,
            .deinitFn = &deinitImpl,
            .bodyErrorFn = &bodyErrorImpl,
        };
        return &self.operation;
    }

    fn copyRequestHeaders(
        self: *StdStreamingOperation,
        request: *const Request,
        framing: BodyFraming,
    ) !void {
        var extra = std.ArrayList(std.http.Header).empty;
        defer extra.deinit(self.allocator);

        var iterator = request.headers.iterator();
        while (iterator.next()) |entry| {
            if (try validateFramingHeader(entry.key_ptr.*, entry.value_ptr.*, framing)) {
                continue;
            }
            const name = try self.allocator.dupe(u8, entry.key_ptr.*);
            errdefer self.allocator.free(name);
            const value = try self.allocator.dupe(u8, entry.value_ptr.*);
            errdefer self.allocator.free(value);
            try extra.append(self.allocator, .{ .name = name, .value = value });
            try self.request_headers.put(name, value);
        }
        self.extra_headers = try extra.toOwnedSlice(self.allocator);
    }

    fn sendBytes(self: *StdStreamingOperation, bytes: []const u8) !void {
        self.request.transfer_encoding = .{ .content_length = bytes.len };
        var writer = try self.request.sendBodyUnflushed(&self.upload_write_buffer);
        try writer.writer.writeAll(bytes);
        try writer.end();
    }

    fn sendStream(
        self: *StdStreamingOperation,
        body: StreamingRequestBody,
        cancellation: ?*const CancellationToken,
    ) !void {
        self.request.transfer_encoding = if (body.content_length) |length|
            .{ .content_length = length }
        else
            .chunked;
        var writer = try self.request.sendBodyUnflushed(&self.upload_write_buffer);

        if (body.content_length) |length| {
            var remaining = length;
            while (remaining > 0) {
                try checkCancelled(cancellation);
                const limit: usize = @intCast(@min(remaining, self.upload_read_buffer.len));
                const count = try body.reader.readSliceShort(self.upload_read_buffer[0..limit]);
                if (count == 0) return error.RequestBodyTooShort;
                try checkCancelled(cancellation);
                try writer.writer.writeAll(self.upload_read_buffer[0..count]);
                remaining -= count;
            }
            try checkCancelled(cancellation);
            var extra: [1]u8 = undefined;
            const extra_count = try body.reader.readSliceShort(&extra);
            try checkCancelled(cancellation);
            if (extra_count != 0) return error.RequestBodyTooLong;
        } else {
            while (true) {
                try checkCancelled(cancellation);
                const count = try body.reader.readSliceShort(&self.upload_read_buffer);
                try checkCancelled(cancellation);
                if (count == 0) break;
                try writer.writer.writeAll(self.upload_read_buffer[0..count]);
            }
        }
        try checkCancelled(cancellation);
        try writer.end();
    }

    fn finishImpl(operation: *HttpOperation) !void {
        const self: *StdStreamingOperation = @alignCast(@fieldParentPtr("operation", operation));
        _ = self.operation.body_reader.discardRemaining() catch |err| {
            const body_error = self.response.bodyErr();
            self.releaseRequest(true);
            return body_error orelse err;
        };
        if (self.transfer_reader != self.operation.body_reader) {
            _ = self.transfer_reader.discardRemaining() catch |err| {
                const body_error = self.response.bodyErr();
                self.releaseRequest(true);
                return body_error orelse err;
            };
        }
        self.releaseRequest(false);
    }

    fn abortImpl(operation: *HttpOperation) void {
        const self: *StdStreamingOperation = @alignCast(@fieldParentPtr("operation", operation));
        self.releaseRequest(true);
    }

    fn bodyErrorImpl(operation: *const HttpOperation) ?anyerror {
        const self: *const StdStreamingOperation = @alignCast(@fieldParentPtr("operation", operation));
        return self.response.bodyErr();
    }

    fn deinitImpl(operation: *HttpOperation) void {
        const self: *StdStreamingOperation = @alignCast(@fieldParentPtr("operation", operation));
        self.operation.response_headers.deinit();
        deinitOwnedHeaders(self.allocator, &self.operation.headers);
        self.cleanupStorage();
        self.allocator.destroy(self);
    }

    fn releaseRequest(self: *StdStreamingOperation, close: bool) void {
        if (self.request_active) {
            if (close) {
                if (self.request.connection) |connection| connection.closing = true;
            }
            self.request.deinit();
            self.request_active = false;
        }
    }

    fn cleanupStorage(self: *StdStreamingOperation) void {
        if (self.decompress_buffer.len > 0) self.allocator.free(self.decompress_buffer);
        if (self.redirect_buffer.len > 0) self.allocator.free(self.redirect_buffer);
        if (self.extra_headers.len > 0) self.allocator.free(self.extra_headers);
        deinitOwnedHeaders(self.allocator, &self.request_headers);
        if (self.owns_client) self.client.deinit();
    }
};

fn checkCancelled(cancellation: ?*const CancellationToken) !void {
    if (cancellation) |token| {
        if (token.isCancelled()) return error.OperationCancelled;
    }
}

fn requestBodyFraming(request: *const Request, options: OpenOptions) BodyFraming {
    if (options.body) |body| {
        return if (body.content_length) |length|
            .{ .content_length = length }
        else
            .chunked;
    }
    if (request.body) |body| return .{ .content_length = body.len };
    if (request.method.toStd().requestHasBody()) return .{ .content_length = 0 };
    return .none;
}

/// Returns true when the validated header must be omitted because std.http
/// emits it from `BodyFraming`.
fn validateFramingHeader(
    name: []const u8,
    value: []const u8,
    framing: BodyFraming,
) !bool {
    if (std.ascii.eqlIgnoreCase(name, "Content-Length")) {
        const expected = switch (framing) {
            .content_length => |length| length,
            .none, .chunked => return error.ConflictingRequestFraming,
        };
        const actual = std.fmt.parseInt(u64, std.mem.trim(u8, value, " \t"), 10) catch
            return error.ConflictingRequestFraming;
        if (actual != expected) return error.ConflictingRequestFraming;
        return true;
    }
    if (std.ascii.eqlIgnoreCase(name, "Transfer-Encoding")) {
        if (framing != .chunked or
            !std.ascii.eqlIgnoreCase(std.mem.trim(u8, value, " \t"), "chunked"))
        {
            return error.ConflictingRequestFraming;
        }
        return true;
    }
    return false;
}

const OwnedResponseHeaderSet = struct {
    map: std.StringHashMap([]const u8),
    values: ResponseHeaders,

    fn deinit(self: *OwnedResponseHeaderSet, allocator: std.mem.Allocator) void {
        self.values.deinit();
        deinitOwnedHeaders(allocator, &self.map);
    }
};

fn cloneOwnedResponseHeaderSet(
    allocator: std.mem.Allocator,
    source: *const std.StringHashMap([]const u8),
    response_headers: *const ResponseHeaders,
) !OwnedResponseHeaderSet {
    var result = std.StringHashMap([]const u8).init(allocator);
    errdefer deinitOwnedHeaders(allocator, &result);
    var iterator = source.iterator();
    while (iterator.next()) |entry| {
        const name = try allocator.dupe(u8, entry.key_ptr.*);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, entry.value_ptr.*);
        errdefer allocator.free(value);
        try result.put(name, value);
    }
    return .{
        .map = result,
        .values = try response_headers.clone(allocator),
    };
}

fn copyResponseHeaders(
    allocator: std.mem.Allocator,
    head: *const std.http.Client.Response.Head,
) !OwnedResponseHeaderSet {
    var headers = std.StringHashMap([]const u8).init(allocator);
    errdefer deinitOwnedHeaders(allocator, &headers);
    var values = ResponseHeaders.init(allocator);
    errdefer values.deinit();
    var iterator = head.iterateHeaders();
    while (iterator.next()) |header| {
        try values.append(header.name, header.value);
        const name = try allocator.dupe(u8, header.name);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, header.value);
        errdefer allocator.free(value);
        const gop = try headers.getOrPut(name);
        if (gop.found_existing) {
            allocator.free(name);
            allocator.free(gop.value_ptr.*);
            gop.value_ptr.* = value;
        } else {
            gop.key_ptr.* = name;
            gop.value_ptr.* = value;
        }
    }
    return .{ .map = headers, .values = values };
}

/// A transport that returns canned responses — for unit tests.
pub const MockTransport = struct {
    pub const HeaderPair = struct { name: []const u8, value: []const u8 };

    response_status: u16,
    response_body: []const u8,
    allocator: std.mem.Allocator,
    transport: HttpTransport,
    last_method: ?Method = null,
    last_url: ?[]u8 = null,
    last_headers: std.StringHashMap([]const u8),
    last_body: ?[]u8 = null,
    last_retryable: ?bool = null,
    last_redirect_policy: ?RedirectPolicy = null,
    last_operation_timeout_ms: ?u64 = null,
    call_count: usize = 0,
    response_headers_list: []const HeaderPair = &.{},
    stream_upload_chunk_size: usize = 4 * 1024,
    stream_response_chunk_size: usize = 4 * 1024,
    stream_fail_upload_after: ?usize = null,
    stream_fail_response_after: ?usize = null,
    stream_finish_count: usize = 0,
    stream_abort_count: usize = 0,
    stream_cancel_count: usize = 0,
    stream_deinit_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator, status: u16, body: []const u8) MockTransport {
        return .{
            .response_status = status,
            .response_body = body,
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl, .openFn = &openImpl },
            .last_method = null,
            .last_url = null,
            .last_headers = std.StringHashMap([]const u8).init(allocator),
            .last_redirect_policy = null,
            .call_count = 0,
        };
    }

    pub fn asTransport(self: *MockTransport) *HttpTransport {
        return &self.transport;
    }

    pub fn deinit(self: *MockTransport) void {
        if (self.last_url) |u| self.allocator.free(u);
        if (self.last_body) |body| self.allocator.free(body);
        deinitOwnedHeaders(self.allocator, &self.last_headers);
    }

    fn sendImpl(transport: *HttpTransport, request: *Request) !Response {
        const self: *MockTransport = @alignCast(@fieldParentPtr("transport", transport));
        try self.captureRequest(request, request.body);

        const response_body_copy = try self.allocator.dupe(u8, self.response_body);
        errdefer self.allocator.free(response_body_copy);
        var header_set = try self.copyResponseHeaders();
        errdefer header_set.deinit(self.allocator);
        return .{
            .status_code = self.response_status,
            .headers = header_set.map,
            .body = response_body_copy,
            .allocator = self.allocator,
            .response_headers = header_set.values,
        };
    }

    fn openImpl(
        transport: *HttpTransport,
        request: *Request,
        options: OpenOptions,
    ) !*HttpOperation {
        const self: *MockTransport = @alignCast(@fieldParentPtr("transport", transport));
        if (options.body != null and request.body != null) return error.MultipleRequestBodies;
        try checkCancelled(options.cancellation);
        const framing = requestBodyFraming(request, options);
        var framing_headers = request.headers.iterator();
        while (framing_headers.next()) |header| {
            _ = try validateFramingHeader(header.key_ptr.*, header.value_ptr.*, framing);
        }

        if (options.body) |body| {
            var captured: std.Io.Writer.Allocating = .init(self.allocator);
            errdefer captured.deinit();
            var buffer: [4 * 1024]u8 = undefined;
            var total: usize = 0;
            if (body.content_length) |length| {
                var remaining = length;
                while (remaining > 0) {
                    try checkCancelled(options.cancellation);
                    if (self.stream_fail_upload_after) |fail_after| {
                        if (total >= fail_after) return error.InjectedUploadFailure;
                    }
                    const read_limit: usize = @intCast(@min(
                        remaining,
                        @min(@max(self.stream_upload_chunk_size, 1), buffer.len),
                    ));
                    const count = try body.reader.readSliceShort(buffer[0..read_limit]);
                    try checkCancelled(options.cancellation);
                    if (count == 0) return error.RequestBodyTooShort;
                    captured.writer.writeAll(buffer[0..count]) catch return error.OutOfMemory;
                    total += count;
                    remaining -= count;
                }
                var extra: [1]u8 = undefined;
                const extra_count = try body.reader.readSliceShort(&extra);
                try checkCancelled(options.cancellation);
                if (extra_count != 0) return error.RequestBodyTooLong;
            } else {
                while (true) {
                    try checkCancelled(options.cancellation);
                    if (self.stream_fail_upload_after) |fail_after| {
                        if (total >= fail_after) return error.InjectedUploadFailure;
                    }
                    const read_limit = @min(
                        @max(self.stream_upload_chunk_size, 1),
                        buffer.len,
                    );
                    const count = try body.reader.readSliceShort(buffer[0..read_limit]);
                    try checkCancelled(options.cancellation);
                    if (count == 0) break;
                    captured.writer.writeAll(buffer[0..count]) catch return error.OutOfMemory;
                    total += count;
                }
            }
            const bytes = try captured.toOwnedSlice();
            defer self.allocator.free(bytes);
            try self.captureRequest(request, bytes);
        } else {
            try self.captureRequest(request, request.body);
        }

        return MockStreamingOperation.open(self);
    }

    fn captureRequest(
        self: *MockTransport,
        request: *Request,
        body: ?[]const u8,
    ) !void {
        self.call_count += 1;
        self.last_method = request.method;
        if (self.last_url) |old| self.allocator.free(old);
        self.last_url = null;
        self.last_url = try self.allocator.dupe(u8, request.url);
        if (self.last_body) |old| self.allocator.free(old);
        self.last_body = null;
        self.last_body = if (body) |bytes|
            try self.allocator.dupe(u8, bytes)
        else
            null;
        clearOwnedHeaders(self.allocator, &self.last_headers);
        var request_headers = request.headers.iterator();
        while (request_headers.next()) |header| {
            const name = try self.allocator.dupe(u8, header.key_ptr.*);
            errdefer self.allocator.free(name);
            const value = try self.allocator.dupe(u8, header.value_ptr.*);
            errdefer self.allocator.free(value);
            try self.last_headers.put(name, value);
        }
        self.last_retryable = request.retryable;
        self.last_redirect_policy = request.redirect_policy;
        self.last_operation_timeout_ms = request.operation_timeout_ms;
    }

    fn copyResponseHeaders(self: *MockTransport) !OwnedResponseHeaderSet {
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        errdefer deinitOwnedHeaders(self.allocator, &headers);
        var values = ResponseHeaders.init(self.allocator);
        errdefer values.deinit();
        for (self.response_headers_list) |hdr| {
            try values.append(hdr.name, hdr.value);
            const k = try self.allocator.dupe(u8, hdr.name);
            errdefer self.allocator.free(k);
            const v = try self.allocator.dupe(u8, hdr.value);
            errdefer self.allocator.free(v);
            const entry = try headers.getOrPut(k);
            if (entry.found_existing) {
                self.allocator.free(k);
                self.allocator.free(entry.value_ptr.*);
            } else {
                entry.key_ptr.* = k;
            }
            entry.value_ptr.* = v;
        }
        return .{ .map = headers, .values = values };
    }
};

const MockStreamingOperation = struct {
    operation: HttpOperation,
    allocator: std.mem.Allocator,
    owner: *MockTransport,
    response_body: []u8,
    response_reader: MockResponseReader,

    fn open(owner: *MockTransport) !*HttpOperation {
        const self = try owner.allocator.create(MockStreamingOperation);
        errdefer owner.allocator.destroy(self);
        const response_body = try owner.allocator.dupe(u8, owner.response_body);
        errdefer owner.allocator.free(response_body);
        var header_set = try owner.copyResponseHeaders();
        errdefer header_set.deinit(owner.allocator);

        self.* = .{
            .operation = undefined,
            .allocator = owner.allocator,
            .owner = owner,
            .response_body = response_body,
            .response_reader = undefined,
        };
        self.response_reader = MockResponseReader.init(
            response_body,
            owner.stream_response_chunk_size,
            owner.stream_fail_response_after,
        );
        self.operation = .{
            .status_code = owner.response_status,
            .headers = header_set.map,
            .response_headers = header_set.values,
            .body_reader = &self.response_reader.interface,
            .finishFn = &finishImpl,
            .abortFn = &abortImpl,
            .cancelFn = &cancelImpl,
            .deinitFn = &deinitImpl,
        };
        return &self.operation;
    }

    fn finishImpl(operation: *HttpOperation) !void {
        const self: *MockStreamingOperation = @alignCast(@fieldParentPtr("operation", operation));
        self.owner.stream_finish_count += 1;
        _ = try self.response_reader.interface.discardRemaining();
    }

    fn abortImpl(operation: *HttpOperation) void {
        const self: *MockStreamingOperation = @alignCast(@fieldParentPtr("operation", operation));
        self.owner.stream_abort_count += 1;
    }

    fn cancelImpl(operation: *HttpOperation) void {
        const self: *MockStreamingOperation = @alignCast(@fieldParentPtr("operation", operation));
        self.owner.stream_cancel_count += 1;
    }

    fn deinitImpl(operation: *HttpOperation) void {
        const self: *MockStreamingOperation = @alignCast(@fieldParentPtr("operation", operation));
        self.owner.stream_deinit_count += 1;
        self.operation.response_headers.deinit();
        deinitOwnedHeaders(self.allocator, &self.operation.headers);
        self.allocator.free(self.response_body);
        self.allocator.destroy(self);
    }
};

const MockResponseReader = struct {
    interface: std.Io.Reader,
    body: []const u8,
    offset: usize,
    chunk_size: usize,
    fail_after: ?usize,

    fn init(body: []const u8, chunk_size: usize, fail_after: ?usize) MockResponseReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .body = body,
            .offset = 0,
            .chunk_size = @max(chunk_size, 1),
            .fail_after = fail_after,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *MockResponseReader = @alignCast(@fieldParentPtr("interface", interface));
        if (self.fail_after) |fail_after| {
            if (self.offset >= fail_after) return error.ReadFailed;
        }
        if (self.offset >= self.body.len) return error.EndOfStream;

        var count = @min(
            self.body.len - self.offset,
            limit.minInt(self.chunk_size),
        );
        if (self.fail_after) |fail_after| {
            count = @min(count, fail_after - self.offset);
        }
        if (count == 0) return 0;
        try writer.writeAll(self.body[self.offset .. self.offset + count]);
        self.offset += count;
        return count;
    }
};

fn clearOwnedHeaders(
    allocator: std.mem.Allocator,
    headers: *std.StringHashMap([]const u8),
) void {
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    headers.clearRetainingCapacity();
}

fn getHeaderFromMap(
    headers: *const std.StringHashMap([]const u8),
    name: []const u8,
) ?[]const u8 {
    var iterator = headers.iterator();
    while (iterator.next()) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, name)) return entry.value_ptr.*;
    }
    return null;
}

fn deinitOwnedHeaders(
    allocator: std.mem.Allocator,
    headers: *std.StringHashMap([]const u8),
) void {
    clearOwnedHeaders(allocator, headers);
    headers.deinit();
}

/// A transport that returns a sequence of canned responses — for retry testing.
pub const SequenceMockTransport = struct {
    pub const CannedResponse = struct {
        status: u16,
        body: []const u8,
        headers: []const MockTransport.HeaderPair = &.{},
    };

    responses: []const CannedResponse,
    call_count: usize = 0,
    allocator: std.mem.Allocator,
    transport: HttpTransport,
    captured_methods: [16]?Method = .{null} ** 16,
    captured_authorization: [16]bool = .{false} ** 16,
    captured_url_lengths: [16]usize = .{0} ** 16,
    captured_urls: [16][512]u8 = undefined,
    captured_body_lengths: [16]usize = .{0} ** 16,
    captured_bodies: [16][512]u8 = undefined,

    pub fn init(allocator: std.mem.Allocator, responses: []const CannedResponse) SequenceMockTransport {
        return .{
            .responses = responses,
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl, .openFn = &openImpl },
        };
    }

    pub fn asTransport(self: *SequenceMockTransport) *HttpTransport {
        return &self.transport;
    }

    fn sendImpl(transport: *HttpTransport, request: *Request) !Response {
        const self: *SequenceMockTransport = @alignCast(@fieldParentPtr("transport", transport));
        const idx = try self.capture(request, request.body);
        return self.response(idx);
    }

    fn openImpl(
        transport: *HttpTransport,
        request: *Request,
        options: OpenOptions,
    ) !*HttpOperation {
        const self: *SequenceMockTransport = @alignCast(@fieldParentPtr("transport", transport));
        if (options.body != null and request.body != null) return error.MultipleRequestBodies;
        try checkCancelled(options.cancellation);
        const framing = requestBodyFraming(request, options);
        var framing_headers = request.headers.iterator();
        while (framing_headers.next()) |header| {
            _ = try validateFramingHeader(header.key_ptr.*, header.value_ptr.*, framing);
        }
        var body_bytes: ?[]const u8 = request.body;
        var captured: std.Io.Writer.Allocating = .init(self.allocator);
        defer captured.deinit();
        if (options.body) |body| {
            var buffer: [7]u8 = undefined;
            if (body.content_length) |length| {
                var remaining = length;
                while (remaining > 0) {
                    try checkCancelled(options.cancellation);
                    const limit: usize = @intCast(@min(remaining, buffer.len));
                    const count = try body.reader.readSliceShort(buffer[0..limit]);
                    if (count == 0) return error.RequestBodyTooShort;
                    try captured.writer.writeAll(buffer[0..count]);
                    remaining -= count;
                }
                var extra: [1]u8 = undefined;
                if (try body.reader.readSliceShort(&extra) != 0) return error.RequestBodyTooLong;
            } else {
                while (true) {
                    try checkCancelled(options.cancellation);
                    const count = try body.reader.readSliceShort(&buffer);
                    if (count == 0) break;
                    try captured.writer.writeAll(buffer[0..count]);
                }
            }
            body_bytes = captured.writer.buffered();
        }

        const idx = try self.capture(request, body_bytes);
        return BufferedOperation.fromResponse(try self.response(idx));
    }

    fn response(self: *SequenceMockTransport, idx: usize) !Response {
        const r = self.responses[idx];
        const body_copy = try self.allocator.dupe(u8, r.body);
        errdefer self.allocator.free(body_copy);
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        errdefer deinitOwnedHeaders(self.allocator, &headers);
        var response_headers = ResponseHeaders.init(self.allocator);
        errdefer response_headers.deinit();
        for (r.headers) |header| {
            try response_headers.append(header.name, header.value);
            const name = try self.allocator.dupe(u8, header.name);
            errdefer self.allocator.free(name);
            const value = try self.allocator.dupe(u8, header.value);
            errdefer self.allocator.free(value);
            const entry = try headers.getOrPut(name);
            if (entry.found_existing) {
                self.allocator.free(name);
                self.allocator.free(entry.value_ptr.*);
            } else {
                entry.key_ptr.* = name;
            }
            entry.value_ptr.* = value;
        }
        return .{
            .status_code = r.status,
            .headers = headers,
            .body = body_copy,
            .allocator = self.allocator,
            .response_headers = response_headers,
        };
    }

    fn capture(
        self: *SequenceMockTransport,
        request: *const Request,
        body: ?[]const u8,
    ) !usize {
        if (self.responses.len == 0) return error.NoCannedResponses;
        if (self.call_count >= self.captured_methods.len) return error.TooManyMockRequests;
        if (request.url.len > self.captured_urls[0].len) return error.MockRequestUrlTooLong;
        const body_value = body orelse "";
        if (body_value.len > self.captured_bodies[0].len) return error.MockRequestBodyTooLong;

        const call = self.call_count;
        self.captured_methods[call] = request.method;
        self.captured_authorization[call] = request.getHeader("Authorization") != null;
        @memcpy(self.captured_urls[call][0..request.url.len], request.url);
        self.captured_url_lengths[call] = request.url.len;
        @memcpy(self.captured_bodies[call][0..body_value.len], body_value);
        self.captured_body_lengths[call] = body_value.len;
        self.call_count += 1;
        return @min(call, self.responses.len - 1);
    }

    pub fn capturedUrl(self: *const SequenceMockTransport, index: usize) []const u8 {
        return self.captured_urls[index][0..self.captured_url_lengths[index]];
    }

    pub fn capturedBody(self: *const SequenceMockTransport, index: usize) []const u8 {
        return self.captured_bodies[index][0..self.captured_body_lengths[index]];
    }
};

test "request init and set header" {
    const allocator = std.testing.allocator;
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    try std.testing.expectEqual(RedirectPolicy.follow, req.redirect_policy);
    try std.testing.expectEqual(@as(?u64, null), req.operation_timeout_ms);
    req.redirect_policy = .not_allowed;
    try std.testing.expectEqual(RedirectPolicy.not_allowed, req.redirect_policy);
    try req.setHeader("Accept", "application/json");
    try std.testing.expectEqualStrings("application/json", req.headers.get("Accept").?);
    try req.setHeader("Accept", "application/xml");
    try std.testing.expectEqualStrings("application/xml", req.headers.get("Accept").?);
    try req.setHeader("accept", "application/json");
    try std.testing.expectEqual(@as(usize, 1), req.headers.count());
    try std.testing.expectEqualStrings("application/json", req.getHeader("ACCEPT").?);
    try std.testing.expectError(error.InvalidHttpHeaderName, req.setHeader("bad name", "value"));
    try std.testing.expectError(error.InvalidHttpHeaderValue, req.setHeader("x-value", "one\r\ntwo"));
}

test "response isSuccess" {
    var resp = Response{
        .status_code = 200,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, "ok"),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    try std.testing.expect(resp.isSuccess());
}

test "response header lookup preserves mixed-case duplicates" {
    const allocator = std.testing.allocator;
    var response_headers = ResponseHeaders.init(allocator);
    errdefer response_headers.deinit();
    try response_headers.append("Link", "</page/2>; rel=next");
    try response_headers.append("lInK", "</page/3>; rel=last");

    var resp = Response{
        .status_code = 200,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(u8, "ok"),
        .allocator = allocator,
        .response_headers = response_headers,
    };
    defer resp.deinit();
    try std.testing.expectEqualStrings("</page/2>; rel=next", resp.getHeader("LINK").?);
    const links = try resp.getHeaderValues(allocator, "link");
    defer allocator.free(links);
    try std.testing.expectEqual(@as(usize, 2), links.len);
    try std.testing.expectEqualStrings("</page/2>; rel=next", links[0]);
    try std.testing.expectEqualStrings("</page/3>; rel=last", links[1]);
    try std.testing.expect(resp.getHeader("missing") == null);
}

test "mock transport" {
    const allocator = std.testing.allocator;
    var mock = MockTransport.init(allocator, 200, "{\"status\":\"ok\"}");
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "Docker-Content-Digest", .value = "sha256:first" },
        .{ .name = "docker-content-digest", .value = "sha256:second" },
    };
    var req = Request.init(allocator, .POST, "https://vault.azure.net/secrets/mysecret");
    defer req.deinit();
    req.body = "{\"value\":\"secret-value\"}";
    req.redirect_policy = .not_allowed;
    req.operation_timeout_ms = 12_345;
    var resp = try mock.asTransport().send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
    try std.testing.expectEqualStrings("{\"status\":\"ok\"}", resp.body);
    try std.testing.expectEqual(Method.POST, mock.last_method.?);
    try std.testing.expectEqualStrings("https://vault.azure.net/secrets/mysecret", mock.last_url.?);
    try std.testing.expectEqualStrings("{\"value\":\"secret-value\"}", mock.last_body.?);
    try std.testing.expectEqual(RedirectPolicy.not_allowed, mock.last_redirect_policy.?);
    try std.testing.expectEqual(@as(?u64, 12_345), mock.last_operation_timeout_ms);
    try std.testing.expectEqual(@as(usize, 1), mock.call_count);
    try std.testing.expectEqualStrings("sha256:first", resp.getHeader("DOCKER-CONTENT-DIGEST").?);
    const digests = try resp.getHeaderValues(allocator, "docker-content-digest");
    defer allocator.free(digests);
    try std.testing.expectEqual(@as(usize, 2), digests.len);
    try std.testing.expectEqualStrings("sha256:first", digests[0]);
    try std.testing.expectEqualStrings("sha256:second", digests[1]);
}

test "mock streaming transport accepts known and chunked uploads" {
    const allocator = std.testing.allocator;
    var mock = MockTransport.init(allocator, 201, "response-data");
    defer mock.deinit();
    mock.stream_upload_chunk_size = 3;
    mock.stream_response_chunk_size = 2;

    {
        var known_source = std.Io.Reader.fixed("known-body");
        var known_request = Request.init(allocator, .POST, "https://example.com/known");
        defer known_request.deinit();
        var known = try mock.asTransport().open(&known_request, .{
            .body = .{ .reader = &known_source, .content_length = 10 },
        });
        defer known.deinit();
        try std.testing.expectEqual(@as(u16, 201), known.status_code);
        try std.testing.expectEqualStrings("known-body", mock.last_body.?);
        var response_buffer: [32]u8 = undefined;
        const first_count = try (try known.reader()).readSliceShort(response_buffer[0..3]);
        try std.testing.expect(first_count > 0);
        try known.finish();
    }

    {
        var chunked_source = std.Io.Reader.fixed("chunked-body");
        var chunked_request = Request.init(allocator, .POST, "https://example.com/chunked");
        defer chunked_request.deinit();
        var chunked = try mock.asTransport().open(&chunked_request, .{
            .body = .{ .reader = &chunked_source },
        });
        defer chunked.deinit();
        try std.testing.expectEqualStrings("chunked-body", mock.last_body.?);
        chunked.abort();
    }

    try std.testing.expectEqual(@as(usize, 2), mock.call_count);
    try std.testing.expectEqual(@as(usize, 1), mock.stream_finish_count);
    try std.testing.expectEqual(@as(usize, 1), mock.stream_abort_count);
    try std.testing.expectEqual(@as(usize, 2), mock.stream_deinit_count);
}

test "ReplayableBytes rewinds without copying" {
    var replay = ReplayableBytes.init("replay-body");
    var body = replay.body();
    var buffer: [32]u8 = undefined;
    const first = try body.reader.readSliceShort(&buffer);
    try std.testing.expectEqualStrings("replay-body", buffer[0..first]);
    try body.rewind();
    const second = try body.reader.readSliceShort(&buffer);
    try std.testing.expectEqualStrings("replay-body", buffer[0..second]);
}

test "transport follows safe redirects and strips cross-origin authorization" {
    const allocator = std.testing.allocator;
    var sequence = SequenceMockTransport.init(allocator, &.{
        .{
            .status = 307,
            .body = "",
            .headers = &.{.{ .name = "Location", .value = "https://storage.example/blob" }},
        },
        .{ .status = 200, .body = "ok" },
    });
    var request = Request.init(allocator, .POST, "https://registry.example/v2/upload");
    defer request.deinit();
    try request.setHeader("Authorization", "Bearer registry-token");
    var replay = ReplayableBytes.init("payload");
    var operation = try sequence.asTransport().open(&request, .{ .body = replay.body() });
    defer operation.deinit();
    try std.testing.expectEqual(@as(u16, 200), operation.status_code);
    try std.testing.expectEqual(@as(usize, 2), sequence.call_count);
    try std.testing.expect(sequence.captured_authorization[0]);
    try std.testing.expect(!sequence.captured_authorization[1]);
    try std.testing.expectEqual(Method.POST, sequence.captured_methods[1].?);
    try std.testing.expectEqualStrings("payload", sequence.capturedBody(0));
    try std.testing.expectEqualStrings("payload", sequence.capturedBody(1));
    try std.testing.expectEqualStrings("https://storage.example/blob", sequence.capturedUrl(1));
    try operation.finish();

    var buffered_sequence = SequenceMockTransport.init(allocator, &.{
        .{
            .status = 308,
            .body = "",
            .headers = &.{.{ .name = "Location", .value = "/v2/continued" }},
        },
        .{ .status = 200, .body = "buffered-ok" },
    });
    var buffered_request = Request.init(allocator, .PUT, "https://registry.example/v2/upload");
    defer buffered_request.deinit();
    buffered_request.body = "buffered-payload";
    try buffered_request.setHeader("Authorization", "Bearer registry-token");
    var response = try buffered_sequence.asTransport().send(&buffered_request);
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expectEqualStrings("buffered-ok", response.body);
    try std.testing.expectEqual(@as(usize, 2), buffered_sequence.call_count);
    try std.testing.expect(buffered_sequence.captured_authorization[1]);
    try std.testing.expectEqual(Method.PUT, buffered_sequence.captured_methods[1].?);
    try std.testing.expectEqualStrings("buffered-payload", buffered_sequence.capturedBody(1));
    try std.testing.expectEqualStrings(
        "https://registry.example/v2/continued",
        buffered_sequence.capturedUrl(1),
    );
}

test "transport does not replay one-shot bodies and rejects insecure redirects" {
    const allocator = std.testing.allocator;
    const redirect_headers = &.{MockTransport.HeaderPair{
        .name = "Location",
        .value = "https://storage.example/blob",
    }};
    var one_shot_sequence = SequenceMockTransport.init(allocator, &.{
        .{ .status = 308, .body = "", .headers = redirect_headers },
        .{ .status = 200, .body = "unexpected" },
    });
    var request = Request.init(allocator, .PUT, "https://registry.example/v2/upload");
    defer request.deinit();
    var source = std.Io.Reader.fixed("one-shot");
    var operation = try one_shot_sequence.asTransport().open(&request, .{
        .body = StreamingRequestBody.knownLength(&source, 8),
    });
    defer operation.deinit();
    try std.testing.expectEqual(@as(u16, 308), operation.status_code);
    try std.testing.expectEqual(@as(usize, 1), one_shot_sequence.call_count);
    operation.abort();

    var insecure_sequence = SequenceMockTransport.init(allocator, &.{
        .{
            .status = 307,
            .body = "",
            .headers = &.{.{ .name = "Location", .value = "http://storage.example/blob" }},
        },
    });
    var insecure_request = Request.init(allocator, .GET, "https://registry.example/v2/blob");
    defer insecure_request.deinit();
    try std.testing.expectError(
        error.HttpsRequired,
        insecure_sequence.asTransport().send(&insecure_request),
    );
    try std.testing.expectEqual(@as(usize, 1), insecure_sequence.call_count);

    var disabled_sequence = SequenceMockTransport.init(allocator, &.{
        .{ .status = 307, .body = "", .headers = redirect_headers },
        .{ .status = 200, .body = "unexpected" },
    });
    var disabled_request = Request.init(allocator, .GET, "https://registry.example/v2/blob");
    defer disabled_request.deinit();
    disabled_request.redirect_policy = .not_allowed;
    var disabled_response = try disabled_sequence.asTransport().send(&disabled_request);
    defer disabled_response.deinit();
    try std.testing.expectEqual(@as(u16, 307), disabled_response.status_code);
    try std.testing.expectEqual(@as(usize, 1), disabled_sequence.call_count);
}

test "mock streaming transport validates upload lengths and failures" {
    const allocator = std.testing.allocator;
    var mock = MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();

    var short_source = std.Io.Reader.fixed("short");
    var request = Request.init(allocator, .POST, "https://example.com");
    defer request.deinit();
    try std.testing.expectError(
        error.RequestBodyTooShort,
        mock.asTransport().open(&request, .{
            .body = .{ .reader = &short_source, .content_length = 6 },
        }),
    );

    var long_source = std.Io.Reader.fixed("long");
    try std.testing.expectError(
        error.RequestBodyTooLong,
        mock.asTransport().open(&request, .{
            .body = .{ .reader = &long_source, .content_length = 3 },
        }),
    );

    mock.stream_fail_upload_after = 2;
    mock.stream_upload_chunk_size = 2;
    var failing_source = std.Io.Reader.fixed("failure");
    try std.testing.expectError(
        error.InjectedUploadFailure,
        mock.asTransport().open(&request, .{
            .body = .{ .reader = &failing_source },
        }),
    );

    try request.setHeader("Content-Length", "99");
    var conflicting_source = std.Io.Reader.fixed("body");
    try std.testing.expectError(
        error.ConflictingRequestFraming,
        mock.asTransport().open(&request, .{
            .body = .{ .reader = &conflicting_source, .content_length = 4 },
        }),
    );
}

test "mock streaming response failure cancellation and cleanup" {
    const allocator = std.testing.allocator;
    var mock = MockTransport.init(allocator, 200, "response");
    defer mock.deinit();
    mock.stream_response_chunk_size = 2;
    mock.stream_fail_response_after = 4;

    var request = Request.init(allocator, .GET, "https://example.com");
    defer request.deinit();
    var operation = try mock.asTransport().open(&request, .{});
    defer operation.deinit();
    var buffer: [8]u8 = undefined;
    try std.testing.expectError(
        error.ReadFailed,
        (try operation.reader()).readSliceShort(&buffer),
    );
    operation.cancel();
    try std.testing.expectEqual(OperationState.cancelled, operation.state);
    try std.testing.expectEqual(@as(usize, 1), mock.stream_cancel_count);

    var failed_finish = try mock.asTransport().open(&request, .{});
    defer failed_finish.deinit();
    try std.testing.expectError(error.ReadFailed, failed_finish.finish());
    try std.testing.expectEqual(OperationState.aborted, failed_finish.state);
    try std.testing.expectEqual(@as(usize, 1), mock.stream_abort_count);

    var token = CancellationToken{};
    token.cancel();
    try std.testing.expectError(
        error.OperationCancelled,
        mock.asTransport().open(&request, .{ .cancellation = &token }),
    );

    var active_token = CancellationToken{};
    var cancelling_source = CancellingReader.init(&active_token);
    var upload_request = Request.init(allocator, .POST, "https://example.com/upload");
    defer upload_request.deinit();
    try std.testing.expectError(
        error.OperationCancelled,
        mock.asTransport().open(&upload_request, .{
            .body = .{ .reader = &cancelling_source.interface },
            .cancellation = &active_token,
        }),
    );
}

test "buffered transport adapts to response streaming" {
    const allocator = std.testing.allocator;
    const responses = [_]SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body = "buffered" },
    };
    var mock = SequenceMockTransport.init(allocator, &responses);
    var request = Request.init(allocator, .GET, "https://example.com");
    defer request.deinit();
    var operation = try mock.asTransport().open(&request, .{});
    defer operation.deinit();
    const body = try (try operation.reader()).allocRemaining(allocator, .unlimited);
    defer allocator.free(body);
    try std.testing.expectEqualStrings("buffered", body);
    try operation.finish();
}

test "standard transport streams known and chunked uploads with decompression" {
    const cases = [_]struct {
        content_length: ?u64,
        encoding: []const u8,
        encoded_response: []const u8,
        chunked_response: bool,
    }{
        .{
            .content_length = 21,
            .encoding = "gzip",
            .encoded_response = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x02\x03\x2b\x2e\x29\x4a\x4d\xcc\x4d\x4d\x51\x48\xce\xcf\x2d\x28\x4a\x2d\x2e\x06\x32\x81\x54\x41\x7e\x5e\x71\x2a\x00\xa6\x80\xb4\x50\x1c\x00\x00\x00",
            .chunked_response = true,
        },
        .{
            .content_length = null,
            .encoding = "deflate",
            .encoded_response = "\x78\x9c\x2b\x2e\x29\x4a\x4d\xcc\x4d\x4d\x51\x48\xce\xcf\x2d\x28\x4a\x2d\x2e\x06\x32\x81\x54\x41\x7e\x5e\x71\x2a\x00\xa2\x5a\x0b\x3a",
            .chunked_response = false,
        },
        .{
            .content_length = null,
            .encoding = "zstd",
            .encoded_response = "\x28\xb5\x2f\xfd\x04\x58\xe1\x00\x00\x73\x74\x72\x65\x61\x6d\x65\x64\x20\x63\x6f\x6d\x70\x72\x65\x73\x73\x65\x64\x20\x72\x65\x73\x70\x6f\x6e\x73\x65\xa9\xca\xdc\xf0",
            .chunked_response = false,
        },
    };
    for (cases) |case| {
        try runStdStreamingCase(
            case.content_length,
            case.encoding,
            case.encoded_response,
            case.chunked_response,
        );
    }
}

fn runStdStreamingCase(
    content_length: ?u64,
    encoding: []const u8,
    encoded_response: []const u8,
    chunked_response: bool,
) !void {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var address: std.Io.net.IpAddress = .{ .ip4 = .loopback(0) };
    var server = try address.listen(io, .{ .reuse_address = true });
    defer server.deinit(io);

    var context = LocalHttpServer{
        .io = io,
        .server = &server,
        .encoding = encoding,
        .encoded_response = encoded_response,
        .chunked_response = chunked_response,
    };
    const thread = try std.Thread.spawn(.{}, LocalHttpServer.run, .{&context});

    const url = try std.fmt.allocPrint(
        allocator,
        "http://127.0.0.1:{d}/stream",
        .{server.socket.address.getPort()},
    );
    defer allocator.free(url);

    var transport = StdHttpTransport.init(allocator, io);
    var request = Request.init(allocator, .POST, url);
    defer request.deinit();
    var source = std.Io.Reader.fixed("streaming upload body");
    var operation = transport.asTransport().open(&request, .{
        .body = .{ .reader = &source, .content_length = content_length },
    }) catch |err| {
        transport.deinit();
        thread.join();
        if (context.failure) |failure| return failure;
        return err;
    };
    transport.deinit();
    defer operation.deinit();
    try std.testing.expectEqualStrings("first", operation.getHeader("x-test").?);
    const test_headers = try operation.getHeaderValues(allocator, "X-Test");
    defer allocator.free(test_headers);
    try std.testing.expectEqual(@as(usize, 2), test_headers.len);
    try std.testing.expectEqualStrings("first", test_headers[0]);
    try std.testing.expectEqualStrings("second", test_headers[1]);

    var response: std.Io.Writer.Allocating = .init(allocator);
    defer response.deinit();
    _ = try (try operation.reader()).streamRemaining(&response.writer);
    try std.testing.expectEqualStrings(
        "streamed compressed response",
        response.writer.buffered(),
    );
    try operation.finish();
    thread.join();
    if (context.failure) |failure| return failure;
    try std.testing.expectEqualStrings("streaming upload body", context.received[0..context.received_len]);
    try std.testing.expectEqual(content_length == null, context.saw_chunked);
}

const LocalHttpServer = struct {
    io: std.Io,
    server: *std.Io.net.Server,
    encoding: []const u8,
    encoded_response: []const u8,
    chunked_response: bool,
    received: [128]u8 = undefined,
    received_len: usize = 0,
    saw_chunked: bool = false,
    failure: ?anyerror = null,

    fn run(self: *LocalHttpServer) void {
        self.serve() catch |err| {
            self.failure = err;
        };
    }

    fn serve(self: *LocalHttpServer) !void {
        const stream = try self.server.accept(self.io);
        defer stream.close(self.io);
        var read_buffer: [1024]u8 = undefined;
        var reader = std.Io.net.Stream.Reader.init(stream, self.io, &read_buffer);
        var write_buffer: [1024]u8 = undefined;
        var writer = std.Io.net.Stream.Writer.init(stream, self.io, &write_buffer);

        var content_length: ?usize = null;
        while (true) {
            const raw_line = (reader.interface.takeDelimiter('\n') catch
                return error.ServerHeaderReadFailed) orelse
                return error.ServerHeaderReadFailed;
            const line = std.mem.trimEnd(u8, raw_line, "\r");
            if (line.len == 0) break;
            if (std.ascii.startsWithIgnoreCase(line, "content-length:")) {
                const value = std.mem.trim(u8, line["content-length:".len..], " ");
                content_length = try std.fmt.parseInt(usize, value, 10);
            } else if (std.ascii.startsWithIgnoreCase(line, "transfer-encoding:")) {
                const value = std.mem.trim(u8, line["transfer-encoding:".len..], " ");
                self.saw_chunked = std.ascii.eqlIgnoreCase(value, "chunked");
            }
        }

        if (self.saw_chunked) {
            while (true) {
                const raw_size = (reader.interface.takeDelimiter('\n') catch
                    return error.ServerChunkHeaderReadFailed) orelse
                    return error.ServerChunkHeaderReadFailed;
                const size_text = std.mem.trim(u8, raw_size, "\r ");
                const size = try std.fmt.parseInt(usize, size_text, 16);
                if (size == 0) {
                    _ = (reader.interface.takeDelimiter('\n') catch
                        return error.ServerChunkTrailerReadFailed) orelse
                        return error.ServerChunkTrailerReadFailed;
                    break;
                }
                if (self.received_len + size > self.received.len) return error.UploadTooLarge;
                reader.interface.readSliceAll(
                    self.received[self.received_len .. self.received_len + size],
                ) catch return error.ServerChunkBodyReadFailed;
                self.received_len += size;
                var crlf: [2]u8 = undefined;
                reader.interface.readSliceAll(&crlf) catch
                    return error.ServerChunkTerminatorReadFailed;
                if (!std.mem.eql(u8, &crlf, "\r\n")) return error.InvalidChunk;
            }
        } else {
            const length = content_length orelse return error.MissingContentLength;
            if (length > self.received.len) return error.UploadTooLarge;
            reader.interface.readSliceAll(self.received[0..length]) catch
                return error.ServerBodyReadFailed;
            self.received_len = length;
        }

        const midpoint = self.encoded_response.len / 2;
        if (self.chunked_response) {
            try writer.interface.print(
                "HTTP/1.1 200 OK\r\nContent-Encoding: {s}\r\nX-Test: first\r\nx-test: second\r\nTransfer-Encoding: chunked\r\n\r\n{x}\r\n",
                .{ self.encoding, midpoint },
            );
            try writer.interface.writeAll(self.encoded_response[0..midpoint]);
            try writer.interface.print(
                "\r\n{x}\r\n",
                .{self.encoded_response.len - midpoint},
            );
            try writer.interface.writeAll(self.encoded_response[midpoint..]);
            try writer.interface.writeAll("\r\n0\r\n\r\n");
        } else {
            try writer.interface.print(
                "HTTP/1.1 200 OK\r\nContent-Encoding: {s}\r\nX-Test: first\r\nx-test: second\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n",
                .{ self.encoding, self.encoded_response.len },
            );
            try writer.interface.writeAll(self.encoded_response[0..midpoint]);
            try writer.interface.flush();
            try writer.interface.writeAll(self.encoded_response[midpoint..]);
        }
        try writer.interface.flush();
    }
};

const CancellingReader = struct {
    interface: std.Io.Reader,
    token: *CancellationToken,
    emitted: bool = false,

    fn init(token: *CancellationToken) CancellingReader {
        return .{
            .interface = .{
                .vtable = &.{ .stream = &stream },
                .buffer = &.{},
                .seek = 0,
                .end = 0,
            },
            .token = token,
        };
    }

    fn stream(
        interface: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *CancellingReader = @alignCast(@fieldParentPtr("interface", interface));
        if (self.emitted) return error.EndOfStream;
        const bytes = limit.sliceConst("part");
        try writer.writeAll(bytes);
        self.emitted = true;
        self.token.cancel();
        return bytes.len;
    }
};

fn mockStreamingAllocationFixture(allocator: std.mem.Allocator) !void {
    var mock = MockTransport.init(allocator, 200, "response");
    defer mock.deinit();
    mock.response_headers_list = &.{.{ .name = "x-test", .value = "value" }};
    var request = Request.init(allocator, .POST, "https://example.com");
    defer request.deinit();
    try request.setHeader("content-type", "application/octet-stream");
    var source = std.Io.Reader.fixed("request");
    var operation = try mock.asTransport().open(&request, .{
        .body = .{ .reader = &source, .content_length = 7 },
    });
    defer operation.deinit();
    try operation.finish();
}

test "mock streaming operation releases every allocation failure path" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        mockStreamingAllocationFixture,
        .{},
    );
}

fn redirectAllocationFixture(allocator: std.mem.Allocator) !void {
    var sequence = SequenceMockTransport.init(allocator, &.{
        .{
            .status = 307,
            .body = "",
            .headers = &.{.{ .name = "Location", .value = "https://storage.example/blob" }},
        },
        .{ .status = 200, .body = "ok" },
    });
    var request = Request.init(allocator, .PUT, "https://registry.example/v2/upload");
    defer request.deinit();
    request.body = "body";
    try request.setHeader("Authorization", "Bearer token");
    var response = sequence.asTransport().send(&request) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => |other| return other,
    };
    defer response.deinit();
}

test "redirect handling releases every allocation failure path" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        redirectAllocationFixture,
        .{},
    );
}
