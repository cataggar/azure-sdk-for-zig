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
        errdefer {
            for (events.items) |*e| e.deinit(allocator);
            events.deinit(allocator);
        }

        while (events.items.len < count) {
            const delivery = self.receiver.receive(self.deadline_ms) catch |err| {
                self.recordDetach();
                // Events already in hand are still valid; a quiet partition is
                // not a failure. Anything else with nothing to show is.
                if (events.items.len > 0 and err == error.Timeout) break;
                return err;
            };

            var decoded = try amqp.decodeMessage(allocator, delivery.payload);
            defer decoded.deinit();

            const received = try event_data.fromRawMessage(allocator, rawFrom(&decoded.message));
            errdefer {
                var owned = received;
                owned.deinit(allocator);
            }

            try events.append(allocator, received);
            try self.receiver.accept(delivery);
        }

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
        var it = self.clients.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.clients.deinit(self.allocator);
    }

    /// The client for `source_address`, attaching one if this is the first
    /// call. `filter_expression` applies only to a first attach.
    pub fn clientFor(
        self: *ReceiverPool,
        source_address: []const u8,
        filter_expression: ?[]const u8,
    ) !*PartitionClient {
        if (self.clients.get(source_address)) |existing| return existing;

        const client = try self.allocator.create(PartitionClient);
        errdefer self.allocator.destroy(client);
        try client.open(self.allocator, self.session, .{
            .source_address = source_address,
            .instance_id = self.instance_id,
            .deadline_ms = self.deadline_ms,
            .filter_expression = filter_expression,
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
