///! Azure Identity — credential implementations.
///!
///! Provides DefaultAzureCredential and individual credential types for
///! authenticating with Azure services.
const core = @import("azure_core");

pub const TokenCredential = core.credentials.TokenCredential;
pub const AccessToken = core.credentials.AccessToken;
pub const TokenRequestContext = core.credentials.TokenRequestContext;

pub const client_secret = @import("client_secret.zig");
pub const client_assertion = @import("client_assertion.zig");
pub const environment = @import("environment.zig");
pub const managed_identity = @import("managed_identity.zig");
pub const azure_cli = @import("azure_cli.zig");
pub const azure_developer_cli = @import("azure_developer_cli.zig");
pub const workload_identity = @import("workload_identity.zig");
pub const default_azure_credential = @import("default_azure_credential.zig");

// Convenience aliases.
pub const ClientSecretCredential = client_secret.ClientSecretCredential;
pub const ClientAssertionCredential = client_assertion.ClientAssertionCredential;
pub const EnvironmentCredential = environment.EnvironmentCredential;
pub const ManagedIdentityCredential = managed_identity.ManagedIdentityCredential;
pub const AzureCliCredential = azure_cli.AzureCliCredential;
pub const AzureDeveloperCliCredential = azure_developer_cli.AzureDeveloperCliCredential;
pub const WorkloadIdentityCredential = workload_identity.WorkloadIdentityCredential;
pub const ChainedTokenCredential = default_azure_credential.ChainedTokenCredential;
pub const DefaultAzureCredential = default_azure_credential.DefaultAzureCredential;

test {
    @import("std").testing.refAllDecls(@This());
}
