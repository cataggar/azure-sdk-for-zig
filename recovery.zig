//! Link and connection recovery.
//!
//! Event Hubs detaches links routinely, during service upgrades and partition
//! moves, so a client that treats a detach as terminal dies on the first
//! ordinary fault. Go recovers through a `LinkRetrier` that classifies the
//! failure and rebuilds only what the classification demands
//! (`internal/links_recover.go`); Rust does the same with reconnect scopes
//! (`common/recoverable/connection.rs`). This is that machinery.

const std = @import("std");
const amqp = @import("azure_sdk_amqp");
const errors = @import("errors.zig");
const sending = @import("sender.zig");
const receiving = @import("receiver.zig");

const Allocator = std.mem.Allocator;
const SenderPool = sending.SenderPool;
const ReceiverPool = receiving.ReceiverPool;
const PartitionClientOptions = receiving.PartitionClientOptions;

/// The AMQP plumbing one connection generation owns.
///
/// `context` is opaque to this file and belongs to the factory that produced
/// it, which is also the only thing that knows how to take it apart.
pub const Plumbing = struct {
    context: *anyopaque,
    session: *amqp.Session,
};

/// Builds and tears down the AMQP plumbing behind a connection.
///
/// A vtable rather than a concrete type because recovery has to be exercised
/// against a scripted peer, and because #207 will add custom endpoints and
/// WebSockets without this file needing to know.
pub const ConnectionFactory = struct {
    openFn: *const fn (self: *ConnectionFactory, timeout_ms: i64) anyerror!Plumbing,
    closeFn: *const fn (self: *ConnectionFactory, plumbing: Plumbing) void,

    pub fn open(self: *ConnectionFactory, timeout_ms: i64) !Plumbing {
        return self.openFn(self, timeout_ms);
    }

    pub fn close(self: *ConnectionFactory, plumbing: Plumbing) void {
        self.closeFn(self, plumbing);
    }
};

/// Puts a CBS token for an audience.
///
/// A rebuilt connection carries no claims, so every link must be
/// re-authorised before it reattaches or the broker refuses the attach with
/// `unauthorized-access` — which is classified fatal, turning a recoverable
/// fault into a terminal one.
pub const Authorizer = struct {
    authorizeFn: *const fn (
        self: *Authorizer,
        session: *amqp.Session,
        deadline_ms: i64,
    ) anyerror!void,

    pub fn authorize(self: *Authorizer, session: *amqp.Session, deadline_ms: i64) !void {
        return self.authorizeFn(self, session, deadline_ms);
    }
};

pub const RecoveryError = error{
    /// The connection was closed by the caller and cannot be reopened.
    ConnectionClosedPermanently,
};

