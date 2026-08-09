//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const CodeCoverageSummaryCoverageDetailedSummaryStatus = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .in_progress => "inProgress",
            .finalized => "finalized",
            .pending => "pending",
            .update_request_queued => "updateRequestQueued",
            .no_modules_found => "noModulesFound",
            .number_of_files_exceeded => "numberOfFilesExceeded",
            .no_input_files => "noInputFiles",
            .build_cancelled => "buildCancelled",
            .failed_jobs => "failedJobs",
            .module_merge_job_timeout => "moduleMergeJobTimeout",
            .code_coverage_success => "codeCoverageSuccess",
            .invalid_build_configuration => "invalidBuildConfiguration",
            .coverage_analyzer_build_not_found => "coverageAnalyzerBuildNotFound",
            .failed_to_requeue => "failedToRequeue",
            .build_bailed_out => "buildBailedOut",
            .no_code_coverage_task => "noCodeCoverageTask",
            .merge_job_failed => "mergeJobFailed",
            .merge_invoker_job_failed => "mergeInvokerJobFailed",
            .monitor_job_failed => "monitorJobFailed",
            .module_merge_invoker_job_timeout => "moduleMergeInvokerJobTimeout",
            .monitor_job_timeout => "monitorJobTimeout",
            .invalid_coverage_input => "invalidCoverageInput",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "finalized")) return .finalized;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "updateRequestQueued")) return .update_request_queued;
        if (std.mem.eql(u8, s, "noModulesFound")) return .no_modules_found;
        if (std.mem.eql(u8, s, "numberOfFilesExceeded")) return .number_of_files_exceeded;
        if (std.mem.eql(u8, s, "noInputFiles")) return .no_input_files;
        if (std.mem.eql(u8, s, "buildCancelled")) return .build_cancelled;
        if (std.mem.eql(u8, s, "failedJobs")) return .failed_jobs;
        if (std.mem.eql(u8, s, "moduleMergeJobTimeout")) return .module_merge_job_timeout;
        if (std.mem.eql(u8, s, "codeCoverageSuccess")) return .code_coverage_success;
        if (std.mem.eql(u8, s, "invalidBuildConfiguration")) return .invalid_build_configuration;
        if (std.mem.eql(u8, s, "coverageAnalyzerBuildNotFound")) return .coverage_analyzer_build_not_found;
        if (std.mem.eql(u8, s, "failedToRequeue")) return .failed_to_requeue;
        if (std.mem.eql(u8, s, "buildBailedOut")) return .build_bailed_out;
        if (std.mem.eql(u8, s, "noCodeCoverageTask")) return .no_code_coverage_task;
        if (std.mem.eql(u8, s, "mergeJobFailed")) return .merge_job_failed;
        if (std.mem.eql(u8, s, "mergeInvokerJobFailed")) return .merge_invoker_job_failed;
        if (std.mem.eql(u8, s, "monitorJobFailed")) return .monitor_job_failed;
        if (std.mem.eql(u8, s, "moduleMergeInvokerJobTimeout")) return .module_merge_invoker_job_timeout;
        if (std.mem.eql(u8, s, "monitorJobTimeout")) return .monitor_job_timeout;
        if (std.mem.eql(u8, s, "invalidCoverageInput")) return .invalid_coverage_input;
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

pub const CodeCoverageSummaryStatus = enum {
    none,
    in_progress,
    completed,
    finalized,
    pending,
    update_request_queued,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .in_progress => "inProgress",
            .completed => "completed",
            .finalized => "finalized",
            .pending => "pending",
            .update_request_queued => "updateRequestQueued",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "finalized")) return .finalized;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "updateRequestQueued")) return .update_request_queued;
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

