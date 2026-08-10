//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `BoardSuggestedValue` as returned by Azure DevOps.
pub const BoardSuggestedValueList = struct {
    count: ?i32 = null,
    value: ?[]const BoardSuggestedValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardSuggestedValue = struct {
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Capacity and teams for all teams in an iteration
pub const IterationCapacity = struct {
    teams: ?[]const TeamCapacityTotals = null,
    total_iteration_capacity_per_day: ?f64 = null,
    total_iteration_days_off: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Team information with total capacity and days off
pub const TeamCapacityTotals = struct {
    team_capacity_per_day: ?f64 = null,
    team_id: ?[]const u8 = null,
    team_total_days_off: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `Plan` as returned by Azure DevOps.
pub const PlanList = struct {
    count: ?i32 = null,
    value: ?[]const Plan = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data contract for the plan definition
pub const Plan = struct {
    created_by_identity: ?IdentityRef = null,
    /// Date when the plan was created
    created_date: ?[]const u8 = null,
    /// Description of the plan
    description: ?[]const u8 = null,
    /// Id of the plan
    id: ?[]const u8 = null,
    /// Date when the plan was last accessed. Default is null.
    last_accessed: ?[]const u8 = null,
    modified_by_identity: ?IdentityRef = null,
    /// Date when the plan was last modified. Default to CreatedDate when the plan is first created.
    modified_date: ?[]const u8 = null,
    /// Name of the plan
    name: ?[]const u8 = null,
    /// The PlanPropertyCollection instance associated with the plan. These are dependent on the type of the plan. For example, DeliveryTimelineView, it would be of type DeliveryViewPropertyCollection.
    properties: ?PlanProperties = null,
    /// Revision of the plan. Used to safeguard users from overwriting each other's changes.
    revision: ?i32 = null,
    /// Type of the plan
    type: ?enums.PlanType = null,
    /// The resource url to locate the plan via rest api
    url: ?[]const u8 = null,
    /// Bit flag indicating set of permissions a user has to the plan.
    user_permissions: ?enums.PlanUserPermissions = null,

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

pub const PlanProperties = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CreatePlan = struct {
    /// Description of the plan
    description: ?[]const u8 = null,
    /// Name of the plan to create.
    name: ?[]const u8 = null,
    /// Plan properties.
    properties: ?CreatePlanProperties = null,
    /// Type of plan to create.
    type: ?enums.CreatePlanType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CreatePlanProperties = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpdatePlan = struct {
    /// Description of the plan
    description: ?[]const u8 = null,
    /// Name of the plan to create.
    name: ?[]const u8 = null,
    /// Plan properties.
    properties: ?UpdatePlanProperties = null,
    /// Revision of the plan that was updated - the value used here should match the one the server gave the client in the Plan.
    revision: ?i32 = null,
    /// Type of the plan
    type: ?enums.UpdatePlanType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpdatePlanProperties = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data contract for Data of Delivery View
pub const DeliveryViewData = struct {
    id: ?[]const u8 = null,
    revision: ?i32 = null,
    /// Work item child id to parent id map
    child_id_to_parent_id_map: ?std.json.ArrayHashMap(i32) = null,
    criteria_status: ?TimelineCriteriaStatus = null,
    /// The end date of the delivery view data
    end_date: ?[]const u8 = null,
    /// Max number of teams that can be configured for a delivery plan
    max_expanded_teams: ?i32 = null,
    /// Mapping between parent id, title and all the child work item ids
    parent_item_maps: ?[]const ParentChildWIMap = null,
    /// The start date for the delivery view data
    start_date: ?[]const u8 = null,
    /// All the team data
    teams: ?[]const TimelineTeamData = null,
    /// List of all work item ids that have a dependency but not a violation
    work_item_dependencies: ?[]const i32 = null,
    /// List of all work item ids that have a violation
    work_item_violations: ?[]const i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineCriteriaStatus = struct {
    message: ?[]const u8 = null,
    type: ?enums.TimelineCriteriaStatusType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ParentChildWIMap = struct {
    child_work_item_ids: ?[]const i32 = null,
    id: ?i32 = null,
    team_project: ?[]const u8 = null,
    title: ?[]const u8 = null,
    work_item_type_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineTeamData = struct {
    backlog: ?BacklogLevel = null,
    /// The field reference names of the work item data
    field_reference_names: ?[]const []const u8 = null,
    /// The id of the team
    id: ?[]const u8 = null,
    /// Was iteration and work item data retrieved for this team. <remarks> Teams with IsExpanded false have not had their iteration, work item, and field related data queried and will never contain this data. If true then these items are queried and, if there are items in the queried range, there will be data. </remarks>
    is_expanded: ?bool = null,
    /// The iteration data, including the work items, in the queried date range.
    iterations: ?[]const TimelineTeamIteration = null,
    /// The name of the team
    name: ?[]const u8 = null,
    /// The order by field name of this team
    order_by_field: ?[]const u8 = null,
    /// The field reference names of the partially paged work items, such as ID, WorkItemType
    partially_paged_field_reference_names: ?[]const []const u8 = null,
    partially_paged_work_items: ?[]const []const TimelineTeamDataPartiallyPagedWorkItem = null,
    /// The project id the team belongs team
    project_id: ?[]const u8 = null,
    /// Work item types for which we will collect roll up data on the client side
    rollup_work_item_types: ?[]const []const u8 = null,
    status: ?TimelineTeamStatus = null,
    /// The team field default value
    team_field_default_value: ?[]const u8 = null,
    /// The team field name of this team
    team_field_name: ?[]const u8 = null,
    /// The team field values
    team_field_values: ?[]const TeamFieldValue = null,
    /// Work items associated with the team that are not under any of the team's iterations
    work_items: ?[]const []const TimelineTeamDataWorkItem = null,
    /// Colors for the work item types.
    work_item_type_colors: ?[]const WorkItemColor = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contract representing a backlog level
pub const BacklogLevel = struct {
    /// Reference name of the corresponding WIT category
    category_reference_name: ?[]const u8 = null,
    /// Plural name for the backlog level
    plural_name: ?[]const u8 = null,
    /// Collection of work item states that are included in the plan. The server will filter to only these work item types.
    work_item_states: ?[]const []const u8 = null,
    /// Collection of valid workitem type names for the given backlog level
    work_item_types: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineTeamIteration = struct {
    /// The iteration CSS Node Id
    css_node_id: ?[]const u8 = null,
    /// The end date of the iteration
    finish_date: ?[]const u8 = null,
    /// The iteration name
    name: ?[]const u8 = null,
    /// All the partially paged workitems in this iteration.
    partially_paged_work_items: ?[]const []const TimelineTeamIterationPartiallyPagedWorkItem = null,
    /// The iteration path
    path: ?[]const u8 = null,
    /// The start date of the iteration
    start_date: ?[]const u8 = null,
    status: ?TimelineIterationStatus = null,
    /// The work items that have been paged in this iteration
    work_items: ?[]const []const TimelineTeamIterationWorkItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineTeamIterationPartiallyPagedWorkItem = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineIterationStatus = struct {
    message: ?[]const u8 = null,
    type: ?enums.TimelineIterationStatusType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineTeamIterationWorkItem = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineTeamDataPartiallyPagedWorkItem = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineTeamStatus = struct {
    message: ?[]const u8 = null,
    type: ?enums.TimelineTeamStatusType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a single TeamFieldValue
pub const TeamFieldValue = struct {
    include_children: ?bool = null,
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineTeamDataWorkItem = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Work item color and icon.
pub const WorkItemColor = struct {
    icon: ?[]const u8 = null,
    primary_color: ?[]const u8 = null,
    work_item_type_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `PredefinedQuery` as returned by Azure DevOps.
pub const PredefinedQueryList = struct {
    count: ?i32 = null,
    value: ?[]const PredefinedQuery = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a single pre-defined query.
pub const PredefinedQuery = struct {
    /// Whether or not the query returned the complete set of data or if the data was truncated.
    has_more: ?bool = null,
    /// Id of the query
    id: ?[]const u8 = null,
    /// Localized name of the query
    name: ?[]const u8 = null,
    /// The results of the query. This will be a set of WorkItem objects with only the 'id' set. The client is responsible for paging in the data as needed.
    results: ?[]const WorkItem = null,
    /// REST API Url to use to retrieve results for this query
    url: ?[]const u8 = null,
    /// Url to use to display a page in the browser with the results of this query
    web_url: ?[]const u8 = null,

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

/// Process Configurations for the project
pub const ProcessConfiguration = struct {
    bug_work_items: ?CategoryConfiguration = null,
    /// Details about portfolio backlogs
    portfolio_backlogs: ?[]const CategoryConfiguration = null,
    requirement_backlog: ?CategoryConfiguration = null,
    task_backlog: ?CategoryConfiguration = null,
    /// Type fields for the process configuration
    type_fields: ?std.json.ArrayHashMap(WorkItemFieldReference) = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Details about a given backlog category
pub const CategoryConfiguration = struct {
    /// Name
    name: ?[]const u8 = null,
    /// Category Reference Name
    reference_name: ?[]const u8 = null,
    /// Work item types for the backlog category
    work_item_types: ?[]const WorkItemTypeReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
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

pub const BacklogConfiguration = struct {
    backlog_fields: ?BacklogFields = null,
    /// Bugs behavior
    bugs_behavior: ?enums.BacklogConfigurationBugsBehavior = null,
    /// Hidden Backlog
    hidden_backlogs: ?[]const []const u8 = null,
    /// Is BugsBehavior Configured in the process
    is_bugs_behavior_configured: ?bool = null,
    /// Portfolio backlog descriptors
    portfolio_backlogs: ?[]const BacklogLevelConfiguration = null,
    requirement_backlog: ?BacklogLevelConfiguration = null,
    task_backlog: ?BacklogLevelConfiguration = null,
    url: ?[]const u8 = null,
    /// Mapped states for work item types
    work_item_type_mapped_states: ?[]const WorkItemTypeStateInfo = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BacklogFields = struct {
    /// Field Type (e.g. Order, Activity) to Field Reference Name map
    type_fields: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BacklogLevelConfiguration = struct {
    /// List of fields to include in Add Panel
    add_panel_fields: ?[]const WorkItemFieldReference = null,
    /// Color for the backlog level
    color: ?[]const u8 = null,
    /// Default list of columns for the backlog
    column_fields: ?[]const BacklogColumn = null,
    default_work_item_type: ?WorkItemTypeReference = null,
    /// Backlog Id (for Legacy Backlog Level from process config it can be categoryref name)
    id: ?[]const u8 = null,
    /// Indicates whether the backlog level is hidden
    is_hidden: ?bool = null,
    /// Backlog Name
    name: ?[]const u8 = null,
    /// Backlog Rank (Taskbacklog is 0)
    rank: ?i32 = null,
    /// The type of this backlog level
    type: ?enums.BacklogLevelConfigurationType = null,
    /// Max number of work items to show in the given backlog
    work_item_count_limit: ?i32 = null,
    /// Work Item types participating in this backlog as known by the project/Process, can be overridden by team settings for bugs
    work_item_types: ?[]const WorkItemTypeReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BacklogColumn = struct {
    column_field_reference: ?WorkItemFieldReference = null,
    width: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemTypeStateInfo = struct {
    /// State name to state category map
    states: ?std.json.ArrayHashMap([]const u8) = null,
    /// Work Item type name
    work_item_type_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `BacklogLevelConfiguration` as returned by Azure DevOps.
pub const BacklogLevelConfigurationList = struct {
    count: ?i32 = null,
    value: ?[]const BacklogLevelConfiguration = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents work items in a backlog level
pub const BacklogLevelWorkItems = struct {
    /// A list of work items within a backlog level
    work_items: ?[]const WorkItemLink = null,

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

/// A collection of `BoardReference` as returned by Azure DevOps.
pub const BoardReferenceList = struct {
    count: ?i32 = null,
    value: ?[]const BoardReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardReference = struct {
    /// Id of the resource
    id: ?[]const u8 = null,
    /// Name of the resource
    name: ?[]const u8 = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Board = struct {
    /// Id of the resource
    id: ?[]const u8 = null,
    /// Name of the resource
    name: ?[]const u8 = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    allowed_mappings: ?std.json.ArrayHashMap(std.json.ArrayHashMap([]const []const u8)) = null,
    can_edit: ?bool = null,
    columns: ?[]const BoardColumn = null,
    fields: ?BoardFields = null,
    is_valid: ?bool = null,
    revision: ?i32 = null,
    rows: ?[]const BoardRow = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const BoardColumn = struct {
    column_type: ?enums.BoardColumnColumnType = null,
    description: ?[]const u8 = null,
    id: ?[]const u8 = null,
    is_split: ?bool = null,
    item_limit: ?i32 = null,
    name: ?[]const u8 = null,
    state_mappings: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardFields = struct {
    column_field: ?FieldReference = null,
    done_field: ?FieldReference = null,
    row_field: ?FieldReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An abstracted reference to a field
pub const FieldReference = struct {
    /// fieldRefName for the field
    reference_name: ?[]const u8 = null,
    /// Full http link to more information about the field
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardRow = struct {
    color: ?[]const u8 = null,
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardUserSettings = struct {
    auto_refresh_state: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardCardRuleSettings = struct {
    links: ?ReferenceLinks = null,
    rules: ?std.json.ArrayHashMap([]const Rule) = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const Rule = struct {
    clauses: ?[]const FilterClause = null,
    filter: ?[]const u8 = null,
    is_enabled: ?[]const u8 = null,
    name: ?[]const u8 = null,
    settings: ?attribute = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FilterClause = struct {
    field_name: ?[]const u8 = null,
    index: ?i32 = null,
    logical_operator: ?[]const u8 = null,
    operator: ?[]const u8 = null,
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const attribute = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardCardSettings = struct {
    cards: ?std.json.ArrayHashMap([]const FieldSetting) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FieldSetting = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `BoardChartReference` as returned by Azure DevOps.
pub const BoardChartReferenceList = struct {
    count: ?i32 = null,
    value: ?[]const BoardChartReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardChartReference = struct {
    /// Name of the resource
    name: ?[]const u8 = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BoardChart = struct {
    /// Name of the resource
    name: ?[]const u8 = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The settings for the resource
    settings: ?std.json.ArrayHashMap(BoardChartSetting) = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const BoardChartSetting = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `BoardColumn` as returned by Azure DevOps.
pub const BoardColumnList = struct {
    count: ?i32 = null,
    value: ?[]const BoardColumn = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `BoardRow` as returned by Azure DevOps.
pub const BoardRowList = struct {
    count: ?i32 = null,
    value: ?[]const BoardRow = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ParentChildWIMap` as returned by Azure DevOps.
pub const ParentChildWIMapList = struct {
    count: ?i32 = null,
    value: ?[]const ParentChildWIMap = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a reorder request for one or more work items.
pub const ReorderOperation = struct {
    /// IDs of the work items to be reordered. Must be valid WorkItem Ids.
    ids: ?[]const i32 = null,
    /// IterationPath for reorder operation. This is only used when we reorder from the Iteration Backlog
    iteration_path: ?[]const u8 = null,
    /// ID of the work item that should be after the reordered items. Can use 0 to specify the end of the list.
    next_id: ?i32 = null,
    /// Parent ID for all of the work items involved in this operation. Can use 0 to indicate the items don't have a parent.
    parent_id: ?i32 = null,
    /// ID of the work item that should be before the reordered items. Can use 0 to specify the beginning of the list.
    previous_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ReorderResult` as returned by Azure DevOps.
pub const ReorderResultList = struct {
    count: ?i32 = null,
    value: ?[]const ReorderResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a reorder result for a work item.
pub const ReorderResult = struct {
    /// The ID of the work item that was reordered.
    id: ?i32 = null,
    /// The updated order value of the work item that was reordered.
    order: ?f64 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskboardColumns = struct {
    columns: ?[]const TaskboardColumn = null,
    /// Are the columns cutomized for this team
    is_customized: ?bool = null,
    /// Specifies if the referenced WIT and State is valid
    is_valid: ?bool = null,
    /// Details of validation failure if the state to column mapping is invalid
    validation_messsage: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the taskbord column
pub const TaskboardColumn = struct {
    /// Column ID
    id: ?[]const u8 = null,
    /// Work item type states mapped to this column to support auto state update when column is updated.
    mappings: ?[]const ITaskboardColumnMapping = null,
    /// Column name
    name: ?[]const u8 = null,
    /// Column position relative to other columns in the same board
    order: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ITaskboardColumnMapping = struct {
    state: ?[]const u8 = null,
    work_item_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpdateTaskboardColumn = struct {
    /// Column ID, keep it null for new column
    id: ?[]const u8 = null,
    /// Work item type states mapped to this column to support auto state update when column is updated.
    mappings: ?[]const TaskboardColumnMapping = null,
    /// Column name is required
    name: ?[]const u8 = null,
    /// Column position relative to other columns in the same board
    order: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the state to column mapping per work item type This allows auto state update when the column changes
pub const TaskboardColumnMapping = struct {
    /// State of the work item type mapped to the column
    state: ?[]const u8 = null,
    /// Work Item Type name who's state is mapped to the column
    work_item_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TaskboardWorkItemColumn` as returned by Azure DevOps.
pub const TaskboardWorkItemColumnList = struct {
    count: ?i32 = null,
    value: ?[]const TaskboardWorkItemColumn = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Column value of a work item in the taskboard
pub const TaskboardWorkItemColumn = struct {
    /// Work item column value in the taskboard
    column: ?[]const u8 = null,
    /// Work item column id in the taskboard
    column_id: ?[]const u8 = null,
    /// Work Item state value
    state: ?[]const u8 = null,
    /// Work item id
    work_item_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpdateTaskboardWorkItemColumn = struct {
    new_column: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data contract for TeamSettings
pub const TeamSetting = struct {
    links: ?ReferenceLinks = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    backlog_iteration: ?TeamSettingsIteration = null,
    /// Information about categories that are visible on the backlog.
    backlog_visibilities: ?std.json.ArrayHashMap(bool) = null,
    /// BugsBehavior (Off, AsTasks, AsRequirements, ...)
    bugs_behavior: ?enums.TeamSettingBugsBehavior = null,
    default_iteration: ?TeamSettingsIteration = null,
    /// Default Iteration macro (if any)
    default_iteration_macro: ?[]const u8 = null,
    /// Days that the team is working
    working_days: ?[]const enums.TeamSettingWorkingDay = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents a shallow ref for a single iteration.
pub const TeamSettingsIteration = struct {
    links: ?ReferenceLinks = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    attributes: ?TeamIterationAttributes = null,
    /// Id of the iteration.
    id: ?[]const u8 = null,
    /// Name of the iteration.
    name: ?[]const u8 = null,
    /// Relative path of the iteration.
    path: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const TeamIterationAttributes = struct {
    /// Finish date of the iteration. Date-only, correct unadjusted at midnight in UTC.
    finish_date: ?[]const u8 = null,
    /// Start date of the iteration. Date-only, correct unadjusted at midnight in UTC.
    start_date: ?[]const u8 = null,
    /// Time frame of the iteration, such as past, current or future.
    time_frame: ?enums.TeamIterationAttributesTimeFrame = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data contract for what we expect to receive when PATCH
pub const TeamSettingsPatch = struct {
    backlog_iteration: ?[]const u8 = null,
    backlog_visibilities: ?std.json.ArrayHashMap(bool) = null,
    bugs_behavior: ?enums.TeamSettingsPatchBugsBehavior = null,
    default_iteration: ?[]const u8 = null,
    default_iteration_macro: ?[]const u8 = null,
    working_days: ?[]const enums.TeamSettingsPatchWorkingDay = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TeamSettingsIteration` as returned by Azure DevOps.
pub const TeamSettingsIterationList = struct {
    count: ?i32 = null,
    value: ?[]const TeamSettingsIteration = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents work items in an iteration backlog
pub const IterationWorkItems = struct {
    links: ?ReferenceLinks = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    /// Work item relations
    work_item_relations: ?[]const WorkItemLink = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents team member capacity with totals aggregated
pub const TeamCapacity = struct {
    team_members: ?[]const TeamMemberCapacityIdentityRef = null,
    total_capacity_per_day: ?f64 = null,
    total_days_off: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents capacity for a specific team member
pub const TeamMemberCapacityIdentityRef = struct {
    links: ?ReferenceLinks = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    /// Collection of capacities associated with the team member
    activities: ?[]const Activity = null,
    /// The days off associated with the team member
    days_off: ?[]const DateRange = null,
    team_member: ?IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const Activity = struct {
    capacity_per_day: ?f32 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const DateRange = struct {
    /// End of the date range.
    end: ?[]const u8 = null,
    /// Start of the date range.
    start: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TeamMemberCapacityIdentityRef` as returned by Azure DevOps.
pub const TeamMemberCapacityIdentityRefList = struct {
    count: ?i32 = null,
    value: ?[]const TeamMemberCapacityIdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Expected data from PATCH
pub const CapacityPatch = struct {
    activities: ?[]const Activity = null,
    days_off: ?[]const DateRange = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TeamSettingsDaysOff = struct {
    links: ?ReferenceLinks = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    days_off: ?[]const DateRange = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const TeamSettingsDaysOffPatch = struct {
    days_off: ?[]const DateRange = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Essentially a collection of team field values
pub const TeamFieldValues = struct {
    links: ?ReferenceLinks = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    /// The default team field value
    default_value: ?[]const u8 = null,
    field: ?FieldReference = null,
    /// Collection of all valid team field values
    values: ?[]const TeamFieldValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Expected data from PATCH
pub const TeamFieldValuesPatch = struct {
    default_value: ?[]const u8 = null,
    values: ?[]const TeamFieldValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
