//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const EnvironmentResourceReferenceType = union(enum) {
    undefined,
    generic,
    virtual_machine,
    kubernetes,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .generic = "generic",
        .virtual_machine = "virtualMachine",
        .kubernetes = "kubernetes",
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

pub const EnvironmentDeploymentExecutionRecordResult = union(enum) {
    succeeded,
    succeeded_with_issues,
    failed,
    canceled,
    skipped,
    abandoned,
    manually_queued,
    dependent_on_manual_queue,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "succeeded",
        .succeeded_with_issues = "succeededWithIssues",
        .failed = "failed",
        .canceled = "canceled",
        .skipped = "skipped",
        .abandoned = "abandoned",
        .manually_queued = "manuallyQueued",
        .dependent_on_manual_queue = "dependentOnManualQueue",
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

pub const KubernetesResourceType = union(enum) {
    undefined,
    generic,
    virtual_machine,
    kubernetes,
    unrecognized: []const u8,

    const wire_names = .{
        .undefined = "undefined",
        .generic = "generic",
        .virtual_machine = "virtualMachine",
        .kubernetes = "kubernetes",
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

pub const TaskAgentStatus = union(enum) {
    offline,
    online,
    unrecognized: []const u8,

    const wire_names = .{
        .offline = "offline",
        .online = "online",
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

pub const TaskAgentPoolReferenceOptions = union(enum) {
    none,
    elastic_pool,
    single_use_agents,
    preserve_agent_on_job_failure,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .elastic_pool = "elasticPool",
        .single_use_agents = "singleUseAgents",
        .preserve_agent_on_job_failure = "preserveAgentOnJobFailure",
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

pub const TaskAgentPoolReferencePoolType = union(enum) {
    automation,
    deployment,
    unrecognized: []const u8,

    const wire_names = .{
        .automation = "automation",
        .deployment = "deployment",
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

pub const TaskAgentJobRequestResult = union(enum) {
    succeeded,
    succeeded_with_issues,
    failed,
    canceled,
    skipped,
    abandoned,
    manually_queued,
    dependent_on_manual_queue,
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "succeeded",
        .succeeded_with_issues = "succeededWithIssues",
        .failed = "failed",
        .canceled = "canceled",
        .skipped = "skipped",
        .abandoned = "abandoned",
        .manually_queued = "manuallyQueued",
        .dependent_on_manual_queue = "dependentOnManualQueue",
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

pub const TaskAgentUpdateReasonCode = union(enum) {
    manual,
    min_agent_version_required,
    downgrade,
    unrecognized: []const u8,

    const wire_names = .{
        .manual = "manual",
        .min_agent_version_required = "minAgentVersionRequired",
        .downgrade = "downgrade",
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
