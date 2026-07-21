//! Azure Container Registry client with secure challenge authentication.

pub const protocol = @import("azure_rest_container_registry");

const challenge = @import("challenge.zig");
const auth = @import("auth_policy.zig");
const client = @import("client.zig");
const models = @import("models.zig");
const service_error = @import("service_error.zig");

pub const BearerChallenge = challenge.BearerChallenge;
pub const parseBearerChallenge = challenge.parseBearerChallenge;
pub const Authentication = auth.Authentication;
pub const ChallengeAuthenticationPolicy = auth.ChallengeAuthenticationPolicy;
pub const ChallengeAuthenticationPolicyOptions = auth.Options;
pub const TimeSource = auth.TimeSource;
pub const ContainerRegistryClient = client.ContainerRegistryClient;
pub const ContainerRegistryClientOptions = client.ContainerRegistryClientOptions;
pub const ListRepositoriesOptions = client.ListRepositoriesOptions;
pub const ListManifestPropertiesOptions = client.ListManifestPropertiesOptions;
pub const ListTagPropertiesOptions = client.ListTagPropertiesOptions;
pub const RepositoryPager = client.RepositoryPager;
pub const ManifestPager = client.ManifestPager;
pub const TagPager = client.TagPager;
pub const RepositoryPropertiesResult = client.RepositoryPropertiesResult;
pub const ManifestPropertiesResult = client.ManifestPropertiesResult;
pub const TagPropertiesResult = client.TagPropertiesResult;
pub const DeleteResult = client.DeleteResult;
pub const ChangeableProperties = models.ChangeableProperties;
pub const ContainerRepositoryProperties = models.ContainerRepositoryProperties;
pub const ArtifactManifestPlatform = models.ArtifactManifestPlatform;
pub const ArtifactManifestProperties = models.ArtifactManifestProperties;
pub const ArtifactTagProperties = models.ArtifactTagProperties;
pub const RepositoryPage = models.RepositoryPage;
pub const ManifestPage = models.ManifestPage;
pub const TagPage = models.TagPage;
pub const ServiceErrorInfo = service_error.ServiceErrorInfo;
pub const ServiceError = service_error.ServiceError;
pub const ContainerRegistryServiceError = service_error.ServiceError;
pub const Result = service_error.Result;
pub const ArtifactManifestOrder = protocol.enums.ArtifactManifestOrder;
pub const ArtifactTagOrder = protocol.enums.ArtifactTagOrder;

test {
    @import("std").testing.refAllDecls(@This());
    _ = @import("metadata_test.zig");
}
