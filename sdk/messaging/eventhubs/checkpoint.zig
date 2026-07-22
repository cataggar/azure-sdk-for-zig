const std = @import("std");

/// Tracks consumer progress for a partition.
pub const Checkpoint = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    consumer_group: []const u8,
    partition_id: []const u8,
    offset: ?i64 = null,
    sequence_number: ?i64 = null,
};

/// Tracks partition ownership for load balancing.
pub const PartitionOwnership = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    consumer_group: []const u8,
    partition_id: []const u8,
    owner_id: []const u8,
    last_modified_time: ?i64 = null,
    etag: ?[]const u8 = null,
};

/// Storage abstraction used by Event Hubs processors.
pub const CheckpointStore = struct {
    claimOwnershipFn: *const fn (self: *CheckpointStore, allocator: std.mem.Allocator, ownership: []const PartitionOwnership) anyerror![]PartitionOwnership,
    listOwnershipFn: *const fn (self: *CheckpointStore, allocator: std.mem.Allocator, fqns: []const u8, hub_name: []const u8, consumer_group: []const u8) anyerror![]PartitionOwnership,
    updateCheckpointFn: *const fn (self: *CheckpointStore, allocator: std.mem.Allocator, checkpoint: Checkpoint) anyerror!void,
    listCheckpointsFn: *const fn (self: *CheckpointStore, allocator: std.mem.Allocator, fqns: []const u8, hub_name: []const u8, consumer_group: []const u8) anyerror![]Checkpoint,

    pub fn claimOwnership(self: *CheckpointStore, allocator: std.mem.Allocator, ownership: []const PartitionOwnership) ![]PartitionOwnership {
        return self.claimOwnershipFn(self, allocator, ownership);
    }

    pub fn listOwnership(self: *CheckpointStore, allocator: std.mem.Allocator, fqns: []const u8, hub_name: []const u8, consumer_group: []const u8) ![]PartitionOwnership {
        return self.listOwnershipFn(self, allocator, fqns, hub_name, consumer_group);
    }

    pub fn updateCheckpoint(self: *CheckpointStore, allocator: std.mem.Allocator, checkpoint: Checkpoint) !void {
        return self.updateCheckpointFn(self, allocator, checkpoint);
    }

    pub fn listCheckpoints(self: *CheckpointStore, allocator: std.mem.Allocator, fqns: []const u8, hub_name: []const u8, consumer_group: []const u8) ![]Checkpoint {
        return self.listCheckpointsFn(self, allocator, fqns, hub_name, consumer_group);
    }
};
