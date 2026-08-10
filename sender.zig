//! Publishing Event Hubs batches over AMQP sender links.
//!
//! A batch goes out as a single transfer whose `message-format` is
//! `batch_message_format`. The body is the first event's non-body sections
//! reused as an envelope, followed by one data section per event, each holding
//! a fully encoded AMQP message. Go (`event_data_batch.go`) and Rust
//! (`producer/batch.rs`) both produce exactly this shape.

const std = @import("std");
const amqp = @import("azure_sdk_amqp");
const event_data = @import("event_data.zig");
const errors = @import("errors.zig");
const batch_mod = @import("batch.zig");

const Allocator = std.mem.Allocator;
const EventDataBatch = batch_mod.EventDataBatch;
const batch_message_format = batch_mod.batch_message_format;

pub const SendError = error{
    /// There is nothing to send. Go and Rust both refuse rather than putting
    /// an empty transfer on the wire.
    EmptyBatch,
};

/// The entity a sender link attaches to: the hub itself, so the service picks
/// a partition, or one explicit partition. Caller owns the result.
pub fn entityPathFor(
    allocator: Allocator,
    event_hub_name: []const u8,
    partition_id: ?[]const u8,
) ![]u8 {
    const id = partition_id orelse return allocator.dupe(u8, event_hub_name);
    return std.fmt.allocPrint(allocator, "{s}/Partitions/{s}", .{ event_hub_name, id });
}

/// Longest entity path Azure can name: a 256-character hub, the separator, and
/// a partition id with room to spare. `entity_path_buffer_len` sizes a stack
/// buffer that never has to grow for a real hub.
pub const entity_path_buffer_len = 320;

/// `entityPathFor` without the allocation, for callers that only need the path
/// long enough to look a link up.
///
/// Returns `error.NoSpaceLeft` if `buf` is too small, which a caller with a
/// `entity_path_buffer_len` buffer only sees for a name Event Hubs would not
/// accept. Falling back to `entityPathFor` keeps such a name working.
pub fn entityPathInto(
    buf: []u8,
    event_hub_name: []const u8,
    partition_id: ?[]const u8,
) ![]const u8 {
    const id = partition_id orelse {
        if (event_hub_name.len > buf.len) return error.NoSpaceLeft;
        @memcpy(buf[0..event_hub_name.len], event_hub_name);
        return buf[0..event_hub_name.len];
    };
    return std.fmt.bufPrint(buf, "{s}/Partitions/{s}", .{ event_hub_name, id });
}

/// Sender links keyed by entity address, opened on demand.
///
/// The links belong to the session, which detaches and frees them when it is
/// deinitialised; this pool only owns the addresses it keys them by. Reusing a
/// link matters beyond the attach round trip: the peer's credit and the
/// negotiated `max-message-size` are per link.
/// How many batches a link keeps on the wire unconfirmed by default.
///
/// Eight covers a round trip an order of magnitude longer than the time it
/// takes to encode a batch, which is the regime that matters, and costs a ring
/// of eight slots per link. Raising it further trades memory and the number of
/// batches whose fate is unknown after a failure for very little more
/// throughput.
pub const default_max_in_flight: u32 = 8;

