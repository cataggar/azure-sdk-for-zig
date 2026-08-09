//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A paginated list of session tokens. Session tokens correspond to OAuth credentials such as personal access tokens (PATs) and other OAuth authorizations.
pub const TokenAdminPagedSessionTokens = struct {
    /// The continuation token that can be used to retrieve the next page of session tokens, or <code>null</code> if there is no next page.
    continuation_token: ?[]const u8 = null,
    /// The list of all session tokens in the current page.
    value: ?[]const SessionToken = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a session token used to access Azure DevOps resources
pub const SessionToken = struct {
    access_id: ?[]const u8 = null,
    /// This is populated when user requests a compact token. The alternate token value is self describing token.
    alternate_token: ?[]const u8 = null,
    authorization_id: ?[]const u8 = null,
    claims: ?std.json.ArrayHashMap([]const u8) = null,
    client_id: ?[]const u8 = null,
    /// Hash of the Token conforming to the C3ID standard, used for PATs.
    cross_company_correlating_id: ?[]const u8 = null,
    display_name: ?[]const u8 = null,
    host_authorization_id: ?[]const u8 = null,
    is_public: ?bool = null,
    is_valid: ?bool = null,
    public_data: ?[]const u8 = null,
    scope: ?[]const u8 = null,
    source: ?[]const u8 = null,
    target_accounts: ?[]const []const u8 = null,
    /// This is computed and not returned in Get queries
    token: ?[]const u8 = null,
    user_id: ?[]const u8 = null,
    valid_from: ?[]const u8 = null,
    valid_to: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A rule which is applied to disable any incoming delegated authorization which matches the given properties.
pub const TokenAdminRevocationRule = struct {
    /// A datetime cutoff. Tokens created before this time will be rejected. This is an optional parameter. If omitted, defaults to the time at which the rule was created.
    created_before: ?[]const u8 = null,
    /// A string containing a space-delimited list of OAuth scopes. A token matching any one of the scopes will be rejected. For a list of all OAuth scopes supported by Azure DevOps, see: https://docs.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/oauth?view=azure-devops#scopes This is a mandatory parameter.
    scopes: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A request to revoke a particular delegated authorization.
pub const TokenAdminRevocation = struct {
    /// The authorization ID of the OAuth authorization to revoke.
    authorization_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
