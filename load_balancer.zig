//! Distributed consumption: the `Processor` and its load balancer.
//!
//! One consumer per partition is the easy case. The hard case is a fleet of
//! processors that has to agree on who reads what, survive members joining and
//! leaving, and resume where the last owner stopped. Every SDK solves it the
//! same way: ownership records in a shared store, claimed and renewed on a
//! timer, with a balancing rule that converges on an even split.
//!
//! This is a port of Go's `processorLoadBalancer` (`processor_load_balancer.go`)
//! and the start-position precedence in `processor.go`. Rust's
//! `event_processor/processor.rs` has the same two strategies.
//!
//! Nothing here starts a thread. `runOnce` performs exactly one balancing
//! cycle and the caller drives the loop, which keeps the whole algorithm
//! testable against a fake clock and a seeded random source.

const std = @import("std");
const checkpoint_types = @import("checkpoint.zig");
const errors = @import("errors.zig");
const start_position_types = @import("position.zig");

const Allocator = std.mem.Allocator;
const Checkpoint = checkpoint_types.Checkpoint;
const CheckpointStore = checkpoint_types.CheckpointStore;
const PartitionOwnership = checkpoint_types.PartitionOwnership;
const EventPosition = start_position_types.EventPosition;
const StartPositions = start_position_types.StartPositions;

/// How aggressively a processor claims partitions.
pub const LoadBalancingStrategy = enum {
    /// Claim at most one partition per cycle. Slower to converge, but a
    /// restarting fleet does not thrash.
    balanced,
    /// Claim up to the fair share in a single cycle.
    greedy,
};

/// Go's defaults. Rust uses a 30s interval and greedy; Go's are the more
/// conservative pair and the ones the issue asks for.
pub const default_update_interval_ms: i64 = 10_000;
pub const default_partition_expiration_ms: i64 = 60_000;

/// Jitter bounds applied to the loop interval, matching Go's retry jitter.
pub const jitter_min = 0.8;
pub const jitter_max = 1.3;

pub const ProcessorOptions = struct {
    load_balancing_strategy: LoadBalancingStrategy = .balanced,
    /// How often ownership is re-evaluated and renewed.
    update_interval_ms: i64 = default_update_interval_ms,
    /// How long an unrenewed ownership stays valid. Must comfortably exceed
    /// the update interval or a live owner expires between its own renewals.
    partition_expiration_ms: i64 = default_partition_expiration_ms,
    /// Where to start a partition that has no checkpoint.
    start_positions: StartPositions = .{},
    prefetch: i32 = 0,
};

/// Wall clock, injected so the expiry rules can be tested without waiting.
/// A `Clock` over the system clock.
pub const Clock = checkpoint_types.Clock;
pub const SystemClock = checkpoint_types.SystemClock;

/// Identifies the consumer group this processor balances within.
pub const OwnershipDetails = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    consumer_group: []const u8,
    /// This processor's identity, written into every ownership it claims.
    client_id: []const u8,
};

/// The empty owner id a departing processor writes to release a partition.
pub const relinquished_owner_id = "";

/// What one balancing cycle decided, before anything is written.
///
/// Kept separate from the claim so the decision can be asserted directly:
/// the claim's result depends on what the store accepts, which is a different
/// question from what the algorithm asked for.
pub const Plan = struct {
    allocator: Allocator,
    /// Ownerships to claim or renew this cycle.
    requested: []PartitionOwnership,
    /// What this processor already held, before the cycle.
    held: usize,
    /// The fair share this processor is allowed.
    max_allowed: usize,
    /// Whether the cycle decided to reach for more.
    claim_more: bool,

    pub fn deinit(self: *Plan) void {
        for (self.requested) |ownership| freeOwned(self.allocator, ownership);
        self.allocator.free(self.requested);
    }

    /// Whether `partition_id` is in the plan.
    pub fn includes(self: Plan, partition_id: []const u8) bool {
        for (self.requested) |ownership| {
            if (std.mem.eql(u8, ownership.partition_id, partition_id)) return true;
        }
        return false;
    }
};

const freeOwned = checkpoint_types.freeOwned;
const dupeOwnership = checkpoint_types.dupeOwnership;