pub const CustomTestFieldDefinitionFieldType = enum {
    bit,
    date_time,
    int,
    float,
    string,
    guid,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .bit => "bit",
            .date_time => "dateTime",
            .int => "int",
            .float => "float",
            .string => "string",
            .guid => "guid",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "bit")) return .bit;
        if (std.mem.eql(u8, s, "dateTime")) return .date_time;
        if (std.mem.eql(u8, s, "int")) return .int;
        if (std.mem.eql(u8, s, "float")) return .float;
        if (std.mem.eql(u8, s, "string")) return .string;
        if (std.mem.eql(u8, s, "guid")) return .guid;
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

pub const CustomTestFieldDefinitionScope = enum {
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

pub const AggregatedResultDetailsByOutcomeOutcome = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unspecified => "unspecified",
            .none => "none",
            .passed => "passed",
            .failed => "failed",
            .inconclusive => "inconclusive",
            .timeout => "timeout",
            .aborted => "aborted",
            .blocked => "blocked",
            .not_executed => "notExecuted",
            .warning => "warning",
            .@"error" => "error",
            .not_applicable => "notApplicable",
            .paused => "paused",
            .in_progress => "inProgress",
            .not_impacted => "notImpacted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unspecified")) return .unspecified;
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "passed")) return .passed;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "inconclusive")) return .inconclusive;
        if (std.mem.eql(u8, s, "timeout")) return .timeout;
        if (std.mem.eql(u8, s, "aborted")) return .aborted;
        if (std.mem.eql(u8, s, "blocked")) return .blocked;
        if (std.mem.eql(u8, s, "notExecuted")) return .not_executed;
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "notApplicable")) return .not_applicable;
        if (std.mem.eql(u8, s, "paused")) return .paused;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "notImpacted")) return .not_impacted;
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

pub const TestCaseResultResultGroupType = enum {
    none,
    rerun,
    data_driven,
    ordered_test,
    generic,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .rerun => "rerun",
            .data_driven => "dataDriven",
            .ordered_test => "orderedTest",
            .generic => "generic",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "rerun")) return .rerun;
        if (std.mem.eql(u8, s, "dataDriven")) return .data_driven;
        if (std.mem.eql(u8, s, "orderedTest")) return .ordered_test;
        if (std.mem.eql(u8, s, "generic")) return .generic;
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

pub const TestSubResultResultGroupType = enum {
    none,
    rerun,
    data_driven,
    ordered_test,
    generic,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .rerun => "rerun",
            .data_driven => "dataDriven",
            .ordered_test => "orderedTest",
            .generic => "generic",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "rerun")) return .rerun;
        if (std.mem.eql(u8, s, "dataDriven")) return .data_driven;
        if (std.mem.eql(u8, s, "orderedTest")) return .ordered_test;
        if (std.mem.eql(u8, s, "generic")) return .generic;
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

pub const AggregatedResultsByOutcomeOutcome = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unspecified => "unspecified",
            .none => "none",
            .passed => "passed",
            .failed => "failed",
            .inconclusive => "inconclusive",
            .timeout => "timeout",
            .aborted => "aborted",
            .blocked => "blocked",
            .not_executed => "notExecuted",
            .warning => "warning",
            .@"error" => "error",
            .not_applicable => "notApplicable",
            .paused => "paused",
            .in_progress => "inProgress",
            .not_impacted => "notImpacted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unspecified")) return .unspecified;
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "passed")) return .passed;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "inconclusive")) return .inconclusive;
        if (std.mem.eql(u8, s, "timeout")) return .timeout;
        if (std.mem.eql(u8, s, "aborted")) return .aborted;
        if (std.mem.eql(u8, s, "blocked")) return .blocked;
        if (std.mem.eql(u8, s, "notExecuted")) return .not_executed;
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "notApplicable")) return .not_applicable;
        if (std.mem.eql(u8, s, "paused")) return .paused;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "notImpacted")) return .not_impacted;
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

pub const ResultsFilterExecutedIn = enum {
    any,
    tcm,
    tfs,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .any => "any",
            .tcm => "tcm",
            .tfs => "tfs",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "any")) return .any;
        if (std.mem.eql(u8, s, "tcm")) return .tcm;
        if (std.mem.eql(u8, s, "tfs")) return .tfs;
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

