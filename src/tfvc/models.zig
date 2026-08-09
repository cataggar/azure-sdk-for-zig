//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A change.
pub const TfvcChange = struct {
    /// The type of change that was made to the item.
    change_type: ?enums.TfvcChangeChangeType = null,
    /// Current version.
    item: ?[]const u8 = null,
    new_content: ?ItemContent = null,
    /// Path of the item on the server.
    source_server_item: ?[]const u8 = null,
    /// URL to retrieve the item.
    url: ?[]const u8 = null,
    /// List of merge sources in case of rename or branch creation.
    merge_sources: ?[]const TfvcMergeSource = null,
    /// Version at which a (shelved) change was pended against
    pending_version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ItemContent = struct {
    content: ?[]const u8 = null,
    content_type: ?enums.ItemContentContentType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TfvcMergeSource = struct {
    /// Indicates if this a rename source. If false, it is a merge source.
    is_rename: ?bool = null,
    /// The server item of the merge source.
    server_item: ?[]const u8 = null,
    /// Start of the version range.
    version_from: ?i32 = null,
    /// End of the version range.
    version_to: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AssociatedWorkItem = struct {
    assigned_to: ?[]const u8 = null,
    /// Id of associated the work item.
    id: ?i32 = null,
    state: ?[]const u8 = null,
    title: ?[]const u8 = null,
    /// REST Url of the work item.
    url: ?[]const u8 = null,
    web_url: ?[]const u8 = null,
    work_item_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Request body for Get batched changesets.
pub const TfvcChangesetsRequestData = struct {
    /// List of changeset Ids.
    changeset_ids: ?[]const i32 = null,
    /// Max length of the comment.
    comment_length: ?i32 = null,
    /// Whether to include the _links field on the shallow references
    include_links: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Metadata for a changeset.
pub const TfvcChangesetRef = struct {
    links: ?ReferenceLinks = null,
    author: ?IdentityRef = null,
    /// Changeset Id.
    changeset_id: ?i32 = null,
    checked_in_by: ?IdentityRef = null,
    /// Comment for the changeset.
    comment: ?[]const u8 = null,
    /// Was the Comment result truncated?
    comment_truncated: ?bool = null,
    /// Creation date of the changeset.
    created_date: ?[]const u8 = null,
    /// URL to retrieve the item.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
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

/// MappingFilter can be used to include or exclude specific paths.
pub const TfvcMappingFilter = struct {
    /// True if ServerPath should be excluded.
    exclude: ?bool = null,
    /// Path to be included or excluded.
    server_path: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of changes.
pub const TfvcChangeset = struct {
    links: ?ReferenceLinks = null,
    author: ?IdentityRef = null,
    /// Changeset Id.
    changeset_id: ?i32 = null,
    checked_in_by: ?IdentityRef = null,
    /// Comment for the changeset.
    comment: ?[]const u8 = null,
    /// Was the Comment result truncated?
    comment_truncated: ?bool = null,
    /// Creation date of the changeset.
    created_date: ?[]const u8 = null,
    /// URL to retrieve the item.
    url: ?[]const u8 = null,
    /// Changeset Account Id also known as Organization Id.
    account_id: ?[]const u8 = null,
    /// List of associated changes.
    changes: ?[]const TfvcChange = null,
    /// List of Checkin Notes for the changeset.
    checkin_notes: ?[]const CheckinNote = null,
    /// Changeset collection Id.
    collection_id: ?[]const u8 = null,
    /// True if more changes are available.
    has_more_changes: ?bool = null,
    policy_override: ?TfvcPolicyOverrideInfo = null,
    /// Team Project Ids for the changeset.
    team_project_ids: ?[]const []const u8 = null,
    /// List of work items associated with the changeset.
    work_items: ?[]const AssociatedWorkItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const CheckinNote = struct {
    name: ?[]const u8 = null,
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information on the policy override.
pub const TfvcPolicyOverrideInfo = struct {
    /// Overidden policy comment.
    comment: ?[]const u8 = null,
    /// Information on the failed policy that was overridden.
    policy_failures: ?[]const TfvcPolicyFailureInfo = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Policy failure information.
pub const TfvcPolicyFailureInfo = struct {
    /// Policy failure message.
    message: ?[]const u8 = null,
    /// Name of the policy that failed.
    policy_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Metadata for an item.
pub const TfvcItem = struct {
    links: ?ReferenceLinks = null,
    content: ?[]const u8 = null,
    content_metadata: ?FileContentMetadata = null,
    is_folder: ?bool = null,
    is_sym_link: ?bool = null,
    path: ?[]const u8 = null,
    url: ?[]const u8 = null,
    /// Item changed datetime.
    change_date: ?[]const u8 = null,
    /// Greater than 0 if item is deleted.
    deletion_id: ?i32 = null,
    /// File encoding from database, -1 represents binary.
    encoding: ?i32 = null,
    /// MD5 hash as a base 64 string, applies to files only.
    hash_value: ?[]const u8 = null,
    /// True if item is a branch.
    is_branch: ?bool = null,
    /// True if there is a change pending.
    is_pending_change: ?bool = null,
    /// The size of the file, if applicable.
    size: ?i64 = null,
    /// Changeset version Id.
    version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const FileContentMetadata = struct {
    content_type: ?[]const u8 = null,
    encoding: ?i32 = null,
    extension: ?[]const u8 = null,
    file_name: ?[]const u8 = null,
    is_binary: ?bool = null,
    is_image: ?bool = null,
    vs_link: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Metadata for a Label.
pub const TfvcLabelRef = struct {
    links: ?ReferenceLinks = null,
    /// Label description.
    description: ?[]const u8 = null,
    /// Label Id.
    id: ?i32 = null,
    /// Label scope.
    label_scope: ?[]const u8 = null,
    /// Last modified datetime for the label.
    modified_date: ?[]const u8 = null,
    /// Label name.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    /// Label Url.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Metadata for a label.
pub const TfvcLabel = struct {
    links: ?ReferenceLinks = null,
    /// Label description.
    description: ?[]const u8 = null,
    /// Label Id.
    id: ?i32 = null,
    /// Label scope.
    label_scope: ?[]const u8 = null,
    /// Last modified datetime for the label.
    modified_date: ?[]const u8 = null,
    /// Label name.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    /// Label Url.
    url: ?[]const u8 = null,
    /// List of items.
    items: ?[]const TfvcItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Metadata for a shelveset.
pub const TfvcShelveset = struct {
    links: ?ReferenceLinks = null,
    /// Shelveset comment.
    comment: ?[]const u8 = null,
    /// Shelveset comment truncated as applicable.
    comment_truncated: ?bool = null,
    /// Shelveset create date.
    created_date: ?[]const u8 = null,
    /// Shelveset Id.
    id: ?[]const u8 = null,
    /// Shelveset name.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    /// Shelveset Url.
    url: ?[]const u8 = null,
    /// List of changes.
    changes: ?[]const TfvcChange = null,
    /// List of checkin notes.
    notes: ?[]const CheckinNote = null,
    policy_override: ?TfvcPolicyOverrideInfo = null,
    /// List of associated workitems.
    work_items: ?[]const AssociatedWorkItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Metadata for a branchref.
pub const TfvcBranchRef = struct {
    /// Path for the branch.
    path: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// Creation date of the branch.
    created_date: ?[]const u8 = null,
    /// Branch description.
    description: ?[]const u8 = null,
    /// Is the branch deleted?
    is_deleted: ?bool = null,
    owner: ?IdentityRef = null,
    /// URL to retrieve the item.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Request body used by Get Items Batch
pub const TfvcItemRequestData = struct {
    /// If true, include metadata about the file type
    include_content_metadata: ?bool = null,
    /// Whether to include the _links field on the shallow references
    include_links: ?bool = null,
    item_descriptors: ?[]const TfvcItemDescriptor = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Item path and Version descriptor properties
pub const TfvcItemDescriptor = struct {
    /// Item path.
    path: ?[]const u8 = null,
    /// Defaults to OneLevel.
    recursion_level: ?enums.TfvcItemDescriptorRecursionLevel = null,
    /// Specify the desired version, can be null or empty string only if VersionType is latest or tip.
    version: ?[]const u8 = null,
    /// Defaults to None.
    version_option: ?enums.TfvcItemDescriptorVersionOption = null,
    /// Defaults to Latest.
    version_type: ?enums.TfvcItemDescriptorVersionType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