pub const SenderPool = struct {
    allocator: Allocator,
    session: *amqp.Session,
    /// Keyed by entity address rather than scanned, so the cost of finding a
    /// link does not grow with the caller's partition count. Measured worst
    /// case, 1000 lookups per timed iteration so the result is not the
    /// clock floor: a scan costs 8.1ns at N=4, 66ns at N=32, 467ns at N=256
    /// and 1.68us at N=1024, against a flat 4.8ns hashed at every N. The
    /// hash never loses, including at N=4. The pool owns the keys.
    entries: std.StringHashMapUnmanaged(*amqp.Sender) = .empty,
    deadline_ms: i64,
    /// Distinguishes these links from any others on the connection.
    link_id: []const u8,
    /// Why the broker refused the most recent delivery. An error cannot carry
    /// a payload, so it is recorded here as `Management` does for its status.
    /// Borrowed from the sender that failed and valid until its next send.
    last_rejection: ?amqp.Rejection = null,
    /// How many batches a link may have on the wire unconfirmed.
    max_in_flight: u32 = 1,

    pub const Options = struct {
        deadline_ms: i64,
        link_id: []const u8 = "eventhubs",
        /// How many batches a link may have on the wire unconfirmed.
        ///
        /// One makes every send wait a full round trip for the broker's
        /// disposition, which caps a link at one batch per round trip however
        /// large the batches are. Raising it lets `sendAsync`, and so
        /// `sendPipelined`, keep that many batches in flight.
        ///
        /// The blocking `send` still refuses to overlap with anything, so this
        /// only ever costs the ring: a few dozen bytes per slot, allocated
        /// once when the link attaches. Zero is treated as one.
        max_in_flight: u32 = default_max_in_flight,
    };

    pub fn init(allocator: Allocator, session: *amqp.Session, options: Options) SenderPool {
        return .{
            .allocator = allocator,
            .session = session,
            .deadline_ms = options.deadline_ms,
            .link_id = options.link_id,
            .max_in_flight = @max(options.max_in_flight, 1),
        };
    }

    /// Release the pool's own bookkeeping. The senders are the session's.
    pub fn deinit(self: *SenderPool) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| self.allocator.free(entry.key_ptr.*);
        self.entries.deinit(self.allocator);
        self.entries = .empty;
        self.last_rejection = null;
    }

    /// The sender attached to `address`, attaching one if there is none.
    pub fn senderFor(self: *SenderPool, address: []const u8) !*amqp.Sender {
        if (self.entries.get(address)) |sender| return sender;

        const name = try std.fmt.allocPrint(
            self.allocator,
            "{s}-sender-{s}",
            .{ address, self.link_id },
        );
        defer self.allocator.free(name);

        const owned = try self.allocator.dupe(u8, address);
        errdefer self.allocator.free(owned);

        try self.entries.ensureUnusedCapacity(self.allocator, 1);

        // Go asks for geo-replication so an offset stays meaningful across a
        // failover, and for mixed settlement so the broker reports acceptance.
        const sender = try amqp.openSender(self.session, .{
            .name = name,
            .target_address = address,
            .desired_capabilities = &.{amqp.georeplication_capability},
            .max_in_flight = self.max_in_flight,
        }, self.deadline_ms);

        self.entries.putAssumeCapacityNoClobber(owned, sender);
        return sender;
    }

    /// Detach the sender for `address` and forget it, so the next send
    /// reattaches.
    ///
    /// `detach` is false when the session is already gone: writing a detach
    /// into a dead connection would fail, and the link died with the session
    /// regardless.
    pub fn drop(self: *SenderPool, address: []const u8, detach: bool) void {
        const removed = self.entries.fetchRemove(address) orelse return;
        if (detach) self.session.closeSender(removed.value, self.deadline_ms);
        self.allocator.free(removed.key);
        self.last_rejection = null;
    }

    /// Forget every sender.
    pub fn dropAll(self: *SenderPool, detach: bool) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (detach) self.session.closeSender(entry.value_ptr.*, self.deadline_ms);
            self.allocator.free(entry.key_ptr.*);
        }
        self.entries.clearRetainingCapacity();
        self.last_rejection = null;
    }

    /// Point the pool at a rebuilt session.
    ///
    /// The old session took its senders with it, so they are forgotten rather
    /// than detached; detaching would write into a connection that is gone.
    pub fn rebind(self: *SenderPool, session: *amqp.Session) void {
        self.dropAll(false);
        self.session = session;
    }

    /// The largest transfer the broker will take on `address`, or null when it
    /// advertised no limit.
    pub fn maxMessageSize(self: *SenderPool, address: []const u8) !?u64 {
        const sender = try self.senderFor(address);
        return sender.maxMessageSize();
    }

    /// Send `batch` to `address` and wait for the broker to settle it.
    pub fn send(
        self: *SenderPool,
        allocator: Allocator,
        address: []const u8,
        batch: EventDataBatch,
    ) !void {
        if (batch.count() == 0) return SendError.EmptyBatch;

        const sender = try self.senderFor(address);
        const payload = try encodeBatchTransfer(allocator, batch);
        defer allocator.free(payload);

        self.last_rejection = null;
        sender.sendBytesWithOptions(
            payload,
            .{ .message_format = batch_message_format },
            self.deadline_ms,
        ) catch |err| {
            self.last_rejection = sender.rejection;
            return err;
        };
    }

    /// Write `batch` to `address` without waiting for the broker to confirm
    /// it, returning the token that names the delivery.
    ///
    /// The bytes are on the wire when this returns, so `batch` and its
    /// encoding may be released immediately; only the broker's verdict is
    /// outstanding. Collect it with `confirm`, which reports outcomes in send
    /// order and names each one, so a caller keeping several batches in flight
    /// can tell exactly which batch was refused and resend that one.
    ///
    /// Returns `error.InFlightWindowFull` once `max_in_flight` batches on
    /// `address` are unconfirmed; `confirm` retires one and makes room.
    pub fn sendAsync(
        self: *SenderPool,
        allocator: Allocator,
        address: []const u8,
        batch: EventDataBatch,
    ) !amqp.DeliveryToken {
        if (batch.count() == 0) return SendError.EmptyBatch;

        const sender = try self.senderFor(address);
        const payload = try encodeBatchTransfer(allocator, batch);
        defer allocator.free(payload);

        return sender.sendBytesAsync(
            payload,
            .{ .message_format = batch_message_format },
            self.deadline_ms,
        );
    }

    /// Wait for the broker's verdict on the oldest unconfirmed batch on
    /// `address`.
    ///
    /// A refusal comes back as `Settlement.outcome` rather than as an error,
    /// because the point of pipelining is knowing *which* batch was refused;
    /// `lastError` describes it until the next `confirm` on the same address.
    /// An error here means the link itself failed.
    pub fn confirm(self: *SenderPool, address: []const u8) !amqp.Settlement {
        const sender = try self.senderFor(address);
        const settlement = try sender.awaitSettlement(self.deadline_ms);
        self.last_rejection = settlement.rejection;
        return settlement;
    }

    /// How many batches on `address` are on the wire unconfirmed.
    pub fn unconfirmed(self: *SenderPool, address: []const u8) !usize {
        const sender = try self.senderFor(address);
        return sender.inFlight();
    }

    /// The result of a pipelined send. Total rather than an error union: the
    /// caller needs the accepted prefix even when it stopped early, since that
    /// is exactly what it must not send again.
    pub const PipelinedSend = struct {
        /// How many batches, counting from the front, the broker accepted.
        /// Deliveries settle in the order they were sent, so the accepted set
        /// is always a prefix.
        accepted: usize,
        /// Why it stopped, or null when every batch was accepted. The batch at
        /// index `accepted` is the one that failed; those after it were never
        /// given a verdict.
        err: ?anyerror = null,
    };

    /// Send every batch to `address`, keeping up to `max_in_flight` of them on
    /// the wire at once.
    ///
    /// This is the throughput path: one round trip covers the whole window
    /// instead of one batch. It does not retry — a caller wanting the Event
    /// Hubs schedule should resend the unaccepted remainder through
    /// `sendWithRetry`, which is what `ProducerClient.sendBatches` does.
    ///
    /// The link is always left idle, so the caller can fall straight back to
    /// the blocking path. Anything still unconfirmed when this stops early is
    /// abandoned, which means a batch the broker went on to accept can be sent
    /// twice — the same at-least-once bargain a retry already makes.
    pub fn sendPipelined(
        self: *SenderPool,
        allocator: Allocator,
        address: []const u8,
        batches: []const EventDataBatch,
    ) PipelinedSend {
        self.last_rejection = null;

        // Checked before anything below can abandon the window: this call
        // reads the link's depth as its own and empties the ring on the way
        // out, so sharing the link would both misreport which batches landed
        // and throw away a verdict its owner is still waiting for.
        const already = self.unconfirmed(address) catch |err| {
            return .{ .accepted = 0, .err = err };
        };
        if (already != 0) return .{ .accepted = 0, .err = error.DeliveriesInFlight };

        var accepted: usize = 0;
        const err = self.pipeline(allocator, address, batches, &accepted);

        // Every exit runs this. The caller has been told its accepted prefix
        // and will resend the rest, so a verdict arriving for the remainder
        // now has nobody to report to. Dropping the window is also what lets
        // the link be used again: a sender still holding unsettled deliveries
        // refuses every blocking send, so without this one timed-out pipeline
        // would wedge the fallback path it is supposed to hand off to.
        self.abandonInFlight(address);

        return .{ .accepted = accepted, .err = err };
    }

    /// The body of `sendPipelined`, split out so the window is emptied on
    /// every path rather than at each of half a dozen returns.
    fn pipeline(
        self: *SenderPool,
        allocator: Allocator,
        address: []const u8,
        batches: []const EventDataBatch,
        accepted: *usize,
    ) ?anyerror {
        var sent: usize = 0;
        while (sent < batches.len) {
            const outstanding = sent - accepted.*;
            // Retire the oldest to make room, so the window stays full rather
            // than draining between batches.
            if (outstanding >= self.max_in_flight) {
                self.confirmOne(address) catch |err| return err;
                accepted.* += 1;
            }

            _ = self.sendAsync(allocator, address, batches[sent]) catch |err| {
                // The send failed, but the deliveries already on the wire are
                // being judged on their own merits, so collect their verdicts
                // instead of abandoning batches the broker is about to accept.
                accepted.* += self.drain(address, sent - accepted.*);
                return err;
            };
            sent += 1;
        }

        while (accepted.* < sent) {
            self.confirmOne(address) catch |err| return err;
            accepted.* += 1;
        }
        return null;
    }

    /// Collect one verdict, mapping a refusal onto an error the way `send`
    /// does so that a pipelined failure classifies like a blocking one.
    fn confirmOne(self: *SenderPool, address: []const u8) !void {
        const settlement = try self.confirm(address);
        if (settlement.outcome != .accepted) return error.SendRejected;
    }

    /// Collect up to `count` outstanding verdicts, stopping at the first that
    /// is not an acceptance. Returns how many were accepted.
    fn drain(self: *SenderPool, address: []const u8, count: usize) usize {
        var accepted: usize = 0;
        while (accepted < count) : (accepted += 1) {
            self.confirmOne(address) catch return accepted;
        }
        return accepted;
    }

    /// Drop any verdicts still outstanding on `address`, leaving the link free
    /// for a blocking send. Nothing to do if the link was never opened.
    fn abandonInFlight(self: *SenderPool, address: []const u8) void {
        if (self.entries.get(address)) |sender| sender.abandonInFlight();
    }

    /// Send under the Event Hubs retry schedule.
    pub fn sendWithRetry(
        self: *SenderPool,
        allocator: Allocator,
        address: []const u8,
        batch: EventDataBatch,
        config: errors.RetryConfig,
    ) errors.Outcome(void) {
        const Op = struct {
            pool: *SenderPool,
            allocator: Allocator,
            address: []const u8,
            batch: EventDataBatch,

            pub fn call(op: *const @This(), attempt: *errors.Attempt) anyerror!void {
                return op.pool.send(op.allocator, op.address, op.batch) catch |err| {
                    op.pool.recordCondition(attempt);
                    return err;
                };
            }
        };

        const op = Op{
            .pool = self,
            .allocator = allocator,
            .address = address,
            .batch = batch,
        };
        return errors.retry(void, &op, config);
    }

    /// The most recent rejection as a structured Event Hubs error.
    pub fn lastError(self: *const SenderPool) ?errors.EventHubsError {
        const rejection = self.last_rejection orelse return null;
        return .{
            // A rejection carries a condition, but not every condition has a
            // stable public code; `send_rejected` is the honest fallback and is
            // what Rust reports for the whole class.
            .code = errors.errorCodeForCondition(rejection.condition) orelse .send_rejected,
            .amqp_condition = rejection.condition,
            .description = rejection.description,
        };
    }

    fn recordCondition(self: *const SenderPool, attempt: *errors.Attempt) void {
        const rejection = self.last_rejection orelse return;
        attempt.condition = rejection.condition;
        attempt.description = rejection.description;
    }

    /// Describe why the send to `address` failed, so the retrier can classify
    /// it.
    ///
    /// A rejection wins over a detach: the broker refused this specific
    /// delivery, which is more precise than "the link went away".
    pub fn recordFailure(self: *const SenderPool, address: []const u8, attempt: *errors.Attempt) void {
        if (self.last_rejection != null) return self.recordCondition(attempt);
        const sender = self.entries.get(address) orelse return;
        const detached = sender.detach_error orelse return;
        attempt.condition = detached.condition;
        attempt.description = detached.description;
    }
};

