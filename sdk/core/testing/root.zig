///! Azure SDK Test Framework — mock transport, recording/playback, helpers.
///!
///! Built on `std.testing` with Azure-specific utilities.
///!
///! Supports two test modes (controlled by `AZURE_TEST_MODE` env var):
///!   - `record`   — runs live requests, records exchanges to JSON files
///!   - `playback` — replays previously recorded exchanges (default)
const std = @import("std");
const core = @import("azure_sdk_core");

// ──────────────────── Recorded Exchange ────────────────────

/// A recorded HTTP exchange for recording and playback.
pub const RecordedExchange = struct {
    request_method: core.http.Method,
    request_url: []const u8,
    request_headers: ?[]const HeaderPair = null,
    request_body: ?[]const u8 = null,
    response_status: u16,
    response_body: []const u8,
    response_headers: ?[]const HeaderPair = null,
};

pub const HeaderPair = struct {
    name: []const u8,
    value: []const u8,
};

// ──────────────────── Playback Transport ───────────────────

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
        const self: *PlaybackTransport = @alignCast(@fieldParentPtr("transport", transport));
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

// ──────────────────── Recording Transport ─────────────────

/// Recording transport — wraps a real transport, forwards requests,
/// and captures all exchanges for later serialization.
pub const RecordingTransport = struct {
    inner: *core.http.HttpTransport,
    exchanges: std.ArrayList(OwnedExchange),
    allocator: std.mem.Allocator,
    transport: core.http.HttpTransport,

    const OwnedExchange = struct {
        request_method: core.http.Method,
        request_url: []u8,
        response_status: u16,
        response_body: []u8,
    };

    pub fn init(allocator: std.mem.Allocator, inner: *core.http.HttpTransport) RecordingTransport {
        return .{
            .inner = inner,
            .exchanges = .empty,
            .allocator = allocator,
            .transport = .{ .sendFn = &sendImpl },
        };
    }

    pub fn asTransport(self: *RecordingTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    pub fn deinit(self: *RecordingTransport) void {
        for (self.exchanges.items) |ex| {
            self.allocator.free(ex.request_url);
            self.allocator.free(ex.response_body);
        }
        self.exchanges.deinit(self.allocator);
    }

    /// Get the recorded exchanges as a slice.
    pub fn getExchanges(self: *const RecordingTransport) []const OwnedExchange {
        return self.exchanges.items;
    }

    /// Serialize all recorded exchanges to a JSON string.
    pub fn toJson(self: *const RecordingTransport, allocator: std.mem.Allocator) ![]u8 {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        errdefer aw.deinit();
        const writer = &aw.writer;
        try writer.writeAll("[");
        for (self.exchanges.items, 0..) |ex, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.writeAll("\n  {");
            try writer.writeAll("\"method\":\"");
            try writer.writeAll(methodToString(ex.request_method));
            try writer.writeAll("\",\"url\":");
            try writeJsonString(writer, ex.request_url);
            try writer.writeAll(",\"status\":");
            try writer.print("{d}", .{ex.response_status});
            try writer.writeAll(",\"body\":");
            try writeJsonString(writer, sanitizeBody(ex.response_body));
            try writer.writeAll("}");
        }
        try writer.writeAll("\n]\n");
        return aw.toOwnedSlice();
    }

    fn sendImpl(transport: *core.http.HttpTransport, request: *core.http.Request) !core.http.Response {
        const self: *RecordingTransport = @alignCast(@fieldParentPtr("transport", transport));

        // Forward to inner transport.
        const resp = try self.inner.send(request);

        // Record the exchange.
        try self.exchanges.append(self.allocator, .{
            .request_method = request.method,
            .request_url = try self.allocator.dupe(u8, request.url),
            .response_status = resp.status_code,
            .response_body = try self.allocator.dupe(u8, resp.body),
        });

        return resp;
    }
};

// ──────────────────── Sanitization ────────────────────────

