const std = @import("std");
const transport = @import("transport.zig");

const Request = transport.Request;
const Response = transport.Response;
const HttpTransport = transport.HttpTransport;

/// A single stage in the HTTP pipeline.
///
/// Policies form a chain: each receives the request, may modify it,
/// then calls `next` to pass it down the pipeline.
pub const HttpPolicy = struct {
    processFn: *const fn (
        self: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) anyerror!Response,

    pub fn process(
        self: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        return self.processFn(self, request, next, final_transport);
    }
};

/// Ordered chain of policy pointers that terminates at an `HttpTransport`.
pub const HttpPipeline = struct {
    policies: []*HttpPolicy,
    transport_impl: *HttpTransport,

    pub fn send(self: *HttpPipeline, request: *Request) !Response {
        return callNext(request, self.policies, self.transport_impl);
    }
};

/// Advance through the remaining policies, calling the transport at the end.
fn callNext(request: *Request, next: []*HttpPolicy, final_transport: *HttpTransport) !Response {
    if (next.len == 0) {
        return final_transport.send(request);
    }
    return next[0].process(request, next[1..], final_transport);
}

// ───────────────────────────── Policies ─────────────────────────────

/// Injects `User-Agent` header.
pub const TelemetryPolicy = struct {
    user_agent: []const u8,
    policy: HttpPolicy,

    pub fn init(user_agent: []const u8) TelemetryPolicy {
        return .{
            .user_agent = user_agent,
            .policy = .{ .processFn = &processImpl },
        };
    }

    pub fn asPolicy(self: *TelemetryPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        const self: *TelemetryPolicy = @fieldParentPtr("policy", policy);
        try request.setHeader("User-Agent", self.user_agent);
        return callNext(request, next, final_transport);
    }
};