pub const TestResultsContextContextType = enum {
    build,
    release,
    pipeline,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .build => "build",
            .release => "release",
            .pipeline => "pipeline",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "build")) return .build;
        if (std.mem.eql(u8, s, "release")) return .release;
        if (std.mem.eql(u8, s, "pipeline")) return .pipeline;
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

pub const TestHistoryQueryGroupBy = enum {
    branch,
    environment,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .environment => "environment",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "environment")) return .environment;
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

pub const WorkItemToTestLinksExecutedIn = enum {
    any,
    tcm,
    tfs,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .any => "any",
            .tcm => "tcm",
            .tfs => "tfs",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "any")) return .any;
        if (std.mem.eql(u8, s, "tcm")) return .tcm;
        if (std.mem.eql(u8, s, "tfs")) return .tfs;
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

pub const AggregatedRunsByOutcomeOutcome = enum {
    passed,
    failed,
    not_impacted,
    others,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .passed => "passed",
            .failed => "failed",
            .not_impacted => "notImpacted",
            .others => "others",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "passed")) return .passed;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "notImpacted")) return .not_impacted;
        if (std.mem.eql(u8, s, "others")) return .others;
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

pub const AggregatedRunsByStateState = enum {
    unspecified,
    not_started,
    in_progress,
    completed,
    aborted,
    waiting,
    needs_investigation,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unspecified => "unspecified",
            .not_started => "notStarted",
            .in_progress => "inProgress",
            .completed => "completed",
            .aborted => "aborted",
            .waiting => "waiting",
            .needs_investigation => "needsInvestigation",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unspecified")) return .unspecified;
        if (std.mem.eql(u8, s, "notStarted")) return .not_started;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "aborted")) return .aborted;
        if (std.mem.eql(u8, s, "waiting")) return .waiting;
        if (std.mem.eql(u8, s, "needsInvestigation")) return .needs_investigation;
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

pub const TeamProjectReferenceState = enum {
    deleting,
    new,
    well_formed,
    create_pending,
    all,
    unchanged,
    deleted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .deleting => "deleting",
            .new => "new",
            .well_formed => "wellFormed",
            .create_pending => "createPending",
            .all => "all",
            .unchanged => "unchanged",
            .deleted => "deleted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "deleting")) return .deleting;
        if (std.mem.eql(u8, s, "new")) return .new;
        if (std.mem.eql(u8, s, "wellFormed")) return .well_formed;
        if (std.mem.eql(u8, s, "createPending")) return .create_pending;
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "unchanged")) return .unchanged;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
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

pub const TeamProjectReferenceVisibility = enum {
    private,
    public,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .private => "private",
            .public => "public",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "private")) return .private;
        if (std.mem.eql(u8, s, "public")) return .public;
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

pub const RunStatisticResultMetadata = enum {
    rerun,
    flaky,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .rerun => "rerun",
            .flaky => "flaky",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "rerun")) return .rerun;
        if (std.mem.eql(u8, s, "flaky")) return .flaky;
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

pub const TestRunSubstate = enum {
    none,
    creating_environment,
    running_tests,
    canceled_by_user,
    aborted_by_system,
    timed_out,
    pending_analysis,
    analyzed,
    cancellation_in_progress,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .creating_environment => "creatingEnvironment",
            .running_tests => "runningTests",
            .canceled_by_user => "canceledByUser",
            .aborted_by_system => "abortedBySystem",
            .timed_out => "timedOut",
            .pending_analysis => "pendingAnalysis",
            .analyzed => "analyzed",
            .cancellation_in_progress => "cancellationInProgress",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "creatingEnvironment")) return .creating_environment;
        if (std.mem.eql(u8, s, "runningTests")) return .running_tests;
        if (std.mem.eql(u8, s, "canceledByUser")) return .canceled_by_user;
        if (std.mem.eql(u8, s, "abortedBySystem")) return .aborted_by_system;
        if (std.mem.eql(u8, s, "timedOut")) return .timed_out;
        if (std.mem.eql(u8, s, "pendingAnalysis")) return .pending_analysis;
        if (std.mem.eql(u8, s, "analyzed")) return .analyzed;
        if (std.mem.eql(u8, s, "cancellationInProgress")) return .cancellation_in_progress;
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