/// Lay out the batch exactly as it goes on the wire.
///
/// The envelope was encoded without a body, and `EventData.toAmqpMessage`
/// never produces a footer, so the data sections simply follow it.
pub fn encodeBatchTransfer(allocator: Allocator, batch: EventDataBatch) ![]u8 {
    const envelope = batch.envelope orelse return SendError.EmptyBatch;
    return event_data.encodeDataSectionsFromBlob(
        allocator,
        envelope,
        batch.blob.items,
        batch.ends.items,
    );
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const harness = amqp.test_peer;
const driver = amqp.connection_driver;
const Peer = harness.Peer;
const Fixture = harness.Fixture;
const EmittedFrames = harness.EmittedFrames;
const MemoryTransport = amqp.MemoryTransport;
const EventData = event_data.EventData;

/// The name `SenderPool` gives the link for `my-hub` at the default link id.
const test_link_name = "my-hub-sender-eventhubs";

/// Script attach and enough credit for `deliveries` sends.
fn scriptSender(peer: Peer, max_message_size: ?u64, deliveries: u32) !void {
    try harness.scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = test_link_name,
        .handle = 0,
        .role = .receiver,
        .max_message_size = max_message_size,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = deliveries + 5,
    } });
}

/// The payload of the one delivery written since the last `clearWritten`,
/// reassembled across frames, plus the format the transfer named.
const SentDelivery = struct {
    payload: []u8,
    message_format: ?u32,

    fn deinit(self: SentDelivery, allocator: Allocator) void {
        allocator.free(self.payload);
    }
};

fn lastDelivery(allocator: Allocator, mem: *MemoryTransport) !SentDelivery {
    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();

    var payload: std.ArrayList(u8) = .empty;
    errdefer payload.deinit(allocator);
    var format: ?u32 = null;
    var seen = false;

    for (frames.bodies.items) |body| {
        if (amqp.performative.peekDescriptor(body) != amqp.performative.descriptor.transfer) continue;
        if (!seen) {
            var decoded = try amqp.performative.decode(allocator, body);
            defer decoded.deinit();
            format = decoded.performative.transfer.message_format;
            seen = true;
        }
        try payload.appendSlice(allocator, try harness.transferPayload(allocator, body));
    }

    return .{ .payload = try payload.toOwnedSlice(allocator), .message_format = format };
}

/// Everything needed to drive a pool against a scripted peer.
///
/// Initialised in place: the pool holds a pointer into `fixture.session`, so
/// returning this by value would aim it at a dead frame. That reads fine on
/// Linux and segfaults on Windows.
const Scripted = struct {
    fixture: Fixture,
    pool: SenderPool = undefined,

    fn open(
        self: *Scripted,
        allocator: Allocator,
        mem: *MemoryTransport,
        clock: *driver.ManualClock,
        conn: *driver.Driver,
    ) !void {
        return self.openWith(allocator, mem, clock, conn, .{ .deadline_ms = 10_000 });
    }

    fn openWith(
        self: *Scripted,
        allocator: Allocator,
        mem: *MemoryTransport,
        clock: *driver.ManualClock,
        conn: *driver.Driver,
        options: SenderPool.Options,
    ) !void {
        self.* = .{ .fixture = try Fixture.init(allocator, mem, clock, conn) };
        errdefer self.fixture.deinit();
        self.pool = SenderPool.init(allocator, &self.fixture.session, options);
    }

    fn deinit(self: *Scripted) void {
        self.pool.deinit();
        self.fixture.deinit();
    }
};

