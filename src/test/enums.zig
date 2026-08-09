//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

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

pub const ListRequestDetailsToInclude = enum {
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

pub const GetRequestDetailsToInclude = enum {
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

pub const ListRequestSource = enum {
    unknown,
    xt_desktop,
    feedback_desktop,
    xt_web,
    feedback_web,
    xt_desktop2,
    session_insights_for_all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .xt_desktop => "xtDesktop",
            .feedback_desktop => "feedbackDesktop",
            .xt_web => "xtWeb",
            .feedback_web => "feedbackWeb",
            .xt_desktop2 => "xtDesktop2",
            .session_insights_for_all => "sessionInsightsForAll",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "xtDesktop")) return .xt_desktop;
        if (std.mem.eql(u8, s, "feedbackDesktop")) return .feedback_desktop;
        if (std.mem.eql(u8, s, "xtWeb")) return .xt_web;
        if (std.mem.eql(u8, s, "feedbackWeb")) return .feedback_web;
        if (std.mem.eql(u8, s, "xtDesktop2")) return .xt_desktop2;
        if (std.mem.eql(u8, s, "sessionInsightsForAll")) return .session_insights_for_all;
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

pub const TestSessionSource = enum {
    unknown,
    xt_desktop,
    feedback_desktop,
    xt_web,
    feedback_web,
    xt_desktop2,
    session_insights_for_all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .xt_desktop => "xtDesktop",
            .feedback_desktop => "feedbackDesktop",
            .xt_web => "xtWeb",
            .feedback_web => "feedbackWeb",
            .xt_desktop2 => "xtDesktop2",
            .session_insights_for_all => "sessionInsightsForAll",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "xtDesktop")) return .xt_desktop;
        if (std.mem.eql(u8, s, "feedbackDesktop")) return .feedback_desktop;
        if (std.mem.eql(u8, s, "xtWeb")) return .xt_web;
        if (std.mem.eql(u8, s, "feedbackWeb")) return .feedback_web;
        if (std.mem.eql(u8, s, "xtDesktop2")) return .xt_desktop2;
        if (std.mem.eql(u8, s, "sessionInsightsForAll")) return .session_insights_for_all;
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

pub const TestSessionState = enum {
    unspecified,
    not_started,
    in_progress,
    paused,
    completed,
    declined,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unspecified => "unspecified",
            .not_started => "notStarted",
            .in_progress => "inProgress",
            .paused => "paused",
            .completed => "completed",
            .declined => "declined",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unspecified")) return .unspecified;
        if (std.mem.eql(u8, s, "notStarted")) return .not_started;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "paused")) return .paused;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "declined")) return .declined;
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
