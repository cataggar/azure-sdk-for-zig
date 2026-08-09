//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const TestSuiteSuiteType = enum {
    none,
    dynamic_test_suite,
    static_test_suite,
    requirement_test_suite,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .dynamic_test_suite => "dynamicTestSuite",
            .static_test_suite => "staticTestSuite",
            .requirement_test_suite => "requirementTestSuite",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "dynamicTestSuite")) return .dynamic_test_suite;
        if (std.mem.eql(u8, s, "staticTestSuite")) return .static_test_suite;
        if (std.mem.eql(u8, s, "requirementTestSuite")) return .requirement_test_suite;
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

pub const GetTestSuitesForPlanRequestExpand = enum {
    none,
    children,
    default_testers,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .children => "children",
            .default_testers => "defaultTesters",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "children")) return .children;
        if (std.mem.eql(u8, s, "defaultTesters")) return .default_testers;
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

pub const GetRequestExpand = enum {
    none,
    children,
    default_testers,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .children => "children",
            .default_testers => "defaultTesters",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "children")) return .children;
        if (std.mem.eql(u8, s, "defaultTesters")) return .default_testers;
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

pub const TestConfigurationState = enum {
    active,
    inactive,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .active => "active",
            .inactive => "inactive",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "inactive")) return .inactive;
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

pub const GetTestCaseListRequestExcludeFlags = enum {
    none,
    point_assignments,
    extra_information,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .point_assignments => "pointAssignments",
            .extra_information => "extraInformation",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "pointAssignments")) return .point_assignments;
        if (std.mem.eql(u8, s, "extraInformation")) return .extra_information;
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

pub const TestPointResultsFailureType = enum {
    none,
    regression,
    new_issue,
    known_issue,
    unknown,
    null_value,
    max_value,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .regression => "regression",
            .new_issue => "new_Issue",
            .known_issue => "known_Issue",
            .unknown => "unknown",
            .null_value => "null_Value",
            .max_value => "maxValue",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "regression")) return .regression;
        if (std.mem.eql(u8, s, "new_Issue")) return .new_issue;
        if (std.mem.eql(u8, s, "known_Issue")) return .known_issue;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "null_Value")) return .null_value;
        if (std.mem.eql(u8, s, "maxValue")) return .max_value;
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

pub const TestPointResultsLastResolutionState = enum {
    none,
    needs_investigation,
    test_issue,
    product_issue,
    configuration_issue,
    null_value,
    max_value,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .needs_investigation => "needsInvestigation",
            .test_issue => "testIssue",
            .product_issue => "productIssue",
            .configuration_issue => "configurationIssue",
            .null_value => "nullValue",
            .max_value => "maxValue",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "needsInvestigation")) return .needs_investigation;
        if (std.mem.eql(u8, s, "testIssue")) return .test_issue;
        if (std.mem.eql(u8, s, "productIssue")) return .product_issue;
        if (std.mem.eql(u8, s, "configurationIssue")) return .configuration_issue;
        if (std.mem.eql(u8, s, "nullValue")) return .null_value;
        if (std.mem.eql(u8, s, "maxValue")) return .max_value;
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

pub const TestPointResultsLastResultState = enum {
    unspecified,
    pending,
    queued,
    in_progress,
    paused,
    completed,
    max_value,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unspecified => "unspecified",
            .pending => "pending",
            .queued => "queued",
            .in_progress => "inProgress",
            .paused => "paused",
            .completed => "completed",
            .max_value => "maxValue",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unspecified")) return .unspecified;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "paused")) return .paused;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "maxValue")) return .max_value;
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

pub const TestPointResultsOutcome = enum {
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
    max_value,

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
            .max_value => "maxValue",
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
        if (std.mem.eql(u8, s, "maxValue")) return .max_value;
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

pub const TestPointResultsState = enum {
    none,
    ready,
    completed,
    not_ready,
    in_progress,
    max_value,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .ready => "ready",
            .completed => "completed",
            .not_ready => "notReady",
            .in_progress => "inProgress",
            .max_value => "maxValue",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "ready")) return .ready;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "notReady")) return .not_ready;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "maxValue")) return .max_value;
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

pub const ResultsOutcome = enum {
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
    max_value,

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
            .max_value => "maxValue",
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
        if (std.mem.eql(u8, s, "maxValue")) return .max_value;
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

pub const CloneOperationCommonResponseState = enum {
    failed,
    in_progress,
    queued,
    succeeded,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .failed => "failed",
            .in_progress => "inProgress",
            .queued => "queued",
            .succeeded => "succeeded",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
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

pub const GetDeletedTestSuitesForPlanRequestExpand = enum {
    none,
    children,
    default_testers,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .children => "children",
            .default_testers => "defaultTesters",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "children")) return .children;
        if (std.mem.eql(u8, s, "defaultTesters")) return .default_testers;
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

pub const GetDeletedTestSuitesForProjectRequestExpand = enum {
    none,
    children,
    default_testers,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .children => "children",
            .default_testers => "defaultTesters",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "children")) return .children;
        if (std.mem.eql(u8, s, "defaultTesters")) return .default_testers;
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

pub const ListRequestSuiteEntryType = enum {
    test_case,
    suite,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .test_case => "testCase",
            .suite => "suite",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "testCase")) return .test_case;
        if (std.mem.eql(u8, s, "suite")) return .suite;
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

pub const SuiteEntrySuiteEntryType = enum {
    test_case,
    suite,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .test_case => "testCase",
            .suite => "suite",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "testCase")) return .test_case;
        if (std.mem.eql(u8, s, "suite")) return .suite;
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