fn batchOf(allocator: Allocator, bodies: []const []const u8, options: batch_mod.EventDataBatchOptions) !EventDataBatch {
    var out = try EventDataBatch.init(options);
    errdefer out.deinit(allocator);
    for (bodies) |body| {
        var event = EventData.init(body);
        defer event.deinit(allocator);
        try testing.expect(try out.tryAdd(allocator, event));
    }
    return out;
}

test "a rejected event leaves no trace in the encoded transfer" {
    const allocator = testing.allocator;

    // An event is encoded into the batch's scratch buffer before it is known
    // to fit, so a batch that refused one must still encode exactly as a batch
    // that was never offered it. Byte equality is what proves the refused
    // event left nothing behind in the shared blob.
    var event = EventData.init("z" ** 48);
    defer event.deinit(allocator);

    var filled = try EventDataBatch.init(.{ .max_bytes = 512 });
    defer filled.deinit(allocator);
    var accepted: usize = 0;
    while (try filled.tryAdd(allocator, event)) : (accepted += 1) {}
    try testing.expect(accepted > 1);
    // The loop above stopped on a refusal, so one has already happened here.
    try testing.expect(!try filled.tryAdd(allocator, event));

    var clean = try EventDataBatch.init(.{ .max_bytes = 512 });
    defer clean.deinit(allocator);
    for (0..accepted) |_| try testing.expect(try clean.tryAdd(allocator, event));

    try testing.expectEqual(clean.count(), filled.count());
    try testing.expectEqual(clean.sizeInBytes(), filled.sizeInBytes());
    // The blob itself, not just the sections cut from it: a refusal that
    // appended before checking the fit leaves bytes here that no end offset
    // names, and the encoded transfer alone cannot see them.
    try testing.expectEqual(clean.blob.items.len, filled.blob.items.len);

    const from_filled = try encodeBatchTransfer(allocator, filled);
    defer allocator.free(from_filled);
    const from_clean = try encodeBatchTransfer(allocator, clean);
    defer allocator.free(from_clean);

    try testing.expectEqualSlices(u8, from_clean, from_filled);
}

test "an event accepted after a refusal carries only its own bytes" {
    const allocator = testing.allocator;

    // An event is encoded before it is known to fit, so a commit ordered ahead
    // of the fit check would leave the refused bytes in the blob with no end
    // offset naming them. The next accepted event's section then starts at the
    // previous end and runs to the new one, swallowing the refused event
    // whole. Refusing at the end of a batch cannot show this: nothing is
    // appended afterwards, so the stray bytes fall outside every section.
    var small = EventData.init("small");
    defer small.deinit(allocator);
    var big = EventData.init("B" ** 600);
    defer big.deinit(allocator);

    var batch = try EventDataBatch.init(.{ .max_bytes = 512 });
    defer batch.deinit(allocator);

    try testing.expect(try batch.tryAdd(allocator, small));
    try testing.expect(!try batch.tryAdd(allocator, big));
    try testing.expect(try batch.tryAdd(allocator, small));

    try testing.expectEqual(@as(usize, 2), batch.count());
    for (0..2) |i| {
        const payload = batch.payloadAt(i);
        try testing.expect(std.mem.indexOf(u8, payload, "small") != null);
        try testing.expect(std.mem.indexOf(u8, payload, "BBBB") == null);
    }

    // The two events are identical, so their sections are the same length and
    // between them account for every byte of the blob.
    try testing.expectEqual(batch.payloadAt(0).len, batch.payloadAt(1).len);
    try testing.expectEqual(batch.blob.items.len, batch.payloadAt(0).len * 2);
}

test "a refused oversized event does not park its encoding on the batch" {
    const allocator = testing.allocator;

    // `scratch` is reused, so it keeps the high-water mark of every event
    // *offered*, not every event adopted — and an event is encoded in full
    // before its size is checked. Without a release on the refusal path a
    // batch that refused one huge event would hold that encoding until
    // `deinit`, which the per-event allocation this replaced never did.
    var small = EventData.init("small");
    defer small.deinit(allocator);
    var huge = EventData.init("H" ** 200_000);
    defer huge.deinit(allocator);

    var batch = try EventDataBatch.init(.{ .max_bytes = 4096 });
    defer batch.deinit(allocator);

    try testing.expect(try batch.tryAdd(allocator, small));
    try testing.expect(!try batch.tryAdd(allocator, huge));

    // Nothing the batch can accept needs more than `max_size_bytes`.
    try testing.expect(batch.scratch.data.len <= batch.max_size_bytes);

    // Still usable afterwards: the release must not have left a buffer that
    // the next event cannot encode into.
    try testing.expect(try batch.tryAdd(allocator, small));
    try testing.expectEqual(@as(usize, 2), batch.count());
    try testing.expectEqual(batch.payloadAt(0).len, batch.payloadAt(1).len);
    try testing.expectEqual(batch.blob.items.len, batch.payloadAt(0).len * 2);
}

test "scratch is reused across accepted events rather than released" {
    const allocator = testing.allocator;

    // Reuse is the entire point of `scratch` — it is what makes encoding cost
    // nothing per event after the first. Releasing it on the accept path as
    // well as the refusal path would be harmless for correctness, would leave
    // every other test passing, and would quietly restore the per-event
    // allocation this change exists to remove.
    var small = EventData.init("small");
    defer small.deinit(allocator);

    var batch = try EventDataBatch.init(.{ .max_bytes = 4096 });
    defer batch.deinit(allocator);

    try testing.expect(try batch.tryAdd(allocator, small));
    const after_first = batch.scratch.data.len;
    try testing.expect(after_first > 0);

    try testing.expect(try batch.tryAdd(allocator, small));
    try testing.expectEqual(after_first, batch.scratch.data.len);
}

test "payloadAt returns each event's own encoded bytes" {
    const allocator = testing.allocator;

    const bodies = [_][]const u8{ "first", "second body", "third body is longest" };
    var batch = try batchOf(allocator, &bodies, .{});
    defer batch.deinit(allocator);

    try testing.expectEqual(bodies.len, batch.count());

    // Every payload must both differ from its neighbours and contain its own
    // body, so an off-by-one in the end offsets cannot pass.
    var total: usize = 0;
    for (bodies, 0..) |body, i| {
        const payload = batch.payloadAt(i);
        try testing.expect(std.mem.indexOf(u8, payload, body) != null);
        for (bodies, 0..) |other, j| {
            if (i == j) continue;
            try testing.expect(std.mem.indexOf(u8, payload, other) == null);
        }
        total += payload.len;
    }

    // The payloads tile the blob exactly, with no gap and no overlap.
    try testing.expectEqual(batch.blob.items.len, total);
}