/// An AMQP connection that can be rebuilt underneath its links.
///
/// `generation` is the connection identity Go calls `connID`. A caller reads
/// it before an operation and hands it back when asking for recovery; a
/// mismatch means someone else already rebuilt, so the request is a no-op.
/// That is what makes concurrent failures recover once rather than once per
/// waiter.
pub const RecoverableConnection = struct {
    allocator: Allocator,
    factory: *ConnectionFactory,
    /// Null skips re-authorisation, which is what a test peer or an emulator
    /// with authentication disabled wants.
    authorizer: ?*Authorizer,
    timeout_ms: i64,
    sender_options: SenderPool.Options,
    receiver_options: ReceiverPool.Options,

    generation: u64 = 0,
    plumbing: ?Plumbing = null,
    senders: SenderPool = undefined,
    receivers: ReceiverPool = undefined,
    /// Attached on first use and torn down with the connection that carries
    /// it, since the link cannot outlive its session.
    management: ?*amqp.Management = null,
    /// Distinguishes this client's `$management` link pair from any other on
    /// the connection.
    management_link_id: []const u8 = "eventhubs",
    closed: bool = false,
    /// The pools outlive any one generation, because a receiver's position
    /// has to survive the rebuild that lost its link.
    pools_ready: bool = false,
    /// Counts completed rebuilds, so a test can prove a stale request did not
    /// cause a second one.
    recoveries: u64 = 0,
    link_recoveries: u64 = 0,
    /// Counts CBS authorisations, so a test can prove a rebuild re-authorised
    /// before reattaching.
    authorizations: u64 = 0,
    /// A copy of the most recent failure's condition and description.
    ///
    /// The originals belong to the link that failed, which recovery is about
    /// to free; the retrier reads them after the attempt returns, and the
    /// outcome hands them to the caller after that. Only the connection
    /// outlives both, so the copy lives here.
    condition_buf: [128]u8 = undefined,
    condition_len: usize = 0,
    description_buf: [512]u8 = undefined,
    description_len: usize = 0,

    pub const Options = struct {
        factory: *ConnectionFactory,
        authorizer: ?*Authorizer = null,
        /// Per-operation timeout duration in milliseconds. The legacy field
        /// name is retained for source compatibility.
        deadline_ms: i64,
        /// Identifies this reader to the broker on receiver links.
        instance_id: []const u8 = "eventhubs",
        /// Distinguishes this client's sender links from any others.
        link_id: []const u8 = "eventhubs",
        /// How many batches a sender link may have on the wire unconfirmed.
        /// Only `sendBatches` overlaps them; `sendBatch` waits either way.
        max_in_flight: u32 = sending.default_max_in_flight,
        partition_client: PartitionClientOptions = .{},
    };

    pub fn init(allocator: Allocator, options: Options) RecoverableConnection {
        return .{
            .allocator = allocator,
            .factory = options.factory,
            .authorizer = options.authorizer,
            .timeout_ms = options.deadline_ms,
            .sender_options = .{
                .deadline_ms = options.deadline_ms,
                .link_id = options.link_id,
                .max_in_flight = options.max_in_flight,
            },
            .receiver_options = .{
                .instance_id = options.instance_id,
                .deadline_ms = options.deadline_ms,
                .client = options.partition_client,
            },
        };
    }

    pub fn deinit(self: *RecoverableConnection) void {
        self.teardown();
        if (self.pools_ready) {
            self.senders.deinit();
            self.receivers.deinit();
            self.pools_ready = false;
        }
        self.closed = true;
    }

    /// Open the connection if it is not already open.
    ///
    /// Returns the generation the caller is now working against; pass it back
    /// to `recoverConnection` if the operation fails.
    pub fn ensureOpen(self: *RecoverableConnection) !u64 {
        if (self.closed) return RecoveryError.ConnectionClosedPermanently;
        if (self.plumbing != null) return self.generation;

        const plumbing = try self.factory.open(self.timeout_ms);
        errdefer self.factory.close(plumbing);

        // Before the pools, not after: a link that attaches without a claim is
        // refused with a condition classified fatal, so the recovery would
        // report as unrecoverable.
        if (self.authorizer) |authorizer| {
            try authorizer.authorize(
                plumbing.session,
                receiving.deadlineAfter(plumbing.session, self.timeout_ms),
            );
            self.authorizations += 1;
        }

        self.plumbing = plumbing;
        if (self.pools_ready) {
            // Rebound, not rebuilt: a fresh `ReceiverPool` would drop the
            // remembered positions and every reattached client would replay
            // from the configured start position.
            self.senders.rebind(plumbing.session);
            self.receivers.rebind(plumbing.session);
        } else {
            self.senders = SenderPool.init(self.allocator, plumbing.session, self.sender_options);
            self.receivers = ReceiverPool.init(self.allocator, plumbing.session, self.receiver_options);
            self.pools_ready = true;
        }
        return self.generation;
    }

    pub fn session(self: *RecoverableConnection) !*amqp.Session {
        _ = try self.ensureOpen();
        return self.plumbing.?.session;
    }

    /// Whether a wrapper still belongs to the live native session.
    pub fn isGenerationCurrent(self: *const RecoverableConnection, generation: u64) bool {
        return !self.closed and self.plumbing != null and self.generation == generation;
    }

    /// The `$management` client, attached on first use.
    ///
    /// Lazily, as Go does: a producer that only ever sends never needs the
    /// link, and attaching one on every connection would cost a round trip
    /// per recovery for nothing.
    pub fn managementClient(self: *RecoverableConnection) !*amqp.Management {
        _ = try self.ensureOpen();
        if (self.management) |client| return client;
        const client = try amqp.Management.open(
            self.plumbing.?.session,
            .{ .link_id = self.management_link_id },
            receiving.deadlineAfter(self.plumbing.?.session, self.timeout_ms),
        );
        self.management = client;
        return client;
    }

    pub fn senderPool(self: *RecoverableConnection) !*SenderPool {
        _ = try self.ensureOpen();
        return &self.senders;
    }

    pub fn receiverPool(self: *RecoverableConnection) !*ReceiverPool {
        _ = try self.ensureOpen();
        return &self.receivers;
    }

    /// Detach the links for `address` so the next use reattaches them.
    ///
    /// Both pools are asked because the address alone does not say which side
    /// failed, and dropping a link that was never attached is free.
    pub fn recoverLink(self: *RecoverableConnection, address: []const u8) void {
        if (self.plumbing == null) return;
        self.senders.drop(address, true);
        self.receivers.drop(address, true);
        self.link_recoveries += 1;
    }

    /// Rebuild the connection, unless someone already did.
    ///
    /// `their_generation` is what the caller read from `ensureOpen`. If the
    /// current generation has moved past it, the connection the caller failed
    /// on no longer exists and rebuilding again would throw away a healthy
    /// one — Go makes exactly this check in `Namespace.Recover`.
    pub fn recoverConnection(self: *RecoverableConnection, their_generation: u64) !void {
        if (self.closed) return RecoveryError.ConnectionClosedPermanently;
        if (their_generation != self.generation) return;

        self.invalidateGeneration(their_generation);

        _ = try self.ensureOpen();
    }

    /// Destroy one native generation without opening its replacement.
    ///
    /// Used when cleanup after an attached-but-untracked link cannot confirm a
    /// detach. The next operation lazily opens a new generation.
    pub fn invalidateGeneration(self: *RecoverableConnection, their_generation: u64) void {
        if (self.closed or their_generation != self.generation) return;
        self.teardown();
        self.generation += 1;
        self.recoveries += 1;
    }

    /// Whether the connection currently has plumbing behind it.
    pub fn isOpen(self: *const RecoverableConnection) bool {
        return self.plumbing != null;
    }

    /// Copy the failure out of the link that produced it and repoint
    /// `attempt` at the copy.
    ///
    /// Without this, recovering the link frees the strings the retrier is
    /// about to classify, and the outcome the caller inspects points at freed
    /// memory. Truncation is fine: these are diagnostics, and an AMQP
    /// condition is a short symbol.
    pub fn captureFailure(self: *RecoverableConnection, attempt: *errors.Attempt) void {
        self.condition_len = copyInto(&self.condition_buf, attempt.condition);
        self.description_len = copyInto(&self.description_buf, attempt.description);
        attempt.condition = if (attempt.condition != null) self.condition_buf[0..self.condition_len] else null;
        attempt.description = if (attempt.description != null) self.description_buf[0..self.description_len] else null;
    }

    fn teardown(self: *RecoverableConnection) void {
        const plumbing = self.plumbing orelse return;
        if (self.management) |client| {
            client.deinit();
            self.management = null;
        }
        if (self.pools_ready) {
            // Forgotten rather than detached: the links belong to a session
            // that is about to stop existing, so a detach would be written
            // into a connection that is already gone.
            self.senders.dropAll(false);
            self.receivers.dropAll(false);
        }
        self.plumbing = null;
        self.factory.close(plumbing);
    }
};

