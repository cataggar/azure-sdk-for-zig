//! The `Processor`: distributed consumption over a fleet.
//!
//! One balancing cycle claims what this processor is entitled to, opens a
//! reader for anything newly claimed, and closes anything lost. The caller
//! drives the loop, so there is no thread here and nothing to shut down
//! except the readers themselves.
//!
//! Ported from Go's `Processor` (`processor.go`), minus its goroutine
//! plumbing: `runOnce` is the body of Go's `Run` loop, and
//! `nextPartitionClient` is `NextPartitionClient`.

const std = @import("std");
const checkpoint_types = @import("checkpoint.zig");
const errors = @import("errors.zig");
const event_data = @import("event_data.zig");
const balancing = @import("load_balancer.zig");
const receiving = @import("receiver.zig");
const start_position_types = @import("position.zig");

const Allocator = std.mem.Allocator;
const Checkpoint = checkpoint_types.Checkpoint;
const CheckpointStore = checkpoint_types.CheckpointStore;
const EventPosition = start_position_types.EventPosition;
const LoadBalancer = balancing.LoadBalancer;
const OwnershipDetails = balancing.OwnershipDetails;
const PartitionClient = receiving.PartitionClient;
const PartitionClientOptions = receiving.PartitionClientOptions;
const ProcessorOptions = balancing.ProcessorOptions;
const ReceivedEventData = event_data.ReceivedEventData;

/// Opens and closes partition readers on the processor's behalf.
///
/// A vtable rather than a `ConsumerClient` for the same reason recovery uses
/// one: `root.zig` imports this file, so this file cannot import `root.zig`.
/// It also lets the balancing loop be tested without an AMQP peer.
pub const PartitionOpener = struct {
    partitionIdsFn: *const fn (self: *PartitionOpener, allocator: Allocator) anyerror![][]const u8,
    openFn: *const fn (
        self: *PartitionOpener,
        allocator: Allocator,
        partition_id: []const u8,
        position: EventPosition,
        options: PartitionClientOptions,
    ) anyerror!*PartitionClient,
    closeFn: *const fn (self: *PartitionOpener, client: *PartitionClient) void,

    /// The hub's partition ids. Caller owns the slice and its strings.
    pub fn partitionIds(self: *PartitionOpener, allocator: Allocator) ![][]const u8 {
        return self.partitionIdsFn(self, allocator);
    }

    pub fn open(
        self: *PartitionOpener,
        allocator: Allocator,
        partition_id: []const u8,
        position: EventPosition,
        options: PartitionClientOptions,
    ) !*PartitionClient {
        return self.openFn(self, allocator, partition_id, position, options);
    }

    pub fn close(self: *PartitionOpener, client: *PartitionClient) void {
        self.closeFn(self, client);
    }
};

pub fn freePartitionIds(allocator: Allocator, ids: [][]const u8) void {
    for (ids) |id| allocator.free(id);
    allocator.free(ids);
}

/// A reader for one claimed partition, plus the checkpointing that goes with
/// it.
pub const ProcessorPartitionClient = struct {
    allocator: Allocator,
    /// Owned: the ownership record it came from does not outlive the cycle.
    partition_id: []u8,
    client: *PartitionClient,
    store: *CheckpointStore,
    details: OwnershipDetails,
    opener: *PartitionOpener,
    /// Set when the broker says another processor took the partition. The
    /// processor releases rather than retries: the whole point of an owner
    /// level is that the newer reader wins.
    ownership_lost: bool = false,

    pub fn partitionId(self: *const ProcessorPartitionClient) []const u8 {
        return self.partition_id;
    }

    /// Receive up to `count` events. Free the result with
    /// `freeReceivedEvents`.
    pub fn receiveEvents(
        self: *ProcessorPartitionClient,
        allocator: Allocator,
        count: u32,
    ) ![]ReceivedEventData {
        return self.client.receiveEvents(allocator, count) catch |err| {
            if (self.client.last_error) |info| {
                if (info.code == .ownership_lost) self.ownership_lost = true;
            }
            return err;
        };
    }

    /// Record `event` as processed, so a later owner resumes after it.
    pub fn updateCheckpoint(
        self: *ProcessorPartitionClient,
        allocator: Allocator,
        event: ReceivedEventData,
    ) !void {
        return self.store.updateCheckpoint(allocator, .{
            .fully_qualified_namespace = self.details.fully_qualified_namespace,
            .event_hub_name = self.details.event_hub_name,
            .consumer_group = self.details.consumer_group,
            .partition_id = self.partition_id,
            .offset = event.offset,
            .sequence_number = event.sequence_number,
        });
    }

    pub fn close(self: *ProcessorPartitionClient) void {
        self.opener.close(self.client);
        self.allocator.free(self.partition_id);
    }
};

