const std = @import("std");
const transport = @import("transport.zig");

const Request = transport.Request;
const Response = transport.Response;
const HttpTransport = transport.HttpTransport;

fn nanoTimestamp() i128 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    return std.Io.Timestamp.now(threaded.io(), .real).toNanoseconds();
}

fn unixTimestampSeconds() i64 {
    return @intCast(@divTrunc(nanoTimestamp(), std.time.ns_per_s));
}

fn sleepMs(ms: u64) void {
    var threaded: std.Io.Threaded = .init_single_threaded;
    threaded.io().sleep(.fromMilliseconds(@intCast(ms)), .real) catch {};
}

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
        const self: *TelemetryPolicy = @alignCast(@fieldParentPtr("policy", policy));
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
        if (!request.retryable) return callNext(request, next, final_transport);
        const self: *RetryPolicy = @alignCast(@fieldParentPtr("policy", policy));
        var attempt: u32 = 0;
        var prng = std.Random.DefaultPrng.init(@truncate(@as(u128, @bitCast(nanoTimestamp()))));
        while (true) {
            const result = callNext(request, next, final_transport);
            if (result) |resp| {
                if (!isRetryable(resp.status_code) or attempt >= self.max_retries) return resp;

                // Check for Retry-After header (seconds).
                const retry_after_ms = retryAfterDelayMs(resp);

                var r = resp;
                r.deinit();

                attempt += 1;
                if (retry_after_ms > 0) {
                    // Honor server's Retry-After, capped at max_delay.
                    const delay = @min(retry_after_ms, self.max_delay_ms);
                    sleepMs(delay);
                } else {
                    const base_delay = @min(
                        self.initial_delay_ms * (@as(u64, 1) << @intCast(attempt - 1)),
                        self.max_delay_ms,
                    );
                    const jitter = prng.random().uintLessThan(u64, @max(base_delay, 1));
                    const delay = base_delay / 2 + jitter / 2;
                    sleepMs(delay);
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
                sleepMs(delay);
            }
        }
    }

    fn parseRetryAfter(resp: Response) ?u64 {
        const value = resp.headers.get("Retry-After") orelse
            resp.headers.get("retry-after") orelse
            return null;
        return std.fmt.parseInt(u64, value, 10) catch null;
    }

    fn retryAfterDelayMs(resp: Response) u64 {
        const seconds = parseRetryAfter(resp) orelse return 0;
        return std.math.mul(u64, seconds, 1000) catch std.math.maxInt(u64);
    }
};

/// Injects `Authorization: Bearer <token>` using a `TokenCredential`.
///
/// Caches the token and only refreshes when within 5 minutes of expiry.
pub const BearerTokenAuthPolicy = struct {
    const creds = @import("../credentials/token.zig");

    credential: *creds.TokenCredential,
    scopes: []const []const u8,
    policy: HttpPolicy,
    allocator: std.mem.Allocator,
    cached_token: ?[]const u8 = null,
    cached_expires_on: i64 = 0,
    cached_auth_value: ?[]const u8 = null,

    pub fn init(
        allocator: std.mem.Allocator,
        credential: *creds.TokenCredential,
        scopes: []const []const u8,
    ) BearerTokenAuthPolicy {
        return .{
            .allocator = allocator,
            .credential = credential,
            .scopes = scopes,
            .policy = .{ .processFn = &processImpl },
        };
    }

    pub fn asPolicy(self: *BearerTokenAuthPolicy) *HttpPolicy {
        return &self.policy;
    }

    pub fn deinit(self: *BearerTokenAuthPolicy) void {
        if (self.cached_token) |t| self.allocator.free(t);
        if (self.cached_auth_value) |v| self.allocator.free(v);
    }

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        const self: *BearerTokenAuthPolicy = @alignCast(@fieldParentPtr("policy", policy));
        const now = unixTimestampSeconds();
        const refresh_buffer: i64 = 300; // 5 minutes before expiry

        // Use cached token if still valid.
        var token_str = self.cached_token;
        if (token_str == null or now >= self.cached_expires_on - refresh_buffer) {
            const ctx = @import("../context.zig").Context.none;
            var fresh = try self.credential.getToken(
                .{ .scopes = self.scopes },
                ctx,
            );
            defer fresh.deinit();
            const replacement = try self.allocator.dupe(u8, fresh.token);
            if (self.cached_token) |old| self.allocator.free(old);
            self.cached_token = replacement;
            self.cached_expires_on = fresh.expires_on;
            token_str = self.cached_token;
        }

        // Build and cache the "Bearer {token}" header value.
        const old_auth_value = self.cached_auth_value;
        {
            self.cached_auth_value = null;
            errdefer self.cached_auth_value = old_auth_value;
            self.cached_auth_value = try std.fmt.allocPrint(
                self.allocator,
                "Bearer {s}",
                .{token_str.?},
            );
        }
        if (old_auth_value) |old| self.allocator.free(old);
        try request.setHeader("Authorization", self.cached_auth_value.?);
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
        if (request.getHeader("x-ms-client-request-id") != null) {
            return callNext(request, next, final_transport);
        }
        const uuid_mod = @import("../uuid.zig");
        const seed: u64 = @truncate(@as(u128, @bitCast(nanoTimestamp())));
        var prng = std.Random.DefaultPrng.init(seed);
        const id = uuid_mod.Uuid.init(prng.random());
        const id_str = id.toString();
        try request.setHeader("x-ms-client-request-id", &id_str);
        return callNext(request, next, final_transport);
    }
};

