//! Azure Container Registry client with secure challenge authentication.

pub const protocol = @import("azure_rest_container_registry");

const challenge = @import("challenge.zig");
const auth = @import("auth_policy.zig");
const client = @import("client.zig");

pub const BearerChallenge = challenge.BearerChallenge;
pub const parseBearerChallenge = challenge.parseBearerChallenge;
pub const Authentication = auth.Authentication;
pub const ChallengeAuthenticationPolicy = auth.ChallengeAuthenticationPolicy;
pub const ChallengeAuthenticationPolicyOptions = auth.Options;
pub const TimeSource = auth.TimeSource;
pub const ContainerRegistryClient = client.ContainerRegistryClient;
pub const ContainerRegistryClientOptions = client.ContainerRegistryClientOptions;

test {
    @import("std").testing.refAllDecls(@This());
}