pub const Processor = struct {
    allocator: Allocator,
    store: *CheckpointStore,
    opener: *PartitionOpener,
    details: OwnershipDetails,
    options: ProcessorOptions = .{},
    balancer: LoadBalancer,
    /// Readers keyed by partition id. The key is the client's owned id, so
    /// the map borrows and the client frees.
    clients: std.StringArrayHashMapUnmanaged(*ProcessorPartitionClient) = .empty,
    /// Newly opened readers waiting to be handed out.
    pending: std.ArrayList(*ProcessorPartitionClient) = .empty,
    deadline_ms: i64 = 60_000,

    pub fn init(
        allocator: Allocator,
        store: *CheckpointStore,
        opener: *PartitionOpener,
        details: OwnershipDetails,
        options: ProcessorOptions,
        clock: *balancing.Clock,
        random: std.Random,
    ) Processor {
        return .{
            .allocator = allocator,
            .store = store,
            .opener = opener,
            .details = details,
            .options = options,
            .balancer = .{
                .allocator = allocator,
                .store = store,
                .details = details,
                .strategy = options.load_balancing_strategy,
                .partition_expiration_ms = options.partition_expiration_ms,
                .clock = clock,
                .random = random,
            },
        };
    }

    /// Close every reader and drop the ownership records.
    ///
    /// Relinquishing is best effort: a processor whose store has gone away
    /// still has to stop cleanly, and the records expire on their own.
    pub fn deinit(self: *Processor) void {
        var held: std.ArrayList([]const u8) = .empty;
        defer held.deinit(self.allocator);
        for (self.clients.keys()) |id| held.append(self.allocator, id) catch {};
        self.balancer.relinquish(held.items) catch {};

        for (self.clients.values()) |client| {
            client.close();
            self.allocator.destroy(client);
        }
        self.clients.deinit(self.allocator);
        self.pending.deinit(self.allocator);
    }

    /// One balancing cycle: claim, renew, open, and release.
    pub fn runOnce(self: *Processor) !void {
        const partition_ids = try self.opener.partitionIds(self.allocator);
        defer freePartitionIds(self.allocator, partition_ids);

        const claimed = try self.balancer.loadBalance(partition_ids);
        defer checkpoint_types.freeOwnerships(self.allocator, claimed);

        try self.releaseUnclaimed(claimed);

        const checkpoints = try self.store.listCheckpoints(
            self.allocator,
            self.details.fully_qualified_namespace,
            self.details.event_hub_name,
            self.details.consumer_group,
        );
        defer checkpoint_types.freeCheckpoints(self.allocator, checkpoints);

        for (claimed) |ownership| {
            if (self.clients.contains(ownership.partition_id)) continue;
            try self.openPartition(ownership.partition_id, checkpoints);
        }
    }

    /// Close readers for partitions this cycle did not keep.
    ///
    /// Also covers a reader that reported ownership lost: it is no longer in
    /// the claim, and holding the link open would keep stealing the partition
    /// back from whoever took it.
    fn releaseUnclaimed(self: *Processor, claimed: []const checkpoint_types.PartitionOwnership) !void {
        var dropped: std.ArrayList([]const u8) = .empty;
        defer dropped.deinit(self.allocator);

        for (self.clients.keys(), self.clients.values()) |id, client| {
            var kept = false;
            for (claimed) |ownership| {
                if (std.mem.eql(u8, ownership.partition_id, id)) {
                    kept = true;
                    break;
                }
            }
            if (kept and !client.ownership_lost) continue;
            try dropped.append(self.allocator, id);
        }

        for (dropped.items) |id| self.releasePartition(id);
    }

    fn releasePartition(self: *Processor, partition_id: []const u8) void {
        const client = self.clients.get(partition_id) orelse return;

        var i: usize = 0;
        while (i < self.pending.items.len) {
            if (self.pending.items[i] == client) {
                _ = self.pending.orderedRemove(i);
                continue;
            }
            i += 1;
        }
        _ = self.clients.orderedRemove(partition_id);
        client.close();
        self.allocator.destroy(client);
    }

    fn openPartition(self: *Processor, partition_id: []const u8, checkpoints: []const Checkpoint) !void {
        var stored: ?Checkpoint = null;
        for (checkpoints) |c| {
            if (std.mem.eql(u8, c.partition_id, partition_id)) stored = c;
        }

        const position = try balancing.resolveStartPosition(
            self.options.start_positions,
            partition_id,
            stored,
        );

        const options: PartitionClientOptions = .{ .prefetch = self.options.prefetch };
        const client = blk: {
            break :blk self.opener.open(self.allocator, partition_id, position, options) catch |err| {
                // A replicated namespace cannot interpret an offset carried
                // over from before a failover. Go restarts at earliest,
                // inclusive: duplicates, rather than a partition nobody can
                // read at all.
                if (err != error.GeoReplicationOffsetRejected) return err;
                break :blk try self.opener.open(
                    self.allocator,
                    partition_id,
                    balancing.geo_replication_fallback,
                    options,
                );
            };
        };

        const owned_id = try self.allocator.dupe(u8, partition_id);
        errdefer self.allocator.free(owned_id);

        const wrapper = try self.allocator.create(ProcessorPartitionClient);
        errdefer self.allocator.destroy(wrapper);
        wrapper.* = .{
            .allocator = self.allocator,
            .partition_id = owned_id,
            .client = client,
            .store = self.store,
            .details = self.details,
            .opener = self.opener,
        };

        try self.clients.put(self.allocator, owned_id, wrapper);
        errdefer _ = self.clients.orderedRemove(owned_id);
        try self.pending.append(self.allocator, wrapper);
    }

    /// The next newly claimed partition, or null when there is none.
    ///
    /// The processor keeps owning the reader: it has to close it when the
    /// partition is lost, which the caller cannot know about.
    pub fn nextPartitionClient(self: *Processor) ?*ProcessorPartitionClient {
        if (self.pending.items.len == 0) return null;
        return self.pending.orderedRemove(0);
    }

    /// Partitions this processor currently reads.
    pub fn ownedPartitions(self: *const Processor) []const []const u8 {
        return self.clients.keys();
    }

    /// The next cycle's delay, jittered.
    pub fn nextIntervalMs(self: *Processor) i64 {
        return self.balancer.nextIntervalMs(self.options.update_interval_ms);
    }
};

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const InMemoryCheckpointStore = checkpoint_types.InMemoryCheckpointStore;
const ManualClock = checkpoint_types.ManualClock;

