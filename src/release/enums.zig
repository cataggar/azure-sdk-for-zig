//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const ListRequestStatusFilter = enum {
    undefined,
    pending,
    approved,
    rejected,
    reassigned,
    canceled,
    skipped,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .pending => "pending",
            .approved => "approved",
            .rejected => "rejected",
            .reassigned => "reassigned",
            .canceled => "canceled",
            .skipped => "skipped",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "approved")) return .approved;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "reassigned")) return .reassigned;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "skipped")) return .skipped;
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

pub const ListRequestTypeFilter = enum {
    undefined,
    pre_deploy,
    post_deploy,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .pre_deploy => "preDeploy",
            .post_deploy => "postDeploy",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "preDeploy")) return .pre_deploy;
        if (std.mem.eql(u8, s, "postDeploy")) return .post_deploy;
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

pub const ListRequestQueryOrder = enum {
    descending,
    ascending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .descending => "descending",
            .ascending => "ascending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "descending")) return .descending;
        if (std.mem.eql(u8, s, "ascending")) return .ascending;
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

pub const ReleaseApprovalApprovalType = union(enum) {
    undefined,
    pre_deploy,
    post_deploy,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .pre_deploy = "preDeploy",
        .post_deploy = "postDeploy",
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

pub const ReleaseApprovalStatus = union(enum) {
    undefined,
    pending,
    approved,
    rejected,
    reassigned,
    canceled,
    skipped,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .pending = "pending",
        .approved = "approved",
        .rejected = "rejected",
        .reassigned = "reassigned",
        .canceled = "canceled",
        .skipped = "skipped",
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

pub const ListRequestExpand = enum {
    none,
    environments,
    artifacts,
    triggers,
    variables,
    tags,
    last_release,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .environments => "environments",
            .artifacts => "artifacts",
            .triggers => "triggers",
            .variables => "variables",
            .tags => "tags",
            .last_release => "lastRelease",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "environments")) return .environments;
        if (std.mem.eql(u8, s, "artifacts")) return .artifacts;
        if (std.mem.eql(u8, s, "triggers")) return .triggers;
        if (std.mem.eql(u8, s, "variables")) return .variables;
        if (std.mem.eql(u8, s, "tags")) return .tags;
        if (std.mem.eql(u8, s, "lastRelease")) return .last_release;
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

pub const ListRequestQueryOrder1 = enum {
    id_ascending,
    id_descending,
    name_ascending,
    name_descending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .id_ascending => "idAscending",
            .id_descending => "idDescending",
            .name_ascending => "nameAscending",
            .name_descending => "nameDescending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "idAscending")) return .id_ascending;
        if (std.mem.eql(u8, s, "idDescending")) return .id_descending;
        if (std.mem.eql(u8, s, "nameAscending")) return .name_ascending;
        if (std.mem.eql(u8, s, "nameDescending")) return .name_descending;
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

pub const ConditionConditionType = union(enum) {
    undefined,
    event,
    environment_state,
    artifact,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .event = "event",
        .environment_state = "environmentState",
        .artifact = "artifact",
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

pub const DeployPhasePhaseType = union(enum) {
    undefined,
    agent_based_deployment,
    run_on_server,
    machine_group_based_deployment,
    deployment_gates,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .agent_based_deployment = "agentBasedDeployment",
        .run_on_server = "runOnServer",
        .machine_group_based_deployment = "machineGroupBasedDeployment",
        .deployment_gates = "deploymentGates",
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

pub const EnvironmentTriggerTriggerType = union(enum) {
    undefined,
    deployment_group_redeploy,
    rollback_redeploy,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .deployment_group_redeploy = "deploymentGroupRedeploy",
        .rollback_redeploy = "rollbackRedeploy",
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

pub const ApprovalOptionsExecutionOrder = union(enum) {
    before_gates,
    after_successful_gates,
    after_gates_always,
    unrecognized: []const u8,

    const wire_names = .{
        .before_gates = "beforeGates",
        .after_successful_gates = "afterSuccessfulGates",
        .after_gates_always = "afterGatesAlways",
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

pub const ReleaseScheduleDaysToRelease = union(enum) {
    none,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .monday = "monday",
        .tuesday = "tuesday",
        .wednesday = "wednesday",
        .thursday = "thursday",
        .friday = "friday",
        .saturday = "saturday",
        .sunday = "sunday",
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

pub const ReleaseReferenceReason = union(enum) {
    none,
    manual,
    continuous_integration,
    schedule,
    pull_request,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .manual = "manual",
        .continuous_integration = "continuousIntegration",
        .schedule = "schedule",
        .pull_request = "pullRequest",
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

pub const ReleaseDefinitionSource = union(enum) {
    undefined,
    rest_api,
    user_interface,
    ibiza,
    portal_extension_api,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .rest_api = "restApi",
        .user_interface = "userInterface",
        .ibiza = "ibiza",
        .portal_extension_api = "portalExtensionApi",
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

pub const ReleaseTriggerBaseTriggerType = union(enum) {
    undefined,
    artifact_source,
    schedule,
    source_repo,
    container_image,
    package,
    pull_request,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .artifact_source = "artifactSource",
        .schedule = "schedule",
        .source_repo = "sourceRepo",
        .container_image = "containerImage",
        .package = "package",
        .pull_request = "pullRequest",
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

pub const ReleaseDefinitionRevisionChangeType = union(enum) {
    add,
    update,
    delete,
    undelete,
    unrecognized: []const u8,

    const wire_names = .{
        .add = "add",
        .update = "update",
        .delete = "delete",
        .undelete = "undelete",
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

pub const ListRequestDeploymentStatus = enum {
    undefined,
    not_deployed,
    in_progress,
    succeeded,
    partially_succeeded,
    failed,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .not_deployed => "notDeployed",
            .in_progress => "inProgress",
            .succeeded => "succeeded",
            .partially_succeeded => "partiallySucceeded",
            .failed => "failed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "notDeployed")) return .not_deployed;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "partiallySucceeded")) return .partially_succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
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

pub const ListRequestOperationStatus = enum {
    undefined,
    queued,
    scheduled,
    pending,
    approved,
    rejected,
    deferred,
    queued_for_agent,
    phase_in_progress,
    phase_succeeded,
    phase_partially_succeeded,
    phase_failed,
    canceled,
    phase_canceled,
    manual_intervention_pending,
    queued_for_pipeline,
    cancelling,
    evaluating_gates,
    gate_failed,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .queued => "queued",
            .scheduled => "scheduled",
            .pending => "pending",
            .approved => "approved",
            .rejected => "rejected",
            .deferred => "deferred",
            .queued_for_agent => "queuedForAgent",
            .phase_in_progress => "phaseInProgress",
            .phase_succeeded => "phaseSucceeded",
            .phase_partially_succeeded => "phasePartiallySucceeded",
            .phase_failed => "phaseFailed",
            .canceled => "canceled",
            .phase_canceled => "phaseCanceled",
            .manual_intervention_pending => "manualInterventionPending",
            .queued_for_pipeline => "queuedForPipeline",
            .cancelling => "cancelling",
            .evaluating_gates => "evaluatingGates",
            .gate_failed => "gateFailed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "scheduled")) return .scheduled;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "approved")) return .approved;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "deferred")) return .deferred;
        if (std.mem.eql(u8, s, "queuedForAgent")) return .queued_for_agent;
        if (std.mem.eql(u8, s, "phaseInProgress")) return .phase_in_progress;
        if (std.mem.eql(u8, s, "phaseSucceeded")) return .phase_succeeded;
        if (std.mem.eql(u8, s, "phasePartiallySucceeded")) return .phase_partially_succeeded;
        if (std.mem.eql(u8, s, "phaseFailed")) return .phase_failed;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "phaseCanceled")) return .phase_canceled;
        if (std.mem.eql(u8, s, "manualInterventionPending")) return .manual_intervention_pending;
        if (std.mem.eql(u8, s, "queuedForPipeline")) return .queued_for_pipeline;
        if (std.mem.eql(u8, s, "cancelling")) return .cancelling;
        if (std.mem.eql(u8, s, "evaluatingGates")) return .evaluating_gates;
        if (std.mem.eql(u8, s, "gateFailed")) return .gate_failed;
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

pub const ListRequestQueryOrder2 = enum {
    descending,
    ascending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .descending => "descending",
            .ascending => "ascending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "descending")) return .descending;
        if (std.mem.eql(u8, s, "ascending")) return .ascending;
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

pub const DeploymentDeploymentStatus = union(enum) {
    undefined,
    not_deployed,
    in_progress,
    succeeded,
    partially_succeeded,
    failed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .not_deployed = "notDeployed",
        .in_progress = "inProgress",
        .succeeded = "succeeded",
        .partially_succeeded = "partiallySucceeded",
        .failed = "failed",
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

pub const DeploymentOperationStatus = union(enum) {
    undefined,
    queued,
    scheduled,
    pending,
    approved,
    rejected,
    deferred,
    queued_for_agent,
    phase_in_progress,
    phase_succeeded,
    phase_partially_succeeded,
    phase_failed,
    canceled,
    phase_canceled,
    manual_intervention_pending,
    queued_for_pipeline,
    cancelling,
    evaluating_gates,
    gate_failed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .queued = "queued",
        .scheduled = "scheduled",
        .pending = "pending",
        .approved = "approved",
        .rejected = "rejected",
        .deferred = "deferred",
        .queued_for_agent = "queuedForAgent",
        .phase_in_progress = "phaseInProgress",
        .phase_succeeded = "phaseSucceeded",
        .phase_partially_succeeded = "phasePartiallySucceeded",
        .phase_failed = "phaseFailed",
        .canceled = "canceled",
        .phase_canceled = "phaseCanceled",
        .manual_intervention_pending = "manualInterventionPending",
        .queued_for_pipeline = "queuedForPipeline",
        .cancelling = "cancelling",
        .evaluating_gates = "evaluatingGates",
        .gate_failed = "gateFailed",
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

pub const DeploymentReason = union(enum) {
    none,
    manual,
    automated,
    scheduled,
    redeploy_trigger,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .manual = "manual",
        .automated = "automated",
        .scheduled = "scheduled",
        .redeploy_trigger = "redeployTrigger",
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

pub const ListRequestQueryOrder3 = enum {
    none,
    ascending,
    descending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .ascending => "ascending",
            .descending => "descending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "ascending")) return .ascending;
        if (std.mem.eql(u8, s, "descending")) return .descending;
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

pub const ReleaseTaskStatus = union(enum) {
    unknown,
    pending,
    in_progress,
    success,
    failure,
    canceled,
    skipped,
    succeeded,
    failed,
    partially_succeeded,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .pending = "pending",
        .in_progress = "inProgress",
        .success = "success",
        .failure = "failure",
        .canceled = "canceled",
        .skipped = "skipped",
        .succeeded = "succeeded",
        .failed = "failed",
        .partially_succeeded = "partiallySucceeded",
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

pub const ReleaseGatesStatus = union(enum) {
    none,
    pending,
    in_progress,
    succeeded,
    failed,
    canceled,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .pending = "pending",
        .in_progress = "inProgress",
        .succeeded = "succeeded",
        .failed = "failed",
        .canceled = "canceled",
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

pub const ListRequestStatusFilter1 = enum {
    undefined,
    draft,
    active,
    abandoned,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .draft => "draft",
            .active => "active",
            .abandoned => "abandoned",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "draft")) return .draft;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
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

pub const ListRequestQueryOrder4 = enum {
    descending,
    ascending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .descending => "descending",
            .ascending => "ascending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "descending")) return .descending;
        if (std.mem.eql(u8, s, "ascending")) return .ascending;
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

pub const ListRequestExpand1 = enum {
    none,
    environments,
    artifacts,
    approvals,
    manual_interventions,
    variables,
    tags,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .environments => "environments",
            .artifacts => "artifacts",
            .approvals => "approvals",
            .manual_interventions => "manualInterventions",
            .variables => "variables",
            .tags => "tags",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "environments")) return .environments;
        if (std.mem.eql(u8, s, "artifacts")) return .artifacts;
        if (std.mem.eql(u8, s, "approvals")) return .approvals;
        if (std.mem.eql(u8, s, "manualInterventions")) return .manual_interventions;
        if (std.mem.eql(u8, s, "variables")) return .variables;
        if (std.mem.eql(u8, s, "tags")) return .tags;
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

pub const DeploymentAttemptOperationStatus = union(enum) {
    undefined,
    queued,
    scheduled,
    pending,
    approved,
    rejected,
    deferred,
    queued_for_agent,
    phase_in_progress,
    phase_succeeded,
    phase_partially_succeeded,
    phase_failed,
    canceled,
    phase_canceled,
    manual_intervention_pending,
    queued_for_pipeline,
    cancelling,
    evaluating_gates,
    gate_failed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .queued = "queued",
        .scheduled = "scheduled",
        .pending = "pending",
        .approved = "approved",
        .rejected = "rejected",
        .deferred = "deferred",
        .queued_for_agent = "queuedForAgent",
        .phase_in_progress = "phaseInProgress",
        .phase_succeeded = "phaseSucceeded",
        .phase_partially_succeeded = "phasePartiallySucceeded",
        .phase_failed = "phaseFailed",
        .canceled = "canceled",
        .phase_canceled = "phaseCanceled",
        .manual_intervention_pending = "manualInterventionPending",
        .queued_for_pipeline = "queuedForPipeline",
        .cancelling = "cancelling",
        .evaluating_gates = "evaluatingGates",
        .gate_failed = "gateFailed",
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

pub const DeploymentAttemptReason = union(enum) {
    none,
    manual,
    automated,
    scheduled,
    redeploy_trigger,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .manual = "manual",
        .automated = "automated",
        .scheduled = "scheduled",
        .redeploy_trigger = "redeployTrigger",
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

pub const ManualInterventionStatus = union(enum) {
    unknown,
    pending,
    rejected,
    approved,
    canceled,
    bypassed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .pending = "pending",
        .rejected = "rejected",
        .approved = "approved",
        .canceled = "canceled",
        .bypassed = "bypassed",
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

pub const ManualInterventionType = union(enum) {
    task,
    proof_of_presence,
    unrecognized: []const u8,

    const wire_names = .{
        .task = "task",
        .proof_of_presence = "proofOfPresence",
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

pub const ReleaseDeployPhasePhaseType = union(enum) {
    undefined,
    agent_based_deployment,
    run_on_server,
    machine_group_based_deployment,
    deployment_gates,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .agent_based_deployment = "agentBasedDeployment",
        .run_on_server = "runOnServer",
        .machine_group_based_deployment = "machineGroupBasedDeployment",
        .deployment_gates = "deploymentGates",
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

pub const ReleaseDeployPhaseStatus = union(enum) {
    undefined,
    not_started,
    in_progress,
    partially_succeeded,
    succeeded,
    failed,
    canceled,
    skipped,
    cancelling,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .not_started = "notStarted",
        .in_progress = "inProgress",
        .partially_succeeded = "partiallySucceeded",
        .succeeded = "succeeded",
        .failed = "failed",
        .canceled = "canceled",
        .skipped = "skipped",
        .cancelling = "cancelling",
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

pub const DeploymentAttemptStatus = union(enum) {
    undefined,
    not_deployed,
    in_progress,
    succeeded,
    partially_succeeded,
    failed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .not_deployed = "notDeployed",
        .in_progress = "inProgress",
        .succeeded = "succeeded",
        .partially_succeeded = "partiallySucceeded",
        .failed = "failed",
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

pub const ReleaseEnvironmentStatus = union(enum) {
    undefined,
    not_started,
    in_progress,
    succeeded,
    canceled,
    rejected,
    queued,
    scheduled,
    partially_succeeded,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .not_started = "notStarted",
        .in_progress = "inProgress",
        .succeeded = "succeeded",
        .canceled = "canceled",
        .rejected = "rejected",
        .queued = "queued",
        .scheduled = "scheduled",
        .partially_succeeded = "partiallySucceeded",
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

pub const ReleaseReason = union(enum) {
    none,
    manual,
    continuous_integration,
    schedule,
    pull_request,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .manual = "manual",
        .continuous_integration = "continuousIntegration",
        .schedule = "schedule",
        .pull_request = "pullRequest",
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

pub const ReleaseStatus = union(enum) {
    undefined,
    draft,
    active,
    abandoned,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .draft = "draft",
        .active = "active",
        .abandoned = "abandoned",
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

pub const ReleaseStartMetadataReason = union(enum) {
    none,
    manual,
    continuous_integration,
    schedule,
    pull_request,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .manual = "manual",
        .continuous_integration = "continuousIntegration",
        .schedule = "schedule",
        .pull_request = "pullRequest",
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

pub const ReleaseUpdateMetadataStatus = union(enum) {
    undefined,
    draft,
    active,
    abandoned,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .draft = "draft",
        .active = "active",
        .abandoned = "abandoned",
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

pub const GetReleaseEnvironmentRequestExpand = enum {
    none,
    tasks,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .tasks => "tasks",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "tasks")) return .tasks;
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

pub const ReleaseEnvironmentUpdateMetadataStatus = union(enum) {
    undefined,
    not_started,
    in_progress,
    succeeded,
    canceled,
    rejected,
    queued,
    scheduled,
    partially_succeeded,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .not_started = "notStarted",
        .in_progress = "inProgress",
        .succeeded = "succeeded",
        .canceled = "canceled",
        .rejected = "rejected",
        .queued = "queued",
        .scheduled = "scheduled",
        .partially_succeeded = "partiallySucceeded",
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

pub const ManualInterventionUpdateMetadataStatus = union(enum) {
    unknown,
    pending,
    rejected,
    approved,
    canceled,
    bypassed,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .pending = "pending",
        .rejected = "rejected",
        .approved = "approved",
        .canceled = "canceled",
        .bypassed = "bypassed",
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
