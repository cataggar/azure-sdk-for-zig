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
const amqp = @import("azure_sdk_amqp");
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
    closeFn: *const fn (self: *PartitionOpener, client: *PartitionClient) anyerror!void,
    abortFn: *const fn (self: *PartitionOpener, client: *PartitionClient) void,

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

    pub fn close(self: *PartitionOpener, client: *PartitionClient) !void {
        try self.closeFn(self, client);
    }

    /// Dispose a client that attached successfully but could not be registered
    /// with its processor.
    pub fn abort(self: *PartitionOpener, client: *PartitionClient) void {
        self.abortFn(self, client);
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
    processor: *Processor,
    link_closed: bool = false,
    finalized: bool = false,
    /// Set when the broker says another processor took the partition. The
    /// processor releases rather than retries: the whole point of an owner
    /// level is that the newer reader wins.
    ownership_lost: bool = false,
    /// A local post-consumption failure made the link terminal without
    /// advancing its selector. The next balancing cycle replaces this reader
    /// so the broker can replay from the checkpoint.
    recoverable_failure: bool = false,

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
        if (self.link_closed) return error.LinkDetached;
        const events = self.client.receiveEvents(allocator, count) catch |err| {
            self.observeClientState();
            return err;
        };
        // A receiver can return a valid short batch after the frame that
        // terminally detached it. Preserve those events, but replace the link
        // on the next cycle.
        self.observeClientState();
        return events;
    }

    fn observeClientState(self: *ProcessorPartitionClient) void {
        _ = self.client.refreshGeneration();
        if (self.client.last_error) |info| {
            if (info.code == .ownership_lost) self.ownership_lost = true;
        }
        if (!self.ownership_lost and self.client.terminal) {
            self.recoverable_failure = true;
        }
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

    /// Close the underlying link and release it from the processor.
    ///
    /// An ambiguous detach keeps this wrapper registered so the caller can
    /// retry the same close handshake. After success this pointer is invalid;
    /// a later balancing cycle may open a replacement for the partition.
    pub fn close(self: *ProcessorPartitionClient) !void {
        const processor = self.processor;
        const partition_id = self.partition_id;
        try processor.releasePartition(partition_id);
    }

    fn closeReader(self: *ProcessorPartitionClient) !void {
        if (self.link_closed) return;
        try self.opener.close(self.client);
        self.link_closed = true;
    }

    fn finishClose(self: *ProcessorPartitionClient) void {
        if (self.finalized) return;
        self.allocator.free(self.partition_id);
        self.partition_id = &.{};
        self.finalized = true;
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
    /// Partitions whose broker link reported ownership loss. They are not
    /// reopened while the store still claims them for this processor; seeing
    /// a cycle where another owner holds them clears the suppression.
    suppressed: std.StringHashMapUnmanaged(void) = .empty,
    closing: bool = false,
    relinquished: bool = false,
    deinitialized: bool = false,

    /// Keep the returned value at a stable address after its first balancing
    /// cycle. Partition readers retain a pointer to their owning processor so
    /// a successful public close can unregister itself.
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

    /// Detach every reader while its connection is still alive.
    ///
    /// An ambiguous detach is returned and its wrapper remains owned, so this
    /// operation can be retried after the session receives more frames.
    /// Relinquishing is best effort; ownership records also expire naturally.
    pub fn close(self: *Processor) !void {
        if (self.deinitialized) return;
        self.closing = true;
        self.relinquish();

        var first_error: ?anyerror = null;
        var index: usize = 0;
        while (index < self.clients.count()) {
            const id = self.clients.keys()[index];
            self.releasePartition(id) catch |err| {
                if (first_error == null) first_error = err;
                index += 1;
                continue;
            };
        }
        if (first_error) |err| return err;
    }

    /// Release all processor-owned allocations.
    ///
    /// Call `close` first while the connection is usable. If closing remains
    /// ambiguous, terminate the owning connection/session before `deinit`;
    /// this method never dereferences a native receiver and leaves its final
    /// destruction to that owner.
    pub fn deinit(self: *Processor) void {
        if (self.deinitialized) return;
        self.relinquish();

        for (self.clients.values()) |client| {
            if (!client.link_closed) {
                client.client.deinit();
                client.client.allocator.destroy(client.client);
            }
            client.finishClose();
            self.allocator.destroy(client);
        }
        self.clients.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        var suppressed = self.suppressed.keyIterator();
        while (suppressed.next()) |id| self.allocator.free(id.*);
        self.suppressed.deinit(self.allocator);
        self.deinitialized = true;
    }

    fn relinquish(self: *Processor) void {
        if (self.relinquished) return;
        var held: std.ArrayList([]const u8) = .empty;
        defer held.deinit(self.allocator);
        for (self.clients.keys()) |id| held.append(self.allocator, id) catch {};
        var suppressed = self.suppressed.keyIterator();
        while (suppressed.next()) |id| {
            if (!self.clients.contains(id.*)) held.append(self.allocator, id.*) catch {};
        }
        self.balancer.relinquish(held.items) catch {};
        self.relinquished = true;
    }

    /// One balancing cycle: claim, renew, open, and release.
    pub fn runOnce(self: *Processor) !void {
        if (self.closing or self.deinitialized) return error.ProcessorClosed;
        const partition_ids = try self.opener.partitionIds(self.allocator);
        defer freePartitionIds(self.allocator, partition_ids);

        const claimed = try self.balancer.loadBalance(partition_ids);
        defer checkpoint_types.freeOwnerships(self.allocator, claimed);

        try self.releaseUnclaimed(claimed);
        try self.clearUnclaimedSuppressions(claimed);

        const checkpoints = try self.store.listCheckpoints(
            self.allocator,
            self.details.fully_qualified_namespace,
            self.details.event_hub_name,
            self.details.consumer_group,
        );
        defer checkpoint_types.freeCheckpoints(self.allocator, checkpoints);

        for (claimed) |ownership| {
            if (self.clients.contains(ownership.partition_id) or
                self.suppressed.contains(ownership.partition_id)) continue;
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
            if (!client.link_closed) client.observeClientState();
            var kept = false;
            for (claimed) |ownership| {
                if (std.mem.eql(u8, ownership.partition_id, id)) {
                    kept = true;
                    break;
                }
            }
            if (kept and !client.ownership_lost and !client.recoverable_failure) continue;
            if (client.ownership_lost) try self.suppress(id);
            try dropped.append(self.allocator, id);
        }

        for (dropped.items) |id| try self.releasePartition(id);
    }

    fn suppress(self: *Processor, partition_id: []const u8) !void {
        if (self.suppressed.contains(partition_id)) return;
        const owned = try self.allocator.dupe(u8, partition_id);
        errdefer self.allocator.free(owned);
        try self.suppressed.put(self.allocator, owned, {});
    }

    fn clearUnclaimedSuppressions(
        self: *Processor,
        claimed: []const checkpoint_types.PartitionOwnership,
    ) !void {
        var cleared: std.ArrayList([]const u8) = .empty;
        defer cleared.deinit(self.allocator);

        var it = self.suppressed.keyIterator();
        while (it.next()) |id| {
            var still_claimed = false;
            for (claimed) |ownership| {
                if (std.mem.eql(u8, ownership.partition_id, id.*)) {
                    still_claimed = true;
                    break;
                }
            }
            if (!still_claimed) try cleared.append(self.allocator, id.*);
        }

        for (cleared.items) |id| {
            const removed = self.suppressed.fetchRemove(id) orelse continue;
            self.allocator.free(removed.key);
        }
    }

    fn releasePartition(self: *Processor, partition_id: []const u8) !void {
        const client = self.clients.get(partition_id) orelse return;

        try client.closeReader();

        var i: usize = 0;
        while (i < self.pending.items.len) {
            if (self.pending.items[i] == client) {
                _ = self.pending.orderedRemove(i);
                continue;
            }
            i += 1;
        }
        _ = self.clients.orderedRemove(partition_id);
        client.finishClose();
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
        errdefer self.opener.abort(client);

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
            .processor = self,
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
    close_failures_remaining: usize = 0,
    aborted: usize = 0,
    /// Reject an offset once, as a geo-replicated namespace does.
    reject_offsets: bool = false,
    opener: PartitionOpener = .{
        .partitionIdsFn = partitionIds,
        .openFn = open,
        .closeFn = close,
        .abortFn = abort,
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
            .filter_expression = &.{},
            .prefetch = 0,
            .owner_level = null,
            .receive_timeout_ms = 0,
        };
        return client;
    }

    fn close(o: *PartitionOpener, client: *PartitionClient) anyerror!void {
        const self: *FakeOpener = @fieldParentPtr("opener", o);
        if (self.close_failures_remaining > 0) {
            self.close_failures_remaining -= 1;
            return error.Timeout;
        }
        self.closed += 1;
        client.allocator.destroy(client);
    }

    fn abort(o: *PartitionOpener, client: *PartitionClient) void {
        const self: *FakeOpener = @fieldParentPtr("opener", o);
        client.deinit();
        client.allocator.destroy(client);
        self.aborted += 1;
    }
};

const AmqpTestOpener = struct {
    session: *amqp.Session,
    generation: ?*TestGeneration = null,
    post_open_fail: ?*PostOpenFailAllocator = null,
    opens: usize = 0,
    closes: usize = 0,
    aborts: usize = 0,
    filter_bufs: [4][128]u8 = undefined,
    filter_lens: [4]usize = @splat(0),
    opener: PartitionOpener = .{
        .partitionIdsFn = partitionIds,
        .openFn = open,
        .closeFn = close,
        .abortFn = abort,
    },

    const source = "my-hub/ConsumerGroups/$default/Partitions/0";
    const instance_id = "processor-test";
    const link_name = source ++ "-receiver-" ++ instance_id;

    fn partitionIds(_: *PartitionOpener, allocator: Allocator) anyerror![][]const u8 {
        const ids = try allocator.alloc([]const u8, 1);
        errdefer allocator.free(ids);
        ids[0] = try allocator.dupe(u8, "0");
        return ids;
    }

    fn open(
        o: *PartitionOpener,
        allocator: Allocator,
        _: []const u8,
        position: EventPosition,
        options: PartitionClientOptions,
    ) anyerror!*PartitionClient {
        const self: *AmqpTestOpener = @fieldParentPtr("opener", o);
        const filter = try position.toFilterExpression(allocator);
        defer allocator.free(filter);

        const index = self.opens;
        if (index < self.filter_bufs.len) {
            const len = @min(filter.len, self.filter_bufs[index].len);
            @memcpy(self.filter_bufs[index][0..len], filter[0..len]);
            self.filter_lens[index] = len;
        }

        const client = try allocator.create(PartitionClient);
        errdefer allocator.destroy(client);
        try client.open(allocator, self.session, .{
            .source_address = source,
            .instance_id = instance_id,
            .deadline_ms = 10_000,
            .filter_expression = filter,
            .generation_guard = if (self.generation) |generation| .{
                .context = generation,
                .generation = generation.current,
                .isCurrentFn = TestGeneration.isCurrent,
            } else null,
        }, options);
        self.opens += 1;
        if (self.opens == 1) {
            if (self.post_open_fail) |failing| failing.arm();
        }
        return client;
    }

    fn close(o: *PartitionOpener, client: *PartitionClient) anyerror!void {
        const self: *AmqpTestOpener = @fieldParentPtr("opener", o);
        try client.closeAfter(10_000);
        client.allocator.destroy(client);
        self.closes += 1;
    }

    fn abort(o: *PartitionOpener, client: *PartitionClient) void {
        const self: *AmqpTestOpener = @fieldParentPtr("opener", o);
        client.closeAfter(10_000) catch client.deinit();
        client.allocator.destroy(client);
        self.aborts += 1;
    }

    fn filterAt(self: *const AmqpTestOpener, index: usize) []const u8 {
        return self.filter_bufs[index][0..self.filter_lens[index]];
    }
};

const TestGeneration = struct {
    current: u64 = 0,

    fn isCurrent(context: *anyopaque, generation: u64) bool {
        const self: *TestGeneration = @ptrCast(@alignCast(context));
        return self.current == generation;
    }
};

const PostOpenFailAllocator = struct {
    parent: Allocator,
    fail_index: usize,
    active: bool = false,
    allocations: usize = 0,
    failed: bool = false,

    fn arm(self: *PostOpenFailAllocator) void {
        self.active = true;
        self.allocations = 0;
    }

    fn allocator(self: *PostOpenFailAllocator) Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *PostOpenFailAllocator = @ptrCast(@alignCast(ctx));
        if (self.active) {
            if (self.allocations == self.fail_index) {
                self.active = false;
                self.failed = true;
                return null;
            }
            self.allocations += 1;
        }
        return self.parent.rawAlloc(len, alignment, ra);
    }

    fn resize(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *PostOpenFailAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(memory, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *PostOpenFailAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawRemap(memory, alignment, new_len, ra);
    }

    fn free(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *PostOpenFailAllocator = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(memory, alignment, ra);
    }
};

fn scriptProcessorAttach(peer: amqp.test_peer.Peer, handle: u32) !void {
    try peer.push(0, .{ .attach = .{
        .name = AmqpTestOpener.link_name,
        .handle = handle,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
}

fn pushProcessorEvent(
    allocator: Allocator,
    peer: amqp.test_peer.Peer,
    handle: u32,
    id: u32,
    sequence_number: i64,
    body: []const u8,
) !void {
    var annotations = [_]amqp.MapEntry{
        .{
            .key = .{ .symbol = event_data.sequence_number_annotation },
            .value = .{ .long = sequence_number },
        },
        .{
            .key = .{ .symbol = event_data.offset_annotation },
            .value = .{ .string = "100" },
        },
    };
    const bodies = [_][]const u8{body};
    const payload = try amqp.encodeMessageAlloc(allocator, .{
        .message_annotations = &annotations,
        .body = .{ .data = &bodies },
    });
    defer allocator.free(payload);

    const tag = std.mem.asBytes(&id);
    try peer.pushTransfer(0, .{
        .handle = handle,
        .delivery_id = id,
        .delivery_tag = tag,
        .message_format = 0,
        .settled = false,
        .more = false,
    }, payload);
}

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

test "public partition close unregisters and reopens the claimed partition" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{"0"} };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(9);
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

    opener.close_failures_remaining = 1;
    try testing.expectError(error.Timeout, first.close());
    try testing.expectEqual(@as(usize, 1), processor.ownedPartitions().len);
    try testing.expect(processor.clients.get("0").? == first);

    try first.close();
    try testing.expectEqual(@as(usize, 0), processor.ownedPartitions().len);
    try testing.expect(processor.nextPartitionClient() == null);

    try processor.runOnce();
    try testing.expectEqual(@as(usize, 1), processor.ownedPartitions().len);
    try testing.expectEqual(@as(usize, 2), opener.opened.items.len);
    _ = processor.nextPartitionClient().?;
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

    // The link is gone, so the reader must be too. The store has not observed
    // the new owner yet, so reopening now would steal the partition straight
    // back; ownership loss remains nonretryable until a cycle sees it held by
    // somebody else.
    try testing.expectEqual(@as(usize, 1), opener.closed);
    try testing.expectEqual(@as(usize, 1), opener.opened.items.len);
    try testing.expectEqual(@as(usize, 0), processor.ownedPartitions().len);
    try testing.expect(processor.nextPartitionClient() == null);
    try testing.expect(processor.suppressed.contains("0"));

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
    try testing.expect(!processor.suppressed.contains("0"));
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

test "an ambiguous partition close retains ownership for retry" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{"0"} };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(23);
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
    const retained = processor.clients.get("0").?;

    const stolen = [_]checkpoint_types.PartitionOwnership{.{
        .fully_qualified_namespace = test_details.fully_qualified_namespace,
        .event_hub_name = test_details.event_hub_name,
        .consumer_group = test_details.consumer_group,
        .partition_id = "0",
        .owner_id = "processor-b",
    }};
    const taken = try store.store.claimOwnership(allocator, &stolen);
    checkpoint_types.freeOwnerships(allocator, taken);

    opener.close_failures_remaining = 1;
    try testing.expectError(error.Timeout, processor.runOnce());
    try testing.expectEqual(@as(usize, 1), processor.ownedPartitions().len);
    try testing.expect(processor.clients.get("0").? == retained);
    try testing.expect(!retained.link_closed);

    try processor.runOnce();
    try testing.expectEqual(@as(usize, 0), processor.ownedPartitions().len);
    try testing.expectEqual(@as(usize, 1), opener.closed);
}

test "Processor.close retains timed out readers for retry" {
    const allocator = testing.allocator;
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var opener = FakeOpener{ .allocator = allocator, .partitions = &.{"0"} };
    defer opener.deinit();

    var random = std.Random.DefaultPrng.init(29);
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
    const retained = processor.clients.get("0").?;

    opener.close_failures_remaining = 1;
    try testing.expectError(error.Timeout, processor.close());
    try testing.expectEqual(@as(usize, 1), processor.ownedPartitions().len);
    try testing.expect(processor.clients.get("0").? == retained);
    try testing.expect(!retained.link_closed);

    try processor.close();
    try processor.close();
    try testing.expectEqual(@as(usize, 0), processor.ownedPartitions().len);
    try testing.expectEqual(@as(usize, 1), opener.closed);
}

test "Processor.close gives a late acknowledgement a fresh retry deadline" {
    const allocator = testing.allocator;
    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    var amqp_clock = amqp.connection_driver.ManualClock{};
    var conn = try amqp.connection_driver.Driver.init(
        allocator,
        mem.transport(),
        amqp_clock.clock(),
        amqp.test_peer.driver_options,
    );
    defer conn.deinit();

    const peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &mem };
    try amqp.test_peer.scriptHandshake(peer, 512);
    try scriptProcessorAttach(peer, 0);
    var fixture = try amqp.test_peer.Fixture.init(allocator, &mem, &amqp_clock, &conn);
    defer fixture.deinit();
    var opener = AmqpTestOpener{ .session = &fixture.session };
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var random = std.Random.DefaultPrng.init(30);
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
    mem.starve = true;
    amqp_clock.auto_advance_ms = 1_000;
    try testing.expectError(error.Timeout, processor.close());
    try testing.expectEqual(@as(usize, 1), processor.ownedPartitions().len);

    try pushProcessorEvent(allocator, peer, 0, 0, 1, "late");
    try peer.push(0, .{ .detach = .{ .handle = 0, .closed = true } });
    try processor.close();
    try testing.expectEqual(@as(usize, 0), processor.ownedPartitions().len);
    try testing.expectEqual(@as(usize, 1), opener.closes);
}

