//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Represents the code coverage summary results Used to publish or retrieve code coverage summary against a build
pub const CodeCoverageSummary = struct {
    build: ?ShallowReference = null,
    /// List of coverage data and details for the build
    coverage_data: ?[]const CodeCoverageData = null,
    coverage_detailed_summary_status: ?enums.CodeCoverageSummaryCoverageDetailedSummaryStatus = null,
    delta_build: ?ShallowReference = null,
    /// Uri of build against which difference in coverage is computed
    status: ?enums.CodeCoverageSummaryStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An abstracted reference to some other resource. This class is used to provide the build data contracts with a uniform way to reference other resources in a way that provides easy traversal through links.
pub const ShallowReference = struct {
    /// ID of the resource
    id: ?[]const u8 = null,
    /// Name of the linked resource (definition name, controller name, etc.)
    name: ?[]const u8 = null,
    /// Full http link to the resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the build configuration (platform, flavor) and coverage data for the build
pub const CodeCoverageData = struct {
    /// Flavor of build for which data is retrieved/published
    build_flavor: ?[]const u8 = null,
    /// Platform of build for which data is retrieved/published
    build_platform: ?[]const u8 = null,
    /// List of coverage data for the build
    coverage_stats: ?[]const CodeCoverageStatistics = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the code coverage statistics for a particular coverage label (modules, statements, blocks, etc.)
pub const CodeCoverageStatistics = struct {
    /// Covered units
    covered: ?i32 = null,
    /// Delta of coverage
    delta: ?f64 = null,
    /// Is delta valid
    is_delta_available: ?bool = null,
    /// Label of coverage data ('Blocks', 'Statements', 'Modules', etc.)
    label: ?[]const u8 = null,
    /// Position of label
    position: ?i32 = null,
    /// Total units
    total: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `SourceViewBuildCoverage` as returned by Azure DevOps.
pub const SourceViewBuildCoverageList = struct {
    count: ?i32 = null,
    value: ?[]const SourceViewBuildCoverage = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SourceViewBuildCoverage = struct {
    configuration: ?BuildConfiguration = null,
    folder_coverage_data: ?FolderCoverageData = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// BuildConfiguration Details.
pub const BuildConfiguration = struct {
    /// Branch name for which build is generated.
    branch_name: ?[]const u8 = null,
    /// BuildDefinitionId for build.
    build_definition_id: ?i32 = null,
    /// Build system.
    build_system: ?[]const u8 = null,
    /// Build Creation Date.
    creation_date: ?[]const u8 = null,
    /// Build flavor (eg Build/Release).
    flavor: ?[]const u8 = null,
    /// BuildConfiguration Id.
    id: ?i32 = null,
    /// Build Number.
    number: ?[]const u8 = null,
    /// BuildConfiguration Platform.
    platform: ?[]const u8 = null,
    project: ?ShallowReference = null,
    /// Repository Guid for the Build.
    repository_guid: ?[]const u8 = null,
    /// Repository Type (eg. TFSGit).
    repository_type: ?[]const u8 = null,
    /// Source Version(/first commit) for the build was triggered.
    source_version: ?[]const u8 = null,
    /// Target BranchName.
    target_branch_name: ?[]const u8 = null,
    /// Build Uri.
    uri: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FolderCoverageData = struct {
    coverage_statistics: ?CoverageStatistics = null,
    files: ?[]const FileCoverageData = null,
    folders: ?[]const FolderCoverageData = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CoverageStatistics = struct {
    blocks_covered: ?i32 = null,
    blocks_not_covered: ?i32 = null,
    branches_covered: ?i32 = null,
    branches_not_covered: ?i32 = null,
    lines_covered: ?i32 = null,
    lines_not_covered: ?i32 = null,
    lines_partially_covered: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FileCoverageData = struct {
    coverage_statistics: ?CoverageStatistics = null,
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestRunCoverage` as returned by Azure DevOps.
pub const TestRunCoverageList = struct {
    count: ?i32 = null,
    value: ?[]const TestRunCoverage = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Run Code Coverage Details
pub const TestRunCoverage = struct {
    /// Last Error
    last_error: ?[]const u8 = null,
    /// List of Modules Coverage
    modules: ?[]const ModuleCoverage = null,
    /// State
    state: ?[]const u8 = null,
    test_run: ?ShallowReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ModuleCoverage = struct {
    block_count: ?i32 = null,
    block_data: ?[]const []const u8 = null,
    /// Code Coverage File Url
    file_url: ?[]const u8 = null,
    functions: ?[]const FunctionCoverage = null,
    name: ?[]const u8 = null,
    signature: ?[]const u8 = null,
    signature_age: ?i32 = null,
    statistics: ?CoverageStatistics = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FunctionCoverage = struct {
    class: ?[]const u8 = null,
    name: ?[]const u8 = null,
    namespace: ?[]const u8 = null,
    source_file: ?[]const u8 = null,
    statistics: ?CoverageStatistics = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FileCoverageRequest = struct {
    file_path: ?[]const u8 = null,
    pull_request_base_iteration_id: ?i32 = null,
    pull_request_id: ?i32 = null,
    pull_request_iteration_id: ?i32 = null,
    repo_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `CustomTestFieldDefinition` as returned by Azure DevOps.
pub const CustomTestFieldDefinitionList = struct {
    count: ?i32 = null,
    value: ?[]const CustomTestFieldDefinition = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data structure which stores details for the customTestFields to be updated
pub const CustomTestFieldDefinition = struct {
    /// ID assigned to the custom test field upon creation, should be left empty when creating.
    field_id: ?i32 = null,
    /// The name of custom field cannot be longer than 50 characters (spaces, numbers, and special characters are not allowed) and must be unique in the project. The names are case insensitive.
    field_name: ?[]const u8 = null,
    /// Data type of the customTestField.
    field_type: ?enums.CustomTestFieldDefinitionFieldType = null,
    /// Artifact to which customTestField will be set.
    scope: ?enums.CustomTestFieldDefinitionScope = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Data structure which stores details for the customTestField to be updated.
pub const CustomTestFieldUpdateDefinition = struct {
    /// Custom test field id which is to be updated.
    field_id: ?i32 = null,
    /// The name of custom field cannot be longer than 50 characters(spaces, numbers, and special characters are not allowed) and must be unique in the project.CustomTestField name is case insensitive.
    field_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test summary of a pipeline instance.
pub const PipelineTestMetrics = struct {
    current_context: ?PipelineReference = null,
    results_analysis: ?ResultsAnalysis = null,
    result_summary: ?ResultSummary = null,
    run_summary: ?RunSummary = null,
    /// Summary at child node.
    summary_at_child: ?[]const PipelineTestMetrics = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Pipeline reference
pub const PipelineReference = struct {
    job_reference: ?JobReference = null,
    phase_reference: ?PhaseReference = null,
    /// Reference of the BuildDefinitionId.
    pipeline_definition_id: ?i32 = null,
    /// Reference of the pipeline with which this pipeline instance is related.
    pipeline_id: ?i32 = null,
    stage_reference: ?StageReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Job in pipeline. This is related to matrixing in YAML.
pub const JobReference = struct {
    /// Attempt number of the job
    attempt: ?i32 = null,
    /// Matrixing in YAML generates copies of a job with different inputs in matrix. JobName is the name of those input. Maximum supported length for name is 256 character.
    job_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Phase in pipeline
pub const PhaseReference = struct {
    /// Attempt number of the phase
    attempt: ?i32 = null,
    /// Name of the phase. Maximum supported length for name is 256 character.
    phase_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Stage in pipeline
pub const StageReference = struct {
    /// Attempt number of stage
    attempt: ?i32 = null,
    /// Name of the stage. Maximum supported length for name is 256 character.
    stage_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Results insights for runs with state completed and NeedInvestigation.
pub const ResultsAnalysis = struct {
    previous_context: ?PipelineReference = null,
    results_difference: ?AggregatedResultsDifference = null,
    test_failures_analysis: ?TestResultFailuresAnalysis = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AggregatedResultsDifference = struct {
    increase_in_duration: ?[]const u8 = null,
    increase_in_failures: ?i32 = null,
    increase_in_non_impacted_tests: ?i32 = null,
    increase_in_other_tests: ?i32 = null,
    increase_in_passed_tests: ?i32 = null,
    increase_in_total_tests: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultFailuresAnalysis = struct {
    existing_failures: ?TestFailureDetails = null,
    fixed_tests: ?TestFailureDetails = null,
    new_failures: ?TestFailureDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestFailureDetails = struct {
    count: ?i32 = null,
    test_results: ?[]const TestCaseResultIdentifier = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to a test result.
pub const TestCaseResultIdentifier = struct {
    /// Test result ID.
    test_result_id: ?i32 = null,
    /// Test run ID.
    test_run_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Summary of results for a pipeline instance.
pub const ResultSummary = struct {
    /// Result summary of pipeline, group by TestRun state.
    result_summary_by_run_state: ?std.json.ArrayHashMap(ResultsSummaryByOutcome) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Result summary by the outcome of test results.
pub const ResultsSummaryByOutcome = struct {
    /// Aggregated result details for each test result outcome.
    aggregated_result_details_by_outcome: ?std.json.ArrayHashMap(AggregatedResultDetailsByOutcome) = null,
    /// Time taken by results.
    duration: ?[]const u8 = null,
    /// Total number of not reported test results.
    not_reported_test_count: ?i32 = null,
    /// Total number of test results. (It includes NotImpacted test results as well which need to exclude while calculating pass/fail test result percentage).
    total_test_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Result deatils for a particular test result outcome.
pub const AggregatedResultDetailsByOutcome = struct {
    /// Number of results for current outcome.
    count: ?i32 = null,
    /// Time taken by results.
    duration: ?[]const u8 = null,
    /// Test result outcome
    outcome: ?enums.AggregatedResultDetailsByOutcomeOutcome = null,
    /// Number of results on rerun
    rerun_result_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Summary of runs for a pipeline instance.
pub const RunSummary = struct {
    /// Total time taken by runs with state completed and NeedInvestigation.
    duration: ?[]const u8 = null,
    /// NoConfig runs count.
    no_config_runs_count: ?i32 = null,
    /// Runs count by outcome for runs with state completed and NeedInvestigation runs.
    run_summary_by_outcome: ?std.json.ArrayHashMap(i32) = null,
    /// Runs count by state.
    run_summary_by_state: ?std.json.ArrayHashMap(i32) = null,
    /// Total runs count.
    total_runs_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultsDetails = struct {
    group_by_field: ?[]const u8 = null,
    results_for_group: ?[]const TestResultsDetailsForGroup = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultsDetailsForGroup = struct {
    group_by_value: ?TestResultsDetailsForGroupGroupByValue = null,
    results: ?[]const TestCaseResult = null,
    results_count_by_outcome: ?std.json.ArrayHashMap(AggregatedResultsByOutcome) = null,
    tags: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultsDetailsForGroupGroupByValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a test result.
pub const TestCaseResult = struct {
    /// Test attachment ID of action recording.
    afn_strip_id: ?i32 = null,
    area: ?ShallowReference = null,
    /// Reference to bugs linked to test result.
    associated_bugs: ?[]const ShallowReference = null,
    /// ID representing test method in a dll.
    automated_test_id: ?[]const u8 = null,
    /// Fully qualified name of test executed.
    automated_test_name: ?[]const u8 = null,
    /// Container to which test belongs.
    automated_test_storage: ?[]const u8 = null,
    /// Type of automated test.
    automated_test_type: ?[]const u8 = null,
    /// TypeId of automated test.
    automated_test_type_id: ?[]const u8 = null,
    build: ?ShallowReference = null,
    build_reference: ?BuildReference = null,
    /// Comment in a test result with maxSize= 1000 chars.
    comment: ?[]const u8 = null,
    /// Time when test execution completed(UTC). Completed date should be greater than StartedDate.
    completed_date: ?[]const u8 = null,
    /// Machine name where test executed.
    computer_name: ?[]const u8 = null,
    configuration: ?ShallowReference = null,
    /// Timestamp when test result created(UTC).
    created_date: ?[]const u8 = null,
    /// Array of custom data for additional categorization of the test result. Value of the CustomTestField cannot be more than 1KB.
    custom_fields: ?[]const CustomTestField = null,
    /// Duration of test execution in milliseconds. If not provided value will be set as CompletedDate - StartedDate
    duration_in_ms: ?f64 = null,
    /// Error message in test execution.
    error_message: ?[]const u8 = null,
    failing_since: ?FailingSince = null,
    /// Failure type of test result. Valid Value= (Known Issue, New Issue, Regression, Unknown, None)
    failure_type: ?[]const u8 = null,
    /// ID of a test result.
    id: ?i32 = null,
    /// Test result details of test iterations used only for Manual Testing.
    iteration_details: ?[]const TestIterationDetailsModel = null,
    last_updated_by: ?IdentityRef = null,
    /// Last updated datetime of test result(UTC).
    last_updated_date: ?[]const u8 = null,
    /// Test outcome of test result. Valid values = (Unspecified, None, Passed, Failed, Inconclusive, Timeout, Aborted, Blocked, NotExecuted, Warning, Error, NotApplicable, Paused, InProgress, NotImpacted)
    outcome: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    /// Priority of test executed.
    priority: ?i32 = null,
    project: ?ShallowReference = null,
    release: ?ShallowReference = null,
    release_reference: ?ReleaseReference = null,
    /// ResetCount.
    reset_count: ?i32 = null,
    /// Resolution state of test result.
    resolution_state: ?[]const u8 = null,
    /// ID of resolution state.
    resolution_state_id: ?i32 = null,
    /// Hierarchy type of the result, default value of None means its leaf node.
    result_group_type: ?enums.TestCaseResultResultGroupType = null,
    /// Revision number of test result.
    revision: ?i32 = null,
    run_by: ?IdentityRef = null,
    /// Stacktrace with maxSize= 1000 chars.
    stack_trace: ?[]const u8 = null,
    /// Time when test execution started(UTC).
    started_date: ?[]const u8 = null,
    /// State of test result. Type TestRunState.
    state: ?[]const u8 = null,
    /// List of sub results inside a test result, if ResultGroupType is not None, it holds corresponding type sub results.
    sub_results: ?[]const TestSubResult = null,
    test_case: ?ShallowReference = null,
    /// Reference ID of test used by test result. Type TestResultMetaData
    test_case_reference_id: ?i32 = null,
    /// TestCaseRevision Number.
    test_case_revision: ?i32 = null,
    /// Name of test.
    test_case_title: ?[]const u8 = null,
    test_plan: ?ShallowReference = null,
    test_point: ?ShallowReference = null,
    test_run: ?ShallowReference = null,
    test_suite: ?ShallowReference = null,
    /// Url of test result.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to a build.
pub const BuildReference = struct {
    /// Branch name.
    branch_name: ?[]const u8 = null,
    /// Build system.
    build_system: ?[]const u8 = null,
    /// Build Definition ID.
    definition_id: ?i32 = null,
    /// Build ID.
    id: ?i32 = null,
    /// Build Number.
    number: ?[]const u8 = null,
    /// Repository ID.
    repository_id: ?[]const u8 = null,
    /// Build URI.
    uri: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A custom field information. Allowed Key : Value pairs - ( AttemptId: int value, IsTestResultFlaky: bool)
pub const CustomTestField = struct {
    /// Name of the Custom Test Field
    field_name: ?[]const u8 = null,
    /// 1. If the CustomTestField is registered as Bit data type, value should be sent as case insensitive string - either 'true' or 'false'. 2. If the CustomTestField is registered as Datetime data type, value should be sent as string in the format of 'YYYY-MM-DD hh:mm:ss' 3. If the CustomTestField is registered as Int data type, value should be sent as string representation of 32 bit signed integer. Ex: '5'. 4. If the CustomTestField is registered as Float data type, value should be sent as string for example '4.237' 5. If the CustomTestField is registered as String data type, Any string up to 1kB is accepted. 6. If the CustomTestField is registered as Guid, value should be sent as case insensitive string representation of GUID in usual format 'XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXX' where X can be either number 0-9 or letter A-F. For example 'f88d6b84-3549-4af0-a4f4-58139cd0a14f'.
    value: ?CustomTestFieldValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CustomTestFieldValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Failing since information of a test result.
pub const FailingSince = struct {
    build: ?BuildReference = null,
    /// Time since failing(UTC).
    date: ?[]const u8 = null,
    release: ?ReleaseReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to a release.
pub const ReleaseReference = struct {
    /// Number of Release Attempt.
    attempt: ?i32 = null,
    /// Release Creation Date(UTC).
    creation_date: ?[]const u8 = null,
    /// Release definition ID.
    definition_id: ?i32 = null,
    /// Environment creation Date(UTC).
    environment_creation_date: ?[]const u8 = null,
    /// Release environment definition ID.
    environment_definition_id: ?i32 = null,
    /// Release environment definition name.
    environment_definition_name: ?[]const u8 = null,
    /// Release environment ID.
    environment_id: ?i32 = null,
    /// Release environment name.
    environment_name: ?[]const u8 = null,
    /// Release ID.
    id: ?i32 = null,
    /// Release name.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a test iteration result.
pub const TestIterationDetailsModel = struct {
    /// Test step results in an iteration.
    action_results: ?[]const TestActionResultModel = null,
    /// Reference to attachments in test iteration result.
    attachments: ?[]const TestCaseResultAttachmentModel = null,
    /// Comment in test iteration result.
    comment: ?[]const u8 = null,
    /// Time when execution completed(UTC).
    completed_date: ?[]const u8 = null,
    /// Duration of execution.
    duration_in_ms: ?f64 = null,
    /// Error message in test iteration result execution.
    error_message: ?[]const u8 = null,
    /// ID of test iteration result.
    id: ?i32 = null,
    /// Test outcome if test iteration result.
    outcome: ?[]const u8 = null,
    /// Test parameters in an iteration.
    parameters: ?[]const TestResultParameterModel = null,
    /// Time when execution started(UTC).
    started_date: ?[]const u8 = null,
    /// Url to test iteration result.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a test step result.
pub const TestActionResultModel = struct {
    /// Comment in result.
    comment: ?[]const u8 = null,
    /// Time when execution completed(UTC).
    completed_date: ?[]const u8 = null,
    /// Duration of execution.
    duration_in_ms: ?f64 = null,
    /// Error message in result.
    error_message: ?[]const u8 = null,
    /// Test outcome of result.
    outcome: ?[]const u8 = null,
    /// Time when execution started(UTC).
    started_date: ?[]const u8 = null,
    /// Path identifier for test step in test case workitem. Note: 1) It is represented in Hexadecimal format with 8 digits for a step. 2) Internally, the step ID value for first step starts with 2 so actionPath = 00000002 step 9, will have an ID = 10 and actionPath = 0000000a step 15, will have an ID =16 and actionPath = 00000010 3) actionPath of shared step is concatenated with the parent step of test case. Example, it would be something of type - 0000000300000001 where 00000003 denotes action path of test step and 00000001 denotes action path for shared step
    action_path: ?[]const u8 = null,
    /// Actual result message of test action result.
    actual_result_message: ?[]const u8 = null,
    /// Iteration ID of test action result.
    iteration_id: ?i32 = null,
    shared_step_model: ?SharedStepModel = null,
    /// This is step Id of test case. For shared step, it is step Id of shared step in test case workitem; step Id in shared step. Example: TestCase workitem has two steps: 1) Normal step with Id = 1 2) Shared Step with Id = 2. Inside shared step: a) Normal Step with Id = 1 Value for StepIdentifier for First step: '1' Second step: '2;1'
    step_identifier: ?[]const u8 = null,
    /// Url of test action result. Deprecated in hosted environment.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to shared step workitem.
pub const SharedStepModel = struct {
    /// WorkItem shared step ID.
    id: ?i32 = null,
    /// Shared step workitem revision.
    revision: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test attachment information in a test iteration.
pub const TestCaseResultAttachmentModel = struct {
    /// Path identifier test step in test case workitem.
    action_path: ?[]const u8 = null,
    /// Attachment ID.
    id: ?i32 = null,
    /// Iteration ID.
    iteration_id: ?i32 = null,
    /// Name of attachment.
    name: ?[]const u8 = null,
    /// Attachment size.
    size: ?i64 = null,
    /// Url to attachment.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test parameter information in a test iteration.
pub const TestResultParameterModel = struct {
    /// Test step path where parameter is referenced.
    action_path: ?[]const u8 = null,
    /// Iteration ID.
    iteration_id: ?i32 = null,
    /// Name of parameter.
    parameter_name: ?[]const u8 = null,
    /// This is step Id of test case. For shared step, it is step Id of shared step in test case workitem; step Id in shared step. Example: TestCase workitem has two steps: 1) Normal step with Id = 1 2) Shared Step with Id = 2. Inside shared step: a) Normal Step with Id = 1 Value for StepIdentifier for First step: '1' Second step: '2;1'
    step_identifier: ?[]const u8 = null,
    /// Url of test parameter. Deprecated in hosted environment.
    url: ?[]const u8 = null,
    /// Value of parameter.
    value: ?[]const u8 = null,

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

/// Represents a sub result of a test result.
pub const TestSubResult = struct {
    /// Comment in sub result.
    comment: ?[]const u8 = null,
    /// Time when test execution completed(UTC).
    completed_date: ?[]const u8 = null,
    /// Machine where test executed.
    computer_name: ?[]const u8 = null,
    configuration: ?ShallowReference = null,
    /// Additional properties of sub result.
    custom_fields: ?[]const CustomTestField = null,
    /// Name of sub result.
    display_name: ?[]const u8 = null,
    /// Duration of test execution.
    duration_in_ms: ?i64 = null,
    /// Error message in sub result.
    error_message: ?[]const u8 = null,
    /// ID of sub result.
    id: ?i32 = null,
    /// Time when result last updated(UTC).
    last_updated_date: ?[]const u8 = null,
    /// Outcome of sub result.
    outcome: ?[]const u8 = null,
    /// Immediate parent ID of sub result.
    parent_id: ?i32 = null,
    /// Hierarchy type of the result, default value of None means its leaf node.
    result_group_type: ?enums.TestSubResultResultGroupType = null,
    /// Index number of sub result.
    sequence_id: ?i32 = null,
    /// Stacktrace.
    stack_trace: ?[]const u8 = null,
    /// Time when test execution started(UTC).
    started_date: ?[]const u8 = null,
    /// List of sub results inside a sub result, if ResultGroupType is not None, it holds corresponding type sub results.
    sub_results: ?[]const TestSubResult = null,
    test_result: ?TestCaseResultIdentifier = null,
    /// Url of sub result.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AggregatedResultsByOutcome = struct {
    count: ?i32 = null,
    duration: ?[]const u8 = null,
    group_by_field: ?[]const u8 = null,
    group_by_value: ?AggregatedResultsByOutcomeGroupByValue = null,
    outcome: ?enums.AggregatedResultsByOutcomeOutcome = null,
    rerun_result_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AggregatedResultsByOutcomeGroupByValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `FieldDetailsForTestResults` as returned by Azure DevOps.
pub const FieldDetailsForTestResultsList = struct {
    count: ?i32 = null,
    value: ?[]const FieldDetailsForTestResults = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FieldDetailsForTestResults = struct {
    /// Group by field name
    field_name: ?[]const u8 = null,
    /// Group by field values
    groups_for_field: ?[]const FieldDetailsForTestResultsGroupsForField = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FieldDetailsForTestResultsGroupsForField = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultsQuery = struct {
    fields: ?[]const []const u8 = null,
    results: ?[]const TestCaseResult = null,
    results_filter: ?ResultsFilter = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ResultsFilter = struct {
    automated_test_name: ?[]const u8 = null,
    branch: ?[]const u8 = null,
    executed_in: ?enums.ResultsFilterExecutedIn = null,
    group_by: ?[]const u8 = null,
    max_complete_date: ?[]const u8 = null,
    results_count: ?i32 = null,
    test_case_id: ?i32 = null,
    test_case_reference_ids: ?[]const i32 = null,
    test_plan_id: ?i32 = null,
    test_point_ids: ?[]const i32 = null,
    test_results_context: ?TestResultsContext = null,
    trend_days: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultsContext = struct {
    build: ?BuildReference = null,
    context_type: ?enums.TestResultsContextContextType = null,
    pipeline_reference: ?PipelineReference = null,
    release: ?ReleaseReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const QueryModel = struct {
    query: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestCaseResult` as returned by Azure DevOps.
pub const TestCaseResultList = struct {
    count: ?i32 = null,
    value: ?[]const TestCaseResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultHistory = struct {
    group_by_field: ?[]const u8 = null,
    results_for_group: ?[]const TestResultHistoryDetailsForGroup = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultHistoryDetailsForGroup = struct {
    group_by_value: ?TestResultHistoryDetailsForGroupGroupByValue = null,
    latest_result: ?TestCaseResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultHistoryDetailsForGroupGroupByValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestResultMetaData` as returned by Azure DevOps.
pub const TestResultMetaDataList = struct {
    count: ?i32 = null,
    value: ?[]const TestResultMetaData = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a Meta Data of a test result.
pub const TestResultMetaData = struct {
    /// AutomatedTestName of test result.
    automated_test_name: ?[]const u8 = null,
    /// AutomatedTestStorage of test result.
    automated_test_storage: ?[]const u8 = null,
    /// List of Flaky Identifier for TestCaseReferenceId
    flaky_identifiers: ?[]const TestFlakyIdentifier = null,
    /// Owner of test result.
    owner: ?[]const u8 = null,
    /// Priority of test result.
    priority: ?i32 = null,
    /// ID of TestCaseReference.
    test_case_reference_id: ?i32 = null,
    /// TestCaseTitle of test result.
    test_case_title: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Flaky Identifier
pub const TestFlakyIdentifier = struct {
    /// Branch Name where Flakiness has to be Marked/Unmarked
    branch_name: ?[]const u8 = null,
    /// State for Flakiness
    is_flaky: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a TestResultMetaData Input
pub const TestResultMetaDataUpdateInput = struct {
    /// List of Flaky Identifiers
    flaky_identifiers: ?[]const TestFlakyIdentifier = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Filter to get TestCase result history.
pub const TestHistoryQuery = struct {
    /// Automated test name of the TestCase.
    automated_test_name: ?[]const u8 = null,
    /// Results to be get for a particular branches.
    branch: ?[]const u8 = null,
    /// Get the results history only for this BuildDefinitionId. This to get used in query GroupBy should be Branch. If this is provided, Branch will have no use.
    build_definition_id: ?i32 = null,
    /// It will be filled by server. If not null means there are some results still to be get, and we need to call this REST API with this ContinuousToken. It is not supposed to be created (or altered, if received from server in last batch) by user.
    continuation_token: ?[]const u8 = null,
    /// Group the result on the basis of TestResultGroupBy. This can be Branch, Environment or null(if results are fetched by BuildDefinitionId)
    group_by: ?enums.TestHistoryQueryGroupBy = null,
    /// History to get between time interval MaxCompleteDate and (MaxCompleteDate - TrendDays). Default is current date time.
    max_complete_date: ?[]const u8 = null,
    /// Get the results history only for this ReleaseEnvDefinitionId. This to get used in query GroupBy should be Environment.
    release_env_definition_id: ?i32 = null,
    /// List of TestResultHistoryForGroup which are grouped by GroupBy
    results_for_group: ?[]const TestResultHistoryForGroup = null,
    /// Get the results history only for this testCaseId. This to get used in query to filter the result along with automatedtestname
    test_case_id: ?i32 = null,
    /// Number of days for which history to collect. Maximum supported value is 7 days. Default is 7 days.
    trend_days: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// List of test results filtered on the basis of GroupByValue
pub const TestResultHistoryForGroup = struct {
    /// Display name of the group.
    display_name: ?[]const u8 = null,
    /// Name or Id of the group identifier by which results are grouped together.
    group_by_value: ?[]const u8 = null,
    /// List of results for GroupByValue
    results: ?[]const TestCaseResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemReference` as returned by Azure DevOps.
pub const WorkItemReferenceList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// WorkItem reference Details.
pub const WorkItemReference = struct {
    /// WorkItem Id.
    id: ?[]const u8 = null,
    /// WorkItem Name.
    name: ?[]const u8 = null,
    /// WorkItem Type.
    type: ?[]const u8 = null,
    /// WorkItem Url. Valid Values : (Bug, Task, User Story, Test Case)
    url: ?[]const u8 = null,
    /// WorkItem WebUrl.
    web_url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemToTestLinks = struct {
    executed_in: ?enums.WorkItemToTestLinksExecutedIn = null,
    tests: ?[]const TestMethod = null,
    work_item: ?WorkItemReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestMethod = struct {
    container: ?[]const u8 = null,
    name: ?[]const u8 = null,
    test_result: ?TestCaseResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ShallowTestCaseResult` as returned by Azure DevOps.
pub const ShallowTestCaseResultList = struct {
    count: ?i32 = null,
    value: ?[]const ShallowTestCaseResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ShallowTestCaseResult = struct {
    automated_test_name: ?[]const u8 = null,
    automated_test_storage: ?[]const u8 = null,
    duration_in_ms: ?f64 = null,
    id: ?i32 = null,
    is_re_run: ?bool = null,
    outcome: ?[]const u8 = null,
    owner: ?[]const u8 = null,
    priority: ?i32 = null,
    ref_id: ?i32 = null,
    run_id: ?i32 = null,
    tags: ?[]const []const u8 = null,
    test_case_title: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultSummary = struct {
    aggregated_results_analysis: ?AggregatedResultsAnalysis = null,
    no_config_runs_count: ?i32 = null,
    team_project: ?TeamProjectReference = null,
    test_failures: ?TestFailuresAnalysis = null,
    test_results_context: ?TestResultsContext = null,
    total_runs_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AggregatedResultsAnalysis = struct {
    duration: ?[]const u8 = null,
    not_reported_results_by_outcome: ?std.json.ArrayHashMap(AggregatedResultsByOutcome) = null,
    previous_context: ?TestResultsContext = null,
    results_by_outcome: ?std.json.ArrayHashMap(AggregatedResultsByOutcome) = null,
    results_difference: ?AggregatedResultsDifference = null,
    run_summary_by_outcome: ?std.json.ArrayHashMap(AggregatedRunsByOutcome) = null,
    run_summary_by_state: ?std.json.ArrayHashMap(AggregatedRunsByState) = null,
    total_tests: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AggregatedRunsByOutcome = struct {
    outcome: ?enums.AggregatedRunsByOutcomeOutcome = null,
    runs_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AggregatedRunsByState = struct {
    results_by_outcome: ?std.json.ArrayHashMap(AggregatedResultsByOutcome) = null,
    runs_count: ?i32 = null,
    state: ?enums.AggregatedRunsByStateState = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TeamProjectReference = struct {
    abbreviation: ?[]const u8 = null,
    default_team_image_url: ?[]const u8 = null,
    description: ?[]const u8 = null,
    id: ?[]const u8 = null,
    last_update_time: ?[]const u8 = null,
    name: ?[]const u8 = null,
    revision: ?i64 = null,
    state: ?enums.TeamProjectReferenceState = null,
    url: ?[]const u8 = null,
    visibility: ?enums.TeamProjectReferenceVisibility = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestFailuresAnalysis = struct {
    existing_failures: ?TestFailureDetails = null,
    fixed_tests: ?TestFailureDetails = null,
    new_failures: ?TestFailureDetails = null,
    previous_context: ?TestResultsContext = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestResultSummary` as returned by Azure DevOps.
pub const TestResultSummaryList = struct {
    count: ?i32 = null,
    value: ?[]const TestResultSummary = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestSummaryForWorkItem` as returned by Azure DevOps.
pub const TestSummaryForWorkItemList = struct {
    count: ?i32 = null,
    value: ?[]const TestSummaryForWorkItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestSummaryForWorkItem = struct {
    summary: ?AggregatedDataForResultTrend = null,
    work_item: ?WorkItemReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AggregatedDataForResultTrend = struct {
    /// This is tests execution duration.
    duration: ?[]const u8 = null,
    results_by_outcome: ?std.json.ArrayHashMap(AggregatedResultsByOutcome) = null,
    run_summary_by_state: ?std.json.ArrayHashMap(AggregatedRunsByState) = null,
    test_results_context: ?TestResultsContext = null,
    total_tests: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultTrendFilter = struct {
    branch_names: ?[]const []const u8 = null,
    build_count: ?i32 = null,
    definition_ids: ?[]const i32 = null,
    env_definition_ids: ?[]const i32 = null,
    max_complete_date: ?[]const u8 = null,
    publish_context: ?[]const u8 = null,
    test_run_titles: ?[]const []const u8 = null,
    trend_days: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `AggregatedDataForResultTrend` as returned by Azure DevOps.
pub const AggregatedDataForResultTrendList = struct {
    count: ?i32 = null,
    value: ?[]const AggregatedDataForResultTrend = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestRun` as returned by Azure DevOps.
pub const TestRunList = struct {
    count: ?i32 = null,
    value: ?[]const TestRun = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test run details.
pub const TestRun = struct {
    build: ?ShallowReference = null,
    build_configuration: ?BuildConfiguration = null,
    /// Comments entered by those analyzing the run.
    comment: ?[]const u8 = null,
    /// Completed date time of the run.
    completed_date: ?[]const u8 = null,
    /// Test Run Controller.
    controller: ?[]const u8 = null,
    /// Test Run CreatedDate.
    created_date: ?[]const u8 = null,
    /// List of Custom Fields for TestRun.
    custom_fields: ?[]const CustomTestField = null,
    /// Drop Location for the test Run.
    drop_location: ?[]const u8 = null,
    dtl_aut_environment: ?ShallowReference = null,
    dtl_environment: ?ShallowReference = null,
    dtl_environment_creation_details: ?DtlEnvironmentDetails = null,
    /// Due date and time for test run.
    due_date: ?[]const u8 = null,
    /// Error message associated with the run.
    error_message: ?[]const u8 = null,
    filter: ?RunFilter = null,
    /// ID of the test run.
    id: ?i32 = null,
    /// Number of Incomplete Tests.
    incomplete_tests: ?i32 = null,
    /// true if test run is automated, false otherwise.
    is_automated: ?bool = null,
    /// The iteration to which the run belongs.
    iteration: ?[]const u8 = null,
    last_updated_by: ?IdentityRef = null,
    /// Last updated date and time
    last_updated_date: ?[]const u8 = null,
    /// Name of the test run.
    name: ?[]const u8 = null,
    /// Number of Not Applicable Tests.
    not_applicable_tests: ?i32 = null,
    owner: ?IdentityRef = null,
    /// Number of passed tests in the run
    passed_tests: ?i32 = null,
    /// Phase/State for the testRun.
    phase: ?[]const u8 = null,
    pipeline_reference: ?PipelineReference = null,
    plan: ?ShallowReference = null,
    /// Post Process State.
    post_process_state: ?[]const u8 = null,
    project: ?ShallowReference = null,
    release: ?ReleaseReference = null,
    /// Release Environment Uri for TestRun.
    release_environment_uri: ?[]const u8 = null,
    /// Release Uri for TestRun.
    release_uri: ?[]const u8 = null,
    revision: ?i32 = null,
    /// RunSummary by outcome.
    run_statistics: ?[]const RunStatistic = null,
    /// Start date time of the run.
    started_date: ?[]const u8 = null,
    /// The state of the run. Type TestRunState Valid states - Unspecified ,NotStarted, InProgress, Completed, Waiting, Aborted, NeedsInvestigation
    state: ?[]const u8 = null,
    /// TestRun Substate.
    substate: ?enums.TestRunSubstate = null,
    /// Tags attached with this test run.
    tags: ?[]const TestTag = null,
    test_environment: ?TestEnvironment = null,
    test_message_log_id: ?i32 = null,
    test_settings: ?ShallowReference = null,
    /// Total tests in the run
    total_tests: ?i32 = null,
    /// Number of failed tests in the run.
    unanalyzed_tests: ?i32 = null,
    /// Url of the test run
    url: ?[]const u8 = null,
    /// Web Access Url for TestRun.
    web_access_url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// This is a temporary class to provide the details for the test run environment.
pub const DtlEnvironmentDetails = struct {
    csm_content: ?[]const u8 = null,
    csm_parameters: ?[]const u8 = null,
    subscription_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// This class is used to provide the filters used for discovery
pub const RunFilter = struct {
    /// filter for the test case sources (test containers)
    source_filter: ?[]const u8 = null,
    /// filter for the test cases
    test_case_filter: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test run statistics per outcome.
pub const RunStatistic = struct {
    /// Test result count fo the given outcome.
    count: ?i32 = null,
    /// Test result outcome
    outcome: ?[]const u8 = null,
    resolution_state: ?TestResolutionState = null,
    /// ResultMetadata for the given outcome/count.
    result_metadata: ?enums.RunStatisticResultMetadata = null,
    /// State of the test run
    state: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Resolution State Details.
pub const TestResolutionState = struct {
    /// Test Resolution state Id.
    id: ?i32 = null,
    /// Test Resolution State Name.
    name: ?[]const u8 = null,
    project: ?ShallowReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Tag attached to a run or result.
pub const TestTag = struct {
    /// Name of the tag, alphanumeric value less than 30 chars
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test environment Detail.
pub const TestEnvironment = struct {
    /// Test Environment Id.
    environment_id: ?[]const u8 = null,
    /// Test Environment Name.
    environment_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test run create details.
pub const RunCreateModel = struct {
    /// true if test run is automated, false otherwise. By default it will be false.
    automated: ?bool = null,
    build: ?ShallowReference = null,
    /// Drop location of the build used for test run.
    build_drop_location: ?[]const u8 = null,
    /// Flavor of the build used for test run. (E.g: Release, Debug)
    build_flavor: ?[]const u8 = null,
    /// Platform of the build used for test run. (E.g.: x86, amd64)
    build_platform: ?[]const u8 = null,
    build_reference: ?BuildConfiguration = null,
    /// Comments entered by those analyzing the run.
    comment: ?[]const u8 = null,
    /// Completed date time of the run.
    complete_date: ?[]const u8 = null,
    /// IDs of the test configurations associated with the run.
    configuration_ids: ?[]const i32 = null,
    /// Name of the test controller used for automated run.
    controller: ?[]const u8 = null,
    /// List of custom data for additional categorization of the test run. Value of the CustomTestField cannot be more than 1KB.
    custom_test_fields: ?[]const CustomTestField = null,
    dtl_aut_environment: ?ShallowReference = null,
    dtl_test_environment: ?ShallowReference = null,
    /// Due date and time for test run.
    due_date: ?[]const u8 = null,
    environment_details: ?DtlEnvironmentDetails = null,
    /// Error message associated with the run.
    error_message: ?[]const u8 = null,
    filter: ?RunFilter = null,
    /// The iteration in which to create the run. Root iteration of the team project will be default
    iteration: ?[]const u8 = null,
    /// Name of the test run.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    pipeline_reference: ?PipelineReference = null,
    plan: ?ShallowReference = null,
    /// IDs of the test points to use in the run.
    point_ids: ?[]const i32 = null,
    /// URI of release environment associated with the run.
    release_environment_uri: ?[]const u8 = null,
    release_reference: ?ReleaseReference = null,
    /// URI of release associated with the run.
    release_uri: ?[]const u8 = null,
    /// Run summary for run Type = NoConfigRun.
    run_summary: ?[]const RunSummaryModel = null,
    /// Timespan till the run times out.
    run_timeout: ?[]const u8 = null,
    /// SourceWorkFlow(CI/CD) of the test run.
    source_workflow: ?[]const u8 = null,
    /// Start date time of the run.
    start_date: ?[]const u8 = null,
    /// The state of the run. Type TestRunState Valid states - NotStarted, InProgress, Waiting
    state: ?[]const u8 = null,
    /// Tags to attach with the test run, maximum of 5 tags can be added to run.
    tags: ?[]const TestTag = null,
    /// TestConfigurationMapping of the test run.
    test_configurations_mapping: ?[]const u8 = null,
    /// ID of the test environment associated with the run.
    test_environment_id: ?[]const u8 = null,
    test_settings: ?ShallowReference = null,
    /// Type of the run(RunType) Valid Values : (Unspecified, Normal, Blocking, Web, MtrRunInitiatedFromWeb, RunWithDtlEnv, NoConfigRun)
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Run summary for each output type of test.
pub const RunSummaryModel = struct {
    /// Total time taken in milliseconds.
    duration: ?i64 = null,
    /// Number of results for Outcome TestOutcome
    result_count: ?i32 = null,
    /// Summary is based on outcome
    test_outcome: ?enums.RunSummaryModelTestOutcome = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const RunUpdateModel = struct {
    build: ?ShallowReference = null,
    /// Drop location of the build used for test run.
    build_drop_location: ?[]const u8 = null,
    /// Flavor of the build used for test run. (E.g: Release, Debug)
    build_flavor: ?[]const u8 = null,
    /// Platform of the build used for test run. (E.g.: x86, amd64)
    build_platform: ?[]const u8 = null,
    /// Comments entered by those analyzing the run.
    comment: ?[]const u8 = null,
    /// Completed date time of the run.
    completed_date: ?[]const u8 = null,
    /// Name of the test controller used for automated run.
    controller: ?[]const u8 = null,
    /// List of custom data for additional categorization of the test run. Value of the CustomTestField cannot be more than 1KB.
    custom_test_fields: ?[]const CustomTestField = null,
    /// true to delete inProgess Results , false otherwise.
    delete_in_progress_results: ?bool = null,
    dtl_aut_environment: ?ShallowReference = null,
    dtl_environment: ?ShallowReference = null,
    dtl_environment_details: ?DtlEnvironmentDetails = null,
    /// Due date and time for test run.
    due_date: ?[]const u8 = null,
    /// Error message associated with the run.
    error_message: ?[]const u8 = null,
    /// The iteration in which to create the run.
    iteration: ?[]const u8 = null,
    /// Log entries associated with the run. Use a comma-separated list of multiple log entry objects. { logEntry }, { logEntry }, ...
    log_entries: ?[]const TestMessageLogDetails = null,
    /// Name of the test run.
    name: ?[]const u8 = null,
    /// URI of release environment associated with the run.
    release_environment_uri: ?[]const u8 = null,
    /// URI of release associated with the run.
    release_uri: ?[]const u8 = null,
    /// Run summary for run Type = NoConfigRun.
    run_summary: ?[]const RunSummaryModel = null,
    /// SourceWorkFlow(CI/CD) of the test run.
    source_workflow: ?[]const u8 = null,
    /// Start date time of the run.
    started_date: ?[]const u8 = null,
    /// The state of the test run Below are the valid values - NotStarted, InProgress, Completed, Aborted, Waiting
    state: ?[]const u8 = null,
    /// The types of sub states for test run.
    substate: ?enums.RunUpdateModelSubstate = null,
    /// Tags to attach with the test run.
    tags: ?[]const TestTag = null,
    /// ID of the test environment associated with the run.
    test_environment_id: ?[]const u8 = null,
    test_settings: ?ShallowReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An abstracted reference to some other resource. This class is used to provide the build data contracts with a uniform way to reference other resources in a way that provides easy traversal through links.
pub const TestMessageLogDetails = struct {
    /// Date when the resource is created
    date_created: ?[]const u8 = null,
    /// Id of the resource
    entry_id: ?i32 = null,
    /// Message of the resource
    message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestAttachment` as returned by Azure DevOps.
pub const TestAttachmentList = struct {
    count: ?i32 = null,
    value: ?[]const TestAttachment = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestAttachment = struct {
    /// Attachment type.
    attachment_type: ?enums.TestAttachmentAttachmentType = null,
    /// Comment associated with attachment.
    comment: ?[]const u8 = null,
    /// Attachment created date.
    created_date: ?[]const u8 = null,
    /// Attachment file name
    file_name: ?[]const u8 = null,
    /// ID of the attachment.
    id: ?i32 = null,
    /// Attachment size.
    size: ?i64 = null,
    /// Attachment Url.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test attachment request model
pub const TestAttachmentRequestModel = struct {
    /// Attachment type By Default it will be GeneralAttachment. It can be one of the following type. { GeneralAttachment, AfnStrip, BugFilingData, CodeCoverage, IntermediateCollectorData, RunConfig, TestImpactDetails, TmiTestRunDeploymentFiles, TmiTestRunReverseDeploymentFiles, TmiTestResultDetail, TmiTestRunSummary }
    attachment_type: ?[]const u8 = null,
    /// Comment associated with attachment
    comment: ?[]const u8 = null,
    /// Attachment filename
    file_name: ?[]const u8 = null,
    /// Base64 encoded file stream
    stream: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to test attachment.
pub const TestAttachmentReference = struct {
    /// ID of the attachment.
    id: ?i32 = null,
    /// Url to download the attachment.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestMessageLogDetails` as returned by Azure DevOps.
pub const TestMessageLogDetailsList = struct {
    count: ?i32 = null,
    value: ?[]const TestMessageLogDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultDocument = struct {
    operation_reference: ?TestOperationReference = null,
    payload: ?TestResultPayload = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class representing a reference to an operation.
pub const TestOperationReference = struct {
    id: ?[]const u8 = null,
    status: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultPayload = struct {
    comment: ?[]const u8 = null,
    name: ?[]const u8 = null,
    stream: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestLog` as returned by Azure DevOps.
pub const TestLogList = struct {
    count: ?i32 = null,
    value: ?[]const TestLog = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents Test Log Result object.
pub const TestLog = struct {
    log_reference: ?TestLogReference = null,
    /// Meta data for Log file
    meta_data: ?std.json.ArrayHashMap([]const u8) = null,
    /// LastUpdatedDate for Log file
    modified_on: ?[]const u8 = null,
    /// Size in Bytes for Log file
    size: ?i64 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Log Reference object
pub const TestLogReference = struct {
    /// BuildId for test log, if context is build
    build_id: ?i32 = null,
    /// FileName for log file
    file_path: ?[]const u8 = null,
    /// ReleaseEnvId for test log, if context is Release
    release_env_id: ?i32 = null,
    /// ReleaseId for test log, if context is Release
    release_id: ?i32 = null,
    /// Resultid for test log, if context is run and log is related to result
    result_id: ?i32 = null,
    /// runid for test log, if context is run
    run_id: ?i32 = null,
    /// Test Log Scope
    scope: ?enums.TestLogReferenceScope = null,
    /// SubResultid for test log, if context is run and log is related to subresult
    sub_result_id: ?i32 = null,
    /// Log Type
    type: ?enums.TestLogReferenceType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents Test Log store endpoint details.
pub const TestLogStoreEndpointDetails = struct {
    /// Test log store connection Uri.
    endpoint_sas_uri: ?[]const u8 = null,
    /// Test log store endpoint type.
    endpoint_type: ?enums.TestLogStoreEndpointDetailsEndpointType = null,
    /// Test log store status code
    status: ?enums.TestLogStoreEndpointDetailsStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .endpoint_sas_uri = "endpointSASUri",
        },
    };
};

/// Test run statistics.
pub const TestRunStatistic = struct {
    run: ?ShallowReference = null,
    run_statistics: ?[]const RunStatistic = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Tags to update to a run or result.
pub const TestTagsUpdateModel = struct {
    tags: ?[]const TestTagsUpdateModelTag = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestTagsUpdateModelTag = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestTag` as returned by Azure DevOps.
pub const TestTagList = struct {
    count: ?i32 = null,
    value: ?[]const TestTag = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestLogStoreAttachment` as returned by Azure DevOps.
pub const TestLogStoreAttachmentList = struct {
    count: ?i32 = null,
    value: ?[]const TestLogStoreAttachment = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Attachment metadata for test attachments from LogStore.
pub const TestLogStoreAttachment = struct {
    /// Attachment type.
    attachment_type: ?enums.TestLogStoreAttachmentAttachmentType = null,
    /// Comment associated with attachment.
    comment: ?[]const u8 = null,
    /// Attachment created date.
    created_date: ?[]const u8 = null,
    /// Attachment file name.
    file_name: ?[]const u8 = null,
    /// Attachment size.
    size: ?i64 = null,
    /// Attachment Url.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to test attachment.
pub const TestLogStoreAttachmentReference = struct {
    /// Url to download the attachment.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultsSettings = struct {
    advanced_flaky_detection_settings: ?AdvancedFlakyDetectionSettings = null,
    flaky_settings: ?FlakySettings = null,
    new_test_result_logging_settings: ?NewTestResultLoggingSettings = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AdvancedFlakyDetectionSettings = struct {
    /// Threshold for filing a bug for a flaky test.
    filing_bug_threshold: ?i32 = null,
    flaky_test_bug_config: ?FlakyTestBugConfig = null,
    /// Threshold for marking a test as flaky.
    marking_flaky_threshold: ?i32 = null,
    /// List of parameters with their weights for advanced flaky detection.
    weighted_scores: ?[]const AdvancedFlakyDetectionParameter = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FlakyTestBugConfig = struct {
    /// Metadata properties for flaky test bug.
    bug_metadata: ?[]const enums.FlakyTestBugConfigBugMetadatum = null,
    /// Bug Priority for flaky test bug.
    bug_priority: ?i32 = null,
    /// Bug Template Id for flaky test bug.
    bug_template_id: ?[]const u8 = null,
    /// Team Id for the bug template
    team_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AdvancedFlakyDetectionParameter = struct {
    /// Lookback period for the parameter in multiple of 24 hours
    lookback_period: ?i32 = null,
    /// Type of the parameter.
    parameter_type: ?enums.AdvancedFlakyDetectionParameterParameterType = null,
    /// Weight for the parameter. Values between 0-100
    weight: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FlakySettings = struct {
    /// Advanced flaky detection Mode
    advanced_system_detection_mode: ?enums.FlakySettingsAdvancedSystemDetectionMode = null,
    flaky_detection: ?FlakyDetection = null,
    /// FlakyInSummaryReport defines flaky data should show in summary report or not.
    flaky_in_summary_report: ?bool = null,
    /// IsFlakyBugCreated defines if there is any bug that has been created with flaky testresult.
    is_flaky_bug_created: ?bool = null,
    /// ManualMarkUnmarkFlaky defines manual marking unmarking of flaky testcase.
    manual_mark_unmark_flaky: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FlakyDetection = struct {
    flaky_detection_pipelines: ?FlakyDetectionPipelines = null,
    /// FlakyDetectionType defines Detection type i.e. 1. System or 2. Manual.
    flaky_detection_type: ?enums.FlakyDetectionFlakyDetectionType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const FlakyDetectionPipelines = struct {
    /// AllowedPipelines - List All Pipelines allowed for detection.
    allowed_pipelines: ?[]const i32 = null,
    /// IsAllPipelinesAllowed if users configure all system's pipelines.
    is_all_pipelines_allowed: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const NewTestResultLoggingSettings = struct {
    /// LogNewTests defines whether or not we will record new test cases coming into the system
    log_new_tests: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const TestResultsUpdateSettings = struct {
    advanced_flaky_detection_settings: ?AdvancedFlakyDetectionSettings = null,
    flaky_settings: ?FlakySettings = null,
    new_test_result_logging_settings: ?NewTestResultLoggingSettings = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test tag summary for build or release grouped by test run.
pub const TestTagSummary = struct {
    /// Dictionary which contains tags associated with a test run.
    tags_group_by_test_artifact: ?std.json.ArrayHashMap([]const TestTag) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestResultFailureType` as returned by Azure DevOps.
pub const TestResultFailureTypeList = struct {
    count: ?i32 = null,
    value: ?[]const TestResultFailureType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The test failure type resource
pub const TestResultFailureType = struct {
    /// ID of the test failure type
    id: ?i32 = null,
    /// Name of the test failure type
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The test failure type request model
pub const TestResultFailureTypeRequestModel = struct {
    /// Name of the test failure type
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the test settings of the run. Used to create test settings and fetch test settings
pub const TestSettings = struct {
    /// Area path required to create test settings
    area_path: ?[]const u8 = null,
    /// Description of the test settings. Used in create test settings.
    description: ?[]const u8 = null,
    /// Indicates if the tests settings is public or private.Used in create test settings.
    is_public: ?bool = null,
    /// Xml string of machine roles. Used in create test settings.
    machine_roles: ?[]const u8 = null,
    /// Test settings content.
    test_settings_content: ?[]const u8 = null,
    /// Test settings id.
    test_settings_id: ?i32 = null,
    /// Test settings name.
    test_settings_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
