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

pub const CheckIssueType = enum {
    @"error",
    warning,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .@"error" => "error",
            .warning => "warning",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "warning")) return .warning;
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

pub const CheckRunStatus = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .queued => "queued",
            .running => "running",
            .approved => "approved",
            .rejected => "rejected",
            .canceled => "canceled",
            .timed_out => "timedOut",
            .rerunning => "rerunning",
            .bypassed => "bypassed",
            .deferred => "deferred",
            .failed => "failed",
            .completed => "completed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "running")) return .running;
        if (std.mem.eql(u8, s, "approved")) return .approved;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "timedOut")) return .timed_out;
        if (std.mem.eql(u8, s, "rerunning")) return .rerunning;
        if (std.mem.eql(u8, s, "bypassed")) return .bypassed;
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

pub const CheckRunEvaluationOrder = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .system => "system",
            .sanity_checks => "sanityChecks",
            .pre_checks => "preChecks",
            .production_readiness_check => "productionReadinessCheck",
            .proof_of_presence => "proofOfPresence",
            .production_readiness_check_deprecated => "productionReadinessCheckDeprecated",
            .main => "main",
            .post_checks => "postChecks",
            .proof_of_presence_temp => "proofOfPresenceTemp",
            .final => "final",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "sanityChecks")) return .sanity_checks;
        if (std.mem.eql(u8, s, "preChecks")) return .pre_checks;
        if (std.mem.eql(u8, s, "productionReadinessCheck")) return .production_readiness_check;
        if (std.mem.eql(u8, s, "proofOfPresence")) return .proof_of_presence;
        if (std.mem.eql(u8, s, "productionReadinessCheckDeprecated")) return .production_readiness_check_deprecated;
        if (std.mem.eql(u8, s, "main")) return .main;
        if (std.mem.eql(u8, s, "postChecks")) return .post_checks;
        if (std.mem.eql(u8, s, "proofOfPresenceTemp")) return .proof_of_presence_temp;
        if (std.mem.eql(u8, s, "final")) return .final;
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

pub const CheckRunUpdateStatus = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .queued => "queued",
            .running => "running",
            .approved => "approved",
            .rejected => "rejected",
            .canceled => "canceled",
            .timed_out => "timedOut",
            .rerunning => "rerunning",
            .bypassed => "bypassed",
            .deferred => "deferred",
            .failed => "failed",
            .completed => "completed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "running")) return .running;
        if (std.mem.eql(u8, s, "approved")) return .approved;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "timedOut")) return .timed_out;
        if (std.mem.eql(u8, s, "rerunning")) return .rerunning;
        if (std.mem.eql(u8, s, "bypassed")) return .bypassed;
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

pub const CheckSuiteStatus = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .queued => "queued",
            .running => "running",
            .approved => "approved",
            .rejected => "rejected",
            .canceled => "canceled",
            .timed_out => "timedOut",
            .rerunning => "rerunning",
            .bypassed => "bypassed",
            .deferred => "deferred",
            .failed => "failed",
            .completed => "completed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "running")) return .running;
        if (std.mem.eql(u8, s, "approved")) return .approved;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "timedOut")) return .timed_out;
        if (std.mem.eql(u8, s, "rerunning")) return .rerunning;
        if (std.mem.eql(u8, s, "bypassed")) return .bypassed;
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

pub const CheckSuiteUpdateParameterAction = enum {
    rerun,
    bypass,
    @"defer",

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .rerun => "rerun",
            .bypass => "bypass",
            .@"defer" => "defer",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "rerun")) return .rerun;
        if (std.mem.eql(u8, s, "bypass")) return .bypass;
        if (std.mem.eql(u8, s, "defer")) return .@"defer";
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

pub const ApprovalExecutionOrder = enum {
    any_order,
    in_sequence,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .any_order => "anyOrder",
            .in_sequence => "inSequence",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "anyOrder")) return .any_order;
        if (std.mem.eql(u8, s, "inSequence")) return .in_sequence;
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

pub const ApprovalPermissions = enum {
    none,
    view,
    update,
    reassign,
    resource_admin,
    queue_build,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .view => "view",
            .update => "update",
            .reassign => "reassign",
            .resource_admin => "resourceAdmin",
            .queue_build => "queueBuild",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "view")) return .view;
        if (std.mem.eql(u8, s, "update")) return .update;
        if (std.mem.eql(u8, s, "reassign")) return .reassign;
        if (std.mem.eql(u8, s, "resourceAdmin")) return .resource_admin;
        if (std.mem.eql(u8, s, "queueBuild")) return .queue_build;
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

pub const ApprovalStatus = enum {
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

pub const ApprovalStepPermissions = enum {
    none,
    view,
    update,
    reassign,
    resource_admin,
    queue_build,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .view => "view",
            .update => "update",
            .reassign => "reassign",
            .resource_admin => "resourceAdmin",
            .queue_build => "queueBuild",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "view")) return .view;
        if (std.mem.eql(u8, s, "update")) return .update;
        if (std.mem.eql(u8, s, "reassign")) return .reassign;
        if (std.mem.eql(u8, s, "resourceAdmin")) return .resource_admin;
        if (std.mem.eql(u8, s, "queueBuild")) return .queue_build;
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

pub const ApprovalStepStatus = enum {
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

pub const ApprovalUpdateParametersStatus = enum {
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