/// Run an operation, recovering whatever its failures say is broken.
///
/// `op` is a pointer to a struct with a
/// `pub fn call(self: @TypeOf(op), attempt: *errors.Attempt) anyerror!Result`
/// method, the same shape `errors.retry` takes. It should set
/// `attempt.condition` when the broker named one, since that is what decides
/// whether a link, the connection, or nothing gets rebuilt.
///
/// `address` names the link the operation uses, so a link-level failure can be
/// narrowed to it. Null recovers nothing at link level, which is what a
/// connection-wide operation wants.
pub fn runWithRecovery(
    comptime Result: type,
    connection: *RecoverableConnection,
    address: ?[]const u8,
    op: anytype,
    config: errors.RetryConfig,
) errors.Outcome(Result) {
    var runner = Runner(Result, @TypeOf(op)){
        .connection = connection,
        .address = address,
        .op = op,
    };
    return errors.retry(Result, &runner, config);
}

fn copyInto(buffer: []u8, value: ?[]const u8) usize {
    const bytes = value orelse return 0;
    const n = @min(bytes.len, buffer.len);
    @memcpy(buffer[0..n], bytes[0..n]);
    return n;
}

fn Runner(comptime Result: type, comptime Op: type) type {
    return struct {
        connection: *RecoverableConnection,
        address: ?[]const u8,
        op: Op,
        /// Go does one immediate retry for an asynchronous detach before
        /// backing off, because the error may describe a link that has already
        /// been replaced. Once only, or a link that keeps failing never backs
        /// off at all.
        did_quick_retry: bool = false,

        pub fn call(self: *@This(), attempt: *errors.Attempt) anyerror!Result {
            const generation = try self.connection.ensureOpen();

            const result = self.op.call(attempt) catch |err| {
                // Before anything is torn down: the condition belongs to the
                // link that failed.
                self.connection.captureFailure(attempt);

                const kind = if (attempt.condition) |c|
                    errors.recoveryKindForCondition(c)
                else
                    // An error with no condition left the connection in an
                    // unknown state, which is Go's fallthrough too.
                    .connection;

                // Never for a fatal failure: `amqp:link:stolen` means another
                // consumer legitimately owns the partition, and reattaching
                // would steal it straight back.
                if (kind == .fatal) return err;

                if (attempt.index == 0 and !self.did_quick_retry and kind == .link) {
                    self.did_quick_retry = true;
                    attempt.resetAttempts();
                }

                switch (kind) {
                    .none => {},
                    .link => if (self.address) |address| self.connection.recoverLink(address),
                    .connection => {
                        // Drop this operation's link too. Go does the same:
                        // the link cannot outlive the connection it was
                        // attached to.
                        if (self.address) |address| self.connection.recoverLink(address);
                        try self.connection.recoverConnection(generation);
                    },
                    .fatal => unreachable,
                }

                // The original error, not the recovery's success: returning
                // null here would end the retry loop as though the operation
                // had worked.
                return err;
            };
            return result;
        }
    };
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const harness = amqp.test_peer;
const driver = amqp.connection_driver;
const Peer = harness.Peer;
const MemoryTransport = amqp.MemoryTransport;
const event_data = @import("event_data.zig");
const batching = @import("batch.zig");

/// One connection generation: its own transport, driver, and session.
///
/// Heap-allocated because the session holds a pointer to the driver and the
/// links hold pointers to the session, so moving any of it invalidates the
/// rest.
const Generation = struct {
    allocator: Allocator,
    mem: *MemoryTransport,
    clock: *driver.ManualClock,
    conn: *driver.Driver,
    session: *amqp.Session,

    fn deinit(self: *Generation) void {
        self.session.deinit();
        self.allocator.destroy(self.session);
        self.conn.deinit();
        self.allocator.destroy(self.conn);
        self.mem.deinit();
        self.allocator.destroy(self.mem);
        self.allocator.destroy(self.clock);
        self.allocator.destroy(self);
    }
};

/// Hands out one pre-scripted generation per open.
///
/// A connection rebuild needs a genuinely new transport, so the script for
/// each generation is written by the test before anything opens.
const ScriptedFactory = struct {
    allocator: Allocator,
    scripts: []const *const fn (Allocator, Peer) anyerror!void,
    opened: usize = 0,
    live: std.ArrayList(*Generation) = .empty,
    factory: ConnectionFactory = .{ .openFn = open, .closeFn = close },

    fn deinit(self: *ScriptedFactory) void {
        for (self.live.items) |generation| generation.deinit();
        self.live.deinit(self.allocator);
    }

    fn open(f: *ConnectionFactory, timeout_ms: i64) anyerror!Plumbing {
        const self: *ScriptedFactory = @fieldParentPtr("factory", f);
        if (self.opened >= self.scripts.len) return error.NoMoreConnections;

        const generation = try self.allocator.create(Generation);
        errdefer self.allocator.destroy(generation);

        const mem = try self.allocator.create(MemoryTransport);
        mem.* = MemoryTransport.init(self.allocator);
        const clock = try self.allocator.create(driver.ManualClock);
        clock.* = .{};

        try self.scripts[self.opened](self.allocator, .{ .allocator = self.allocator, .mem = mem });
        self.opened += 1;

        const conn = try self.allocator.create(driver.Driver);
        conn.* = try driver.Driver.init(self.allocator, mem.transport(), clock.clock(), harness.driver_options);
        const deadline_ms = conn.clock.nowMillis() +| @max(timeout_ms, 0);
        try conn.open(deadline_ms);

        const session = try self.allocator.create(amqp.Session);
        session.* = try amqp.Session.begin(self.allocator, conn, 0, .{
            .incoming_window = 100,
            .outgoing_window = 100,
        }, deadline_ms);

        generation.* = .{
            .allocator = self.allocator,
            .mem = mem,
            .clock = clock,
            .conn = conn,
            .session = session,
        };
        try self.live.append(self.allocator, generation);
        return .{
            .context = generation,
            .session = session,
        };
    }

    fn close(f: *ConnectionFactory, plumbing: Plumbing) void {
        const self: *ScriptedFactory = @fieldParentPtr("factory", f);
        const generation: *Generation = @ptrCast(@alignCast(plumbing.context));
        for (self.live.items, 0..) |item, i| {
            if (item != generation) continue;
            _ = self.live.orderedRemove(i);
            generation.deinit();
            return;
        }
    }

    /// The generation currently serving, for asserting on emitted frames.
    fn current(self: *ScriptedFactory) *Generation {
        return self.live.items[self.live.items.len - 1];
    }
};

const CountingAuthorizer = struct {
    calls: usize = 0,
    /// Set to record the ordering question that matters: a claim put after a
    /// link attaches is a claim the broker never saw.
    sessions: std.ArrayList(*amqp.Session) = .empty,
    allocator: Allocator,
    authorizer: Authorizer = .{ .authorizeFn = authorize },

    fn deinit(self: *CountingAuthorizer) void {
        self.sessions.deinit(self.allocator);
    }

    fn authorize(a: *Authorizer, session: *amqp.Session, deadline_ms: i64) anyerror!void {
        _ = deadline_ms;
        const self: *CountingAuthorizer = @fieldParentPtr("authorizer", a);
        self.calls += 1;
        try self.sessions.append(self.allocator, session);
    }
};

const test_target = "my-hub";
const test_sender_link = test_target ++ "-sender-eventhubs";

fn scriptHandshakeOnly(allocator: Allocator, peer: Peer) anyerror!void {
    _ = allocator;
    try harness.scriptHandshake(peer, 512);
}

/// Attach the sender, grant credit, then detach it with a link-level
/// condition, which is what an ordinary Event Hubs link recycle looks like.
fn scriptSenderThenDetach(allocator: Allocator, peer: Peer) anyerror!void {
    _ = allocator;
    try harness.scriptHandshake(peer, 512);
    try scriptSenderAttach(peer, 0);
    try peer.push(0, .{ .detach = .{
        .handle = 0,
        .closed = true,
        .err = .{ .condition = "amqp:link:detach-forced", .description = "recycling" },
    } });
    // The reattach after recovery, on a fresh handle, then an accepted send.
    // Delivery id 1: the session counted the first, failed delivery.
    try scriptSenderAttach(peer, 1);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 1,
        .last = 1,
        .settled = true,
        .state = .accepted,
    } });
}

