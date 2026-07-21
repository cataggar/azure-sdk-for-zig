const std = @import("std");

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

    pub fn getHeader(self: *Request, key: []const u8) ?[]const u8 {
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

/// An HTTP response.
pub const Response = struct {
    status_code: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn isSuccess(self: Response) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }

    pub fn getHeader(self: *const Response, key: []const u8) ?[]const u8 {
        var iterator = self.headers.iterator();
        while (iterator.next()) |entry| {
            if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, key)) {
                return entry.value_ptr.*;
            }
        }
        return null;
    }

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
        deinitOwnedHeaders(self.allocator, &self.headers);
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

    pub fn send(self: *HttpTransport, request: *Request) !Response {
        return self.sendFn(self, request);
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
    client: std.http.Client,
    transport: HttpTransport,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) StdHttpTransport {
        return .{
            .allocator = allocator,
            .client = .{ .allocator = allocator, .io = io },
            .transport = .{ .sendFn = &sendImpl },
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

        // Convert request headers to std.http.Header slices.
        //
        // Authenticated requests must not follow redirects because
        // `extra_headers` are retained across cross-origin redirects.
        var extra = std.ArrayList(std.http.Header).empty;
        defer extra.deinit(allocator);
        var authenticated = false;

        var it = request.headers.iterator();
        while (it.next()) |entry| {
            const header = std.http.Header{ .name = entry.key_ptr.*, .value = entry.value_ptr.* };
            try extra.append(allocator, header);
            if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, "Authorization")) {
                authenticated = true;
            }
        }

        const uri = try std.Uri.parse(request.url);

        // Use lower-level API to access response headers.
        var req = try self.client.request(request.method.toStd(), uri, .{
            .extra_headers = extra.items,
            .redirect_behavior = if (authenticated or request.redirect_policy == .not_allowed)
                .not_allowed
            else
                @enumFromInt(3),
        });
        defer req.deinit();

        // Send body if present.
        if (request.body) |payload| {
            req.transfer_encoding = .{ .content_length = payload.len };
            var body_writer = try req.sendBodyUnflushed(&.{});
            try body_writer.writer.writeAll(payload);
            try body_writer.end();
            try req.connection.?.flush();
        } else {
            try req.sendBodiless();
        }

        // Receive response head.
        const redirect_buf = try allocator.alloc(u8, 8 * 1024);
        defer allocator.free(redirect_buf);
        var response = try req.receiveHead(redirect_buf);

        // Capture response headers before reading body (body invalidates head strings).
        var resp_headers = std.StringHashMap([]const u8).init(allocator);
        errdefer deinitOwnedHeaders(allocator, &resp_headers);
        var header_it = response.head.iterateHeaders();
        while (header_it.next()) |hdr| {
            const name = try allocator.dupe(u8, hdr.name);
            errdefer allocator.free(name);
            const value = try allocator.dupe(u8, hdr.value);
            errdefer allocator.free(value);

            // ARM may return the same header twice (e.g. ratelimit counters).
            // `put` would silently leak the prior key+value pair, so use
            // `getOrPut` and free our duplicate ourselves.
            const gop = try resp_headers.getOrPut(name);
            if (gop.found_existing) {
                allocator.free(name);
                allocator.free(gop.value_ptr.*);
                gop.value_ptr.* = value;
            } else {
                gop.key_ptr.* = name;
                gop.value_ptr.* = value;
            }
        }

        // Read body with decompression support.
        var body_allocating: std.Io.Writer.Allocating = .init(allocator);
        errdefer body_allocating.deinit();
        var transfer_buffer: [64]u8 = undefined;
        var decompress: std.http.Decompress = undefined;
        const decompress_buffer: []u8 = switch (response.head.content_encoding) {
            .identity => &.{},
            .zstd => try allocator.alloc(u8, std.compress.zstd.default_window_len),
            .deflate, .gzip => try allocator.alloc(u8, std.compress.flate.max_window_len),
            .compress => return error.UnsupportedCompressionMethod,
        };
        defer if (decompress_buffer.len > 0) allocator.free(decompress_buffer);
        const reader = response.readerDecompressing(&transfer_buffer, &decompress, decompress_buffer);
        _ = reader.streamRemaining(&body_allocating.writer) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            error.WriteFailed => return error.OutOfMemory,
        };

        return .{
            .status_code = @intFromEnum(response.head.status),
            .headers = resp_headers,
            .body = try body_allocating.toOwnedSlice(),
            .allocator = allocator,
        };
    }
};

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

    pub fn init(allocator: std.mem.Allocator, status: u16, body: []const u8) MockTransport {
        return .{
            .response_status = status,
            .response_body = body,
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl },
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
        self.call_count += 1;
        self.last_method = request.method;
        if (self.last_url) |old| self.allocator.free(old);
        self.last_url = null;
        self.last_url = try self.allocator.dupe(u8, request.url);
        if (self.last_body) |old| self.allocator.free(old);
        self.last_body = null;
        self.last_body = if (request.body) |body|
            try self.allocator.dupe(u8, body)
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

        const response_body_copy = try self.allocator.dupe(u8, self.response_body);
        errdefer self.allocator.free(response_body_copy);
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        errdefer deinitOwnedHeaders(self.allocator, &headers);
        for (self.response_headers_list) |hdr| {
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
        return .{
            .status_code = self.response_status,
            .headers = headers,
            .body = response_body_copy,
            .allocator = self.allocator,
        };
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

fn deinitOwnedHeaders(
    allocator: std.mem.Allocator,
    headers: *std.StringHashMap([]const u8),
) void {
    clearOwnedHeaders(allocator, headers);
    headers.deinit();
}

/// A transport that returns a sequence of canned responses — for retry testing.
pub const SequenceMockTransport = struct {
    pub const CannedResponse = struct { status: u16, body: []const u8 };

    responses: []const CannedResponse,
    call_count: usize = 0,
    allocator: std.mem.Allocator,
    transport: HttpTransport,

    pub fn init(allocator: std.mem.Allocator, responses: []const CannedResponse) SequenceMockTransport {
        return .{
            .responses = responses,
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl },
        };
    }

    pub fn asTransport(self: *SequenceMockTransport) *HttpTransport {
        return &self.transport;
    }

    fn sendImpl(transport: *HttpTransport, request: *Request) !Response {
        const self: *SequenceMockTransport = @alignCast(@fieldParentPtr("transport", transport));
        _ = request;
        const idx = @min(self.call_count, self.responses.len - 1);
        self.call_count += 1;
        const r = self.responses[idx];
        const body_copy = try self.allocator.dupe(u8, r.body);
        const headers = std.StringHashMap([]const u8).init(self.allocator);
        return .{
            .status_code = r.status,
            .headers = headers,
            .body = body_copy,
            .allocator = self.allocator,
        };
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

test "response header lookup is case-insensitive" {
    const allocator = std.testing.allocator;
    var headers = std.StringHashMap([]const u8).init(allocator);
    const name = try allocator.dupe(u8, "X-MS-Activity-Id");
    errdefer allocator.free(name);
    const value = try allocator.dupe(u8, "activity-id");
    errdefer allocator.free(value);
    try headers.put(name, value);

    var resp = Response{
        .status_code = 200,
        .headers = headers,
        .body = try allocator.dupe(u8, "ok"),
        .allocator = allocator,
    };
    defer resp.deinit();
    try std.testing.expectEqualStrings("activity-id", resp.getHeader("x-ms-activity-id").?);
    try std.testing.expect(resp.getHeader("missing") == null);
}

test "mock transport" {
    const allocator = std.testing.allocator;
    var mock = MockTransport.init(allocator, 200, "{\"status\":\"ok\"}");
    defer mock.deinit();
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
}