/// A `PartitionOpener` that records what it was asked for instead of
/// attaching a link.
///
/// The `PartitionClient` it hands back is never read from: the processor only
/// stores it and passes it back to `close`. That is exactly the surface the
/// balancing loop uses, so a fake is enough to test the loop without a peer.
const FakeOpener = struct {
    allocator: Allocator,
    partitions: []const []const u8,
    /// Every position the processor asked to open at, in order.
    opened: std.ArrayList(Opened) = .empty,
    closed: usize = 0,
    /// Reject an offset once, as a geo-replicated namespace does.
    reject_offsets: bool = false,
    opener: PartitionOpener = .{
        .partitionIdsFn = partitionIds,
        .openFn = open,
        .closeFn = close,
    },

    const Opened = struct {
        partition_id: []u8,
        position: EventPosition,
        /// An owned copy: the position's offset is borrowed from the
        /// checkpoint list, which the cycle frees before the test looks.
        offset: ?[]u8,
    };

    fn deinit(self: *FakeOpener) void {
        for (self.opened.items) |o| {
            self.allocator.free(o.partition_id);
            if (o.offset) |offset| self.allocator.free(offset);
        }
        self.opened.deinit(self.allocator);
    }

    fn positionFor(self: *FakeOpener, partition_id: []const u8) ?EventPosition {
        var found: ?EventPosition = null;
        for (self.opened.items) |o| {
            if (std.mem.eql(u8, o.partition_id, partition_id)) found = o.position;
        }
        return found;
    }

    fn partitionIds(o: *PartitionOpener, allocator: Allocator) anyerror![][]const u8 {
        const self: *FakeOpener = @fieldParentPtr("opener", o);
        const ids = try allocator.alloc([]const u8, self.partitions.len);
        errdefer allocator.free(ids);
        for (ids, self.partitions) |*slot, id| slot.* = try allocator.dupe(u8, id);
        return ids;
    }

    fn open(
        o: *PartitionOpener,
        allocator: Allocator,
        partition_id: []const u8,
        position: EventPosition,
        _: PartitionClientOptions,
    ) anyerror!*PartitionClient {
        const self: *FakeOpener = @fieldParentPtr("opener", o);
        const id = try self.allocator.dupe(u8, partition_id);
        const offset = switch (position.location) {
            .offset => |token| try self.allocator.dupe(u8, token),
            else => null,
        };
        // No errdefer: the record outlives a rejected open, which is the
        // whole point of recording it.
        self.opened.append(self.allocator, .{
            .partition_id = id,
            .position = position,
            .offset = offset,
        }) catch |err| {
            self.allocator.free(id);
            if (offset) |token| self.allocator.free(token);
            return err;
        };

        if (self.reject_offsets and position.location == .offset) {
            return error.GeoReplicationOffsetRejected;
        }

        const client = try allocator.create(PartitionClient);
        client.* = .{
            .allocator = allocator,
            .receiver = undefined,
            .filter_expression = &.{},
            .prefetch = 0,
            .owner_level = null,
            .deadline_ms = 0,
        };
        return client;
    }

    fn close(o: *PartitionOpener, client: *PartitionClient) void {
        const self: *FakeOpener = @fieldParentPtr("opener", o);
        self.closed += 1;
        client.allocator.destroy(client);
    }
};