pub const RunSummaryModelTestOutcome = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unspecified => "unspecified",
            .none => "none",
            .passed => "passed",
            .failed => "failed",
            .inconclusive => "inconclusive",
            .timeout => "timeout",
            .aborted => "aborted",
            .blocked => "blocked",
            .not_executed => "notExecuted",
            .warning => "warning",
            .@"error" => "error",
            .not_applicable => "notApplicable",
            .paused => "paused",
            .in_progress => "inProgress",
            .not_impacted => "notImpacted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unspecified")) return .unspecified;
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "passed")) return .passed;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "inconclusive")) return .inconclusive;
        if (std.mem.eql(u8, s, "timeout")) return .timeout;
        if (std.mem.eql(u8, s, "aborted")) return .aborted;
        if (std.mem.eql(u8, s, "blocked")) return .blocked;
        if (std.mem.eql(u8, s, "notExecuted")) return .not_executed;
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "notApplicable")) return .not_applicable;
        if (std.mem.eql(u8, s, "paused")) return .paused;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "notImpacted")) return .not_impacted;
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

pub const RunUpdateModelSubstate = enum {
    none,
    creating_environment,
    running_tests,
    canceled_by_user,
    aborted_by_system,
    timed_out,
    pending_analysis,
    analyzed,
    cancellation_in_progress,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .creating_environment => "creatingEnvironment",
            .running_tests => "runningTests",
            .canceled_by_user => "canceledByUser",
            .aborted_by_system => "abortedBySystem",
            .timed_out => "timedOut",
            .pending_analysis => "pendingAnalysis",
            .analyzed => "analyzed",
            .cancellation_in_progress => "cancellationInProgress",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "creatingEnvironment")) return .creating_environment;
        if (std.mem.eql(u8, s, "runningTests")) return .running_tests;
        if (std.mem.eql(u8, s, "canceledByUser")) return .canceled_by_user;
        if (std.mem.eql(u8, s, "abortedBySystem")) return .aborted_by_system;
        if (std.mem.eql(u8, s, "timedOut")) return .timed_out;
        if (std.mem.eql(u8, s, "pendingAnalysis")) return .pending_analysis;
        if (std.mem.eql(u8, s, "analyzed")) return .analyzed;
        if (std.mem.eql(u8, s, "cancellationInProgress")) return .cancellation_in_progress;
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

pub const TestAttachmentAttachmentType = enum {
    general_attachment,
    code_coverage,
    console_log,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .general_attachment => "generalAttachment",
            .code_coverage => "codeCoverage",
            .console_log => "consoleLog",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "generalAttachment")) return .general_attachment;
        if (std.mem.eql(u8, s, "codeCoverage")) return .code_coverage;
        if (std.mem.eql(u8, s, "consoleLog")) return .console_log;
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

pub const TestLogStoreEndpointDetailsEndpointType = enum {
    root,
    file,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .root => "root",
            .file => "file",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "root")) return .root;
        if (std.mem.eql(u8, s, "file")) return .file;
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

