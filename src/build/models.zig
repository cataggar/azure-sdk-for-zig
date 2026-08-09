//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const BuildController = struct {
    /// Id of the resource
    id: ?i32 = null,
    /// Name of the linked resource (definition name, controller name, etc.)
    name: ?[]const u8 = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The date the controller was created.
    created_date: ?[]const u8 = null,
    /// The description of the controller.
    description: ?[]const u8 = null,
    /// Indicates whether the controller is enabled.
    enabled: ?bool = null,
    /// The status of the controller.
    status: ?enums.BuildControllerStatus = null,
    /// The date the controller was last updated.
    updated_date: ?[]const u8 = null,
    /// The controller's URI.
    uri: ?[]const u8 = null,

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

/// Represents information about resources used by builds in the system.
pub const BuildResourceUsage = struct {
    /// The number of build agents.
    distributed_task_agents: ?i32 = null,
    /// The number of paid private agent slots.
    paid_private_agent_slots: ?i32 = null,
    /// The total usage.
    total_usage: ?i32 = null,
    /// The number of XAML controllers.
    xaml_controllers: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A historical overview of build retention information. This includes a list of snapshots taken about build retention usage, and a list of builds that have exceeded the default 30 day retention policy.
pub const BuildRetentionHistory = struct {
    /// A list of builds that are older than the default retention policy, but are not marked as retained. Something is causing these builds to not get cleaned up.
    build_retention_samples: ?[]const BuildRetentionSample = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A snapshot of build retention information. This class takes a sample at the given time. It provides information about retained builds, files associated with those retained builds, and number of files being retained.
pub const BuildRetentionSample = struct {
    /// Summary of retention by build
    builds: ?[]const u8 = null,
    /// List of build definitions
    definitions: ?[]const u8 = null,
    /// Summary of files consumed by retained builds
    files: ?[]const u8 = null,
    /// The date and time when the sample was taken
    sample_time: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const DefinitionResourceReference = struct {
    /// Indicates whether the resource is authorized for use.
    authorized: ?bool = null,
    /// The id of the resource.
    id: ?[]const u8 = null,
    /// A friendly name for the resource.
    name: ?[]const u8 = null,
    /// The type of the resource.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data representation of a build.
pub const Build = struct {
    links: ?ReferenceLinks = null,
    agent_specification: ?AgentSpecification = null,
    /// Append Commit Message To BuildNumber in UI.
    append_commit_message_to_run_name: ?bool = null,
    /// The build number/name of the build.
    build_number: ?[]const u8 = null,
    /// The build number revision.
    build_number_revision: ?i32 = null,
    controller: ?BuildController = null,
    definition: ?DefinitionReference = null,
    /// Indicates whether the build has been deleted.
    deleted: ?bool = null,
    deleted_by: ?IdentityRef = null,
    /// The date the build was deleted.
    deleted_date: ?[]const u8 = null,
    /// The description of how the build was deleted.
    deleted_reason: ?[]const u8 = null,
    /// A list of demands that represents the agent capabilities required by this build.
    demands: ?[]const Demand = null,
    /// The time that the build was completed.
    finish_time: ?[]const u8 = null,
    /// The ID of the build.
    id: ?i32 = null,
    last_changed_by: ?IdentityRef = null,
    /// The date the build was last changed.
    last_changed_date: ?[]const u8 = null,
    logs: ?BuildLogReference = null,
    orchestration_plan: ?TaskOrchestrationPlanReference = null,
    /// The parameters for the build.
    parameters: ?[]const u8 = null,
    /// Orchestration plans associated with the build (build, cleanup)
    plans: ?[]const TaskOrchestrationPlanReference = null,
    /// Azure Pipelines does not support job priority. This field is deprecated.
    priority: ?enums.BuildPriority = null,
    project: ?TeamProjectReference = null,
    properties: ?PropertiesCollection = null,
    /// The quality of the xaml build (good, bad, etc.)
    quality: ?[]const u8 = null,
    queue: ?AgentPoolQueue = null,
    /// Additional options for queueing the build.
    queue_options: ?enums.BuildQueueOptions = null,
    /// The current position of the build in the queue.
    queue_position: ?i32 = null,
    /// The time that the build was queued.
    queue_time: ?[]const u8 = null,
    /// The reason that the build was created.
    reason: ?enums.BuildReason = null,
    repository: ?BuildRepository = null,
    requested_by: ?IdentityRef = null,
    requested_for: ?IdentityRef = null,
    /// The build result.
    result: ?enums.BuildResult = null,
    /// Indicates whether the build is retained by a release.
    retained_by_release: ?bool = null,
    /// The source branch.
    source_branch: ?[]const u8 = null,
    /// The source version.
    source_version: ?[]const u8 = null,
    /// The time that the build was started.
    start_time: ?[]const u8 = null,
    /// The status of the build.
    status: ?enums.BuildStatus = null,
    tags: ?[]const []const u8 = null,
    /// Parameters to template expression evaluation
    template_parameters: ?std.json.ArrayHashMap([]const u8) = null,
    triggered_by_build: ?*const Build = null,
    /// Sourceprovider-specific information about what triggered the build
    trigger_info: ?std.json.ArrayHashMap([]const u8) = null,
    /// The URI of the build.
    uri: ?[]const u8 = null,
    /// The REST URL of the build.
    url: ?[]const u8 = null,
    validation_results: ?[]const BuildRequestValidationResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Specification of the agent defined by the pool provider.
pub const AgentSpecification = struct {
    /// Agent specification unique identifier.
    identifier: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a reference to a definition.
pub const DefinitionReference = struct {
    /// The date this version of the definition was created.
    created_date: ?[]const u8 = null,
    /// The ID of the referenced definition.
    id: ?i32 = null,
    /// The name of the referenced definition.
    name: ?[]const u8 = null,
    /// The folder path of the definition.
    path: ?[]const u8 = null,
    project: ?TeamProjectReference = null,
    /// A value that indicates whether builds can be queued against this definition.
    queue_status: ?enums.DefinitionReferenceQueueStatus = null,
    /// The definition revision number.
    revision: ?i32 = null,
    /// The type of the definition.
    type: ?enums.DefinitionReferenceType = null,
    /// The definition's URI.
    uri: ?[]const u8 = null,
    /// The REST URL of the definition.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a shallow reference to a TeamProject.
pub const TeamProjectReference = struct {
    /// Project abbreviation.
    abbreviation: ?[]const u8 = null,
    /// Url to default team identity image.
    default_team_image_url: ?[]const u8 = null,
    /// The project's description (if any).
    description: ?[]const u8 = null,
    /// Project identifier.
    id: ?[]const u8 = null,
    /// Project last update time.
    last_update_time: ?[]const u8 = null,
    /// Project name.
    name: ?[]const u8 = null,
    /// Project revision.
    revision: ?i64 = null,
    /// Project state.
    state: ?enums.TeamProjectReferenceState = null,
    /// Url to the full version of the object.
    url: ?[]const u8 = null,
    /// Project visibility.
    visibility: ?enums.TeamProjectReferenceVisibility = null,

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

/// Represents a demand used by a definition or build.
pub const Demand = struct {
    /// The name of the capability referenced by the demand.
    name: ?[]const u8 = null,
    /// The demanded value.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a reference to a build log.
pub const BuildLogReference = struct {
    /// The ID of the log.
    id: ?i32 = null,
    /// The type of the log location.
    type: ?[]const u8 = null,
    /// A full link to the log resource.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a reference to an orchestration plan.
pub const TaskOrchestrationPlanReference = struct {
    /// The type of the plan.
    orchestration_type: ?i32 = null,
    /// The ID of the plan.
    plan_id: ?[]const u8 = null,

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

/// Represents a queue for running builds.
pub const AgentPoolQueue = struct {
    links: ?ReferenceLinks = null,
    /// The ID of the queue.
    id: ?i32 = null,
    /// The name of the queue.
    name: ?[]const u8 = null,
    pool: ?TaskAgentPoolReference = null,
    /// The full http link to the resource.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents a reference to an agent pool.
pub const TaskAgentPoolReference = struct {
    /// The pool ID.
    id: ?i32 = null,
    /// A value indicating whether or not this pool is managed by the service.
    is_hosted: ?bool = null,
    /// The pool name.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a repository used by a build definition.
pub const BuildRepository = struct {
    /// Indicates whether to checkout submodules.
    checkout_submodules: ?bool = null,
    /// Indicates whether to clean the target folder when getting code from the repository.
    clean: ?[]const u8 = null,
    /// The name of the default branch.
    default_branch: ?[]const u8 = null,
    /// The ID of the repository.
    id: ?[]const u8 = null,
    /// The friendly name of the repository.
    name: ?[]const u8 = null,
    properties: ?std.json.ArrayHashMap([]const u8) = null,
    /// The root folder.
    root_folder: ?[]const u8 = null,
    /// The type of the repository.
    type: ?[]const u8 = null,
    /// The URL of the repository.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the result of validating a build request.
pub const BuildRequestValidationResult = struct {
    /// The message associated with the result.
    message: ?[]const u8 = null,
    /// The result.
    result: ?enums.BuildRequestValidationResultResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a change associated with a build.
pub const Change = struct {
    author: ?IdentityRef = null,
    /// The location of a user-friendly representation of the resource.
    display_uri: ?[]const u8 = null,
    /// The identifier for the change. For a commit, this would be the SHA1. For a TFVC changeset, this would be the changeset ID.
    id: ?[]const u8 = null,
    /// The location of the full representation of the resource.
    location: ?[]const u8 = null,
    /// The description of the change. This might be a commit message or changeset description.
    message: ?[]const u8 = null,
    /// Indicates whether the message was truncated.
    message_truncated: ?bool = null,
    /// The person or process that pushed the change.
    pusher: ?[]const u8 = null,
    /// The timestamp for the change.
    timestamp: ?[]const u8 = null,
    /// The type of change. 'commit', 'changeset', etc.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A valid retention lease prevents automated systems from deleting a pipeline run.
pub const RetentionLease = struct {
    /// When the lease was created.
    created_on: ?[]const u8 = null,
    /// The pipeline definition of the run.
    definition_id: ?i32 = null,
    /// The unique identifier for this lease.
    lease_id: ?i32 = null,
    /// Non-unique string that identifies the owner of a retention lease.
    owner_id: ?[]const u8 = null,
    /// If set, this lease will also prevent the pipeline from being deleted while the lease is still valid.
    protect_pipeline: ?bool = null,
    /// The pipeline run protected by this lease.
    run_id: ?i32 = null,
    /// The last day the lease is considered valid.
    valid_until: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a build log.
pub const BuildLog = struct {
    /// The ID of the log.
    id: ?i32 = null,
    /// The type of the log location.
    type: ?[]const u8 = null,
    /// A full link to the log resource.
    url: ?[]const u8 = null,
    /// The date and time the log was created.
    created_on: ?[]const u8 = null,
    /// The date and time the log was last changed.
    last_changed_on: ?[]const u8 = null,
    /// The number of lines in the log.
    line_count: ?i64 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ResourceRef = struct {
    id: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an attachment to a build.
pub const Attachment = struct {
    links: ?ReferenceLinks = null,
    /// The name of the attachment.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents an artifact produced by a build.
pub const BuildArtifact = struct {
    /// The artifact ID.
    id: ?i32 = null,
    /// The name of the artifact.
    name: ?[]const u8 = null,
    resource: ?ArtifactResource = null,
    /// The artifact source, which will be the ID of the job that produced this artifact. If an artifact is associated with multiple sources, this points to the first source.
    source: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ArtifactResource = struct {
    links: ?ReferenceLinks = null,
    /// Type-specific data about the artifact.
    data: ?[]const u8 = null,
    /// A link to download the resource.
    download_url: ?[]const u8 = null,
    /// Type-specific properties of the artifact.
    properties: ?std.json.ArrayHashMap([]const u8) = null,
    /// The type of the resource: File container, version control folder, UNC path, etc.
    type: ?[]const u8 = null,
    /// The full http link to the resource.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The JSON model for JSON Patch Operations
pub const JsonPatchDocument = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents information about a build report.
pub const BuildReportMetadata = struct {
    /// The Id of the build.
    build_id: ?i32 = null,
    /// The content of the report.
    content: ?[]const u8 = null,
    /// The type of the report.
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpdateStageParameters = struct {
    force_retry_all_jobs: ?bool = null,
    retry_dependencies: ?bool = null,
    state: ?enums.UpdateStageParametersState = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpdateTagParameters = struct {
    tags_to_add: ?[]const []const u8 = null,
    tags_to_remove: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the timeline of a build.
pub const Timeline = struct {
    /// The change ID.
    change_id: ?i32 = null,
    /// The ID of the timeline.
    id: ?[]const u8 = null,
    /// The REST URL of the timeline.
    url: ?[]const u8 = null,
    /// The process or person that last changed the timeline.
    last_changed_by: ?[]const u8 = null,
    /// The time the timeline was last changed.
    last_changed_on: ?[]const u8 = null,
    records: ?[]const TimelineRecord = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an entry in a build's timeline.
pub const TimelineRecord = struct {
    links: ?ReferenceLinks = null,
    /// Attempt number of record.
    attempt: ?i32 = null,
    /// The change ID.
    change_id: ?i32 = null,
    /// A string that indicates the current operation.
    current_operation: ?[]const u8 = null,
    details: ?TimelineReference = null,
    /// The number of errors produced by this operation.
    error_count: ?i32 = null,
    /// The finish time.
    finish_time: ?[]const u8 = null,
    /// The ID of the record.
    id: ?[]const u8 = null,
    /// String identifier that is consistent across attempts.
    identifier: ?[]const u8 = null,
    issues: ?[]const Issue = null,
    /// The time the record was last modified.
    last_modified: ?[]const u8 = null,
    log: ?BuildLogReference = null,
    /// The name.
    name: ?[]const u8 = null,
    /// An ordinal value relative to other records.
    order: ?i32 = null,
    /// The ID of the record's parent.
    parent_id: ?[]const u8 = null,
    /// The current completion percentage.
    percent_complete: ?i32 = null,
    previous_attempts: ?[]const TimelineAttempt = null,
    /// The queue ID of the queue that the operation ran on.
    queue_id: ?i32 = null,
    /// The ref name
    ref_name: ?[]const u8 = null,
    /// The result.
    result: ?enums.TimelineRecordResult = null,
    /// The result code.
    result_code: ?[]const u8 = null,
    /// The start time.
    start_time: ?[]const u8 = null,
    /// The state of the record.
    state: ?enums.TimelineRecordState = null,
    task: ?TaskReference = null,
    /// The type of the record.
    type: ?[]const u8 = null,
    /// The REST URL of the timeline record.
    url: ?[]const u8 = null,
    /// The number of warnings produced by this operation.
    warning_count: ?i32 = null,
    /// The name of the agent running the operation.
    worker_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents a reference to a timeline.
pub const TimelineReference = struct {
    /// The change ID.
    change_id: ?i32 = null,
    /// The ID of the timeline.
    id: ?[]const u8 = null,
    /// The REST URL of the timeline.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an issue (error, warning) associated with a build.
pub const Issue = struct {
    /// The category.
    category: ?[]const u8 = null,
    data: ?std.json.ArrayHashMap([]const u8) = null,
    /// A description of the issue.
    message: ?[]const u8 = null,
    /// The type (error, warning) of the issue.
    type: ?enums.IssueType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TimelineAttempt = struct {
    /// Gets or sets the attempt of the record.
    attempt: ?i32 = null,
    /// Gets or sets the record identifier located within the specified timeline.
    record_id: ?[]const u8 = null,
    /// Gets or sets the timeline identifier which owns the record representing this attempt.
    timeline_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a reference to a task.
pub const TaskReference = struct {
    /// The ID of the task definition.
    id: ?[]const u8 = null,
    /// The name of the task definition.
    name: ?[]const u8 = null,
    /// The version of the task definition.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a reference to a build definition.
pub const BuildDefinitionReference = struct {
    /// The date this version of the definition was created.
    created_date: ?[]const u8 = null,
    /// The ID of the referenced definition.
    id: ?i32 = null,
    /// The name of the referenced definition.
    name: ?[]const u8 = null,
    /// The folder path of the definition.
    path: ?[]const u8 = null,
    project: ?TeamProjectReference = null,
    /// A value that indicates whether builds can be queued against this definition.
    queue_status: ?enums.DefinitionReferenceQueueStatus = null,
    /// The definition revision number.
    revision: ?i32 = null,
    /// The type of the definition.
    type: ?enums.DefinitionReferenceType = null,
    /// The definition's URI.
    uri: ?[]const u8 = null,
    /// The REST URL of the definition.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    authored_by: ?IdentityRef = null,
    draft_of: ?DefinitionReference = null,
    /// The list of drafts associated with this definition, if this is not a draft definition.
    drafts: ?[]const DefinitionReference = null,
    latest_build: ?Build = null,
    latest_completed_build: ?Build = null,
    metrics: ?[]const BuildMetric = null,
    /// The quality of the definition document (draft, etc.)
    quality: ?enums.BuildDefinitionReferenceQuality = null,
    queue: ?AgentPoolQueue = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents metadata about builds in the system.
pub const BuildMetric = struct {
    /// The date for the scope.
    date: ?[]const u8 = null,
    /// The value.
    int_value: ?i32 = null,
    /// The name of the metric.
    name: ?[]const u8 = null,
    /// The scope.
    scope: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a build definition.
pub const BuildDefinition = struct {
    /// The date this version of the definition was created.
    created_date: ?[]const u8 = null,
    /// The ID of the referenced definition.
    id: ?i32 = null,
    /// The name of the referenced definition.
    name: ?[]const u8 = null,
    /// The folder path of the definition.
    path: ?[]const u8 = null,
    project: ?TeamProjectReference = null,
    /// A value that indicates whether builds can be queued against this definition.
    queue_status: ?enums.DefinitionReferenceQueueStatus = null,
    /// The definition revision number.
    revision: ?i32 = null,
    /// The type of the definition.
    type: ?enums.DefinitionReferenceType = null,
    /// The definition's URI.
    uri: ?[]const u8 = null,
    /// The REST URL of the definition.
    url: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    authored_by: ?IdentityRef = null,
    draft_of: ?DefinitionReference = null,
    /// The list of drafts associated with this definition, if this is not a draft definition.
    drafts: ?[]const DefinitionReference = null,
    latest_build: ?Build = null,
    latest_completed_build: ?Build = null,
    metrics: ?[]const BuildMetric = null,
    /// The quality of the definition document (draft, etc.)
    quality: ?enums.BuildDefinitionReferenceQuality = null,
    queue: ?AgentPoolQueue = null,
    /// Indicates whether badges are enabled for this definition.
    badge_enabled: ?bool = null,
    /// The build number format.
    build_number_format: ?[]const u8 = null,
    /// A save-time comment for the definition.
    comment: ?[]const u8 = null,
    demands: ?[]const Demand = null,
    /// The description.
    description: ?[]const u8 = null,
    /// The drop location for the definition.
    drop_location: ?[]const u8 = null,
    /// The job authorization scope for builds queued against this definition.
    job_authorization_scope: ?enums.BuildDefinitionJobAuthorizationScope = null,
    /// The job cancel timeout (in minutes) for builds cancelled by user for this definition.
    job_cancel_timeout_in_minutes: ?i32 = null,
    /// The job execution timeout (in minutes) for builds queued against this definition.
    job_timeout_in_minutes: ?i32 = null,
    options: ?[]const BuildOption = null,
    process: ?BuildProcess = null,
    process_parameters: ?ProcessParameters = null,
    properties: ?PropertiesCollection = null,
    repository: ?BuildRepository = null,
    retention_rules: ?[]const RetentionPolicy = null,
    tags: ?[]const []const u8 = null,
    triggers: ?[]const BuildTrigger = null,
    variable_groups: ?[]const VariableGroup = null,
    variables: ?std.json.ArrayHashMap(BuildDefinitionVariable) = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents the application of an optional behavior to a build definition.
pub const BuildOption = struct {
    definition: ?BuildOptionDefinitionReference = null,
    /// Indicates whether the behavior is enabled.
    enabled: ?bool = null,
    inputs: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a reference to a build option definition.
pub const BuildOptionDefinitionReference = struct {
    /// The ID of the referenced build option.
    id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a build process.
pub const BuildProcess = struct {
    /// The type of the process.
    type: ?i32 = null,

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

/// Represents a retention policy for a build definition.
pub const RetentionPolicy = struct {
    artifacts: ?[]const []const u8 = null,
    artifact_types_to_delete: ?[]const []const u8 = null,
    branches: ?[]const []const u8 = null,
    /// The number of days to keep builds.
    days_to_keep: ?i32 = null,
    /// Indicates whether the build record itself should be deleted.
    delete_build_record: ?bool = null,
    /// Indicates whether to delete test results associated with the build.
    delete_test_results: ?bool = null,
    /// The minimum number of builds to keep.
    minimum_to_keep: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a trigger for a buld definition.
pub const BuildTrigger = struct {
    /// The type of the trigger.
    trigger_type: ?enums.BuildTriggerTriggerType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a variable group.
pub const VariableGroup = struct {
    /// The Name of the variable group.
    alias: ?[]const u8 = null,
    /// The ID of the variable group.
    id: ?i32 = null,
    /// The description.
    description: ?[]const u8 = null,
    /// The name of the variable group.
    name: ?[]const u8 = null,
    /// The type of the variable group.
    type: ?[]const u8 = null,
    variables: ?std.json.ArrayHashMap(BuildDefinitionVariable) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a variable used by a build definition.
pub const BuildDefinitionVariable = struct {
    /// Indicates whether the value can be set at queue time.
    allow_override: ?bool = null,
    /// Indicates whether the variable's value is a secret.
    is_secret: ?bool = null,
    /// The value of the variable.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a revision of a build definition.
pub const BuildDefinitionRevision = struct {
    changed_by: ?IdentityRef = null,
    /// The date and time that the definition was changed.
    changed_date: ?[]const u8 = null,
    /// The change type (add, edit, delete).
    change_type: ?enums.BuildDefinitionRevisionChangeType = null,
    /// The comment associated with the change.
    comment: ?[]const u8 = null,
    /// A link to the definition at this revision.
    definition_url: ?[]const u8 = null,
    /// The name of the definition.
    name: ?[]const u8 = null,
    /// The revision number.
    revision: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a yaml build.
pub const YamlBuild = struct {
    /// The yaml used to define the build
    yaml: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a template from which new build definitions can be created.
pub const BuildDefinitionTemplate = struct {
    /// Indicates whether the template can be deleted.
    can_delete: ?bool = null,
    /// The template category.
    category: ?[]const u8 = null,
    /// An optional hosted agent queue for the template to use by default.
    default_hosted_queue: ?[]const u8 = null,
    /// A description of the template.
    description: ?[]const u8 = null,
    icons: ?std.json.ArrayHashMap([]const u8) = null,
    /// The ID of the task whose icon is used when showing this template in the UI.
    icon_task_id: ?[]const u8 = null,
    /// The ID of the template.
    id: ?[]const u8 = null,
    /// The name of the template.
    name: ?[]const u8 = null,
    template: ?BuildDefinition = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a folder that contains build definitions.
pub const Folder = struct {
    created_by: ?IdentityRef = null,
    /// The date the folder was created.
    created_on: ?[]const u8 = null,
    /// The description.
    description: ?[]const u8 = null,
    last_changed_by: ?IdentityRef = null,
    /// The date the folder was last changed.
    last_changed_date: ?[]const u8 = null,
    /// The full path.
    path: ?[]const u8 = null,
    project: ?TeamProjectReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contains pipeline general settings.
pub const PipelineGeneralSettings = struct {
    /// If enabled, audit logs will be generated whenever someone queues a pipeline run and defines variables that are not marked as 'Settable at queue time'.
    audit_enforce_settable_var: ?bool = null,
    /// Enable forked repositories to build pull requests.
    builds_enabled_for_forks: ?bool = null,
    /// Disable classic build pipelines creation.
    disable_classic_build_pipeline_creation: ?bool = null,
    /// Disable classic pipelines creation.
    disable_classic_pipeline_creation: ?bool = null,
    /// Disable classic release pipelines creation.
    disable_classic_release_pipeline_creation: ?bool = null,
    /// Disable implied pipeline CI triggers if the trigger section in YAML is missing.
    disable_implied_yaml_ci_trigger: ?bool = null,
    /// Enable shell tasks args sanitizing.
    enable_shell_tasks_args_sanitizing: ?bool = null,
    /// Enable shell tasks args sanitizing preview.
    enable_shell_tasks_args_sanitizing_audit: ?bool = null,
    /// If enabled, scope of access for all non-release pipelines reduces to the current project.
    enforce_job_auth_scope: ?bool = null,
    /// Enforce job auth scope for builds of forked repositories.
    enforce_job_auth_scope_for_forks: ?bool = null,
    /// If enabled, scope of access for all release pipelines reduces to the current project.
    enforce_job_auth_scope_for_releases: ?bool = null,
    /// Enforce no access to secrets for builds of forked repositories.
    enforce_no_access_to_secrets_from_forks: ?bool = null,
    /// Restricts the scope of GitHub access for all pipelines to only GitHub repositories explicitly referenced by the pipeline.
    enforce_referenced_git_hub_repo_scoped_token: ?bool = null,
    /// Restricts the scope of access for all pipelines to only repositories explicitly referenced by the pipeline.
    enforce_referenced_repo_scoped_token: ?bool = null,
    /// If enabled, only those variables that are explicitly marked as 'Settable at queue time' can be set at queue time.
    enforce_settable_var: ?bool = null,
    /// Enable settings that enforce certain levels of protection for building pull requests from forks globally.
    fork_protection_enabled: ?bool = null,
    /// Make comments required to have builds in all pull requests.
    is_comment_required_for_pull_request: ?bool = null,
    /// Allows pipelines to record metadata.
    publish_pipeline_metadata: ?bool = null,
    /// Make comments required to have builds in pull requests from non-team members and non-contributors.
    require_comments_for_non_team_member_and_non_contributors: ?bool = null,
    /// Make comments required to have builds in pull requests from non-team members.
    require_comments_for_non_team_members_only: ?bool = null,
    /// Anonymous users can access the status badge API for all pipelines unless this option is enabled.
    status_badges_are_private: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .disable_implied_yaml_ci_trigger = "disableImpliedYAMLCiTrigger",
        },
    };
};

/// Represents an optional behavior that can be applied to a build definition.
pub const BuildOptionDefinition = struct {
    /// The ID of the referenced build option.
    id: ?[]const u8 = null,
    /// The description.
    description: ?[]const u8 = null,
    /// The list of input groups defined for the build option.
    groups: ?[]const BuildOptionGroupDefinition = null,
    /// The list of inputs defined for the build option.
    inputs: ?[]const BuildOptionInputDefinition = null,
    /// The name of the build option.
    name: ?[]const u8 = null,
    /// A value that indicates the relative order in which the behavior should be applied.
    ordinal: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a group of inputs for a build option.
pub const BuildOptionGroupDefinition = struct {
    /// The name of the group to display in the UI.
    display_name: ?[]const u8 = null,
    /// Indicates whether the group is initially displayed as expanded in the UI.
    is_expanded: ?bool = null,
    /// The internal name of the group.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an input for a build option.
pub const BuildOptionInputDefinition = struct {
    /// The default value.
    default_value: ?[]const u8 = null,
    /// The name of the input group that this input belongs to.
    group_name: ?[]const u8 = null,
    help: ?std.json.ArrayHashMap([]const u8) = null,
    /// The label for the input.
    label: ?[]const u8 = null,
    /// The name of the input.
    name: ?[]const u8 = null,
    options: ?std.json.ArrayHashMap([]const u8) = null,
    /// Indicates whether the input is required to have a value.
    required: ?bool = null,
    /// Indicates the type of the input value.
    type: ?enums.BuildOptionInputDefinitionType = null,
    /// The rule that is applied to determine whether the input is visible in the UI.
    visible_rule: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contains the settings for the retention rules.
pub const ProjectRetentionSetting = struct {
    purge_artifacts: ?RetentionSetting = null,
    purge_pull_request_runs: ?RetentionSetting = null,
    purge_runs: ?RetentionSetting = null,
    retain_runs_per_protected_branch: ?RetentionSetting = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contains the minimum, maximum, and current value for a retention setting.
pub const RetentionSetting = struct {
    max: ?i32 = null,
    min: ?i32 = null,
    value: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Contains members for updating the retention settings values. All fields are optional.
pub const UpdateProjectRetentionSettingModel = struct {
    artifacts_retention: ?UpdateRetentionSettingModel = null,
    pull_request_run_retention: ?UpdateRetentionSettingModel = null,
    retain_runs_per_protected_branch: ?UpdateRetentionSettingModel = null,
    run_retention: ?UpdateRetentionSettingModel = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpdateRetentionSettingModel = struct {
    value: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Required information to create a new retention lease.
pub const NewRetentionLease = struct {
    /// The number of days to consider the lease valid. A retention lease valid for more than 100 years (36500 days) will display as retaining the build 'forever'.
    days_valid: ?i32 = null,
    /// The pipeline definition of the run.
    definition_id: ?i32 = null,
    /// User-provided string that identifies the owner of a retention lease.
    owner_id: ?[]const u8 = null,
    /// If set, this lease will also prevent the pipeline from being deleted while the lease is still valid.
    protect_pipeline: ?bool = null,
    /// The pipeline run to protect.
    run_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An update to the retention parameters of a retention lease.
pub const RetentionLeaseUpdate = struct {
    /// The number of days to consider the lease valid. A retention lease valid for more than 100 years (36500 days) will display as retaining the build 'forever'.
    days_valid: ?i32 = null,
    /// If set, this lease will also prevent the pipeline from being deleted while the lease is still valid.
    protect_pipeline: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents system-wide build settings.
pub const BuildSettings = struct {
    /// The number of days to keep records of deleted builds.
    days_to_keep_deleted_builds_before_destroy: ?i32 = null,
    default_retention_policy: ?RetentionPolicy = null,
    maximum_retention_policy: ?RetentionPolicy = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SourceProviderAttributes = struct {
    /// The name of the source provider.
    name: ?[]const u8 = null,
    /// The capabilities supported by this source provider.
    supported_capabilities: ?std.json.ArrayHashMap(bool) = null,
    /// The types of triggers supported by this source provider.
    supported_triggers: ?[]const SupportedTrigger = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SupportedTrigger = struct {
    /// The default interval to wait between polls (only relevant when NotificationType is Polling).
    default_polling_interval: ?i32 = null,
    /// How the trigger is notified of changes.
    notification_type: ?[]const u8 = null,
    /// The capabilities supported by this trigger.
    supported_capabilities: ?std.json.ArrayHashMap(enums.SupportedTriggerSupportedCapability) = null,
    /// The type of trigger.
    type: ?enums.SupportedTriggerType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an item in a repository from a source provider.
pub const SourceRepositoryItem = struct {
    /// Whether the item is able to have sub-items (e.g., is a folder).
    is_container: ?bool = null,
    /// The full path of the item, relative to the root of the repository.
    path: ?[]const u8 = null,
    /// The type of the item (folder, file, etc).
    type: ?[]const u8 = null,
    /// The URL of the item.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a pull request object. These are retrieved from Source Providers.
pub const PullRequest = struct {
    links: ?ReferenceLinks = null,
    author: ?IdentityRef = null,
    /// Current state of the pull request, e.g. open, merged, closed, conflicts, etc.
    current_state: ?[]const u8 = null,
    /// Description for the pull request.
    description: ?[]const u8 = null,
    /// Returns if pull request is draft
    draft: ?bool = null,
    /// Unique identifier for the pull request
    id: ?[]const u8 = null,
    /// The name of the provider this pull request is associated with.
    provider_name: ?[]const u8 = null,
    /// Source branch ref of this pull request
    source_branch_ref: ?[]const u8 = null,
    /// Owner of the source repository of this pull request
    source_repository_owner: ?[]const u8 = null,
    /// Target branch ref of this pull request
    target_branch_ref: ?[]const u8 = null,
    /// Owner of the target repository of this pull request
    target_repository_owner: ?[]const u8 = null,
    /// Title of the pull request.
    title: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A set of repositories returned from the source provider.
pub const SourceRepositories = struct {
    /// A token used to continue this paged request; 'null' if the request is complete
    continuation_token: ?[]const u8 = null,
    /// The number of repositories requested for each page
    page_length: ?i32 = null,
    /// A list of repositories
    repositories: ?[]const SourceRepository = null,
    /// The total number of pages, or '-1' if unknown
    total_page_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a repository returned from a source provider.
pub const SourceRepository = struct {
    /// The name of the default branch.
    default_branch: ?[]const u8 = null,
    /// The full name of the repository.
    full_name: ?[]const u8 = null,
    /// The ID of the repository.
    id: ?[]const u8 = null,
    /// The friendly name of the repository.
    name: ?[]const u8 = null,
    properties: ?std.json.ArrayHashMap([]const u8) = null,
    /// The name of the source provider the repository is from.
    source_provider_name: ?[]const u8 = null,
    /// The URL of the repository.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a repository's webhook returned from a source provider.
pub const RepositoryWebhook = struct {
    /// The status of last delivery attempt for the webhook.
    last_delivery_status: ?i32 = null,
    /// The friendly name of the repository.
    name: ?[]const u8 = null,
    types: ?[]const enums.RepositoryWebhookType = null,
    /// The URL of the repository.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
