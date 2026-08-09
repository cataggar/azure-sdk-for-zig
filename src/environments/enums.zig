//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const EnvironmentResourceReferenceType = enum {
    undefined,
    generic,
    virtual_machine,
    kubernetes,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .generic => "generic",
            .virtual_machine => "virtualMachine",
            .kubernetes => "kubernetes",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "generic")) return .generic;
        if (std.mem.eql(u8, s, "virtualMachine")) return .virtual_machine;
        if (std.mem.eql(u8, s, "kubernetes")) return .kubernetes;
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

pub const GetRequestExpands = enum {
    none,
    resource_references,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .resource_references => "resourceReferences",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "resourceReferences")) return .resource_references;
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

pub const EnvironmentDeploymentExecutionRecordResult = enum {
    succeeded,
    succeeded_with_issues,
    failed,
    canceled,
    skipped,
    abandoned,
    manually_queued,
    dependent_on_manual_queue,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .succeeded => "succeeded",
            .succeeded_with_issues => "succeededWithIssues",
            .failed => "failed",
            .canceled => "canceled",
            .skipped => "skipped",
            .abandoned => "abandoned",
            .manually_queued => "manuallyQueued",
            .dependent_on_manual_queue => "dependentOnManualQueue",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "succeededWithIssues")) return .succeeded_with_issues;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "skipped")) return .skipped;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        if (std.mem.eql(u8, s, "manuallyQueued")) return .manually_queued;
        if (std.mem.eql(u8, s, "dependentOnManualQueue")) return .dependent_on_manual_queue;
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

pub const KubernetesResourceType = enum {
    undefined,
    generic,
    virtual_machine,
    kubernetes,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .undefined => "undefined",
            .generic => "generic",
            .virtual_machine => "virtualMachine",
            .kubernetes => "kubernetes",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "undefined")) return .undefined;
        if (std.mem.eql(u8, s, "generic")) return .generic;
        if (std.mem.eql(u8, s, "virtualMachine")) return .virtual_machine;
        if (std.mem.eql(u8, s, "kubernetes")) return .kubernetes;
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

pub const TaskAgentStatus = enum {
    offline,
    online,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .offline => "offline",
            .online => "online",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "offline")) return .offline;
        if (std.mem.eql(u8, s, "online")) return .online;
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

pub const TaskAgentPoolReferenceOptions = enum {
    none,
    elastic_pool,
    single_use_agents,
    preserve_agent_on_job_failure,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .elastic_pool => "elasticPool",
            .single_use_agents => "singleUseAgents",
            .preserve_agent_on_job_failure => "preserveAgentOnJobFailure",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "elasticPool")) return .elastic_pool;
        if (std.mem.eql(u8, s, "singleUseAgents")) return .single_use_agents;
        if (std.mem.eql(u8, s, "preserveAgentOnJobFailure")) return .preserve_agent_on_job_failure;
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

pub const TaskAgentPoolReferencePoolType = enum {
    automation,
    deployment,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .automation => "automation",
            .deployment => "deployment",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "automation")) return .automation;
        if (std.mem.eql(u8, s, "deployment")) return .deployment;
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

pub const TaskAgentJobRequestResult = enum {
    succeeded,
    succeeded_with_issues,
    failed,
    canceled,
    skipped,
    abandoned,
    manually_queued,
    dependent_on_manual_queue,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .succeeded => "succeeded",
            .succeeded_with_issues => "succeededWithIssues",
            .failed => "failed",
            .canceled => "canceled",
            .skipped => "skipped",
            .abandoned => "abandoned",
            .manually_queued => "manuallyQueued",
            .dependent_on_manual_queue => "dependentOnManualQueue",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "succeededWithIssues")) return .succeeded_with_issues;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "canceled")) return .canceled;
        if (std.mem.eql(u8, s, "skipped")) return .skipped;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        if (std.mem.eql(u8, s, "manuallyQueued")) return .manually_queued;
        if (std.mem.eql(u8, s, "dependentOnManualQueue")) return .dependent_on_manual_queue;
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

pub const TaskAgentUpdateReasonCode = enum {
    manual,
    min_agent_version_required,
    downgrade,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .manual => "manual",
            .min_agent_version_required => "minAgentVersionRequired",
            .downgrade => "downgrade",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "manual")) return .manual;
        if (std.mem.eql(u8, s, "minAgentVersionRequired")) return .min_agent_version_required;
        if (std.mem.eql(u8, s, "downgrade")) return .downgrade;
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
