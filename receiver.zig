//! Receiving events from one Event Hubs partition.
//!
//! A partition is read through a single receiver link held open for the life
//! of the client. Go (`partition_client.go`) and Rust
//! (`consumer/event_receiver.rs`) both interpose an object like this rather
//! than exposing a one-shot call, because the link carries the reader's
//! position: reattaching without advancing the filter replays events that were
//! already handed to the caller.

const std = @import("std");
const amqp = @import("azure_sdk_amqp");
const event_data = @import("event_data.zig");
const errors = @import("errors.zig");
const position = @import("position.zig");

const Allocator = std.mem.Allocator;
const EventPosition = position.EventPosition;
const ReceivedEventData = event_data.ReceivedEventData;

/// Credit issued on attach when the caller expresses no preference. Go and
/// Rust both use 300.
pub const default_prefetch: i32 = 300;

/// The largest number of events a single receive may ask for, and the ceiling
/// on prefetch. It is the session's incoming window in Go, so asking for more
/// would let the peer overrun it.
pub const max_credit: u32 = 5000;

/// Names the reader in the broker's error text, so a stolen link says which
/// receiver took it.
pub const receiver_name_property = amqp.receiver_name_property;

/// The exclusive-consumer epoch. A higher level detaches every lower one.
pub const epoch_property = amqp.epoch_property;

pub const ReceiveError = error{
    /// `count` was zero, or above `max_credit`.
    InvalidCount,
    /// `prefetch` was above `max_credit`.
    PrefetchTooLarge,
};

pub const PartitionClientOptions = struct {
    /// Where to start reading. Defaults to `latest`, as Go and Rust do, so a
    /// client that says nothing sees only new events.
    start_position: EventPosition = .{},
    /// Claims exclusive ownership of the partition at this level. Absent
    /// leaves the reader non-exclusive.
    owner_level: ?i64 = null,
    /// Credit issued up front. Zero takes `default_prefetch`; a negative value
    /// disables prefetch and issues credit per receive, which is what a caller
    /// that wants to bound its own memory use asks for.
    prefetch: i32 = 0,
};

/// The AMQP address a partition is read from. Caller owns the result.
pub fn consumerPathFor(
    allocator: Allocator,
    event_hub_name: []const u8,
    consumer_group: []const u8,
    partition_id: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/ConsumerGroups/{s}/Partitions/{s}",
        .{ event_hub_name, consumer_group, partition_id },
    );
}

