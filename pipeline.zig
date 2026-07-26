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
    authentication: Authentication,
    policy_ptrs: []*HttpPolicy,
    pipeline: core.pipeline.HttpPipeline,
    owned_user_agent: []u8,
    owned_client_request_id: ?[]u8,
    owned_api_version: []u8,

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

        return createWithAuthentication(
            allocator,
            transport,
            init_options,
            .{ .bearer = core.pipeline.BearerTokenAuthPolicy.init(
                allocator,
                credential,
                &.{auth.storage_scope},
            ) },
        );
    }

    pub fn createSharedKey(
        allocator: std.mem.Allocator,
        credential: *auth.SharedKeyCredential,
        transport: *HttpTransport,
        init_options: options.TableClientOptions,
    ) !*PipelineState {
        return createWithAuthentication(
            allocator,
            transport,
            init_options,
            .{ .shared_key = auth.SharedKeyLitePolicy.init(credential, init_options.api_version) },
        );
    }

    /// Used by SAS clients. It deliberately has no authorization policy.
    pub fn createNoAuth(
        allocator: std.mem.Allocator,
        transport: *HttpTransport,
        init_options: options.TableClientOptions,
    ) !*PipelineState {
        return createWithAuthentication(allocator, transport, init_options, .{ .none = .{} });
    }

    fn createWithAuthentication(
        allocator: std.mem.Allocator,
        transport: *HttpTransport,
        init_options: options.TableClientOptions,
        authentication: Authentication,
    ) !*PipelineState {
        try validateHeaderValue(init_options.client_request_id, error.InvalidClientRequestId);
        try validateHeaderValue(
            init_options.telemetry.application_id,
            error.InvalidApplicationId,
        );
        const state = try allocator.create(PipelineState);
        errdefer allocator.destroy(state);

        const api_version = try allocator.dupe(u8, init_options.api_version);
        errdefer allocator.free(api_version);

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
            .authentication = authentication,
            .policy_ptrs = policy_ptrs,
            .pipeline = undefined,
            .owned_user_agent = agent,
            .owned_client_request_id = request_id,
            .owned_api_version = api_version,
        };
        state.authentication.bindApiVersion(state.owned_api_version);
        state.retry.max_retries = init_options.retry.max_retries;
        state.retry.initial_delay_ms = init_options.retry.initial_delay_ms;
        state.retry.max_delay_ms = init_options.retry.max_delay_ms;

        // Retry precedes authentication so every attempt refreshes or reapplies
        // auth before client and per-operation policies run.
        policy_ptrs[0] = state.request_options.asPolicy();
        policy_ptrs[1] = state.telemetry.asPolicy();
        policy_ptrs[2] = state.retry.asPolicy();
        policy_ptrs[3] = state.authentication.asPolicy();
        @memcpy(policy_ptrs[4..], init_options.policies);
        state.pipeline = .{
            .policies = policy_ptrs,
            .transport_impl = transport,
        };
        return state;
    }

    pub fn deinit(self: *PipelineState) void {
        const allocator = self.allocator;
        self.authentication.deinit();
        allocator.free(self.policy_ptrs);
        allocator.free(self.owned_user_agent);
        if (self.owned_client_request_id) |value| allocator.free(value);
        allocator.free(self.owned_api_version);
        allocator.destroy(self);
    }

    pub fn usesSas(self: *const PipelineState) bool {
        return self.authentication == .none;
    }

    pub fn sharedKeyCredential(self: *PipelineState) ?*auth.SharedKeyCredential {
        return switch (self.authentication) {
            .shared_key => |*policy| policy.credential,
            else => null,
        };
    }
};