/// Decides which partitions this processor should own.
///
/// Not thread safe, and not meant to be: one processor runs one balancer.
pub const LoadBalancer = struct {
    allocator: Allocator,
    store: *CheckpointStore,
    details: OwnershipDetails,
    strategy: LoadBalancingStrategy = .balanced,
    partition_expiration_ms: i64 = default_partition_expiration_ms,
    clock: *Clock,
    random: std.Random,

    /// Work out what to claim this cycle, without claiming it.
    pub fn plan(self: *LoadBalancer, partition_ids: []const []const u8) !Plan {
        const existing = try self.store.listOwnership(
            self.allocator,
            self.details.fully_qualified_namespace,
            self.details.event_hub_name,
            self.details.consumer_group,
        );
        defer checkpoint_types.freeOwnerships(self.allocator, existing);

        return self.planFrom(partition_ids, existing);
    }

    /// The algorithm proper, over an already-listed ownership set.
    pub fn planFrom(
        self: *LoadBalancer,
        partition_ids: []const []const u8,
        existing: []const PartitionOwnership,
    ) !Plan {
        const now = self.clock.nowMillis();

        var seen: std.StringHashMapUnmanaged(void) = .empty;
        defer seen.deinit(self.allocator);

        // Owner id -> how many live partitions it holds. Every owner counts,
        // including this one, because the fair share is per participant.
        var by_owner: std.StringHashMapUnmanaged(usize) = .empty;
        defer by_owner.deinit(self.allocator);
        try by_owner.put(self.allocator, self.details.client_id, 0);

        var available: std.ArrayList(PartitionOwnership) = .empty;
        defer available.deinit(self.allocator);
        var mine: std.ArrayList(PartitionOwnership) = .empty;
        defer mine.deinit(self.allocator);
        var others: std.ArrayList(PartitionOwnership) = .empty;
        defer others.deinit(self.allocator);

        for (existing) |ownership| {
            try seen.put(self.allocator, ownership.partition_id, {});

            // Expired first: a record whose owner stopped renewing is free
            // regardless of whose name is on it.
            const last_modified = ownership.last_modified_time orelse 0;
            if (now - last_modified * std.time.ms_per_s > self.partition_expiration_ms) {
                try available.append(self.allocator, ownership);
                continue;
            }
            if (ownership.isRelinquished()) {
                try available.append(self.allocator, ownership);
                continue;
            }

            const gop = try by_owner.getOrPut(self.allocator, ownership.owner_id);
            gop.value_ptr.* = if (gop.found_existing) gop.value_ptr.* + 1 else 1;

            if (std.mem.eql(u8, ownership.owner_id, self.details.client_id)) {
                try mine.append(self.allocator, ownership);
            } else {
                try others.append(self.allocator, ownership);
            }
        }

        // Partitions nobody has ever owned have no record at all.
        for (partition_ids) |id| {
            if (seen.contains(id)) continue;
            try available.append(self.allocator, .{
                .fully_qualified_namespace = self.details.fully_qualified_namespace,
                .event_hub_name = self.details.event_hub_name,
                .consumer_group = self.details.consumer_group,
                .partition_id = id,
                .owner_id = self.details.client_id,
            });
        }

        const owners = by_owner.count();
        const min_required = partition_ids.len / owners;
        const allow_extra = partition_ids.len % owners > 0;
        var max_allowed = min_required;
        // An extra partition is only allowed once the minimum is met.
        // Otherwise a processor that is still below its share would defend a
        // surplus it has no claim to.
        if (allow_extra and mine.items.len >= min_required) max_allowed += 1;

        // Only an owner *above* the fair share is worth stealing from.
        var above_max: std.ArrayList(PartitionOwnership) = .empty;
        defer above_max.deinit(self.allocator);
        var owner_it = by_owner.iterator();
        while (owner_it.next()) |entry| {
            if (std.mem.eql(u8, entry.key_ptr.*, self.details.client_id)) continue;
            if (entry.value_ptr.* <= max_allowed) continue;
            for (others.items) |ownership| {
                if (std.mem.eql(u8, ownership.owner_id, entry.key_ptr.*)) {
                    try above_max.append(self.allocator, ownership);
                }
            }
        }

        var claim_more = true;
        if (mine.items.len >= max_allowed) {
            // Exactly right, or too many and expecting to be stolen from.
            claim_more = false;
        } else if (allow_extra and mine.items.len == max_allowed - 1) {
            // One under, in the uneven case. Worth one more only if there is
            // something to take that nobody is entitled to.
            claim_more = available.items.len > 0 or above_max.items.len > 0;
        }

        var requested: std.ArrayList(PartitionOwnership) = .empty;
        errdefer {
            for (requested.items) |ownership| freeOwned(self.allocator, ownership);
            requested.deinit(self.allocator);
        }

        // Renewing what is already held is the whole of the steady state:
        // ownership expires unless it is re-claimed every cycle.
        for (mine.items) |ownership| {
            try requested.append(self.allocator, try dupeOwnership(
                self.allocator,
                ownership,
                self.details.client_id,
            ));
        }

        if (claim_more) {
            const room = max_allowed - mine.items.len;
            switch (self.strategy) {
                .greedy => {
                    // Free partitions first; stealing is a last resort even
                    // when greedy.
                    try self.takeRandom(&requested, available.items, room);
                    if (requested.items.len < max_allowed) {
                        try self.takeRandom(
                            &requested,
                            above_max.items,
                            max_allowed - requested.items.len,
                        );
                    }
                },
                .balanced => {
                    const pool = if (available.items.len > 0)
                        available.items
                    else
                        above_max.items;
                    try self.takeRandom(&requested, pool, @min(1, room));
                },
            }
        }

        return .{
            .allocator = self.allocator,
            .requested = try requested.toOwnedSlice(self.allocator),
            .held = mine.items.len,
            .max_allowed = max_allowed,
            .claim_more = claim_more,
        };
    }

    /// Take up to `count` from `pool`, at random and without repeats.
    ///
    /// Random because every processor runs the same algorithm at the same
    /// moment: picking in list order would have them all reach for the same
    /// partition and all but one lose the race, every cycle.
    fn takeRandom(
        self: *LoadBalancer,
        out: *std.ArrayList(PartitionOwnership),
        pool: []const PartitionOwnership,
        count: usize,
    ) !void {
        if (count == 0 or pool.len == 0) return;

        const indices = try self.allocator.alloc(usize, pool.len);
        defer self.allocator.free(indices);
        for (indices, 0..) |*index, i| index.* = i;
        self.random.shuffle(usize, indices);

        for (indices[0..@min(count, pool.len)]) |index| {
            try out.append(self.allocator, try dupeOwnership(
                self.allocator,
                pool[index],
                self.details.client_id,
            ));
        }
    }

    /// Plan and then claim, returning what the store accepted.
    ///
    /// Free the result with `freeOwnerships`. A partition lost to another
    /// processor is simply absent, not an error.
    pub fn loadBalance(
        self: *LoadBalancer,
        partition_ids: []const []const u8,
    ) ![]PartitionOwnership {
        var decided = try self.plan(partition_ids);
        defer decided.deinit();
        return self.store.claimOwnership(self.allocator, decided.requested);
    }

    /// Write an empty owner id for each partition, freeing it immediately.
    ///
    /// Without this a departing processor's partitions sit idle until they
    /// expire, which is a minute of nobody reading them.
    pub fn relinquish(self: *LoadBalancer, partition_ids: []const []const u8) !void {
        if (partition_ids.len == 0) return;

        const releases = try self.allocator.alloc(PartitionOwnership, partition_ids.len);
        defer self.allocator.free(releases);

        for (releases, partition_ids) |*release, id| {
            release.* = .{
                .fully_qualified_namespace = self.details.fully_qualified_namespace,
                .event_hub_name = self.details.event_hub_name,
                .consumer_group = self.details.consumer_group,
                .partition_id = id,
                .owner_id = relinquished_owner_id,
            };
        }

        const claimed = try self.store.claimOwnership(self.allocator, releases);
        checkpoint_types.freeOwnerships(self.allocator, claimed);
    }

    /// The next cycle's delay, jittered so a fleet does not synchronise.
    pub fn nextIntervalMs(self: *LoadBalancer, update_interval_ms: i64) i64 {
        const factor = jitter_min + self.random.float(f64) * (jitter_max - jitter_min);
        const jittered: f64 = @as(f64, @floatFromInt(update_interval_ms)) * factor;
        return @intFromFloat(jittered);
    }
};