/// Reads events from one partition over a receiver link it keeps attached.
pub const PartitionClient = struct {
    allocator: Allocator,
    receiver: *amqp.Receiver,
    /// The selector the link was attached with, advanced past the last event
    /// delivered so a reattach resumes rather than replaying. Owned.
    filter_expression: []u8,
    /// As configured, before `default_prefetch` is substituted for zero.
    prefetch: i32,
    owner_level: ?i64,
    deadline_ms: i64,
    /// Set when the broker detached the link; a stolen link reports
    /// `amqp:link:stolen` here. Its strings belong to the receiver, so read it
    /// before the session is torn down.
    last_error: ?errors.EventHubsError = null,
    /// Scratch for decoding a received message, reset per event.
    ///
    /// `fromRawMessage` copies everything it keeps into the caller's
    /// allocator, so a decoded message is dead by the end of its iteration —
    /// but `decodeMessage` charges an arena and its pages for each one. One
    /// arena reset per event costs that once. It lives on the client rather
    /// than in `receiveEvents` because a caller asking for a few events at a
    /// time is the common shape, and a per-call arena would be cold every
    /// call.
    ///
    /// Capped rather than retained outright: an event may be up to a megabyte
    /// and decoding expands it, so the largest event ever received would
    /// otherwise stay pinned per partition for the life of the client.
    decode_arena: ?std.heap.ArenaAllocator = null,

    /// What `decode_arena` keeps between events. Below it,
    /// `retain_with_limit` is byte-for-byte `retain_capacity`, so ordinary
    /// traffic pays nothing for the cap.
    pub const decode_arena_limit = 256 * 1024;

    pub const Args = struct {
        /// `{hub}/ConsumerGroups/{group}/Partitions/{id}`.
        source_address: []const u8,
        /// Identifies this reader to the broker.
        instance_id: []const u8,
        deadline_ms: i64,
        /// Attach with this selector instead of rendering
        /// `options.start_position`. Used to resume from a position that was
        /// already reduced to an expression.
        filter_expression: ?[]const u8 = null,
    };

    /// Attach the receiver link and start reading.
    ///
    /// Initialise in place rather than assigning the result: nothing here
    /// points into the client, but `close` detaches a link the session also
    /// tracks, so the two must not disagree about lifetime.
    pub fn open(
        self: *PartitionClient,
        allocator: Allocator,
        session: *amqp.Session,
        args: Args,
        options: PartitionClientOptions,
    ) !void {
        if (options.prefetch > @as(i32, @intCast(max_credit))) return ReceiveError.PrefetchTooLarge;

        const filter = if (args.filter_expression) |expression|
            try allocator.dupe(u8, expression)
        else
            try options.start_position.toFilterExpression(allocator);
        errdefer allocator.free(filter);

        const name = try std.fmt.allocPrint(
            allocator,
            "{s}-receiver-{s}",
            .{ args.source_address, args.instance_id },
        );
        defer allocator.free(name);

        var properties: [2]amqp.MapEntry = undefined;
        var property_count: usize = 1;
        properties[0] = .{
            .key = .{ .symbol = receiver_name_property },
            .value = .{ .string = args.instance_id },
        };
        if (options.owner_level) |level| {
            properties[1] = .{
                .key = .{ .symbol = epoch_property },
                .value = .{ .long = level },
            };
            property_count = 2;
        }

        const filters = [_]amqp.performative.Filter{amqp.performative.Filter.selector(filter)};

        const receiver = try amqp.openReceiver(session, .{
            .name = name,
            .source_address = args.source_address,
            // Go sets the target to the instance id, which is what makes the
            // reader identifiable in a stolen-link message.
            .target_address = args.instance_id,
            .filters = &filters,
            .properties = properties[0..property_count],
            .desired_capabilities = &.{amqp.georeplication_capability},
            .prefetch = prefetchCredit(options.prefetch),
        }, args.deadline_ms);

        self.* = .{
            .allocator = allocator,
            .receiver = receiver,
            .filter_expression = filter,
            .prefetch = options.prefetch,
            .owner_level = options.owner_level,
            .deadline_ms = args.deadline_ms,
        };
    }

    /// Release the client. The link belongs to the session, which detaches it.
    pub fn deinit(self: *PartitionClient) void {
        self.allocator.free(self.filter_expression);
        self.filter_expression = &.{};
        if (self.decode_arena) |*a| a.deinit();
        self.decode_arena = null;
    }

    /// Detach the link and release the client.
    pub fn close(self: *PartitionClient, deadline_ms: i64) !void {
        defer self.deinit();
        try self.receiver.detach(deadline_ms);
    }

    /// The selector the next attach would use. Advances as events arrive.
    pub fn filterExpression(self: *const PartitionClient) []const u8 {
        return self.filter_expression;
    }

    /// Receive up to `count` events.
    ///
    /// Returns early with whatever arrived when the partition goes quiet,
    /// which is how Go behaves when its context expires: a caller asking for a
    /// full batch should not lose the events that did arrive. Free the result
    /// with `freeReceivedEvents`.
    pub fn receiveEvents(
        self: *PartitionClient,
        allocator: Allocator,
        count: u32,
    ) ![]ReceivedEventData {
        if (count == 0 or count > max_credit) return ReceiveError.InvalidCount;

        // Without prefetch the link holds no credit, so ask for exactly what
        // this call needs on top of anything still outstanding.
        if (self.prefetch < 0 and self.receiver.credit < count) {
            try self.receiver.issueCredit(count - self.receiver.credit);
        }

        var events: std.ArrayList(ReceivedEventData) = .empty;
        // `count` is exactly how many will be appended on the success path, and
        // a `ReceivedEventData` is large enough that regrowing a 300-deep
        // prefetch means repeatedly copying tens of kilobytes.
        try events.ensureTotalCapacityPrecise(allocator, count);
        errdefer {
            for (events.items) |*e| e.deinit(allocator);
            events.deinit(allocator);
        }

        // One disposition per message meant a frame on the wire per event; a
        // full prefetch window cost hundreds of round trips of bookkeeping.
        // `SettleBatch` coalesces the ids into runs and only breaks a run
        // where another link on the session took an id in between.
        var settling = amqp.SettleBatch.init(self.receiver, .accepted);

        while (events.items.len < count) {
            const delivery = self.receiver.receive(self.deadline_ms) catch |err| {
                self.recordDetach();
                // Events already in hand arrived, so dropping them here would
                // lose them outright. Hand back the short batch and let the
                // next call surface the failure: the link is dead, so that
                // call fails immediately with nothing to lose.
                if (events.items.len > 0) break;
                return err;
            };

            const received = blk: {
                // Decode into the client's scratch arena rather than a fresh
                // one per message. Nothing survives the block: the decoded
                // message points into the arena and into the driver's frame
                // buffer, and `fromRawMessage` copies what it keeps into
                // `allocator`.
                if (self.decode_arena == null) self.decode_arena = .init(self.allocator);
                const arena = &self.decode_arena.?;
                _ = arena.reset(.{ .retain_with_limit = decode_arena_limit });
                const message = try amqp.decodeMessageInto(arena.allocator(), delivery.payload);
                break :blk try event_data.fromRawMessage(allocator, rawFrom(&message));
            };

            // Capacity for `count` was reserved up front and the loop runs
            // only while short of it, so this cannot fail. That matters
            // beyond the allocation it saves: it leaves no point at which
            // the event is owned by both this frame and `events`, which is
            // what would otherwise let a later failure in this iteration
            // free it twice.
            events.appendAssumeCapacity(received);
            // `add` is not merely bookkeeping: it puts the open run on the
            // wire whenever a delivery id is not the one after the last,
            // which is whenever another link on the session took an id in
            // between. So it fails for the same reasons the flush below
            // does, and is swallowed for the same reason — see there.
            settling.add(delivery) catch {};
        }

        // Settling tells the peer these will not be asked for again. It is
        // advisory here: an unsettled delivery is redelivered, and a consumer
        // resumes from the sequence number rather than from AMQP settlement.
        // So a settle write that does not land is never worth the events that
        // did arrive — least of all on the break above, where the link that
        // would carry it is the one that just failed.
        settling.flush() catch {};

        if (events.items.len > 0) {
            try self.advancePast(events.items[events.items.len - 1].sequence_number);
        }
        return events.toOwnedSlice(allocator);
    }

    /// Move the selector past `sequence_number` so a reattach resumes.
    fn advancePast(self: *PartitionClient, sequence_number: i64) !void {
        const advanced = try EventPosition.fromSequenceNumber(sequence_number, false)
            .toFilterExpression(self.allocator);
        self.allocator.free(self.filter_expression);
        self.filter_expression = advanced;
    }

    fn recordDetach(self: *PartitionClient) void {
        const remote = self.receiver.detach_error orelse return;
        self.last_error = errors.EventHubsError.fromCondition(remote.condition, remote.description);
    }
};

