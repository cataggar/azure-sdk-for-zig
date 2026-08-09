//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Contains the resulting personal access token (PAT) and the error (if any) that occurred during the operation
pub const PatTokenResult = struct {
    pat_token: ?PatToken = null,
    /// The error (if any) that occurred
    pat_token_error: ?enums.PatTokenResultPatTokenError = null,
    /// The error message (if any) that occurred
    pat_token_error_message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a personal access token (PAT) used to access Azure DevOps resources
pub const PatToken = struct {
    /// Unique guid identifier
    authorization_id: ?[]const u8 = null,
    /// The token name
    display_name: ?[]const u8 = null,
    /// The token scopes for accessing Azure DevOps resources
    scope: ?[]const u8 = null,
    /// The organizations for which the token is valid; null if the token applies to all of the user's accessible organizations
    target_accounts: ?[]const []const u8 = null,
    /// The unique token string generated at creation
    token: ?[]const u8 = null,
    /// The token creation date
    valid_from: ?[]const u8 = null,
    /// The token expiration date
    valid_to: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the request parameters for creating a new personal access token (PAT)
pub const PatTokenCreateRequest = struct {
    /// True, if this personal access token (PAT) is for all of the user's accessible organizations. False, if otherwise (e.g. if the token is for a specific organization)
    all_orgs: ?bool = null,
    /// The token name
    display_name: ?[]const u8 = null,
    /// The token scopes for accessing Azure DevOps resources
    scope: ?[]const u8 = null,
    /// The token expiration date. If the 'Enforce maximum personal access token lifespan' policy is enabled and the provided token expiration date is past the maximum allowed lifespan, it will return back a PAT with a validTo date equal to the current date + maximum allowed lifespan.
    valid_to: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Encapsulates the request parameters for updating a personal access token (PAT)
pub const PatTokenUpdateRequest = struct {
    /// (Optional) True if this personal access token (PAT) is for all of the user's accessible organizations. False if otherwise (e.g. if the token is for a specific organization)
    all_orgs: ?bool = null,
    /// The authorizationId identifying a single, unique personal access token (PAT)
    authorization_id: ?[]const u8 = null,
    /// (Optional) The token name
    display_name: ?[]const u8 = null,
    /// (Optional) The token scopes for accessing Azure DevOps resources
    scope: ?[]const u8 = null,
    /// (Optional) The token expiration date. If the 'Enforce maximum personal access token lifespan' policy is enabled and the provided token expiration date is past the maximum allowed lifespan, it will return back a PAT with a validTo date equal to the date when the PAT was intially created + maximum allowed lifespan.
    valid_to: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
