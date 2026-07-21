const std = @import("std");
const core = @import("azure_core");
const protocol = @import("azure_rest_container_registry");
const auth = @import("auth_policy.zig");

pub const ContainerRegistryClientOptions = struct {
    transport: *core.http.HttpTransport,
    authentication: auth.Authentication,
    api_version: []const u8 = "2021-07-01",
    authentication_options: auth.Options = .{},
};

/// Authenticated wrapper over the generated Container Registry protocol client.
pub const ContainerRegistryClient = struct {
    allocator: std.mem.Allocator,
    auth_policy: *auth.ChallengeAuthenticationPolicy,
    policy_ptrs: []*core.pipeline.HttpPolicy,
    protocol_client: protocol.ContainerRegistryClient,

    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        options: ContainerRegistryClientOptions,
    ) !ContainerRegistryClient {
        var authentication_options = options.authentication_options;
        authentication_options.api_version = options.api_version;
        const auth_policy = try allocator.create(auth.ChallengeAuthenticationPolicy);
        errdefer allocator.destroy(auth_policy);
        auth_policy.* = try auth.ChallengeAuthenticationPolicy.init(
            allocator,
            endpoint,
            options.authentication,
            authentication_options,
        );
        errdefer auth_policy.deinit();

        const policy_ptrs = try allocator.alloc(*core.pipeline.HttpPolicy, 1);
        errdefer allocator.free(policy_ptrs);
        policy_ptrs[0] = auth_policy.asPolicy();

        const pipeline = core.pipeline.HttpPipeline{
            .policies = policy_ptrs,
            .transport_impl = options.transport,
        };
        return .{
            .allocator = allocator,
            .auth_policy = auth_policy,
            .policy_ptrs = policy_ptrs,
            .protocol_client = protocol.ContainerRegistryClient.initWithPipeline(
                allocator,
                pipeline,
                .{
                    .endpoint = auth_policy.endpoint,
                    .api_version = options.api_version,
                },
            ),
        };
    }

    pub fn deinit(self: *ContainerRegistryClient) void {
        self.protocol_client.deinit();
        self.allocator.free(self.policy_ptrs);
        self.auth_policy.deinit();
        self.allocator.destroy(self.auth_policy);
        self.* = undefined;
    }

    /// Access the generated protocol client using the prepared challenge-auth
    /// pipeline. The returned pointer borrows from this client.
    pub fn protocolClient(self: *ContainerRegistryClient) *protocol.ContainerRegistryClient {
        return &self.protocol_client;
    }
};

test "ContainerRegistryClient drives generated protocol APIs through challenge auth" {
    const allocator = std.testing.allocator;
    const challenge =
        "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"registry:catalog:*\"";
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{
            .status = 200,
            .body = "{\"access_token\":\"e30.eyJleHAiOjQxMDI0NDQ4MDB9.signature\"}",
        },
        .{ .status = 200, .body = "" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var client = try ContainerRegistryClient.init(
        allocator,
        "https://registry.example",
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer client.deinit();

    var service = client.protocolClient().containerRegistry();
    try service.checkDockerV2Support(allocator);
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expect(transport.captured_authorization[2]);
}
