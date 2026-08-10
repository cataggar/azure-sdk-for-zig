//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const PatTokenResultPatTokenError = union(enum) {
    none,
    display_name_required,
    invalid_display_name,
    invalid_valid_to,
    invalid_scope,
    user_id_required,
    invalid_user_id,
    invalid_user_type,
    access_denied,
    failed_to_issue_access_token,
    invalid_client,
    invalid_client_type,
    invalid_client_id,
    invalid_target_accounts,
    host_authorization_not_found,
    authorization_not_found,
    failed_to_update_access_token,
    source_not_supported,
    invalid_source_ip,
    invalid_source,
    duplicate_hash,
    ssh_policy_disabled,
    invalid_token,
    token_not_found,
    invalid_authorization_id,
    failed_to_read_tenant_policy,
    global_pat_policy_violation,
    full_scope_pat_policy_violation,
    pat_lifespan_policy_violation,
    invalid_token_type,
    invalid_audience,
    invalid_subject,
    deployment_host_not_supported,
    disable_pat_creation_policy_violation,
    failed_to_read_org_policy,
    global_pat_creation_blocked,
    expired_pat_cannot_be_extended,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .display_name_required = "displayNameRequired",
        .invalid_display_name = "invalidDisplayName",
        .invalid_valid_to = "invalidValidTo",
        .invalid_scope = "invalidScope",
        .user_id_required = "userIdRequired",
        .invalid_user_id = "invalidUserId",
        .invalid_user_type = "invalidUserType",
        .access_denied = "accessDenied",
        .failed_to_issue_access_token = "failedToIssueAccessToken",
        .invalid_client = "invalidClient",
        .invalid_client_type = "invalidClientType",
        .invalid_client_id = "invalidClientId",
        .invalid_target_accounts = "invalidTargetAccounts",
        .host_authorization_not_found = "hostAuthorizationNotFound",
        .authorization_not_found = "authorizationNotFound",
        .failed_to_update_access_token = "failedToUpdateAccessToken",
        .source_not_supported = "sourceNotSupported",
        .invalid_source_ip = "invalidSourceIP",
        .invalid_source = "invalidSource",
        .duplicate_hash = "duplicateHash",
        .ssh_policy_disabled = "sshPolicyDisabled",
        .invalid_token = "invalidToken",
        .token_not_found = "tokenNotFound",
        .invalid_authorization_id = "invalidAuthorizationId",
        .failed_to_read_tenant_policy = "failedToReadTenantPolicy",
        .global_pat_policy_violation = "globalPatPolicyViolation",
        .full_scope_pat_policy_violation = "fullScopePatPolicyViolation",
        .pat_lifespan_policy_violation = "patLifespanPolicyViolation",
        .invalid_token_type = "invalidTokenType",
        .invalid_audience = "invalidAudience",
        .invalid_subject = "invalidSubject",
        .deployment_host_not_supported = "deploymentHostNotSupported",
        .disable_pat_creation_policy_violation = "disablePatCreationPolicyViolation",
        .failed_to_read_org_policy = "failedToReadOrgPolicy",
        .global_pat_creation_blocked = "globalPATCreationBlocked",
        .expired_pat_cannot_be_extended = "expiredPatCannotBeExtended",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const ServiceApiVersions = enum {
    v7_2_preview,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .v7_2_preview => "7.2-preview",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "7.2-preview")) return .v7_2_preview;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};