test "terminal allocation failure is reopened and replayed next cycle" {
    const allocator = testing.allocator;
    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    var amqp_clock = amqp.connection_driver.ManualClock{};
    var conn = try amqp.connection_driver.Driver.init(
        allocator,
        mem.transport(),
        amqp_clock.clock(),
        amqp.test_peer.driver_options,
    );
    defer conn.deinit();

    const peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &mem };
    try amqp.test_peer.scriptHandshake(peer, 512);
    try scriptProcessorAttach(peer, 0);
    try pushProcessorEvent(allocator, peer, 0, 0, 1, "first attempt");
    try peer.push(0, .{ .detach = .{ .handle = 0, .closed = true } });
    try scriptProcessorAttach(peer, 1);
    try pushProcessorEvent(allocator, peer, 1, 1, 1, "replayed");
    try peer.push(0, .{ .detach = .{ .handle = 1, .closed = true } });

    var fixture = try amqp.test_peer.Fixture.init(allocator, &mem, &amqp_clock, &conn);
    defer fixture.deinit();
    var opener = AmqpTestOpener{ .session = &fixture.session };

    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var random = std.Random.DefaultPrng.init(31);
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
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    first.client.allocator = failing.allocator();
    try testing.expectError(error.OutOfMemory, first.receiveEvents(allocator, 1));
    try testing.expect(first.recoverable_failure);
    try testing.expect(!first.ownership_lost);

    try processor.runOnce();
    try testing.expectEqual(@as(usize, 2), opener.opens);
    try testing.expectEqual(@as(usize, 1), opener.closes);
    try testing.expectEqualStrings(opener.filterAt(0), opener.filterAt(1));

    const replacement = processor.nextPartitionClient().?;
    const replayed = try replacement.receiveEvents(allocator, 1);
    defer event_data.freeReceivedEvents(allocator, replayed);
    try testing.expectEqual(@as(usize, 1), replayed.len);
    try testing.expectEqual(@as(i64, 1), replayed[0].sequence_number);
    try testing.expectEqualStrings("replayed", replayed[0].body());

    try processor.close();
}

