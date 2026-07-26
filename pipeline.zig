//! Stable pipeline state and constructor plumbing.
//!
//! Owning clients will allocate pipeline state at a stable address. Derived
//! clients borrow that state and may not outlive the owning service client.

const std = @import("std");
const core = @import("azure_sdk_core");
const auth = @import("auth.zig");
const options = @import("options.zig");
const responses = @import("responses.zig");

const HttpPolicy = core.pipeline.HttpPolicy;
const HttpTransport = core.http.HttpTransport;
const Request = core.http.Request;
const Response = core.http.Response;

pub const user_agent = "azsdk-zig-data-tables/0.1.0";

/// Heap-owned policy storage shared by an owning client and its derived
/// clients. The credential, transport, and caller policy objects are borrowed.
///
/// The mutable bearer-token cache and the standard transport are not
/// thread-safe. Calls sharing this state, including calls from derived clients,
/// must be serialized unless the caller supplies equivalent synchronization.
pub const PipelineState = struct {
    allocator: std.mem.Allocator,
    request_options: RequestOptionsPolicy,
    telemetry: core.pipeline.TelemetryPolicy,
    retry: core.pipeline.RetryPolicy,
    bearer_auth: core.pipeline.BearerTokenAuthPolicy,
    policy_ptrs: []*HttpPolicy,
    pipeline: core.pipeline.HttpPipeline,
    owned_user_agent: []u8,
    owned_client_request_id: ?[]u8,

    pub fn create(
        allocator: std.mem.Allocator,
        credential: *core.credentials.TokenCredential,
        transport: *HttpTransport,
        init_options: options.TableClientOptions,
    ) !*PipelineState {
        try validateHeaderValue(init_options.client_request_id, error.InvalidClientRequestId);
        try validateHeaderValue(
            init_options.telemetry.application_id,
            error.InvalidApplicationId,
        );

        const state = try allocator.create(PipelineState);
        errdefer allocator.destroy(state);

        const request_id = if (init_options.client_request_id) |value|
            try allocator.dupe(u8, value)
        else
            null;
        errdefer if (request_id) |value| allocator.free(value);

        const agent = if (init_options.telemetry.application_id) |application_id|
            try std.fmt.allocPrint(allocator, "{s} {s}", .{ application_id, user_agent })
        else
            try allocator.dupe(u8, user_agent);
        errdefer allocator.free(agent);

        const policy_ptrs = try allocator.alloc(
            *HttpPolicy,
            4 + init_options.policies.len,
        );
        errdefer allocator.free(policy_ptrs);

        state.* = .{
            .allocator = allocator,
            .request_options = RequestOptionsPolicy.init(
                request_id,
                init_options.operation_timeout_ms,
            ),
            .telemetry = core.pipeline.TelemetryPolicy.init(agent),
            .retry = core.pipeline.RetryPolicy.init(),
            .bearer_auth = core.pipeline.BearerTokenAuthPolicy.init(
                allocator,
                credential,
                &.{auth.storage_scope},
            ),
            .policy_ptrs = policy_ptrs,
            .pipeline = undefined,
            .owned_user_agent = agent,
            .owned_client_request_id = request_id,
        };
        state.retry.max_retries = init_options.retry.max_retries;
        state.retry.initial_delay_ms = init_options.retry.initial_delay_ms;
        state.retry.max_delay_ms = init_options.retry.max_delay_ms;

        // Retry precedes authentication so every attempt refreshes or reapplies
        // auth before client and per-operation policies run.
        policy_ptrs[0] = state.request_options.asPolicy();
        policy_ptrs[1] = state.telemetry.asPolicy();
        policy_ptrs[2] = state.retry.asPolicy();
        policy_ptrs[3] = state.bearer_auth.asPolicy();
        @memcpy(policy_ptrs[4..], init_options.policies);
        state.pipeline = .{
            .policies = policy_ptrs,
            .transport_impl = transport,
        };
        return state;
    }

    pub fn deinit(self: *PipelineState) void {
        const allocator = self.allocator;
        self.bearer_auth.deinit();
        allocator.free(self.policy_ptrs);
        allocator.free(self.owned_user_agent);
        if (self.owned_client_request_id) |value| allocator.free(value);
        allocator.destroy(self);
    }
};

