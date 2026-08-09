//! Azure DevOps SDK for Zig.
//!
//! A hand-written layer over the generated `azure_rest_devops` protocol
//! package: it adds Azure DevOps' credential model, one pipeline shared
//! by all 44 API areas, continuation-token paging, and error handling for
//! the service's non-standard failure shapes. The generated protocol
//! surface is re-exported as `protocol` so any operation stays reachable
//! even when this package offers no convenience wrapper for it.

const std = @import("std");

pub const protocol = @import("azure_rest_devops");

const auth = @import("auth.zig");
const client = @import("client.zig");
const continuation = @import("continuation.zig");
const service_error = @import("service_error.zig");

pub const Credential = auth.Credential;
pub const CredentialPolicy = auth.CredentialPolicy;
pub const CredentialPolicyOptions = auth.CredentialPolicy.Options;
pub const devops_scope = auth.devops_scope;

pub const DevOpsClient = client.DevOpsClient;
pub const ClientOptions = client.ClientOptions;
pub const user_agent = client.user_agent;

pub const ContinuationPager = continuation.ContinuationPager;
pub const Page = continuation.Page;

pub const ServiceError = service_error.ServiceError;
pub const ServiceErrorInfo = service_error.ServiceErrorInfo;
pub const parseServiceError = service_error.parse;
pub const isSignInPage = service_error.isSignInPage;

test {
    std.testing.refAllDecls(@This());
    _ = auth;
    _ = client;
    _ = continuation;
    _ = service_error;
    _ = @import("client_test.zig");
}
