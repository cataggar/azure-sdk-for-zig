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

/// An outgoing HTTP request.
pub const Request = struct {
    method: Method = .GET,
    url: []const u8,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8 = null,
    allocator: std.mem.Allocator,

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
        try self.headers.put(key, value);
    }

    pub fn deinit(self: *Request) void {
        self.headers.deinit();
    }
};

/// An HTTP response.
pub const Response = struct {
    status_code: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn isSuccess(self: Response) bool {
        return self.status_code >= 200 and self.status_code < 300;
    }

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
        // Free heap-allocated header keys/values from StdHttpTransport.
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }
};

/// Pluggable HTTP transport interface.
///
/// Default implementation uses `std.http.Client` (TLS via `std.crypto.tls`).
/// Users may supply their own for testing or custom networking.
pub const HttpTransport = struct {
    sendFn: *const fn (self: *HttpTransport, request: *Request) anyerror!Response,

    pub fn send(self: *HttpTransport, request: *Request) !Response {
        return self.sendFn(self, request);
    }
};

/// Default transport backed by `std.http.Client`.
///
/// Requires `std.Io` (threaded or evented) for TLS, DNS, and socket I/O.
pub const StdHttpTransport = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    transport: HttpTransport,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) StdHttpTransport {
        return .{
            .allocator = allocator,
            .io = io,
            .transport = .{ .sendFn = &sendImpl },
        };
    }

    pub fn asTransport(self: *StdHttpTransport) *HttpTransport {
        return &self.transport;
    }

    fn sendImpl(transport: *HttpTransport, request: *Request) !Response {
        const self: *StdHttpTransport = @fieldParentPtr("transport", transport);
        const allocator = self.allocator;

        var client: std.http.Client = .{ .allocator = allocator, .io = self.io };
        defer client.deinit();

        // Convert request headers to std.http.Header slices.
        var extra = std.ArrayList(std.http.Header).empty;
        defer extra.deinit(allocator);
        var privileged = std.ArrayList(std.http.Header).empty;
        defer privileged.deinit(allocator);

        var it = request.headers.iterator();
        while (it.next()) |entry| {
            const header = std.http.Header{ .name = entry.key_ptr.*, .value = entry.value_ptr.* };
            if (std.mem.eql(u8, entry.key_ptr.*, "Authorization")) {
                try privileged.append(allocator, header);
            } else {
                try extra.append(allocator, header);
            }
        }

        const uri = try std.Uri.parse(request.url);

        // Use lower-level API to access response headers.
        var req = try client.request(request.method.toStd(), uri, .{
            .extra_headers = extra.items,
            .privileged_headers = privileged.items,
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
        errdefer resp_headers.deinit();
        var header_it = response.head.iterateHeaders();
        while (header_it.next()) |hdr| {
            const name = try allocator.dupe(u8, hdr.name);
            errdefer allocator.free(name);
            const value = try allocator.dupe(u8, hdr.value);
            try resp_headers.put(name, value);
        }

        // Read body with decompression support.
        var response_body: std.ArrayList(u8) = .empty;
        errdefer response_body.deinit(allocator);
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
        _ = reader.streamRemaining(response_body.writer(allocator).any()) catch |err| switch (err) {
            error.ReadFailed => return response.bodyErr().?,
            else => |e| return e,
        };

        return .{
            .status_code = @intFromEnum(response.head.status),
            .headers = resp_headers,
            .body = try response_body.toOwnedSlice(allocator),
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
    response_headers_list: []const HeaderPair = &.{},

    pub fn init(allocator: std.mem.Allocator, status: u16, body: []const u8) MockTransport {
        return .{
            .response_status = status,
            .response_body = body,
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl },
            .last_method = null,
            .last_url = null,
        };
    }

    pub fn asTransport(self: *MockTransport) *HttpTransport {
        return &self.transport;
    }

    pub fn deinit(self: *MockTransport) void {
        if (self.last_url) |u| self.allocator.free(u);
    }

    fn sendImpl(transport: *HttpTransport, request: *Request) !Response {
        const self: *MockTransport = @fieldParentPtr("transport", transport);
        self.last_method = request.method;
        if (self.last_url) |old| self.allocator.free(old);
        self.last_url = try self.allocator.dupe(u8, request.url);

        const body_copy = try self.allocator.dupe(u8, self.response_body);
        var headers = std.StringHashMap([]const u8).init(self.allocator);
        for (self.response_headers_list) |hdr| {
            const k = try self.allocator.dupe(u8, hdr.name);
            errdefer self.allocator.free(k);
            const v = try self.allocator.dupe(u8, hdr.value);
            try headers.put(k, v);
        }
        return .{
            .status_code = self.response_status,
            .headers = headers,
            .body = body_copy,
            .allocator = self.allocator,
        };
    }
};

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
        const self: *SequenceMockTransport = @fieldParentPtr("transport", transport);
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
    try req.setHeader("Accept", "application/json");
    try std.testing.expectEqualStrings("application/json", req.headers.get("Accept").?);
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

test "mock transport" {
    const allocator = std.testing.allocator;
    var mock = MockTransport.init(allocator, 200, "{\"status\":\"ok\"}");
    defer mock.deinit();
    var req = Request.init(allocator, .POST, "https://vault.azure.net/secrets/mysecret");
    defer req.deinit();
    var resp = try mock.asTransport().send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
    try std.testing.expectEqualStrings("{\"status\":\"ok\"}", resp.body);
    try std.testing.expectEqual(Method.POST, mock.last_method.?);
}
