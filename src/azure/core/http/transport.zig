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

    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
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
pub const StdHttpTransport = struct {
    allocator: std.mem.Allocator,
    transport: HttpTransport,

    pub fn init(allocator: std.mem.Allocator) StdHttpTransport {
        return .{
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl },
        };
    }

    pub fn asTransport(self: *StdHttpTransport) *HttpTransport {
        return &self.transport;
    }

    fn sendImpl(transport: *HttpTransport, request: *Request) !Response {
        const self: *StdHttpTransport = @fieldParentPtr("transport", transport);
        const allocator = self.allocator;

        const uri = try std.Uri.parse(request.url);

        var client: std.http.Client = .{ .allocator = allocator };
        defer client.deinit();

        var header_buf: [16 * 1024]u8 = undefined;

        const method: std.http.Method = switch (request.method) {
            .GET => .GET,
            .POST => .POST,
            .PUT => .PUT,
            .DELETE => .DELETE,
            .PATCH => .PATCH,
            .HEAD => .HEAD,
            .OPTIONS => .OPTIONS,
        };

        var extra_headers = std.ArrayList(std.http.Header).init(allocator);
        defer extra_headers.deinit();

        var it = request.headers.iterator();
        while (it.next()) |entry| {
            try extra_headers.append(.{
                .name = entry.key_ptr.*,
                .value = entry.value_ptr.*,
            });
        }

        var req = try client.open(method, uri, .{
            .server_header_buffer = &header_buf,
            .extra_headers = extra_headers.items,
        });
        defer req.deinit();

        if (request.body) |body| {
            req.transfer_encoding = .{ .content_length = body.len };
        }

        try req.send();

        if (request.body) |body| {
            try req.writer().writeAll(body);
            try req.finish();
        }

        try req.wait();

        const body = try req.reader().readAllAlloc(allocator, 10 * 1024 * 1024);

        const resp_headers = std.StringHashMap([]const u8).init(allocator);
        // Response headers could be parsed from header_buf if needed.

        return .{
            .status_code = @intFromEnum(req.status),
            .headers = resp_headers,
            .body = body,
            .allocator = allocator,
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