/// Attach the sender, grant credit, then drop the whole connection.
fn scriptSenderThenConnectionLoss(allocator: Allocator, peer: Peer) anyerror!void {
    _ = allocator;
    try harness.scriptHandshake(peer, 512);
    try scriptSenderAttach(peer, 0);
    try peer.push(0, .{ .close = .{
        .err = .{ .condition = "amqp:connection:forced", .description = "node shutting down" },
    } });
}

/// A fresh connection that attaches the sender and accepts one delivery.
fn scriptSenderThenAccept(allocator: Allocator, peer: Peer) anyerror!void {
    _ = allocator;
    try harness.scriptHandshake(peer, 512);
    try scriptSenderAttach(peer, 0);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });
}

fn scriptSenderAttach(peer: Peer, handle: u32) !void {
    try peer.push(0, .{ .attach = .{
        .name = test_sender_link,
        .handle = handle,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = handle,
        .delivery_count = 0,
        .link_credit = 10,
    } });
}

fn testRetryConfig(sleeper: *errors.Sleeper, random: std.Random) errors.RetryConfig {
    return .{
        .options = .{ .max_retries = 3, .retry_delay_ns = 0, .max_retry_delay_ns = 0 },
        .sleeper = sleeper,
        .random = random,
    };
}

fn noSleep(_: *errors.Sleeper, _: u64) errors.SleepError!void {}