test "a batch goes out as one transfer whose data sections are the events" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptSender(peer, null, 1);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    var payload_batch = try batchOf(allocator, &.{ "one", "two", "three" }, .{});
    defer payload_batch.deinit(allocator);

    mem.clearWritten();
    try scripted.pool.send(allocator, "my-hub", payload_batch);

    const sent = try lastDelivery(allocator, &mem);
    defer sent.deinit(allocator);
    try testing.expectEqual(batch_message_format, sent.message_format.?);

    var envelope = try amqp.decodeMessage(allocator, sent.payload);
    defer envelope.deinit();

    const sections = envelope.message.body.data;
    try testing.expectEqual(@as(usize, 3), sections.len);

    // Each section is itself a complete AMQP message, which is what makes the
    // service able to split a batch back into individual events.
    const expected = [_][]const u8{ "one", "two", "three" };
    for (sections, expected) |section, want| {
        var inner = try amqp.decodeMessage(allocator, section);
        defer inner.deinit();
        try testing.expectEqual(@as(usize, 1), inner.message.body.data.len);
        try testing.expectEqualStrings(want, inner.message.body.data[0]);
    }
}

test "a partition key rides along as a message annotation" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptSender(peer, null, 1);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    var keyed = try batchOf(allocator, &.{"hello"}, .{ .partition_key = "orders-7" });
    defer keyed.deinit(allocator);

    mem.clearWritten();
    try scripted.pool.send(allocator, "my-hub", keyed);

    const sent = try lastDelivery(allocator, &mem);
    defer sent.deinit(allocator);

    // The envelope is the first event's sections, so the key the service reads
    // for routing is on the transfer itself, not only on the inner messages.
    var envelope = try amqp.decodeMessage(allocator, sent.payload);
    defer envelope.deinit();
    try testing.expectEqualStrings(
        "orders-7",
        annotation(envelope.message.message_annotations.?, event_data.partition_key_annotation).?.string,
    );

    var inner = try amqp.decodeMessage(allocator, envelope.message.body.data[0]);
    defer inner.deinit();
    try testing.expectEqualStrings(
        "orders-7",
        annotation(inner.message.message_annotations.?, event_data.partition_key_annotation).?.string,
    );
}

fn annotation(entries: []const amqp.uamqp.MapEntry, key: []const u8) ?amqp.uamqp.AmqpValue {
    for (entries) |entry| {
        const name = switch (entry.key) {
            .symbol, .string => |s| s,
            else => continue,
        };
        if (std.mem.eql(u8, name, key)) return entry.value;
    }
    return null;
}

test "a pipelined send that stops early leaves the link fit for a blocking send" {
    // The failure path hands off to `sendWithRetry`, which is a blocking send,
    // and a sender still holding unsettled deliveries refuses those outright.
    // So if the window were not emptied here, the very first pipelined failure
    // would take the retry path down with it — permanently, for this link.
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptSender(peer, null, 4);
    // Refuse the first batch. The second is on the wire by then and never
    // gets a verdict; the third is never sent.
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .{ .rejected = .{
            .condition = "amqp:link:message-size-exceeded",
            .description = "too big",
        } },
    } });
    // The blocking send that follows takes delivery id 2: the abandoned
    // deliveries spent 0 and 1, and ids never rewind.
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 2,
        .last = 2,
        .settled = true,
        .state = .accepted,
    } });

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.openWith(allocator, &mem, &clock, &conn, .{
        .deadline_ms = 10_000,
        .max_in_flight = 2,
    });
    defer scripted.deinit();

    var batches: [3]EventDataBatch = undefined;
    for (&batches) |*b| b.* = try batchOf(allocator, &.{"hello"}, .{});
    defer for (&batches) |*b| b.deinit(allocator);

    const result = scripted.pool.sendPipelined(allocator, "my-hub", &batches);
    try testing.expectEqual(@as(usize, 0), result.accepted);
    try testing.expectEqual(@as(?anyerror, error.SendRejected), result.err);

    // Nothing outstanding, so the caller can fall straight back to the
    // retrying blocking path with the batches it was not told were accepted.
    try testing.expectEqual(@as(usize, 0), try scripted.pool.unconfirmed("my-hub"));
    try scripted.pool.send(allocator, "my-hub", batches[0]);
}

test "a fully accepted pipeline reports every batch and stays idle" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptSender(peer, null, 4);
    for (0..3) |i| {
        try peer.push(0, .{ .disposition = .{
            .role = .receiver,
            .first = @intCast(i),
            .last = @intCast(i),
            .settled = true,
            .state = .accepted,
        } });
    }

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.openWith(allocator, &mem, &clock, &conn, .{
        .deadline_ms = 10_000,
        .max_in_flight = 2,
    });
    defer scripted.deinit();

    var batches: [3]EventDataBatch = undefined;
    for (&batches) |*b| b.* = try batchOf(allocator, &.{"hello"}, .{});
    defer for (&batches) |*b| b.deinit(allocator);

    const result = scripted.pool.sendPipelined(allocator, "my-hub", &batches);
    try testing.expectEqual(@as(usize, 3), result.accepted);
    try testing.expectEqual(@as(?anyerror, null), result.err);
    try testing.expectEqual(@as(usize, 0), try scripted.pool.unconfirmed("my-hub"));
}

test "a pipelined send keeps the window full instead of draining between batches" {
    // The point of the exercise: with a window of 3, all three batches are on
    // the wire before the first verdict is collected, so the round trip is
    // paid once rather than three times.
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptSender(peer, null, 4);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 2,
        .settled = true,
        .state = .accepted,
    } });

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.openWith(allocator, &mem, &clock, &conn, .{
        .deadline_ms = 10_000,
        .max_in_flight = 3,
    });
    defer scripted.deinit();

    var batches: [3]EventDataBatch = undefined;
    for (&batches) |*b| b.* = try batchOf(allocator, &.{"hello"}, .{});
    defer for (&batches) |*b| b.deinit(allocator);

    // One disposition covering all three is the only thing the peer sends, so
    // this passes only if nothing waited for a verdict mid-flight.
    const result = scripted.pool.sendPipelined(allocator, "my-hub", &batches);
    try testing.expectEqual(@as(usize, 3), result.accepted);
    try testing.expectEqual(@as(?anyerror, null), result.err);
}

