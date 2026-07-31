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
    entries: std.ArrayList(Entry) = .empty,
    deadline_ms: i64,
    /// Distinguishes these links from any others on the connection.
    link_id: []const u8,
    /// Why the broker refused the most recent delivery. An error cannot carry
    /// a payload, so it is recorded here as `Management` does for its status.
    /// Borrowed from the sender that failed and valid until its next send.
    last_rejection: ?amqp.Rejection = null,
    /// How many batches a link may have on the wire unconfirmed.
    max_in_flight: u32 = 1,

    const Entry = struct {
        address: []u8,
        sender: *amqp.Sender,
    };

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
        for (self.entries.items) |entry| self.allocator.free(entry.address);
        self.entries.deinit(self.allocator);
        self.entries = .empty;
        self.last_rejection = null;
    }

    /// The sender attached to `address`, attaching one if there is none.
    pub fn senderFor(self: *SenderPool, address: []const u8) !*amqp.Sender {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.address, address)) return entry.sender;
        }

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

        self.entries.appendAssumeCapacity(.{ .address = owned, .sender = sender });
        return sender;
    }

    /// Detach the sender for `address` and forget it, so the next send
    /// reattaches.
    ///
    /// `detach` is false when the session is already gone: writing a detach
    /// into a dead connection would fail, and the link died with the session
    /// regardless.
    pub fn drop(self: *SenderPool, address: []const u8, detach: bool) void {
        for (self.entries.items, 0..) |entry, i| {
            if (!std.mem.eql(u8, entry.address, address)) continue;
            if (detach) self.session.closeSender(entry.sender, self.deadline_ms);
            self.allocator.free(entry.address);
            _ = self.entries.orderedRemove(i);
            self.last_rejection = null;
            return;
        }
    }

    /// Forget every sender.
    pub fn dropAll(self: *SenderPool, detach: bool) void {
        for (self.entries.items) |entry| {
            if (detach) self.session.closeSender(entry.sender, self.deadline_ms);
            self.allocator.free(entry.address);
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
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.address, address)) {
                entry.sender.abandonInFlight();
                return;
            }
        }
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
        for (self.entries.items) |entry| {
            if (!std.mem.eql(u8, entry.address, address)) continue;
            const detached = entry.sender.detach_error orelse return;
            attempt.condition = detached.condition;
            attempt.description = detached.description;
            return;
        }
    }
};

/// Lay out the batch exactly as it goes on the wire.
///
/// The envelope was encoded without a body, and `EventData.toAmqpMessage`
/// never produces a footer, so the data sections simply follow it.
pub fn encodeBatchTransfer(allocator: Allocator, batch: EventDataBatch) ![]u8 {
    const envelope = batch.envelope orelse return SendError.EmptyBatch;
    return event_data.encodeDataSections(allocator, envelope, batch.marshaled.items);
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

test "entityPathFor targets the hub or one partition" {
    const allocator = testing.allocator;

    const hub = try entityPathFor(allocator, "my-hub", null);
    defer allocator.free(hub);
    try testing.expectEqualStrings("my-hub", hub);

    const partition = try entityPathFor(allocator, "my-hub", "3");
    defer allocator.free(partition);
    try testing.expectEqualStrings("my-hub/Partitions/3", partition);
}