/// Translate the public prefetch setting into link credit.
fn prefetchCredit(prefetch: i32) u32 {
    if (prefetch < 0) return 0;
    if (prefetch == 0) return @intCast(default_prefetch);
    return @intCast(prefetch);
}

fn rawFrom(message: *const amqp.message_codec.Message) event_data.RawMessage {
    return .{
        .body = switch (message.body) {
            .data => |sections| if (sections.len == 1) sections[0] else null,
            else => null,
        },
        .message_annotations = message.message_annotations,
        .application_properties = message.application_properties,
        .message_id = message.properties.message_id,
        .correlation_id = message.properties.correlation_id,
        .content_type = message.properties.content_type,
    };
}

/// Partition clients attached on demand, one per source address.
///
/// A client is kept for the life of the pool so its position survives across
/// calls: reopening per call would replay from the configured start position
/// every time.
pub const ReceiverPool = struct {
    allocator: Allocator,
    session: *amqp.Session,
    options: PartitionClientOptions,
    instance_id: []const u8,
    deadline_ms: i64,
    /// Keyed by source address. The pool owns the keys; the session owns the
    /// links behind the clients.
    clients: std.StringHashMapUnmanaged(*PartitionClient) = .empty,
    /// The selector each dropped client had reached, kept so a reattach
    /// resumes instead of replaying from the configured start position. Keys
    /// and values are both owned.
    positions: std.StringHashMapUnmanaged([]u8) = .empty,

    pub const Options = struct {
        instance_id: []const u8,
        deadline_ms: i64,
        client: PartitionClientOptions = .{},
    };

    pub fn init(allocator: Allocator, session: *amqp.Session, options: Options) ReceiverPool {
        return .{
            .allocator = allocator,
            .session = session,
            .options = options.client,
            .instance_id = options.instance_id,
            .deadline_ms = options.deadline_ms,
        };
    }

    pub fn deinit(self: *ReceiverPool) void {
        self.dropAll(false);
        self.clients.deinit(self.allocator);

        var positions = self.positions.iterator();
        while (positions.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.positions.deinit(self.allocator);
    }

    /// Detach the client for `source_address` and forget it, remembering where
    /// it had read to.
    ///
    /// `detach` is false when the session is already gone: writing a detach
    /// into a dead connection would fail, and the link died with the session
    /// regardless.
    pub fn drop(self: *ReceiverPool, source_address: []const u8, detach: bool) void {
        const entry = self.clients.fetchRemove(source_address) orelse return;
        const client = entry.value;

        // Remembered before the client is torn down, so the reattach resumes
        // rather than replaying everything already delivered.
        self.remember(entry.key, client.filterExpression()) catch {};

        if (detach) self.session.closeReceiver(client.receiver, self.deadline_ms);
        client.deinit();
        self.allocator.destroy(client);
        self.allocator.free(entry.key);
    }

    /// Forget every client, remembering where each had read to.
    pub fn dropAll(self: *ReceiverPool, detach: bool) void {
        var addresses: std.ArrayList([]const u8) = .empty;
        defer addresses.deinit(self.allocator);

        var it = self.clients.keyIterator();
        while (it.next()) |key| addresses.append(self.allocator, key.*) catch return;
        for (addresses.items) |address| self.drop(address, detach);
    }

    /// Point the pool at a rebuilt session.
    ///
    /// The old session took its links with it, so they are forgotten rather
    /// than detached; the remembered positions survive so the reattached
    /// clients resume.
    pub fn rebind(self: *ReceiverPool, session: *amqp.Session) void {
        self.dropAll(false);
        self.session = session;
    }

    fn remember(self: *ReceiverPool, source_address: []const u8, expression: []const u8) !void {
        const owned = try self.allocator.dupe(u8, expression);
        errdefer self.allocator.free(owned);

        const gop = try self.positions.getOrPut(self.allocator, source_address);
        if (gop.found_existing) {
            self.allocator.free(gop.value_ptr.*);
        } else {
            gop.key_ptr.* = self.allocator.dupe(u8, source_address) catch |err| {
                _ = self.positions.remove(source_address);
                return err;
            };
        }
        gop.value_ptr.* = owned;
    }

    /// The client for `source_address`, attaching one if this is the first
    /// call. `filter_expression` applies only to a first attach, and is
    /// ignored once the pool has remembered a position for the address.
    pub fn clientFor(
        self: *ReceiverPool,
        source_address: []const u8,
        filter_expression: ?[]const u8,
    ) !*PartitionClient {
        if (self.clients.get(source_address)) |existing| return existing;

        // A remembered position wins: reapplying the original filter after a
        // recovery would replay every event already delivered.
        const resume_from: ?[]const u8 = if (self.positions.get(source_address)) |remembered|
            remembered
        else
            filter_expression;

        const client = try self.allocator.create(PartitionClient);
        errdefer self.allocator.destroy(client);
        try client.open(self.allocator, self.session, .{
            .source_address = source_address,
            .instance_id = self.instance_id,
            .deadline_ms = self.deadline_ms,
            .filter_expression = resume_from,
        }, self.options);
        errdefer client.deinit();

        const key = try self.allocator.dupe(u8, source_address);
        errdefer self.allocator.free(key);
        try self.clients.put(self.allocator, key, client);
        return client;
    }

    /// Read up to `count` events, attaching on first use.
    pub fn receive(
        self: *ReceiverPool,
        allocator: Allocator,
        source_address: []const u8,
        filter_expression: ?[]const u8,
        count: u32,
    ) ![]ReceivedEventData {
        const client = try self.clientFor(source_address, filter_expression);
        return client.receiveEvents(allocator, count);
    }

    /// Why the broker detached the link for `source_address`.
    pub fn lastError(self: *ReceiverPool, source_address: []const u8) ?errors.EventHubsError {
        const client = self.clients.get(source_address) orelse return null;
        return client.last_error;
    }

    /// Describe why the receive from `source_address` failed, so the retrier
    /// can classify it.
    pub fn recordFailure(
        self: *ReceiverPool,
        source_address: []const u8,
        attempt: *errors.Attempt,
    ) void {
        const client = self.clients.get(source_address) orelse return;
        const detached = client.receiver.detach_error orelse return;
        attempt.condition = detached.condition;
        attempt.description = detached.description;
    }
};

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const harness = amqp.test_peer;
const driver = amqp.connection_driver;
const Peer = harness.Peer;
const Fixture = harness.Fixture;
const EmittedFrames = harness.EmittedFrames;
const MemoryTransport = amqp.MemoryTransport;

const test_source = "my-hub/ConsumerGroups/$default/Partitions/0";
const test_instance = "reader-1";
const test_link_name = test_source ++ "-receiver-" ++ test_instance;

/// Everything needed to drive a client against a scripted peer.
///
/// Initialised in place: the client's receiver is created by
/// `fixture.session`, so returning this by value would leave the session
/// pointer aimed at a dead frame.
const Scripted = struct {
    fixture: Fixture,
    client: PartitionClient = undefined,

    fn open(
        self: *Scripted,
        allocator: Allocator,
        mem: *MemoryTransport,
        clock: *driver.ManualClock,
        conn: *driver.Driver,
        options: PartitionClientOptions,
    ) !void {
        self.* = .{ .fixture = try Fixture.init(allocator, mem, clock, conn) };
        errdefer self.fixture.deinit();
        try self.client.open(allocator, &self.fixture.session, .{
            .source_address = test_source,
            .instance_id = test_instance,
            .deadline_ms = 10_000,
        }, options);
    }

    fn deinit(self: *Scripted) void {
        self.client.deinit();
        self.fixture.deinit();
    }
};

/// Script the peer's side of attach for the receiver under test.
fn scriptAttach(peer: Peer) !void {
    try harness.scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = test_link_name,
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
}

/// Push one event as a settled single-frame transfer.
fn pushEvent(
    allocator: Allocator,
    peer: Peer,
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

    const tag = [_]u8{@intCast(id)};
    try peer.pushTransfer(0, .{
        .handle = 0,
        .delivery_id = id,
        .delivery_tag = &tag,
        .message_format = 0,
        .settled = true,
        .more = false,
    }, payload);
}

/// Push one event split across transfer frames, which is how anything larger
/// than the negotiated frame size actually arrives.
fn pushChunkedEvent(
    allocator: Allocator,
    peer: Peer,
    id: u32,
    sequence_number: i64,
    body: []const u8,
    chunk_len: usize,
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

    const tag = [_]u8{@intCast(id)};
    var offset: usize = 0;
    var first = true;
    while (offset < payload.len) {
        const take = @min(chunk_len, payload.len - offset);
        const more = offset + take < payload.len;
        if (first) {
            try peer.pushTransfer(0, .{
                .handle = 0,
                .delivery_id = id,
                .delivery_tag = &tag,
                .message_format = 0,
                .settled = true,
                .more = more,
            }, payload[offset..][0..take]);
            first = false;
        } else {
            try peer.pushTransfer(0, .{
                .handle = 0,
                .more = more,
            }, payload[offset..][0..take]);
        }
        offset += take;
    }
}

/// The attach the client wrote, decoded. Caller must `deinit` it.
fn sentAttach(allocator: Allocator, mem: *MemoryTransport) !amqp.performative.Decoded {
    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    for (frames.bodies.items) |body| {
        if (amqp.performative.peekDescriptor(body) != amqp.performative.descriptor.attach) continue;
        return amqp.performative.decode(allocator, body);
    }
    return error.NoAttach;
}

test "consumerPathFor builds the consumer group address" {
    const allocator = testing.allocator;
    const path = try consumerPathFor(allocator, "my-hub", "$default", "3");
    defer allocator.free(path);
    try testing.expectEqualStrings("my-hub/ConsumerGroups/$default/Partitions/3", path);
}

test "prefetch maps onto link credit" {
    // Zero means "no preference", not "no credit"; only a negative value
    // disables prefetch.
    try testing.expectEqual(@as(u32, 300), prefetchCredit(0));
    try testing.expectEqual(@as(u32, 50), prefetchCredit(50));
    try testing.expectEqual(@as(u32, 0), prefetchCredit(-1));
}

test "attach carries the start position as a selector filter" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{
        .start_position = EventPosition.earliest(),
    });
    defer scripted.deinit();

    var attach = try sentAttach(allocator, &mem);
    defer attach.deinit();

    const filters = attach.performative.attach.source.?.filters.?;
    try testing.expectEqual(@as(usize, 1), filters.len);
    try testing.expectEqualStrings(amqp.performative.selector_filter_name, filters[0].name);
    try testing.expectEqualStrings(
        "amqp.annotation.x-opt-offset > '-1'",
        filters[0].value.string,
    );
}

