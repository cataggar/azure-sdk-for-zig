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

pub const ReleaseApprovalApprovalType = enum {
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

pub const ReleaseApprovalStatus = enum {
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

pub const ConditionConditionType = enum {
    undefined,
    event,
    environment_state,
    artifact,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .event => "event",
            .environment_state => "environmentState",
            .artifact => "artifact",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "event")) return .event;
        if (std.mem.eql(u8, s, "environmentState")) return .environment_state;
        if (std.mem.eql(u8, s, "artifact")) return .artifact;
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

pub const DeployPhasePhaseType = enum {
    undefined,
    agent_based_deployment,
    run_on_server,
    machine_group_based_deployment,
    deployment_gates,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .agent_based_deployment => "agentBasedDeployment",
            .run_on_server => "runOnServer",
            .machine_group_based_deployment => "machineGroupBasedDeployment",
            .deployment_gates => "deploymentGates",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "agentBasedDeployment")) return .agent_based_deployment;
        if (std.mem.eql(u8, s, "runOnServer")) return .run_on_server;
        if (std.mem.eql(u8, s, "machineGroupBasedDeployment")) return .machine_group_based_deployment;
        if (std.mem.eql(u8, s, "deploymentGates")) return .deployment_gates;
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

pub const EnvironmentTriggerTriggerType = enum {
    undefined,
    deployment_group_redeploy,
    rollback_redeploy,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .deployment_group_redeploy => "deploymentGroupRedeploy",
            .rollback_redeploy => "rollbackRedeploy",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "deploymentGroupRedeploy")) return .deployment_group_redeploy;
        if (std.mem.eql(u8, s, "rollbackRedeploy")) return .rollback_redeploy;
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

pub const ApprovalOptionsExecutionOrder = enum {
    before_gates,
    after_successful_gates,
    after_gates_always,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .before_gates => "beforeGates",
            .after_successful_gates => "afterSuccessfulGates",
            .after_gates_always => "afterGatesAlways",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "beforeGates")) return .before_gates;
        if (std.mem.eql(u8, s, "afterSuccessfulGates")) return .after_successful_gates;
        if (std.mem.eql(u8, s, "afterGatesAlways")) return .after_gates_always;
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

pub const ReleaseScheduleDaysToRelease = enum {
    none,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
    sunday,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .monday => "monday",
            .tuesday => "tuesday",
            .wednesday => "wednesday",
            .thursday => "thursday",
            .friday => "friday",
            .saturday => "saturday",
            .sunday => "sunday",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "monday")) return .monday;
        if (std.mem.eql(u8, s, "tuesday")) return .tuesday;
        if (std.mem.eql(u8, s, "wednesday")) return .wednesday;
        if (std.mem.eql(u8, s, "thursday")) return .thursday;
        if (std.mem.eql(u8, s, "friday")) return .friday;
        if (std.mem.eql(u8, s, "saturday")) return .saturday;
        if (std.mem.eql(u8, s, "sunday")) return .sunday;
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

pub const ReleaseReferenceReason = enum {
    none,
    manual,
    continuous_integration,
    schedule,
    pull_request,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manual => "manual",
            .continuous_integration => "continuousIntegration",
            .schedule => "schedule",
            .pull_request => "pullRequest",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manual")) return .manual;
        if (std.mem.eql(u8, s, "continuousIntegration")) return .continuous_integration;
        if (std.mem.eql(u8, s, "schedule")) return .schedule;
        if (std.mem.eql(u8, s, "pullRequest")) return .pull_request;
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

pub const ReleaseDefinitionSource = enum {
    undefined,
    rest_api,
    user_interface,
    ibiza,
    portal_extension_api,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .rest_api => "restApi",
            .user_interface => "userInterface",
            .ibiza => "ibiza",
            .portal_extension_api => "portalExtensionApi",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "restApi")) return .rest_api;
        if (std.mem.eql(u8, s, "userInterface")) return .user_interface;
        if (std.mem.eql(u8, s, "ibiza")) return .ibiza;
        if (std.mem.eql(u8, s, "portalExtensionApi")) return .portal_extension_api;
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