/// Logs request method + URL via `std.log`.
pub const LoggingPolicy = struct {
    policy: HttpPolicy,

    pub fn init() LoggingPolicy {
        return .{ .policy = .{ .processFn = &processImpl } };
    }

    pub fn asPolicy(self: *LoggingPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn processImpl(
        _: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        std.log.info("azure-sdk: {s} {s}", .{ @tagName(request.method), request.url });
        const response = try callNext(request, next, final_transport);
        std.log.info("azure-sdk: {d} {s}", .{ response.status_code, request.url });
        return response;
    }
};

/// Retries failed requests with exponential back-off and jitter.
///
/// Retries on server errors (5xx) and throttling (429). Honors the
/// `Retry-After` response header when present.
pub const RetryPolicy = struct {
    max_retries: u32 = 3,
    initial_delay_ms: u64 = 800,
    max_delay_ms: u64 = 60_000,
    policy: HttpPolicy,

    pub fn init() RetryPolicy {
        return .{
            .policy = .{ .processFn = &processImpl },
        };
    }

    pub fn asPolicy(self: *RetryPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn isRetryable(status: u16) bool {
        return status == 429 or status == 408 or status == 500 or
            status == 502 or status == 503 or status == 504;
    }

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        const self: *RetryPolicy = @fieldParentPtr("policy", policy);
        var attempt: u32 = 0;
        var prng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
        while (true) {
            const result = callNext(request, next, final_transport);
            if (result) |resp| {
                if (!isRetryable(resp.status_code) or attempt >= self.max_retries) return resp;

                // Check for Retry-After header (seconds).
                const retry_after_ms = parseRetryAfter(resp) orelse 0;

                var r = resp;
                r.deinit();

                attempt += 1;
                if (retry_after_ms > 0) {
                    // Honor server's Retry-After, capped at max_delay.
                    const delay = @min(retry_after_ms, self.max_delay_ms);
                    std.Thread.sleep(delay * std.time.ns_per_ms);
                } else {
                    const base_delay = @min(
                        self.initial_delay_ms * (@as(u64, 1) << @intCast(attempt - 1)),
                        self.max_delay_ms,
                    );
                    const jitter = prng.random().uintLessThan(u64, @max(base_delay, 1));
                    const delay = base_delay / 2 + jitter / 2;
                    std.Thread.sleep(delay * std.time.ns_per_ms);
                }
            } else |err| {
                if (attempt >= self.max_retries) return err;
                attempt += 1;
                const base_delay = @min(
                    self.initial_delay_ms * (@as(u64, 1) << @intCast(attempt - 1)),
                    self.max_delay_ms,
                );
                const jitter = prng.random().uintLessThan(u64, @max(base_delay, 1));
                const delay = base_delay / 2 + jitter / 2;
                std.Thread.sleep(delay * std.time.ns_per_ms);
            }
        }
    }

    fn parseRetryAfter(resp: Response) ?u64 {
        const value = resp.headers.get("Retry-After") orelse
            resp.headers.get("retry-after") orelse
            return null;
        return std.fmt.parseInt(u64, value, 10) catch null;
    }
};

/// Injects `Authorization: Bearer <token>` using a `TokenCredential`.
pub const BearerTokenAuthPolicy = struct {
    const creds = @import("../credentials/token.zig");

    credential: *creds.TokenCredential,
    scopes: []const []const u8,
    policy: HttpPolicy,

    pub fn init(credential: *creds.TokenCredential, scopes: []const []const u8) BearerTokenAuthPolicy {
        return .{
            .credential = credential,
            .scopes = scopes,
            .policy = .{ .processFn = &processImpl },
        };
    }

    pub fn asPolicy(self: *BearerTokenAuthPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        const self: *BearerTokenAuthPolicy = @fieldParentPtr("policy", policy);
        const ctx = @import("../context.zig").Context.none;
        const token = try self.credential.getToken(
            .{ .scopes = self.scopes },
            ctx,
        );
        const auth_value = try std.fmt.allocPrint(
            request.allocator,
            "Bearer {s}",
            .{token.token},
        );
        try request.setHeader("Authorization", auth_value);
        return callNext(request, next, final_transport);
    }
};

/// Injects `x-ms-client-request-id` with a unique UUID per request.
pub const RequestIdPolicy = struct {
    policy: HttpPolicy,

    pub fn init() RequestIdPolicy {
        return .{ .policy = .{ .processFn = &processImpl } };
    }

    pub fn asPolicy(self: *RequestIdPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn processImpl(
        _: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        const uuid_mod = @import("../uuid.zig");
        var prng = std.Random.DefaultPrng.init(@bitCast(std.time.timestamp()));
        const id = uuid_mod.Uuid.init(prng.random());
        const id_str = id.toString();
        const id_owned = try request.allocator.dupe(u8, &id_str);
        try request.setHeader("x-ms-client-request-id", id_owned);
        return callNext(request, next, final_transport);
    }
};

test "pipeline with telemetry and mock transport" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var telemetry = TelemetryPolicy.init("azsdk-zig-test/0.1.0");
    var policy_ptrs = [_]*HttpPolicy{telemetry.asPolicy()};
    var pipeline_inst = HttpPipeline{
        .policies = &policy_ptrs,
        .transport_impl = mock.asTransport(),
    };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pipeline_inst.send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
    try std.testing.expectEqualStrings("azsdk-zig-test/0.1.0", req.headers.get("User-Agent").?);
}

test "pipeline with no policies" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 404, "not found");
    defer mock.deinit();
    var empty = [_]*HttpPolicy{};
    var pipeline_inst = HttpPipeline{
        .policies = &empty,
        .transport_impl = mock.asTransport(),
    };
    var req = Request.init(allocator, .GET, "https://example.com/missing");
    defer req.deinit();
    var resp = try pipeline_inst.send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 404), resp.status_code);
}

test "pipeline with multiple policies" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var telemetry = TelemetryPolicy.init("azsdk-zig-test/0.1.0");
    var logging = LoggingPolicy.init();
    var policy_ptrs = [_]*HttpPolicy{ telemetry.asPolicy(), logging.asPolicy() };
    var pipeline_inst = HttpPipeline{
        .policies = &policy_ptrs,
        .transport_impl = mock.asTransport(),
    };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pipeline_inst.send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
}

