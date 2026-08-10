//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `WorkArtifactLink` as returned by Azure DevOps.
pub const WorkArtifactLinkList = struct {
    count: ?i32 = null,
    value: ?[]const WorkArtifactLink = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A work artifact link describes an outbound artifact link type.
pub const WorkArtifactLink = struct {
    /// Target artifact type.
    artifact_type: ?[]const u8 = null,
    /// Outbound link type.
    link_type: ?[]const u8 = null,
    /// Target tool type.
    tool_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemIcon` as returned by Azure DevOps.
pub const WorkItemIconList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemIcon = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to a work item icon.
pub const WorkItemIcon = struct {
    /// The identifier of the icon.
    id: ?[]const u8 = null,
    /// The REST URL of the resource.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemRelationType` as returned by Azure DevOps.
pub const WorkItemRelationTypeList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemRelationType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the work item type relation type.
pub const WorkItemRelationType = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The name.
    name: ?[]const u8 = null,
    /// The reference name.
    reference_name: ?[]const u8 = null,
    /// The collection of relation type attributes.
    attributes: ?std.json.ArrayHashMap(WorkItemRelationTypeAttribute) = null,

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

pub const WorkItemRelationTypeAttribute = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemNextStateOnTransition` as returned by Azure DevOps.
pub const WorkItemNextStateOnTransitionList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemNextStateOnTransition = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes the next state for a work item.
pub const WorkItemNextStateOnTransition = struct {
    /// Error code if there is no next state transition possible.
    error_code: ?[]const u8 = null,
    /// Work item ID.
    id: ?i32 = null,
    /// Error message if there is no next state transition possible.
    message: ?[]const u8 = null,
    /// Name of the next state on transition.
    state_on_transition: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `AccountRecentActivityWorkItemModel2` as returned by Azure DevOps.
pub const AccountRecentActivityWorkItemModel2List = struct {
    count: ?i32 = null,
    value: ?[]const AccountRecentActivityWorkItemModel2 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents Work Item Recent Activity
pub const AccountRecentActivityWorkItemModel2 = struct {
    /// Date of the last Activity by the user
    activity_date: ?[]const u8 = null,
    /// Type of the activity
    activity_type: ?enums.AccountRecentActivityWorkItemModel2ActivityType = null,
    /// Last changed date of the work item
    changed_date: ?[]const u8 = null,
    /// Work Item Id
    id: ?i32 = null,
    /// TeamFoundationId of the user this activity belongs to
    identity_id: ?[]const u8 = null,
    /// State of the work item
    state: ?[]const u8 = null,
    /// Team project the work item belongs to
    team_project: ?[]const u8 = null,
    /// Title of the work item
    title: ?[]const u8 = null,
    /// Type of Work Item
    work_item_type: ?[]const u8 = null,
    assigned_to: ?IdentityRef = null,

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

/// A collection of `GitHubConnectionModel` as returned by Azure DevOps.
pub const GitHubConnectionModelList = struct {
    count: ?i32 = null,
    value: ?[]const GitHubConnectionModel = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes Github connection.
pub const GitHubConnectionModel = struct {
    /// Github connection authorization type (f. e. PAT, OAuth)
    authorization_type: ?[]const u8 = null,
    created_by: ?IdentityRef = null,
    /// Github connection id
    id: ?[]const u8 = null,
    /// Whether current Github connection is valid or not
    is_connection_valid: ?bool = null,
    /// Github connection name (should contain organization/user name)
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `GitHubConnectionRepoModel` as returned by Azure DevOps.
pub const GitHubConnectionRepoModelList = struct {
    count: ?i32 = null,
    value: ?[]const GitHubConnectionRepoModel = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes Github connection's repo.
pub const GitHubConnectionRepoModel = struct {
    /// Error message
    error_message: ?[]const u8 = null,
    /// Repository web url
    git_hub_repository_url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes Github connection's repo bulk request
pub const GitHubConnectionReposBatchRequest = struct {
    /// Requested repos urls
    git_hub_repository_urls: ?[]const GitHubConnectionRepoModel = null,
    /// Operation type (f. e. add, remove)
    operation_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contains criteria for querying work items based on artifact URI.
pub const ArtifactUriQuery = struct {
    /// List of artifact URIs to use for querying work items.
    artifact_uris: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines result of artifact URI query on work items. Contains mapping of work item IDs to artifact URI.
pub const ArtifactUriQueryResult = struct {
    /// A Dictionary that maps a list of work item references to the given list of artifact URI.
    artifact_uris_query_result: ?std.json.ArrayHashMap([]const WorkItemReference) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contains reference to a work item.
pub const WorkItemReference = struct {
    /// Work item ID.
    id: ?i32 = null,
    /// REST API URL of the resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AttachmentReference = struct {
    id: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes permanently deleted attachment and work items that had links to this attachment.
pub const DestroyedAttachment = struct {
    /// Work items with attachment references that have been marked as deleted.
    affected_work_items: ?[]const WorkItemReference = null,
    attachment: ?AttachmentReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemClassificationNode` as returned by Azure DevOps.
pub const WorkItemClassificationNodeList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemClassificationNode = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a classification node for work item tracking.
pub const WorkItemClassificationNode = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// Dictionary that has node attributes like start/finish date for iteration nodes.
    attributes: ?std.json.ArrayHashMap(WorkItemClassificationNodeAttribute) = null,
    /// List of child nodes fetched.
    children: ?[]const WorkItemClassificationNode = null,
    /// Flag that indicates if the classification node has any child nodes.
    has_children: ?bool = null,
    /// Integer ID of the classification node.
    id: ?i32 = null,
    /// GUID ID of the classification node.
    identifier: ?[]const u8 = null,
    /// Name of the classification node.
    name: ?[]const u8 = null,
    /// Path of the classification node.
    path: ?[]const u8 = null,
    /// Node structure type.
    structure_type: ?enums.WorkItemClassificationNodeStructureType = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const WorkItemClassificationNodeAttribute = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemField2` as returned by Azure DevOps.
pub const WorkItemField2List = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemField2 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a field on a work item and it's properties specific to that work item type.
pub const WorkItemField2 = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// Indicates whether the field is sortable in server queries.
    can_sort_by: ?bool = null,
    /// The description of the field.
    description: ?[]const u8 = null,
    /// Indicates whether this field is deleted.
    is_deleted: ?bool = null,
    /// Indicates whether this field is an identity field.
    is_identity: ?bool = null,
    /// Indicates whether this instance is picklist.
    is_picklist: ?bool = null,
    /// Indicates whether this instance is a suggested picklist .
    is_picklist_suggested: ?bool = null,
    /// Indicates whether the field can be queried in the server.
    is_queryable: ?bool = null,
    /// The name of the field.
    name: ?[]const u8 = null,
    /// If this field is picklist, the identifier of the picklist associated, otherwise null
    picklist_id: ?[]const u8 = null,
    /// Indicates whether the field is [read only].
    read_only: ?bool = null,
    /// The reference name of the field.
    reference_name: ?[]const u8 = null,
    /// The supported operations on this field.
    supported_operations: ?[]const WorkItemFieldOperation = null,
    /// The type of the field.
    type: ?enums.WorkItemField2Type = null,
    /// The usage of the field.
    usage: ?enums.WorkItemField2Usage = null,
    /// Indicates whether this field is marked as locked for editing.
    is_locked: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Describes a work item field operation.
pub const WorkItemFieldOperation = struct {
    /// Friendly name of the operation.
    name: ?[]const u8 = null,
    /// Reference name of the operation.
    reference_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes an update request for a work item field.
pub const FieldUpdate = struct {
    /// Indicates whether the user wants to restore the field.
    is_deleted: ?bool = null,
    /// Indicates whether the user wants to lock the field.
    is_locked: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Stores process ID.
pub const ProcessIdModel = struct {
    /// The ID of the process.
    type_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Stores project ID and its process ID.
pub const ProcessMigrationResultModel = struct {
    /// The ID of the process.
    process_id: ?[]const u8 = null,
    /// The ID of the project.
    project_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `QueryHierarchyItem` as returned by Azure DevOps.
pub const QueryHierarchyItemList = struct {
    count: ?i32 = null,
    value: ?[]const QueryHierarchyItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an item in the work item query hierarchy. This can be either a query or a folder.
pub const QueryHierarchyItem = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The child query items inside a query folder.
    children: ?[]const QueryHierarchyItem = null,
    clauses: ?WorkItemQueryClause = null,
    /// The columns of the query.
    columns: ?[]const WorkItemFieldReference = null,
    created_by: ?IdentityReference = null,
    /// When the query item was created.
    created_date: ?[]const u8 = null,
    /// The link query mode.
    filter_options: ?enums.QueryHierarchyItemFilterOptions = null,
    /// If this is a query folder, indicates if it contains any children.
    has_children: ?bool = null,
    /// The id of the query item.
    id: ?[]const u8 = null,
    /// Indicates if this query item is deleted. Setting this to false on a deleted query item will undelete it. Undeleting a query or folder will not bring back the permission changes that were previously applied to it.
    is_deleted: ?bool = null,
    /// Indicates if this is a query folder or a query.
    is_folder: ?bool = null,
    /// Indicates if the WIQL of this query is invalid. This could be due to invalid syntax or a no longer valid area/iteration path.
    is_invalid_syntax: ?bool = null,
    /// Indicates if this query item is public or private.
    is_public: ?bool = null,
    last_executed_by: ?IdentityReference = null,
    /// When the query was last run.
    last_executed_date: ?[]const u8 = null,
    last_modified_by: ?IdentityReference = null,
    /// When the query item was last modified.
    last_modified_date: ?[]const u8 = null,
    link_clauses: ?WorkItemQueryClause = null,
    /// The name of the query item.
    name: ?[]const u8 = null,
    /// The path of the query item.
    path: ?[]const u8 = null,
    /// The recursion option for use in a tree query.
    query_recursion_option: ?enums.QueryHierarchyItemQueryRecursionOption = null,
    /// The type of query.
    query_type: ?enums.QueryHierarchyItemQueryType = null,
    /// The sort columns of the query.
    sort_columns: ?[]const WorkItemQuerySortColumn = null,
    source_clauses: ?WorkItemQueryClause = null,
    target_clauses: ?WorkItemQueryClause = null,
    /// The WIQL text of the query
    wiql: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents a clause in a work item query. This shows the structure of a work item query.
pub const WorkItemQueryClause = struct {
    /// Child clauses if the current clause is a logical operator
    clauses: ?[]const WorkItemQueryClause = null,
    field: ?WorkItemFieldReference = null,
    field_value: ?WorkItemFieldReference = null,
    /// Determines if this is a field to field comparison
    is_field_value: ?bool = null,
    /// Logical operator separating the condition clause
    logical_operator: ?enums.WorkItemQueryClauseLogicalOperator = null,
    operator: ?WorkItemFieldOperation = null,
    /// Right side of the condition when a field to value comparison
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to a field in a work item
pub const WorkItemFieldReference = struct {
    /// The friendly name of the field.
    name: ?[]const u8 = null,
    /// The reference name of the field.
    reference_name: ?[]const u8 = null,
    /// The REST URL of the resource.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a reference to an identity.
pub const IdentityReference = struct {
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
    /// Legacy back-compat property. This has been the WIT specific value from Constants. Will be hidden (but exists) on the client unless they are targeting the newest version
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A sort column.
pub const WorkItemQuerySortColumn = struct {
    /// The direction to sort by.
    descending: ?bool = null,
    field: ?WorkItemFieldReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a request to get a list of queries
pub const QueryBatchGetRequest = struct {
    /// The expand parameters for queries. Possible options are { None, Wiql, Clauses, All, Minimal }
    @"$expand": ?enums.QueryBatchGetRequestExpand = null,
    /// The flag to control error policy in a query batch request. Possible options are { Fail, Omit }.
    error_policy: ?enums.QueryBatchGetRequestErrorPolicy = null,
    /// The requested query ids
    ids: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemDeleteShallowReference` as returned by Azure DevOps.
pub const WorkItemDeleteShallowReferenceList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemDeleteShallowReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Shallow Reference to a deleted work item.
pub const WorkItemDeleteShallowReference = struct {
    /// Work item ID.
    id: ?i32 = null,
    /// REST API URL of the resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Full deleted work item object. Includes the work item itself.
pub const WorkItemDelete = struct {
    /// The HTTP status code for work item operation in a batch request.
    code: ?i32 = null,
    /// The user who deleted the work item type.
    deleted_by: ?[]const u8 = null,
    /// The work item deletion date.
    deleted_date: ?[]const u8 = null,
    /// Work item ID.
    id: ?i32 = null,
    /// The exception message for work item operation in a batch request.
    message: ?[]const u8 = null,
    /// Name or title of the work item.
    name: ?[]const u8 = null,
    /// Parent project of the deleted work item.
    project: ?[]const u8 = null,
    /// Type of work item.
    type: ?[]const u8 = null,
    /// REST API URL of the resource
    url: ?[]const u8 = null,
    resource: ?WorkItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a work item.
pub const WorkItem = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    comment_version_ref: ?WorkItemCommentVersionRef = null,
    /// Map of field and values for the work item.
    fields: ?std.json.ArrayHashMap(WorkItemField) = null,
    /// The work item ID.
    id: ?i32 = null,
    /// Dictionary describing the Format for multiline fields selected by the last edit user.
    multiline_fields_format: ?std.json.ArrayHashMap(enums.WorkItemMultilineFieldsFormat) = null,
    /// Relations of the work item.
    relations: ?[]const WorkItemRelation = null,
    /// Revision number of the work item.
    rev: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents the reference to a specific version of a comment on a Work Item.
pub const WorkItemCommentVersionRef = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    /// The id assigned to the comment.
    comment_id: ?i32 = null,
    /// [Internal] The work item revision where this comment was originally added.
    created_in_revision: ?i32 = null,
    /// [Internal] Specifies whether comment was deleted.
    is_deleted: ?bool = null,
    /// [Internal] The text of the comment.
    text: ?[]const u8 = null,
    /// The version number.
    version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemField = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemRelation = struct {
    /// Collection of link attributes.
    attributes: ?std.json.ArrayHashMap(WorkItemRelationAttribute) = null,
    /// Relation type.
    rel: ?[]const u8 = null,
    /// Link url.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemRelationAttribute = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes an update request for a deleted work item.
pub const WorkItemDeleteUpdate = struct {
    /// Sets a value indicating whether this work item is deleted.
    is_deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReportingWorkItemLinksBatch = struct {
    /// ContinuationToken acts as a waterMark. Used while querying large results.
    continuation_token: ?[]const u8 = null,
    /// Returns 'true' if it's last batch, 'false' otherwise.
    is_last_batch: ?bool = null,
    /// The next link for the work item.
    next_link: ?[]const u8 = null,
    /// Values such as rel, sourceId, TargetId, ChangedDate, isActive.
    values: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReportingWorkItemRevisionsBatch = struct {
    /// ContinuationToken acts as a waterMark. Used while querying large results.
    continuation_token: ?[]const u8 = null,
    /// Returns 'true' if it's last batch, 'false' otherwise.
    is_last_batch: ?bool = null,
    /// The next link for the work item.
    next_link: ?[]const u8 = null,
    /// Values such as rel, sourceId, TargetId, ChangedDate, isActive.
    values: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The class represents the reporting work item revision filer.
pub const ReportingWorkItemRevisionsFilter = struct {
    /// A list of fields to return in work item revisions. Omit this parameter to get all reportable fields.
    fields: ?[]const []const u8 = null,
    /// Include deleted work item in the result.
    include_deleted: ?bool = null,
    /// Return an identity reference instead of a string value for identity fields.
    include_identity_ref: ?bool = null,
    /// Include only the latest version of a work item, skipping over all previous revisions of the work item.
    include_latest_only: ?bool = null,
    /// Include tag reference instead of string value for System.Tags field
    include_tag_ref: ?bool = null,
    /// A list of types to filter the results to specific work item types. Omit this parameter to get work item revisions of all work item types.
    types: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SendMailBody = struct {
    fields: ?[]const []const u8 = null,
    ids: ?[]const i32 = null,
    message: ?MailMessage = null,
    persistence_id: ?[]const u8 = null,
    project_id: ?[]const u8 = null,
    sort_fields: ?[]const []const u8 = null,
    temp_query_id: ?[]const u8 = null,
    wiql: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const MailMessage = struct {
    /// The mail body in HTML format.
    body: ?[]const u8 = null,
    cc: ?EmailRecipients = null,
    /// The in-reply-to header value
    in_reply_to: ?[]const u8 = null,
    /// The Message Id value
    message_id: ?[]const u8 = null,
    reply_to: ?EmailRecipients = null,
    /// The mail subject.
    subject: ?[]const u8 = null,
    to: ?EmailRecipients = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const EmailRecipients = struct {
    /// Plaintext email addresses.
    email_addresses: ?[]const []const u8 = null,
    /// TfIds
    tf_ids: ?[]const []const u8 = null,
    /// Unresolved entity ids
    unresolved_entity_ids: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemTagDefinition` as returned by Azure DevOps.
pub const WorkItemTagDefinitionList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemTagDefinition = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemTagDefinition = struct {
    id: ?[]const u8 = null,
    last_updated: ?[]const u8 = null,
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a request to create a temporary query
pub const TemporaryQueryRequestModel = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The WIQL text of the temporary query
    wiql: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The result of a temporary query creation.
pub const TemporaryQueryResponseModel = struct {
    /// The id of the temporary query item.
    id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItem` as returned by Azure DevOps.
pub const WorkItemList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The JSON model for JSON Patch Operations
pub const JsonPatchDocument = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a request to get a set of work items
pub const WorkItemBatchGetRequest = struct {
    /// The expand parameters for work item attributes. Possible options are { None, Relations, Fields, Links, All }
    @"$expand": ?enums.WorkItemBatchGetRequestExpand = null,
    /// AsOf UTC date time string
    as_of: ?[]const u8 = null,
    /// The flag to control error policy in a bulk get work items request. Possible options are {Fail, Omit}.
    error_policy: ?enums.WorkItemBatchGetRequestErrorPolicy = null,
    /// The requested fields
    fields: ?[]const []const u8 = null,
    /// The requested work item ids
    ids: ?[]const i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a request to delete a set of work items
pub const WorkItemDeleteBatchRequest = struct {
    /// Optional parameter, if set to true, the work item is deleted permanently. Please note: the destroy action is PERMANENT and cannot be undone.
    destroy: ?bool = null,
    /// The requested work item ids
    ids: ?[]const i32 = null,
    /// Optional parameter, if set to true, notifications will be disabled.
    skip_notifications: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes response to delete a set of work items.
pub const WorkItemDeleteBatch = struct {
    /// List of results for each work item
    results: ?[]const WorkItemDelete = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemUpdate` as returned by Azure DevOps.
pub const WorkItemUpdateList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemUpdate = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes an update to a work item.
pub const WorkItemUpdate = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// List of updates to fields.
    fields: ?std.json.ArrayHashMap(WorkItemFieldUpdate) = null,
    /// ID of update.
    id: ?i32 = null,
    relations: ?WorkItemRelationUpdates = null,
    /// The revision number of work item update.
    rev: ?i32 = null,
    revised_by: ?IdentityReference = null,
    /// The work item updates revision date.
    revised_date: ?[]const u8 = null,
    /// The work item ID.
    work_item_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Describes an update to a work item field.
pub const WorkItemFieldUpdate = struct {
    /// The new value of the field.
    new_value: ?WorkItemFieldUpdateNewValue = null,
    /// The old value of the field.
    old_value: ?WorkItemFieldUpdateOldValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemFieldUpdateNewValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemFieldUpdateOldValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes updates to a work item's relations.
pub const WorkItemRelationUpdates = struct {
    /// List of newly added relations.
    added: ?[]const WorkItemRelation = null,
    /// List of removed relations.
    removed: ?[]const WorkItemRelation = null,
    /// List of updated relations.
    updated: ?[]const WorkItemRelation = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a list of work item comments.
pub const CommentList = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// List of comments in the current batch.
    comments: ?[]const Comment = null,
    /// A string token that can be used to retrieving next page of comments if available. Otherwise null.
    continuation_token: ?[]const u8 = null,
    /// The count of comments in the current batch.
    count: ?i32 = null,
    /// Uri to the next page of comments if it is available. Otherwise null.
    next_page: ?[]const u8 = null,
    /// Total count of comments on a work item.
    total_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Comment on a Work Item.
pub const Comment = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    created_by: ?IdentityRef = null,
    /// The creation date of the comment.
    created_date: ?[]const u8 = null,
    /// Effective Date/time value for adding the comment. Can be optionally different from CreatedDate.
    created_on_behalf_date: ?[]const u8 = null,
    created_on_behalf_of: ?IdentityRef = null,
    /// Represents the possible types for the comment format.
    format: ?enums.CommentFormat = null,
    /// The id assigned to the comment.
    id: ?i32 = null,
    /// Indicates if the comment has been deleted.
    is_deleted: ?bool = null,
    /// The mentions of the comment.
    mentions: ?[]const CommentMention = null,
    modified_by: ?IdentityRef = null,
    /// The last modification date of the comment.
    modified_date: ?[]const u8 = null,
    /// The reactions of the comment.
    reactions: ?[]const CommentReaction = null,
    /// The text of the comment in HTML format.
    rendered_text: ?[]const u8 = null,
    /// The text of the comment.
    text: ?[]const u8 = null,
    /// The current version of the comment.
    version: ?i32 = null,
    /// The id of the work item this comment belongs to.
    work_item_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const CommentMention = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The artifact portion of the parsed text. (i.e. the work item's id)
    artifact_id: ?[]const u8 = null,
    /// The type the parser assigned to the mention. (i.e. person, work item, etc)
    artifact_type: ?[]const u8 = null,
    /// The comment id of the mention.
    comment_id: ?i32 = null,
    /// The resolved target of the mention. An example of this could be a user's tfid
    target_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Contains information about work item comment reaction for a particular reaction type.
pub const CommentReaction = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The id of the comment this reaction belongs to.
    comment_id: ?i32 = null,
    /// Total number of reactions for the CommentReactionType.
    count: ?i32 = null,
    /// Flag to indicate if the current user has engaged on this particular EngagementType (e.g. if they liked the associated comment).
    is_current_user_engaged: ?bool = null,
    /// Type of the reaction.
    type: ?enums.CommentReactionType = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents a request to create a work item comment.
pub const CommentCreate = struct {
    /// The text of the comment.
    text: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a request to update a work item comment.
pub const CommentUpdate = struct {
    /// The updated text of the comment.
    text: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `CommentReaction` as returned by Azure DevOps.
pub const CommentReactionList = struct {
    count: ?i32 = null,
    value: ?[]const CommentReaction = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `IdentityRef` as returned by Azure DevOps.
pub const IdentityRefList = struct {
    count: ?i32 = null,
    value: ?[]const IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `CommentVersion` as returned by Azure DevOps.
pub const CommentVersionList = struct {
    count: ?i32 = null,
    value: ?[]const CommentVersion = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a specific version of a comment on a work item.
pub const CommentVersion = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    created_by: ?IdentityRef = null,
    /// The creation date of the comment.
    created_date: ?[]const u8 = null,
    /// Effective Date/time value for adding the comment. Can be optionally different from CreatedDate.
    created_on_behalf_date: ?[]const u8 = null,
    created_on_behalf_of: ?IdentityRef = null,
    /// The id assigned to the comment.
    id: ?i32 = null,
    /// Indicates if the comment has been deleted at this version.
    is_deleted: ?bool = null,
    modified_by: ?IdentityRef = null,
    /// The modification date of the comment for this version.
    modified_date: ?[]const u8 = null,
    /// The rendered content of the comment at this version.
    rendered_text: ?[]const u8 = null,
    /// The text of the comment at this version.
    text: ?[]const u8 = null,
    /// The version number.
    version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A collection of `WorkItemTypeCategory` as returned by Azure DevOps.
pub const WorkItemTypeCategoryList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemTypeCategory = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a work item type category.
pub const WorkItemTypeCategory = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    default_work_item_type: ?WorkItemTypeReference = null,
    /// The name of the category.
    name: ?[]const u8 = null,
    /// The reference name of the category.
    reference_name: ?[]const u8 = null,
    /// The work item types that belong to the category.
    work_item_types: ?[]const WorkItemTypeReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Reference to a work item type.
pub const WorkItemTypeReference = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    /// Name of the work item type.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemType` as returned by Azure DevOps.
pub const WorkItemTypeList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a work item type.
pub const WorkItemType = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The color.
    color: ?[]const u8 = null,
    /// The description of the work item type.
    description: ?[]const u8 = null,
    /// The fields that exist on the work item type.
    field_instances: ?[]const WorkItemTypeFieldInstance = null,
    /// The fields that exist on the work item type.
    fields: ?[]const WorkItemTypeFieldInstance = null,
    icon: ?WorkItemIcon = null,
    /// True if work item type is disabled
    is_disabled: ?bool = null,
    /// Gets the name of the work item type.
    name: ?[]const u8 = null,
    /// The reference name of the work item type.
    reference_name: ?[]const u8 = null,
    /// Gets state information for the work item type.
    states: ?[]const WorkItemStateColor = null,
    /// Gets the various state transition mappings in the work item type.
    transitions: ?std.json.ArrayHashMap([]const WorkItemStateTransition) = null,
    /// The XML form.
    xml_form: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Field instance of a work item type.
pub const WorkItemTypeFieldInstance = struct {
    /// The friendly name of the field.
    name: ?[]const u8 = null,
    /// The reference name of the field.
    reference_name: ?[]const u8 = null,
    /// The REST URL of the resource.
    url: ?[]const u8 = null,
    /// Indicates whether field value is always required.
    always_required: ?bool = null,
    /// The list of dependent fields.
    dependent_fields: ?[]const WorkItemFieldReference = null,
    /// Gets the help text for the field.
    help_text: ?[]const u8 = null,
    /// The list of field allowed values.
    allowed_values: ?[]const []const u8 = null,
    /// Represents the default value of the field.
    default_value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Work item type state name, color and state category
pub const WorkItemStateColor = struct {
    /// Category of state
    category: ?[]const u8 = null,
    /// Color value
    color: ?[]const u8 = null,
    /// Work item type state name
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a state transition in a work item.
pub const WorkItemStateTransition = struct {
    /// Gets a list of actions needed to transition to that state.
    actions: ?[]const []const u8 = null,
    /// Name of the next state.
    to: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemTypeFieldWithReferences` as returned by Azure DevOps.
pub const WorkItemTypeFieldWithReferencesList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemTypeFieldWithReferences = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Field Instance of a workItemype with detailed references.
pub const WorkItemTypeFieldWithReferences = struct {
    /// The friendly name of the field.
    name: ?[]const u8 = null,
    /// The reference name of the field.
    reference_name: ?[]const u8 = null,
    /// The REST URL of the resource.
    url: ?[]const u8 = null,
    /// Indicates whether field value is always required.
    always_required: ?bool = null,
    /// The list of dependent fields.
    dependent_fields: ?[]const WorkItemFieldReference = null,
    /// Gets the help text for the field.
    help_text: ?[]const u8 = null,
    /// The list of field allowed values.
    allowed_values: ?[]const WorkItemTypeFieldWithReferencesAllowedValue = null,
    /// Represents the default value of the field.
    default_value: ?WorkItemTypeFieldWithReferencesDefaultValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemTypeFieldWithReferencesAllowedValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemTypeFieldWithReferencesDefaultValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemStateColor` as returned by Azure DevOps.
pub const WorkItemStateColorList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemStateColor = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemTemplateReference` as returned by Azure DevOps.
pub const WorkItemTemplateReferenceList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemTemplateReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a shallow reference to a work item template.
pub const WorkItemTemplateReference = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The description of the work item template.
    description: ?[]const u8 = null,
    /// The identifier of the work item template.
    id: ?[]const u8 = null,
    /// The name of the work item template.
    name: ?[]const u8 = null,
    /// The name of the work item type.
    work_item_type_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Describes a work item template.
pub const WorkItemTemplate = struct {
    /// REST URL for the resource.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The description of the work item template.
    description: ?[]const u8 = null,
    /// The identifier of the work item template.
    id: ?[]const u8 = null,
    /// The name of the work item template.
    name: ?[]const u8 = null,
    /// The name of the work item type.
    work_item_type_name: ?[]const u8 = null,
    /// Mapping of field and its templated value.
    fields: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A WIQL query
pub const Wiql = struct {
    /// The text of the WIQL query
    query: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The result of a work item query.
pub const WorkItemQueryResult = struct {
    /// The date the query was run in the context of.
    as_of: ?[]const u8 = null,
    /// The columns of the query.
    columns: ?[]const WorkItemFieldReference = null,
    /// The result type
    query_result_type: ?enums.WorkItemQueryResultQueryResultType = null,
    /// The type of the query
    query_type: ?enums.WorkItemQueryResultQueryType = null,
    /// The sort columns of the query.
    sort_columns: ?[]const WorkItemQuerySortColumn = null,
    /// The work item links returned by the query.
    work_item_relations: ?[]const WorkItemLink = null,
    /// The work items returned by the query.
    work_items: ?[]const WorkItemReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A link between two work items.
pub const WorkItemLink = struct {
    /// The type of link.
    rel: ?[]const u8 = null,
    source: ?WorkItemReference = null,
    target: ?WorkItemReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