/// Where a partition should start reading.
///
/// Go's precedence, exactly: a checkpoint wins over everything, preferring
/// offset to sequence number; then a per-partition configured position; then
/// the default. A checkpoint that carries neither offset nor sequence number
/// is corrupt and is reported rather than silently ignored, because starting
/// over would replay the partition.
pub const StartPositionError = error{InvalidCheckpoint};

pub fn resolveStartPosition(
    positions: StartPositions,
    partition_id: []const u8,
    stored: ?Checkpoint,
) StartPositionError!EventPosition {
    const found = stored orelse return positions.forPartition(partition_id);

    if (found.offset) |offset| return EventPosition.fromOffset(offset, false);
    if (found.sequence_number) |sequence| return EventPosition.fromSequenceNumber(sequence, false);
    return StartPositionError.InvalidCheckpoint;
}

/// The position to fall back to when a namespace rejects a checkpointed
/// offset.
///
/// A geo-replicated namespace has no meaningful integer offsets: they are
/// per-replica, so one carried over from before a failover names nothing.
/// Go restarts such a partition at earliest, inclusive, which replays rather
/// than skips — duplicates being the acceptable failure here.
pub const geo_replication_fallback = EventPosition{
    .location = .earliest,
    .is_inclusive = true,
};

/// The error a partition opener returns when the namespace refused the
/// checkpointed offset. The processor turns it into the earliest-inclusive
/// restart rather than giving up on the partition.
pub const GeoReplicationOffsetRejected = error.GeoReplicationOffsetRejected;