test "a window of zero is read as one rather than stalling every send" {
    // A caller computing the window — from a config value, say — can land on
    // zero, and an unclamped zero makes the very first batch look like an
    // overflow, so `sendPipelined` fails before sending anything.
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptSender(peer, null, 2);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.openWith(allocator, &mem, &clock, &conn, .{
        .deadline_ms = 10_000,
        .max_in_flight = 0,
    });
    defer scripted.deinit();

    var batch = try batchOf(allocator, &.{"hello"}, .{});
    defer batch.deinit(allocator);

    const batches = [_]EventDataBatch{batch};
    const result = scripted.pool.sendPipelined(allocator, "my-hub", &batches);
    try testing.expectEqual(@as(usize, 1), result.accepted);
    try testing.expectEqual(@as(?anyerror, null), result.err);
}

test "a rejected batch surfaces the broker's condition" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptSender(peer, null, 1);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .{ .rejected = .{
            .condition = "amqp:link:message-size-exceeded",
            .description = "The received message is larger than the maximum allowed size.",
        } },
    } });

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    var rejected = try batchOf(allocator, &.{"hello"}, .{});
    defer rejected.deinit(allocator);

    try testing.expectError(
        error.SendRejected,
        scripted.pool.send(allocator, "my-hub", rejected),
    );

    const failure = scripted.pool.lastError().?;
    try testing.expectEqualStrings("amqp:link:message-size-exceeded", failure.amqp_condition.?);
    try testing.expectEqualStrings(
        "The received message is larger than the maximum allowed size.",
        failure.description.?,
    );
    // `message-size-exceeded` has no stable public code of its own, so the
    // rejection itself is what the caller sees.
    try testing.expectEqual(errors.ErrorCode.send_rejected, failure.code);
}

test "a link is attached once and reused for the same address" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptSender(peer, 1048576, 2);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 1,
        .last = 1,
        .settled = true,
        .state = .accepted,
    } });

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    var first = try batchOf(allocator, &.{"a"}, .{});
    defer first.deinit(allocator);
    var second = try batchOf(allocator, &.{"b"}, .{});
    defer second.deinit(allocator);

    mem.clearWritten();
    try scripted.pool.send(allocator, "my-hub", first);
    try scripted.pool.send(allocator, "my-hub", second);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    // One attach for two sends. Only one is scripted, so a second attempt
    // would run the peer out of bytes rather than quietly reattaching.
    const attaches = try frames.of(allocator, amqp.performative.descriptor.attach);
    defer allocator.free(attaches);
    try testing.expectEqual(@as(usize, 1), attaches.len);

    // The peer's limit is readable without another attach.
    try testing.expectEqual(@as(u64, 1048576), (try scripted.pool.maxMessageSize("my-hub")).?);
}

test "an empty batch is refused before a link is touched" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try harness.scriptHandshake(peer, 512);

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    var empty = try EventDataBatch.init(.{});
    defer empty.deinit(allocator);

    // No attach is scripted, so reaching the link at all would hang or fail.
    try testing.expectError(
        SendError.EmptyBatch,
        scripted.pool.send(allocator, "my-hub", empty),
    );
}

test "entityPathInto writes what entityPathFor would allocate" {
    const allocator = std.testing.allocator;
    var buf: [entity_path_buffer_len]u8 = undefined;

    for ([_]?[]const u8{ null, "3", "1023" }) |partition_id| {
        const allocated = try entityPathFor(allocator, "my-hub", partition_id);
        defer allocator.free(allocated);
        try std.testing.expectEqualStrings(allocated, try entityPathInto(&buf, "my-hub", partition_id));
    }

    // Too small to hold either shape, and it says so rather than truncating.
    var tiny: [4]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, entityPathInto(&tiny, "my-hub", "3"));
    try std.testing.expectError(error.NoSpaceLeft, entityPathInto(&tiny, "my-hub", null));
}

test "entityPathFor targets the hub or one partition" {
    const allocator = testing.allocator;

    const hub = try entityPathFor(allocator, "my-hub", null);
    defer allocator.free(hub);
    try testing.expectEqualStrings("my-hub", hub);

    const partition = try entityPathFor(allocator, "my-hub", "3");
    defer allocator.free(partition);
    try testing.expectEqualStrings("my-hub/Partitions/3", partition);
}

// ───────────── Round trips, measured against a reactive peer ─────────────

const Transport = amqp.transport.Transport;
const TransportError = amqp.transport.TransportError;

// A test peer that answers only what the client has already asked for.
//
// `MemoryTransport` plus `test_peer` scripts the broker's whole side of a
// conversation into the client's read buffer before the client writes
// anything. That is fine for asserting *what* the client sends, but it makes
// round trips unobservable: the answers are in the buffer before the questions
// are written, so there is nothing to wait for. "a peer that answers before it
// is asked shows no round trips at all" pins that — eight batches, zero stalls.
//
// That is why no claim about pipelining could be supported here. What
// pipelining buys is one round trip per window rather than one per batch, and
// a peer that has already answered cannot show it.
//
// `ReactivePeer` withholds each response until the client has flushed the
// request that justifies it. A response is released only when the client
// stalls, which makes a stall countable: `round_trips` is the number of times
// the client could not proceed without hearing from the peer. That count is
// deterministic, so it can be asserted rather than timed — which matters
// here, because the wall-clock ranking of the two send benchmarks flips with
// run order and means nothing.
//
// It counts round trips and deliberately does not simulate one. Charging each
// a delay would need a `std.Io` the transport vtable has nowhere to put, and
// would turn a figure that repeats exactly into one this host cannot measure
// twice the same way. A caller wanting elapsed time can multiply.

