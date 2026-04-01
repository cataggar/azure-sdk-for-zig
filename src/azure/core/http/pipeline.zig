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

/// Retries failed requests with exponential back-off.
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

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        const self: *RetryPolicy = @fieldParentPtr("policy", policy);
        var attempt: u32 = 0;
        while (true) {
            const result = callNext(request, next, final_transport);
            if (result) |resp| {
                if (resp.status_code < 500 or attempt >= self.max_retries) return resp;
                var r = resp;
                r.deinit();
            } else |err| {
                if (attempt >= self.max_retries) return err;
            }
            attempt += 1;
            const delay = @min(
                self.initial_delay_ms * (@as(u64, 1) << @intCast(attempt - 1)),
                self.max_delay_ms,
            );
            std.time.sleep(delay * std.time.ns_per_ms);
        }
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