test "attach names the reader and omits epoch without an owner level" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    var attach = try sentAttach(allocator, &mem);
    defer attach.deinit();

    const properties = attach.performative.attach.properties.?;
    try testing.expectEqual(@as(usize, 1), properties.len);
    try testing.expectEqualStrings(receiver_name_property, properties[0].key.symbol);
    try testing.expectEqualStrings(test_instance, properties[0].value.string);
    // The instance id also names the link's target, which is what makes a
    // stolen-link error say who stole it.
    try testing.expectEqualStrings(test_instance, attach.performative.attach.target.?.address.?);
}

test "an owner level attaches as an exclusive consumer" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{ .owner_level = 7 });
    defer scripted.deinit();

    var attach = try sentAttach(allocator, &mem);
    defer attach.deinit();

    const properties = attach.performative.attach.properties.?;
    try testing.expectEqual(@as(usize, 2), properties.len);
    try testing.expectEqualStrings(epoch_property, properties[1].key.symbol);
    try testing.expectEqual(@as(i64, 7), properties[1].value.long);
}

test "receiveEvents decodes events and advances past the last one" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);
    try pushEvent(allocator, peer, 0, 11, "first");
    try pushEvent(allocator, peer, 1, 12, "second");

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    const events = try scripted.client.receiveEvents(allocator, 2);
    defer event_data.freeReceivedEvents(allocator, events);

    try testing.expectEqual(@as(usize, 2), events.len);
    try testing.expectEqualStrings("first", events[0].body());
    try testing.expectEqualStrings("second", events[1].body());
    try testing.expectEqual(@as(i64, 12), events[1].sequence_number);

    // A reattach must resume after the last event handed out, or the caller
    // sees it twice.
    try testing.expectEqualStrings(
        "amqp.annotation.x-opt-sequence-number > '12'",
        scripted.client.filterExpression(),
    );
}