const ReactivePeer = struct {
    allocator: Allocator,
    mem: *amqp.MemoryTransport,
    units: []const Unit,
    released: usize = 0,
    round_trips: usize = 0,
    /// Delivery ids seen on the wire, in the order the client sent them.
    seen: std.ArrayList(u32) = .empty,
    /// Whether stalls are tallied. Each caller picks its own window: the send
    /// measurements switch it on after the connection handshake, leaving the
    /// link attach ahead of them but pre-answered by the greeting, while the
    /// unanswered-stall test switches it on from the first byte precisely so
    /// that one stall is counted.
    counting: bool = false,

    /// One thing the peer says, and what the client must have said first.
    const Unit = union(enum) {
        /// Released on the first stall, whatever the client has sent. The
        /// handshake, attach and flow are these: they answer frames that carry
        /// no delivery at all.
        greeting: []const u8,
        /// Accept the nth delivery, once the client has flushed it.
        ///
        /// By the id the client actually used, never by `n`. This driver
        /// assigns a delivery the session's `next_outgoing_id` (`link.zig`,
        /// `Sender.sendBytesAsync`), which §2.5.6 advances once per transfer
        /// *frame*, so id and index coincide only while every delivery fits in
        /// one frame. The spec does not require that identity — §2.6.12 says
        /// only that a session assigns the id — so a peer must read the id off
        /// the wire rather than assume either. A scripted id silently stops
        /// matching the moment a batch splits, and the client then waits out
        /// its deadline on a message that had arrived.
        settle: usize,
    };

    fn deinit(self: *ReactivePeer) void {
        self.seen.deinit(self.allocator);
    }

    fn transport(self: *ReactivePeer) Transport {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: Transport.VTable = .{
        .read = read,
        .write = write,
        .flush = flush,
        .close = close,
    };

    fn unread(self: *const ReactivePeer) usize {
        return self.mem.inbound.items.len - self.mem.inbound_pos;
    }

    /// Release every response the client has now earned.
    ///
    /// Releasing all of them together, rather than one per stall, is the whole
    /// point: a real peer that has received eight transfers answers all eight
    /// without waiting to be asked again, so a window costs one round trip
    /// however many deliveries it holds. Releasing one at a time would charge
    /// pipelining the same as sequential sending and quietly erase the very
    /// difference this exists to measure.
    fn serve(self: *ReactivePeer) TransportError!void {
        self.seen.clearRetainingCapacity();
        observeDeliveries(self.allocator, self.mem.written(), &self.seen) catch
            return error.ReadFailed;

        var released_any = false;
        while (self.released < self.units.len) {
            switch (self.units[self.released]) {
                .greeting => |bytes| try self.mem.pushPeerBytes(bytes),
                .settle => |n| {
                    if (n >= self.seen.items.len) break;
                    self.accept(self.seen.items[n]) catch return error.ReadFailed;
                },
            }
            self.released += 1;
            released_any = true;
        }
        // A stall the peer cannot answer is not a round trip: nothing was
        // asked for that has not been said. `MemoryTransport` reports an
        // exhausted buffer as end of stream unless `starve` is set, so in the
        // send measurements below this never happens — but it is reachable,
        // and "a stall the peer cannot answer ends the connection" counts the
        // one stall of a connection that gets no answer at all, which without
        // this guard would be charged as a round trip.
        if (!released_any) return;

        if (self.counting) self.round_trips += 1;
    }

    fn accept(self: *ReactivePeer, delivery_id: u32) !void {
        var scratch = amqp.MemoryTransport.init(self.allocator);
        defer scratch.deinit();
        const peer = amqp.test_peer.Peer{
            .allocator = self.allocator,
            .mem = &scratch,
        };
        try peer.push(0, .{ .disposition = .{
            .role = .receiver,
            .first = delivery_id,
            .last = delivery_id,
            .settled = true,
            .state = .accepted,
        } });
        try self.mem.pushPeerBytes(scratch.inbound.items);
    }

    fn read(ptr: *anyopaque, buffer: []u8) TransportError!usize {
        const self: *ReactivePeer = @ptrCast(@alignCast(ptr));
        // Only an exhausted buffer is a stall. A read that the peer can
        // already satisfy costs nothing on a real link either.
        if (self.unread() == 0) try self.serve();
        return self.mem.transport().read(buffer);
    }

    fn write(ptr: *anyopaque, bytes: []const u8) TransportError!void {
        const self: *ReactivePeer = @ptrCast(@alignCast(ptr));
        return self.mem.transport().write(bytes);
    }

    fn flush(ptr: *anyopaque) TransportError!void {
        const self: *ReactivePeer = @ptrCast(@alignCast(ptr));
        return self.mem.transport().flush();
    }

    fn close(ptr: *anyopaque) void {
        const self: *ReactivePeer = @ptrCast(@alignCast(ptr));
        self.mem.transport().close();
    }
};

/// Delivery ids the client has flushed, in order, read from its own frames.
///
/// A delivery is a transfer carrying a `delivery_id`; the continuation frames
/// of a split message omit it, so a message larger than one frame is one
/// delivery — which matters, because a batch over the negotiated frame size
/// would otherwise look like several and be settled before it had finished
/// being sent. Reading the client's own output rather than tracking calls into
/// the pool keeps this honest about what actually reached the wire.
fn observeDeliveries(
    allocator: Allocator,
    written: []const u8,
    out: *std.ArrayList(u32),
) !void {
    return collect(allocator, written, out, true);
}

/// Transfer *frames*, including the continuations `observeDeliveries` skips.
/// A test asserting that a fixture really did split needs this; without it,
/// "a split delivery counts once" passes vacuously on a fixture that never
/// split.
fn countTransferFrames(allocator: Allocator, written: []const u8) !usize {
    var all: std.ArrayList(u32) = .empty;
    defer all.deinit(allocator);
    try collect(allocator, written, &all, false);
    return all.items.len;
}

/// Walks the client's flushed frames. With `out` collecting only the ids of
/// delivery-bearing transfers when `deliveries_only`, every transfer frame
/// otherwise (continuations contribute a placeholder id, never read).
fn collect(
    allocator: Allocator,
    written: []const u8,
    out: *std.ArrayList(u32),
    deliveries_only: bool,
) !void {
    var offset: usize = if (std.mem.startsWith(u8, written, "AMQP")) 8 else 0;

    while (offset + amqp.uamqp.frame.frame_header_size <= written.len) {
        const header = try amqp.uamqp.frame.FrameHeader.parse(
            written[offset..][0..amqp.uamqp.frame.frame_header_size],
        );
        const header_len = @as(usize, header.doff) * 4;
        if (header.size < header_len or offset + header.size > written.len) break;
        const body = written[offset + header_len ..][0 .. header.size - header_len];
        offset += @intCast(header.size);

        if (amqp.performative.peekDescriptor(body) != amqp.performative.descriptor.transfer) {
            continue;
        }

        var decode_buf: [512]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&decode_buf);
        var decoded = amqp.performative.decode(fba.allocator(), body) catch continue;
        defer decoded.deinit();

        if (decoded.performative.transfer.delivery_id) |id| {
            try out.append(allocator, id);
        } else if (!deliveries_only) {
            try out.append(allocator, 0);
        }
    }
}

