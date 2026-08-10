//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `ReleaseApproval` as returned by Azure DevOps.
pub const ReleaseApprovalList = struct {
    count: ?i32 = null,
    value: ?[]const ReleaseApproval = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseApproval = struct {
    /// Gets or sets the type of approval.
    approval_type: ?enums.ReleaseApprovalApprovalType = null,
    approved_by: ?IdentityRef = null,
    approver: ?IdentityRef = null,
    /// Gets or sets attempt which specifies as which deployment attempt it belongs.
    attempt: ?i32 = null,
    /// Gets or sets comments for approval.
    comments: ?[]const u8 = null,
    /// Gets date on which it got created.
    created_on: ?[]const u8 = null,
    /// Gets history which specifies all approvals associated with this approval.
    history: ?[]const ReleaseApprovalHistory = null,
    /// Gets the unique identifier of this field.
    id: ?i32 = null,
    /// Gets or sets as approval is automated or not.
    is_automated: ?bool = null,
    /// Gets date on which it got modified.
    modified_on: ?[]const u8 = null,
    /// Gets or sets rank which specifies the order of the approval. e.g. Same rank denotes parallel approval.
    rank: ?i32 = null,
    release: ?ReleaseShallowReference = null,
    release_definition: ?ReleaseDefinitionShallowReference = null,
    release_environment: ?ReleaseEnvironmentShallowReference = null,
    /// Gets the revision number.
    revision: ?i32 = null,
    /// Gets or sets the status of the approval.
    status: ?enums.ReleaseApprovalStatus = null,
    /// Gets url to access the approval.
    url: ?[]const u8 = null,

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

pub const ReleaseApprovalHistory = struct {
    approver: ?IdentityRef = null,
    changed_by: ?IdentityRef = null,
    /// Approval history comments.
    comments: ?[]const u8 = null,
    /// Time when this approval created.
    created_on: ?[]const u8 = null,
    /// Time when this approval modified.
    modified_on: ?[]const u8 = null,
    /// Approval history revision.
    revision: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseShallowReference = struct {
    links: ?ReferenceLinks = null,
    /// Gets the unique identifier of release.
    id: ?i32 = null,
    /// Gets or sets the name of the release.
    name: ?[]const u8 = null,
    /// Gets the REST API url to access the release.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const ReleaseDefinitionShallowReference = struct {
    links: ?ReferenceLinks = null,
    /// Gets the unique identifier of release definition.
    id: ?i32 = null,
    /// Gets or sets the name of the release definition.
    name: ?[]const u8 = null,
    /// Gets or sets the path of the release definition.
    path: ?[]const u8 = null,
    project_reference: ?ProjectReference = null,
    /// Gets the REST API url to access the release definition.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const ProjectReference = struct {
    /// Gets the unique identifier of this field.
    id: ?[]const u8 = null,
    /// Gets name of project.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseEnvironmentShallowReference = struct {
    links: ?ReferenceLinks = null,
    /// Gets the unique identifier of release environment.
    id: ?i32 = null,
    /// Gets or sets the name of the release environment.
    name: ?[]const u8 = null,
    /// Gets the REST API url to access the release environment.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A collection of `ReleaseDefinition` as returned by Azure DevOps.
pub const ReleaseDefinitionList = struct {
    count: ?i32 = null,
    value: ?[]const ReleaseDefinition = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinition = struct {
    links: ?ReferenceLinks = null,
    /// Gets the unique identifier of release definition.
    id: ?i32 = null,
    /// Gets or sets the name of the release definition.
    name: ?[]const u8 = null,
    /// Gets or sets the path of the release definition.
    path: ?[]const u8 = null,
    project_reference: ?ProjectReference = null,
    /// Gets the REST API url to access the release definition.
    url: ?[]const u8 = null,
    /// Gets or sets the list of artifacts.
    artifacts: ?[]const Artifact = null,
    /// Gets or sets comment.
    comment: ?[]const u8 = null,
    created_by: ?IdentityRef = null,
    /// Gets date on which it got created.
    created_on: ?[]const u8 = null,
    /// Gets or sets the description.
    description: ?[]const u8 = null,
    /// Gets or sets the list of environments.
    environments: ?[]const ReleaseDefinitionEnvironment = null,
    /// Whether release definition is deleted.
    is_deleted: ?bool = null,
    /// Whether release definition is disabled.
    is_disabled: ?bool = null,
    last_release: ?ReleaseReference = null,
    modified_by: ?IdentityRef = null,
    /// Gets date on which it got modified.
    modified_on: ?[]const u8 = null,
    properties: ?PropertiesCollection = null,
    /// Gets or sets the release name format.
    release_name_format: ?[]const u8 = null,
    /// Gets the revision number.
    revision: ?i32 = null,
    /// Gets or sets source of release definition.
    source: ?enums.ReleaseDefinitionSource = null,
    /// Gets or sets list of tags.
    tags: ?[]const []const u8 = null,
    /// Gets or sets the list of triggers.
    triggers: ?[]const ReleaseTriggerBase = null,
    /// Gets or sets the list of variable groups.
    variable_groups: ?[]const i32 = null,
    /// Gets or sets the dictionary of variables.
    variables: ?std.json.ArrayHashMap(ConfigurationVariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const Artifact = struct {
    /// Gets or sets alias.
    alias: ?[]const u8 = null,
    /// Gets or sets definition reference. e.g. {'project':{'id':'fed755ea-49c5-4399-acea-fd5b5aa90a6c','name':'myProject'},'definition':{'id':'1','name':'mybuildDefinition'},'connection':{'id':'1','name':'myConnection'}}.
    definition_reference: ?std.json.ArrayHashMap(ArtifactSourceReference) = null,
    /// Indicates whether artifact is primary or not.
    is_primary: ?bool = null,
    /// Indicates whether artifact is retained by release or not.
    is_retained: ?bool = null,
    /// Gets or sets type. It can have value as 'Build', 'Jenkins', 'GitHub', 'Nuget', 'Team Build (external)', 'ExternalTFSBuild', 'Git', 'TFVC', 'ExternalTfsXamlBuild'.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ArtifactSourceReference = struct {
    /// ID of the artifact source.
    id: ?[]const u8 = null,
    /// Name of the artifact source.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinitionEnvironment = struct {
    /// Gets or sets the BadgeUrl. BadgeUrl will be used when Badge will be enabled in Release Definition Environment.
    badge_url: ?[]const u8 = null,
    /// Gets or sets the environment conditions.
    conditions: ?[]const Condition = null,
    current_release: ?ReleaseShallowReference = null,
    /// Gets or sets the demands.
    demands: ?[]const Demand = null,
    /// Gets or sets the deploy phases of environment.
    deploy_phases: ?[]const DeployPhase = null,
    deploy_step: ?ReleaseDefinitionDeployStep = null,
    environment_options: ?EnvironmentOptions = null,
    /// Gets or sets the triggers on environment.
    environment_triggers: ?[]const EnvironmentTrigger = null,
    execution_policy: ?EnvironmentExecutionPolicy = null,
    /// Gets and sets the ID of the ReleaseDefinitionEnvironment.
    id: ?i32 = null,
    /// Gets and sets the name of the ReleaseDefinitionEnvironment.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    post_deploy_approvals: ?ReleaseDefinitionApprovals = null,
    post_deployment_gates: ?ReleaseDefinitionGatesStep = null,
    pre_deploy_approvals: ?ReleaseDefinitionApprovals = null,
    pre_deployment_gates: ?ReleaseDefinitionGatesStep = null,
    process_parameters: ?ProcessParameters = null,
    properties: ?PropertiesCollection = null,
    /// Gets or sets the queue ID.
    queue_id: ?i32 = null,
    /// Gets and sets the rank of the ReleaseDefinitionEnvironment.
    rank: ?i32 = null,
    retention_policy: ?EnvironmentRetentionPolicy = null,
    /// Gets or sets the schedules
    schedules: ?[]const ReleaseSchedule = null,
    /// Gets or sets the variable groups.
    variable_groups: ?[]const i32 = null,
    /// Gets and sets the variables.
    variables: ?std.json.ArrayHashMap(ConfigurationVariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Condition = struct {
    /// Gets or sets the condition type.
    condition_type: ?enums.ConditionConditionType = null,
    /// Gets or sets the name of the condition. e.g. 'ReleaseStarted'.
    name: ?[]const u8 = null,
    /// The release condition result.
    result: ?bool = null,
    /// Gets or set value of the condition.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Demand = struct {
    /// Gets and sets the name of demand.
    name: ?[]const u8 = null,
    /// Gets and sets the value of demand.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const DeployPhase = struct {
    /// Gets and sets the name of deploy phase.
    name: ?[]const u8 = null,
    /// Indicates the deploy phase type.
    phase_type: ?enums.DeployPhasePhaseType = null,
    /// Gets and sets the rank of deploy phase.
    rank: ?i32 = null,
    /// Gets and sets the reference name of deploy phase.
    ref_name: ?[]const u8 = null,
    /// Gets and sets the workflow tasks for the deploy phase.
    workflow_tasks: ?[]const WorkflowTask = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkflowTask = struct {
    /// Gets or sets as the task always run or not.
    always_run: ?bool = null,
    check_config: ?CheckConfigurationReference = null,
    /// Gets or sets the task condition.
    condition: ?[]const u8 = null,
    /// Gets or sets as the task continue run on error or not.
    continue_on_error: ?bool = null,
    /// Gets or sets the task definition type. Example:- 'Agent', DeploymentGroup', 'Server' or 'ServerGate'.
    definition_type: ?[]const u8 = null,
    /// Gets or sets as the task enabled or not.
    enabled: ?bool = null,
    /// Gets or sets the task environment variables.
    environment: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the task inputs.
    inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the name of the task.
    name: ?[]const u8 = null,
    /// Gets or sets the task override inputs.
    override_inputs: ?std.json.ArrayHashMap([]const u8) = null,
    /// Gets or sets the reference name of the task.
    ref_name: ?[]const u8 = null,
    /// Gets or sets the task retryCount.
    retry_count_on_task_failure: ?i32 = null,
    /// Gets or sets the ID of the task.
    task_id: ?[]const u8 = null,
    /// Gets or sets the task timeout.
    timeout_in_minutes: ?i32 = null,
    /// Gets or sets the version of the task.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CheckConfigurationReference = struct {
    /// Check configuration Id of generated gate.
    id: ?i32 = null,
    /// Name of the resource for which gate was generated.
    resource_name: ?[]const u8 = null,
    /// Type of the resource for which the gate was generated.
    resource_type: ?[]const u8 = null,
    /// Version of the check configuration gate was generated with.
    version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinitionDeployStep = struct {
    /// ID of the approval or deploy step.
    id: ?i32 = null,
    /// The list of steps for this definition.
    tasks: ?[]const WorkflowTask = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const EnvironmentOptions = struct {
    /// Gets and sets as the auto link workitems or not.
    auto_link_work_items: ?bool = null,
    /// Gets and sets as the badge enabled or not.
    badge_enabled: ?bool = null,
    /// Gets and sets as the publish deployment status or not.
    publish_deployment_status: ?bool = null,
    /// Gets and sets as the.pull request deployment enabled or not.
    pull_request_deployment_enabled: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const EnvironmentTrigger = struct {
    /// Definition environment ID on which this trigger applicable.
    definition_environment_id: ?i32 = null,
    /// ReleaseDefinition ID on which this trigger applicable.
    release_definition_id: ?i32 = null,
    /// Gets or sets the trigger content.
    trigger_content: ?[]const u8 = null,
    /// Gets or sets the trigger type.
    trigger_type: ?enums.EnvironmentTriggerTriggerType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines policy on environment queuing at Release Management side queue. We will send to Environment Runner [creating pre-deploy and other steps] only when the policies mentioned are satisfied.
pub const EnvironmentExecutionPolicy = struct {
    /// This policy decides, how many environments would be with Environment Runner.
    concurrency_count: ?i32 = null,
    /// Queue depth in the EnvironmentQueue table, this table keeps the environment entries till Environment Runner is free [as per it's policy] to take another environment for running.
    queue_depth_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinitionApprovals = struct {
    approval_options: ?ApprovalOptions = null,
    /// Gets or sets the approvals.
    approvals: ?[]const ReleaseDefinitionApprovalStep = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ApprovalOptions = struct {
    /// Specify whether the approval can be skipped if the same approver approved the previous stage.
    auto_triggered_and_previous_environment_approved_can_be_skipped: ?bool = null,
    /// Specify whether revalidate identity of approver before completing the approval.
    enforce_identity_revalidation: ?bool = null,
    /// Approvals execution order.
    execution_order: ?enums.ApprovalOptionsExecutionOrder = null,
    /// Specify whether the user requesting a release or deployment should allow to approver.
    release_creator_can_be_approver: ?bool = null,
    /// The number of approvals required to move release forward. '0' means all approvals required.
    required_approver_count: ?i32 = null,
    /// Approval timeout. Approval default timeout is 30 days. Maximum allowed timeout is 365 days. '0' means default timeout i.e 30 days.
    timeout_in_minutes: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinitionApprovalStep = struct {
    /// ID of the approval or deploy step.
    id: ?i32 = null,
    approver: ?IdentityRef = null,
    /// Indicates whether the approval automated.
    is_automated: ?bool = null,
    /// Indicates whether the approval notification set.
    is_notification_on: ?bool = null,
    /// Gets or sets the rank of approval step.
    rank: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinitionGatesStep = struct {
    /// Gets or sets the gates.
    gates: ?[]const ReleaseDefinitionGate = null,
    gates_options: ?ReleaseDefinitionGatesOptions = null,
    /// ID of the ReleaseDefinitionGateStep.
    id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinitionGate = struct {
    /// Gets or sets the flag that indicates if gate was generated.
    is_generated: ?bool = null,
    /// Gets or sets the gates workflow.
    tasks: ?[]const WorkflowTask = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinitionGatesOptions = struct {
    /// Gets or sets as the gates enabled or not.
    is_enabled: ?bool = null,
    /// Gets or sets the minimum duration for steady results after a successful gates evaluation.
    minimum_success_duration: ?i32 = null,
    /// Gets or sets the time between re-evaluation of gates.
    sampling_interval: ?i32 = null,
    /// Gets or sets the delay before evaluation.
    stabilization_time: ?i32 = null,
    /// Gets or sets the timeout after which gates fail.
    timeout: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProcessParameters = struct {
    data_source_bindings: ?[]const DataSourceBindingBase = null,
    inputs: ?[]const TaskInputDefinitionBase = null,
    source_definitions: ?[]const TaskSourceDefinitionBase = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents binding of data source for the service endpoint request.
pub const DataSourceBindingBase = struct {
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
    name: ?[]const u8 = null,
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TaskInputDefinitionBase = struct {
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

pub const TaskSourceDefinitionBase = struct {
    auth_key: ?[]const u8 = null,
    endpoint: ?[]const u8 = null,
    key_selector: ?[]const u8 = null,
    selector: ?[]const u8 = null,
    target: ?[]const u8 = null,

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

pub const EnvironmentRetentionPolicy = struct {
    /// Gets and sets the number of days to keep environment.
    days_to_keep: ?i32 = null,
    /// Gets and sets the number of releases to keep.
    releases_to_keep: ?i32 = null,
    /// Gets and sets as the build to be retained or not.
    retain_build: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseSchedule = struct {
    /// Days of the week to release.
    days_to_release: ?enums.ReleaseScheduleDaysToRelease = null,
    /// Team Foundation Job Definition Job Id.
    job_id: ?[]const u8 = null,
    /// Flag to determine if this schedule should only release if the associated artifact has been changed or release definition changed.
    schedule_only_with_changes: ?bool = null,
    /// Local time zone hour to start.
    start_hours: ?i32 = null,
    /// Local time zone minute to start.
    start_minutes: ?i32 = null,
    /// Time zone Id of release schedule, such as 'UTC'.
    time_zone_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ConfigurationVariableValue = struct {
    /// Gets and sets if a variable can be overridden at deployment time or not.
    allow_override: ?bool = null,
    /// Gets or sets as variable is secret or not.
    is_secret: ?bool = null,
    /// Gets and sets value of the configuration variable.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseReference = struct {
    links: ?ReferenceLinks = null,
    /// Gets list of artifacts.
    artifacts: ?[]const Artifact = null,
    created_by: ?IdentityRef = null,
    /// Gets date on when this release created.
    created_on: ?[]const u8 = null,
    /// Gets description.
    description: ?[]const u8 = null,
    /// ID of the Release.
    id: ?i32 = null,
    modified_by: ?IdentityRef = null,
    /// Gets name of release.
    name: ?[]const u8 = null,
    /// Gets reason for release.
    reason: ?enums.ReleaseReferenceReason = null,
    release_definition: ?ReleaseDefinitionShallowReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const ReleaseTriggerBase = struct {
    /// Type of release trigger.
    trigger_type: ?enums.ReleaseTriggerBaseTriggerType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ReleaseDefinitionRevision` as returned by Azure DevOps.
pub const ReleaseDefinitionRevisionList = struct {
    count: ?i32 = null,
    value: ?[]const ReleaseDefinitionRevision = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDefinitionRevision = struct {
    /// Gets api-version for revision object.
    api_version: ?[]const u8 = null,
    changed_by: ?IdentityRef = null,
    /// Gets date on which ReleaseDefinition changed.
    changed_date: ?[]const u8 = null,
    /// Gets type of change.
    change_type: ?enums.ReleaseDefinitionRevisionChangeType = null,
    /// Gets comments for revision.
    comment: ?[]const u8 = null,
    /// Get id of the definition.
    definition_id: ?i32 = null,
    /// Gets definition URL.
    definition_url: ?[]const u8 = null,
    /// Get revision number of the definition.
    revision: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `Deployment` as returned by Azure DevOps.
pub const DeploymentList = struct {
    count: ?i32 = null,
    value: ?[]const Deployment = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Deployment = struct {
    /// Gets attempt number.
    attempt: ?i32 = null,
    /// Gets the date on which deployment is complete.
    completed_on: ?[]const u8 = null,
    /// Gets the list of condition associated with deployment.
    conditions: ?[]const Condition = null,
    /// Gets release definition environment id.
    definition_environment_id: ?i32 = null,
    /// Gets status of the deployment.
    deployment_status: ?enums.DeploymentDeploymentStatus = null,
    /// Gets the unique identifier for deployment.
    id: ?i32 = null,
    last_modified_by: ?IdentityRef = null,
    /// Gets the date on which deployment is last modified.
    last_modified_on: ?[]const u8 = null,
    /// Gets operation status of deployment.
    operation_status: ?enums.DeploymentOperationStatus = null,
    /// Gets list of PostDeployApprovals.
    post_deploy_approvals: ?[]const ReleaseApproval = null,
    /// Gets list of PreDeployApprovals.
    pre_deploy_approvals: ?[]const ReleaseApproval = null,
    project_reference: ?ProjectReference = null,
    /// Gets the date on which deployment is queued.
    queued_on: ?[]const u8 = null,
    /// Gets reason of deployment.
    reason: ?enums.DeploymentReason = null,
    release: ?ReleaseReference = null,
    release_definition: ?ReleaseDefinitionShallowReference = null,
    release_environment: ?ReleaseEnvironmentShallowReference = null,
    requested_by: ?IdentityRef = null,
    requested_for: ?IdentityRef = null,
    /// Gets the date on which deployment is scheduled.
    scheduled_deployment_time: ?[]const u8 = null,
    /// Gets the date on which deployment is started.
    started_on: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `Folder` as returned by Azure DevOps.
pub const FolderList = struct {
    count: ?i32 = null,
    value: ?[]const Folder = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Folder = struct {
    created_by: ?IdentityRef = null,
    /// Time when this folder created.
    created_on: ?[]const u8 = null,
    /// Description of the folder.
    description: ?[]const u8 = null,
    last_changed_by: ?IdentityRef = null,
    /// Time when this folder last changed.
    last_changed_date: ?[]const u8 = null,
    /// path of the folder.
    path: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GateUpdateMetadata = struct {
    /// Comment.
    comment: ?[]const u8 = null,
    /// Name of gate to be ignored.
    gates_to_ignore: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseGates = struct {
    /// Contains the gates job details of each evaluation.
    deployment_jobs: ?[]const DeploymentJob = null,
    /// ID of release gates.
    id: ?i32 = null,
    /// List of ignored gates.
    ignored_gates: ?[]const IgnoredGate = null,
    /// Gates last modified time.
    last_modified_on: ?[]const u8 = null,
    /// Run plan ID of the gates.
    run_plan_id: ?[]const u8 = null,
    /// Gates stabilization completed date and time.
    stabilization_completed_on: ?[]const u8 = null,
    /// Gates evaluation started time.
    started_on: ?[]const u8 = null,
    /// Status of release gates.
    status: ?enums.ReleaseGatesStatus = null,
    /// Date and time at which all gates executed successfully.
    succeeding_since: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const DeploymentJob = struct {
    job: ?ReleaseTask = null,
    /// List of executed tasks with in job.
    tasks: ?[]const ReleaseTask = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseTask = struct {
    /// Agent name on which task executed.
    agent_name: ?[]const u8 = null,
    /// Finish time of the release task.
    finish_time: ?[]const u8 = null,
    /// ID of the release task.
    id: ?i32 = null,
    /// List of issues occurred while execution of task.
    issues: ?[]const Issue = null,
    /// Number of lines log release task has.
    line_count: ?i64 = null,
    /// Log URL of the task.
    log_url: ?[]const u8 = null,
    /// Name of the task.
    name: ?[]const u8 = null,
    /// Task execution complete precent.
    percent_complete: ?i32 = null,
    /// Rank of the release task.
    rank: ?i32 = null,
    /// Result code of the task.
    result_code: ?[]const u8 = null,
    /// ID of the release task.
    start_time: ?[]const u8 = null,
    /// Status of release task.
    status: ?enums.ReleaseTaskStatus = null,
    task: ?WorkflowTaskReference = null,
    /// Timeline record ID of the release task.
    timeline_record_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Issue = struct {
    /// Issue data.
    data: ?std.json.ArrayHashMap([]const u8) = null,
    /// Issue type, for example error, warning or info.
    issue_type: ?[]const u8 = null,
    /// Issue message.
    message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkflowTaskReference = struct {
    /// Task identifier.
    id: ?[]const u8 = null,
    /// Name of the task.
    name: ?[]const u8 = null,
    /// Version of the task.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const IgnoredGate = struct {
    /// Gets the date on which gate is last ignored.
    last_modified_on: ?[]const u8 = null,
    /// Name of gate ignored.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `Release` as returned by Azure DevOps.
pub const ReleaseList = struct {
    count: ?i32 = null,
    value: ?[]const Release = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Release = struct {
    links: ?ReferenceLinks = null,
    /// Gets or sets the list of artifacts.
    artifacts: ?[]const Artifact = null,
    /// Gets or sets comment.
    comment: ?[]const u8 = null,
    created_by: ?IdentityRef = null,
    created_for: ?IdentityRef = null,
    /// Gets date on which it got created.
    created_on: ?[]const u8 = null,
    /// Gets revision number of definition snapshot.
    definition_snapshot_revision: ?i32 = null,
    /// Gets or sets description of release.
    description: ?[]const u8 = null,
    /// Gets list of environments.
    environments: ?[]const ReleaseEnvironment = null,
    /// Gets the unique identifier of this field.
    id: ?i32 = null,
    /// Whether to exclude the release from retention policies.
    keep_forever: ?bool = null,
    /// Gets logs container url.
    logs_container_url: ?[]const u8 = null,
    modified_by: ?IdentityRef = null,
    /// Gets date on which it got modified.
    modified_on: ?[]const u8 = null,
    /// Gets name.
    name: ?[]const u8 = null,
    /// Gets pool name.
    pool_name: ?[]const u8 = null,
    project_reference: ?ProjectReference = null,
    properties: ?PropertiesCollection = null,
    /// Gets reason of release.
    reason: ?enums.ReleaseReason = null,
    release_definition: ?ReleaseDefinitionShallowReference = null,
    /// Gets or sets the release definition revision.
    release_definition_revision: ?i32 = null,
    /// Gets release name format.
    release_name_format: ?[]const u8 = null,
    /// Gets status.
    status: ?enums.ReleaseStatus = null,
    /// Gets or sets list of tags.
    tags: ?[]const []const u8 = null,
    triggering_artifact_alias: ?[]const u8 = null,
    /// Gets the list of variable groups.
    variable_groups: ?[]const VariableGroup = null,
    /// Gets or sets the dictionary of variables.
    variables: ?std.json.ArrayHashMap(ConfigurationVariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const ReleaseEnvironment = struct {
    /// Gets list of conditions.
    conditions: ?[]const ReleaseCondition = null,
    /// Gets date on which it got created.
    created_on: ?[]const u8 = null,
    /// Gets definition environment id.
    definition_environment_id: ?i32 = null,
    /// Gets list of deploy phases snapshot.
    deploy_phases_snapshot: ?[]const DeployPhase = null,
    /// Gets deploy steps.
    deploy_steps: ?[]const DeploymentAttempt = null,
    environment_options: ?EnvironmentOptions = null,
    /// Gets the unique identifier of this field.
    id: ?i32 = null,
    /// Gets date on which it got modified.
    modified_on: ?[]const u8 = null,
    /// Gets name.
    name: ?[]const u8 = null,
    /// Gets next scheduled UTC time.
    next_scheduled_utc_time: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    post_approvals_snapshot: ?ReleaseDefinitionApprovals = null,
    /// Gets list of post deploy approvals.
    post_deploy_approvals: ?[]const ReleaseApproval = null,
    post_deployment_gates_snapshot: ?ReleaseDefinitionGatesStep = null,
    pre_approvals_snapshot: ?ReleaseDefinitionApprovals = null,
    /// Gets list of pre deploy approvals.
    pre_deploy_approvals: ?[]const ReleaseApproval = null,
    pre_deployment_gates_snapshot: ?ReleaseDefinitionGatesStep = null,
    process_parameters: ?ProcessParameters = null,
    /// Gets rank.
    rank: ?i32 = null,
    release: ?ReleaseShallowReference = null,
    release_created_by: ?IdentityRef = null,
    release_definition: ?ReleaseDefinitionShallowReference = null,
    /// Gets release id.
    release_id: ?i32 = null,
    /// Gets schedule deployment time of release environment.
    scheduled_deployment_time: ?[]const u8 = null,
    /// Gets list of schedules.
    schedules: ?[]const ReleaseSchedule = null,
    /// Gets environment status.
    status: ?enums.ReleaseEnvironmentStatus = null,
    /// Gets time to deploy.
    time_to_deploy: ?f64 = null,
    /// Gets trigger reason.
    trigger_reason: ?[]const u8 = null,
    /// Gets the list of variable groups.
    variable_groups: ?[]const VariableGroup = null,
    /// Gets the dictionary of variables.
    variables: ?std.json.ArrayHashMap(ConfigurationVariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseCondition = struct {
    /// Gets or sets the condition type.
    condition_type: ?enums.ConditionConditionType = null,
    /// Gets or sets the name of the condition. e.g. 'ReleaseStarted'.
    name: ?[]const u8 = null,
    /// The release condition result.
    result: ?bool = null,
    /// Gets or set value of the condition.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const DeploymentAttempt = struct {
    /// Deployment attempt.
    attempt: ?i32 = null,
    /// ID of the deployment.
    deployment_id: ?i32 = null,
    /// Specifies whether deployment has started or not.
    has_started: ?bool = null,
    /// ID of deployment.
    id: ?i32 = null,
    /// All the issues related to the deployment.
    issues: ?[]const Issue = null,
    last_modified_by: ?IdentityRef = null,
    /// Time when this deployment last modified.
    last_modified_on: ?[]const u8 = null,
    /// Deployment operation status.
    operation_status: ?enums.DeploymentAttemptOperationStatus = null,
    post_deployment_gates: ?ReleaseGates = null,
    pre_deployment_gates: ?ReleaseGates = null,
    /// When this deployment queued on.
    queued_on: ?[]const u8 = null,
    /// Reason for the deployment.
    reason: ?enums.DeploymentAttemptReason = null,
    /// List of release deployphases executed in this deployment.
    release_deploy_phases: ?[]const ReleaseDeployPhase = null,
    requested_by: ?IdentityRef = null,
    requested_for: ?IdentityRef = null,
    /// status of the deployment.
    status: ?enums.DeploymentAttemptStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseDeployPhase = struct {
    /// Deployment jobs of the phase.
    deployment_jobs: ?[]const DeploymentJob = null,
    /// Phase execution error logs.
    error_log: ?[]const u8 = null,
    /// List of manual intervention tasks execution information in phase.
    manual_interventions: ?[]const ManualIntervention = null,
    /// Name of the phase.
    name: ?[]const u8 = null,
    /// ID of the phase.
    phase_id: ?[]const u8 = null,
    /// Type of the phase.
    phase_type: ?enums.ReleaseDeployPhasePhaseType = null,
    /// Rank of the phase.
    rank: ?i32 = null,
    /// Run Plan ID of the phase.
    run_plan_id: ?[]const u8 = null,
    /// Phase start time.
    started_on: ?[]const u8 = null,
    /// Status of the phase.
    status: ?enums.ReleaseDeployPhaseStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ManualIntervention = struct {
    approver: ?IdentityRef = null,
    /// Gets or sets comments for approval.
    comments: ?[]const u8 = null,
    /// Gets date on which it got created.
    created_on: ?[]const u8 = null,
    /// Gets the unique identifier for manual intervention.
    id: ?i32 = null,
    /// Gets or sets instructions for approval.
    instructions: ?[]const u8 = null,
    /// Gets date on which it got modified.
    modified_on: ?[]const u8 = null,
    /// Gets or sets the name.
    name: ?[]const u8 = null,
    po_p_tenant: ?ProofOfPresenceTenant = null,
    release: ?ReleaseShallowReference = null,
    release_definition: ?ReleaseDefinitionShallowReference = null,
    release_environment: ?ReleaseEnvironmentShallowReference = null,
    /// Gets or sets the status of the manual intervention.
    status: ?enums.ManualInterventionStatus = null,
    /// Get task instance identifier.
    task_instance_id: ?[]const u8 = null,
    /// Gets or sets the type.
    type: ?enums.ManualInterventionType = null,
    /// Gets url to access the manual intervention.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProofOfPresenceTenant = struct {
    /// Gets authority of protected tenant.
    authority: ?[]const u8 = null,
    /// Gets domain hint of protected tenant.
    domain_hint: ?[]const u8 = null,
    /// Gets distinct list of resources which have proof of presence check configured for this tenant.
    resources: ?[]const CheckConfigurationResource = null,
    /// Gets id of protected tenant.
    tenant_id: ?[]const u8 = null,
    /// Gets name of protected tenant.
    tenant_name: ?[]const u8 = null,
    /// Gets timeout of protected tenant PoP check.
    timeout: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CheckConfigurationResource = struct {
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

pub const VariableGroup = struct {
    created_by: ?IdentityRef = null,
    /// Gets date on which it got created.
    created_on: ?[]const u8 = null,
    /// Gets or sets description.
    description: ?[]const u8 = null,
    /// Gets the unique identifier of this field.
    id: ?i32 = null,
    /// Denotes if a variable group is shared with other project or not.
    is_shared: ?bool = null,
    modified_by: ?IdentityRef = null,
    /// Gets date on which it got modified.
    modified_on: ?[]const u8 = null,
    /// Gets or sets name.
    name: ?[]const u8 = null,
    provider_data: ?VariableGroupProviderData = null,
    /// Gets or sets type.
    type: ?[]const u8 = null,
    /// all project references where the variable group is shared with other projects.
    variable_group_project_references: ?[]const VariableGroupProjectReference = null,
    /// Gets and sets the dictionary of variables.
    variables: ?std.json.ArrayHashMap(VariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const VariableGroupProviderData = struct {
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

pub const VariableValue = struct {
    /// Gets or sets if the variable is read only or not.
    is_read_only: ?bool = null,
    /// Gets or sets as the variable is secret or not.
    is_secret: ?bool = null,
    /// Gets or sets the value.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseStartMetadata = struct {
    /// Sets list of artifact to create a release.
    artifacts: ?[]const ArtifactMetadata = null,
    /// Sets definition Id to create a release.
    definition_id: ?i32 = null,
    /// Sets description to create a release.
    description: ?[]const u8 = null,
    /// Sets list of environments meta data.
    environments_metadata: ?[]const ReleaseStartEnvironmentMetadata = null,
    /// Sets 'true' to create release in draft mode, 'false' otherwise.
    is_draft: ?bool = null,
    /// Sets list of environments to manual as condition.
    manual_environments: ?[]const []const u8 = null,
    properties: ?PropertiesCollection = null,
    /// Sets reason to create a release.
    reason: ?enums.ReleaseStartMetadataReason = null,
    /// Sets list of release variables to be overridden at deployment time.
    variables: ?std.json.ArrayHashMap(ConfigurationVariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ArtifactMetadata = struct {
    /// Sets alias of artifact.
    alias: ?[]const u8 = null,
    instance_reference: ?BuildVersion = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BuildVersion = struct {
    /// Gets or sets the commit message for the artifact.
    commit_message: ?[]const u8 = null,
    /// Gets or sets the definition id.
    definition_id: ?[]const u8 = null,
    /// Gets or sets the definition name.
    definition_name: ?[]const u8 = null,
    /// Gets or sets the build id.
    id: ?[]const u8 = null,
    /// Gets or sets if the artifact supports multiple definitions.
    is_multi_definition_type: ?bool = null,
    /// Gets or sets the build number.
    name: ?[]const u8 = null,
    /// Gets or sets the source branch for the artifact.
    source_branch: ?[]const u8 = null,
    source_pull_request_version: ?SourcePullRequestVersion = null,
    /// Gets or sets the repository id for the artifact.
    source_repository_id: ?[]const u8 = null,
    /// Gets or sets the repository type for the artifact.
    source_repository_type: ?[]const u8 = null,
    /// Gets or sets the source version for the artifact.
    source_version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SourcePullRequestVersion = struct {
    /// Pull Request Iteration Id for which the release will publish status.
    iteration_id: ?[]const u8 = null,
    /// Pull Request Id for which the release will publish status.
    pull_request_id: ?[]const u8 = null,
    /// Date and time of the pull request merge creation. It is required to keep timeline record of Releases created by pull request.
    pull_request_merged_at: ?[]const u8 = null,
    /// Source branch of the Pull Request.
    source_branch: ?[]const u8 = null,
    /// Source branch commit Id of the Pull Request for which the release will publish status.
    source_branch_commit_id: ?[]const u8 = null,
    /// Target branch of the Pull Request.
    target_branch: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseStartEnvironmentMetadata = struct {
    /// Sets release definition environment id.
    definition_environment_id: ?i32 = null,
    /// Sets list of environments variables to be overridden at deployment time.
    variables: ?std.json.ArrayHashMap(ConfigurationVariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseUpdateMetadata = struct {
    /// Sets comment for release.
    comment: ?[]const u8 = null,
    /// Set 'true' to exclude the release from retention policies.
    keep_forever: ?bool = null,
    /// Sets list of manual environments.
    manual_environments: ?[]const []const u8 = null,
    /// Sets name of the release.
    name: ?[]const u8 = null,
    /// Sets status of the release.
    status: ?enums.ReleaseUpdateMetadataStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseEnvironmentUpdateMetadata = struct {
    /// Gets or sets comment.
    comment: ?[]const u8 = null,
    /// Gets or sets scheduled deployment time.
    scheduled_deployment_time: ?[]const u8 = null,
    /// Gets or sets status of environment.
    status: ?enums.ReleaseEnvironmentUpdateMetadataStatus = null,
    /// Sets list of environment variables to be overridden at deployment time.
    variables: ?std.json.ArrayHashMap(ConfigurationVariableValue) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ReleaseTaskAttachment` as returned by Azure DevOps.
pub const ReleaseTaskAttachmentList = struct {
    count: ?i32 = null,
    value: ?[]const ReleaseTaskAttachment = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReleaseTaskAttachment = struct {
    links: ?ReferenceLinks = null,
    /// Data and time when it created.
    created_on: ?[]const u8 = null,
    modified_by: ?IdentityRef = null,
    /// Data and time when modified.
    modified_on: ?[]const u8 = null,
    /// Name of the task attachment.
    name: ?[]const u8 = null,
    /// Record ID of the task.
    record_id: ?[]const u8 = null,
    /// Timeline ID of the task.
    timeline_id: ?[]const u8 = null,
    /// Type of task attachment.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A collection of `ManualIntervention` as returned by Azure DevOps.
pub const ManualInterventionList = struct {
    count: ?i32 = null,
    value: ?[]const ManualIntervention = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ManualInterventionUpdateMetadata = struct {
    /// Sets the comment for manual intervention update.
    comment: ?[]const u8 = null,
    /// Sets the status of the manual intervention.
    status: ?enums.ManualInterventionUpdateMetadataStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