const test_details = OwnershipDetails{
    .fully_qualified_namespace = "ns.servicebus.windows.net",
    .event_hub_name = "my-hub",
    .consumer_group = "$Default",
    .client_id = "processor-a",
};

test "a cycle opens a reader for every partition it claims, exactly once" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{ "0", "1" } };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(7);
    var processor = Processor.init(
        allocator,
        &store.store,
        &opener.opener,
        test_details,
        .{ .load_balancing_strategy = .greedy },
        &clock.clock,
        random.random(),
    );
    defer processor.deinit();

    try processor.runOnce();
    try testing.expectEqual(@as(usize, 2), processor.ownedPartitions().len);
    try testing.expectEqual(@as(usize, 2), opener.opened.items.len);

    // Renewal must not reopen: the link is already attached, and dropping it
    // every ten seconds would replay from the last checkpoint each time.
    try processor.runOnce();
    try testing.expectEqual(@as(usize, 2), opener.opened.items.len);
    try testing.expectEqual(@as(usize, 0), opener.closed);
}

test "each claimed partition is handed out once" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{ "0", "1" } };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(3);
    var processor = Processor.init(
        allocator,
        &store.store,
        &opener.opener,
        test_details,
        .{ .load_balancing_strategy = .greedy },
        &clock.clock,
        random.random(),
    );
    defer processor.deinit();

    try processor.runOnce();

    var seen: usize = 0;
    while (processor.nextPartitionClient()) |client| : (seen += 1) {
        try testing.expect(client.partitionId().len > 0);
    }
    try testing.expectEqual(@as(usize, 2), seen);
    // A second drain yields nothing: the reader is already the caller's.
    try testing.expect(processor.nextPartitionClient() == null);
}

test "a reader that lost ownership is closed rather than reused" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{"0"} };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(11);
    var processor = Processor.init(
        allocator,
        &store.store,
        &opener.opener,
        test_details,
        .{ .load_balancing_strategy = .greedy },
        &clock.clock,
        random.random(),
    );
    defer processor.deinit();

    try processor.runOnce();
    const first = processor.nextPartitionClient().?;

    // Set directly rather than through `receiveEvents`, which would need a
    // live link. The flag is what the receive path sets on `amqp:link:stolen`.
    first.ownership_lost = true;

    try processor.runOnce();

    // The link is gone, so the reader must be too. Go drops the client and
    // lets the next cycle decide; because the store still says the partition
    // is ours, that means a fresh reader rather than the dead one.
    try testing.expectEqual(@as(usize, 1), opener.closed);
    try testing.expectEqual(@as(usize, 2), opener.opened.items.len);
    try testing.expectEqual(@as(usize, 1), processor.ownedPartitions().len);

    const second = processor.nextPartitionClient().?;
    try testing.expect(!second.ownership_lost);
}