/// Whether an AMQP error condition says the namespace refused the offset.
///
/// Go keys this off the condition rather than a stable error code, because
/// the condition is fatal for retry purposes and so has no code of its own.
pub fn isGeoReplicationOffsetError(amqp_condition: ?[]const u8) bool {
    const c = amqp_condition orelse return false;
    return std.mem.eql(u8, c, geo_replication_condition);
}

/// The condition Event Hubs returns for an offset a replicated namespace
/// cannot interpret.
pub const geo_replication_condition = errors.condition.georeplication_invalid_offset;

// ─────────────────────────── Tests ───────────────────────────

const testing = std.testing;

/// An in-memory `CheckpointStore` with last-write-wins claiming.
///
/// Enough to converge two processors, which is what the balancing rules are
/// actually about; the blob store's etag races are its own tests' business.
const TestClock = checkpoint_types.ManualClock;
const MemoryStore = checkpoint_types.InMemoryCheckpointStore;

const test_details = OwnershipDetails{
    .fully_qualified_namespace = "ns.servicebus.windows.net",
    .event_hub_name = "my-hub",
    .consumer_group = "$Default",
    .client_id = "processor-a",
};

const eight_partitions = [_][]const u8{ "0", "1", "2", "3", "4", "5", "6", "7" };

fn ownedCount(store: *MemoryStore, owner_id: []const u8) usize {
    var count: usize = 0;
    for (store.ownerships.items) |ownership| {
        if (std.mem.eql(u8, ownership.owner_id, owner_id)) count += 1;
    }
    return count;
}

test "greedy claims the whole fair share in one cycle" {
    const allocator = testing.allocator;
    var clock = TestClock{};
    var store = MemoryStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();

    var prng = std.Random.DefaultPrng.init(1);
    var balancer = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = test_details,
        .strategy = .greedy,
        .clock = &clock.clock,
        .random = prng.random(),
    };

    const claimed = try balancer.loadBalance(&eight_partitions);
    defer checkpoint_types.freeOwnerships(allocator, claimed);

    // Sole processor: the fair share is everything.
    try testing.expectEqual(@as(usize, 8), claimed.len);
}

test "balanced claims one partition per cycle" {
    const allocator = testing.allocator;
    var clock = TestClock{};
    var store = MemoryStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();

    var prng = std.Random.DefaultPrng.init(1);
    var balancer = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = test_details,
        .strategy = .balanced,
        .clock = &clock.clock,
        .random = prng.random(),
    };

    for (1..5) |cycle| {
        const claimed = try balancer.loadBalance(&eight_partitions);
        defer checkpoint_types.freeOwnerships(allocator, claimed);
        // One more each time, on top of everything already held: a renewal is
        // a claim, so the total is the cycle number.
        try testing.expectEqual(cycle, claimed.len);
    }
}