const NoAuthenticationPolicy = struct {
    policy: HttpPolicy = .{ .processFn = &process },

    fn asPolicy(self: *NoAuthenticationPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn process(
        _: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        transport: *HttpTransport,
    ) anyerror!Response {
        // A SAS URL's signature is in the query. The SDK never synthesizes
        // Authorization for this mode.
        if (next.len == 0) return transport.send(request);
        return next[0].process(request, next[1..], transport);
    }
};

const Authentication = union(enum) {
    bearer: core.pipeline.BearerTokenAuthPolicy,
    shared_key: auth.SharedKeyLitePolicy,
    none: NoAuthenticationPolicy,

    fn asPolicy(self: *Authentication) *HttpPolicy {
        return switch (self.*) {
            .bearer => |*policy| policy.asPolicy(),
            .shared_key => |*policy| policy.asPolicy(),
            .none => |*policy| policy.asPolicy(),
        };
    }

    fn deinit(self: *Authentication) void {
        switch (self.*) {
            .bearer => |*policy| policy.deinit(),
            .shared_key, .none => {},
        }
    }

    fn bindApiVersion(self: *Authentication, api_version: []const u8) void {
        switch (self.*) {
            .shared_key => |*policy| policy.api_version = api_version,
            .bearer, .none => {},
        }
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
    capture_policy: ?*CapturePolicy,
    sas_policy: *SasAuthPolicy,
    policy_ptrs: []*HttpPolicy,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        allocator: std.mem.Allocator,
        base: core.pipeline.HttpPipeline,
        raw_endpoint_query: ?[]const u8,
        endpoint_query_is_sas: bool,
        operation_timeout_ms: ?u64,
        server_timeout: ?i32,
        custom_policies: []const *HttpPolicy,
    ) !CallContext {
        return initInternal(
            allocator,
            base,
            raw_endpoint_query,
            endpoint_query_is_sas,
            operation_timeout_ms,
            server_timeout,
            custom_policies,
            .failure_only,
        );
    }

    pub fn initWithResponseBody(
        allocator: std.mem.Allocator,
        base: core.pipeline.HttpPipeline,
        raw_endpoint_query: ?[]const u8,
        endpoint_query_is_sas: bool,
        operation_timeout_ms: ?u64,
        server_timeout: ?i32,
        custom_policies: []const *HttpPolicy,
    ) !CallContext {
        return initInternal(
            allocator,
            base,
            raw_endpoint_query,
            endpoint_query_is_sas,
            operation_timeout_ms,
            server_timeout,
            custom_policies,
            .all,
        );
    }

    pub fn initNoCapture(
        allocator: std.mem.Allocator,
        base: core.pipeline.HttpPipeline,
        raw_endpoint_query: ?[]const u8,
        endpoint_query_is_sas: bool,
        operation_timeout_ms: ?u64,
        server_timeout: ?i32,
        custom_policies: []const *HttpPolicy,
    ) !CallContext {
        return initInternal(
            allocator,
            base,
            raw_endpoint_query,
            endpoint_query_is_sas,
            operation_timeout_ms,
            server_timeout,
            custom_policies,
            .none,
        );
    }

    fn initInternal(
        allocator: std.mem.Allocator,
        base: core.pipeline.HttpPipeline,
        raw_endpoint_query: ?[]const u8,
        endpoint_query_is_sas: bool,
        operation_timeout_ms: ?u64,
        server_timeout: ?i32,
        custom_policies: []const *HttpPolicy,
        capture_mode: CaptureMode,
    ) !CallContext {
        const config = try allocator.create(ConfigPolicy);
        errdefer allocator.destroy(config);
        config.* = ConfigPolicy.init(
            if (endpoint_query_is_sas) null else raw_endpoint_query,
            operation_timeout_ms,
            server_timeout,
        );
        const capture = if (capture_mode != .none)
            try allocator.create(CapturePolicy)
        else
            null;
        errdefer if (capture) |value| allocator.destroy(value);
        if (capture) |value|
            value.* = CapturePolicy.init(allocator, capture_mode == .all);
        const sas = try allocator.create(SasAuthPolicy);
        errdefer allocator.destroy(sas);
        sas.* = SasAuthPolicy.init(if (endpoint_query_is_sas) raw_endpoint_query else null);

        const policies = try allocator.alloc(
            *HttpPolicy,
            2 + @intFromBool(capture != null) + custom_policies.len + base.policies.len,
        );
        errdefer allocator.free(policies);
        policies[0] = config.asPolicy();
        var base_start: usize = 1;
        if (capture) |value| {
            policies[1] = value.asPolicy();
            base_start += 1;
        }
        @memcpy(policies[base_start .. base_start + base.policies.len], base.policies);
        const custom_start = base_start + base.policies.len;
        @memcpy(policies[custom_start .. custom_start + custom_policies.len], custom_policies);
        policies[policies.len - 1] = sas.asPolicy();
        return .{
            .allocator = allocator,
            .config_policy = config,
            .capture_policy = capture,
            .sas_policy = sas,
            .policy_ptrs = policies,
            .pipeline = .{ .policies = policies, .transport_impl = base.transport_impl },
        };
    }

    pub fn takeResponse(self: *CallContext) !responses.ResponseMetadata {
        const capture = self.capture_policy orelse return error.ResponseCaptureDisabled;
        const metadata = capture.metadata orelse return error.MissingRawResponse;
        capture.metadata = null;
        return metadata;
    }

    pub fn deinit(self: *CallContext) void {
        if (self.capture_policy) |capture| {
            capture.deinit();
            self.allocator.destroy(capture);
        }
        self.allocator.free(self.policy_ptrs);
        self.allocator.destroy(self.config_policy);
        self.allocator.destroy(self.sas_policy);
        self.* = undefined;
    }
};

const CaptureMode = enum { none, failure_only, all };

const ConfigPolicy = struct {
    raw_query: ?[]const u8,
    operation_timeout_ms: ?u64,
    server_timeout: ?i32,
    policy: HttpPolicy,

    fn init(
        raw_query: ?[]const u8,
        operation_timeout_ms: ?u64,
        server_timeout: ?i32,
    ) ConfigPolicy {
        return .{
            .raw_query = raw_query,
            .operation_timeout_ms = operation_timeout_ms,
            .server_timeout = server_timeout,
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
        var url = old_url;
        var owned_url: ?[]u8 = null;
        errdefer if (owned_url) |value| request.allocator.free(value);
        if (self.raw_query) |raw_query| {
            owned_url = try appendEndpointQuery(request.allocator, url, raw_query);
            url = owned_url.?;
        }
        if (self.server_timeout) |timeout| {
            const timeout_url = try appendServerTimeout(request.allocator, url, timeout);
            if (owned_url) |value| request.allocator.free(value);
            owned_url = timeout_url;
            url = timeout_url;
        }
        if (owned_url == null) return callNext(request, next, transport);
        const final_url = owned_url.?;
        owned_url = null;
        request.url = final_url;
        defer {
            request.url = old_url;
            request.allocator.free(final_url);
        }
        return callNext(request, next, transport);
    }
};

/// Appends an opaque SAS query only for the transport call. It is always the
/// final policy, inside retry, so caller observability sees a credential-free
/// URL and every attempt gets the exact original query bytes.
const SasAuthPolicy = struct {
    raw_query: ?[]const u8,
    policy: HttpPolicy,

    fn init(raw_query: ?[]const u8) SasAuthPolicy {
        return .{
            .raw_query = raw_query,
            .policy = .{ .processFn = &process },
        };
    }

    fn asPolicy(self: *SasAuthPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn process(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        transport: *HttpTransport,
    ) anyerror!Response {
        const self: *SasAuthPolicy = @alignCast(@fieldParentPtr("policy", policy));
        const raw_query = self.raw_query orelse return callNext(request, next, transport);
        if (next.len != 0) return error.InvalidSasPolicyOrder;

        const signed_url = try appendEndpointQuery(request.allocator, request.url, raw_query);

        const old_url = request.url;
        const old_redirect_policy = request.redirect_policy;
        request.url = signed_url;
        request.redirect_policy = .not_allowed;
        defer {
            request.url = old_url;
            request.redirect_policy = old_redirect_policy;
            request.allocator.free(signed_url);
        }
        return transport.send(request);
    }
};

fn appendEndpointQuery(
    allocator: std.mem.Allocator,
    url: []const u8,
    raw_query: []const u8,
) ![]u8 {
    const question = std.mem.indexOfScalar(u8, url, '?');
    return if (question) |index|
        std.fmt.allocPrint(
            allocator,
            "{s}?{s}{s}{s}",
            .{
                url[0..index],
                raw_query,
                if (raw_query.len > 0 and index + 1 < url.len) "&" else "",
                url[index + 1 ..],
            },
        )
    else
        std.fmt.allocPrint(allocator, "{s}?{s}", .{ url, raw_query });
}

/// Appends the validated decimal Azure Tables `timeout` query option without
/// re-encoding generated query parameters or opaque endpoint query bytes.
fn appendServerTimeout(
    allocator: std.mem.Allocator,
    url: []const u8,
    timeout: i32,
) ![]u8 {
    const separator: []const u8 = if (std.mem.indexOfScalar(u8, url, '?')) |_| blk: {
        if (url.len > 0 and (url[url.len - 1] == '?' or url[url.len - 1] == '&')) break :blk "";
        break :blk "&";
    } else "?";
    return std.fmt.allocPrint(allocator, "{s}{s}timeout={d}", .{ url, separator, timeout });
}

const CapturePolicy = struct {
    allocator: std.mem.Allocator,
    capture_success_body: bool,
    metadata: ?responses.ResponseMetadata = null,
    policy: HttpPolicy,

    fn init(allocator: std.mem.Allocator, capture_success_body: bool) CapturePolicy {
        return .{
            .allocator = allocator,
            .capture_success_body = capture_success_body,
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
        errdefer {
            self.metadata.?.deinit();
            self.metadata = null;
        }
        if (self.capture_success_body or response.status_code < 200 or response.status_code >= 300)
            self.metadata.?.body = try self.allocator.dupe(u8, response.body);
        return response;
    }

    fn deinit(self: *CapturePolicy) void {
        if (self.metadata) |*metadata| metadata.deinit();
    }
};

fn testLargeSuccessCapture(allocator: std.mem.Allocator) !void {
    var body: [64 * 1024]u8 = undefined;
    @memset(&body, 'x');
    var transport = core.http.MockTransport.init(allocator, 200, &body);
    defer transport.deinit();
    const base: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    var call = try CallContext.init(allocator, base, null, false, null, null, &.{});
    defer call.deinit();
    var request = Request.init(allocator, .GET, "https://example.test/Tables");
    defer request.deinit();
    var response = try call.pipeline.send(&request);
    defer response.deinit();
    var metadata = try call.takeResponse();
    defer metadata.deinit();
    try std.testing.expect(metadata.body == null);
}

test "capture does not duplicate large successful response bodies" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        testLargeSuccessCapture,
        .{},
    );
}

test "capture retains a non-success body for structured error adaptation" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 409, "failure body");
    defer transport.deinit();
    const base: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    var call = try CallContext.init(allocator, base, null, false, null, null, &.{});
    defer call.deinit();
    var request = Request.init(allocator, .GET, "https://example.test/Tables");
    defer request.deinit();
    var response = try call.pipeline.send(&request);
    defer response.deinit();
    var metadata = try call.takeResponse();
    defer metadata.deinit();
    try std.testing.expectEqualStrings("failure body", metadata.body.?);
}

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

