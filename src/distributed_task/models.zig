//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Data and settings for an elastic pool
pub const ElasticPool = struct {
    /// Set whether agents should be configured to run with interactive UI
    agent_interactive_ui: ?bool = null,
    /// Azure string representing to location of the resource
    azure_id: ?[]const u8 = null,
    /// Number of agents to have ready waiting for jobs
    desired_idle: ?i32 = null,
    /// The desired size of the pool
    desired_size: ?i32 = null,
    /// Maximum number of nodes that will exist in the elastic pool
    max_capacity: ?i32 = null,
    /// Keep nodes in the pool on failure for investigation
    max_saved_node_count: ?i32 = null,
    /// Timestamp the pool was first detected to be offline
    offline_since: ?[]const u8 = null,
    /// Operating system type of the nodes in the pool
    orchestration_type: ?enums.ElasticPoolOrchestrationType = null,
    /// Operating system type of the nodes in the pool
    os_type: ?enums.ElasticPoolOsType = null,
    /// Id of the associated TaskAgentPool
    pool_id: ?i32 = null,
    /// Discard node after each job completes
    recycle_after_each_use: ?bool = null,
    /// Id of the Service Endpoint used to connect to Azure
    service_endpoint_id: ?[]const u8 = null,
    /// Scope the Service Endpoint belongs to
    service_endpoint_scope: ?[]const u8 = null,
    /// The number of sizing attempts executed while trying to achieve a desired size
    sizing_attempts: ?i32 = null,
    /// State of the pool
    state: ?enums.ElasticPoolState = null,
    /// The minimum time in minutes to keep idle agents alive
    time_to_live_minutes: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .agent_interactive_ui = "agentInteractiveUI",
        },
    };
};