fn oneEventBatch(allocator: Allocator) !batching.EventDataBatch {
    var batch = try batching.EventDataBatch.init(.{});
    errdefer batch.deinit(allocator);
    var event = event_data.EventData.init("hello");
    defer event.deinit(allocator);
    _ = try batch.tryAdd(allocator, event);
    return batch;
}

test "a detached link is reattached and the send succeeds" {
    const allocator = testing.allocator;
    var factory = ScriptedFactory{
        .allocator = allocator,
        .scripts = &.{&scriptSenderThenDetach},
    };
    defer factory.deinit();

    var connection = RecoverableConnection.init(allocator, .{
        .factory = &factory.factory,
        .deadline_ms = 10_000,
    });
    defer connection.deinit();

    var sleeper = errors.Sleeper{ .sleepFn = noSleep };
    var prng = std.Random.DefaultPrng.init(0);

    var batch = try oneEventBatch(allocator);
    defer batch.deinit(allocator);

    const Op = struct {
        connection: *RecoverableConnection,
        allocator: Allocator,
        batch: batching.EventDataBatch,

        pub fn call(op: *const @This(), attempt: *errors.Attempt) anyerror!void {
            const pool = try op.connection.senderPool();
            return pool.send(op.allocator, test_target, op.batch) catch |err| {
                pool.recordFailure(test_target, attempt);
                return err;
            };
        }
    };
    var op = Op{ .connection = &connection, .allocator = allocator, .batch = batch };

    const outcome = runWithRecovery(
        void,
        &connection,
        test_target,
        &op,
        testRetryConfig(&sleeper, prng.random()),
    );
    try testing.expect(outcome == .ok);

    // A link-level failure must not cost the connection.
    try testing.expectEqual(@as(u64, 1), connection.link_recoveries);
    try testing.expectEqual(@as(u64, 0), connection.recoveries);
    try testing.expectEqual(@as(u64, 0), connection.generation);
}