test "receiveEvents settles a whole batch in one disposition" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);

    const batch = 32;
    var i: u32 = 0;
    while (i < batch) : (i += 1) {
        try pushEvent(allocator, peer, i, @as(i64, i) + 1, "event");
    }

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    mem.clearWritten();
    const events = try scripted.client.receiveEvents(allocator, batch);
    defer event_data.freeReceivedEvents(allocator, events);
    try testing.expectEqual(@as(usize, batch), events.len);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();

    var dispositions: usize = 0;
    var covered_first: ?u32 = null;
    var covered_last: ?u32 = null;
    for (frames.bodies.items) |body| {
        if (amqp.performative.peekDescriptor(body) != amqp.performative.descriptor.disposition) continue;
        dispositions += 1;
        var decoded = try amqp.performative.decode(allocator, body);
        defer decoded.deinit();
        const d = decoded.performative.disposition;
        try testing.expectEqual(amqp.performative.Role.receiver, d.role);
        try testing.expect(d.settled);
        try testing.expectEqual(amqp.performative.DeliveryState.accepted, d.state.?);
        covered_first = d.first;
        covered_last = d.last orelse d.first;
    }

    // Settling one at a time put a frame on the wire per event, so a 300-deep
    // prefetch cost 300 round trips of nothing but bookkeeping. AMQP 1.0
    // §2.6.10 lets one disposition cover a contiguous `first..last` run, which
    // is what every other client does.
    try testing.expectEqual(@as(usize, 1), dispositions);
    try testing.expectEqual(@as(u32, 0), covered_first.?);
    try testing.expectEqual(@as(u32, batch - 1), covered_last.?);
}