/// Returned result from creating a new elastic pool
pub const ElasticPoolCreationResult = struct {
    agent_pool: ?TaskAgentPool = null,
    agent_queue: ?TaskAgentQueue = null,
    elastic_pool: ?ElasticPool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An organization-level grouping of agents.
pub const TaskAgentPool = struct {
    id: ?i32 = null,
    /// Gets or sets a value indicating whether or not this pool is managed by the service.
    is_hosted: ?bool = null,
    /// Determines whether the pool is legacy.
    is_legacy: ?bool = null,
    name: ?[]const u8 = null,
    /// Additional pool settings and details
    options: ?enums.TaskAgentPoolOptions = null,
    /// Gets or sets the type of the pool
    pool_type: ?enums.TaskAgentPoolPoolType = null,
    scope: ?[]const u8 = null,
    /// Gets the current size of the pool.
    size: ?i32 = null,
    /// The ID of the associated agent cloud.
    agent_cloud_id: ?i32 = null,
    /// Whether or not a queue should be automatically provisioned for each project collection.
    auto_provision: ?bool = null,
    /// Whether or not the pool should autosize itself based on the Agent Cloud Provider settings.
    auto_size: ?bool = null,
    /// Whether or not agents in this pool are allowed to automatically update
    auto_update: ?bool = null,
    created_by: ?IdentityRef = null,
    /// The date/time of the pool creation.
    created_on: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    properties: ?PropertiesCollection = null,
    /// Target parallelism - Only applies to agent pools that are backed by pool providers. It will be null for regular pools.
    target_size: ?i32 = null,

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

/// The class represents a property bag as a collection of key-value pairs. Values of all primitive types (any type with a `TypeCode != TypeCode.Object`) except for `DBNull` are accepted. Values of type Byte[], Int32, Double, DateType and String preserve their type, other primitives are retuned as a String. Byte[] expected as base64 encoded string.
pub const PropertiesCollection = struct {
    /// The count of properties in the collection.
    count: ?i32 = null,
    item: ?PropertiesCollectionItem = null,
    /// The set of keys in the collection.
    keys: ?[]const []const u8 = null,
    /// The set of values in the collection.
    values: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PropertiesCollectionItem = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An agent queue.
pub const TaskAgentQueue = struct {
    /// ID of the queue
    id: ?i32 = null,
    /// Name of the queue
    name: ?[]const u8 = null,
    pool: ?TaskAgentPoolReference = null,
    /// Project ID
    project_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskAgentPoolReference = struct {
    id: ?i32 = null,
    /// Gets or sets a value indicating whether or not this pool is managed by the service.
    is_hosted: ?bool = null,
    /// Determines whether the pool is legacy.
    is_legacy: ?bool = null,
    name: ?[]const u8 = null,
    /// Additional pool settings and details
    options: ?enums.TaskAgentPoolOptions = null,
    /// Gets or sets the type of the pool
    pool_type: ?enums.TaskAgentPoolPoolType = null,
    scope: ?[]const u8 = null,
    /// Gets the current size of the pool.
    size: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class used for updating an elastic pool where only certain members are populated
pub const ElasticPoolSettings = struct {
    /// Set whether agents should be configured to run with interactive UI
    agent_interactive_ui: ?bool = null,
    /// Azure string representing to location of the resource
    azure_id: ?[]const u8 = null,
    /// Number of machines to have ready waiting for jobs
    desired_idle: ?i32 = null,
    /// Maximum number of machines that will exist in the elastic pool
    max_capacity: ?i32 = null,
    /// Keep machines in the pool on failure for investigation
    max_saved_node_count: ?i32 = null,
    /// Operating system type of the machines in the pool
    orchestration_type: ?enums.ElasticPoolSettingsOrchestrationType = null,
    /// Operating system type of the machines in the pool
    os_type: ?enums.ElasticPoolSettingsOsType = null,
    /// Discard machines after each job completes
    recycle_after_each_use: ?bool = null,
    /// Id of the Service Endpoint used to connect to Azure
    service_endpoint_id: ?[]const u8 = null,
    /// Scope the Service Endpoint belongs to
    service_endpoint_scope: ?[]const u8 = null,
    /// The minimum time in minutes to keep idle agents alive
    time_to_live_minutes: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .agent_interactive_ui = "agentInteractiveUI",
        },
    };
};

/// Log data for an Elastic Pool
pub const ElasticPoolLog = struct {
    /// Log Id
    id: ?i64 = null,
    /// E.g. error, warning, info
    level: ?enums.ElasticPoolLogLevel = null,
    /// Log contents
    message: ?[]const u8 = null,
    /// Operation that triggered the message being logged
    operation: ?enums.ElasticPoolLogOperation = null,
    /// Id of the associated TaskAgentPool
    pool_id: ?i32 = null,
    /// Datetime that the log occurred
    timestamp: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data and settings for an elastic node
pub const ElasticNode = struct {
    /// Distributed Task's Agent Id
    agent_id: ?i32 = null,
    /// Summary of the state of the agent
    agent_state: ?enums.ElasticNodeAgentState = null,
    /// Compute Id. VMSS's InstanceId
    compute_id: ?[]const u8 = null,
    /// State of the compute host
    compute_state: ?enums.ElasticNodeComputeState = null,
    /// Users can force state changes to specific states (ToReimage, ToDelete, Save)
    desired_state: ?enums.ElasticNodeDesiredState = null,
    /// Unique identifier since the agent and/or VM may be null
    id: ?i32 = null,
    /// Computer name. Used to match a scaleset VM with an agent
    name: ?[]const u8 = null,
    /// Pool Id that this node belongs to
    pool_id: ?i32 = null,
    /// Last job RequestId assigned to this agent
    request_id: ?i64 = null,
    /// State of the ElasticNode
    state: ?enums.ElasticNodeState = null,
    /// Last state change. Only updated by SQL.
    state_changed_on: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class used for updating an elastic node where only certain members are populated
pub const ElasticNodeSettings = struct {
    /// State of the ElasticNode
    state: ?enums.ElasticNodeSettingsState = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A pipeline job event to be processed by the execution plan.
pub const JobEvent = struct {
    /// The ID of the pipeline job affected by the event.
    job_id: ?[]const u8 = null,
    /// The name of the pipeline job event.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskHubOidcToken = struct {
    oidc_token: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A task log connected to a timeline record.
pub const TaskLog = struct {
    /// The ID of the task log.
    id: ?i32 = null,
    /// The REST URL of the task log.
    location: ?[]const u8 = null,
    /// The time of the task log creation.
    created_on: ?[]const u8 = null,
    /// The REST URL of the task log when indexed.
    index_location: ?[]const u8 = null,
    /// The time of the last modification of the task log.
    last_changed_on: ?[]const u8 = null,
    /// The number of the task log lines.
    line_count: ?i64 = null,
    /// The path of the task log.
    path: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// This class is used to serialize collections as a single JSON object on the wire.
pub const VssJsonCollectionWrapper = struct {
    /// The number of serialized items.
    count: ?i32 = null,
    /// The serialized item.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Detailed information about the execution of different operations during pipeline run.
pub const TimelineRecord = struct {
    agent_specification: ?JObject = null,
    /// The number of record attempts.
    attempt: ?i32 = null,
    /// The ID connecting all records updated at the same time. This value is taken from timeline's ChangeId.
    change_id: ?i32 = null,
    /// A string that indicates the current operation.
    current_operation: ?[]const u8 = null,
    details: ?TimelineReference = null,
    /// The number of errors produced by this operation.
    error_count: ?i32 = null,
    /// The finish time of the record.
    finish_time: ?[]const u8 = null,
    /// The ID of the record.
    id: ?[]const u8 = null,
    /// String identifier that is consistent across attempts.
    identifier: ?[]const u8 = null,
    /// The list of issues produced by this operation.
    issues: ?[]const Issue = null,
    /// The time the record was last modified.
    last_modified: ?[]const u8 = null,
    /// The REST URL of the record.
    location: ?[]const u8 = null,
    log: ?TaskLogReference = null,
    /// The name of the record.
    name: ?[]const u8 = null,
    /// An ordinal value relative to other records within the timeline.
    order: ?i32 = null,
    /// The ID of the record's parent. <br />Example: Stage is a parent of a Phase, Phase is a parent of a Job, Job is a parent of a Task.
    parent_id: ?[]const u8 = null,
    /// The percentage of record completion.
    percent_complete: ?i32 = null,
    /// The previous record attempts.
    previous_attempts: ?[]const TimelineAttempt = null,
    /// The ID of the queue which connects projects to agent pools on which the operation ran on. Applicable when record is of type Job.
    queue_id: ?i32 = null,
    /// Name of the referenced record.
    ref_name: ?[]const u8 = null,
    /// The result of the record.
    result: ?enums.TimelineRecordResult = null,
    /// Evaluation of predefined conditions upon completion of record's operation. <br />Example: Evaluating `succeeded()`, Result = True <br />Example: Evaluating `and(succeeded(), eq(variables['system.debug'], False))`, Result = False
    result_code: ?[]const u8 = null,
    /// The start time of the record.
    start_time: ?[]const u8 = null,
    /// The state of the record.
    state: ?enums.TimelineRecordState = null,
    task: ?TaskReference = null,
    /// The type of operation being tracked by the record. <br />Example: Stage, Phase, Job, Task...
    type: ?[]const u8 = null,
    /// The variables of the record.
    variables: ?std.json.ArrayHashMap(VariableValue) = null,
    /// The number of warnings produced by this operation.
    warning_count: ?i32 = null,
    /// The name of the agent running the operation. Applicable when record is of type Job.
    worker_name: ?[]const u8 = null,

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

/// A reference to a timeline.
pub const TimelineReference = struct {
    /// The change ID.
    change_id: ?i32 = null,
    /// The ID of the timeline.
    id: ?[]const u8 = null,
    /// The REST URL of the timeline.
    location: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An issue (error, warning) associated with a pipeline run.
pub const Issue = struct {
    /// The category of the issue. <br />Example: Code - refers to compilation errors <br />Example: General - refers to generic errors
    category: ?[]const u8 = null,
    /// A dictionary containing details about the issue.
    data: ?std.json.ArrayHashMap([]const u8) = null,
    /// A description of issue.
    message: ?[]const u8 = null,
    /// The type (error, warning) of the issue.
    type: ?enums.IssueType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A reference to a task log. This class contains information about the output printed to the timeline record's logs console during pipeline run.
pub const TaskLogReference = struct {
    /// The ID of the task log.
    id: ?i32 = null,
    /// The REST URL of the task log.
    location: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An attempt to update a TimelineRecord.
pub const TimelineAttempt = struct {
    /// The attempt of the record.
    attempt: ?i32 = null,
    /// The unique identifier for the record.
    identifier: ?[]const u8 = null,
    /// The record identifier located within the specified timeline.
    record_id: ?[]const u8 = null,
    /// The timeline identifier which owns the record representing this attempt.
    timeline_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A reference to a task.
pub const TaskReference = struct {
    /// The build config of the task definition. Corresponds to the version value of task.json file. <br />Example: CmdLineV2 { '_buildConfigMapping': { 'Default': '2.232.2', 'Node20_229_7': '2.232.3' } }
    build_config: ?[]const u8 = null,
    contribution_identifier: ?[]const u8 = null,
    contribution_version: ?[]const u8 = null,
    /// The ID of the task definition. Corresponds to the id value of task.json file. <br />Example: CmdLineV2 { 'id': 'D9BAFED4-0B18-4F58-968D-86655B4D2CE9' }
    id: ?[]const u8 = null,
    /// A dictionary of inputs specific to a task definition. Corresponds to inputs value of task.json file.
    inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// The name of the task definition. Corresponds to the name value of task.json file. <br />Example: CmdLineV2 { 'name': 'CmdLine' }
    name: ?[]const u8 = null,
    /// The version of the task definition. Corresponds to the version value of task.json file. <br />Example: CmdLineV2 { 'version': { 'Major': 2, 'Minor': 212, 'Patch': 0 } }
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A wrapper class for a generic variable.
pub const VariableValue = struct {
    /// Indicates whether the variable can be changed during script's execution runtime.
    is_read_only: ?bool = null,
    /// Indicates whether the variable should be encrypted at rest.
    is_secret: ?bool = null,
    /// The value of the variable.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskAgentCloud = struct {
    /// Gets or sets a AcquireAgentEndpoint using which a request can be made to acquire new agent
    acquire_agent_endpoint: ?[]const u8 = null,
    acquisition_timeout: ?i32 = null,
    agent_cloud_id: ?i32 = null,
    get_account_parallelism_endpoint: ?[]const u8 = null,
    get_agent_definition_endpoint: ?[]const u8 = null,
    get_agent_request_status_endpoint: ?[]const u8 = null,
    id: ?[]const u8 = null,
    /// Signifies that this Agent Cloud is internal and should not be user-manageable
    internal: ?bool = null,
    max_parallelism: ?i32 = null,
    name: ?[]const u8 = null,
    release_agent_endpoint: ?[]const u8 = null,
    shared_secret: ?[]const u8 = null,
    /// Gets or sets the type of the endpoint.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskAgentCloudRequest = struct {
    agent: ?TaskAgentReference = null,
    agent_cloud_id: ?i32 = null,
    agent_connected_time: ?[]const u8 = null,
    agent_data: ?JObject = null,
    agent_specification: ?JObject = null,
    pool: ?TaskAgentPoolReference = null,
    pool_providers_tags: ?std.json.ArrayHashMap([]const u8) = null,
    provisioned_time: ?[]const u8 = null,
    provision_request_time: ?[]const u8 = null,
    release_request_time: ?[]const u8 = null,
    request_id: ?[]const u8 = null,
    request_version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A reference to an agent.
pub const TaskAgentReference = struct {
    links: ?ReferenceLinks = null,
    /// This agent's access point.
    access_point: ?[]const u8 = null,
    /// Whether or not this agent should run jobs.
    enabled: ?bool = null,
    /// Identifier of the agent.
    id: ?i32 = null,
    /// Name of the agent.
    name: ?[]const u8 = null,
    /// Agent OS.
    os_description: ?[]const u8 = null,
    /// Provisioning state of this agent.
    provisioning_state: ?[]const u8 = null,
    /// Whether or not the agent is online.
    status: ?enums.TaskAgentReferenceStatus = null,
    /// Agent version.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents an abstract JSON token.
pub const JToken = struct {
    first: ?JToken = null,
    /// Gets a value indicating whether this token has child tokens.
    has_values: ?bool = null,
    item: ?JToken = null,
    last: ?JToken = null,
    next: ?JToken = null,
    /// Gets or sets the parent.
    parent: ?[]const u8 = null,
    /// Gets the path of the JSON token.
    path: ?[]const u8 = null,
    previous: ?JToken = null,
    root: ?JToken = null,
    /// Gets the node type for this JToken.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskAgentCloudType = struct {
    /// Gets or sets the display name of agent cloud type.
    display_name: ?[]const u8 = null,
    /// Gets or sets the input descriptors
    input_descriptors: ?[]const InputDescriptor = null,
    /// Gets or sets the name of agent cloud type.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes an input for subscriptions.
pub const InputDescriptor = struct {
    /// The ids of all inputs that the value of this input is dependent on.
    dependency_input_ids: ?[]const []const u8 = null,
    /// Description of what this input is used for
    description: ?[]const u8 = null,
    /// The group localized name to which this input belongs and can be shown as a header for the container that will include all the inputs in the group.
    group_name: ?[]const u8 = null,
    /// If true, the value information for this input is dynamic and should be fetched when the value of dependency inputs change.
    has_dynamic_value_information: ?bool = null,
    /// Identifier for the subscription input
    id: ?[]const u8 = null,
    /// Mode in which the value of this input should be entered
    input_mode: ?enums.InputDescriptorInputMode = null,
    /// Gets whether this input is confidential, such as for a password or application key
    is_confidential: ?bool = null,
    /// Localized name which can be shown as a label for the subscription input
    name: ?[]const u8 = null,
    /// Custom properties for the input which can be used by the service provider
    properties: ?std.json.ArrayHashMap(InputDescriptorProperty) = null,
    /// Underlying data type for the input value. When this value is specified, InputMode, Validation and Values are optional.
    type: ?[]const u8 = null,
    /// Gets whether this input is included in the default generated action description.
    use_in_default_description: ?bool = null,
    validation: ?InputValidation = null,
    /// A hint for input value. It can be used in the UI as the input placeholder.
    value_hint: ?[]const u8 = null,
    values: ?InputValues = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const InputDescriptorProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes what values are valid for a subscription input
pub const InputValidation = struct {
    /// Gets or sets the data type to validate.
    data_type: ?enums.InputValidationDataType = null,
    /// Gets or sets if this is a required field.
    is_required: ?bool = null,
    /// Gets or sets the maximum length of this descriptor.
    max_length: ?i32 = null,
    /// Gets or sets the minimum value for this descriptor.
    max_value: ?[]const u8 = null,
    /// Gets or sets the minimum length of this descriptor.
    min_length: ?i32 = null,
    /// Gets or sets the minimum value for this descriptor.
    min_value: ?[]const u8 = null,
    /// Gets or sets the pattern to validate.
    pattern: ?[]const u8 = null,
    /// Gets or sets the error on pattern mismatch.
    pattern_mismatch_error_message: ?[]const u8 = null,
    /// Gets or sets the warning on pattern mismatch.
    pattern_mismatch_warning_message: ?[]const u8 = null,
    /// Gets or sets the pattern to validate.
    warning_pattern: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information about the possible/allowed values for a given subscription input
pub const InputValues = struct {
    /// The default value to use for this input
    default_value: ?[]const u8 = null,
    @"error": ?InputValuesError = null,
    /// The id of the input
    input_id: ?[]const u8 = null,
    /// Should this input be disabled
    is_disabled: ?bool = null,
    /// Should the value be restricted to one of the values in the PossibleValues (True) or are the values in PossibleValues just a suggestion (False)
    is_limited_to_possible_values: ?bool = null,
    /// Should this input be made read-only
    is_read_only: ?bool = null,
    /// Possible values that this input can take
    possible_values: ?[]const InputValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Error information related to a subscription input value.
pub const InputValuesError = struct {
    /// The error message.
    message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information about a single value for an input
pub const InputValue = struct {
    /// Any other data about this input
    data: ?std.json.ArrayHashMap(InputValueDatum) = null,
    /// The text to show for the display of this value
    display_value: ?[]const u8 = null,
    /// The value to store for this input
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const InputValueDatum = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A task agent.
pub const TaskAgent = struct {
    links: ?ReferenceLinks = null,
    /// This agent's access point.
    access_point: ?[]const u8 = null,
    /// Whether or not this agent should run jobs.
    enabled: ?bool = null,
    /// Identifier of the agent.
    id: ?i32 = null,
    /// Name of the agent.
    name: ?[]const u8 = null,
    /// Agent OS.
    os_description: ?[]const u8 = null,
    /// Provisioning state of this agent.
    provisioning_state: ?[]const u8 = null,
    /// Whether or not the agent is online.
    status: ?enums.TaskAgentReferenceStatus = null,
    /// Agent version.
    version: ?[]const u8 = null,
    assigned_agent_cloud_request: ?TaskAgentCloudRequest = null,
    assigned_request: ?TaskAgentJobRequest = null,
    authorization: ?TaskAgentAuthorization = null,
    /// Date on which this agent was created.
    created_on: ?[]const u8 = null,
    last_completed_request: ?TaskAgentJobRequest = null,
    /// Maximum job parallelism allowed for this agent.
    max_parallelism: ?i32 = null,
    pending_update: ?TaskAgentUpdate = null,
    properties: ?PropertiesCollection = null,
    /// Date on which the last connectivity status change occurred.
    status_changed_on: ?[]const u8 = null,
    /// System-defined capabilities supported by this agent's host. Warning: To set capabilities use the PUT method, PUT will completely overwrite existing capabilities.
    system_capabilities: ?std.json.ArrayHashMap([]const u8) = null,
    /// User-defined capabilities supported by this agent's host. Warning: To set capabilities use the PUT method, PUT will completely overwrite existing capabilities.
    user_capabilities: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A job request for an agent.
pub const TaskAgentJobRequest = struct {
    /// The date/time this request was assigned.
    assign_time: ?[]const u8 = null,
    /// The date/time this request was finished.
    finish_time: ?[]const u8 = null,
    orchestration_id: ?[]const u8 = null,
    /// The date/time this request was queued.
    queue_time: ?[]const u8 = null,
    /// The date/time this request was receieved by an agent.
    receive_time: ?[]const u8 = null,
    /// ID of the request.
    request_id: ?i64 = null,
    agent_specification: ?JObject = null,
    /// Additional data about the request.
    data: ?std.json.ArrayHashMap([]const u8) = null,
    definition: ?TaskOrchestrationOwner = null,
    /// A list of demands required to fulfill this request.
    demands: ?[]const Demand = null,
    /// The host which triggered this request.
    host_id: ?[]const u8 = null,
    /// ID of the job resulting from this request.
    job_id: ?[]const u8 = null,
    /// Name of the job resulting from this request.
    job_name: ?[]const u8 = null,
    /// The deadline for the agent to renew the lock.
    locked_until: ?[]const u8 = null,
    matched_agents: ?[]const TaskAgentReference = null,
    matches_all_agents_in_pool: ?bool = null,
    owner: ?TaskOrchestrationOwner = null,
    plan_group: ?[]const u8 = null,
    /// Internal ID for the orchestration plan connected with this request.
    plan_id: ?[]const u8 = null,
    /// Internal detail representing the type of orchestration plan.
    plan_type: ?[]const u8 = null,
    /// The ID of the pool this request targets
    pool_id: ?i32 = null,
    priority: ?i32 = null,
    /// The ID of the queue this request targets
    queue_id: ?i32 = null,
    reserved_agent: ?TaskAgentReference = null,
    /// The result of this request.
    result: ?enums.TaskAgentJobRequestResult = null,
    /// Scope of the pipeline; matches the project ID.
    scope_id: ?[]const u8 = null,
    /// The service which owns this request.
    service_owner: ?[]const u8 = null,
    status_message: ?[]const u8 = null,
    user_delayed: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskOrchestrationOwner = struct {
    links: ?ReferenceLinks = null,
    id: ?i32 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const Demand = struct {
    name: ?[]const u8 = null,
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Provides data necessary for authorizing the agent using OAuth 2.0 authentication flows.
pub const TaskAgentAuthorization = struct {
    /// Endpoint used to obtain access tokens from the configured token service.
    authorization_url: ?[]const u8 = null,
    /// Client identifier for this agent.
    client_id: ?[]const u8 = null,
    public_key: ?TaskAgentPublicKey = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the public key portion of an RSA asymmetric key.
pub const TaskAgentPublicKey = struct {
    /// Gets or sets the exponent for the public key.
    exponent: ?[]const []const u8 = null,
    /// Gets or sets the modulus for the public key.
    modulus: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Details about an agent update.
pub const TaskAgentUpdate = struct {
    /// Current state of this agent update.
    current_state: ?[]const u8 = null,
    reason: ?TaskAgentUpdateReason = null,
    requested_by: ?IdentityRef = null,
    /// Date on which this update was requested.
    request_time: ?[]const u8 = null,
    source_version: ?PackageVersion = null,
    target_version: ?PackageVersion = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskAgentUpdateReason = struct {
    code: ?enums.TaskAgentUpdateReasonCode = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PackageVersion = struct {
    major: ?i32 = null,
    minor: ?i32 = null,
    patch: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A variable group reference is a shallow reference to variable group.
pub const VariableGroupProjectReference = struct {
    /// Gets or sets description of the variable group.
    description: ?[]const u8 = null,
    /// Gets or sets name of the variable group.
    name: ?[]const u8 = null,
    project_reference: ?ProjectReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProjectReference = struct {
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const VariableGroupParameters = struct {
    /// Sets description of the variable group.
    description: ?[]const u8 = null,
    /// Sets name of the variable group.
    name: ?[]const u8 = null,
    provider_data: ?VariableGroupProviderData = null,
    /// Sets type of the variable group.
    type: ?[]const u8 = null,
    variable_group_project_references: ?[]const VariableGroupProjectReference = null,
    /// Sets variables contained in the variable group.
    variables: ?std.json.ArrayHashMap(VariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines provider data of the variable group.
pub const VariableGroupProviderData = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A variable group is a collection of related variables.
pub const VariableGroup = struct {
    created_by: ?IdentityRef = null,
    /// Gets or sets the time when variable group was created.
    created_on: ?[]const u8 = null,
    /// Gets or sets description of the variable group.
    description: ?[]const u8 = null,
    /// Gets or sets id of the variable group.
    id: ?i32 = null,
    /// Indicates whether variable group is shared with other projects or not.
    is_shared: ?bool = null,
    modified_by: ?IdentityRef = null,
    /// Gets or sets the time when variable group was modified
    modified_on: ?[]const u8 = null,
    /// Gets or sets name of the variable group.
    name: ?[]const u8 = null,
    provider_data: ?VariableGroupProviderData = null,
    /// Gets or sets type of the variable group.
    type: ?[]const u8 = null,
    /// all project references where the variable group is shared with other projects.
    variable_group_project_references: ?[]const VariableGroupProjectReference = null,
    /// Gets or sets variables contained in the variable group.
    variables: ?std.json.ArrayHashMap(VariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GetResponse = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deployment group.
pub const DeploymentGroup = struct {
    /// Deployment group identifier.
    id: ?i32 = null,
    /// Name of the deployment group.
    name: ?[]const u8 = null,
    pool: ?TaskAgentPoolReference = null,
    project: ?ProjectReference = null,
    /// Description of the deployment group.
    description: ?[]const u8 = null,
    /// Number of deployment targets in the deployment group.
    machine_count: ?i32 = null,
    /// List of deployment targets in the deployment group.
    machines: ?[]const DeploymentMachine = null,
    /// List of unique tags across all deployment targets in the deployment group.
    machine_tags: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deployment target.
pub const DeploymentMachine = struct {
    agent: ?TaskAgent = null,
    /// Deployment target Identifier.
    id: ?i32 = null,
    properties: ?PropertiesCollection = null,
    /// Tags of the deployment target.
    tags: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Properties to create Deployment group.
pub const DeploymentGroupCreateParameter = struct {
    /// Description of the deployment group.
    description: ?[]const u8 = null,
    /// Name of the deployment group.
    name: ?[]const u8 = null,
    /// Identifier of the deployment pool in which deployment agents are registered.
    pool_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deployment group update parameter.
pub const DeploymentGroupUpdateParameter = struct {
    /// Description of the deployment group.
    description: ?[]const u8 = null,
    /// Name of the deployment group.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deployment target update parameter.
pub const DeploymentTargetUpdateParameter = struct {
    /// Identifier of the deployment target.
    id: ?i32 = null,
    tags: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SecureFile = struct {
    created_by: ?IdentityRef = null,
    created_on: ?[]const u8 = null,
    id: ?[]const u8 = null,
    modified_by: ?IdentityRef = null,
    modified_on: ?[]const u8 = null,
    name: ?[]const u8 = null,
    properties: ?std.json.ArrayHashMap([]const u8) = null,
    ticket: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskGroupCreateParameter = struct {
    /// Sets author name of the task group.
    author: ?[]const u8 = null,
    /// Sets category of the task group.
    category: ?[]const u8 = null,
    /// Sets description of the task group.
    description: ?[]const u8 = null,
    /// Sets friendly name of the task group.
    friendly_name: ?[]const u8 = null,
    /// Sets url icon of the task group.
    icon_url: ?[]const u8 = null,
    /// Sets input for the task group.
    inputs: ?[]const TaskInputDefinition = null,
    /// Sets display name of the task group.
    instance_name_format: ?[]const u8 = null,
    /// Sets name of the task group.
    name: ?[]const u8 = null,
    /// Sets parent task group Id. This is used while creating a draft task group.
    parent_definition_id: ?[]const u8 = null,
    /// Sets RunsOn of the task group. Value can be 'Agent', 'Server' or 'DeploymentGroup'.
    runs_on: ?[]const []const u8 = null,
    /// Sets tasks for the task group.
    tasks: ?[]const TaskGroupStep = null,
    version: ?TaskVersion = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskInputDefinition = struct {
    aliases: ?[]const []const u8 = null,
    default_value: ?[]const u8 = null,
    group_name: ?[]const u8 = null,
    help_mark_down: ?[]const u8 = null,
    label: ?[]const u8 = null,
    name: ?[]const u8 = null,
    options: ?std.json.ArrayHashMap([]const u8) = null,
    properties: ?std.json.ArrayHashMap([]const u8) = null,
    required: ?bool = null,
    type: ?[]const u8 = null,
    validation: ?TaskInputValidation = null,
    visible_rule: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskInputValidation = struct {
    /// Conditional expression
    expression: ?[]const u8 = null,
    /// Message explaining how user can correct if validation fails
    message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents tasks in the task group.
pub const TaskGroupStep = struct {
    /// Gets or sets as 'true' to run the task always, 'false' otherwise.
    always_run: ?bool = null,
    /// Gets or sets condition for the task.
    condition: ?[]const u8 = null,
    /// Gets or sets as 'true' to continue on error, 'false' otherwise.
    continue_on_error: ?bool = null,
    /// Gets or sets the display name.
    display_name: ?[]const u8 = null,
    /// Gets or sets as task is enabled or not.
    enabled: ?bool = null,
    /// Gets dictionary of environment variables.
    environment: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets dictionary of inputs.
    inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the maximum number of retries
    retry_count_on_task_failure: ?i32 = null,
    task: ?TaskDefinitionReference = null,
    /// Gets or sets the maximum time, in minutes, that a task is allowed to execute on agent before being cancelled by server. A zero value indicates an infinite timeout.
    timeout_in_minutes: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskDefinitionReference = struct {
    /// Gets or sets the definition type. Values can be 'task' or 'metaTask'.
    definition_type: ?[]const u8 = null,
    /// Gets or sets the unique identifier of task.
    id: ?[]const u8 = null,
    /// Gets or sets the version specification of task.
    version_spec: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskVersion = struct {
    is_test: ?bool = null,
    major: ?i32 = null,
    minor: ?i32 = null,
    patch: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskGroup = struct {
    agent_execution: ?TaskExecution = null,
    author: ?[]const u8 = null,
    build_config: ?[]const u8 = null,
    category: ?[]const u8 = null,
    contents_uploaded: ?bool = null,
    contribution_identifier: ?[]const u8 = null,
    contribution_version: ?[]const u8 = null,
    data_source_bindings: ?[]const DataSourceBinding = null,
    definition_type: ?[]const u8 = null,
    demands: ?[]const Demand = null,
    deprecated: ?bool = null,
    description: ?[]const u8 = null,
    disabled: ?bool = null,
    execution: ?std.json.ArrayHashMap(JObject) = null,
    friendly_name: ?[]const u8 = null,
    groups: ?[]const TaskGroupDefinition = null,
    help_mark_down: ?[]const u8 = null,
    help_url: ?[]const u8 = null,
    host_type: ?[]const u8 = null,
    icon_url: ?[]const u8 = null,
    id: ?[]const u8 = null,
    inputs: ?[]const TaskInputDefinition = null,
    instance_name_format: ?[]const u8 = null,
    minimum_agent_version: ?[]const u8 = null,
    name: ?[]const u8 = null,
    output_variables: ?[]const TaskOutputVariable = null,
    package_location: ?[]const u8 = null,
    package_type: ?[]const u8 = null,
    post_job_execution: ?std.json.ArrayHashMap(JObject) = null,
    pre_job_execution: ?std.json.ArrayHashMap(JObject) = null,
    preview: ?bool = null,
    release_notes: ?[]const u8 = null,
    restrictions: ?TaskRestrictions = null,
    runs_on: ?[]const []const u8 = null,
    satisfies: ?[]const []const u8 = null,
    server_owned: ?bool = null,
    show_environment_variables: ?bool = null,
    source_definitions: ?[]const TaskSourceDefinition = null,
    source_location: ?[]const u8 = null,
    version: ?TaskVersion = null,
    visibility: ?[]const []const u8 = null,
    /// Gets or sets comment.
    comment: ?[]const u8 = null,
    created_by: ?IdentityRef = null,
    /// Gets or sets date on which it got created.
    created_on: ?[]const u8 = null,
    /// Gets or sets as 'true' to indicate as deleted, 'false' otherwise.
    deleted: ?bool = null,
    modified_by: ?IdentityRef = null,
    /// Gets or sets date on which it got modified.
    modified_on: ?[]const u8 = null,
    /// Gets or sets the owner.
    owner: ?[]const u8 = null,
    /// Gets or sets parent task group Id. This is used while creating a draft task group.
    parent_definition_id: ?[]const u8 = null,
    /// Gets or sets revision.
    revision: ?i32 = null,
    /// Gets or sets the tasks.
    tasks: ?[]const TaskGroupStep = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskExecution = struct {
    exec_task: ?TaskReference = null,
    /// If a task is going to run code, then this provides the type/script etc... information by platform. For example, it might look like. net45: { typeName: 'Microsoft.TeamFoundation.Automation.Tasks.PowerShellTask', assemblyName: 'Microsoft.TeamFoundation.Automation.Tasks.PowerShell.dll' } net20: { typeName: 'Microsoft.TeamFoundation.Automation.Tasks.PowerShellTask', assemblyName: 'Microsoft.TeamFoundation.Automation.Tasks.PowerShell.dll' } java: { jar: 'powershelltask.tasks.automation.teamfoundation.microsoft.com', } node: { script: 'powershellhost.js', }
    platform_instructions: ?std.json.ArrayHashMap(std.json.ArrayHashMap([]const u8)) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const DataSourceBinding = struct {
    /// Pagination format supported by this data source(ContinuationToken/SkipTop).
    callback_context_template: ?[]const u8 = null,
    /// Subsequent calls needed?
    callback_required_template: ?[]const u8 = null,
    /// Gets or sets the name of the data source.
    data_source_name: ?[]const u8 = null,
    /// Gets or sets the endpoint Id.
    endpoint_id: ?[]const u8 = null,
    /// Gets or sets the url of the service endpoint.
    endpoint_url: ?[]const u8 = null,
    /// Gets or sets the authorization headers.
    headers: ?[]const AuthorizationHeader = null,
    /// Defines the initial value of the query params
    initial_context_template: ?[]const u8 = null,
    /// Gets or sets the parameters for the data source.
    parameters: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets http request body
    request_content: ?[]const u8 = null,
    /// Gets or sets http request verb
    request_verb: ?[]const u8 = null,
    /// Gets or sets the result selector.
    result_selector: ?[]const u8 = null,
    /// Gets or sets the result template.
    result_template: ?[]const u8 = null,
    /// Gets or sets the target of the data source.
    target: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AuthorizationHeader = struct {
    /// Gets or sets the name of authorization header.
    name: ?[]const u8 = null,
    /// Gets or sets the value of authorization header.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskGroupDefinition = struct {
    display_name: ?[]const u8 = null,
    is_expanded: ?bool = null,
    name: ?[]const u8 = null,
    tags: ?[]const []const u8 = null,
    visible_rule: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskOutputVariable = struct {
    description: ?[]const u8 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskRestrictions = struct {
    commands: ?TaskCommandRestrictions = null,
    settable_variables: ?TaskVariableRestrictions = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskCommandRestrictions = struct {
    mode: ?enums.TaskCommandRestrictionsMode = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskVariableRestrictions = struct {
    allowed: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskSourceDefinition = struct {
    auth_key: ?[]const u8 = null,
    endpoint: ?[]const u8 = null,
    key_selector: ?[]const u8 = null,
    selector: ?[]const u8 = null,
    target: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskGroupUpdateParameter = struct {
    /// Sets author name of the task group.
    author: ?[]const u8 = null,
    /// Sets category of the task group.
    category: ?[]const u8 = null,
    /// Sets comment of the task group.
    comment: ?[]const u8 = null,
    /// Sets description of the task group.
    description: ?[]const u8 = null,
    /// Sets friendly name of the task group.
    friendly_name: ?[]const u8 = null,
    /// Sets url icon of the task group.
    icon_url: ?[]const u8 = null,
    /// Sets the unique identifier of this field.
    id: ?[]const u8 = null,
    /// Sets input for the task group.
    inputs: ?[]const TaskInputDefinition = null,
    /// Sets display name of the task group.
    instance_name_format: ?[]const u8 = null,
    /// Sets name of the task group.
    name: ?[]const u8 = null,
    /// Gets or sets parent task group Id. This is used while creating a draft task group.
    parent_definition_id: ?[]const u8 = null,
    /// Sets revision of the task group.
    revision: ?i32 = null,
    /// Sets RunsOn of the task group. Value can be 'Agent', 'Server' or 'DeploymentGroup'.
    runs_on: ?[]const []const u8 = null,
    /// Sets tasks for the task group.
    tasks: ?[]const TaskGroupStep = null,
    version: ?TaskVersion = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