test "remote detach after a short batch is replaced next cycle" {
    const allocator = testing.allocator;
    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    var amqp_clock = amqp.connection_driver.ManualClock{};
    var conn = try amqp.connection_driver.Driver.init(
        allocator,
        mem.transport(),
        amqp_clock.clock(),
        amqp.test_peer.driver_options,
    );
    defer conn.deinit();

    const peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &mem };
    try amqp.test_peer.scriptHandshake(peer, 512);
    try scriptProcessorAttach(peer, 0);
    try pushProcessorEvent(allocator, peer, 0, 0, 1, "before detach");
    try peer.push(0, .{ .detach = .{
        .handle = 0,
        .closed = true,
        .err = .{
            .condition = errors.condition.detach_forced,
            .description = "move",
        },
    } });
    try scriptProcessorAttach(peer, 1);
    try pushProcessorEvent(allocator, peer, 1, 1, 2, "replacement");
    try peer.push(0, .{ .detach = .{ .handle = 1, .closed = true } });

    var fixture = try amqp.test_peer.Fixture.init(allocator, &mem, &amqp_clock, &conn);
    defer fixture.deinit();
    var opener = AmqpTestOpener{ .session = &fixture.session };
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var random = std.Random.DefaultPrng.init(41);
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
    const short = try first.receiveEvents(allocator, 2);
    defer event_data.freeReceivedEvents(allocator, short);
    try testing.expectEqual(@as(usize, 1), short.len);
    try testing.expect(first.recoverable_failure);
    try testing.expect(!first.ownership_lost);

    try processor.runOnce();
    try testing.expectEqual(@as(usize, 2), opener.opens);
    const replacement = processor.nextPartitionClient().?;
    const events = try replacement.receiveEvents(allocator, 1);
    defer event_data.freeReceivedEvents(allocator, events);
    try testing.expectEqual(@as(i64, 2), events[0].sequence_number);
    try testing.expectEqualStrings("replacement", events[0].body());

    try processor.close();
}