test "decoding a batch costs the same whatever the batch size" {
    // `decodeMessage` charges an arena and its pages per message, and the
    // receive loop discards each decode as soon as `fromRawMessage` has copied
    // out of it. Decoding into one client-owned arena, reset per event, makes
    // that cost fixed rather than per event.
    //
    // Assert exactly that — two batches of very different sizes cost the same
    // — rather than asserting a number. A number would pin the fixed cost
    // (the filter expression `receiveEvents` re-renders once per call) and
    // break for reasons that have nothing to do with this.
    const allocator = testing.allocator;
    var counting = CountingAllocator.init(allocator);

    const small = 4;
    const large = 36;

    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);
    var i: u32 = 0;
    while (i < small + small + large) : (i += 1) {
        try pushEvent(allocator, peer, i, @as(i64, i) + 1, "event");
    }

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    // Count only the client's own allocator. The events themselves are handed
    // back on `allocator` and are not what this is about.
    scripted.client.allocator = counting.allocator();

    // Warm: the arena is the client's, so the first batch is the one that
    // builds it and every batch after finds it sized.
    event_data.freeReceivedEvents(allocator, try scripted.client.receiveEvents(allocator, small));

    const a = counting.allocations;
    event_data.freeReceivedEvents(allocator, try scripted.client.receiveEvents(allocator, small));
    const cost_small = counting.allocations - a;

    const b = counting.allocations;
    const batch = try scripted.client.receiveEvents(allocator, large);
    defer event_data.freeReceivedEvents(allocator, batch);
    const cost_large = counting.allocations - b;

    try testing.expectEqual(@as(usize, large), batch.len);
    try testing.expectEqual(cost_small, cost_large);
}