const FailingTransport = struct {
    transport: HttpTransport = .{ .sendFn = &send },
    captured_url: [512]u8 = undefined,
    captured_url_len: usize = 0,
    saw_redirects_disabled: bool = false,

    fn asTransport(self: *FailingTransport) *HttpTransport {
        return &self.transport;
    }

    fn send(transport: *HttpTransport, request: *Request) anyerror!Response {
        const self: *FailingTransport = @alignCast(@fieldParentPtr("transport", transport));
        if (request.url.len > self.captured_url.len) return error.TestUrlTooLong;
        @memcpy(self.captured_url[0..request.url.len], request.url);
        self.captured_url_len = request.url.len;
        self.saw_redirects_disabled = request.redirect_policy == .not_allowed;
        return error.InjectedTransportFailure;
    }

    fn capturedUrl(self: *const FailingTransport) []const u8 {
        return self.captured_url[0..self.captured_url_len];
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
    try std.testing.expect(state.policy_ptrs[3] == state.authentication.asPolicy());
    try std.testing.expect(state.policy_ptrs[4] == &configured.policy);

    var per_call = RetryOncePolicy{};
    var call = try CallContext.init(
        allocator,
        state.pipeline,
        null,
        false,
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

test "core logging and tracing never observe SAS while retries send exact opaque bytes" {
    const allocator = std.testing.allocator;
    var transport = core.http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 500, .body = "{}" },
        .{ .status = 200, .body = "{}" },
    });
    var recording_tracer = core.tracing.RecordingTracer.init(allocator);
    defer recording_tracer.deinit();
    var logging = core.pipeline.LoggingPolicy.init();
    var tracing = core.pipeline.TracingPolicy.init(
        recording_tracer.asTracer(),
        "Microsoft.Storage",
    );
    const state = try PipelineState.createNoAuth(
        allocator,
        transport.asTransport(),
        .{
            .retry = .{
                .max_retries = 1,
                .initial_delay_ms = 0,
                .max_delay_ms = 0,
            },
            .policies = &.{ logging.asPolicy(), tracing.asPolicy() },
        },
    );
    defer state.deinit();

    const clean_url = "https://account.table.core.windows.net/Table123?timeout=30&$filter=x%20y";
    const raw_sas = "sv=1%2F2&sig=opaque+SECRET%2Fbytes%3D&sp=r";
    const exact_sas_url = "https://account.table.core.windows.net/Table123?sv=1%2F2&sig=opaque+SECRET%2Fbytes%3D&sp=r&timeout=30&$filter=x%20y";
    var call = try CallContext.init(allocator, state.pipeline, raw_sas, true, null, null, &.{});
    defer call.deinit();
    var request = Request.init(allocator, .GET, clean_url);
    defer request.deinit();

    var response = try call.pipeline.send(&request);
    defer response.deinit();

    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expectEqualStrings(exact_sas_url, transport.capturedUrl(0));
    try std.testing.expectEqualStrings(exact_sas_url, transport.capturedUrl(1));
    try std.testing.expectEqualStrings(clean_url, request.url);
    try std.testing.expectEqual(core.http.RedirectPolicy.follow, request.redirect_policy);
    const observed_url = recording_tracer.last_span.?.attributes.get("url.full").?;
    try std.testing.expectEqualStrings(clean_url, observed_url);
    try std.testing.expect(std.mem.indexOf(u8, observed_url, "sig=") == null);
    try std.testing.expect(std.mem.indexOf(u8, observed_url, "SECRET") == null);
}

