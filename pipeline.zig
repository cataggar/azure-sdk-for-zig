//! Stable authenticated pipeline state shared by Key Vault clients.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const default_scope = "https://vault.azure.net/.default";

pub const RetryOptions = struct {
    max_retries: u32 = 3,
    initial_delay_ms: u64 = 800,
    max_delay_ms: u64 = 60_000,
};

/// Heap-owned policy state for a Key Vault client and its derived clients.
///
/// Runtime descriptors are copied by value. Their transport and crypto
/// contexts, the credential, and all policy backend state are borrowed and
/// must outlive the owning client, every derived client and pager, and all
/// in-flight calls. Calls sharing this state must be serialized unless the
/// borrowed implementations provide equivalent synchronization.
pub const PipelineState = struct {
    allocator: std.mem.Allocator,
    scope: []u8,
    scopes: [1][]const u8,
    retry: core.http.RetryPolicy,
    request_id: core.http.RequestIdPolicy,
    auth: core.http.BearerTokenAuthPolicy,
    policies: [3]*core.http.HttpPolicy,
    pipeline: core.http.HttpPipeline,

    pub fn create(
        allocator: std.mem.Allocator,
        credential: *core.credentials.TokenCredential,
        runtime: core.http.HttpRuntime,
        retry_options: RetryOptions,
        scope: []const u8,
    ) !*PipelineState {
        const state = try allocator.create(PipelineState);
        errdefer allocator.destroy(state);
        const owned_scope = try allocator.dupe(u8, scope);
        errdefer allocator.free(owned_scope);

        state.* = .{
            .allocator = allocator,
            .scope = owned_scope,
            .scopes = .{owned_scope},
            .retry = core.http.RetryPolicy.init(),
            .request_id = core.http.RequestIdPolicy.init(),
            .auth = undefined,
            .policies = undefined,
            .pipeline = undefined,
        };
        state.retry.max_retries = retry_options.max_retries;
        state.retry.initial_delay_ms = retry_options.initial_delay_ms;
        state.retry.max_delay_ms = retry_options.max_delay_ms;
        state.auth = core.http.BearerTokenAuthPolicy.init(
            allocator,
            credential,
            &state.scopes,
        );
        state.policies = .{
            state.retry.asPolicy(),
            state.request_id.asPolicy(),
            state.auth.asPolicy(),
        };
        state.pipeline = core.http.HttpPipeline.init(runtime, &state.policies);
        return state;
    }

    pub fn deinit(self: *PipelineState) void {
        const allocator = self.allocator;
        self.auth.deinit();
        allocator.free(self.scope);
        allocator.destroy(self);
    }
};