test "one outsized event does not pin the decode arena" {
    // The decode arena is reused, so whatever it grows to it keeps. An Event
    // Hubs event may be up to a megabyte, and every partition holds a client,
    // so retaining outright would let one outlier pin that per partition for
    // as long as the consumer runs.
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const big = try allocator.alloc(u8, PartitionClient.decode_arena_limit + 64 * 1024);
    defer allocator.free(big);
    @memset(big, 'x');

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);
    // 300 bytes a frame, as a real one would arrive under a negotiated frame
    // size far smaller than the message.
    try pushChunkedEvent(allocator, peer, 0, 1, big, 300);
    try pushEvent(allocator, peer, 1, 2, "back to normal");

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    event_data.freeReceivedEvents(allocator, try scripted.client.receiveEvents(allocator, 1));
    const peak = scripted.client.decode_arena.?.queryCapacity();
    event_data.freeReceivedEvents(allocator, try scripted.client.receiveEvents(allocator, 1));
    const retained = scripted.client.decode_arena.?.queryCapacity();

    // Assert the size, not a symptom: the outlier really did exceed the cap,
    // and the ordinary event behind it really did give it back.
    try testing.expect(peak > PartitionClient.decode_arena_limit);
    try testing.expect(retained <= PartitionClient.decode_arena_limit);
}

test "a quiet partition returns the events that did arrive" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);
    try pushEvent(allocator, peer, 0, 5, "only");

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    // An exhausted script reads as end of stream by default, which is a
    // broken connection rather than a quiet one. Starve it instead, and let
    // the clock run so the deadline is what ends the wait.
    mem.starve = true;
    clock.auto_advance_ms = 1_000;

    // Asks for more than the peer will ever send.
    const events = try scripted.client.receiveEvents(allocator, 10);
    defer event_data.freeReceivedEvents(allocator, events);

    try testing.expectEqual(@as(usize, 1), events.len);
    try testing.expectEqualStrings("only", events[0].body());
}

test "a broken connection still hands back the events that arrived" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);
    try pushEvent(allocator, peer, 0, 1, "first");
    try pushEvent(allocator, peer, 1, 2, "second");

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    // A reset connection stops carrying traffic in both directions, so the
    // disposition that settles the batch cannot go out either. Asking for
    // more than the script holds runs the read failure and the failed
    // settlement together, which is what a consumer sees when a broker
    // recycles a node mid-batch.
    mem.fail_write = true;

    const events = try scripted.client.receiveEvents(allocator, 10);
    defer event_data.freeReceivedEvents(allocator, events);

    // Settling is advisory: unsettled deliveries are redelivered, and the
    // consumer resumes from the sequence number. Reporting the failed
    // disposition instead would throw away two events that did arrive.
    try testing.expectEqual(@as(usize, 2), events.len);
    try testing.expectEqualStrings("first", events[0].body());
    try testing.expectEqualStrings("second", events[1].body());
}

test "a settle write failing mid-batch costs no events either" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);
    // The gap at 2 is what another link on the session leaves behind. It
    // makes `SettleBatch.add` close the open run mid-loop, so the settle
    // write — and its failure — land inside the loop rather than after it.
    try pushEvent(allocator, peer, 0, 1, "first");
    try pushEvent(allocator, peer, 1, 2, "second");
    try pushEvent(allocator, peer, 3, 3, "third");

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    mem.fail_write = true;

    const events = try scripted.client.receiveEvents(allocator, 3);
    defer event_data.freeReceivedEvents(allocator, events);

    // The gap makes the settle write happen inside the loop rather than
    // after it, which is the other place it can fail. It must cost the
    // caller no more there than it does at the end.
    try testing.expectEqual(@as(usize, 3), events.len);
    try testing.expectEqualStrings("first", events[0].body());
    try testing.expectEqualStrings("third", events[2].body());
}

