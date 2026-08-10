//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const TestSuiteSuiteType = union(enum) {
    none,
    dynamic_test_suite,
    static_test_suite,
    requirement_test_suite,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .dynamic_test_suite = "dynamicTestSuite",
        .static_test_suite = "staticTestSuite",
        .requirement_test_suite = "requirementTestSuite",
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

pub const TestConfigurationState = union(enum) {
    active,
    inactive,
    unrecognized: []const u8,

    const wire_names = .{
        .active = "active",
        .inactive = "inactive",
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

pub const TestPointResultsFailureType = union(enum) {
    none,
    regression,
    new_issue,
    known_issue,
    unknown,
    null_value,
    max_value,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .regression = "regression",
        .new_issue = "new_Issue",
        .known_issue = "known_Issue",
        .unknown = "unknown",
        .null_value = "null_Value",
        .max_value = "maxValue",
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

pub const TestPointResultsLastResolutionState = union(enum) {
    none,
    needs_investigation,
    test_issue,
    product_issue,
    configuration_issue,
    null_value,
    max_value,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .needs_investigation = "needsInvestigation",
        .test_issue = "testIssue",
        .product_issue = "productIssue",
        .configuration_issue = "configurationIssue",
        .null_value = "nullValue",
        .max_value = "maxValue",
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

pub const TestPointResultsLastResultState = union(enum) {
    unspecified,
    pending,
    queued,
    in_progress,
    paused,
    completed,
    max_value,
    unrecognized: []const u8,

    const wire_names = .{
        .unspecified = "unspecified",
        .pending = "pending",
        .queued = "queued",
        .in_progress = "inProgress",
        .paused = "paused",
        .completed = "completed",
        .max_value = "maxValue",
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

pub const TestPointResultsOutcome = union(enum) {
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
        .max_value = "maxValue",
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

pub const TestPointResultsState = union(enum) {
    none,
    ready,
    completed,
    not_ready,
    in_progress,
    max_value,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .ready = "ready",
        .completed = "completed",
        .not_ready = "notReady",
        .in_progress = "inProgress",
        .max_value = "maxValue",
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

pub const ResultsOutcome = union(enum) {
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
        .max_value = "maxValue",
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

pub const CloneOperationCommonResponseState = union(enum) {
    failed,
    in_progress,
    queued,
    succeeded,
    unrecognized: []const u8,

    const wire_names = .{
        .failed = "failed",
        .in_progress = "inProgress",
        .queued = "queued",
        .succeeded = "succeeded",
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

pub const SuiteEntrySuiteEntryType = union(enum) {
    test_case,
    suite,
    unrecognized: []const u8,

    const wire_names = .{
        .test_case = "testCase",
        .suite = "suite",
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