test "SAS transport errors restore the credential-free URL and redirect policy" {
    const allocator = std.testing.allocator;
    var transport = FailingTransport{};
    var recording_tracer = core.tracing.RecordingTracer.init(allocator);
    defer recording_tracer.deinit();
    var logging = core.pipeline.LoggingPolicy.init();
    var tracing = core.pipeline.TracingPolicy.init(
        recording_tracer.asTracer(),
        "Microsoft.Storage",
    );
    const state = try PipelineState.createNoAuth(
        allocator,
        transport.asTransport(),
        .{
            .retry = .{ .max_retries = 0 },
            .policies = &.{ logging.asPolicy(), tracing.asPolicy() },
        },
    );
    defer state.deinit();

    const clean_url = "https://account.table.core.windows.net/Table123";
    const exact_sas_url = "https://account.table.core.windows.net/Table123?sig=transport-error-SECRET%3D&sv=1";
    var call = try CallContext.init(
        allocator,
        state.pipeline,
        "sig=transport-error-SECRET%3D&sv=1",
        true,
        null,
        null,
        &.{},
    );
    defer call.deinit();
    var request = Request.init(allocator, .GET, clean_url);
    defer request.deinit();

    try std.testing.expectError(
        error.InjectedTransportFailure,
        call.pipeline.send(&request),
    );
    try std.testing.expectEqualStrings(exact_sas_url, transport.capturedUrl());
    try std.testing.expect(transport.saw_redirects_disabled);
    try std.testing.expectEqualStrings(clean_url, request.url);
    try std.testing.expectEqual(core.http.RedirectPolicy.follow, request.redirect_policy);
    const observed_url = recording_tracer.last_span.?.attributes.get("url.full").?;
    try std.testing.expectEqualStrings(clean_url, observed_url);
    try std.testing.expect(std.mem.indexOf(u8, observed_url, "SECRET") == null);
}