test "RequestIdPolicy injects x-ms-client-request-id" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var rid = RequestIdPolicy.init();
    var policy_ptrs = [_]*HttpPolicy{rid.asPolicy()};
    var pipeline_inst = HttpPipeline{
        .policies = &policy_ptrs,
        .transport_impl = mock.asTransport(),
    };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pipeline_inst.send(&req);
    defer resp.deinit();
    const request_id = req.headers.get("x-ms-client-request-id").?;
    defer allocator.free(request_id);
    // UUID format: 8-4-4-4-12 = 36 chars.
    try std.testing.expectEqual(@as(usize, 36), request_id.len);
    try std.testing.expectEqual(@as(u8, '-'), request_id[8]);
}

test "RetryPolicy passes through 200 without retry" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var retry = RetryPolicy.init();
    var policy_ptrs = [_]*HttpPolicy{retry.asPolicy()};
    var pip = HttpPipeline{ .policies = &policy_ptrs, .transport_impl = mock.asTransport() };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pip.send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
}

test "RetryPolicy passes through 404 without retry" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 404, "not found");
    defer mock.deinit();
    var retry = RetryPolicy.init();
    var policy_ptrs = [_]*HttpPolicy{retry.asPolicy()};
    var pip = HttpPipeline{ .policies = &policy_ptrs, .transport_impl = mock.asTransport() };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pip.send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 404), resp.status_code);
}

test "RetryPolicy retries 500 then succeeds" {
    const allocator = std.testing.allocator;
    var seq = transport.SequenceMockTransport.init(allocator, &.{
        .{ .status = 500, .body = "error" },
        .{ .status = 200, .body = "ok" },
    });
    // Retry with zero delay for test speed.
    var retry = RetryPolicy.init();
    retry.initial_delay_ms = 0;
    var policy_ptrs = [_]*HttpPolicy{retry.asPolicy()};
    var pip = HttpPipeline{ .policies = &policy_ptrs, .transport_impl = seq.asTransport() };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pip.send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
    try std.testing.expectEqual(@as(usize, 2), seq.call_count);
}

test "RetryPolicy retries 429 then succeeds" {
    const allocator = std.testing.allocator;
    var seq = transport.SequenceMockTransport.init(allocator, &.{
        .{ .status = 429, .body = "throttled" },
        .{ .status = 200, .body = "ok" },
    });
    var retry = RetryPolicy.init();
    retry.initial_delay_ms = 0;
    var policy_ptrs = [_]*HttpPolicy{retry.asPolicy()};
    var pip = HttpPipeline{ .policies = &policy_ptrs, .transport_impl = seq.asTransport() };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pip.send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 200), resp.status_code);
    try std.testing.expectEqual(@as(usize, 2), seq.call_count);
}

test "RetryPolicy gives up after max retries" {
    const allocator = std.testing.allocator;
    var seq = transport.SequenceMockTransport.init(allocator, &.{
        .{ .status = 503, .body = "unavailable" },
    });
    var retry = RetryPolicy.init();
    retry.initial_delay_ms = 0;
    retry.max_retries = 2;
    var policy_ptrs = [_]*HttpPolicy{retry.asPolicy()};
    var pip = HttpPipeline{ .policies = &policy_ptrs, .transport_impl = seq.asTransport() };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pip.send(&req);
    defer resp.deinit();
    // After 2 retries (3 total attempts), returns the last 503.
    try std.testing.expectEqual(@as(u16, 503), resp.status_code);
    try std.testing.expectEqual(@as(usize, 3), seq.call_count);
}

test "isRetryable status codes" {
    try std.testing.expect(RetryPolicy.isRetryable(429));
    try std.testing.expect(RetryPolicy.isRetryable(500));
    try std.testing.expect(RetryPolicy.isRetryable(502));
    try std.testing.expect(RetryPolicy.isRetryable(503));
    try std.testing.expect(RetryPolicy.isRetryable(504));
    try std.testing.expect(RetryPolicy.isRetryable(408));
    try std.testing.expect(!RetryPolicy.isRetryable(200));
    try std.testing.expect(!RetryPolicy.isRetryable(400));
    try std.testing.expect(!RetryPolicy.isRetryable(401));
    try std.testing.expect(!RetryPolicy.isRetryable(404));
}