test "a connection failure rebuilds and re-authorises before reattaching" {
    const allocator = testing.allocator;
    var factory = ScriptedFactory{
        .allocator = allocator,
        .scripts = &.{ &scriptSenderThenConnectionLoss, &scriptSenderThenAccept },
    };
    defer factory.deinit();

    var authorizer = CountingAuthorizer{ .allocator = allocator };
    defer authorizer.deinit();

    var connection = RecoverableConnection.init(allocator, .{
        .factory = &factory.factory,
        .authorizer = &authorizer.authorizer,
        .deadline_ms = 10_000,
    });
    defer connection.deinit();

    var sleeper = errors.Sleeper{ .sleepFn = noSleep };
    var prng = std.Random.DefaultPrng.init(0);

    var batch = try oneEventBatch(allocator);
    defer batch.deinit(allocator);

    const Op = struct {
        connection: *RecoverableConnection,
        allocator: Allocator,
        batch: batching.EventDataBatch,

        pub fn call(op: *const @This(), attempt: *errors.Attempt) anyerror!void {
            const pool = try op.connection.senderPool();
            return pool.send(op.allocator, test_target, op.batch) catch |err| {
                pool.recordFailure(test_target, attempt);
                return err;
            };
        }
    };
    var op = Op{ .connection = &connection, .allocator = allocator, .batch = batch };

    const outcome = runWithRecovery(
        void,
        &connection,
        test_target,
        &op,
        testRetryConfig(&sleeper, prng.random()),
    );
    try testing.expect(outcome == .ok);

    try testing.expectEqual(@as(u64, 1), connection.recoveries);
    try testing.expectEqual(@as(u64, 1), connection.generation);

    // Twice: once per connection. A rebuilt connection carries no claims, so
    // a link attaching on it without one is refused as unauthorized-access,
    // which is fatal and would end the retry.
    try testing.expectEqual(@as(usize, 2), authorizer.calls);
    try testing.expectEqual(@as(usize, 2), authorizer.sessions.items.len);
    // The claim has to land on the session the links will actually attach on.
    // Comparing the two recorded pointers would not show that: the first
    // session is freed before the second is allocated, so the allocator is
    // free to hand back the same address, and on Windows it does.
    try testing.expectEqual(try connection.session(), authorizer.sessions.items[1]);
}

test "a stale recovery request does not rebuild a second time" {
    const allocator = testing.allocator;
    var factory = ScriptedFactory{
        .allocator = allocator,
        .scripts = &.{ &scriptHandshakeOnly, &scriptHandshakeOnly },
    };
    defer factory.deinit();

    var connection = RecoverableConnection.init(allocator, .{
        .factory = &factory.factory,
        .deadline_ms = 10_000,
    });
    defer connection.deinit();

    // Two callers read the same generation before either fails.
    const first = try connection.ensureOpen();
    const second = try connection.ensureOpen();
    try testing.expectEqual(first, second);

    try connection.recoverConnection(first);
    try testing.expectEqual(@as(u64, 1), connection.recoveries);

    // The second caller's connection no longer exists. Rebuilding again would
    // throw away the healthy one the first caller just made — and there is no
    // third script, so a second rebuild fails outright.
    try connection.recoverConnection(second);
    try testing.expectEqual(@as(u64, 1), connection.recoveries);
    try testing.expectEqual(@as(u64, 1), connection.generation);
}

test "a closed connection refuses to reopen" {
    const allocator = testing.allocator;
    var factory = ScriptedFactory{
        .allocator = allocator,
        .scripts = &.{&scriptHandshakeOnly},
    };
    defer factory.deinit();

    var connection = RecoverableConnection.init(allocator, .{
        .factory = &factory.factory,
        .deadline_ms = 10_000,
    });
    _ = try connection.ensureOpen();
    connection.deinit();

    try testing.expectError(RecoveryError.ConnectionClosedPermanently, connection.ensureOpen());
    try testing.expectError(RecoveryError.ConnectionClosedPermanently, connection.recoverConnection(0));
}

const test_source = "my-hub/ConsumerGroups/$default/Partitions/0";
const test_receiver_link = test_source ++ "-receiver-eventhubs";

