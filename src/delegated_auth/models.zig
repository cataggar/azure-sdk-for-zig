//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const JsonWebToken = struct {
    is_authenticated: ?bool = null,
    properties: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// ADO OAuth App Registration
pub const Registration = struct {
    access_hash: ?[]const u8 = null,
    /// Alternative Secret
    alternative_secret: ?[]const u8 = null,
    /// Alternative Secret valid from
    alternative_secret_valid_from: ?[]const u8 = null,
    /// Alternative Secret valid to
    alternative_secret_valid_to: ?[]const u8 = null,
    /// Alternative Secret Version Id of the ADO OAuth App Registration
    alternative_secret_version_id: ?[]const u8 = null,
    /// Differentiate the different registration types
    client_type: ?enums.RegistrationClientType = null,
    /// Identity Id of the owner of the ADO OAuth App Registration
    identity_id: ?[]const u8 = null,
    issuer: ?[]const u8 = null,
    /// Validity of the ADO OAuth App Registration
    is_valid: ?bool = null,
    is_well_known: ?bool = null,
    /// URL of the organization that that is registering the app to use OAuthURL of the organization that that is registering the app to use OAuth
    organization_location: ?[]const u8 = null,
    /// Name of the organization that that is registering the app to use OAuth
    organization_name: ?[]const u8 = null,
    /// Raw cert data string from public key. This will be used for authenticating medium trust clients.
    public_key: ?[]const u8 = null,
    /// Redirect URIs of the ADO OAuth App Registration
    redirect_uris: ?[]const []const u8 = null,
    /// Description of the ADO OAuth App Registration
    registration_description: ?[]const u8 = null,
    /// Registration Id of the ADO OAuth App Registration
    registration_id: ?[]const u8 = null,
    /// URL of the ADO OAuth App Registration
    registration_location: ?[]const u8 = null,
    /// URL of the ADO OAuth App Registration Logo
    registration_logo_secure_location: ?[]const u8 = null,
    /// Name of the ADO OAuth App Registration
    registration_name: ?[]const u8 = null,
    /// URL of the ADO OAuth App Registration Privacy Statement
    registration_privacy_statement_location: ?[]const u8 = null,
    /// URL of the ADO OAuth App Registration Terms of Service
    registration_terms_of_service_location: ?[]const u8 = null,
    response_types: ?[]const u8 = null,
    /// Scopes that the app will have access to in ADO on behalf of the users
    scopes: ?[]const u8 = null,
    secondary_hash: ?[]const u8 = null,
    /// Primary Secret
    secret: ?[]const u8 = null,
    /// Primary Secret valid to
    secret_valid_to: ?[]const u8 = null,
    /// Primary Secret Version Id of the ADO OAuth App Registration
    secret_version_id: ?[]const u8 = null,
    /// URL of the ADO OAuth App Registration Setup
    setup_uri: ?[]const u8 = null,
    tenant_ids: ?[]const []const u8 = null,
    /// Primary Secret valid from
    valid_from: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
