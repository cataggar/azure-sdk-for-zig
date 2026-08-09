//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Definition of a pipeline.
pub const Pipeline = struct {
    /// Pipeline folder
    folder: ?[]const u8 = null,
    /// Pipeline ID
    id: ?i32 = null,
    /// Pipeline name
    name: ?[]const u8 = null,
    /// Revision number
    revision: ?i32 = null,
    links: ?ReferenceLinks = null,
    configuration: ?PipelineConfiguration = null,
    /// URL of the pipeline
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

pub const PipelineConfiguration = struct {
    type: ?enums.PipelineConfigurationType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters to create a pipeline.
pub const CreatePipelineParameters = struct {
    configuration: ?CreatePipelineConfigurationParameters = null,
    /// Folder of the pipeline.
    folder: ?[]const u8 = null,
    /// Name of the pipeline.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Configuration parameters of the pipeline.
pub const CreatePipelineConfigurationParameters = struct {
    /// Type of configuration.
    type: ?enums.CreatePipelineConfigurationParametersType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Settings which influence pipeline runs.
pub const RunPipelineParameters = struct {
    /// If true, don't actually create a new run. Instead, return the final YAML document after parsing templates.
    preview_run: ?bool = null,
    resources: ?RunResourcesParameters = null,
    stages_to_skip: ?[]const []const u8 = null,
    template_parameters: ?std.json.ArrayHashMap([]const u8) = null,
    variables: ?std.json.ArrayHashMap(Variable) = null,
    /// If you use the preview run option, you may optionally supply different YAML. This allows you to preview the final YAML document without committing a changed file.
    yaml_override: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RunResourcesParameters = struct {
    builds: ?std.json.ArrayHashMap(BuildResourceParameters) = null,
    containers: ?std.json.ArrayHashMap(ContainerResourceParameters) = null,
    packages: ?std.json.ArrayHashMap(PackageResourceParameters) = null,
    pipelines: ?std.json.ArrayHashMap(PipelineResourceParameters) = null,
    repositories: ?std.json.ArrayHashMap(RepositoryResourceParameters) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const BuildResourceParameters = struct {
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ContainerResourceParameters = struct {
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PackageResourceParameters = struct {
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PipelineResourceParameters = struct {
    run_id: ?i32 = null,
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RepositoryResourceParameters = struct {
    ref_name: ?[]const u8 = null,
    /// This is the security token to use when connecting to the repository.
    token: ?[]const u8 = null,
    /// Optional. This is the type of the token given. If not provided, a type of 'Bearer' is assumed. Note: Use 'Basic' for a PAT token.
    token_type: ?[]const u8 = null,
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Variable = struct {
    is_secret: ?bool = null,
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PreviewRun = struct {
    final_yaml: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Run = struct {
    id: ?i32 = null,
    name: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    created_date: ?[]const u8 = null,
    final_yaml: ?[]const u8 = null,
    finished_date: ?[]const u8 = null,
    pipeline: ?PipelineReference = null,
    resources: ?RunResources = null,
    result: ?enums.RunResult = null,
    state: ?enums.RunState = null,
    tags: ?[]const []const u8 = null,
    template_parameters: ?std.json.ArrayHashMap(RunTemplateParameter) = null,
    url: ?[]const u8 = null,
    variables: ?std.json.ArrayHashMap(Variable) = null,
    yaml_details: ?RunYamlDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A reference to a Pipeline.
pub const PipelineReference = struct {
    /// Pipeline folder
    folder: ?[]const u8 = null,
    /// Pipeline ID
    id: ?i32 = null,
    /// Pipeline name
    name: ?[]const u8 = null,
    /// Revision number
    revision: ?i32 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RunResources = struct {
    builds: ?std.json.ArrayHashMap(Build) = null,
    containers: ?std.json.ArrayHashMap(ContainerResource) = null,
    pipelines: ?std.json.ArrayHashMap(PipelineResource) = null,
    repositories: ?std.json.ArrayHashMap(RepositoryResource) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Build = struct {
    artifact_source_version_url: ?[]const u8 = null,
    type: ?[]const u8 = null,
    version_id: ?[]const u8 = null,
    version_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ContainerResource = struct {
    container: ?Container = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Container = struct {
    environment: ?std.json.ArrayHashMap([]const u8) = null,
    image: ?[]const u8 = null,
    map_docker_socket: ?bool = null,
    options: ?[]const u8 = null,
    ports: ?[]const []const u8 = null,
    volumes: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PipelineResource = struct {
    pipeline: ?PipelineReference = null,
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RepositoryResource = struct {
    ref_name: ?[]const u8 = null,
    repository: ?Repository = null,
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Repository = struct {
    type: ?enums.RepositoryType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RunTemplateParameter = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RunYamlDetails = struct {
    expanded_yaml_url: ?[]const u8 = null,
    extended_templates: ?[]const YamlFileDetails = null,
    included_templates: ?[]const YamlFileDetails = null,
    root_yaml_file: ?YamlFileDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const YamlFileDetails = struct {
    ref: ?[]const u8 = null,
    repo_alias: ?[]const u8 = null,
    yaml_file: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Artifacts are collections of files produced by a pipeline. Use artifacts to share files between stages in a pipeline or between different pipelines.
pub const Artifact = struct {
    /// The name of the artifact.
    name: ?[]const u8 = null,
    signed_content: ?SignedUrl = null,
    /// Self-referential url
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A signed url allowing limited-time anonymous access to private resources.
pub const SignedUrl = struct {
    /// Timestamp when access expires.
    signature_expires: ?[]const u8 = null,
    /// The URL to allow access to.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of logs.
pub const LogCollection = struct {
    /// The list of logs.
    logs: ?[]const Log = null,
    signed_content: ?SignedUrl = null,
    /// URL of the log.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Log for a pipeline.
pub const Log = struct {
    /// The date and time the log was created.
    created_on: ?[]const u8 = null,
    /// The ID of the log.
    id: ?i32 = null,
    /// The date and time the log was last changed.
    last_changed_on: ?[]const u8 = null,
    /// The number of lines in the log.
    line_count: ?i64 = null,
    signed_content: ?SignedUrl = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
