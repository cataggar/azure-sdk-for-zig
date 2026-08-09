//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const ResourcePipelinePermissions = struct {
    all_pipelines: ?Permission = null,
    pipelines: ?[]const PipelinePermission = null,
    resource: ?Resource = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Permission = struct {
    authorized: ?bool = null,
    authorized_by: ?IdentityRef = null,
    authorized_on: ?[]const u8 = null,

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

pub const PipelinePermission = struct {
    authorized: ?bool = null,
    authorized_by: ?IdentityRef = null,
    authorized_on: ?[]const u8 = null,
    id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Resource = struct {
    /// Id of the resource.
    id: ?[]const u8 = null,
    /// Name of the resource.
    name: ?[]const u8 = null,
    /// Type of the resource.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CheckConfiguration = struct {
    /// Check configuration id.
    id: ?i32 = null,
    resource: ?Resource = null,
    type: ?CheckType = null,
    /// The URL from which one can fetch the configured check.
    url: ?[]const u8 = null,
    /// Check configuration version.
    version: ?i32 = null,
    links: ?ReferenceLinks = null,
    created_by: ?IdentityRef = null,
    /// Time when check got configured.
    created_on: ?[]const u8 = null,
    /// Is check disabled.
    is_disabled: ?bool = null,
    issue: ?CheckIssue = null,
    modified_by: ?IdentityRef = null,
    /// Time when configured check was modified.
    modified_on: ?[]const u8 = null,
    /// Timeout in minutes for the check.
    timeout: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const CheckType = struct {
    /// Gets or sets check type id.
    id: ?[]const u8 = null,
    /// Name of the check type.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An issue (error, warning) associated with a check configuration.
pub const CheckIssue = struct {
    /// Short summary of the check - its name and resource.
    description: ?[]const u8 = null,
    /// A more detailed description of issue.
    detailed_message: ?[]const u8 = null,
    /// A description of issue.
    message: ?[]const u8 = null,
    /// The type (error, warning) of the issue.
    type: ?enums.CheckIssueType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CheckSuiteRequest = struct {
    context: ?JObject = null,
    id: ?[]const u8 = null,
    resources: ?[]const Resource = null,

    pub const serde = .{
        .rename_all = .camel_case,
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

pub const CheckSuite = struct {
    context: ?JObject = null,
    /// Unique suite id generated by the pipeline orchestrator for the pipeline check runs request on the list of resources Pipeline orchestrator will used this identifier to map the check requests on a stage
    id: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// List of check runs associated with the given check suite request.
    check_runs: ?[]const CheckRun = null,
    /// Completed date of the given check suite request
    completed_date: ?[]const u8 = null,
    /// Optional message for the given check suite request
    message: ?[]const u8 = null,
    /// Overall check runs status for the given suite request. This is check suite status
    status: ?enums.CheckSuiteStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const CheckRun = struct {
    modified_by: ?IdentityRef = null,
    result_message: ?[]const u8 = null,
    status: ?enums.CheckRunStatus = null,
    check_configuration_ref: ?CheckConfigurationRef = null,
    completed_date: ?[]const u8 = null,
    created_date: ?[]const u8 = null,
    evaluation_order: ?enums.CheckRunEvaluationOrder = null,
    id: ?[]const u8 = null,
    /// List of check run result updates.
    result_updates: ?[]const CheckRunUpdate = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CheckConfigurationRef = struct {
    /// Check configuration id.
    id: ?i32 = null,
    resource: ?Resource = null,
    type: ?CheckType = null,
    /// The URL from which one can fetch the configured check.
    url: ?[]const u8 = null,
    /// Check configuration version.
    version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CheckRunUpdate = struct {
    modified_by: ?IdentityRef = null,
    /// Time of check run's result modification.
    modified_on: ?[]const u8 = null,
    /// New check run status introduced by result update.
    status: ?enums.CheckRunUpdateStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CheckSuiteUpdateParameter = struct {
    /// Action that has to be taken for the specified check.
    action: ?enums.CheckSuiteUpdateParameterAction = null,
    /// Check id of the check run to be updated.
    check_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Approval = struct {
    links: ?ReferenceLinks = null,
    /// Identities which are not allowed to approve.
    blocked_approvers: ?[]const IdentityRef = null,
    /// Date on which approval got created.
    created_on: ?[]const u8 = null,
    /// Order in which approvers will be actionable.
    execution_order: ?enums.ApprovalExecutionOrder = null,
    /// Unique identifier of the approval.
    id: ?[]const u8 = null,
    /// Instructions for the approvers.
    instructions: ?[]const u8 = null,
    /// Date on which approval was last modified.
    last_modified_on: ?[]const u8 = null,
    /// Minimum number of approvers that should approve for the entire approval to be considered approved.
    min_required_approvers: ?i32 = null,
    /// Current user permissions for approval object.
    permissions: ?enums.ApprovalPermissions = null,
    pipeline: ?JObject = null,
    /// Overall status of the approval.
    status: ?enums.ApprovalStatus = null,
    /// List of steps associated with the approval.
    steps: ?[]const ApprovalStep = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Data for a single approval step.
pub const ApprovalStep = struct {
    actual_approver: ?IdentityRef = null,
    assigned_approver: ?IdentityRef = null,
    /// Comment associated with this step.
    comment: ?[]const u8 = null,
    /// Date to which approval got deferred.
    deferred_to: ?[]const u8 = null,
    /// History of the approval step
    history: ?[]const ApprovalStepHistory = null,
    /// Timestamp at which this step was initiated.
    initiated_on: ?[]const u8 = null,
    last_modified_by: ?IdentityRef = null,
    /// Timestamp at which this step was last modified.
    last_modified_on: ?[]const u8 = null,
    /// Order in which the approvers are allowed to approve.
    order: ?i32 = null,
    /// Current user permissions for step.
    permissions: ?enums.ApprovalStepPermissions = null,
    /// Current status of this step.
    status: ?enums.ApprovalStepStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data for a single approval step history.
pub const ApprovalStepHistory = struct {
    assigned_to: ?IdentityRef = null,
    /// Comment associated with this step history.
    comment: ?[]const u8 = null,
    created_by: ?IdentityRef = null,
    /// Timestamp at which this step history was created.
    created_on: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data to update an approval object or its individual step.
pub const ApprovalUpdateParameters = struct {
    /// ID of the approval to be updated.
    approval_id: ?[]const u8 = null,
    assigned_approver: ?IdentityRef = null,
    /// Gets or sets comment.
    comment: ?[]const u8 = null,
    /// Date (UTC) to which approval got deferred.
    deferred_to: ?[]const u8 = null,
    reassign_to: ?IdentityRef = null,
    /// Gets or sets status.
    status: ?enums.ApprovalUpdateParametersStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