test "manual credit observes a detach pumped before receive and replaces the link" {
    const allocator = testing.allocator;
    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    var amqp_clock = amqp.connection_driver.ManualClock{};
    var conn = try amqp.connection_driver.Driver.init(
        allocator,
        mem.transport(),
        amqp_clock.clock(),
        amqp.test_peer.driver_options,
    );
    defer conn.deinit();

    const peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &mem };
    try amqp.test_peer.scriptHandshake(peer, 512);
    try scriptProcessorAttach(peer, 0);
    try peer.push(0, .{ .detach = .{
        .handle = 0,
        .closed = true,
        .err = .{
            .condition = errors.condition.detach_forced,
            .description = "move",
        },
    } });
    try scriptProcessorAttach(peer, 1);
    try pushProcessorEvent(allocator, peer, 1, 0, 1, "replacement");
    try peer.push(0, .{ .detach = .{ .handle = 1, .closed = true } });

    var fixture = try amqp.test_peer.Fixture.init(allocator, &mem, &amqp_clock, &conn);
    defer fixture.deinit();
    var opener = AmqpTestOpener{ .session = &fixture.session };
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var random = std.Random.DefaultPrng.init(42);
    var processor = Processor.init(
        allocator,
        &store.store,
        &opener.opener,
        test_details,
        .{ .load_balancing_strategy = .greedy, .prefetch = -1 },
        &clock.clock,
        random.random(),
    );
    defer processor.deinit();

    try processor.runOnce();
    const first = processor.nextPartitionClient().?;

    // Another user of the shared session can observe this detach before the
    // partition asks for manual credit. The Flow call itself must classify
    // the dead link so the processor does not retain it forever.
    _ = try fixture.session.pump(receiving.deadlineAfter(&fixture.session, 10_000));
    try testing.expectError(error.LinkDetached, first.receiveEvents(allocator, 1));
    try testing.expect(first.recoverable_failure);
    try testing.expect(!first.ownership_lost);

    try processor.runOnce();
    try testing.expectEqual(@as(usize, 2), opener.opens);
    const replacement = processor.nextPartitionClient().?;
    const events = try replacement.receiveEvents(allocator, 1);
    defer event_data.freeReceivedEvents(allocator, events);
    try testing.expectEqualStrings("replacement", events[0].body());

    try processor.close();
}

