///! Azure SDK Test Framework — mock transport, recording/playback, helpers.
///!
///! Built on `std.testing` with Azure-specific utilities.
const std = @import("std");
const core = @import("azure_core");

/// A recorded HTTP exchange for playback.
pub const RecordedExchange = struct {
    request_method: core.http.Method,
    request_url: []const u8,
    response_status: u16,
    response_body: []const u8,
};

/// Playback transport — replays a sequence of recorded exchanges in order.
pub const PlaybackTransport = struct {
    recordings: []const RecordedExchange,
    index: usize = 0,
    allocator: std.mem.Allocator,
    transport: core.http.HttpTransport,

    pub fn init(allocator: std.mem.Allocator, recordings: []const RecordedExchange) PlaybackTransport {
        return .{
            .recordings = recordings,
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl },
        };
    }

    pub fn asTransport(self: *PlaybackTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn sendImpl(transport: *core.http.HttpTransport, request: *core.http.Request) !core.http.Response {
        const self: *PlaybackTransport = @fieldParentPtr("transport", transport);
        if (self.index >= self.recordings.len) return error.NoMoreRecordings;

        const rec = self.recordings[self.index];
        self.index += 1;

        if (rec.request_method != request.method) return error.MethodMismatch;

        const body_copy = try self.allocator.dupe(u8, rec.response_body);
        const headers = std.StringHashMap([]const u8).init(self.allocator);
        return .{
            .status_code = rec.response_status,
            .headers = headers,
            .body = body_copy,
            .allocator = self.allocator,
        };
    }
};

/// Assert a response is successful (2xx).
pub fn expectSuccess(resp: core.http.Response) !void {
    if (!resp.isSuccess()) {
        std.log.err("Expected 2xx but got {d}", .{resp.status_code});
        return error.UnexpectedStatus;
    }
}

/// Assert a response has a specific status code.
pub fn expectStatus(resp: core.http.Response, expected: u16) !void {
    try std.testing.expectEqual(expected, resp.status_code);
}

// ─────────────────────── Tests ───────────────────────

test "PlaybackTransport replays recordings" {
    const allocator = std.testing.allocator;
    const recordings = [_]RecordedExchange{
        .{ .request_method = .GET, .request_url = "/secrets/s1", .response_status = 200, .response_body = "{\"value\":\"v1\"}" },
        .{ .request_method = .PUT, .request_url = "/secrets/s2", .response_status = 200, .response_body = "{\"value\":\"v2\"}" },
    };
    var playback = PlaybackTransport.init(allocator, &recordings);

    var req1 = core.http.Request.init(allocator, .GET, "/secrets/s1");
    defer req1.deinit();
    var resp1 = try playback.asTransport().send(&req1);
    defer resp1.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp1.status_code);

    var req2 = core.http.Request.init(allocator, .PUT, "/secrets/s2");
    defer req2.deinit();
    var resp2 = try playback.asTransport().send(&req2);
    defer resp2.deinit();
    try std.testing.expectEqualStrings("{\"value\":\"v2\"}", resp2.body);
}

test "PlaybackTransport detects method mismatch" {
    const allocator = std.testing.allocator;
    const recordings = [_]RecordedExchange{
        .{ .request_method = .POST, .request_url = "/x", .response_status = 200, .response_body = "{}" },
    };
    var playback = PlaybackTransport.init(allocator, &recordings);
    var req = core.http.Request.init(allocator, .GET, "/x");
    defer req.deinit();
    try std.testing.expectError(error.MethodMismatch, playback.asTransport().send(&req));
}

test "expectSuccess" {
    var resp = core.http.Response{
        .status_code = 200,
        .headers = std.StringHashMap([]const u8).init(std.testing.allocator),
        .body = try std.testing.allocator.dupe(u8, "ok"),
        .allocator = std.testing.allocator,
    };
    defer resp.deinit();
    try expectSuccess(resp);
}
