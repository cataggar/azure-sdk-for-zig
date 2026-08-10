//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `AdvancedFilter` as returned by Azure DevOps.
pub const AdvancedFilterList = struct {
    count: ?i32 = null,
    value: ?[]const AdvancedFilter = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents an advanced filter configuration for the Reporting dashboard.
pub const AdvancedFilter = struct {
    filter_criteria: ?CombinedAlertFilterCriteria = null,
    /// User-provided name for the advanced filter.
    name: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// The identity of the user who last changed the advanced filter.
    changed_by: ?[]const u8 = null,
    /// The date and time when the advanced filter was last changed.
    changed_date: ?[]const u8 = null,
    /// The identity of the user who created the advanced filter.
    created_by: ?[]const u8 = null,
    created_by_identity: ?IdentityRef = null,
    /// The date and time when the advanced filter was created.
    created_date: ?[]const u8 = null,
    /// Unique identifier for the advanced filter.
    id: ?[]const u8 = null,
    /// Indicates whether the advanced filter has been soft-deleted.
    is_deleted: ?bool = null,
    /// The URL of the advanced filter.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const CombinedAlertFilterCriteria = struct {
    /// If provided, only return alerts of the specified alert type.
    alert_type: ?enums.CombinedAlertFilterCriteriaAlertType = null,
    /// If provided, only return alerts with the specified validity status.
    alert_validity_status: ?enums.CombinedAlertFilterCriteriaAlertValidityStatus = null,
    /// If provided, only return dependency alerts for the specified package names.
    component_names: ?[]const []const u8 = null,
    /// If provided, only return dependency alerts for the specified ecosystems (e.g., NuGet, Npm, Maven).
    component_types: ?[]const enums.CombinedAlertFilterCriteriaComponentType = null,
    /// If provided, only return alerts with one of the specified dismissal types (closure reasons). Applicable only when filtering for closed/dismissed alerts.
    dismissal_types: ?[]const enums.CombinedAlertFilterCriteriaDismissalType = null,
    /// If provided, only return alerts fixed on or before this date.
    fixed_date_end: ?[]const u8 = null,
    /// If provided, only return alerts fixed on or after this date.
    fixed_date_start: ?[]const u8 = null,
    /// If provided, only return alerts introduced on or before this date.
    introduced_date_end: ?[]const u8 = null,
    /// If provided, only return alerts introduced on or after this date.
    introduced_date_start: ?[]const u8 = null,
    /// If provided, only return alerts whose titles match this pattern.
    keywords: ?[]const u8 = null,
    /// If provided, only return alerts for projects whose names are in this list.
    projects: ?[]const []const u8 = null,
    /// If provided, only return alerts for repositories whose names are in this list.
    repositories: ?[]const []const u8 = null,
    /// If provided, only return alerts for repositories whose IDs (GitRepositoryId) are in this list.
    repository_ids: ?[]const []const u8 = null,
    /// If provided, only return code scanning alerts or secret alerts matching the specified rule names.
    rule_names: ?[]const []const u8 = null,
    /// If provided, only return secret alerts matching the specified secret types (rule friendly name or opaque ID).
    secret_types: ?[]const []const u8 = null,
    /// If provided, only return alerts with the specified severities. Otherwise, return alerts at any severity.
    severities: ?[]const enums.CombinedAlertFilterCriteriaSeverity = null,
    /// If provided, return alerts that are active or inactive based on this value. <br />Otherwise, return alerts in any state.
    state: ?enums.CombinedAlertFilterCriteriaState = null,
    /// If provided, only return code scanning alerts detected by the specified tools.
    tool_names: ?[]const []const u8 = null,

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

/// Represents the data required to create an advanced filter configuration for the Reporting dashboard. Also serves as the base class for AdvancedFilter.
pub const AdvancedFilterCreate = struct {
    filter_criteria: ?CombinedAlertFilterCriteria = null,
    /// User-provided name for the advanced filter.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the data required to update an advanced filter configuration. Only the name can be updated.
pub const AdvancedFilterUpdate = struct {
    /// The new name for the advanced filter.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Org Alert Summary.
pub const OrgAlertSummary = struct {
    /// Org Id.
    org_id: ?[]const u8 = null,
    /// A list of Project summary data.
    projects: ?[]const ProjectAlertSummary = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Project Alert Summary.
pub const ProjectAlertSummary = struct {
    /// Project Id.
    project_id: ?[]const u8 = null,
    /// Project Name.
    project_name: ?[]const u8 = null,
    /// A list of RepoAlertSummary data.
    repos: ?[]const RepoAlertSummary = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Repo Alert Summary.
pub const RepoAlertSummary = struct {
    alerts_by_severity: ?AlertSummaryBySeverity = null,
    alerts_by_state: ?AlertSummaryByState = null,
    /// Total active alerts in the repo.
    open_alerts: ?i32 = null,
    /// RepoId.
    repo_id: ?[]const u8 = null,
    /// Repo Name.
    repo_name: ?[]const u8 = null,
    /// Total active alerts in the repo.
    total_alerts: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Alert Summary by severity.
pub const AlertSummaryBySeverity = struct {
    /// Total Critical severity alerts.
    critical: ?i32 = null,
    /// Total High severity alerts.
    high: ?i32 = null,
    /// Total low severity alerts.
    low: ?i32 = null,
    /// Total Medium severity alerts.
    medium: ?i32 = null,
    /// Total Note severity alerts.
    note: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Alert Summary by state.
pub const AlertSummaryByState = struct {
    /// Total Dismissed state alerts.
    dismissed: ?i32 = null,
    /// Total Fixed state alerts.
    fixed: ?i32 = null,
    /// Total New state alerts.
    new: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `DashboardAlert` as returned by Azure DevOps.
pub const DashboardAlertList = struct {
    count: ?i32 = null,
    value: ?[]const DashboardAlert = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An alert entity used in the dashboard for combined alerts.
pub const DashboardAlert = struct {
    /// Identifier for the alert. It is unique within Azure DevOps organization.
    alert_id: ?i64 = null,
    /// Type of the alert. E.g. secret, code, etc.
    alert_type: ?enums.DashboardAlertAlertType = null,
    /// This value is computed and returned by the service. This value represents the first time the vulnerability was introduced.
    introduced_date: ?[]const u8 = null,
    /// This value is computed and returned by the service. It is a value based on the results from all analysis configurations. An example of a physical location is a file location.
    locations: ?[]const DashboardAlertPhysicalLocation = null,
    /// Name of the project where the alert was detected.
    project_name: ?[]const u8 = null,
    /// Name of the repository where the alert was detected.
    repository_name: ?[]const u8 = null,
    /// Severity of the alert.
    severity: ?enums.DashboardAlertSeverity = null,
    /// This value is computed and returned by the service. It is a value based on the results from all analysis configurations.
    state: ?enums.DashboardAlertState = null,
    /// Title will only be rendered as text and does not support markdown formatting. There is a maximum character limit of 256.
    title: ?[]const u8 = null,
    /// A truncated/obfuscated version of the secret pertaining to the alert (if applicable).
    truncated_secret: ?[]const u8 = null,
    /// Validity status of an alert. Currently, this is only applicable to secret alerts. In case of secret alerts, the validity status is computed by looking at the liveness results for validation fingerprints associated to an alert.
    validity_status: ?enums.DashboardAlertValidityStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Location in the source control system where the issue was found
pub const DashboardAlertPhysicalLocation = struct {
    alert_id: ?i64 = null,
    /// Path of the file where the issue was found
    file_path: ?[]const u8 = null,
    region: ?Region = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Region = struct {
    /// The column where the code snippet ends
    column_end: ?i32 = null,
    /// The column where the code snippet starts
    column_start: ?i32 = null,
    /// The line number where the code snippet ends
    line_end: ?i32 = null,
    /// The line number where the code snippet starts
    line_start: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Org Enablement Summary.
pub const OrgEnablementSummary = struct {
    /// Org Id.
    org_id: ?[]const u8 = null,
    /// A list of Project Enablement data.
    projects: ?[]const ProjectEnablementSummary = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Project Enablement Summary.
pub const ProjectEnablementSummary = struct {
    /// Project Id.
    project_id: ?[]const u8 = null,
    /// Project Name.
    project_name: ?[]const u8 = null,
    /// A list of RepoEnablementSummary data.
    repos: ?[]const RepoEnablementSummary = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Repo Enablement Summary.
pub const RepoEnablementSummary = struct {
    /// AdvSec is enabled for the repo.
    adv_sec_is_enabled: ?bool = null,
    /// Code Security plan is enabled for the repo. Only present for Azure Dev Ops orgs who had enabled Advanced security after billing sku split has went live.
    code_security_enabled: ?bool = null,
    /// RepoId.
    repo_id: ?[]const u8 = null,
    /// Repo Name.
    repo_name: ?[]const u8 = null,
    /// Repo scan type metadata for different scan types.
    scan_type_metadata: ?std.json.ArrayHashMap(ScanTypeSummaryMetadata) = null,
    /// Repo enablement summary for different scan types.
    scan_type_summary: ?std.json.ArrayHashMap(ScanTypeSummaryProperties) = null,
    /// Secret Protection plan is enabled for the repo. Only present for Azure Dev Ops orgs who had enabled Advanced security after billing sku split has went live.
    secret_protection_enabled: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Metadata for a scan type.
pub const ScanTypeSummaryMetadata = struct {
    /// The date and time of the last scan for the associated alert type/repo combination. Null if no scan has been performed.
    last_scan_date: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ScanTypeSummaryProperties = struct {
    alerts: ?ScanTypeSummaryPropertiesData = null,
    pr_alerts: ?ScanTypeSummaryPropertiesData = null,
    push_protection: ?ScanTypeSummaryPropertiesData = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ScanTypeSummaryPropertiesData = struct {
    /// Represents the state of the scan type summary property.
    enabled: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `Alert` as returned by Azure DevOps.
pub const AlertList = struct {
    count: ?i32 = null,
    value: ?[]const Alert = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Alert = struct {
    /// Additional properties of this alert.
    additional_properties: ?std.json.ArrayHashMap(AlertAdditionalProperty) = null,
    /// Identifier for the alert. It is unique within Azure DevOps organization.
    alert_id: ?i64 = null,
    /// Type of the alert. E.g. secret, code, etc.
    alert_type: ?enums.AlertAlertType = null,
    /// Confidence level of the alert.
    confidence: ?enums.AlertConfidence = null,
    dismissal: ?Dismissal = null,
    /// This value is computed and returned by the service. This value represents the first time the service has seen this issue reported in an analysis instance.
    first_seen_date: ?[]const u8 = null,
    /// This value is computed and returned by the service. If the issue is fixed, this value represents the time the service has seen this issue fixed in an analysis instance.
    fixed_date: ?[]const u8 = null,
    /// Reference to a git object, e.g. branch ref.
    git_ref: ?[]const u8 = null,
    /// Value indicates whether the alert comes from a SARIF uploaded by a trusted source.
    has_trusted_source_origin: ?bool = null,
    /// This value is computed and returned by the service. This value represents the first time the vulnerability was introduced.
    introduced_date: ?[]const u8 = null,
    /// Value indicates whether the alert can be auto-fixed by Copilot Autofix. True when the alert is a code scanning alert detected by CodeQL with a supported rule. Null when the value has not been computed for this code path.
    is_auto_fixable: ?bool = null,
    /// This value is computed and returned by the service. This value represents the last time the service has seen this issue reported in an analysis instance.
    last_seen_date: ?[]const u8 = null,
    /// Logical locations for the alert. This value is computed and returned by the service. It is a value based on the results from all analysis configurations. An example of a logical location is a component.
    logical_locations: ?[]const LogicalLocation = null,
    /// This value is computed and returned by the service. It is a value based on the results from all analysis configurations. An example of a physical location is a file location.
    physical_locations: ?[]const PhysicalLocation = null,
    /// Identifier of the project where the alert was detected.
    project_id: ?[]const u8 = null,
    /// Relations between alerts and other artifacts.
    relations: ?[]const RelationMetadata = null,
    /// Identifier of the repository where the alert was detected.
    repository_id: ?[]const u8 = null,
    /// Repository URL where the alert was detected.
    repository_url: ?[]const u8 = null,
    /// Severity of the alert.
    severity: ?enums.AlertSeverity = null,
    /// This value is computed and returned by the service. It is a value based on the results from all analysis configurations.
    state: ?enums.AlertState = null,
    /// Title will only be rendered as text and does not support markdown formatting. There is a maximum character limit of 256.
    title: ?[]const u8 = null,
    /// Tools that have detected this issue.
    tools: ?[]const Tool = null,
    /// A truncated/obfuscated version of the secret pertaining to the alert (if applicable).
    truncated_secret: ?[]const u8 = null,
    /// ValidationFingerprints for the secret liveness check. Only returned on demand in Get API with Expand parameter set to be ValidationFingerprint (not returned in List API)
    validation_fingerprints: ?[]const ValidationFingerprint = null,
    validity_details: ?AlertValidityInfo = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AlertAdditionalProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information about an alert dismissal
pub const Dismissal = struct {
    /// Unique ID for this dismissal
    dismissal_id: ?i64 = null,
    /// Reason for the dismissal
    dismissal_type: ?enums.DismissalDismissalType = null,
    /// Informational message attached to the dismissal
    message: ?[]const u8 = null,
    /// Identity that dismissed the alert
    state_changed_by: ?[]const u8 = null,
    state_changed_by_identity: ?IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const LogicalLocation = struct {
    fully_qualified_name: ?[]const u8 = null,
    /// Dependency kind of this logical location.
    kind: ?enums.LogicalLocationKind = null,
    license: ?License = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// License information for dependencies
pub const License = struct {
    /// License name
    name: ?[]const u8 = null,
    /// License state
    state: ?enums.LicenseState = null,
    /// License type
    type: ?enums.LicenseType = null,
    /// Url for license information
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Location in the source control system where the issue was found
pub const PhysicalLocation = struct {
    /// Additional properties for where the issue was found
    additional_properties: ?std.json.ArrayHashMap(PhysicalLocationAdditionalProperty) = null,
    /// Path of the file where the issue was found
    file_path: ?[]const u8 = null,
    /// Indicates whether the path is a valid Git path that exists in the git repository associated with the alert.
    is_valid_git_path: ?bool = null,
    region: ?Region = null,
    version_control: ?VersionControlDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PhysicalLocationAdditionalProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information for locating files in a source control system
pub const VersionControlDetails = struct {
    commit_hash: ?[]const u8 = null,
    item_url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The metadata to be associated with the alert.
pub const RelationMetadata = struct {
    /// Any additional attributes of the metadata.
    attributes: ?std.json.ArrayHashMap(RelationMetadataAttribute) = null,
    /// The properties of the metadata.
    properties: ?std.json.ArrayHashMap(RelationMetadataProperty) = null,
    /// The type of the metadata.
    rel: ?[]const u8 = null,
    /// The URL of the metadata.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RelationMetadataAttribute = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RelationMetadataProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An Analysis tool that can generate security alerts
pub const Tool = struct {
    /// Name of the tool
    name: ?[]const u8 = null,
    /// The rules that the tool defines
    rules: ?[]const Rule = null,
    /// String representation of the tool version
    tool_version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The analysis rule that caused the alert.
pub const Rule = struct {
    /// Additional properties of this rule dependent on the rule type. For example, dependency rules may include the CVE ID if it is available.
    additional_properties: ?std.json.ArrayHashMap(RuleAdditionalProperty) = null,
    /// Description of what this rule detects
    description: ?[]const u8 = null,
    /// Plain-text rule identifier
    friendly_name: ?[]const u8 = null,
    /// Additional information about this rule
    help_message: ?[]const u8 = null,
    /// Tool-specific rule identifier
    opaque_id: ?[]const u8 = null,
    /// Markdown-formatted list of resources to learn more about the Rule. In some cases, RuleInfo.AdditionalProperties.advisoryUrls is used instead.
    resources: ?[]const u8 = null,
    /// Classification tags for this rule
    tags: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RuleAdditionalProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ValidationFingerprint = struct {
    /// The key value representation of the asset fingerprint.
    asset_fingerprint: ?std.json.ArrayHashMap([]const u8) = null,
    /// Represents the CrossCompanyCorrelatingId for the secret in the ValidationFingerprintJson.
    c3_id: ?[]const u8 = null,
    /// A normalized string representation of the validation tool version.
    normalized_validation_tool_version: ?i32 = null,
    /// The hash associated to the secret.
    validation_fingerprint_hash: ?[]const u8 = null,
    /// The JSON representation of the secret. Be aware that this field may contain the secret in its unencrypted form. Please exercise caution when using this field.
    validation_fingerprint_json: ?[]const u8 = null,
    /// The date when the validity was last updated.
    validity_last_updated_date: ?[]const u8 = null,
    /// The result of the validation.
    validity_result: ?enums.ValidationFingerprintValidityResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Validity data for an alert that will be part of Alerts APIs and UI.
pub const AlertValidityInfo = struct {
    validity_last_checked_date: ?[]const u8 = null,
    validity_status: ?enums.AlertValidityInfoValidityStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AlertStateUpdate = struct {
    dismissed_comment: ?[]const u8 = null,
    dismissed_reason: ?enums.AlertStateUpdateDismissedReason = null,
    state: ?enums.AlertStateUpdateState = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `AlertAnalysisInstance` as returned by Azure DevOps.
pub const AlertAnalysisInstanceList = struct {
    count: ?i32 = null,
    value: ?[]const AlertAnalysisInstance = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Summary of the state of the alert for a given analysis configuration.
pub const AlertAnalysisInstance = struct {
    analysis_configuration: ?AnalysisConfiguration = null,
    first_seen: ?AnalysisInstance = null,
    fixed_in: ?AnalysisInstance = null,
    last_seen: ?AnalysisInstance = null,
    recent_analysis_instance: ?AnalysisInstance = null,
    /// Result state for a given analysis configuration.
    state: ?enums.AlertAnalysisInstanceState = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// AnalysisConfiguration class models a build definition.
pub const AnalysisConfiguration = struct {
    analysis_configuration_details: ?AnalysisConfigurationDetails = null,
    /// Identifier for the analysis configuration.
    analysis_configuration_id: ?i32 = null,
    /// Type of the configuration.
    analysis_configuration_type: ?enums.AnalysisConfigurationAnalysisConfigurationType = null,
    /// Name of the tool that ran on this configuration.
    tool_name: ?[]const u8 = null,
    /// The latest version of the tool that ran on this configuration.
    tool_version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AnalysisConfigurationDetails = struct {
    /// Properties of the pipeline.
    additional_properties: ?std.json.ArrayHashMap(AnalysisConfigurationDetailsAdditionalProperty) = null,
    /// Reference to a git object, e.g. branch ref.
    git_ref: ?[]const u8 = null,
    /// Is this the default branch?
    is_default_branch: ?bool = null,
    /// Phase ID of the pipeline.
    phase_id: ?[]const u8 = null,
    /// Phase name.
    phase_name: ?[]const u8 = null,
    /// AzureDevOps pipeline id.
    pipeline_id: ?i32 = null,
    /// Name of the pipeline.
    pipeline_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AnalysisConfigurationDetailsAdditionalProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// AnalysisInstance class models a build.
pub const AnalysisInstance = struct {
    /// CommitId is a commit id for that instance
    commit_id: ?[]const u8 = null,
    configuration: ?AnalysisConfiguration = null,
    /// Date when the analysis was created.
    created_date: ?[]const u8 = null,
    /// InstanceIdentifier is a key that uniquely establishes this instance
    instance_identifier: ?[]const u8 = null,
    /// Results that were reported by the analysis.
    results: ?[]const AnalysisResult = null,
    /// Url is the permalink to the build.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AnalysisResult = struct {
    analysis_result_id: ?i64 = null,
    first_introduced_instance_id: ?i64 = null,
    fixed_instance_id: ?i64 = null,
    introduced_instance_id: ?i64 = null,
    last_seen_instance_id: ?i64 = null,
    result: ?Result = null,
    state: ?enums.AnalysisResultState = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Result = struct {
    dependency_result: ?DependencyResult = null,
    /// Full fingerprint of the Result. This is used to detect duplicate instances of the same alert
    fingerprint: ?[]const u8 = null,
    /// Unique ID of the fingerprint of the Result
    fingerprint_id: ?i64 = null,
    /// Unique ID of the Result
    result_id: ?i32 = null,
    /// Detailed description of the rule that triggered the alert
    result_message: ?[]const u8 = null,
    /// The type of rule that triggered the alert
    result_type: ?enums.ResultResultType = null,
    /// ID of the rule that the triggered the alert
    rule_id: ?i32 = null,
    /// Short description of the rule that triggered the alert
    rule_short_description: ?[]const u8 = null,
    /// The severity of the alert
    severity: ?enums.ResultSeverity = null,
    version_control_result: ?VersionControlResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An instance of a vulnerable dependency that was detected
pub const DependencyResult = struct {
    dependency: ?Dependency = null,
    /// Unique ID for this dependency
    dependency_result_id: ?i32 = null,
    /// ID for the Result that this instance belongs to
    result_id: ?i32 = null,
    /// Heirarchal information when multiple instances are found
    root_dependency_id: ?i32 = null,
    version_control_file_path: ?VersionControlFilePath = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information about a vulnerable dependency
pub const Dependency = struct {
    /// Dependency name
    component_name: ?[]const u8 = null,
    /// Source of the dependency
    component_type: ?enums.DependencyComponentType = null,
    /// Version information
    component_version: ?[]const u8 = null,
    /// Unique ID for the dependency
    dependency_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const VersionControlFilePath = struct {
    /// Path of the file in the version control system
    file_path: ?[]const u8 = null,
    /// Hash of the file in the version control system
    file_path_hash: ?[]const []const u8 = null,
    /// Unique ID for the file in the version control system
    version_control_file_path_id: ?i64 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const VersionControlResult = struct {
    /// The ID to associate this structure with the cooresponding Result
    result_id: ?i32 = null,
    version_control_snippet: ?VersionControlSnippet = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const VersionControlSnippet = struct {
    /// column in the code file where the snippet ends
    end_column: ?i32 = null,
    /// line in the code file where the snippet ends
    end_line: ?i32 = null,
    /// column in the code file where the snippet starts
    start_column: ?i32 = null,
    /// line in the code file where the snippet starts
    start_line: ?i32 = null,
    version_control_file_path: ?VersionControlFilePath = null,
    /// Unique Id number for the file path
    version_control_file_path_id: ?i64 = null,
    /// Unique Id number for this snippet
    version_control_snippet_id: ?i64 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Alert metadata.
pub const AlertMetadata = struct {
    /// The ID of the alert.
    alert_id: ?i64 = null,
    /// A list of metadata to be associated with the alert.
    metadata: ?[]const Metadata = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The metadata operation to be performed on the alert.
pub const Metadata = struct {
    /// The type of operation to be performed.
    op: ?enums.MetadataOp = null,
    value: ?RelationMetadata = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Alert metadata.
pub const AlertMetadataBatchRequest = struct {
    /// List of alert IDs.
    alert_ids: ?[]const i64 = null,
    /// The flag to control error policy in a bulk get work items request. Possible options are {Fail, Omit}.
    error_policy: ?enums.AlertMetadataBatchRequestErrorPolicy = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `AlertMetadata` as returned by Azure DevOps.
pub const AlertMetadataList = struct {
    count: ?i32 = null,
    value: ?[]const AlertMetadata = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Request model for getting alerts by IDs with optional alert type filter.
pub const AlertBatchRequest = struct {
    /// List of alert IDs to retrieve.
    alert_ids: ?[]const i64 = null,
    /// Alert type of the alert IDs.
    alert_type: ?enums.AlertBatchRequestAlertType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `Branch` as returned by Azure DevOps.
pub const BranchList = struct {
    count: ?i32 = null,
    value: ?[]const Branch = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const Branch = struct {
    branch_id: ?i32 = null,
    deleted_date: ?[]const u8 = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const OrgEnablementSettings = struct {
    code_security_features: ?CodeSecurityFeatures = null,
    enablement_on_create_settings: ?EnablementOnCreateSettings = null,
    /// A list of enablement statuses for repositories within the specified organization or project.
    repos_enablement_status: ?[]const RepoEnablementSettings = null,
    secret_protection_features: ?SecretProtectionFeatures = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CodeSecurityFeatures = struct {
    /// Copilot Autofix enablement status set to False when disabled and True when enabled; Null is never explicitly set. Setting Autofix enablement state is only supported for repo enablement and not org or project enablement at this time.
    autofix_enabled: ?bool = null,
    /// CodeQL default setup enablement status set to False when not using default setup and True when using default setup; Null is never explicitly set.
    code_ql_enabled: ?bool = null,
    /// The VSID of the last user who modified the enablement status of Code Security.
    code_security_changed_by: ?[]const u8 = null,
    /// Code Security enablement status set to False when disabled and True when enabled; Null is never explicitly set.
    code_security_enabled: ?bool = null,
    /// The last time the status of Code Security for this repository was updated
    code_security_enablement_last_changed_date: ?[]const u8 = null,
    /// Dependency Scanning Injection enablement status set to False when disabled and True when enabled; Null is never explicitly set. <br /> If Advanced Security is NOT already enabled, behavior will depend on if Advanced Security is to be enabled/disabled. DependencyScanningInjectionEnabled will not affect anything in this scenario. <br /> If Advanced Security is to be disabled, the value of DependencyScanningInjectionEnabled will have no effect.
    dependency_scanning_injection_enabled: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .code_ql_enabled = "codeQLEnabled",
        },
    };
};

pub const EnablementOnCreateSettings = struct {
    /// Automatically enable blocking of pushes that contain secrets when Secret Protection is auto-enabled. If EnableSecretProtectionOnCreate is not true this flag is ignored.
    enable_block_pushes_on_create: ?bool = null,
    /// Automatically enable CodeQL when Code Security is auto-enabled. If EnableCodeSecurityOnCreate is not true this flag is ignored.
    enable_code_ql_on_create: ?bool = null,
    /// Automatically enable Code Security on newly created repositories.
    enable_code_security_on_create: ?bool = null,
    /// Automatically enable Dependabot when Code Security is auto-enabled. If EnableCodeSecurityOnCreate is not true this flag is ignored.
    enable_dependabot_on_create: ?bool = null,
    /// Automatically enable Dependency Scanning Injection when Code Security is auto-enabled. If EnableCodeSecurityOnCreate is not true this flag is ignored.
    enable_dependency_scanning_injection_on_create: ?bool = null,
    /// Automatically enable Secret Protection on newly created repositories.
    enable_secret_protection_on_create: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .enable_code_ql_on_create = "enableCodeQLOnCreate",
        },
    };
};

pub const RepoEnablementSettings = struct {
    code_security_features: ?CodeSecurityFeatures = null,
    /// The project Id
    project_id: ?[]const u8 = null,
    /// The repository Id
    repository_id: ?[]const u8 = null,
    secret_protection_features: ?SecretProtectionFeatures = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SecretProtectionFeatures = struct {
    /// When true, pushes containing secrets will be blocked. <br />When false, pushes are scanned for secrets and are not blocked. <br />If includeAllProperties in the request is false, this value will be null.
    block_pushes: ?bool = null,
    /// The VSID of the last user who modified the enablement status of Secret Protection.
    secret_protection_changed_by: ?[]const u8 = null,
    /// Secret Protection enablement status set to False when disabled and True when enabled; Null is never explicitly set.
    secret_protection_enabled: ?bool = null,
    /// The last time the status of Secret Protection for this repository was updated
    secret_protection_enablement_last_changed_date: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information related to meter usage for a Scanning plan
pub const MeterUsageForPlan = struct {
    /// The Azure DevOps account
    account_id: ?[]const u8 = null,
    azure_subscription_id: ?[]const u8 = null,
    billed_users: ?BilledCommittersList = null,
    /// The date this billing information pertains to
    billing_date: ?[]const u8 = null,
    /// True when the Scanning plan is enabled in this organization
    is_plan_enabled: ?bool = null,
    /// The Azure subscription
    tenant_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A list of billed committers
pub const BilledCommittersList = struct {
    /// A list of BilledCommitter objects that contain the identityRef of committers.
    billed_users: ?[]const BilledCommitter = null,
    /// Count of billed committers in BilledUsers
    unique_committer_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information related to billed committers using Advanced Security services
pub const BilledCommitter = struct {
    /// Cuid of the billed committer. CUID is unique across an Azure Subscription.
    cuid: ?[]const u8 = null,
    user_identity: ?IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information related to meter usage estimate for Code Security plan and/or Secret Protection plan
pub const MeterUsageEstimate = struct {
    code_security_meter_usage_estimate: ?BilledCommittersList = null,
    secret_protection_meter_usage_estimate: ?BilledCommittersList = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProjectEnablementSettings = struct {
    code_security_features: ?CodeSecurityFeatures = null,
    enablement_on_create_settings: ?EnablementOnCreateSettings = null,
    /// A list of enablement statuses for repositories within the specified organization or project.
    repos_enablement_status: ?[]const RepoEnablementSettings = null,
    secret_protection_features: ?SecretProtectionFeatures = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
