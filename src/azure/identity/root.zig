///! Azure Identity — credential implementations.
///!
///! Provides DefaultAzureCredential and individual credential types for
///! authenticating with Azure services.

const core = @import("azure_core");

pub const TokenCredential = core.credentials.TokenCredential;
pub const AccessToken = core.credentials.AccessToken;
pub const TokenRequestContext = core.credentials.TokenRequestContext;

// Individual credentials will be added in Phase 2:
// pub const client_secret = @import("client_secret.zig");
// pub const environment = @import("environment.zig");
// pub const managed_identity = @import("managed_identity.zig");
// pub const azure_cli = @import("azure_cli.zig");
// pub const default_azure_credential = @import("default_azure_credential.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