/// Run two processors to convergence and report the split.
fn converge(
    allocator: Allocator,
    strategy: LoadBalancingStrategy,
    cycles: usize,
) ![2]usize {
    var clock = TestClock{};
    var store = MemoryStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();

    var prng_a = std.Random.DefaultPrng.init(7);
    var prng_b = std.Random.DefaultPrng.init(11);

    var a = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = test_details,
        .strategy = strategy,
        .clock = &clock.clock,
        .random = prng_a.random(),
    };
    var details_b = test_details;
    details_b.client_id = "processor-b";
    var b = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = details_b,
        .strategy = strategy,
        .clock = &clock.clock,
        .random = prng_b.random(),
    };

    for (0..cycles) |_| {
        for ([_]*LoadBalancer{ &a, &b }) |balancer| {
            const claimed = try balancer.loadBalance(&eight_partitions);
            checkpoint_types.freeOwnerships(allocator, claimed);
        }
        // Well inside the expiration, so nothing is reclaimed as stale.
        clock.advance(1_000);
    }

    return .{
        ownedCount(&store, "processor-a"),
        ownedCount(&store, "processor-b"),
    };
}

test "two greedy processors converge on a four-four split" {
    const split = try converge(testing.allocator, .greedy, 6);
    try testing.expectEqual(@as(usize, 4), split[0]);
    try testing.expectEqual(@as(usize, 4), split[1]);
}

test "two balanced processors converge on a four-four split" {
    // Balanced takes one partition per cycle, so it needs more of them.
    const split = try converge(testing.allocator, .balanced, 12);
    try testing.expectEqual(@as(usize, 4), split[0]);
    try testing.expectEqual(@as(usize, 4), split[1]);
}

test "an expired ownership is reclaimed and a live one is not" {
    const allocator = testing.allocator;
    var clock = TestClock{};
    var store = MemoryStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();

    const partitions = [_][]const u8{ "0", "1" };
    const now_s = @divFloor(clock.millis, std.time.ms_per_s);
    try store.ownerships.append(allocator, try dupeOwnership(allocator, .{
        .fully_qualified_namespace = test_details.fully_qualified_namespace,
        .event_hub_name = test_details.event_hub_name,
        .consumer_group = test_details.consumer_group,
        .partition_id = "0",
        .owner_id = "processor-b",
        // Stopped renewing two minutes ago.
        .last_modified_time = now_s - 120,
    }, "processor-b"));
    try store.ownerships.append(allocator, try dupeOwnership(allocator, .{
        .fully_qualified_namespace = test_details.fully_qualified_namespace,
        .event_hub_name = test_details.event_hub_name,
        .consumer_group = test_details.consumer_group,
        .partition_id = "1",
        .owner_id = "processor-b",
        .last_modified_time = now_s,
    }, "processor-b"));

    var prng = std.Random.DefaultPrng.init(3);
    var balancer = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = test_details,
        .strategy = .greedy,
        .clock = &clock.clock,
        .random = prng.random(),
    };

    var decided = try balancer.plan(&partitions);
    defer decided.deinit();

    // Partition 0's owner is gone; partition 1's is alive and holds exactly
    // its fair share, so taking it would only start a tug of war.
    try testing.expect(decided.includes("0"));
    try testing.expect(!decided.includes("1"));
}

test "a relinquished partition is available immediately" {
    const allocator = testing.allocator;
    var clock = TestClock{};
    var store = MemoryStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();

    const partitions = [_][]const u8{ "0", "1" };
    const now_s = @divFloor(clock.millis, std.time.ms_per_s);
    try store.ownerships.append(allocator, try dupeOwnership(allocator, .{
        .fully_qualified_namespace = test_details.fully_qualified_namespace,
        .event_hub_name = test_details.event_hub_name,
        .consumer_group = test_details.consumer_group,
        .partition_id = "0",
        .owner_id = relinquished_owner_id,
        // Freshly written, so only the empty owner id makes it available.
        .last_modified_time = now_s,
    }, relinquished_owner_id));

    var prng = std.Random.DefaultPrng.init(5);
    var balancer = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = test_details,
        .strategy = .greedy,
        .clock = &clock.clock,
        .random = prng.random(),
    };

    var decided = try balancer.plan(&partitions);
    defer decided.deinit();
    try testing.expect(decided.includes("0"));
}