pub const ReleaseTriggerBaseTriggerType = enum {
    undefined,
    artifact_source,
    schedule,
    source_repo,
    container_image,
    package,
    pull_request,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .artifact_source => "artifactSource",
            .schedule => "schedule",
            .source_repo => "sourceRepo",
            .container_image => "containerImage",
            .package => "package",
            .pull_request => "pullRequest",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "artifactSource")) return .artifact_source;
        if (std.mem.eql(u8, s, "schedule")) return .schedule;
        if (std.mem.eql(u8, s, "sourceRepo")) return .source_repo;
        if (std.mem.eql(u8, s, "containerImage")) return .container_image;
        if (std.mem.eql(u8, s, "package")) return .package;
        if (std.mem.eql(u8, s, "pullRequest")) return .pull_request;
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

pub const ReleaseDefinitionRevisionChangeType = enum {
    add,
    update,
    delete,
    undelete,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .add => "add",
            .update => "update",
            .delete => "delete",
            .undelete => "undelete",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "add")) return .add;
        if (std.mem.eql(u8, s, "update")) return .update;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "undelete")) return .undelete;
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

pub const DeploymentDeploymentStatus = enum {
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

pub const DeploymentOperationStatus = enum {
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

pub const DeploymentReason = enum {
    none,
    manual,
    automated,
    scheduled,
    redeploy_trigger,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manual => "manual",
            .automated => "automated",
            .scheduled => "scheduled",
            .redeploy_trigger => "redeployTrigger",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manual")) return .manual;
        if (std.mem.eql(u8, s, "automated")) return .automated;
        if (std.mem.eql(u8, s, "scheduled")) return .scheduled;
        if (std.mem.eql(u8, s, "redeployTrigger")) return .redeploy_trigger;
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

pub const ReleaseTaskStatus = enum {
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

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .pending => "pending",
            .in_progress => "inProgress",
            .success => "success",
            .failure => "failure",
            .canceled => "canceled",
            .skipped => "skipped",
            .succeeded => "succeeded",
            .failed => "failed",
            .partially_succeeded => "partiallySucceeded",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "success")) return .success;
        if (std.mem.eql(u8, s, "failure")) return .failure;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "skipped")) return .skipped;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "partiallySucceeded")) return .partially_succeeded;
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

pub const ReleaseGatesStatus = enum {
    none,
    pending,
    in_progress,
    succeeded,
    failed,
    canceled,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .pending => "pending",
            .in_progress => "inProgress",
            .succeeded => "succeeded",
            .failed => "failed",
            .canceled => "canceled",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
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

pub const DeploymentAttemptOperationStatus = enum {
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

pub const DeploymentAttemptReason = enum {
    none,
    manual,
    automated,
    scheduled,
    redeploy_trigger,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manual => "manual",
            .automated => "automated",
            .scheduled => "scheduled",
            .redeploy_trigger => "redeployTrigger",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manual")) return .manual;
        if (std.mem.eql(u8, s, "automated")) return .automated;
        if (std.mem.eql(u8, s, "scheduled")) return .scheduled;
        if (std.mem.eql(u8, s, "redeployTrigger")) return .redeploy_trigger;
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

pub const ManualInterventionStatus = enum {
    unknown,
    pending,
    rejected,
    approved,
    canceled,
    bypassed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .pending => "pending",
            .rejected => "rejected",
            .approved => "approved",
            .canceled => "canceled",
            .bypassed => "bypassed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "approved")) return .approved;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "bypassed")) return .bypassed;
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

pub const ManualInterventionType = enum {
    task,
    proof_of_presence,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .task => "task",
            .proof_of_presence => "proofOfPresence",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "task")) return .task;
        if (std.mem.eql(u8, s, "proofOfPresence")) return .proof_of_presence;
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

pub const ReleaseDeployPhasePhaseType = enum {
    undefined,
    agent_based_deployment,
    run_on_server,
    machine_group_based_deployment,
    deployment_gates,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .agent_based_deployment => "agentBasedDeployment",
            .run_on_server => "runOnServer",
            .machine_group_based_deployment => "machineGroupBasedDeployment",
            .deployment_gates => "deploymentGates",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "agentBasedDeployment")) return .agent_based_deployment;
        if (std.mem.eql(u8, s, "runOnServer")) return .run_on_server;
        if (std.mem.eql(u8, s, "machineGroupBasedDeployment")) return .machine_group_based_deployment;
        if (std.mem.eql(u8, s, "deploymentGates")) return .deployment_gates;
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

pub const ReleaseDeployPhaseStatus = enum {
    undefined,
    not_started,
    in_progress,
    partially_succeeded,
    succeeded,
    failed,
    canceled,
    skipped,
    cancelling,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .not_started => "notStarted",
            .in_progress => "inProgress",
            .partially_succeeded => "partiallySucceeded",
            .succeeded => "succeeded",
            .failed => "failed",
            .canceled => "canceled",
            .skipped => "skipped",
            .cancelling => "cancelling",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "notStarted")) return .not_started;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "partiallySucceeded")) return .partially_succeeded;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "skipped")) return .skipped;
        if (std.mem.eql(u8, s, "cancelling")) return .cancelling;
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