const RequestOptionsPolicy = struct {
    client_request_id: ?[]const u8,
    operation_timeout_ms: ?u64,
    policy: HttpPolicy,

    fn init(
        client_request_id: ?[]const u8,
        operation_timeout_ms: ?u64,
    ) RequestOptionsPolicy {
        return .{
            .client_request_id = client_request_id,
            .operation_timeout_ms = operation_timeout_ms,
            .policy = .{ .processFn = &process },
        };
    }

    fn asPolicy(self: *RequestOptionsPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn process(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        transport: *HttpTransport,
    ) anyerror!Response {
        const self: *RequestOptionsPolicy = @alignCast(@fieldParentPtr("policy", policy));
        if (request.getHeader("x-ms-client-request-id") == null) {
            if (self.client_request_id) |request_id|
                try request.setHeader("x-ms-client-request-id", request_id)
            else
                try core.pipeline.ensureRequestId(request);
        }
        if (request.operation_timeout_ms == null)
            request.operation_timeout_ms = self.operation_timeout_ms;
        return callNext(request, next, transport);
    }
};

fn validateHeaderValue(value: ?[]const u8, comptime invalid_error: anyerror) !void {
    const bytes = value orelse return;
    if (bytes.len == 0) return invalid_error;
    for (bytes) |byte| {
        if ((byte < 0x20 and byte != '\t') or byte == 0x7f)
            return invalid_error;
    }
}

pub const CallContext = struct {
    allocator: std.mem.Allocator,
    config_policy: *ConfigPolicy,
    capture_policy: *CapturePolicy,
    policy_ptrs: []*HttpPolicy,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        allocator: std.mem.Allocator,
        base: core.pipeline.HttpPipeline,
        raw_endpoint_query: ?[]const u8,
        operation_timeout_ms: ?u64,
        custom_policies: []const *HttpPolicy,
    ) !CallContext {
        const config = try allocator.create(ConfigPolicy);
        errdefer allocator.destroy(config);
        config.* = ConfigPolicy.init(raw_endpoint_query, operation_timeout_ms);
        const capture = try allocator.create(CapturePolicy);
        errdefer allocator.destroy(capture);
        capture.* = CapturePolicy.init(allocator);

        const policies = try allocator.alloc(
            *HttpPolicy,
            2 + custom_policies.len + base.policies.len,
        );
        errdefer allocator.free(policies);
        policies[0] = config.asPolicy();
        policies[1] = capture.asPolicy();
        @memcpy(policies[2 .. 2 + base.policies.len], base.policies);
        @memcpy(policies[2 + base.policies.len ..], custom_policies);
        return .{
            .allocator = allocator,
            .config_policy = config,
            .capture_policy = capture,
            .policy_ptrs = policies,
            .pipeline = .{ .policies = policies, .transport_impl = base.transport_impl },
        };
    }

    pub fn takeResponse(self: *CallContext) !responses.ResponseMetadata {
        const metadata = self.capture_policy.metadata orelse return error.MissingRawResponse;
        self.capture_policy.metadata = null;
        return metadata;
    }

    pub fn deinit(self: *CallContext) void {
        self.capture_policy.deinit();
        self.allocator.free(self.policy_ptrs);
        self.allocator.destroy(self.capture_policy);
        self.allocator.destroy(self.config_policy);
        self.* = undefined;
    }
};

