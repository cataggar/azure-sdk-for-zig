//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const CodeCoverageSummaryCoverageDetailedSummaryStatus = union(enum) {
    none,
    in_progress,
    finalized,
    pending,
    update_request_queued,
    no_modules_found,
    number_of_files_exceeded,
    no_input_files,
    build_cancelled,
    failed_jobs,
    module_merge_job_timeout,
    code_coverage_success,
    invalid_build_configuration,
    coverage_analyzer_build_not_found,
    failed_to_requeue,
    build_bailed_out,
    no_code_coverage_task,
    merge_job_failed,
    merge_invoker_job_failed,
    monitor_job_failed,
    module_merge_invoker_job_timeout,
    monitor_job_timeout,
    invalid_coverage_input,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .in_progress = "inProgress",
        .finalized = "finalized",
        .pending = "pending",
        .update_request_queued = "updateRequestQueued",
        .no_modules_found = "noModulesFound",
        .number_of_files_exceeded = "numberOfFilesExceeded",
        .no_input_files = "noInputFiles",
        .build_cancelled = "buildCancelled",
        .failed_jobs = "failedJobs",
        .module_merge_job_timeout = "moduleMergeJobTimeout",
        .code_coverage_success = "codeCoverageSuccess",
        .invalid_build_configuration = "invalidBuildConfiguration",
        .coverage_analyzer_build_not_found = "coverageAnalyzerBuildNotFound",
        .failed_to_requeue = "failedToRequeue",
        .build_bailed_out = "buildBailedOut",
        .no_code_coverage_task = "noCodeCoverageTask",
        .merge_job_failed = "mergeJobFailed",
        .merge_invoker_job_failed = "mergeInvokerJobFailed",
        .monitor_job_failed = "monitorJobFailed",
        .module_merge_invoker_job_timeout = "moduleMergeInvokerJobTimeout",
        .monitor_job_timeout = "monitorJobTimeout",
        .invalid_coverage_input = "invalidCoverageInput",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const CodeCoverageSummaryStatus = union(enum) {
    none,
    in_progress,
    completed,
    finalized,
    pending,
    update_request_queued,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .in_progress = "inProgress",
        .completed = "completed",
        .finalized = "finalized",
        .pending = "pending",
        .update_request_queued = "updateRequestQueued",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const QueryRequestScopeFilter = enum {
    none,
    test_run,
    test_result,
    test_run_and_test_result,
    system,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .test_run => "testRun",
            .test_result => "testResult",
            .test_run_and_test_result => "testRunAndTestResult",
            .system => "system",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "testRun")) return .test_run;
        if (std.mem.eql(u8, s, "testResult")) return .test_result;
        if (std.mem.eql(u8, s, "testRunAndTestResult")) return .test_run_and_test_result;
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "all")) return .all;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const CustomTestFieldDefinitionFieldType = union(enum) {
    bit,
    date_time,
    int,
    float,
    string,
    guid,
    unrecognized: []const u8,

    const wire_names = .{
        .bit = "bit",
        .date_time = "dateTime",
        .int = "int",
        .float = "float",
        .string = "string",
        .guid = "guid",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const CustomTestFieldDefinitionScope = union(enum) {
    none,
    test_run,
    test_result,
    test_run_and_test_result,
    system,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .test_run = "testRun",
        .test_result = "testResult",
        .test_run_and_test_result = "testRunAndTestResult",
        .system = "system",
        .all = "all",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const AggregatedResultDetailsByOutcomeOutcome = union(enum) {
    unspecified,
    none,
    passed,
    failed,
    inconclusive,
    timeout,
    aborted,
    blocked,
    not_executed,
    warning,
    @"error",
    not_applicable,
    paused,
    in_progress,
    not_impacted,
    unrecognized: []const u8,

    const wire_names = .{
        .unspecified = "unspecified",
        .none = "none",
        .passed = "passed",
        .failed = "failed",
        .inconclusive = "inconclusive",
        .timeout = "timeout",
        .aborted = "aborted",
        .blocked = "blocked",
        .not_executed = "notExecuted",
        .warning = "warning",
        .@"error" = "error",
        .not_applicable = "notApplicable",
        .paused = "paused",
        .in_progress = "inProgress",
        .not_impacted = "notImpacted",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestCaseResultResultGroupType = union(enum) {
    none,
    rerun,
    data_driven,
    ordered_test,
    generic,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .rerun = "rerun",
        .data_driven = "dataDriven",
        .ordered_test = "orderedTest",
        .generic = "generic",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestSubResultResultGroupType = union(enum) {
    none,
    rerun,
    data_driven,
    ordered_test,
    generic,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .rerun = "rerun",
        .data_driven = "dataDriven",
        .ordered_test = "orderedTest",
        .generic = "generic",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const AggregatedResultsByOutcomeOutcome = union(enum) {
    unspecified,
    none,
    passed,
    failed,
    inconclusive,
    timeout,
    aborted,
    blocked,
    not_executed,
    warning,
    @"error",
    not_applicable,
    paused,
    in_progress,
    not_impacted,
    unrecognized: []const u8,

    const wire_names = .{
        .unspecified = "unspecified",
        .none = "none",
        .passed = "passed",
        .failed = "failed",
        .inconclusive = "inconclusive",
        .timeout = "timeout",
        .aborted = "aborted",
        .blocked = "blocked",
        .not_executed = "notExecuted",
        .warning = "warning",
        .@"error" = "error",
        .not_applicable = "notApplicable",
        .paused = "paused",
        .in_progress = "inProgress",
        .not_impacted = "notImpacted",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const ResultsFilterExecutedIn = union(enum) {
    any,
    tcm,
    tfs,
    unrecognized: []const u8,

    const wire_names = .{
        .any = "any",
        .tcm = "tcm",
        .tfs = "tfs",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestResultsContextContextType = union(enum) {
    build,
    release,
    pipeline,
    unrecognized: []const u8,

    const wire_names = .{
        .build = "build",
        .release = "release",
        .pipeline = "pipeline",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GetTestResultsRequestDetailsToInclude = enum {
    none,
    iterations,
    work_items,
    sub_results,
    point,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .iterations => "iterations",
            .work_items => "workItems",
            .sub_results => "subResults",
            .point => "point",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "iterations")) return .iterations;
        if (std.mem.eql(u8, s, "workItems")) return .work_items;
        if (std.mem.eql(u8, s, "subResults")) return .sub_results;
        if (std.mem.eql(u8, s, "point")) return .point;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetTestResultByIdRequestDetailsToInclude = enum {
    none,
    iterations,
    work_items,
    sub_results,
    point,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .iterations => "iterations",
            .work_items => "workItems",
            .sub_results => "subResults",
            .point => "point",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "iterations")) return .iterations;
        if (std.mem.eql(u8, s, "workItems")) return .work_items;
        if (std.mem.eql(u8, s, "subResults")) return .sub_results;
        if (std.mem.eql(u8, s, "point")) return .point;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const QueryRequestDetailsToInclude = enum {
    none,
    flaky_identifiers,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .flaky_identifiers => "flakyIdentifiers",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "flakyIdentifiers")) return .flaky_identifiers;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const TestHistoryQueryGroupBy = union(enum) {
    branch,
    environment,
    unrecognized: []const u8,

    const wire_names = .{
        .branch = "branch",
        .environment = "environment",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const WorkItemToTestLinksExecutedIn = union(enum) {
    any,
    tcm,
    tfs,
    unrecognized: []const u8,

    const wire_names = .{
        .any = "any",
        .tcm = "tcm",
        .tfs = "tfs",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const AggregatedRunsByOutcomeOutcome = union(enum) {
    passed,
    failed,
    not_impacted,
    others,
    unrecognized: []const u8,

    const wire_names = .{
        .passed = "passed",
        .failed = "failed",
        .not_impacted = "notImpacted",
        .others = "others",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const AggregatedRunsByStateState = union(enum) {
    unspecified,
    not_started,
    in_progress,
    completed,
    aborted,
    waiting,
    needs_investigation,
    unrecognized: []const u8,

    const wire_names = .{
        .unspecified = "unspecified",
        .not_started = "notStarted",
        .in_progress = "inProgress",
        .completed = "completed",
        .aborted = "aborted",
        .waiting = "waiting",
        .needs_investigation = "needsInvestigation",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TeamProjectReferenceState = union(enum) {
    deleting,
    new,
    well_formed,
    create_pending,
    all,
    unchanged,
    deleted,
    unrecognized: []const u8,

    const wire_names = .{
        .deleting = "deleting",
        .new = "new",
        .well_formed = "wellFormed",
        .create_pending = "createPending",
        .all = "all",
        .unchanged = "unchanged",
        .deleted = "deleted",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TeamProjectReferenceVisibility = union(enum) {
    private,
    public,
    unrecognized: []const u8,

    const wire_names = .{
        .private = "private",
        .public = "public",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const RunStatisticResultMetadata = union(enum) {
    rerun,
    flaky,
    unrecognized: []const u8,

    const wire_names = .{
        .rerun = "rerun",
        .flaky = "flaky",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestRunSubstate = union(enum) {
    none,
    creating_environment,
    running_tests,
    canceled_by_user,
    aborted_by_system,
    timed_out,
    pending_analysis,
    analyzed,
    cancellation_in_progress,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .creating_environment = "creatingEnvironment",
        .running_tests = "runningTests",
        .canceled_by_user = "canceledByUser",
        .aborted_by_system = "abortedBySystem",
        .timed_out = "timedOut",
        .pending_analysis = "pendingAnalysis",
        .analyzed = "analyzed",
        .cancellation_in_progress = "cancellationInProgress",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const RunSummaryModelTestOutcome = union(enum) {
    unspecified,
    none,
    passed,
    failed,
    inconclusive,
    timeout,
    aborted,
    blocked,
    not_executed,
    warning,
    @"error",
    not_applicable,
    paused,
    in_progress,
    not_impacted,
    unrecognized: []const u8,

    const wire_names = .{
        .unspecified = "unspecified",
        .none = "none",
        .passed = "passed",
        .failed = "failed",
        .inconclusive = "inconclusive",
        .timeout = "timeout",
        .aborted = "aborted",
        .blocked = "blocked",
        .not_executed = "notExecuted",
        .warning = "warning",
        .@"error" = "error",
        .not_applicable = "notApplicable",
        .paused = "paused",
        .in_progress = "inProgress",
        .not_impacted = "notImpacted",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const RunUpdateModelSubstate = union(enum) {
    none,
    creating_environment,
    running_tests,
    canceled_by_user,
    aborted_by_system,
    timed_out,
    pending_analysis,
    analyzed,
    cancellation_in_progress,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .creating_environment = "creatingEnvironment",
        .running_tests = "runningTests",
        .canceled_by_user = "canceledByUser",
        .aborted_by_system = "abortedBySystem",
        .timed_out = "timedOut",
        .pending_analysis = "pendingAnalysis",
        .analyzed = "analyzed",
        .cancellation_in_progress = "cancellationInProgress",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestAttachmentAttachmentType = union(enum) {
    general_attachment,
    code_coverage,
    console_log,
    unrecognized: []const u8,

    const wire_names = .{
        .general_attachment = "generalAttachment",
        .code_coverage = "codeCoverage",
        .console_log = "consoleLog",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestLogReferenceScope = union(enum) {
    run,
    unrecognized: []const u8,

    const wire_names = .{
        .run = "run",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestLogReferenceType = union(enum) {
    general_attachment,
    unrecognized: []const u8,

    const wire_names = .{
        .general_attachment = "generalAttachment",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestLogStoreEndpointDetailsEndpointType = union(enum) {
    root,
    file,
    unrecognized: []const u8,

    const wire_names = .{
        .root = "root",
        .file = "file",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestLogStoreEndpointDetailsStatus = union(enum) {
    success,
    failed,
    file_already_exists,
    invalid_input,
    invalid_file_name,
    invalid_container,
    transfer_failed,
    feature_disabled,
    build_does_not_exist,
    run_does_not_exist,
    container_not_created,
    api_not_supported,
    file_size_exceeds,
    container_not_found,
    file_not_found,
    directory_not_found,
    storage_capacity_exceeded,
    unrecognized: []const u8,

    const wire_names = .{
        .success = "success",
        .failed = "failed",
        .file_already_exists = "fileAlreadyExists",
        .invalid_input = "invalidInput",
        .invalid_file_name = "invalidFileName",
        .invalid_container = "invalidContainer",
        .transfer_failed = "transferFailed",
        .feature_disabled = "featureDisabled",
        .build_does_not_exist = "buildDoesNotExist",
        .run_does_not_exist = "runDoesNotExist",
        .container_not_created = "containerNotCreated",
        .api_not_supported = "apiNotSupported",
        .file_size_exceeds = "fileSizeExceeds",
        .container_not_found = "containerNotFound",
        .file_not_found = "fileNotFound",
        .directory_not_found = "directoryNotFound",
        .storage_capacity_exceeded = "storageCapacityExceeded",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TestLogStoreAttachmentAttachmentType = union(enum) {
    general_attachment,
    code_coverage,
    console_log,
    unrecognized: []const u8,

    const wire_names = .{
        .general_attachment = "generalAttachment",
        .code_coverage = "codeCoverage",
        .console_log = "consoleLog",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GetRequestSettingsType = enum {
    all,
    flaky,
    new_test_logging,
    advanced_flaky_detection,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .all => "all",
            .flaky => "flaky",
            .new_test_logging => "newTestLogging",
            .advanced_flaky_detection => "advancedFlakyDetection",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "flaky")) return .flaky;
        if (std.mem.eql(u8, s, "newTestLogging")) return .new_test_logging;
        if (std.mem.eql(u8, s, "advancedFlakyDetection")) return .advanced_flaky_detection;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const FlakyTestBugConfigBugMetadatum = union(enum) {
    error_message,
    stack_trace,
    test_name,
    machine,
    unrecognized: []const u8,

    const wire_names = .{
        .error_message = "errorMessage",
        .stack_trace = "stackTrace",
        .test_name = "testName",
        .machine = "machine",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const AdvancedFlakyDetectionParameterParameterType = union(enum) {
    failure_rate,
    pass_rate,
    timing_variability,
    rerun_count,
    unrecognized: []const u8,

    const wire_names = .{
        .failure_rate = "failureRate",
        .pass_rate = "passRate",
        .timing_variability = "timingVariability",
        .rerun_count = "rerunCount",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const FlakySettingsAdvancedSystemDetectionMode = union(enum) {
    disabled,
    preview,
    enabled,
    unrecognized: []const u8,

    const wire_names = .{
        .disabled = "disabled",
        .preview = "preview",
        .enabled = "enabled",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const FlakyDetectionFlakyDetectionType = union(enum) {
    custom,
    system,
    unrecognized: []const u8,

    const wire_names = .{
        .custom = "custom",
        .system = "system",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const ServiceApiVersions = enum {
    v7_2_preview,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .v7_2_preview => "7.2-preview",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "7.2-preview")) return .v7_2_preview;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};