test "generation recovery invalidates stale receive and close pointers" {
    const allocator = testing.allocator;
    var first_mem = amqp.MemoryTransport.init(allocator);
    defer first_mem.deinit();
    var first_clock = amqp.connection_driver.ManualClock{};
    var first_conn = try amqp.connection_driver.Driver.init(
        allocator,
        first_mem.transport(),
        first_clock.clock(),
        amqp.test_peer.driver_options,
    );
    defer first_conn.deinit();
    const first_peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &first_mem };
    try amqp.test_peer.scriptHandshake(first_peer, 512);
    try scriptProcessorAttach(first_peer, 0);
    var first_fixture = try amqp.test_peer.Fixture.init(
        allocator,
        &first_mem,
        &first_clock,
        &first_conn,
    );

    var next_mem = amqp.MemoryTransport.init(allocator);
    defer next_mem.deinit();
    var next_clock = amqp.connection_driver.ManualClock{};
    var next_conn = try amqp.connection_driver.Driver.init(
        allocator,
        next_mem.transport(),
        next_clock.clock(),
        amqp.test_peer.driver_options,
    );
    defer next_conn.deinit();
    const next_peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &next_mem };
    try amqp.test_peer.scriptHandshake(next_peer, 512);
    try scriptProcessorAttach(next_peer, 0);
    try pushProcessorEvent(allocator, next_peer, 0, 0, 1, "new generation");
    try next_peer.push(0, .{ .detach = .{ .handle = 0, .closed = true } });
    var next_fixture = try amqp.test_peer.Fixture.init(
        allocator,
        &next_mem,
        &next_clock,
        &next_conn,
    );
    defer next_fixture.deinit();

    var generation = TestGeneration{};
    var opener = AmqpTestOpener{
        .session = &first_fixture.session,
        .generation = &generation,
    };
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var random = std.Random.DefaultPrng.init(43);
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
    const stale = processor.nextPartitionClient().?;

    first_fixture.deinit();
    generation.current += 1;
    opener.session = &next_fixture.session;

    try testing.expectError(error.LinkDetached, stale.receiveEvents(allocator, 1));
    try testing.expect(stale.recoverable_failure);
    try testing.expect(stale.client.session == null);
    try testing.expect(stale.client.receiver == null);
    try stale.close();

    try processor.runOnce();
    const replacement = processor.nextPartitionClient().?;
    const events = try replacement.receiveEvents(allocator, 1);
    defer event_data.freeReceivedEvents(allocator, events);
    try testing.expectEqualStrings("new generation", events[0].body());

    try processor.close();
}