/// The peer's side as withheld units: the connection greeting, then one
/// settlement per delivery, each owed only once that delivery is on the wire.
fn reactiveSendUnits(
    allocator: Allocator,
    units: *std.ArrayList(ReactivePeer.Unit),
    deliveries: u32,
    prescripted: bool,
) !void {
    var scratch = MemoryTransport.init(allocator);
    defer scratch.deinit();
    const peer = Peer{ .allocator = allocator, .mem = &scratch };
    try scriptSender(peer, null, deliveries);

    // `prescripted` reproduces what the send benchmarks do: settle every
    // delivery in the greeting, before the client has sent one. Delivery ids
    // can be guessed here only because each batch fits in a single frame.
    if (prescripted) {
        var id: u32 = 0;
        while (id < deliveries) : (id += 1) try peer.push(0, .{ .disposition = .{
            .role = .receiver,
            .first = id,
            .last = id,
            .settled = true,
            .state = .accepted,
        } });
    }

    try units.append(allocator, .{
        .greeting = try allocator.dupe(u8, scratch.inbound.items),
    });
    if (prescripted) return;

    var n: usize = 0;
    while (n < deliveries) : (n += 1) try units.append(allocator, .{ .settle = n });
}

fn freeUnits(allocator: Allocator, units: *std.ArrayList(ReactivePeer.Unit)) void {
    for (units.items) |unit| switch (unit) {
        .greeting => |bytes| allocator.free(bytes),
        .settle => {},
    };
    units.deinit(allocator);
}

const RoundTripRun = struct {
    round_trips: usize,
    accepted: usize,
    /// Transfer frames the client flushed, so a test can prove its fixture
    /// really did split a delivery rather than assume it.
    transfer_frames: usize,
};

const Mode = enum { sequential, pipelined, prescripted };

fn measureRoundTrips(
    allocator: Allocator,
    mode: Mode,
    count: u32,
    body_len: usize,
) !RoundTripRun {
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();

    var units: std.ArrayList(ReactivePeer.Unit) = .empty;
    defer freeUnits(allocator, &units);
    try reactiveSendUnits(allocator, &units, count, mode == .prescripted);

    var peer = ReactivePeer{
        .allocator = allocator,
        .mem = &mem,
        .units = units.items,
    };
    defer peer.deinit();
    var clock: driver.ManualClock = .{};
    var conn = try driver.Driver.init(
        allocator,
        peer.transport(),
        clock.clock(),
        harness.driver_options,
    );
    defer conn.deinit();

    var scripted: Scripted = undefined;
    try scripted.openWith(allocator, &mem, &clock, &conn, .{
        .deadline_ms = 10_000,
        .max_in_flight = count,
    });
    defer scripted.deinit();

    var batches = try allocator.alloc(EventDataBatch, count);
    defer allocator.free(batches);
    var built: usize = 0;
    defer for (batches[0..built]) |*b| b.deinit(allocator);
    const body = try allocator.alloc(u8, body_len);
    defer allocator.free(body);
    @memset(body, 'x');
    for (batches) |*b| {
        b.* = try batchOf(allocator, &.{body}, .{});
        built += 1;
    }

    // The connection is open, but the link is not: `SenderPool` attaches
    // lazily, so the attach and its flow are exchanged inside the first send,
    // after counting starts. They cost no stall because `reactiveSendUnits`
    // deliberately folds them into the greeting, which answers frames that
    // carry no delivery. What is being counted is the deliveries.
    peer.counting = true;
    var accepted: usize = 0;
    if (mode == .pipelined) {
        const result = scripted.pool.sendPipelined(allocator, "my-hub", batches);
        if (result.err) |err| return err;
        accepted = result.accepted;
    } else {
        for (batches) |b| {
            try scripted.pool.send(allocator, "my-hub", b);
            accepted += 1;
        }
    }
    return .{
        .round_trips = peer.round_trips,
        .accepted = accepted,
        .transfer_frames = try countTransferFrames(allocator, mem.written()),
    };
}

test "a sequential send waits for the peer once per batch" {
    // The scripted peer cannot show this: it answers before it is asked, so
    // eight batches cost one read whichever way they are sent. Against a peer
    // that withholds each settlement until its transfer is on the wire, the
    // blocking path pays a full round trip for every batch.
    const run = try measureRoundTrips(testing.allocator, .sequential, 8, 5);
    try testing.expectEqual(@as(usize, 8), run.accepted);
    try testing.expectEqual(@as(usize, 8), run.round_trips);
}

test "a pipelined window waits for the peer once for the whole window" {
    // The same eight batches and the same peer, differing only in whether the
    // window is kept full. This is the entire benefit of pipelining, and it is
    // the first measurement in this package able to see it.
    const run = try measureRoundTrips(testing.allocator, .pipelined, 8, 5);
    try testing.expectEqual(@as(usize, 8), run.accepted);
    try testing.expectEqual(@as(usize, 1), run.round_trips);
}

test "a batch split across frames is one delivery, not one per frame" {
    // The peer settles delivery i once transfer i is on the wire, so counting
    // continuation frames as deliveries would settle a batch before it had
    // finished being sent. The negotiated frame size here is 512, so a 2 KiB
    // body must split; `transfer_frames` proves it did rather than leaving
    // this to pass vacuously on a fixture that fits in one frame.
    const run = try measureRoundTrips(testing.allocator, .sequential, 3, 2048);
    try testing.expectEqual(@as(usize, 3), run.accepted);
    try testing.expect(run.transfer_frames > 3);
    try testing.expectEqual(@as(usize, 3), run.round_trips);
}

test "a peer that answers before it is asked shows no round trips at all" {
    // The control for the two figures above, and the reason they needed a new
    // peer: this is exactly the arrangement `benchSendSequential` uses — every
    // settlement pushed into the client's read buffer before the first batch
    // is written. The same eight batches then stall zero times, so no
    // instrument placed on that peer could have told sequential from
    // pipelined.
    const run = try measureRoundTrips(testing.allocator, .prescripted, 8, 5);
    try testing.expectEqual(@as(usize, 8), run.accepted);
    try testing.expectEqual(@as(usize, 0), run.round_trips);
}

test "a stall the peer cannot answer ends the connection" {
    // Two things at once: an exhausted read buffer is end of stream, which is
    // why the send measurements never meet an unanswered stall; and a stall
    // the peer says nothing into is not a round trip. Counting is on from the
    // first byte here, so `serve` charging every stall rather than only the
    // answered ones would read 1 instead of 0.
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();

    var peer = ReactivePeer{
        .allocator = allocator,
        .mem = &mem,
        .units = &.{},
    };
    defer peer.deinit();
    peer.counting = true;
    var clock: driver.ManualClock = .{};
    var conn = try driver.Driver.init(
        allocator,
        peer.transport(),
        clock.clock(),
        harness.driver_options,
    );
    defer conn.deinit();

    try testing.expectError(error.ConnectionClosed, conn.open(100));
    try testing.expectEqual(@as(usize, 0), peer.round_trips);
}
