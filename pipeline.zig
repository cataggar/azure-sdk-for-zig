//! Stable pipeline state and constructor plumbing.
//!
//! Owning clients will allocate pipeline state at a stable address. Derived
//! clients borrow that state and may not outlive the owning service client.

const std = @import("std");
const core = @import("azure_sdk_core");
const responses = @import("responses.zig");

const HttpPolicy = core.pipeline.HttpPolicy;
const HttpTransport = core.http.HttpTransport;
const Request = core.http.Request;
const Response = core.http.Response;

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
        @memcpy(policies[2 .. 2 + custom_policies.len], custom_policies);
        @memcpy(policies[2 + custom_policies.len ..], base.policies);
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
