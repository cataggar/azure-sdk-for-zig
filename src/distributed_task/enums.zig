//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const ElasticPoolOrchestrationType = enum {
    uniform,
    flexible,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .uniform => "uniform",
            .flexible => "flexible",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "uniform")) return .uniform;
        if (std.mem.eql(u8, s, "flexible")) return .flexible;
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

pub const ElasticPoolOsType = enum {
    windows,
    linux,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .windows => "windows",
            .linux => "linux",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "windows")) return .windows;
        if (std.mem.eql(u8, s, "linux")) return .linux;
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

pub const ElasticPoolState = enum {
    online,
    offline,
    unhealthy,
    new,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .online => "online",
            .offline => "offline",
            .unhealthy => "unhealthy",
            .new => "new",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "online")) return .online;
        if (std.mem.eql(u8, s, "offline")) return .offline;
        if (std.mem.eql(u8, s, "unhealthy")) return .unhealthy;
        if (std.mem.eql(u8, s, "new")) return .new;
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

pub const TaskAgentPoolOptions = enum {
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

pub const TaskAgentPoolPoolType = enum {
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

pub const ElasticPoolSettingsOrchestrationType = enum {
    uniform,
    flexible,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .uniform => "uniform",
            .flexible => "flexible",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "uniform")) return .uniform;
        if (std.mem.eql(u8, s, "flexible")) return .flexible;
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

pub const ElasticPoolSettingsOsType = enum {
    windows,
    linux,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .windows => "windows",
            .linux => "linux",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "windows")) return .windows;
        if (std.mem.eql(u8, s, "linux")) return .linux;
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

pub const ElasticPoolLogLevel = enum {
    @"error",
    warning,
    info,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .@"error" => "error",
            .warning => "warning",
            .info => "info",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "warning")) return .warning;
        if (std.mem.eql(u8, s, "info")) return .info;
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

pub const ElasticPoolLogOperation = enum {
    configuration_job,
    sizing_job,
    increase_capacity,
    reimage,
    delete_v_ms,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .configuration_job => "configurationJob",
            .sizing_job => "sizingJob",
            .increase_capacity => "increaseCapacity",
            .reimage => "reimage",
            .delete_v_ms => "deleteVMs",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "configurationJob")) return .configuration_job;
        if (std.mem.eql(u8, s, "sizingJob")) return .sizing_job;
        if (std.mem.eql(u8, s, "increaseCapacity")) return .increase_capacity;
        if (std.mem.eql(u8, s, "reimage")) return .reimage;
        if (std.mem.eql(u8, s, "deleteVMs")) return .delete_v_ms;
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

pub const ElasticNodeAgentState = enum {
    none,
    enabled,
    online,
    assigned,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .enabled => "enabled",
            .online => "online",
            .assigned => "assigned",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "enabled")) return .enabled;
        if (std.mem.eql(u8, s, "online")) return .online;
        if (std.mem.eql(u8, s, "assigned")) return .assigned;
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

pub const ElasticNodeComputeState = enum {
    none,
    healthy,
    creating,
    deleting,
    failed,
    stopped,
    reimaging,
    unhealthy_vm,
    unhealthy_vmss_vm,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .healthy => "healthy",
            .creating => "creating",
            .deleting => "deleting",
            .failed => "failed",
            .stopped => "stopped",
            .reimaging => "reimaging",
            .unhealthy_vm => "unhealthyVm",
            .unhealthy_vmss_vm => "unhealthyVmssVm",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "healthy")) return .healthy;
        if (std.mem.eql(u8, s, "creating")) return .creating;
        if (std.mem.eql(u8, s, "deleting")) return .deleting;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "stopped")) return .stopped;
        if (std.mem.eql(u8, s, "reimaging")) return .reimaging;
        if (std.mem.eql(u8, s, "unhealthyVm")) return .unhealthy_vm;
        if (std.mem.eql(u8, s, "unhealthyVmssVm")) return .unhealthy_vmss_vm;
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

pub const ElasticNodeDesiredState = enum {
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

pub const ElasticNodeState = enum {
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

pub const ElasticNodeSettingsState = enum {
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

pub const IssueType = enum {
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

pub const TimelineRecordResult = enum {
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

pub const TimelineRecordState = enum {
    pending,
    in_progress,
    completed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .pending => "pending",
            .in_progress => "inProgress",
            .completed => "completed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
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

pub const TaskAgentReferenceStatus = enum {
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

pub const InputDescriptorInputMode = enum {
    none,
    text_box,
    password_box,
    combo,
    radio_buttons,
    check_box,
    text_area,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .text_box => "textBox",
            .password_box => "passwordBox",
            .combo => "combo",
            .radio_buttons => "radioButtons",
            .check_box => "checkBox",
            .text_area => "textArea",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "textBox")) return .text_box;
        if (std.mem.eql(u8, s, "passwordBox")) return .password_box;
        if (std.mem.eql(u8, s, "combo")) return .combo;
        if (std.mem.eql(u8, s, "radioButtons")) return .radio_buttons;
        if (std.mem.eql(u8, s, "checkBox")) return .check_box;
        if (std.mem.eql(u8, s, "textArea")) return .text_area;
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

pub const InputValidationDataType = enum {
    none,
    string,
    number,
    boolean,
    guid,
    uri,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .string => "string",
            .number => "number",
            .boolean => "boolean",
            .guid => "guid",
            .uri => "uri",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "string")) return .string;
        if (std.mem.eql(u8, s, "number")) return .number;
        if (std.mem.eql(u8, s, "boolean")) return .boolean;
        if (std.mem.eql(u8, s, "guid")) return .guid;
        if (std.mem.eql(u8, s, "uri")) return .uri;
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

pub const TaskCommandRestrictionsMode = enum {
    any,
    restricted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .any => "any",
            .restricted => "restricted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "any")) return .any;
        if (std.mem.eql(u8, s, "restricted")) return .restricted;
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
