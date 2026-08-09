//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Build Coverage Detail
pub const BuildCoverage = struct {
    /// Code Coverage File Url
    code_coverage_file_url: ?[]const u8 = null,
    configuration: ?BuildConfiguration = null,
    /// Last Error
    last_error: ?[]const u8 = null,
    /// List of Modules
    modules: ?[]const ModuleCoverage = null,
    /// State
    state: ?[]const u8 = null,

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

/// Test point.
pub const TestPoint = struct {
    assigned_to: ?IdentityRef = null,
    /// Automated.
    automated: ?bool = null,
    /// Comment associated with test point.
    comment: ?[]const u8 = null,
    configuration: ?ShallowReference = null,
    /// Failure type of test point.
    failure_type: ?[]const u8 = null,
    /// ID of the test point.
    id: ?i32 = null,
    /// Last date when test point was reset to Active.
    last_reset_to_active: ?[]const u8 = null,
    /// Last resolution state id of test point.
    last_resolution_state_id: ?i32 = null,
    last_result: ?ShallowReference = null,
    last_result_details: ?LastResultDetails = null,
    /// Last result state of test point.
    last_result_state: ?[]const u8 = null,
    /// LastRun build number of test point.
    last_run_build_number: ?[]const u8 = null,
    last_test_run: ?ShallowReference = null,
    last_updated_by: ?IdentityRef = null,
    /// Last updated date of test point.
    last_updated_date: ?[]const u8 = null,
    /// Outcome of test point.
    outcome: ?[]const u8 = null,
    /// Revision number.
    revision: ?i32 = null,
    /// State of test point.
    state: ?[]const u8 = null,
    suite: ?ShallowReference = null,
    test_case: ?WorkItemReference = null,
    test_plan: ?ShallowReference = null,
    /// Test point Url.
    url: ?[]const u8 = null,
    /// Work item properties of test point.
    work_item_properties: ?[]const TestPointWorkItemProperty = null,

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

/// Last result details of test point.
pub const LastResultDetails = struct {
    /// Completed date of last result.
    date_completed: ?[]const u8 = null,
    /// Duration of the last result in milliseconds.
    duration: ?i64 = null,
    run_by: ?IdentityRef = null,

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

pub const TestPointWorkItemProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Model to update test point.
pub const PointUpdateModel = struct {
    /// Outcome to update.
    outcome: ?[]const u8 = null,
    /// Reset test point to active.
    reset_to_active: ?bool = null,
    tester: ?IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test point query class.
pub const TestPointsQuery = struct {
    /// Order by results.
    order_by: ?[]const u8 = null,
    /// List of test points
    points: ?[]const TestPoint = null,
    points_filter: ?PointsFilter = null,
    /// List of workitem fields to get.
    wit_fields: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Filter class for test point.
pub const PointsFilter = struct {
    /// List of Configurations for filtering.
    configuration_names: ?[]const []const u8 = null,
    /// List of test case id for filtering.
    testcase_ids: ?[]const i32 = null,
    /// List of tester for filtering.
    testers: ?[]const IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test case for the suite.
pub const SuiteTestCase = struct {
    /// Point Assignment for test suite's test case.
    point_assignments: ?[]const PointAssignment = null,
    test_case: ?WorkItemReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Adding test cases to a suite creates one of more test points based on the default configurations and testers assigned to the test suite. PointAssignment is the list of test points that were created for each of the test cases that were added to the test suite.
pub const PointAssignment = struct {
    configuration: ?ShallowReference = null,
    tester: ?IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test suite update model.
pub const SuiteTestCaseUpdateModel = struct {
    /// Shallow reference of configurations for the test cases in the suite.
    configurations: ?[]const ShallowReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test result retention settings
pub const ResultRetentionSettings = struct {
    /// Automated test result retention duration in days
    automated_results_retention_duration: ?i32 = null,
    last_updated_by: ?IdentityRef = null,
    /// Last updated date
    last_updated_date: ?[]const u8 = null,
    /// Manual test result retention duration in days
    manual_results_retention_duration: ?i32 = null,

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

/// Test run statistics.
pub const TestRunStatistic = struct {
    run: ?ShallowReference = null,
    run_statistics: ?[]const RunStatistic = null,

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

/// Test Session
pub const TestSession = struct {
    area: ?ShallowReference = null,
    /// Comments in the test session
    comment: ?[]const u8 = null,
    /// Duration of the session
    end_date: ?[]const u8 = null,
    /// Id of the test session
    id: ?i32 = null,
    last_updated_by: ?IdentityRef = null,
    /// Last updated date
    last_updated_date: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    project: ?ShallowReference = null,
    property_bag: ?PropertyBag = null,
    /// Revision of the test session
    revision: ?i32 = null,
    /// Source of the test session
    source: ?enums.TestSessionSource = null,
    /// Start date
    start_date: ?[]const u8 = null,
    /// State of the test session
    state: ?enums.TestSessionState = null,
    /// Title of the test session
    title: ?[]const u8 = null,
    /// Url of Test Session Resource
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The class to represent a Generic store for test session data.
pub const PropertyBag = struct {
    /// Generic store for test session data
    bag: ?std.json.ArrayHashMap([]const u8) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