fn scriptReceiverAttach(peer: Peer, handle: u32) !void {
    try peer.push(0, .{ .attach = .{
        .name = test_receiver_link,
        .handle = handle,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
}

fn scriptReceiverOnly(_: Allocator, peer: Peer) anyerror!void {
    try harness.scriptHandshake(peer, 512);
    try scriptReceiverAttach(peer, 0);
}

fn scriptReceiverOneEvent(allocator: Allocator, peer: Peer) anyerror!void {
    try scriptReceiverOnly(allocator, peer);
    try pushEvent(allocator, peer, 0, 0, 50, "before recovery");
}

fn pushEvent(allocator: Allocator, peer: Peer, handle: u32, id: u32, sequence_number: i64, body: []const u8) !void {
    var annotations = [_]amqp.MapEntry{.{
        .key = .{ .symbol = event_data.sequence_number_annotation },
        .value = .{ .long = sequence_number },
    }};
    const bodies = [_][]const u8{body};
    const payload = try amqp.encodeMessageAlloc(allocator, .{
        .message_annotations = &annotations,
        .body = .{ .data = &bodies },
    });
    defer allocator.free(payload);

    const tag = [_]u8{@intCast(id)};
    try peer.pushTransfer(0, .{
        .handle = handle,
        .delivery_id = id,
        .delivery_tag = &tag,
        .message_format = 0,
        .settled = true,
        .more = false,
    }, payload);
}

/// One event, then the link is taken by another consumer.
fn scriptReceiverThenStolen(allocator: Allocator, peer: Peer) anyerror!void {
    try harness.scriptHandshake(peer, 512);
    try scriptReceiverAttach(peer, 0);
    try pushEvent(allocator, peer, 0, 0, 30, "before");
    try peer.push(0, .{ .detach = .{
        .handle = 0,
        .closed = true,
        .err = .{ .condition = "amqp:link:stolen", .description = "another receiver attached" },
    } });
}

/// One event, an ordinary link recycle, then the reattach delivers more.
fn scriptReceiverThenDetach(allocator: Allocator, peer: Peer) anyerror!void {
    try harness.scriptHandshake(peer, 512);
    try scriptReceiverAttach(peer, 0);
    try pushEvent(allocator, peer, 0, 0, 40, "first");
    try peer.push(0, .{ .detach = .{
        .handle = 0,
        .closed = true,
        .err = .{ .condition = "amqp:link:detach-forced", .description = "recycling" },
    } });
    try scriptReceiverAttach(peer, 1);
    try pushEvent(allocator, peer, 1, 1, 41, "second");
    try pushEvent(allocator, peer, 1, 2, 42, "third");
}

const ReceiveOp = struct {
    connection: *RecoverableConnection,
    allocator: Allocator,
    count: u32,

    pub fn call(op: *const @This(), attempt: *errors.Attempt) anyerror![]event_data.ReceivedEventData {
        const pool = try op.connection.receiverPool();
        return pool.receive(op.allocator, test_source, null, op.count) catch |err| {
            pool.recordFailure(test_source, attempt);
            return err;
        };
    }
};

/// Every selector expression the client attached with, in order.
fn attachedFilters(allocator: Allocator, mem: *MemoryTransport) ![][]const u8 {
    var frames = try harness.EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();

    var out: std.ArrayList([]const u8) = .empty;
    errdefer out.deinit(allocator);
    for (frames.bodies.items) |body| {
        if (amqp.performative.peekDescriptor(body) != amqp.performative.descriptor.attach) continue;
        var decoded = try amqp.performative.decode(allocator, body);
        defer decoded.deinit();
        const source = decoded.performative.attach.source orelse continue;
        const filters = source.filters orelse continue;
        if (filters.len == 0) continue;
        try out.append(allocator, try allocator.dupe(u8, filters[0].value.string));
    }
    return out.toOwnedSlice(allocator);
}

fn freeFilters(allocator: Allocator, filters: [][]const u8) void {
    for (filters) |f| allocator.free(f);
    allocator.free(filters);
}

test "a stolen receiver link surfaces ownership lost and is not reattached" {
    const allocator = testing.allocator;
    var factory = ScriptedFactory{
        .allocator = allocator,
        .scripts = &.{&scriptReceiverThenStolen},
    };
    defer factory.deinit();

    var connection = RecoverableConnection.init(allocator, .{
        .factory = &factory.factory,
        .deadline_ms = 10_000,
    });
    defer connection.deinit();

    var sleeper = errors.Sleeper{ .sleepFn = noSleep };
    var prng = std.Random.DefaultPrng.init(0);

    var op = ReceiveOp{ .connection = &connection, .allocator = allocator, .count = 2 };
    const config = testRetryConfig(&sleeper, prng.random());

    const first = runWithRecovery([]event_data.ReceivedEventData, &connection, test_source, &op, config);
    try testing.expect(first == .ok);
    event_data.freeReceivedEvents(allocator, first.ok);

    const second = runWithRecovery([]event_data.ReceivedEventData, &connection, test_source, &op, config);
    try testing.expect(second == .failed);
    // The partition belongs to someone else now. Reattaching would steal it
    // straight back, and the displaced consumer would never learn to stop.
    try testing.expectEqual(errors.ErrorCode.ownership_lost, second.failed.info.code);
    try testing.expectEqualStrings("amqp:link:stolen", second.failed.info.amqp_condition.?);
    try testing.expectEqual(@as(u32, 1), second.failed.attempts);
    try testing.expectEqual(@as(u64, 0), connection.link_recoveries);
    try testing.expectEqual(@as(u64, 0), connection.recoveries);

    const filters = try attachedFilters(allocator, factory.current().mem);
    defer freeFilters(allocator, filters);
    try testing.expectEqual(@as(usize, 1), filters.len);
}

test "a reattached receiver resumes from the last sequence number" {
    const allocator = testing.allocator;
    var factory = ScriptedFactory{
        .allocator = allocator,
        .scripts = &.{&scriptReceiverThenDetach},
    };
    defer factory.deinit();

    var connection = RecoverableConnection.init(allocator, .{
        .factory = &factory.factory,
        .deadline_ms = 10_000,
    });
    defer connection.deinit();

    var sleeper = errors.Sleeper{ .sleepFn = noSleep };
    var prng = std.Random.DefaultPrng.init(0);

    var op = ReceiveOp{ .connection = &connection, .allocator = allocator, .count = 2 };
    const config = testRetryConfig(&sleeper, prng.random());

    // The link dies halfway through the batch. The one event that did arrive
    // is still handed back rather than dropped on the floor.
    const first = runWithRecovery([]event_data.ReceivedEventData, &connection, test_source, &op, config);
    try testing.expect(first == .ok);
    defer event_data.freeReceivedEvents(allocator, first.ok);
    try testing.expectEqual(@as(usize, 1), first.ok.len);
    try testing.expectEqualStrings("first", first.ok[0].body());

    const second = runWithRecovery([]event_data.ReceivedEventData, &connection, test_source, &op, config);
    try testing.expect(second == .ok);
    defer event_data.freeReceivedEvents(allocator, second.ok);
    try testing.expectEqual(@as(usize, 2), second.ok.len);
    try testing.expectEqualStrings("second", second.ok[0].body());
    try testing.expectEqualStrings("third", second.ok[1].body());
    // A link-level fault: the connection itself was never rebuilt.
    try testing.expectEqual(@as(u64, 1), connection.link_recoveries);
    try testing.expectEqual(@as(u64, 0), connection.recoveries);

    const filters = try attachedFilters(allocator, factory.current().mem);
    defer freeFilters(allocator, filters);
    try testing.expectEqual(@as(usize, 2), filters.len);
    try testing.expectEqualStrings("amqp.annotation.x-opt-offset > '@latest'", filters[0]);
    // Reattaching with the original filter would replay event 40, which the
    // caller has already been given.
    try testing.expectEqualStrings("amqp.annotation.x-opt-sequence-number > '40'", filters[1]);
}

test "connection invalidation drops receiver wrappers without allocation" {
    const allocator = testing.allocator;
    var factory = ScriptedFactory{
        .allocator = allocator,
        .scripts = &.{ &scriptReceiverOneEvent, &scriptReceiverOnly },
    };
    defer factory.deinit();

    var connection = RecoverableConnection.init(allocator, .{
        .factory = &factory.factory,
        .deadline_ms = 10_000,
    });
    defer connection.deinit();

    const generation = try connection.ensureOpen();
    const first_pool = try connection.receiverPool();
    const first = try first_pool.receive(allocator, test_source, null, 1);
    defer event_data.freeReceivedEvents(allocator, first);
    try testing.expectEqual(@as(i64, 50), first[0].sequence_number);
    try testing.expectEqual(@as(usize, 1), first_pool.clients.count());

    var failing = testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    connection.receivers.allocator = failing.allocator();
    connection.invalidateGeneration(generation);
    try testing.expectEqual(@as(usize, 0), connection.receivers.clients.count());

    connection.receivers.allocator = allocator;
    _ = try connection.ensureOpen();
    const rebound = try connection.receiverPool();
    try testing.expect(rebound.session == factory.current().session);
    _ = try rebound.clientFor(test_source, null);
    try testing.expectEqual(@as(usize, 1), rebound.clients.count());

    const filters = try attachedFilters(allocator, factory.current().mem);
    defer freeFilters(allocator, filters);
    try testing.expectEqual(@as(usize, 1), filters.len);
    try testing.expectEqualStrings("amqp.annotation.x-opt-sequence-number > '50'", filters[0]);
}

test "the client's window reaches the sender links it is meant to size" {
    // Without this the whole pipelining path is inert: the pool defaults its
    // window from its own options, so an option that stops anywhere along the
    // chain leaves every real client sending one batch per round trip while
    // the documentation promises otherwise.
    const allocator = std.testing.allocator;

    var factory: ConnectionFactory = undefined;
    var connection = RecoverableConnection.init(allocator, .{
        .factory = &factory,
        .deadline_ms = 1_000,
        .max_in_flight = 5,
    });
    defer connection.deinit();

    try std.testing.expectEqual(@as(u32, 5), connection.sender_options.max_in_flight);

    // And the default is a window worth having, not one.
    var defaulted = RecoverableConnection.init(allocator, .{
        .factory = &factory,
        .deadline_ms = 1_000,
    });
    defer defaulted.deinit();
    try std.testing.expectEqual(
        sending.default_max_in_flight,
        defaulted.sender_options.max_in_flight,
    );
    try std.testing.expect(sending.default_max_in_flight > 1);
}
