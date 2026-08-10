//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

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

pub const TestSessionSource = union(enum) {
    unknown,
    xt_desktop,
    feedback_desktop,
    xt_web,
    feedback_web,
    xt_desktop2,
    session_insights_for_all,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .xt_desktop = "xtDesktop",
        .feedback_desktop = "feedbackDesktop",
        .xt_web = "xtWeb",
        .feedback_web = "feedbackWeb",
        .xt_desktop2 = "xtDesktop2",
        .session_insights_for_all = "sessionInsightsForAll",
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

pub const TestSessionState = union(enum) {
    unspecified,
    not_started,
    in_progress,
    paused,
    completed,
    declined,
    unrecognized: []const u8,

    const wire_names = .{
        .unspecified = "unspecified",
        .not_started = "notStarted",
        .in_progress = "inProgress",
        .paused = "paused",
        .completed = "completed",
        .declined = "declined",
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