test "SAS URL allocation errors leave the request untouched" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    const base: core.pipeline.HttpPipeline = .{
        .policies = &.{},
        .transport_impl = transport.asTransport(),
    };
    var call = try CallContext.init(
        allocator,
        base,
        "sig=allocation-SECRET&sv=1",
        true,
        null,
        null,
        &.{},
    );
    defer call.deinit();

    var buffer: [1]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&buffer);
    const clean_url = "https://account.table.core.windows.net/Table123";
    var request = Request.init(fixed.allocator(), .GET, clean_url);
    defer request.deinit();
    try std.testing.expectError(error.OutOfMemory, call.pipeline.send(&request));
    try std.testing.expectEqualStrings(clean_url, request.url);
    try std.testing.expectEqual(core.http.RedirectPolicy.follow, request.redirect_policy);
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

test "Shared Key core observability records no credential material in URLs" {
    const allocator = std.testing.allocator;
    var transport = core.http.MockTransport.init(allocator, 200, "{}");
    defer transport.deinit();
    var credential = try auth.SharedKeyCredential.init(
        allocator,
        "account",
        "YWNjb3VudC1rZXk=",
    );
    defer credential.deinit();
    var recording_tracer = core.tracing.RecordingTracer.init(allocator);
    defer recording_tracer.deinit();
    var logging = core.pipeline.LoggingPolicy.init();
    var tracing = core.pipeline.TracingPolicy.init(
        recording_tracer.asTracer(),
        "Microsoft.Storage",
    );
    const state = try PipelineState.createSharedKey(
        allocator,
        &credential,
        transport.asTransport(),
        .{ .policies = &.{ logging.asPolicy(), tracing.asPolicy() } },
    );
    defer state.deinit();
    var call = try CallContext.init(allocator, state.pipeline, null, false, null, null, &.{});
    defer call.deinit();
    const clean_url = "https://account.table.core.windows.net/Table123?comp=acl";
    var request = Request.init(allocator, .GET, clean_url);
    defer request.deinit();
    var response = try call.pipeline.send(&request);
    defer response.deinit();

    try std.testing.expect(transport.last_headers.get("Authorization") != null);
    const observed_url = recording_tracer.last_span.?.attributes.get("url.full").?;
    try std.testing.expectEqualStrings(clean_url, observed_url);
    try std.testing.expect(std.mem.indexOf(u8, observed_url, "SharedKeyLite") == null);
    try std.testing.expect(std.mem.indexOf(u8, observed_url, "account-key") == null);
}

test "Shared Key policy retains an owned API version across caller mutation and policy moves" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();
    var credential = try auth.SharedKeyCredential.init(allocator, "account", "YWNjb3VudC1rZXk=");
    defer credential.deinit();

    const supplied_api_version = try allocator.dupe(u8, "2020-owned-version");
    var state = try PipelineState.createSharedKey(
        allocator,
        &credential,
        mock.asTransport(),
        .{ .api_version = supplied_api_version },
    );
    defer state.deinit();
    @memset(supplied_api_version, 'x');
    allocator.free(supplied_api_version);

    var request = Request.init(allocator, .GET, "https://account.table.core.windows.net");
    defer request.deinit();
    var response = try state.pipeline.send(&request);
    defer response.deinit();
    try std.testing.expectEqualStrings(
        "2020-owned-version",
        mock.last_headers.get("x-ms-version").?,
    );
}
