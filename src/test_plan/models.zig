//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `TestSuite` as returned by Azure DevOps.
pub const TestSuiteList = struct {
    count: ?i32 = null,
    value: ?[]const TestSuite = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test suite
pub const TestSuite = struct {
    /// Test suite default configurations.
    default_configurations: ?[]const TestConfigurationReference = null,
    /// Test suite default testers.
    default_testers: ?[]const IdentityRef = null,
    /// Default configuration was inherited or not.
    inherit_default_configurations: ?bool = null,
    /// Name of test suite.
    name: ?[]const u8 = null,
    parent_suite: ?TestSuiteReference = null,
    /// Test suite query string, for dynamic suites.
    query_string: ?[]const u8 = null,
    /// Test suite requirement id.
    requirement_id: ?i32 = null,
    /// Test suite type.
    suite_type: ?enums.TestSuiteSuiteType = null,
    links: ?ReferenceLinks = null,
    /// Child test suites of current test suite.
    children: ?[]const TestSuite = null,
    /// Boolean value dictating if Child test suites are present
    has_children: ?bool = null,
    /// Id of test suite.
    id: ?i32 = null,
    /// Last error for test suite.
    last_error: ?[]const u8 = null,
    /// Last populated date.
    last_populated_date: ?[]const u8 = null,
    last_updated_by: ?IdentityRef = null,
    /// Last update date.
    last_updated_date: ?[]const u8 = null,
    plan: ?TestPlanReference = null,
    project: ?TeamProjectReference = null,
    /// Test suite revision.
    revision: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Test Configuration Reference
pub const TestConfigurationReference = struct {
    /// Id of the configuration
    id: ?i32 = null,
    /// Name of the configuration
    name: ?[]const u8 = null,

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

/// The test suite reference resource.
pub const TestSuiteReference = struct {
    /// ID of the test suite.
    id: ?i32 = null,
    /// Name of the test suite.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The test plan reference resource.
pub const TestPlanReference = struct {
    /// ID of the test plan.
    id: ?i32 = null,
    /// Name of the test plan.
    name: ?[]const u8 = null,

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

/// Test suite Create Parameters
pub const TestSuiteCreateParams = struct {
    /// Test suite default configurations.
    default_configurations: ?[]const TestConfigurationReference = null,
    /// Test suite default testers.
    default_testers: ?[]const IdentityRef = null,
    /// Default configuration was inherited or not.
    inherit_default_configurations: ?bool = null,
    /// Name of test suite.
    name: ?[]const u8 = null,
    parent_suite: ?TestSuiteReference = null,
    /// Test suite query string, for dynamic suites.
    query_string: ?[]const u8 = null,
    /// Test suite requirement id.
    requirement_id: ?i32 = null,
    /// Test suite type.
    suite_type: ?enums.TestSuiteSuiteType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Suite Update Parameters
pub const TestSuiteUpdateParams = struct {
    /// Test suite default configurations.
    default_configurations: ?[]const TestConfigurationReference = null,
    /// Test suite default testers.
    default_testers: ?[]const IdentityRef = null,
    /// Default configuration was inherited or not.
    inherit_default_configurations: ?bool = null,
    /// Name of test suite.
    name: ?[]const u8 = null,
    parent_suite: ?TestSuiteReference = null,
    /// Test suite query string, for dynamic suites.
    query_string: ?[]const u8 = null,
    /// Test suite revision.
    revision: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestConfiguration` as returned by Azure DevOps.
pub const TestConfigurationList = struct {
    count: ?i32 = null,
    value: ?[]const TestConfiguration = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test configuration
pub const TestConfiguration = struct {
    /// Description of the configuration
    description: ?[]const u8 = null,
    /// Is the configuration a default for the test plans
    is_default: ?bool = null,
    /// Name of the configuration
    name: ?[]const u8 = null,
    /// State of the configuration
    state: ?enums.TestConfigurationState = null,
    /// Dictionary of Test Variable, Selected Value
    values: ?[]const NameValuePair = null,
    /// Id of the configuration
    id: ?i32 = null,
    project: ?TeamProjectReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Name value pair
pub const NameValuePair = struct {
    /// Name
    name: ?[]const u8 = null,
    /// Value
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Configuration Create or Update Parameters
pub const TestConfigurationCreateUpdateParameters = struct {
    /// Description of the configuration
    description: ?[]const u8 = null,
    /// Is the configuration a default for the test plans
    is_default: ?bool = null,
    /// Name of the configuration
    name: ?[]const u8 = null,
    /// State of the configuration
    state: ?enums.TestConfigurationState = null,
    /// Dictionary of Test Variable, Selected Value
    values: ?[]const NameValuePair = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestPlan` as returned by Azure DevOps.
pub const TestPlanList = struct {
    count: ?i32 = null,
    value: ?[]const TestPlan = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The test plan resource.
pub const TestPlan = struct {
    actual_test_result_settings: ?ActualTestResultSettings = null,
    /// Area of the test plan.
    area_path: ?[]const u8 = null,
    build_definition: ?BuildDefinitionReference = null,
    /// Build to be tested.
    build_id: ?i32 = null,
    /// Description of the test plan.
    description: ?[]const u8 = null,
    /// End date for the test plan.
    end_date: ?[]const u8 = null,
    /// Iteration path of the test plan.
    iteration: ?[]const u8 = null,
    /// Name of the test plan.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    release_environment_definition: ?ReleaseEnvironmentDefinitionReference = null,
    /// Start date for the test plan.
    start_date: ?[]const u8 = null,
    /// State of the test plan.
    state: ?[]const u8 = null,
    test_outcome_settings: ?TestOutcomeSettings = null,
    yaml_release_reference: ?YamlReleaseReference = null,
    /// Revision of the test plan.
    revision: ?i32 = null,
    links: ?ReferenceLinks = null,
    /// ID of the test plan.
    id: ?i32 = null,
    /// Previous build Id associated with the test plan
    previous_build_id: ?i32 = null,
    project: ?TeamProjectReference = null,
    root_suite: ?TestSuiteReference = null,
    updated_by: ?IdentityRef = null,
    /// Updated date of the test plan
    updated_date: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Actual Test Result Settings for a Test Plan
pub const ActualTestResultSettings = struct {
    /// Enable actual results field usage for test step result in the test plan during test execution
    is_actual_test_result_enabled: ?bool = null,
    /// Mandate actual results field usage for test step result in the test plan during test execution
    is_actual_test_result_mandatory: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The build definition reference resource
pub const BuildDefinitionReference = struct {
    /// ID of the build definition
    id: ?i32 = null,
    /// Name of the build definition
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to release environment resource.
pub const ReleaseEnvironmentDefinitionReference = struct {
    /// ID of the release definition that contains the release environment definition.
    definition_id: ?i32 = null,
    /// ID of the release environment definition.
    environment_definition_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test outcome settings
pub const TestOutcomeSettings = struct {
    /// Value to configure how test outcomes for the same tests across suites are shown
    sync_outcome_across_suites: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to yaml release resource.
pub const YamlReleaseReference = struct {
    /// ID of the yaml release definition
    definition_id: ?i32 = null,
    /// Stages to skip while queuing yaml release.
    stages_to_skip: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The test plan create parameters.
pub const TestPlanCreateParams = struct {
    actual_test_result_settings: ?ActualTestResultSettings = null,
    /// Area of the test plan.
    area_path: ?[]const u8 = null,
    build_definition: ?BuildDefinitionReference = null,
    /// Build to be tested.
    build_id: ?i32 = null,
    /// Description of the test plan.
    description: ?[]const u8 = null,
    /// End date for the test plan.
    end_date: ?[]const u8 = null,
    /// Iteration path of the test plan.
    iteration: ?[]const u8 = null,
    /// Name of the test plan.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    release_environment_definition: ?ReleaseEnvironmentDefinitionReference = null,
    /// Start date for the test plan.
    start_date: ?[]const u8 = null,
    /// State of the test plan.
    state: ?[]const u8 = null,
    test_outcome_settings: ?TestOutcomeSettings = null,
    yaml_release_reference: ?YamlReleaseReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The test plan update parameters.
pub const TestPlanUpdateParams = struct {
    actual_test_result_settings: ?ActualTestResultSettings = null,
    /// Area of the test plan.
    area_path: ?[]const u8 = null,
    build_definition: ?BuildDefinitionReference = null,
    /// Build to be tested.
    build_id: ?i32 = null,
    /// Description of the test plan.
    description: ?[]const u8 = null,
    /// End date for the test plan.
    end_date: ?[]const u8 = null,
    /// Iteration path of the test plan.
    iteration: ?[]const u8 = null,
    /// Name of the test plan.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    release_environment_definition: ?ReleaseEnvironmentDefinitionReference = null,
    /// Start date for the test plan.
    start_date: ?[]const u8 = null,
    /// State of the test plan.
    state: ?[]const u8 = null,
    test_outcome_settings: ?TestOutcomeSettings = null,
    yaml_release_reference: ?YamlReleaseReference = null,
    /// Revision of the test plan.
    revision: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestCase` as returned by Azure DevOps.
pub const TestCaseList = struct {
    count: ?i32 = null,
    value: ?[]const TestCase = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Case Class
pub const TestCase = struct {
    links: ?ReferenceLinks = null,
    /// Order of the TestCase in the Suite
    order: ?i32 = null,
    /// List of Points associated with the Test Case
    point_assignments: ?[]const PointAssignment = null,
    project: ?TeamProjectReference = null,
    test_plan: ?TestPlanReference = null,
    test_suite: ?TestSuiteReference = null,
    work_item: ?WorkItemDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Assignments for the Test Point
pub const PointAssignment = struct {
    /// Id of the Configuration Assigned to the Test Point
    configuration_id: ?i32 = null,
    /// Name of the Configuration Assigned to the Test Point
    configuration_name: ?[]const u8 = null,
    /// Id of the Test Point
    id: ?i32 = null,
    tester: ?IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Work Item Class
pub const WorkItemDetails = struct {
    /// Work Item Id
    id: ?i32 = null,
    /// Work Item Name
    name: ?[]const u8 = null,
    /// Work Item Fields
    work_item_fields: ?[]const WorkItemDetailsWorkItemField = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WorkItemDetailsWorkItemField = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Create and Update Suite Test Case Parameters
pub const SuiteTestCaseCreateUpdateParameters = struct {
    /// Configurations Ids
    point_assignments: ?[]const Configuration = null,
    work_item: ?WorkItem = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Configuration of the Test Point
pub const Configuration = struct {
    /// Id of the Configuration Assigned to the Test Point
    configuration_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Work Item
pub const WorkItem = struct {
    /// Id of the Work Item
    id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestPoint` as returned by Azure DevOps.
pub const TestPointList = struct {
    count: ?i32 = null,
    value: ?[]const TestPoint = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Point Class
pub const TestPoint = struct {
    /// Comment associated to the Test Point
    comment: ?[]const u8 = null,
    configuration: ?TestConfigurationReference = null,
    /// Id of the Test Point
    id: ?i32 = null,
    /// Variable to decide whether the test case is Active or not
    is_active: ?bool = null,
    /// Is the Test Point for Automated Test Case or Manual
    is_automated: ?bool = null,
    /// Last Reset to Active Time Stamp for the Test Point
    last_reset_to_active: ?[]const u8 = null,
    last_updated_by: ?IdentityRef = null,
    /// Last Update Time Stamp for the Test Point
    last_updated_date: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    project: ?TeamProjectReference = null,
    results: ?TestPointResults = null,
    test_case_reference: ?TestCaseReference = null,
    tester: ?IdentityRef = null,
    test_plan: ?TestPlanReference = null,
    test_suite: ?TestSuiteReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Point Results
pub const TestPointResults = struct {
    /// Failure Type for the Test Point
    failure_type: ?enums.TestPointResultsFailureType = null,
    /// Last Resolution State Id for the Test Point
    last_resolution_state: ?enums.TestPointResultsLastResolutionState = null,
    last_result_details: ?LastResultDetails = null,
    /// Last Result Id
    last_result_id: ?i32 = null,
    /// Last Result State of the Test Point
    last_result_state: ?enums.TestPointResultsLastResultState = null,
    /// Last RUn Build Number for the Test Point
    last_run_build_number: ?[]const u8 = null,
    /// Last Test Run Id for the Test Point
    last_test_run_id: ?i32 = null,
    /// Outcome of the Test Point
    outcome: ?enums.TestPointResultsOutcome = null,
    /// State of the Test Point
    state: ?enums.TestPointResultsState = null,

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

/// Test Case Reference
pub const TestCaseReference = struct {
    assigned_to: ?IdentityRef = null,
    /// Test Case Id
    id: ?i32 = null,
    /// Test Case Name
    name: ?[]const u8 = null,
    /// State of the test case work item
    state: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Point Update Parameters
pub const TestPointUpdateParams = struct {
    /// Id of Test Point to be updated
    id: ?i32 = null,
    /// Reset the Test Point to Active
    is_active: ?bool = null,
    results: ?Results = null,
    tester: ?IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Results class for Test Point
pub const Results = struct {
    /// Outcome of the Test Point
    outcome: ?enums.ResultsOutcome = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters for Test Plan clone operation
pub const CloneTestPlanParams = struct {
    clone_options: ?CloneOptions = null,
    destination_test_plan: ?DestinationTestPlanCloneParams = null,
    source_test_plan: ?SourceTestPlanInfo = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Clone options for cloning the test suite.
pub const CloneOptions = struct {
    /// If set to true requirements will be cloned
    clone_requirements: ?bool = null,
    /// copy all suites from a source plan
    copy_all_suites: ?bool = null,
    /// copy ancestor hierarchy
    copy_ancestor_hierarchy: ?bool = null,
    /// Name of the workitem type of the clone
    destination_work_item_type: ?[]const u8 = null,
    /// Key value pairs where the key value is overridden by the value.
    override_parameters: ?std.json.ArrayHashMap([]const u8) = null,
    /// Comment on the link that will link the new clone test case to the original Set null for no comment
    related_link_comment: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Destination Test Plan create parameters
pub const DestinationTestPlanCloneParams = struct {
    actual_test_result_settings: ?ActualTestResultSettings = null,
    /// Area of the test plan.
    area_path: ?[]const u8 = null,
    build_definition: ?BuildDefinitionReference = null,
    /// Build to be tested.
    build_id: ?i32 = null,
    /// Description of the test plan.
    description: ?[]const u8 = null,
    /// End date for the test plan.
    end_date: ?[]const u8 = null,
    /// Iteration path of the test plan.
    iteration: ?[]const u8 = null,
    /// Name of the test plan.
    name: ?[]const u8 = null,
    owner: ?IdentityRef = null,
    release_environment_definition: ?ReleaseEnvironmentDefinitionReference = null,
    /// Start date for the test plan.
    start_date: ?[]const u8 = null,
    /// State of the test plan.
    state: ?[]const u8 = null,
    test_outcome_settings: ?TestOutcomeSettings = null,
    yaml_release_reference: ?YamlReleaseReference = null,
    /// Destination Project Name
    project: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Source Test Plan information for Test Plan clone operation
pub const SourceTestPlanInfo = struct {
    /// ID of the source Test Plan
    id: ?i32 = null,
    /// Id of suites to be cloned inside source Test Plan
    suite_ids: ?[]const i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Response for Test Plan clone operation
pub const CloneTestPlanOperationInformation = struct {
    clone_operation_response: ?CloneOperationCommonResponse = null,
    clone_options: ?CloneOptions = null,
    destination_test_plan: ?TestPlan = null,
    source_test_plan: ?SourceTestplanResponse = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Common Response for clone operation
pub const CloneOperationCommonResponse = struct {
    clone_statistics: ?CloneStatistics = null,
    /// Completion data of the operation
    completion_date: ?[]const u8 = null,
    /// Creation data of the operation
    creation_date: ?[]const u8 = null,
    links: ?ReferenceLinks = null,
    /// Message related to the job
    message: ?[]const u8 = null,
    /// Clone operation Id
    op_id: ?i32 = null,
    /// Clone operation state
    state: ?enums.CloneOperationCommonResponseState = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Clone Statistics Details.
pub const CloneStatistics = struct {
    /// Number of requirements cloned so far.
    cloned_requirements_count: ?i32 = null,
    /// Number of shared steps cloned so far.
    cloned_shared_steps_count: ?i32 = null,
    /// Number of test cases cloned so far
    cloned_test_cases_count: ?i32 = null,
    /// Total number of requirements to be cloned
    total_requirements_count: ?i32 = null,
    /// Total number of test cases to be cloned
    total_test_cases_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Source Test Plan Response for Test Plan clone operation
pub const SourceTestplanResponse = struct {
    /// ID of the test plan.
    id: ?i32 = null,
    /// Name of the test plan.
    name: ?[]const u8 = null,
    project: ?TeamProjectReference = null,
    /// Id of suites to be cloned inside source Test Plan
    suite_ids: ?[]const i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Plan/Suite restore request body params
pub const TestPlanAndSuiteRestoreModel = struct {
    /// Indicates whether the deleted test plan/suite should be restored.
    is_deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `SuiteEntry` as returned by Azure DevOps.
pub const SuiteEntryList = struct {
    count: ?i32 = null,
    value: ?[]const SuiteEntry = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A suite entry defines properties for a test suite.
pub const SuiteEntry = struct {
    /// Id of the suite entry in the test suite: either a test case id or child suite id.
    id: ?i32 = null,
    /// Sequence number for the suite entry object in the test suite.
    sequence_number: ?i32 = null,
    /// Defines whether the entry is of type test case or suite.
    suite_entry_type: ?enums.SuiteEntrySuiteEntryType = null,
    /// Id for the test suite.
    suite_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A suite entry defines properties for a test suite.
pub const SuiteEntryUpdateParams = struct {
    /// Id of the suite entry in the test suite: either a test case id or child suite id.
    id: ?i32 = null,
    /// Sequence number for the suite entry object in the test suite.
    sequence_number: ?i32 = null,
    /// Defines whether the entry is of type test case or suite.
    suite_entry_type: ?enums.SuiteEntrySuiteEntryType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters for Test Suite clone operation
pub const CloneTestSuiteParams = struct {
    clone_options: ?CloneOptions = null,
    destination_test_suite: ?DestinationTestSuiteInfo = null,
    source_test_suite: ?SourceTestSuiteInfo = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Destination Test Suite information for Test Suite clone operation
pub const DestinationTestSuiteInfo = struct {
    /// Destination Suite Id
    id: ?i32 = null,
    /// Destination Project Name
    project: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Source Test Suite information for Test Suite clone operation
pub const SourceTestSuiteInfo = struct {
    /// Id of the Source Test Suite
    id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Response for Test Suite clone operation
pub const CloneTestSuiteOperationInformation = struct {
    cloned_test_suite: ?TestSuiteReferenceWithProject = null,
    clone_operation_response: ?CloneOperationCommonResponse = null,
    clone_options: ?CloneOptions = null,
    destination_test_suite: ?TestSuiteReferenceWithProject = null,
    source_test_suite: ?TestSuiteReferenceWithProject = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Suite Reference with Project
pub const TestSuiteReferenceWithProject = struct {
    /// ID of the test suite.
    id: ?i32 = null,
    /// Name of the test suite.
    name: ?[]const u8 = null,
    project: ?TeamProjectReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters for Test Suite clone operation
pub const CloneTestCaseParams = struct {
    clone_options: ?CloneTestCaseOptions = null,
    destination_test_plan: ?TestPlanReference = null,
    destination_test_suite: ?DestinationTestSuiteInfo = null,
    source_test_plan: ?TestPlanReference = null,
    source_test_suite: ?SourceTestSuiteInfo = null,
    /// Test Case IDs
    test_case_ids: ?[]const i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CloneTestCaseOptions = struct {
    /// If set to true, include the attachments
    include_attachments: ?bool = null,
    /// If set to true, include the links
    include_links: ?bool = null,
    /// Comment on the link that will link the new clone test case to the original Set null for no comment
    related_link_comment: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CloneTestCaseOperationInformation = struct {
    clone_operation_response: ?CloneOperationCommonResponse = null,
    clone_options: ?CloneTestCaseOptions = null,
    destination_test_suite: ?TestSuiteReferenceWithProject = null,
    source_test_suite: ?SourceTestSuiteResponse = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Source Test Suite Response for Test Case clone operation
pub const SourceTestSuiteResponse = struct {
    /// ID of the test suite.
    id: ?i32 = null,
    /// Name of the test suite.
    name: ?[]const u8 = null,
    project: ?TeamProjectReference = null,
    /// Id of suites to be cloned inside source Test Plan
    test_case_ids: ?[]const i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `TestVariable` as returned by Azure DevOps.
pub const TestVariableList = struct {
    count: ?i32 = null,
    value: ?[]const TestVariable = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Variable
pub const TestVariable = struct {
    /// Description of the test variable
    description: ?[]const u8 = null,
    /// Name of the test variable
    name: ?[]const u8 = null,
    /// List of allowed values
    values: ?[]const []const u8 = null,
    /// Id of the test variable
    id: ?i32 = null,
    project: ?TeamProjectReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Test Variable Create or Update Parameters
pub const TestVariableCreateUpdateParameters = struct {
    /// Description of the test variable
    description: ?[]const u8 = null,
    /// Name of the test variable
    name: ?[]const u8 = null,
    /// List of allowed values
    values: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
