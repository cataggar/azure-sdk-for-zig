//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

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

pub const ListRequestExpand = enum {
    none,
    settings,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .settings => "settings",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "settings")) return .settings;
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

pub const CheckIssueType = union(enum) {
    @"error",
    warning,
    unrecognized: []const u8,

    const wire_names = .{
        .@"error" = "error",
        .warning = "warning",
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

pub const GetRequestExpand = enum {
    none,
    settings,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .settings => "settings",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "settings")) return .settings;
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

pub const QueryRequestExpand = enum {
    none,
    settings,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .settings => "settings",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "settings")) return .settings;
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

pub const EvaluateRequestExpand = enum {
    none,
    resources,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .resources => "resources",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "resources")) return .resources;
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

pub const CheckRunStatus = union(enum) {
    none,
    queued,
    running,
    approved,
    rejected,
    canceled,
    timed_out,
    rerunning,
    bypassed,
    deferred,
    failed,
    completed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .queued = "queued",
        .running = "running",
        .approved = "approved",
        .rejected = "rejected",
        .canceled = "canceled",
        .timed_out = "timedOut",
        .rerunning = "rerunning",
        .bypassed = "bypassed",
        .deferred = "deferred",
        .failed = "failed",
        .completed = "completed",
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

pub const CheckRunEvaluationOrder = union(enum) {
    system,
    sanity_checks,
    pre_checks,
    production_readiness_check,
    proof_of_presence,
    production_readiness_check_deprecated,
    main,
    post_checks,
    proof_of_presence_temp,
    final,
    unrecognized: []const u8,

    const wire_names = .{
        .system = "system",
        .sanity_checks = "sanityChecks",
        .pre_checks = "preChecks",
        .production_readiness_check = "productionReadinessCheck",
        .proof_of_presence = "proofOfPresence",
        .production_readiness_check_deprecated = "productionReadinessCheckDeprecated",
        .main = "main",
        .post_checks = "postChecks",
        .proof_of_presence_temp = "proofOfPresenceTemp",
        .final = "final",
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

pub const CheckRunUpdateStatus = union(enum) {
    none,
    queued,
    running,
    approved,
    rejected,
    canceled,
    timed_out,
    rerunning,
    bypassed,
    deferred,
    failed,
    completed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .queued = "queued",
        .running = "running",
        .approved = "approved",
        .rejected = "rejected",
        .canceled = "canceled",
        .timed_out = "timedOut",
        .rerunning = "rerunning",
        .bypassed = "bypassed",
        .deferred = "deferred",
        .failed = "failed",
        .completed = "completed",
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

pub const CheckSuiteStatus = union(enum) {
    none,
    queued,
    running,
    approved,
    rejected,
    canceled,
    timed_out,
    rerunning,
    bypassed,
    deferred,
    failed,
    completed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .queued = "queued",
        .running = "running",
        .approved = "approved",
        .rejected = "rejected",
        .canceled = "canceled",
        .timed_out = "timedOut",
        .rerunning = "rerunning",
        .bypassed = "bypassed",
        .deferred = "deferred",
        .failed = "failed",
        .completed = "completed",
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

pub const GetRequestExpand1 = enum {
    none,
    resources,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .resources => "resources",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "resources")) return .resources;
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

pub const UpdateRequestExpand = enum {
    none,
    resources,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .resources => "resources",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "resources")) return .resources;
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

pub const CheckSuiteUpdateParameterAction = union(enum) {
    rerun,
    bypass,
    @"defer",
    unrecognized: []const u8,

    const wire_names = .{
        .rerun = "rerun",
        .bypass = "bypass",
        .@"defer" = "defer",
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

pub const QueryRequestState = enum {
    undefined,
    uninitiated,
    pending,
    approved,
    rejected,
    skipped,
    canceled,
    timed_out,
    deferred,
    failed,
    completed,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .uninitiated => "uninitiated",
            .pending => "pending",
            .approved => "approved",
            .rejected => "rejected",
            .skipped => "skipped",
            .canceled => "canceled",
            .timed_out => "timedOut",
            .deferred => "deferred",
            .failed => "failed",
            .completed => "completed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "uninitiated")) return .uninitiated;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "approved")) return .approved;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "skipped")) return .skipped;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "timedOut")) return .timed_out;
        if (std.mem.eql(u8, s, "deferred")) return .deferred;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "completed")) return .completed;
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

pub const ApprovalExecutionOrder = union(enum) {
    any_order,
    in_sequence,
    unrecognized: []const u8,

    const wire_names = .{
        .any_order = "anyOrder",
        .in_sequence = "inSequence",
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

pub const ApprovalPermissions = union(enum) {
    none,
    view,
    update,
    reassign,
    resource_admin,
    queue_build,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .view = "view",
        .update = "update",
        .reassign = "reassign",
        .resource_admin = "resourceAdmin",
        .queue_build = "queueBuild",
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

pub const ApprovalStatus = union(enum) {
    undefined,
    uninitiated,
    pending,
    approved,
    rejected,
    skipped,
    canceled,
    timed_out,
    deferred,
    failed,
    completed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .uninitiated = "uninitiated",
        .pending = "pending",
        .approved = "approved",
        .rejected = "rejected",
        .skipped = "skipped",
        .canceled = "canceled",
        .timed_out = "timedOut",
        .deferred = "deferred",
        .failed = "failed",
        .completed = "completed",
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

pub const ApprovalStepPermissions = union(enum) {
    none,
    view,
    update,
    reassign,
    resource_admin,
    queue_build,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .view = "view",
        .update = "update",
        .reassign = "reassign",
        .resource_admin = "resourceAdmin",
        .queue_build = "queueBuild",
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

pub const ApprovalStepStatus = union(enum) {
    undefined,
    uninitiated,
    pending,
    approved,
    rejected,
    skipped,
    canceled,
    timed_out,
    deferred,
    failed,
    completed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .uninitiated = "uninitiated",
        .pending = "pending",
        .approved = "approved",
        .rejected = "rejected",
        .skipped = "skipped",
        .canceled = "canceled",
        .timed_out = "timedOut",
        .deferred = "deferred",
        .failed = "failed",
        .completed = "completed",
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

pub const ApprovalUpdateParametersStatus = union(enum) {
    undefined,
    uninitiated,
    pending,
    approved,
    rejected,
    skipped,
    canceled,
    timed_out,
    deferred,
    failed,
    completed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .uninitiated = "uninitiated",
        .pending = "pending",
        .approved = "approved",
        .rejected = "rejected",
        .skipped = "skipped",
        .canceled = "canceled",
        .timed_out = "timedOut",
        .deferred = "deferred",
        .failed = "failed",
        .completed = "completed",
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
