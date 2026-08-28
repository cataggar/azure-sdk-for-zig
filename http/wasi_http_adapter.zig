//! Target-neutral request adaptation for WASI-style HTTP hosts.
//!
//! The canonical-ABI extern implementation lives in `wasi_http.zig`. Keeping
//! URL/header adaptation here permits native tests to inject a fake host
//! without claiming runtime coverage for a WASI engine.

const std = @import("std");
const transport = @import("transport.zig");

pub const Scheme = enum {
    http,
    https,
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const HostRequest = struct {
    method: transport.Method,
    scheme: Scheme,
    authority: []const u8,
    path_with_query: []const u8,
    headers: *const std.StringHashMap([]const u8),
};

pub const HostResponse = struct {
    status_code: u16,
    headers: []const Header = &.{},
    /// Allocated by the host with the allocator passed to `send`.
    body: []u8,
};

/// Build an `HttpTransport` around a host value exposing:
///
/// `send(allocator, HostRequest) !HostResponse`.
pub fn HttpTransportAdapter(comptime Host: type) type {
    return struct {
        allocator: std.mem.Allocator,
        host: Host,

        const Self = @This();
        const vtable: transport.HttpTransport.VTable = .{ .send = &sendImpl };

        pub fn init(allocator: std.mem.Allocator, host: Host) Self {
            return .{ .allocator = allocator, .host = host };
        }

        pub fn asTransport(self: *Self) transport.HttpTransport {
            return .{ .context = self, .vtable = &vtable };
        }

        fn sendImpl(
            context: *anyopaque,
            request: *transport.Request,
        ) !transport.Response {
            const self: *Self = @ptrCast(@alignCast(context));
            if (request.body != null) return error.RequestBodyUnsupported;

            const sep = std.mem.indexOf(u8, request.url, "://") orelse
                return error.InvalidUrl;
            const scheme_text = request.url[0..sep];
            const scheme: Scheme = if (std.ascii.eqlIgnoreCase(scheme_text, "http"))
                .http
            else if (std.ascii.eqlIgnoreCase(scheme_text, "https"))
                .https
            else
                return error.InvalidUrl;
            const after_scheme = request.url[sep + 3 ..];
            const slash = std.mem.indexOfScalar(u8, after_scheme, '/') orelse
                after_scheme.len;
            const authority = after_scheme[0..slash];
            if (authority.len == 0) return error.InvalidUrl;
            const path_with_query = if (slash < after_scheme.len)
                after_scheme[slash..]
            else
                "/";

            const host_response = try self.host.send(self.allocator, .{
                .method = request.method,
                .scheme = scheme,
                .authority = authority,
                .path_with_query = path_with_query,
                .headers = &request.headers,
            });
            errdefer self.allocator.free(host_response.body);

            var headers = std.StringHashMap([]const u8).init(self.allocator);
            errdefer deinitHeaders(self.allocator, &headers);
            var ordered = transport.ResponseHeaders.init(self.allocator);
            errdefer ordered.deinit();
            for (host_response.headers) |header| {
                try ordered.append(header.name, header.value);
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
                .status_code = host_response.status_code,
                .headers = headers,
                .body = host_response.body,
                .allocator = self.allocator,
                .response_headers = ordered,
            };
        }
    };
}

fn deinitHeaders(
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

test "native fake host exercises target-neutral WASI adaptation" {
    const FakeHost = struct {
        calls: usize = 0,
        method: ?transport.Method = null,
        scheme: ?Scheme = null,
        authority: []const u8 = "",
        path: []const u8 = "",
        saw_host: bool = false,

        fn send(
            self: *@This(),
            allocator: std.mem.Allocator,
            request: HostRequest,
        ) !HostResponse {
            self.calls += 1;
            self.method = request.method;
            self.scheme = request.scheme;
            self.authority = request.authority;
            self.path = request.path_with_query;
            var headers = request.headers.iterator();
            while (headers.next()) |header| {
                if (std.ascii.eqlIgnoreCase(header.key_ptr.*, "host")) {
                    self.saw_host = true;
                }
            }
            return .{
                .status_code = 202,
                .headers = &.{
                    .{ .name = "X-Test", .value = "first" },
                    .{ .name = "x-test", .value = "second" },
                },
                .body = try allocator.dupe(u8, "fake-host"),
            };
        }
    };

    var fake = FakeHost{};
    var adapter = HttpTransportAdapter(*FakeHost).init(
        std.testing.allocator,
        &fake,
    );
    var request = transport.Request.init(
        std.testing.allocator,
        .GET,
        "https://example.com:8443/path?query=yes",
    );
    defer request.deinit();
    try request.setHeader("Host", "ignored.example");
    var response = try adapter.asTransport().send(&request);
    defer response.deinit();

    try std.testing.expectEqual(@as(usize, 1), fake.calls);
    try std.testing.expectEqual(transport.Method.GET, fake.method.?);
    try std.testing.expectEqual(Scheme.https, fake.scheme.?);
    try std.testing.expectEqualStrings("example.com:8443", fake.authority);
    try std.testing.expectEqualStrings("/path?query=yes", fake.path);
    try std.testing.expect(fake.saw_host);
    try std.testing.expectEqualStrings("fake-host", response.body);
    const values = try response.getHeaderValues(std.testing.allocator, "x-test");
    defer std.testing.allocator.free(values);
    try std.testing.expectEqual(@as(usize, 2), values.len);
    try std.testing.expectEqualStrings("first", values[0]);
    try std.testing.expectEqualStrings("second", values[1]);

    var body_request = transport.Request.init(
        std.testing.allocator,
        .POST,
        "https://example.com/",
    );
    defer body_request.deinit();
    body_request.body = "unsupported";
    try std.testing.expectError(
        error.RequestBodyUnsupported,
        adapter.asTransport().send(&body_request),
    );
    try std.testing.expectEqual(@as(usize, 1), fake.calls);
}