test "relinquishing hands the partition to the other processor" {
    const allocator = testing.allocator;
    var clock = TestClock{};
    var store = MemoryStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();

    const partitions = [_][]const u8{"0"};
    var prng_a = std.Random.DefaultPrng.init(2);
    var a = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = test_details,
        .strategy = .greedy,
        .clock = &clock.clock,
        .random = prng_a.random(),
    };
    const first = try a.loadBalance(&partitions);
    checkpoint_types.freeOwnerships(allocator, first);
    try testing.expectEqual(@as(usize, 1), ownedCount(&store, "processor-a"));

    try a.relinquish(&partitions);

    var details_b = test_details;
    details_b.client_id = "processor-b";
    var prng_b = std.Random.DefaultPrng.init(4);
    var b = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = details_b,
        .strategy = .greedy,
        .clock = &clock.clock,
        .random = prng_b.random(),
    };

    // Without the relinquish this would wait out the full expiration, which
    // is a minute of nobody reading the partition.
    const second = try b.loadBalance(&partitions);
    checkpoint_types.freeOwnerships(allocator, second);
    try testing.expectEqual(@as(usize, 1), ownedCount(&store, "processor-b"));
}

test "a checkpoint beats the configured start position" {
    const allocator = testing.allocator;
    var positions = StartPositions{ .default = EventPosition.latest() };
    defer positions.deinit(allocator);
    try positions.put(allocator, "0", EventPosition.earliest());

    const from_offset = try resolveStartPosition(positions, "0", .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .offset = "12345",
    });
    try testing.expectEqualStrings("12345", from_offset.location.offset);
    try testing.expect(!from_offset.is_inclusive);

    // Offset wins over sequence number when a checkpoint carries both: it is
    // the more precise of the two.
    const both = try resolveStartPosition(positions, "0", .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .offset = "999",
        .sequence_number = 42,
    });
    try testing.expectEqualStrings("999", both.location.offset);

    const from_sequence = try resolveStartPosition(positions, "0", .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .sequence_number = 42,
    });
    try testing.expectEqual(@as(i64, 42), from_sequence.location.sequence_number);
}

test "the per-partition position beats the default" {
    const allocator = testing.allocator;
    var positions = StartPositions{ .default = EventPosition.latest() };
    defer positions.deinit(allocator);
    try positions.put(allocator, "0", EventPosition.earliest());

    const configured = try resolveStartPosition(positions, "0", null);
    try testing.expectEqual(start_position_types.StartLocation.earliest, configured.location);

    const fallback = try resolveStartPosition(positions, "1", null);
    try testing.expectEqual(start_position_types.StartLocation.latest, fallback.location);
}

test "a checkpoint with neither offset nor sequence number is rejected" {
    // Silently starting over would replay the whole partition, which is worse
    // than telling the caller their store is corrupt.
    try testing.expectError(StartPositionError.InvalidCheckpoint, resolveStartPosition(.{}, "0", .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
    }));
}

test "a geo-replication offset rejection falls back to inclusive earliest" {
    try testing.expect(isGeoReplicationOffsetError(geo_replication_condition));
    try testing.expect(!isGeoReplicationOffsetError(null));
    try testing.expectEqual(start_position_types.StartLocation.earliest, geo_replication_fallback.location);
    // Inclusive, so the event the offset named is replayed rather than lost.
    try testing.expect(geo_replication_fallback.is_inclusive);

    try testing.expect(!isGeoReplicationOffsetError("amqp:link:detach-forced"));
}

test "the loop interval is jittered within Go's bounds" {
    const allocator = testing.allocator;
    var clock = TestClock{};
    var store = MemoryStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();

    var prng = std.Random.DefaultPrng.init(9);
    var balancer = LoadBalancer{
        .allocator = allocator,
        .store = &store.store,
        .details = test_details,
        .clock = &clock.clock,
        .random = prng.random(),
    };

    // A fleet that all restarted together would otherwise balance in
    // lockstep, and every cycle would be a race nobody needs to run.
    var saw_below: bool = false;
    var saw_above: bool = false;
    for (0..200) |_| {
        const interval = balancer.nextIntervalMs(10_000);
        try testing.expect(interval >= 8_000);
        try testing.expect(interval <= 13_000);
        if (interval < 10_000) saw_below = true;
        if (interval > 10_000) saw_above = true;
    }
    try testing.expect(saw_below);
    try testing.expect(saw_above);
}
