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

/// A source of wall-clock time, so ownership expiry can be tested without
/// sleeping.
pub const Clock = struct {
    nowMillisFn: *const fn (self: *Clock) i64,

    pub fn nowMillis(self: *Clock) i64 {
        return self.nowMillisFn(self);
    }
};

/// The real clock.
///
/// Wall time rather than monotonic: ownership expiry compares against a
/// `last_modified_time` written by another process, possibly on another
/// machine, so the two have to share an epoch.
pub const SystemClock = struct {
    io: std.Io,
    clock: Clock = .{ .nowMillisFn = now },

    fn now(c: *Clock) i64 {
        const self: *SystemClock = @fieldParentPtr("clock", c);
        const timestamp = std.Io.Timestamp.now(self.io, .real);
        return @intCast(@divTrunc(timestamp.nanoseconds, std.time.ns_per_ms));
    }
};

/// A clock that only moves when told to.
pub const ManualClock = struct {
    millis: i64 = 1_000_000,
    clock: Clock = .{ .nowMillisFn = now },

    fn now(c: *Clock) i64 {
        const self: *ManualClock = @fieldParentPtr("clock", c);
        return self.millis;
    }

    pub fn advance(self: *ManualClock, ms: i64) void {
        self.millis += ms;
    }
};

/// Free an ownership record that was duplicated with `dupeOwnership`.
pub fn freeOwned(allocator: std.mem.Allocator, ownership: PartitionOwnership) void {
    ownership.deinit(allocator);
}

/// Copy an ownership record, substituting `owner_id`.
pub fn dupeOwnership(
    allocator: std.mem.Allocator,
    source: PartitionOwnership,
    owner_id: []const u8,
) !PartitionOwnership {
    var out: PartitionOwnership = .{
        .fully_qualified_namespace = undefined,
        .event_hub_name = undefined,
        .consumer_group = undefined,
        .partition_id = undefined,
        .owner_id = undefined,
        .last_modified_time = source.last_modified_time,
    };
    out.fully_qualified_namespace = try allocator.dupe(u8, source.fully_qualified_namespace);
    errdefer allocator.free(out.fully_qualified_namespace);
    out.event_hub_name = try allocator.dupe(u8, source.event_hub_name);
    errdefer allocator.free(out.event_hub_name);
    out.consumer_group = try allocator.dupe(u8, source.consumer_group);
    errdefer allocator.free(out.consumer_group);
    out.partition_id = try allocator.dupe(u8, source.partition_id);
    errdefer allocator.free(out.partition_id);
    out.owner_id = try allocator.dupe(u8, owner_id);
    return out;
}