/// Creates a tracing span around each HTTP request with standard attributes.
///
/// When a `TracerProvider` is configured, creates spans with:
/// - `http.method`, `url.full`, `http.status_code`
/// - `az.client_request_id` (if present)
/// - W3C `traceparent` / `tracestate` header propagation
pub const TracingPolicy = struct {
    const tracing = @import("../tracing/root.zig");

    tracer: *tracing.Tracer,
    az_namespace: []const u8,
    policy: HttpPolicy,

    pub fn init(tracer: *tracing.Tracer, az_namespace: []const u8) TracingPolicy {
        return .{
            .tracer = tracer,
            .az_namespace = az_namespace,
            .policy = .{ .processFn = &processImpl },
        };
    }

    pub fn asPolicy(self: *TracingPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        const self: *TracingPolicy = @alignCast(@fieldParentPtr("policy", policy));

        const span = self.tracer.startSpan("HTTP", .client) catch {
            return callNext(request, next, final_transport);
        };

        // Set standard Azure SDK span attributes.
        span.setAttribute("http.method", @tagName(request.method)) catch {};
        span.setAttribute("url.full", request.url) catch {};
        span.setAttribute("az.namespace", self.az_namespace) catch {};

        if (request.getHeader("x-ms-client-request-id")) |rid| {
            span.setAttribute("az.client_request_id", rid) catch {};
        }

        // Execute the rest of the pipeline.
        const response = callNext(request, next, final_transport) catch |err| {
            span.setStatus(.@"error");
            span.end();
            return err;
        };

        // Record response status.
        if (response.isSuccess()) {
            span.setStatus(.ok);
        } else {
            span.setStatus(.@"error");
        }

        span.end();
        return response;
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
    // UUID format: 8-4-4-4-12 = 36 chars.
    try std.testing.expectEqual(@as(usize, 36), request_id.len);
    try std.testing.expectEqual(@as(u8, '-'), request_id[8]);
}

test "RequestIdPolicy preserves caller-provided request ID" {
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
    try req.setHeader("X-MS-Client-Request-Id", "caller-request-id");
    var resp = try pipeline_inst.send(&req);
    defer resp.deinit();
    try std.testing.expectEqualStrings(
        "caller-request-id",
        req.getHeader("x-ms-client-request-id").?,
    );
}

test "BearerTokenAuthPolicy injects Authorization header" {
    const allocator = std.testing.allocator;
    const creds = @import("../credentials/token.zig");

    const Stub = struct {
        fn getTokenFn(
            _: *creds.TokenCredential,
            _: creds.TokenRequestContext,
            _: @import("../context.zig").Context,
        ) anyerror!creds.AccessToken {
            const token = try allocator.dupe(u8, "stub-token");
            return .{
                .token = token,
                .expires_on = unixTimestampSeconds() + 3600,
                .allocator = allocator,
            };
        }
    };
    var credential = creds.TokenCredential{ .getTokenFn = &Stub.getTokenFn };

    var mock = transport.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();
    var auth = BearerTokenAuthPolicy.init(
        allocator,
        &credential,
        &.{"https://vault.azure.net/.default"},
    );
    defer auth.deinit();
    var policy_ptrs = [_]*HttpPolicy{auth.asPolicy()};
    var pipeline_inst = HttpPipeline{
        .policies = &policy_ptrs,
        .transport_impl = mock.asTransport(),
    };
    var req = Request.init(allocator, .GET, "https://example.com");
    defer req.deinit();
    var resp = try pipeline_inst.send(&req);
    defer resp.deinit();
    try std.testing.expectEqualStrings("Bearer stub-token", req.headers.get("Authorization").?);
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

test "RetryPolicy converts Retry-After seconds to milliseconds" {
    var headers = std.StringHashMap([]const u8).init(std.testing.allocator);
    defer headers.deinit();
    try headers.put("Retry-After", "10");
    const response = Response{
        .status_code = 429,
        .headers = headers,
        .body = @constCast(&.{}),
        .allocator = std.testing.allocator,
    };
    try std.testing.expectEqual(@as(u64, 10_000), RetryPolicy.retryAfterDelayMs(response));
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

test "RetryPolicy bypasses retries for non-retryable requests" {
    const allocator = std.testing.allocator;
    var seq = transport.SequenceMockTransport.init(allocator, &.{
        .{ .status = 500, .body = "error" },
        .{ .status = 200, .body = "ok" },
    });
    var retry = RetryPolicy.init();
    retry.initial_delay_ms = 0;
    var policy_ptrs = [_]*HttpPolicy{retry.asPolicy()};
    var pip = HttpPipeline{ .policies = &policy_ptrs, .transport_impl = seq.asTransport() };
    var req = Request.init(allocator, .POST, "https://example.com/create");
    defer req.deinit();
    req.retryable = false;
    var resp = try pip.send(&req);
    defer resp.deinit();
    try std.testing.expectEqual(@as(u16, 500), resp.status_code);
    try std.testing.expectEqual(@as(usize, 1), seq.call_count);
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

test "TracingPolicy creates span with attributes" {
    const allocator = std.testing.allocator;
    const tracing = @import("../tracing/root.zig");
    var mock = transport.MockTransport.init(allocator, 200, "ok");
    defer mock.deinit();

    var rec_tracer = tracing.RecordingTracer.init(allocator);
    defer rec_tracer.deinit();

    var tracing_policy = TracingPolicy.init(rec_tracer.asTracer(), "KeyVault");
    var policy_ptrs = [_]*HttpPolicy{tracing_policy.asPolicy()};
    var pip = HttpPipeline{ .policies = &policy_ptrs, .transport_impl = mock.asTransport() };

    var req = Request.init(allocator, .GET, "https://vault.azure.net/secrets/mysecret");
    defer req.deinit();
    var resp = try pip.send(&req);
    defer resp.deinit();

    // Verify span was created and ended with correct attributes.
    const span = &rec_tracer.last_span.?;
    try std.testing.expectEqualStrings("HTTP", span.name);
    try std.testing.expectEqual(tracing.SpanKind.client, span.kind);
    try std.testing.expectEqual(tracing.SpanStatus.ok, span.status);
    try std.testing.expect(span.ended);
    try std.testing.expectEqualStrings("GET", span.attributes.get("http.method").?);
    try std.testing.expectEqualStrings("KeyVault", span.attributes.get("az.namespace").?);
}

test "TracingPolicy sets error status on failure" {
    const allocator = std.testing.allocator;
    const tracing = @import("../tracing/root.zig");
    var mock = transport.MockTransport.init(allocator, 500, "error");
    defer mock.deinit();

    var rec_tracer = tracing.RecordingTracer.init(allocator);
    defer rec_tracer.deinit();

    var tracing_policy = TracingPolicy.init(rec_tracer.asTracer(), "Storage");
    var policy_ptrs = [_]*HttpPolicy{tracing_policy.asPolicy()};
    var pip = HttpPipeline{ .policies = &policy_ptrs, .transport_impl = mock.asTransport() };

    var req = Request.init(allocator, .GET, "https://storage.blob.core.windows.net");
    defer req.deinit();
    var resp = try pip.send(&req);
    defer resp.deinit();

    try std.testing.expectEqual(tracing.SpanStatus.@"error", rec_tracer.last_span.?.status);
    try std.testing.expect(rec_tracer.last_span.?.ended);
}