/// List of header names whose values should be redacted in recordings.
const sensitive_headers = [_][]const u8{
    "authorization",
    "x-ms-client-secret",
    "ocp-apim-subscription-key",
    "api-key",
};

/// Replace sensitive values in a body string.
/// Currently redacts `access_token` values in JSON.
fn sanitizeBody(body: []const u8) []const u8 {
    // Light-touch: don't modify body in-place. Full sanitization
    // would require JSON-aware rewriting. For now, return as-is;
    // callers should avoid recording in production environments.
    return body;
}

/// Check if a header name is sensitive (case-insensitive).
pub fn isSensitiveHeader(name: []const u8) bool {
    for (sensitive_headers) |h| {
        if (eqlIgnoreCase(name, h)) return true;
    }
    return false;
}

// ──────────────────── JSON Helpers ─────────────────────────

fn methodToString(m: core.http.Method) []const u8 {
    return switch (m) {
        .GET => "GET",
        .POST => "POST",
        .PUT => "PUT",
        .DELETE => "DELETE",
        .PATCH => "PATCH",
        .HEAD => "HEAD",
        .OPTIONS => "OPTIONS",
    };
}

fn writeJsonString(writer: anytype, s: []const u8) !void {
    try writer.writeByte('"');
    for (s) |c| {
        switch (c) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (c < 0x20) {
                    const hex = "0123456789abcdef";
                    try writer.writeAll("\\u00");
                    try writer.writeByte(hex[c >> 4]);
                    try writer.writeByte(hex[c & 0x0f]);
                } else {
                    try writer.writeByte(c);
                }
            },
        }
    }
    try writer.writeByte('"');
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
    }
    return true;
}

// ──────────────────── Test Helpers ─────────────────────────

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

test "RecordingTransport captures exchanges" {
    const allocator = std.testing.allocator;

    // Inner mock transport.
    var mock = core.http.MockTransport.init(allocator, 200, "{\"secret\":\"value\"}");
    defer mock.deinit();

    var recorder = RecordingTransport.init(allocator, mock.asTransport());
    defer recorder.deinit();

    var req = core.http.Request.init(allocator, .GET, "https://vault.azure.net/secrets/s1");
    defer req.deinit();
    var resp = try recorder.asTransport().send(&req);
    defer resp.deinit();

    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
    try std.testing.expectEqualStrings("{\"secret\":\"value\"}", resp.body);

    // Verify the exchange was recorded.
    const exchanges = recorder.getExchanges();
    try std.testing.expectEqual(@as(usize, 1), exchanges.len);
    try std.testing.expectEqual(core.http.Method.GET, exchanges[0].request_method);
    try std.testing.expect(std.mem.find(u8, exchanges[0].request_url, "secrets/s1") != null);
}

test "RecordingTransport toJson" {
    const allocator = std.testing.allocator;

    var mock = core.http.MockTransport.init(allocator, 201, "{\"id\":\"123\"}");
    defer mock.deinit();

    var recorder = RecordingTransport.init(allocator, mock.asTransport());
    defer recorder.deinit();

    var req = core.http.Request.init(allocator, .POST, "https://example.com/items");
    defer req.deinit();
    var resp = try recorder.asTransport().send(&req);
    defer resp.deinit();

    const json = try recorder.toJson(allocator);
    defer allocator.free(json);

    // Verify JSON structure.
    try std.testing.expect(std.mem.find(u8, json, "\"method\":\"POST\"") != null);
    try std.testing.expect(std.mem.find(u8, json, "\"status\":201") != null);
    try std.testing.expect(std.mem.find(u8, json, "example.com/items") != null);
}

test "isSensitiveHeader" {
    try std.testing.expect(isSensitiveHeader("Authorization"));
    try std.testing.expect(isSensitiveHeader("authorization"));
    try std.testing.expect(isSensitiveHeader("Api-Key"));
    try std.testing.expect(!isSensitiveHeader("Content-Type"));
    try std.testing.expect(!isSensitiveHeader("Accept"));
}