/// A `CheckpointStore` held entirely in memory.
///
/// Intended for tests and for running a processor fleet in one process. It is
/// last-write-wins: it does not model the etag race a real store arbitrates,
/// so two processors claiming the same partition in the same cycle both
/// succeed rather than one losing.
pub const InMemoryCheckpointStore = struct {
    allocator: std.mem.Allocator,
    ownerships: std.ArrayList(PartitionOwnership) = .empty,
    checkpoints: std.ArrayList(Checkpoint) = .empty,
    clock: *Clock,
    store: CheckpointStore = .{
        .claimOwnershipFn = claimOwnership,
        .listOwnershipFn = listOwnership,
        .updateCheckpointFn = updateCheckpoint,
        .listCheckpointsFn = listCheckpoints,
    },

    pub fn deinit(self: *InMemoryCheckpointStore) void {
        for (self.ownerships.items) |ownership| freeOwned(self.allocator, ownership);
        self.ownerships.deinit(self.allocator);
        for (self.checkpoints.items) |c| c.deinit(self.allocator);
        self.checkpoints.deinit(self.allocator);
    }

    fn find(self: *InMemoryCheckpointStore, partition_id: []const u8) ?*PartitionOwnership {
        for (self.ownerships.items) |*ownership| {
            if (std.mem.eql(u8, ownership.partition_id, partition_id)) return ownership;
        }
        return null;
    }

    fn claimOwnership(
        s: *CheckpointStore,
        allocator: std.mem.Allocator,
        requested: []const PartitionOwnership,
    ) anyerror![]PartitionOwnership {
        const self: *InMemoryCheckpointStore = @fieldParentPtr("store", s);
        const now = @divFloor(self.clock.nowMillis(), std.time.ms_per_s);

        var claimed: std.ArrayList(PartitionOwnership) = .empty;
        errdefer {
            for (claimed.items) |c| freeOwned(allocator, c);
            claimed.deinit(allocator);
        }

        for (requested) |ownership| {
            if (self.find(ownership.partition_id)) |existing| {
                allocator.free(existing.owner_id);
                existing.owner_id = try allocator.dupe(u8, ownership.owner_id);
                existing.last_modified_time = now;
            } else {
                var stored = try dupeOwnership(allocator, ownership, ownership.owner_id);
                stored.last_modified_time = now;
                try self.ownerships.append(self.allocator, stored);
            }
            var out = try dupeOwnership(allocator, ownership, ownership.owner_id);
            out.last_modified_time = now;
            try claimed.append(allocator, out);
        }
        return claimed.toOwnedSlice(allocator);
    }

    fn listOwnership(
        s: *CheckpointStore,
        allocator: std.mem.Allocator,
        _: []const u8,
        _: []const u8,
        _: []const u8,
    ) anyerror![]PartitionOwnership {
        const self: *InMemoryCheckpointStore = @fieldParentPtr("store", s);
        const out = try allocator.alloc(PartitionOwnership, self.ownerships.items.len);
        errdefer allocator.free(out);
        for (out, self.ownerships.items) |*slot, stored| {
            slot.* = try dupeOwnership(allocator, stored, stored.owner_id);
        }
        return out;
    }

    fn updateCheckpoint(s: *CheckpointStore, allocator: std.mem.Allocator, c: Checkpoint) anyerror!void {
        const self: *InMemoryCheckpointStore = @fieldParentPtr("store", s);
        _ = allocator;
        for (self.checkpoints.items) |*existing| {
            if (!std.mem.eql(u8, existing.partition_id, c.partition_id)) continue;
            if (existing.offset) |offset| self.allocator.free(offset);
            existing.offset = if (c.offset) |o| try self.allocator.dupe(u8, o) else null;
            existing.sequence_number = c.sequence_number;
            return;
        }
        try self.checkpoints.append(self.allocator, .{
            .fully_qualified_namespace = try self.allocator.dupe(u8, c.fully_qualified_namespace),
            .event_hub_name = try self.allocator.dupe(u8, c.event_hub_name),
            .consumer_group = try self.allocator.dupe(u8, c.consumer_group),
            .partition_id = try self.allocator.dupe(u8, c.partition_id),
            .offset = if (c.offset) |o| try self.allocator.dupe(u8, o) else null,
            .sequence_number = c.sequence_number,
        });
    }

    fn listCheckpoints(
        s: *CheckpointStore,
        allocator: std.mem.Allocator,
        _: []const u8,
        _: []const u8,
        _: []const u8,
    ) anyerror![]Checkpoint {
        const self: *InMemoryCheckpointStore = @fieldParentPtr("store", s);
        const out = try allocator.alloc(Checkpoint, self.checkpoints.items.len);
        errdefer allocator.free(out);
        for (out, self.checkpoints.items) |*slot, stored| {
            slot.* = .{
                .fully_qualified_namespace = try allocator.dupe(u8, stored.fully_qualified_namespace),
                .event_hub_name = try allocator.dupe(u8, stored.event_hub_name),
                .consumer_group = try allocator.dupe(u8, stored.consumer_group),
                .partition_id = try allocator.dupe(u8, stored.partition_id),
                .offset = if (stored.offset) |o| try allocator.dupe(u8, o) else null,
                .sequence_number = stored.sequence_number,
            };
        }
        return out;
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
