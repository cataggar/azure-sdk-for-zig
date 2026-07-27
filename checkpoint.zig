const std = @import("std");

/// Tracks consumer progress for a partition.
///
/// `offset` is an opaque service-defined token, not a number. Event Hubs
/// returns non-numeric offsets under geo-disaster-recovery, and the Go and
/// Rust SDKs both model it as a string, so it is kept as one here for wire
/// compatibility.
pub const Checkpoint = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    consumer_group: []const u8,
    partition_id: []const u8,
    offset: ?[]const u8 = null,
    sequence_number: ?i64 = null,

    /// Free a checkpoint returned by a `CheckpointStore`. Values the caller
    /// constructed itself do not need this.
    pub fn deinit(self: Checkpoint, allocator: std.mem.Allocator) void {
        allocator.free(self.fully_qualified_namespace);
        allocator.free(self.event_hub_name);
        allocator.free(self.consumer_group);
        allocator.free(self.partition_id);
        if (self.offset) |offset| allocator.free(offset);
    }
};

/// Tracks partition ownership for load balancing.
pub const PartitionOwnership = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    consumer_group: []const u8,
    partition_id: []const u8,
    /// Identifier of the owning processor. An empty string means a previous
    /// owner relinquished the partition, which is how Go and Rust signal that
    /// the partition is free to claim.
    owner_id: []const u8,
    /// Blob `Last-Modified`, in Unix seconds. Load balancing uses it to expire
    /// ownership that a processor stopped renewing.
    last_modified_time: ?i64 = null,
    etag: ?[]const u8 = null,

    pub fn isRelinquished(self: PartitionOwnership) bool {
        return self.owner_id.len == 0;
    }

    /// Free ownership returned by a `CheckpointStore`. Values the caller
    /// constructed itself do not need this.
    pub fn deinit(self: PartitionOwnership, allocator: std.mem.Allocator) void {
        allocator.free(self.fully_qualified_namespace);
        allocator.free(self.event_hub_name);
        allocator.free(self.consumer_group);
        allocator.free(self.partition_id);
        allocator.free(self.owner_id);
        if (self.etag) |etag| allocator.free(etag);
    }
};

pub fn freeCheckpoints(allocator: std.mem.Allocator, checkpoints: []const Checkpoint) void {
    for (checkpoints) |checkpoint| checkpoint.deinit(allocator);
    allocator.free(checkpoints);
}

pub fn freeOwnerships(allocator: std.mem.Allocator, ownerships: []const PartitionOwnership) void {
    for (ownerships) |ownership| ownership.deinit(allocator);
    allocator.free(ownerships);
}

/// Storage abstraction used by Event Hubs processors.
///
/// Every slice returned by these methods is allocator-owned; free it with
/// `freeCheckpoints` or `freeOwnerships`.
pub const CheckpointStore = struct {
    claimOwnershipFn: *const fn (self: *CheckpointStore, allocator: std.mem.Allocator, ownership: []const PartitionOwnership) anyerror![]PartitionOwnership,
    listOwnershipFn: *const fn (self: *CheckpointStore, allocator: std.mem.Allocator, fqns: []const u8, hub_name: []const u8, consumer_group: []const u8) anyerror![]PartitionOwnership,
    updateCheckpointFn: *const fn (self: *CheckpointStore, allocator: std.mem.Allocator, checkpoint: Checkpoint) anyerror!void,
    listCheckpointsFn: *const fn (self: *CheckpointStore, allocator: std.mem.Allocator, fqns: []const u8, hub_name: []const u8, consumer_group: []const u8) anyerror![]Checkpoint,

    /// Attempt to claim each partition. Partitions lost to another processor
    /// are omitted from the result rather than reported as an error.
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

test "relinquished ownership is signalled by an empty owner id" {
    const relinquished = PartitionOwnership{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .owner_id = "",
    };
    try std.testing.expect(relinquished.isRelinquished());

    var owned = relinquished;
    owned.owner_id = "processor-1";
    try std.testing.expect(!owned.isRelinquished());
}