test "post-attach allocation failures close and reopen the same link" {
    const allocator = testing.allocator;

    for (0..4) |fail_index| {
        var mem = amqp.MemoryTransport.init(allocator);
        defer mem.deinit();
        var amqp_clock = amqp.connection_driver.ManualClock{};
        var conn = try amqp.connection_driver.Driver.init(
            allocator,
            mem.transport(),
            amqp_clock.clock(),
            amqp.test_peer.driver_options,
        );
        defer conn.deinit();

        const peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &mem };
        try amqp.test_peer.scriptHandshake(peer, 512);
        try scriptProcessorAttach(peer, 0);
        try peer.push(0, .{ .detach = .{ .handle = 0, .closed = true } });
        try scriptProcessorAttach(peer, 1);
        try peer.push(0, .{ .detach = .{ .handle = 1, .closed = true } });

        var fixture = try amqp.test_peer.Fixture.init(allocator, &mem, &amqp_clock, &conn);
        defer fixture.deinit();
        var failing = PostOpenFailAllocator{
            .parent = allocator,
            .fail_index = fail_index,
        };
        var opener = AmqpTestOpener{
            .session = &fixture.session,
            .post_open_fail = &failing,
        };
        var clock = ManualClock{};
        var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
        defer store.deinit();
        var random = std.Random.DefaultPrng.init(@intCast(47 + fail_index));
        var processor = Processor.init(
            failing.allocator(),
            &store.store,
            &opener.opener,
            test_details,
            .{ .load_balancing_strategy = .greedy },
            &clock.clock,
            random.random(),
        );
        defer processor.deinit();

        try testing.expectError(error.OutOfMemory, processor.runOnce());
        try testing.expect(failing.failed);
        try testing.expectEqual(@as(usize, 1), opener.aborts);
        try testing.expectEqual(@as(usize, 0), fixture.session.receivers.items.len);
        try testing.expectEqual(@as(usize, 0), processor.ownedPartitions().len);

        try processor.runOnce();
        try testing.expectEqual(@as(usize, 2), opener.opens);
        try testing.expectEqual(@as(usize, 1), fixture.session.receivers.items.len);
        try processor.close();
    }
}