test "a partition claimed by another processor is released" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{"0"} };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(19);
    var processor = Processor.init(
        allocator,
        &store.store,
        &opener.opener,
        test_details,
        .{ .load_balancing_strategy = .greedy },
        &clock.clock,
        random.random(),
    );
    defer processor.deinit();

    try processor.runOnce();
    try testing.expectEqual(@as(usize, 1), processor.ownedPartitions().len);

    const stolen = [_]checkpoint_types.PartitionOwnership{.{
        .fully_qualified_namespace = test_details.fully_qualified_namespace,
        .event_hub_name = test_details.event_hub_name,
        .consumer_group = test_details.consumer_group,
        .partition_id = "0",
        .owner_id = "processor-b",
    }};
    const taken = try store.store.claimOwnership(allocator, &stolen);
    checkpoint_types.freeOwnerships(allocator, taken);

    try processor.runOnce();
    try testing.expectEqual(@as(usize, 0), processor.ownedPartitions().len);
    try testing.expectEqual(@as(usize, 1), opener.closed);
}

test "a rejected offset reopens at earliest, inclusive" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    try store.store.updateCheckpoint(allocator, .{
        .fully_qualified_namespace = test_details.fully_qualified_namespace,
        .event_hub_name = test_details.event_hub_name,
        .consumer_group = test_details.consumer_group,
        .partition_id = "0",
        .offset = "12345",
    });

    var opener = FakeOpener{
        .allocator = allocator,
        .partitions = &.{"0"},
        .reject_offsets = true,
    };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(5);
    var processor = Processor.init(
        allocator,
        &store.store,
        &opener.opener,
        test_details,
        .{ .load_balancing_strategy = .greedy },
        &clock.clock,
        random.random(),
    );
    defer processor.deinit();

    try processor.runOnce();

    try testing.expectEqual(@as(usize, 2), opener.opened.items.len);
    try testing.expectEqualStrings("12345", opener.opened.items[0].offset.?);
    const retried = opener.opened.items[1].position;
    try testing.expectEqual(start_position_types.StartLocation.earliest, retried.location);
    try testing.expect(retried.is_inclusive);
    try testing.expectEqual(@as(usize, 1), processor.ownedPartitions().len);
}

test "the checkpoint decides where a reader starts" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    try store.store.updateCheckpoint(allocator, .{
        .fully_qualified_namespace = test_details.fully_qualified_namespace,
        .event_hub_name = test_details.event_hub_name,
        .consumer_group = test_details.consumer_group,
        .partition_id = "1",
        .sequence_number = 99,
    });

    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{ "0", "1" } };
    defer opener.deinit();

    var positions = start_position_types.StartPositions{
        .default = EventPosition.earliest(),
    };
    defer positions.deinit(allocator);

    var random = std.Random.DefaultPrng.init(13);
    var processor = Processor.init(
        allocator,
        &store.store,
        &opener.opener,
        test_details,
        .{ .load_balancing_strategy = .greedy, .start_positions = positions },
        &clock.clock,
        random.random(),
    );
    defer processor.deinit();

    try processor.runOnce();

    // The checkpointed partition resumes after event 99; the other falls
    // through to the configured default.
    const resumed = opener.positionFor("1").?;
    try testing.expectEqual(@as(i64, 99), resumed.location.sequence_number);
    try testing.expect(!resumed.is_inclusive);
    try testing.expectEqual(
        start_position_types.StartLocation.earliest,
        opener.positionFor("0").?.location,
    );
}

test "shutdown relinquishes every partition it held" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{ "0", "1" } };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(17);
    var processor = Processor.init(
        allocator,
        &store.store,
        &opener.opener,
        test_details,
        .{ .load_balancing_strategy = .greedy },
        &clock.clock,
        random.random(),
    );
    try processor.runOnce();
    try testing.expectEqual(@as(usize, 2), processor.ownedPartitions().len);
    processor.deinit();

    try testing.expectEqual(@as(usize, 2), opener.closed);
    for (store.ownerships.items) |ownership| {
        try testing.expect(ownership.isRelinquished());
    }
}