pub const DeploymentAttemptStatus = enum {
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

pub const ReleaseEnvironmentStatus = enum {
    undefined,
    not_started,
    in_progress,
    succeeded,
    canceled,
    rejected,
    queued,
    scheduled,
    partially_succeeded,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .not_started => "notStarted",
            .in_progress => "inProgress",
            .succeeded => "succeeded",
            .canceled => "canceled",
            .rejected => "rejected",
            .queued => "queued",
            .scheduled => "scheduled",
            .partially_succeeded => "partiallySucceeded",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "notStarted")) return .not_started;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "scheduled")) return .scheduled;
        if (std.mem.eql(u8, s, "partiallySucceeded")) return .partially_succeeded;
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

pub const ReleaseReason = enum {
    none,
    manual,
    continuous_integration,
    schedule,
    pull_request,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manual => "manual",
            .continuous_integration => "continuousIntegration",
            .schedule => "schedule",
            .pull_request => "pullRequest",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manual")) return .manual;
        if (std.mem.eql(u8, s, "continuousIntegration")) return .continuous_integration;
        if (std.mem.eql(u8, s, "schedule")) return .schedule;
        if (std.mem.eql(u8, s, "pullRequest")) return .pull_request;
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

pub const ReleaseStatus = enum {
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

pub const ReleaseStartMetadataReason = enum {
    none,
    manual,
    continuous_integration,
    schedule,
    pull_request,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manual => "manual",
            .continuous_integration => "continuousIntegration",
            .schedule => "schedule",
            .pull_request => "pullRequest",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manual")) return .manual;
        if (std.mem.eql(u8, s, "continuousIntegration")) return .continuous_integration;
        if (std.mem.eql(u8, s, "schedule")) return .schedule;
        if (std.mem.eql(u8, s, "pullRequest")) return .pull_request;
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

pub const ReleaseUpdateMetadataStatus = enum {
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

pub const ReleaseEnvironmentUpdateMetadataStatus = enum {
    undefined,
    not_started,
    in_progress,
    succeeded,
    canceled,
    rejected,
    queued,
    scheduled,
    partially_succeeded,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .not_started => "notStarted",
            .in_progress => "inProgress",
            .succeeded => "succeeded",
            .canceled => "canceled",
            .rejected => "rejected",
            .queued => "queued",
            .scheduled => "scheduled",
            .partially_succeeded => "partiallySucceeded",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "notStarted")) return .not_started;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "scheduled")) return .scheduled;
        if (std.mem.eql(u8, s, "partiallySucceeded")) return .partially_succeeded;
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

pub const ManualInterventionUpdateMetadataStatus = enum {
    unknown,
    pending,
    rejected,
    approved,
    canceled,
    bypassed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .pending => "pending",
            .rejected => "rejected",
            .approved => "approved",
            .canceled => "canceled",
            .bypassed => "bypassed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "rejected")) return .rejected;
        if (std.mem.eql(u8, s, "approved")) return .approved;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "bypassed")) return .bypassed;
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
