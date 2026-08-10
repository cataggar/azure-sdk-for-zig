//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const ElasticPoolOrchestrationType = union(enum) {
    uniform,
    flexible,
    unrecognized: []const u8,

    const wire_names = .{
        .uniform = "uniform",
        .flexible = "flexible",
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

pub const ElasticPoolOsType = union(enum) {
    windows,
    linux,
    unrecognized: []const u8,

    const wire_names = .{
        .windows = "windows",
        .linux = "linux",
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

pub const ElasticPoolState = union(enum) {
    online,
    offline,
    unhealthy,
    new,
    unrecognized: []const u8,

    const wire_names = .{
        .online = "online",
        .offline = "offline",
        .unhealthy = "unhealthy",
        .new = "new",
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

pub const TaskAgentPoolOptions = union(enum) {
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

pub const TaskAgentPoolPoolType = union(enum) {
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

pub const ElasticPoolSettingsOrchestrationType = union(enum) {
    uniform,
    flexible,
    unrecognized: []const u8,

    const wire_names = .{
        .uniform = "uniform",
        .flexible = "flexible",
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

pub const ElasticPoolSettingsOsType = union(enum) {
    windows,
    linux,
    unrecognized: []const u8,

    const wire_names = .{
        .windows = "windows",
        .linux = "linux",
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

pub const ElasticPoolLogLevel = union(enum) {
    @"error",
    warning,
    info,
    unrecognized: []const u8,

    const wire_names = .{
        .@"error" = "error",
        .warning = "warning",
        .info = "info",
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

pub const ElasticPoolLogOperation = union(enum) {
    configuration_job,
    sizing_job,
    increase_capacity,
    reimage,
    delete_v_ms,
    unrecognized: []const u8,

    const wire_names = .{
        .configuration_job = "configurationJob",
        .sizing_job = "sizingJob",
        .increase_capacity = "increaseCapacity",
        .reimage = "reimage",
        .delete_v_ms = "deleteVMs",
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

pub const ListRequestState = enum {
    none,
    new,
    creating_compute,
    starting_agent,
    idle,
    assigned,
    offline,
    pending_reimage,
    pending_delete,
    saved,
    deleting_compute,
    deleted,
    lost,
    reimaging_compute,
    restarting_agent,
    failed_to_start_pending_delete,
    failed_to_restart_pending_delete,
    failed_vm_pending_delete,
    assigned_pending_delete,
    retry_delete,
    unhealthy_vm,
    unhealthy_vm_pending_delete,
    pending_reimage_candidate,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .new => "new",
            .creating_compute => "creatingCompute",
            .starting_agent => "startingAgent",
            .idle => "idle",
            .assigned => "assigned",
            .offline => "offline",
            .pending_reimage => "pendingReimage",
            .pending_delete => "pendingDelete",
            .saved => "saved",
            .deleting_compute => "deletingCompute",
            .deleted => "deleted",
            .lost => "lost",
            .reimaging_compute => "reimagingCompute",
            .restarting_agent => "restartingAgent",
            .failed_to_start_pending_delete => "failedToStartPendingDelete",
            .failed_to_restart_pending_delete => "failedToRestartPendingDelete",
            .failed_vm_pending_delete => "failedVMPendingDelete",
            .assigned_pending_delete => "assignedPendingDelete",
            .retry_delete => "retryDelete",
            .unhealthy_vm => "unhealthyVm",
            .unhealthy_vm_pending_delete => "unhealthyVmPendingDelete",
            .pending_reimage_candidate => "pendingReimageCandidate",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "new")) return .new;
        if (std.mem.eql(u8, s, "creatingCompute")) return .creating_compute;
        if (std.mem.eql(u8, s, "startingAgent")) return .starting_agent;
        if (std.mem.eql(u8, s, "idle")) return .idle;
        if (std.mem.eql(u8, s, "assigned")) return .assigned;
        if (std.mem.eql(u8, s, "offline")) return .offline;
        if (std.mem.eql(u8, s, "pendingReimage")) return .pending_reimage;
        if (std.mem.eql(u8, s, "pendingDelete")) return .pending_delete;
        if (std.mem.eql(u8, s, "saved")) return .saved;
        if (std.mem.eql(u8, s, "deletingCompute")) return .deleting_compute;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
        if (std.mem.eql(u8, s, "lost")) return .lost;
        if (std.mem.eql(u8, s, "reimagingCompute")) return .reimaging_compute;
        if (std.mem.eql(u8, s, "restartingAgent")) return .restarting_agent;
        if (std.mem.eql(u8, s, "failedToStartPendingDelete")) return .failed_to_start_pending_delete;
        if (std.mem.eql(u8, s, "failedToRestartPendingDelete")) return .failed_to_restart_pending_delete;
        if (std.mem.eql(u8, s, "failedVMPendingDelete")) return .failed_vm_pending_delete;
        if (std.mem.eql(u8, s, "assignedPendingDelete")) return .assigned_pending_delete;
        if (std.mem.eql(u8, s, "retryDelete")) return .retry_delete;
        if (std.mem.eql(u8, s, "unhealthyVm")) return .unhealthy_vm;
        if (std.mem.eql(u8, s, "unhealthyVmPendingDelete")) return .unhealthy_vm_pending_delete;
        if (std.mem.eql(u8, s, "pendingReimageCandidate")) return .pending_reimage_candidate;
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

pub const ElasticNodeAgentState = union(enum) {
    none,
    enabled,
    online,
    assigned,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .enabled = "enabled",
        .online = "online",
        .assigned = "assigned",
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

pub const ElasticNodeComputeState = union(enum) {
    none,
    healthy,
    creating,
    deleting,
    failed,
    stopped,
    reimaging,
    unhealthy_vm,
    unhealthy_vmss_vm,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .healthy = "healthy",
        .creating = "creating",
        .deleting = "deleting",
        .failed = "failed",
        .stopped = "stopped",
        .reimaging = "reimaging",
        .unhealthy_vm = "unhealthyVm",
        .unhealthy_vmss_vm = "unhealthyVmssVm",
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

pub const ElasticNodeDesiredState = union(enum) {
    none,
    new,
    creating_compute,
    starting_agent,
    idle,
    assigned,
    offline,
    pending_reimage,
    pending_delete,
    saved,
    deleting_compute,
    deleted,
    lost,
    reimaging_compute,
    restarting_agent,
    failed_to_start_pending_delete,
    failed_to_restart_pending_delete,
    failed_vm_pending_delete,
    assigned_pending_delete,
    retry_delete,
    unhealthy_vm,
    unhealthy_vm_pending_delete,
    pending_reimage_candidate,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .new = "new",
        .creating_compute = "creatingCompute",
        .starting_agent = "startingAgent",
        .idle = "idle",
        .assigned = "assigned",
        .offline = "offline",
        .pending_reimage = "pendingReimage",
        .pending_delete = "pendingDelete",
        .saved = "saved",
        .deleting_compute = "deletingCompute",
        .deleted = "deleted",
        .lost = "lost",
        .reimaging_compute = "reimagingCompute",
        .restarting_agent = "restartingAgent",
        .failed_to_start_pending_delete = "failedToStartPendingDelete",
        .failed_to_restart_pending_delete = "failedToRestartPendingDelete",
        .failed_vm_pending_delete = "failedVMPendingDelete",
        .assigned_pending_delete = "assignedPendingDelete",
        .retry_delete = "retryDelete",
        .unhealthy_vm = "unhealthyVm",
        .unhealthy_vm_pending_delete = "unhealthyVmPendingDelete",
        .pending_reimage_candidate = "pendingReimageCandidate",
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

pub const ElasticNodeState = union(enum) {
    none,
    new,
    creating_compute,
    starting_agent,
    idle,
    assigned,
    offline,
    pending_reimage,
    pending_delete,
    saved,
    deleting_compute,
    deleted,
    lost,
    reimaging_compute,
    restarting_agent,
    failed_to_start_pending_delete,
    failed_to_restart_pending_delete,
    failed_vm_pending_delete,
    assigned_pending_delete,
    retry_delete,
    unhealthy_vm,
    unhealthy_vm_pending_delete,
    pending_reimage_candidate,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .new = "new",
        .creating_compute = "creatingCompute",
        .starting_agent = "startingAgent",
        .idle = "idle",
        .assigned = "assigned",
        .offline = "offline",
        .pending_reimage = "pendingReimage",
        .pending_delete = "pendingDelete",
        .saved = "saved",
        .deleting_compute = "deletingCompute",
        .deleted = "deleted",
        .lost = "lost",
        .reimaging_compute = "reimagingCompute",
        .restarting_agent = "restartingAgent",
        .failed_to_start_pending_delete = "failedToStartPendingDelete",
        .failed_to_restart_pending_delete = "failedToRestartPendingDelete",
        .failed_vm_pending_delete = "failedVMPendingDelete",
        .assigned_pending_delete = "assignedPendingDelete",
        .retry_delete = "retryDelete",
        .unhealthy_vm = "unhealthyVm",
        .unhealthy_vm_pending_delete = "unhealthyVmPendingDelete",
        .pending_reimage_candidate = "pendingReimageCandidate",
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

pub const ElasticNodeSettingsState = union(enum) {
    none,
    new,
    creating_compute,
    starting_agent,
    idle,
    assigned,
    offline,
    pending_reimage,
    pending_delete,
    saved,
    deleting_compute,
    deleted,
    lost,
    reimaging_compute,
    restarting_agent,
    failed_to_start_pending_delete,
    failed_to_restart_pending_delete,
    failed_vm_pending_delete,
    assigned_pending_delete,
    retry_delete,
    unhealthy_vm,
    unhealthy_vm_pending_delete,
    pending_reimage_candidate,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .new = "new",
        .creating_compute = "creatingCompute",
        .starting_agent = "startingAgent",
        .idle = "idle",
        .assigned = "assigned",
        .offline = "offline",
        .pending_reimage = "pendingReimage",
        .pending_delete = "pendingDelete",
        .saved = "saved",
        .deleting_compute = "deletingCompute",
        .deleted = "deleted",
        .lost = "lost",
        .reimaging_compute = "reimagingCompute",
        .restarting_agent = "restartingAgent",
        .failed_to_start_pending_delete = "failedToStartPendingDelete",
        .failed_to_restart_pending_delete = "failedToRestartPendingDelete",
        .failed_vm_pending_delete = "failedVMPendingDelete",
        .assigned_pending_delete = "assignedPendingDelete",
        .retry_delete = "retryDelete",
        .unhealthy_vm = "unhealthyVm",
        .unhealthy_vm_pending_delete = "unhealthyVmPendingDelete",
        .pending_reimage_candidate = "pendingReimageCandidate",
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

pub const IssueType = union(enum) {
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

pub const TimelineRecordResult = union(enum) {
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

pub const TimelineRecordState = union(enum) {
    pending,
    in_progress,
    completed,
    unrecognized: []const u8,

    const wire_names = .{
        .pending = "pending",
        .in_progress = "inProgress",
        .completed = "completed",
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

pub const TaskAgentReferenceStatus = union(enum) {
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

pub const InputDescriptorInputMode = union(enum) {
    none,
    text_box,
    password_box,
    combo,
    radio_buttons,
    check_box,
    text_area,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .text_box = "textBox",
        .password_box = "passwordBox",
        .combo = "combo",
        .radio_buttons = "radioButtons",
        .check_box = "checkBox",
        .text_area = "textArea",
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

pub const InputValidationDataType = union(enum) {
    none,
    string,
    number,
    boolean,
    guid,
    uri,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .string = "string",
        .number = "number",
        .boolean = "boolean",
        .guid = "guid",
        .uri = "uri",
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

pub const GetAgentPoolsByIdsRequestActionFilter = enum {
    none,
    manage,
    use,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
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

pub const GetRequestActionFilter = enum {
    none,
    manage,
    use,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
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

pub const ListRequestActionFilter = enum {
    none,
    manage,
    use,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
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
    machines,
    tags,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .machines => "machines",
            .tags => "tags",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "machines")) return .machines;
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

pub const GetRequestActionFilter1 = enum {
    none,
    manage,
    use,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
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
    machines,
    tags,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .machines => "machines",
            .tags => "tags",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "machines")) return .machines;
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

pub const ListRequestExpand1 = enum {
    none,
    capabilities,
    assigned_request,
    last_completed_request,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .capabilities => "capabilities",
            .assigned_request => "assignedRequest",
            .last_completed_request => "lastCompletedRequest",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "capabilities")) return .capabilities;
        if (std.mem.eql(u8, s, "assignedRequest")) return .assigned_request;
        if (std.mem.eql(u8, s, "lastCompletedRequest")) return .last_completed_request;
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

pub const ListRequestAgentStatus = enum {
    offline,
    online,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .offline => "offline",
            .online => "online",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "offline")) return .offline;
        if (std.mem.eql(u8, s, "online")) return .online;
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

pub const ListRequestAgentJobResult = enum {
    failed,
    passed,
    never_deployed,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .failed => "failed",
            .passed => "passed",
            .never_deployed => "neverDeployed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "passed")) return .passed;
        if (std.mem.eql(u8, s, "neverDeployed")) return .never_deployed;
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
    capabilities,
    assigned_request,
    last_completed_request,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .capabilities => "capabilities",
            .assigned_request => "assignedRequest",
            .last_completed_request => "lastCompletedRequest",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "capabilities")) return .capabilities;
        if (std.mem.eql(u8, s, "assignedRequest")) return .assigned_request;
        if (std.mem.eql(u8, s, "lastCompletedRequest")) return .last_completed_request;
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

pub const GetAgentQueuesForPoolsRequestActionFilter = enum {
    none,
    manage,
    use,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
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

pub const GetRequestActionFilter2 = enum {
    none,
    manage,
    use,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
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

pub const GetSecureFilesByNamesRequestActionFilter = enum {
    none,
    manage,
    use,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
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

pub const GetRequestActionFilter3 = enum {
    none,
    manage,
    use,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .manage => "manage",
            .use => "use",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "manage")) return .manage;
        if (std.mem.eql(u8, s, "use")) return .use;
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

pub const TaskCommandRestrictionsMode = union(enum) {
    any,
    restricted,
    unrecognized: []const u8,

    const wire_names = .{
        .any = "any",
        .restricted = "restricted",
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

pub const ListRequestQueryOrder = enum {
    created_on_ascending,
    created_on_descending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .created_on_ascending => "createdOnAscending",
            .created_on_descending => "createdOnDescending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "createdOnAscending")) return .created_on_ascending;
        if (std.mem.eql(u8, s, "createdOnDescending")) return .created_on_descending;
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