const ConfigPolicy = struct {
    raw_query: ?[]const u8,
    operation_timeout_ms: ?u64,
    policy: HttpPolicy,

    fn init(raw_query: ?[]const u8, operation_timeout_ms: ?u64) ConfigPolicy {
        return .{
            .raw_query = raw_query,
            .operation_timeout_ms = operation_timeout_ms,
            .policy = .{ .processFn = &process },
        };
    }

    fn asPolicy(self: *ConfigPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn process(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        transport: *HttpTransport,
    ) anyerror!Response {
        const self: *ConfigPolicy = @alignCast(@fieldParentPtr("policy", policy));
        const old_timeout = request.operation_timeout_ms;
        request.operation_timeout_ms = self.operation_timeout_ms;
        defer request.operation_timeout_ms = old_timeout;

        const old_url = request.url;
        var owned_url: ?[]u8 = null;
        defer if (owned_url) |url| request.allocator.free(url);
        if (self.raw_query) |raw_query| {
            const question = std.mem.indexOfScalar(u8, request.url, '?');
            owned_url = if (question) |index|
                try std.fmt.allocPrint(
                    request.allocator,
                    "{s}?{s}{s}{s}",
                    .{
                        request.url[0..index],
                        raw_query,
                        if (raw_query.len > 0 and index + 1 < request.url.len) "&" else "",
                        request.url[index + 1 ..],
                    },
                )
            else
                try std.fmt.allocPrint(request.allocator, "{s}?{s}", .{ request.url, raw_query });
            request.url = owned_url.?;
        }
        defer request.url = old_url;
        return callNext(request, next, transport);
    }
};

const CapturePolicy = struct {
    allocator: std.mem.Allocator,
    metadata: ?responses.ResponseMetadata = null,
    policy: HttpPolicy,

    fn init(allocator: std.mem.Allocator) CapturePolicy {
        return .{
            .allocator = allocator,
            .policy = .{ .processFn = &process },
        };
    }

    fn asPolicy(self: *CapturePolicy) *HttpPolicy {
        return &self.policy;
    }

    fn process(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        transport: *HttpTransport,
    ) anyerror!Response {
        const self: *CapturePolicy = @alignCast(@fieldParentPtr("policy", policy));
        var response = try callNext(request, next, transport);
        errdefer response.deinit();
        if (self.metadata) |*old| old.deinit();
        self.metadata = try responses.ResponseMetadata.fromResponse(self.allocator, &response);
        return response;
    }

    fn deinit(self: *CapturePolicy) void {
        if (self.metadata) |*metadata| metadata.deinit();
    }
};

fn callNext(
    request: *Request,
    next: []*HttpPolicy,
    transport: *HttpTransport,
) !Response {
    if (next.len == 0) return transport.send(request);
    return next[0].process(request, next[1..], transport);
}

const ExpiringCredential = struct {
    calls: usize = 0,
    credential: core.credentials.TokenCredential = .{ .getTokenFn = &getToken },

    fn asCredential(self: *ExpiringCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        context: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *ExpiringCredential = @alignCast(
            @fieldParentPtr("credential", credential),
        );
        if (context.scopes.len != 1 or
            !std.mem.eql(u8, context.scopes[0], auth.storage_scope))
        {
            return error.UnexpectedTokenScope;
        }
        self.calls += 1;
        return .{ .token = "short-lived-token", .expires_on = 0 };
    }
};

const InspectPolicy = struct {
    calls: usize = 0,
    policy: HttpPolicy = .{ .processFn = &process },

    fn process(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        transport: *HttpTransport,
    ) anyerror!Response {
        const self: *InspectPolicy = @alignCast(@fieldParentPtr("policy", policy));
        if (request.getHeader("Authorization") == null or
            request.getHeader("User-Agent") == null or
            request.getHeader("x-ms-client-request-id") == null)
        {
            return error.IncorrectPolicyOrder;
        }
        self.calls += 1;
        return callNext(request, next, transport);
    }
};

const RetryOncePolicy = struct {
    calls: usize = 0,
    policy: HttpPolicy = .{ .processFn = &process },

    fn process(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        transport: *HttpTransport,
    ) anyerror!Response {
        const self: *RetryOncePolicy = @alignCast(@fieldParentPtr("policy", policy));
        if (request.getHeader("Authorization") == null)
            return error.AuthenticationDidNotRun;
        self.calls += 1;
        if (self.calls == 1) {
            return .{
                .status_code = 500,
                .headers = std.StringHashMap([]const u8).init(request.allocator),
                .body = try request.allocator.dupe(u8, "{}"),
                .allocator = request.allocator,
            };
        }
        return callNext(request, next, transport);
    }
};

test "stable policy order authenticates every retry and runs caller policies" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = ExpiringCredential{};
    var configured = InspectPolicy{};

    const state = try PipelineState.create(
        allocator,
        credential.asCredential(),
        mock.asTransport(),
        .{
            .retry = .{
                .max_retries = 1,
                .initial_delay_ms = 0,
                .max_delay_ms = 0,
            },
            .policies = &.{&configured.policy},
        },
    );
    defer state.deinit();

    try std.testing.expect(state.policy_ptrs[0] == state.request_options.asPolicy());
    try std.testing.expect(state.policy_ptrs[1] == state.telemetry.asPolicy());
    try std.testing.expect(state.policy_ptrs[2] == state.retry.asPolicy());
    try std.testing.expect(state.policy_ptrs[3] == state.bearer_auth.asPolicy());
    try std.testing.expect(state.policy_ptrs[4] == &configured.policy);

    var per_call = RetryOncePolicy{};
    var call = try CallContext.init(
        allocator,
        state.pipeline,
        null,
        null,
        &.{&per_call.policy},
    );
    defer call.deinit();
    var request = Request.init(allocator, .GET, "https://example.test");
    defer request.deinit();
    var response = try call.pipeline.send(&request);
    defer response.deinit();

    try std.testing.expectEqual(@as(usize, 2), credential.calls);
    try std.testing.expectEqual(@as(usize, 2), configured.calls);
    try std.testing.expectEqual(@as(usize, 2), per_call.calls);
    try std.testing.expectEqual(@as(usize, 1), mock.call_count);
}
