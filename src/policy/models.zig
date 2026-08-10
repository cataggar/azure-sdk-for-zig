//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `PolicyConfiguration` as returned by Azure DevOps.
pub const PolicyConfigurationList = struct {
    count: ?i32 = null,
    value: ?[]const PolicyConfiguration = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The full policy configuration with settings.
pub const PolicyConfiguration = struct {
    /// The policy configuration ID.
    id: ?i32 = null,
    type: ?PolicyTypeRef = null,
    /// The URL where the policy configuration can be retrieved.
    url: ?[]const u8 = null,
    /// The policy configuration revision ID.
    revision: ?i32 = null,
    links: ?ReferenceLinks = null,
    created_by: ?IdentityRef = null,
    /// The date and time when the policy was created.
    created_date: ?[]const u8 = null,
    /// Indicates whether the policy is blocking.
    is_blocking: ?bool = null,
    /// Indicates whether the policy has been (soft) deleted.
    is_deleted: ?bool = null,
    /// Indicates whether the policy is enabled.
    is_enabled: ?bool = null,
    /// If set, this policy requires 'Manage Enterprise Policies' permission to create, edit, or delete.
    is_enterprise_managed: ?bool = null,
    settings: ?JObject = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Policy type reference.
pub const PolicyTypeRef = struct {
    /// Display name of the policy type.
    display_name: ?[]const u8 = null,
    /// The policy type ID.
    id: ?[]const u8 = null,
    /// The URL where the policy type can be retrieved.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The class to represent a collection of REST reference links.
pub const ReferenceLinks = struct {
    /// The readonly view of the links. Because Reference links are readonly, we only want to expose them as read only.
    links: ?std.json.ArrayHashMap(ReferenceLinksLink) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReferenceLinksLink = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const IdentityRef = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph user referenced in the 'self' entry of the IdentityRef '_links' dictionary
    directory_alias: ?[]const u8 = null,
    id: ?[]const u8 = null,
    /// Deprecated - Available in the 'avatar' entry of the IdentityRef '_links' dictionary
    image_url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph membership state referenced in the 'membershipState' entry of the GraphUser '_links' dictionary
    inactive: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsAadUserType/Descriptor.IsAadGroupType)
    is_aad_identity: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsGroupType)
    is_container: ?bool = null,
    is_deleted_in_origin: ?bool = null,
    /// Deprecated - not in use in most preexisting implementations of ToIdentityRef
    profile_url: ?[]const u8 = null,
    /// Deprecated - use Domain+PrincipalName instead
    unique_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents a JSON object.
pub const JObject = struct {
    item: ?[]const u8 = null,
    /// Gets the node type for this JToken.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `PolicyEvaluationRecord` as returned by Azure DevOps.
pub const PolicyEvaluationRecordList = struct {
    count: ?i32 = null,
    value: ?[]const PolicyEvaluationRecord = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// This record encapsulates the current state of a policy as it applies to one specific pull request. Each pull request has a unique PolicyEvaluationRecord for each pull request which the policy applies to.
pub const PolicyEvaluationRecord = struct {
    links: ?ReferenceLinks = null,
    /// A string which uniquely identifies the target of a policy evaluation.
    artifact_id: ?[]const u8 = null,
    /// Time when this policy finished evaluating on this pull request.
    completed_date: ?[]const u8 = null,
    configuration: ?PolicyConfiguration = null,
    context: ?JObject = null,
    /// Guid which uniquely identifies this evaluation record (one policy running on one pull request).
    evaluation_id: ?[]const u8 = null,
    /// Time when this policy was first evaluated on this pull request.
    started_date: ?[]const u8 = null,
    /// Status of the policy (Running, Approved, Failed, etc.)
    status: ?enums.PolicyEvaluationRecordStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A collection of `PolicyType` as returned by Azure DevOps.
pub const PolicyTypeList = struct {
    count: ?i32 = null,
    value: ?[]const PolicyType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// User-friendly policy type with description (used for querying policy types).
pub const PolicyType = struct {
    /// Display name of the policy type.
    display_name: ?[]const u8 = null,
    /// The policy type ID.
    id: ?[]const u8 = null,
    /// The URL where the policy type can be retrieved.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// Detailed description of the policy type.
    description: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};