pub const TestLogStoreEndpointDetailsStatus = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .success => "success",
            .failed => "failed",
            .file_already_exists => "fileAlreadyExists",
            .invalid_input => "invalidInput",
            .invalid_file_name => "invalidFileName",
            .invalid_container => "invalidContainer",
            .transfer_failed => "transferFailed",
            .feature_disabled => "featureDisabled",
            .build_does_not_exist => "buildDoesNotExist",
            .run_does_not_exist => "runDoesNotExist",
            .container_not_created => "containerNotCreated",
            .api_not_supported => "apiNotSupported",
            .file_size_exceeds => "fileSizeExceeds",
            .container_not_found => "containerNotFound",
            .file_not_found => "fileNotFound",
            .directory_not_found => "directoryNotFound",
            .storage_capacity_exceeded => "storageCapacityExceeded",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "success")) return .success;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "fileAlreadyExists")) return .file_already_exists;
        if (std.mem.eql(u8, s, "invalidInput")) return .invalid_input;
        if (std.mem.eql(u8, s, "invalidFileName")) return .invalid_file_name;
        if (std.mem.eql(u8, s, "invalidContainer")) return .invalid_container;
        if (std.mem.eql(u8, s, "transferFailed")) return .transfer_failed;
        if (std.mem.eql(u8, s, "featureDisabled")) return .feature_disabled;
        if (std.mem.eql(u8, s, "buildDoesNotExist")) return .build_does_not_exist;
        if (std.mem.eql(u8, s, "runDoesNotExist")) return .run_does_not_exist;
        if (std.mem.eql(u8, s, "containerNotCreated")) return .container_not_created;
        if (std.mem.eql(u8, s, "apiNotSupported")) return .api_not_supported;
        if (std.mem.eql(u8, s, "fileSizeExceeds")) return .file_size_exceeds;
        if (std.mem.eql(u8, s, "containerNotFound")) return .container_not_found;
        if (std.mem.eql(u8, s, "fileNotFound")) return .file_not_found;
        if (std.mem.eql(u8, s, "directoryNotFound")) return .directory_not_found;
        if (std.mem.eql(u8, s, "storageCapacityExceeded")) return .storage_capacity_exceeded;
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

pub const TestLogStoreAttachmentAttachmentType = enum {
    general_attachment,
    code_coverage,
    console_log,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .general_attachment => "generalAttachment",
            .code_coverage => "codeCoverage",
            .console_log => "consoleLog",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "generalAttachment")) return .general_attachment;
        if (std.mem.eql(u8, s, "codeCoverage")) return .code_coverage;
        if (std.mem.eql(u8, s, "consoleLog")) return .console_log;
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

pub const FlakyTestBugConfigBugMetadatum = enum {
    error_message,
    stack_trace,
    test_name,
    machine,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .error_message => "errorMessage",
            .stack_trace => "stackTrace",
            .test_name => "testName",
            .machine => "machine",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "errorMessage")) return .error_message;
        if (std.mem.eql(u8, s, "stackTrace")) return .stack_trace;
        if (std.mem.eql(u8, s, "testName")) return .test_name;
        if (std.mem.eql(u8, s, "machine")) return .machine;
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

pub const AdvancedFlakyDetectionParameterParameterType = enum {
    failure_rate,
    pass_rate,
    timing_variability,
    rerun_count,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .failure_rate => "failureRate",
            .pass_rate => "passRate",
            .timing_variability => "timingVariability",
            .rerun_count => "rerunCount",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "failureRate")) return .failure_rate;
        if (std.mem.eql(u8, s, "passRate")) return .pass_rate;
        if (std.mem.eql(u8, s, "timingVariability")) return .timing_variability;
        if (std.mem.eql(u8, s, "rerunCount")) return .rerun_count;
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

pub const FlakySettingsAdvancedSystemDetectionMode = enum {
    disabled,
    preview,
    enabled,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .disabled => "disabled",
            .preview => "preview",
            .enabled => "enabled",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "disabled")) return .disabled;
        if (std.mem.eql(u8, s, "preview")) return .preview;
        if (std.mem.eql(u8, s, "enabled")) return .enabled;
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

pub const FlakyDetectionFlakyDetectionType = enum {
    custom,
    system,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .custom => "custom",
            .system => "system",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "custom")) return .custom;
        if (std.mem.eql(u8, s, "system")) return .system;
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
