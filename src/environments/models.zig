//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Environment.
pub const EnvironmentInstance = struct {
    created_by: ?IdentityRef = null,
    /// Creation time of the Environment
    created_on: ?[]const u8 = null,
    /// Description of the Environment.
    description: ?[]const u8 = null,
    /// Id of the Environment
    id: ?i32 = null,
    last_modified_by: ?IdentityRef = null,
    /// Last modified time of the Environment
    last_modified_on: ?[]const u8 = null,
    /// Name of the Environment.
    name: ?[]const u8 = null,
    project: ?ProjectReference = null,
    resources: ?[]const EnvironmentResourceReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const IdentityRef = struct {
    links: ?ReferenceLinks = null,
    descriptor: ?[]const u8 = null,
    display_name: ?[]const u8 = null,
    url: ?[]const u8 = null,
    directory_alias: ?[]const u8 = null,
    id: ?[]const u8 = null,
    image_url: ?[]const u8 = null,
    inactive: ?bool = null,
    is_aad_identity: ?bool = null,
    is_container: ?bool = null,
    is_deleted_in_origin: ?bool = null,
    profile_url: ?[]const u8 = null,
    unique_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const ReferenceLinks = struct {
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

pub const ProjectReference = struct {
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// EnvironmentResourceReference.
pub const EnvironmentResourceReference = struct {
    /// Id of the resource.
    id: ?i32 = null,
    /// Name of the resource.
    name: ?[]const u8 = null,
    /// Tags of the Environment Resource Reference.
    tags: ?[]const []const u8 = null,
    /// Type of the resource.
    type: ?enums.EnvironmentResourceReferenceType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Properties to create Environment.
pub const EnvironmentCreateParameter = struct {
    /// Description of the environment.
    description: ?[]const u8 = null,
    /// Name of the environment.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Properties to update Environment.
pub const EnvironmentUpdateParameter = struct {
    /// Description of the environment.
    description: ?[]const u8 = null,
    /// Name of the environment.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// EnvironmentDeploymentExecutionRecord.
pub const EnvironmentDeploymentExecutionRecord = struct {
    definition: ?TaskOrchestrationOwner = null,
    /// Id of the Environment
    environment_id: ?i32 = null,
    /// Finish time of the environment deployment execution
    finish_time: ?[]const u8 = null,
    /// Id of the Environment deployment execution history record
    id: ?i64 = null,
    /// Job Attempt
    job_attempt: ?i32 = null,
    /// Job name
    job_name: ?[]const u8 = null,
    owner: ?TaskOrchestrationOwner = null,
    /// Plan Id
    plan_id: ?[]const u8 = null,
    /// Plan type of the environment deployment execution record
    plan_type: ?[]const u8 = null,
    /// Queue time of the environment deployment execution
    queue_time: ?[]const u8 = null,
    /// Request identifier of the Environment deployment execution history record
    request_identifier: ?[]const u8 = null,
    /// Resource Id
    resource_id: ?i32 = null,
    /// Result of the environment deployment execution
    result: ?enums.EnvironmentDeploymentExecutionRecordResult = null,
    /// Project Id
    scope_id: ?[]const u8 = null,
    /// Service owner Id
    service_owner: ?[]const u8 = null,
    /// Stage Attempt
    stage_attempt: ?i32 = null,
    /// Stage name
    stage_name: ?[]const u8 = null,
    /// Start time of the environment deployment execution
    start_time: ?[]const u8 = null,

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

pub const KubernetesResourcePatchParameters = struct {
    authorization_parameters: ?std.json.ArrayHashMap([]const u8) = null,
    /// Provider type (CustomProvider or AzureKubernetesServiceProvider) of the resource to be updated
    provider_type: ?[]const u8 = null,
    resource_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const KubernetesResource = struct {
    id: ?i32 = null,
    name: ?[]const u8 = null,
    created_by: ?IdentityRef = null,
    created_on: ?[]const u8 = null,
    environment_reference: ?EnvironmentReference = null,
    last_modified_by: ?IdentityRef = null,
    last_modified_on: ?[]const u8 = null,
    /// Tags of the Environment Resource.
    tags: ?[]const []const u8 = null,
    /// Environment resource type
    type: ?enums.KubernetesResourceType = null,
    cluster_name: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    service_endpoint_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const EnvironmentReference = struct {
    id: ?i32 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const KubernetesResourceCreateParametersExistingEndpoint = struct {
    cluster_name: ?[]const u8 = null,
    name: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    /// Tags of the kubernetes resource.
    tags: ?[]const []const u8 = null,
    service_endpoint_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const VirtualMachineResource = struct {
    id: ?i32 = null,
    name: ?[]const u8 = null,
    created_by: ?IdentityRef = null,
    created_on: ?[]const u8 = null,
    environment_reference: ?EnvironmentReference = null,
    last_modified_by: ?IdentityRef = null,
    last_modified_on: ?[]const u8 = null,
    /// Tags of the Environment Resource.
    tags: ?[]const []const u8 = null,
    /// Environment resource type
    type: ?enums.KubernetesResourceType = null,
    agent: ?TaskAgent = null,

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
    status: ?enums.TaskAgentStatus = null,
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

pub const TaskAgentCloudRequest = struct {
    agent: ?TaskAgentReference = null,
    agent_cloud_id: ?i32 = null,
    agent_connected_time: ?[]const u8 = null,
    agent_data: ?[]const u8 = null,
    agent_specification: ?[]const u8 = null,
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
    status: ?enums.TaskAgentStatus = null,
    /// Agent version.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
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
    options: ?enums.TaskAgentPoolReferenceOptions = null,
    /// Gets or sets the type of the pool
    pool_type: ?enums.TaskAgentPoolReferencePoolType = null,
    scope: ?[]const u8 = null,
    /// Gets the current size of the pool.
    size: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
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
    agent_specification: ?[]const u8 = null,
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

pub const PropertiesCollection = struct {
    count: ?i32 = null,
    item: ?PropertiesCollectionItem = null,
    keys: ?[]const []const u8 = null,
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

pub const VirtualMachineResourceCreateParameters = struct {
    virtual_machine_resource: ?VirtualMachineResource = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