test "disabled prefetch issues credit per receive" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);
    try pushEvent(allocator, peer, 0, 1, "a");

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{ .prefetch = -1 });
    defer scripted.deinit();

    var attach = try sentAttach(allocator, &mem);
    defer attach.deinit();
    // Nothing was requested on attach, so no flow can have gone out yet.
    try testing.expectEqual(@as(u32, 0), scripted.client.receiver.credit);

    mem.clearWritten();
    const events = try scripted.client.receiveEvents(allocator, 1);
    defer event_data.freeReceivedEvents(allocator, events);
    try testing.expectEqual(@as(usize, 1), events.len);

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    var flows: usize = 0;
    for (frames.bodies.items) |body| {
        if (amqp.performative.peekDescriptor(body) == amqp.performative.descriptor.flow) flows += 1;
    }
    try testing.expect(flows >= 1);
}

test "receiveEvents rejects counts outside the credit window" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);

    var scripted: Scripted = undefined;
    try scripted.open(allocator, &mem, &clock, &conn, .{});
    defer scripted.deinit();

    try testing.expectError(
        ReceiveError.InvalidCount,
        scripted.client.receiveEvents(allocator, 0),
    );
    try testing.expectError(
        ReceiveError.InvalidCount,
        scripted.client.receiveEvents(allocator, max_credit + 1),
    );
}

test "prefetch above the credit window is rejected" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try harness.scriptHandshake(peer, 512);

    var fixture = try Fixture.init(allocator, &mem, &clock, &conn);
    defer fixture.deinit();

    var client: PartitionClient = undefined;
    try testing.expectError(ReceiveError.PrefetchTooLarge, client.open(allocator, &fixture.session, .{
        .source_address = test_source,
        .instance_id = test_instance,
        .deadline_ms = 10_000,
    }, .{ .prefetch = @as(i32, @intCast(max_credit)) + 1 }));
}

test "a pool reuses one link and resumes where it left off" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock = driver.ManualClock{};
    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();

    const peer = Peer{ .allocator = allocator, .mem = &mem };
    try scriptAttach(peer);
    try pushEvent(allocator, peer, 0, 20, "a");
    try pushEvent(allocator, peer, 1, 21, "b");

    var fixture = try Fixture.init(allocator, &mem, &clock, &conn);
    defer fixture.deinit();

    var pool = ReceiverPool.init(allocator, &fixture.session, .{
        .instance_id = test_instance,
        .deadline_ms = 10_000,
    });
    defer pool.deinit();

    mem.clearWritten();
    const first = try pool.receive(allocator, test_source, "amqp.annotation.x-opt-offset > '-1'", 1);
    defer event_data.freeReceivedEvents(allocator, first);
    try testing.expectEqual(@as(usize, 1), first.len);

    // The second call passes the original filter again; the pool must ignore
    // it and keep the position the first call advanced to.
    const second = try pool.receive(allocator, test_source, "amqp.annotation.x-opt-offset > '-1'", 1);
    defer event_data.freeReceivedEvents(allocator, second);
    try testing.expectEqualStrings("b", second[0].body());

    const client = try pool.clientFor(test_source, null);
    try testing.expectEqualStrings(
        "amqp.annotation.x-opt-sequence-number > '21'",
        client.filterExpression(),
    );

    var frames = try EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    var attaches: usize = 0;
    for (frames.bodies.items) |body| {
        if (amqp.performative.peekDescriptor(body) == amqp.performative.descriptor.attach) attaches += 1;
    }
    try testing.expectEqual(@as(usize, 1), attaches);
}

/// Counts allocations so a test can assert that a code path performs none.
const CountingAllocator = struct {
    parent: Allocator,
    allocations: usize = 0,

    fn init(parent: Allocator) CountingAllocator {
        return .{ .parent = parent };
    }

    fn allocator(self: *CountingAllocator) Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.allocations += 1;
        return self.parent.rawAlloc(len, alignment, ra);
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(buf, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const out = self.parent.rawRemap(buf, alignment, new_len, ra);
        // Only a move is a new allocation; growing in place is not.
        if (out) |p| if (p != buf.ptr) {
            self.allocations += 1;
        };
        return out;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(buf, alignment, ra);
    }
};