test "Processor.deinit after session termination never reads freed receivers" {
    const allocator = testing.allocator;
    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    var amqp_clock = amqp.connection_driver.ManualClock{};
    var conn = try amqp.connection_driver.Driver.init(
        allocator,
        mem.transport(),
        amqp_clock.clock(),
        amqp.test_peer.driver_options,
    );
    defer conn.deinit();

    const peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &mem };
    try amqp.test_peer.scriptHandshake(peer, 512);
    try scriptProcessorAttach(peer, 0);

    var fixture = try amqp.test_peer.Fixture.init(allocator, &mem, &amqp_clock, &conn);
    var opener = AmqpTestOpener{ .session = &fixture.session };
    var clock = ManualClock{};
    var store = InMemoryCheckpointStore{ .allocator = allocator, .clock = &clock.clock };
    defer store.deinit();
    var random = std.Random.DefaultPrng.init(37);
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
    try testing.expectEqual(@as(usize, 1), fixture.session.receivers.items.len);

    fixture.deinit();
    processor.deinit();
    try testing.expect(processor.deinitialized);
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
    try processor.close();
    processor.deinit();

    try testing.expectEqual(@as(usize, 2), opener.closed);
    for (store.ownerships.items) |ownership| {
        try testing.expect(ownership.isRelinquished());
    }
}
