//! Event Hub and partition metadata over the `$management` link.
//!
//! Both operations are a `READ` against the hub, distinguished by the entity
//! type: `com.microsoft:eventhub` returns the hub's partition list, and
//! `com.microsoft:partition` returns one partition's sequence number range.
//! The reply arrives as an AMQP map in the message value body.
//!
//! The wire names here are taken from the Go SDK's `mgmt.go` and match Rust's
//! `common/management.rs`. They are not guessable — the partition reply calls
//! the hub `name` and the partition `partition`, the first sequence number is
//! `begin_sequence_number` rather than `beginning_`, and geo-replication is
//! reported as a *factor* that the client turns into a boolean.

const std = @import("std");
const amqp = @import("azure_sdk_amqp");
const uamqp = @import("uamqp");
const errors = @import("errors.zig");

const Allocator = std.mem.Allocator;
const AmqpValue = uamqp.AmqpValue;
const MapEntry = uamqp.MapEntry;

/// The entity type for hub-wide metadata.
pub const entity_type_eventhub = "com.microsoft:eventhub";
/// The entity type for a single partition's metadata.
pub const entity_type_partition = "com.microsoft:partition";

/// The request property naming the partition, alongside the standard four.
pub const partition_key = "partition";

/// Reply property names. The hub and partition replies overlap on `name`,
/// which means the hub in both.
pub const reply = struct {
    pub const name = "name";
    pub const partition_ids = "partition_ids";
    pub const created_at = "created_at";
    /// A count, not a flag: greater than one means geo-replication is on.
    pub const georeplication_factor = "georeplication_factor";
    pub const partition = "partition";
    pub const begin_sequence_number = "begin_sequence_number";
    pub const last_enqueued_sequence_number = "last_enqueued_sequence_number";
    pub const last_enqueued_offset = "last_enqueued_offset";
    pub const last_enqueued_time_utc = "last_enqueued_time_utc";
    pub const is_partition_empty = "is_partition_empty";
};

pub const PropertiesError = amqp.ManagementError || error{
    /// The reply body was not an AMQP map.
    MalformedReplyBody,
    /// The reply omitted a property the operation is defined to return.
    MissingProperty,
    /// A property was present but not of the expected type.
    InvalidProperty,
};

/// Properties of an Event Hub.
///
/// Strings are owned by `arena` when one is set, which is the case for
/// anything decoded from the service. A value built by hand — the mock
/// transport, or a test — leaves it null and borrows instead, so `deinit` is
/// always safe to call and always correct.
pub const EventHubProperties = struct {
    name: []const u8,
    partition_ids: []const []const u8 = &.{},
    /// Milliseconds since the Unix epoch, as AMQP timestamps are defined.
    created_on: ?i64 = null,
    /// True when the namespace has geo-replication enabled, which the service
    /// reports as a geo-replication factor greater than one.
    geo_replication_enabled: bool = false,
    arena: ?*std.heap.ArenaAllocator = null,

    pub fn deinit(self: *EventHubProperties) void {
        releaseArena(&self.arena);
    }
};

/// Properties of one partition of an Event Hub.
pub const PartitionProperties = struct {
    id: []const u8,
    /// Name of the Event Hub the partition belongs to.
    event_hub_name: []const u8 = "",
    beginning_sequence_number: i64 = 0,
    last_enqueued_sequence_number: i64 = 0,
    last_enqueued_offset: ?[]const u8 = null,
    /// Milliseconds since the Unix epoch.
    last_enqueued_time: ?i64 = null,
    is_empty: bool = true,
    arena: ?*std.heap.ArenaAllocator = null,

    pub fn deinit(self: *PartitionProperties) void {
        releaseArena(&self.arena);
    }
};

fn releaseArena(slot: *?*std.heap.ArenaAllocator) void {
    if (slot.*) |arena| {
        const parent = arena.child_allocator;
        arena.deinit();
        parent.destroy(arena);
    }
    slot.* = null;
}

fn newArena(allocator: Allocator) !*std.heap.ArenaAllocator {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = .init(allocator);
    return arena;
}

// ─────────────────────── Operations ───────────────────────

/// Read the hub's metadata.
///
/// `security_token` is the CBS token for the hub audience. Event Hubs wants it
/// on the message as well as on the link, which is why it is a parameter here
/// rather than something the management client remembers.
pub fn getEventHubProperties(
    allocator: Allocator,
    mgmt: *amqp.Management,
    hub_name: []const u8,
    security_token: ?[]const u8,
    deadline_ms: i64,
) PropertiesError!EventHubProperties {
    var response = try mgmt.call(.{
        .entity_type = entity_type_eventhub,
        .name = hub_name,
        .security_token = security_token,
    }, deadline_ms);
    defer response.deinit();

    return parseEventHubProperties(allocator, response.msg().body);
}

/// Read one partition's metadata.
pub fn getPartitionProperties(
    allocator: Allocator,
    mgmt: *amqp.Management,
    hub_name: []const u8,
    partition_id: []const u8,
    security_token: ?[]const u8,
    deadline_ms: i64,
) PropertiesError!PartitionProperties {
    const extra = [_]MapEntry{.{
        .key = .{ .string = partition_key },
        .value = .{ .string = partition_id },
    }};

    var response = try mgmt.call(.{
        .entity_type = entity_type_partition,
        .name = hub_name,
        .security_token = security_token,
        .properties = &extra,
    }, deadline_ms);
    defer response.deinit();

    return parsePartitionProperties(allocator, response.msg().body);
}

// ─────────────────────── Reply decoding ───────────────────────

pub fn parseEventHubProperties(
    allocator: Allocator,
    body: amqp.MessageBody,
) PropertiesError!EventHubProperties {
    const map = try bodyMap(body);

    const arena = try newArena(allocator);
    errdefer {
        var slot: ?*std.heap.ArenaAllocator = arena;
        releaseArena(&slot);
    }
    const arena_allocator = arena.allocator();

    const name = try arena_allocator.dupe(u8, try requireString(map, reply.name));
    const ids = try dupeStringArray(arena_allocator, map, reply.partition_ids);

    // Go rejects a reply with no factor. A broker that predates
    // geo-replication simply omits it, so treat absence as disabled rather
    // than as a malformed reply.
    const factor = if (lookup(map, reply.georeplication_factor)) |value|
        asInt(value) orelse return error.InvalidProperty
    else
        0;

    return .{
        .name = name,
        .partition_ids = ids,
        .created_on = if (lookup(map, reply.created_at)) |value|
            asTimestamp(value) orelse return error.InvalidProperty
        else
            null,
        .geo_replication_enabled = factor > 1,
        .arena = arena,
    };
}

pub fn parsePartitionProperties(
    allocator: Allocator,
    body: amqp.MessageBody,
) PropertiesError!PartitionProperties {
    const map = try bodyMap(body);

    const arena = try newArena(allocator);
    errdefer {
        var slot: ?*std.heap.ArenaAllocator = arena;
        releaseArena(&slot);
    }
    const arena_allocator = arena.allocator();

    const hub = try arena_allocator.dupe(u8, try requireString(map, reply.name));
    const id = try arena_allocator.dupe(u8, try requireString(map, reply.partition));

    const offset = if (lookup(map, reply.last_enqueued_offset)) |value|
        try arena_allocator.dupe(u8, asString(value) orelse return error.InvalidProperty)
    else
        null;

    return .{
        .id = id,
        .event_hub_name = hub,
        .beginning_sequence_number = try requireInt(map, reply.begin_sequence_number),
        .last_enqueued_sequence_number = try requireInt(map, reply.last_enqueued_sequence_number),
        .last_enqueued_offset = offset,
        .last_enqueued_time = if (lookup(map, reply.last_enqueued_time_utc)) |value|
            asTimestamp(value) orelse return error.InvalidProperty
        else
            null,
        // A partition that has never been written to may omit the flag; an
        // empty partition is the safe reading of a missing one.
        .is_empty = if (lookup(map, reply.is_partition_empty)) |value|
            asBool(value) orelse return error.InvalidProperty
        else
            true,
        .arena = arena,
    };
}

fn bodyMap(body: amqp.MessageBody) PropertiesError![]const MapEntry {
    return switch (body) {
        .value => |value| switch (value) {
            .map => |entries| entries,
            else => error.MalformedReplyBody,
        },
        else => error.MalformedReplyBody,
    };
}

/// Look a key up in an AMQP map. Keys arrive as strings from Event Hubs, but
/// symbols are accepted because they are the same thing on the wire to a
/// broker that chooses to encode them that way.
fn lookup(map: []const MapEntry, key: []const u8) ?AmqpValue {
    for (map) |entry| {
        const entry_key = switch (entry.key) {
            .string, .symbol => |s| s,
            else => continue,
        };
        if (std.mem.eql(u8, entry_key, key)) return entry.value;
    }
    return null;
}

fn asString(value: AmqpValue) ?[]const u8 {
    return switch (value) {
        .string, .symbol => |s| s,
        else => null,
    };
}

/// Widen any integral encoding to `i64`.
///
/// The service is free to pick the smallest encoding that fits, so a sequence
/// number that happens to be small arrives as a `byte` or `int` rather than a
/// `long`. Go's `ConvertToInt64` exists for exactly this.
fn asInt(value: AmqpValue) ?i64 {
    return switch (value) {
        .byte => |v| v,
        .short => |v| v,
        .int => |v| v,
        .long => |v| v,
        .ubyte => |v| v,
        .ushort => |v| v,
        .uint => |v| v,
        .ulong => |v| std.math.cast(i64, v),
        else => null,
    };
}

/// A timestamp, or any integral standing in for one. Both are milliseconds
/// since the Unix epoch.
fn asTimestamp(value: AmqpValue) ?i64 {
    return switch (value) {
        .timestamp => |v| v,
        else => asInt(value),
    };
}

fn asBool(value: AmqpValue) ?bool {
    return switch (value) {
        .boolean => |v| v,
        else => null,
    };
}

fn requireString(map: []const MapEntry, key: []const u8) PropertiesError![]const u8 {
    const value = lookup(map, key) orelse return error.MissingProperty;
    return asString(value) orelse error.InvalidProperty;
}

fn requireInt(map: []const MapEntry, key: []const u8) PropertiesError!i64 {
    const value = lookup(map, key) orelse return error.MissingProperty;
    return asInt(value) orelse error.InvalidProperty;
}

/// Copy an array of strings out of a reply.
///
/// Event Hubs sends `partition_ids` as an AMQP array, but a list of the same
/// strings is indistinguishable to a caller and some brokers send one, so both
/// are accepted.
fn dupeStringArray(
    arena: Allocator,
    map: []const MapEntry,
    key: []const u8,
) PropertiesError![]const []const u8 {
    const value = lookup(map, key) orelse return error.MissingProperty;
    const items = switch (value) {
        .array, .list => |items| items,
        else => return error.InvalidProperty,
    };

    const out = try arena.alloc([]const u8, items.len);
    for (items, 0..) |item, i| {
        out[i] = try arena.dupe(u8, asString(item) orelse return error.InvalidProperty);
    }
    return out;
}

// ─────────────────────── Retry ───────────────────────

/// Run `getEventHubProperties` under the Event Hubs retry schedule.
///
/// A management call goes over a link, so a transient detach or a
/// `com.microsoft:server-busy` has to be retried rather than surfaced. The
/// broker's condition is handed to the retrier so it can tell a retryable
/// failure from a fatal one.
pub fn getEventHubPropertiesWithRetry(
    allocator: Allocator,
    mgmt: *amqp.Management,
    hub_name: []const u8,
    security_token: ?[]const u8,
    deadline_ms: i64,
    config: errors.RetryConfig,
) errors.Outcome(EventHubProperties) {
    const Op = struct {
        allocator: Allocator,
        mgmt: *amqp.Management,
        hub_name: []const u8,
        security_token: ?[]const u8,
        deadline_ms: i64,

        pub fn call(self: *const @This(), attempt: *errors.Attempt) anyerror!EventHubProperties {
            return getEventHubProperties(
                self.allocator,
                self.mgmt,
                self.hub_name,
                self.security_token,
                self.deadline_ms,
            ) catch |e| {
                recordCondition(self.mgmt, attempt);
                return e;
            };
        }
    };

    const op = Op{
        .allocator = allocator,
        .mgmt = mgmt,
        .hub_name = hub_name,
        .security_token = security_token,
        .deadline_ms = deadline_ms,
    };
    return errors.retry(EventHubProperties, &op, config);
}

/// Run `getPartitionProperties` under the Event Hubs retry schedule.
pub fn getPartitionPropertiesWithRetry(
    allocator: Allocator,
    mgmt: *amqp.Management,
    hub_name: []const u8,
    partition_id: []const u8,
    security_token: ?[]const u8,
    deadline_ms: i64,
    config: errors.RetryConfig,
) errors.Outcome(PartitionProperties) {
    const Op = struct {
        allocator: Allocator,
        mgmt: *amqp.Management,
        hub_name: []const u8,
        partition_id: []const u8,
        security_token: ?[]const u8,
        deadline_ms: i64,

        pub fn call(self: *const @This(), attempt: *errors.Attempt) anyerror!PartitionProperties {
            return getPartitionProperties(
                self.allocator,
                self.mgmt,
                self.hub_name,
                self.partition_id,
                self.security_token,
                self.deadline_ms,
            ) catch |e| {
                recordCondition(self.mgmt, attempt);
                return e;
            };
        }
    };

    const op = Op{
        .allocator = allocator,
        .mgmt = mgmt,
        .hub_name = hub_name,
        .partition_id = partition_id,
        .security_token = security_token,
        .deadline_ms = deadline_ms,
    };
    return errors.retry(PartitionProperties, &op, config);
}

/// Translate the broker's reply into the AMQP condition the retrier
/// classifies on.
///
/// A management failure carries an HTTP-shaped status code rather than an AMQP
/// error condition, so the mapping has to be made explicitly. Go does the same
/// in `TransformError`.
fn recordCondition(mgmt: *amqp.Management, attempt: *errors.Attempt) void {
    const status = mgmt.last_error orelse return;
    attempt.description = status.description;
    attempt.condition = switch (status.code) {
        401, 403 => errors.condition.unauthorized_access,
        404 => errors.condition.not_found,
        408 => errors.condition.timeout,
        429, 503 => errors.condition.server_busy,
        else => if (status.code >= 500)
            errors.condition.internal_error
        else
            errors.condition.not_allowed,
    };
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;
const harness = amqp.test_peer;
const Peer = harness.Peer;
const Fixture = harness.Fixture;
const EmittedFrames = harness.EmittedFrames;
const MemoryTransport = amqp.MemoryTransport;
const driver = amqp.connection_driver;

fn mapEntry(key: []const u8, value: AmqpValue) MapEntry {
    return .{ .key = .{ .string = key }, .value = value };
}

test "an event hub reply decodes into fully populated properties" {
    const allocator = testing.allocator;
    var ids = [_]AmqpValue{
        .{ .string = "0" },
        .{ .string = "1" },
        .{ .string = "2" },
    };
    var map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "my-hub" }),
        mapEntry(reply.partition_ids, .{ .array = &ids }),
        mapEntry(reply.created_at, .{ .timestamp = 1_700_000_000_000 }),
        mapEntry(reply.georeplication_factor, .{ .int = 2 }),
    };

    var props = try parseEventHubProperties(allocator, .{ .value = .{ .map = &map } });
    defer props.deinit();

    try testing.expectEqualStrings("my-hub", props.name);
    try testing.expectEqual(@as(usize, 3), props.partition_ids.len);
    try testing.expectEqualStrings("0", props.partition_ids[0]);
    try testing.expectEqualStrings("2", props.partition_ids[2]);
    try testing.expectEqual(@as(?i64, 1_700_000_000_000), props.created_on);
    try testing.expect(props.geo_replication_enabled);
}

test "a geo-replication factor of one is not geo-replication" {
    const allocator = testing.allocator;
    var ids = [_]AmqpValue{.{ .string = "0" }};
    var map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "hub" }),
        mapEntry(reply.partition_ids, .{ .array = &ids }),
        mapEntry(reply.georeplication_factor, .{ .int = 1 }),
    };

    var props = try parseEventHubProperties(allocator, .{ .value = .{ .map = &map } });
    defer props.deinit();
    try testing.expect(!props.geo_replication_enabled);
}

test "a reply with no geo-replication factor is not malformed" {
    const allocator = testing.allocator;
    var ids = [_]AmqpValue{.{ .string = "0" }};
    var map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "hub" }),
        mapEntry(reply.partition_ids, .{ .array = &ids }),
    };

    var props = try parseEventHubProperties(allocator, .{ .value = .{ .map = &map } });
    defer props.deinit();
    try testing.expect(!props.geo_replication_enabled);
    try testing.expectEqual(@as(?i64, null), props.created_on);
}

test "partition ids may arrive as a list rather than an array" {
    const allocator = testing.allocator;
    var ids = [_]AmqpValue{ .{ .string = "0" }, .{ .string = "1" } };
    var map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "hub" }),
        mapEntry(reply.partition_ids, .{ .list = &ids }),
    };

    var props = try parseEventHubProperties(allocator, .{ .value = .{ .map = &map } });
    defer props.deinit();
    try testing.expectEqual(@as(usize, 2), props.partition_ids.len);
    try testing.expectEqualStrings("1", props.partition_ids[1]);
}

test "a partition reply decodes into fully populated properties" {
    const allocator = testing.allocator;
    var map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "my-hub" }),
        mapEntry(reply.partition, .{ .string = "3" }),
        mapEntry(reply.begin_sequence_number, .{ .long = 100 }),
        mapEntry(reply.last_enqueued_sequence_number, .{ .long = 4096 }),
        mapEntry(reply.last_enqueued_offset, .{ .string = "12345" }),
        mapEntry(reply.last_enqueued_time_utc, .{ .timestamp = 1_700_000_000_000 }),
        mapEntry(reply.is_partition_empty, .{ .boolean = false }),
    };

    var props = try parsePartitionProperties(allocator, .{ .value = .{ .map = &map } });
    defer props.deinit();

    try testing.expectEqualStrings("3", props.id);
    try testing.expectEqualStrings("my-hub", props.event_hub_name);
    try testing.expectEqual(@as(i64, 100), props.beginning_sequence_number);
    try testing.expectEqual(@as(i64, 4096), props.last_enqueued_sequence_number);
    try testing.expectEqualStrings("12345", props.last_enqueued_offset.?);
    try testing.expectEqual(@as(?i64, 1_700_000_000_000), props.last_enqueued_time);
    try testing.expect(!props.is_empty);
}

test "sequence numbers widen from whatever encoding the service chose" {
    const allocator = testing.allocator;
    // A partition that has just been created reports small numbers, which the
    // service is free to encode as a byte.
    var map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "hub" }),
        mapEntry(reply.partition, .{ .string = "0" }),
        mapEntry(reply.begin_sequence_number, .{ .byte = 0 }),
        mapEntry(reply.last_enqueued_sequence_number, .{ .int = 7 }),
        mapEntry(reply.is_partition_empty, .{ .boolean = true }),
    };

    var props = try parsePartitionProperties(allocator, .{ .value = .{ .map = &map } });
    defer props.deinit();
    try testing.expectEqual(@as(i64, 0), props.beginning_sequence_number);
    try testing.expectEqual(@as(i64, 7), props.last_enqueued_sequence_number);
    try testing.expect(props.is_empty);
    try testing.expectEqual(@as(?[]const u8, null), props.last_enqueued_offset);
}

test "a reply missing a required property is rejected" {
    const allocator = testing.allocator;
    var map = [_]MapEntry{mapEntry(reply.name, .{ .string = "hub" })};
    try testing.expectError(
        error.MissingProperty,
        parseEventHubProperties(allocator, .{ .value = .{ .map = &map } }),
    );

    var partition_map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "hub" }),
        mapEntry(reply.partition, .{ .string = "0" }),
    };
    try testing.expectError(
        error.MissingProperty,
        parsePartitionProperties(allocator, .{ .value = .{ .map = &partition_map } }),
    );
}

test "a reply whose body is not a map is rejected" {
    const allocator = testing.allocator;
    try testing.expectError(
        error.MalformedReplyBody,
        parseEventHubProperties(allocator, .{ .data = &.{"not a map"} }),
    );
    try testing.expectError(
        error.MalformedReplyBody,
        parsePartitionProperties(allocator, .empty),
    );
}

test "properties built by hand carry no arena and free cleanly" {
    var props = EventHubProperties{ .name = "borrowed" };
    props.deinit();
    props.deinit();
    try testing.expectEqualStrings("borrowed", props.name);
}

// ─────────────── Scripted-peer tests ───────────────

/// Script the peer's side of attaching a `$management` link pair.
fn scriptAttach(peer: Peer, credit: u32) !void {
    try harness.scriptHandshake(peer, 65536);
    try peer.push(0, .{ .attach = .{
        .name = "$management-sender-eh",
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .attach = .{
        .name = "$management-receiver-eh",
        .handle = 1,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = credit,
    } });
}

/// The request the client sent as delivery `n - 1` is settled by the peer.
fn scriptSettle(peer: Peer, n: u64) !void {
    const delivery_id: u32 = @intCast(n - 1);
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = delivery_id,
        .last = delivery_id,
        .settled = true,
        .state = .accepted,
    } });
}

/// Push a reply to request `n` carrying `body`.
fn scriptReply(
    peer: Peer,
    allocator: Allocator,
    n: u64,
    status: i32,
    description: []const u8,
    body: amqp.MessageBody,
    delivery_id: u32,
) !void {
    var id_buf: [64]u8 = undefined;
    const correlation = try std.fmt.bufPrint(&id_buf, "management-reply-to-eh:{d}", .{n});
    const props = [_]MapEntry{
        .{ .key = .{ .string = amqp.rpc.status_code_key }, .value = .{ .int = status } },
        .{
            .key = .{ .string = amqp.rpc.status_description_key },
            .value = .{ .string = description },
        },
    };
    const payload = try amqp.encodeMessageAlloc(allocator, .{
        .properties = .{ .correlation_id = .{ .string = correlation } },
        .application_properties = &props,
        .body = body,
    });
    defer allocator.free(payload);

    try peer.pushTransfer(0, .{
        .handle = 1,
        .delivery_id = delivery_id,
        .delivery_tag = "r",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, payload);
}

fn propertyValue(props: []const MapEntry, key: []const u8) ?AmqpValue {
    return lookup(props, key);
}

/// A driver, session, and management client wired to a scripted peer.
const Scripted = struct {
    allocator: Allocator,
    mem: *MemoryTransport,
    clock: *driver.ManualClock,
    conn: *driver.Driver,
    fixture: Fixture,
    client: *amqp.Management,

    fn init(allocator: Allocator, mem: *MemoryTransport, clock: *driver.ManualClock, conn: *driver.Driver) !Scripted {
        var fixture = try Fixture.init(allocator, mem, clock, conn);
        errdefer fixture.deinit();
        const client = try amqp.Management.open(&fixture.session, .{ .link_id = "eh" }, 10_000);
        return .{
            .allocator = allocator,
            .mem = mem,
            .clock = clock,
            .conn = conn,
            .fixture = fixture,
            .client = client,
        };
    }

    fn deinit(self: *Scripted) void {
        self.client.deinit();
        self.fixture.deinit();
    }

    /// The application properties of the single request written since the last
    /// `clearWritten`.
    fn sentProperties(self: *Scripted, decoded: *amqp.message_codec.Decoded) ![]const MapEntry {
        var frames = try EmittedFrames.parse(self.allocator, self.mem.written());
        defer frames.deinit();
        const transfers = try frames.of(self.allocator, 0x14);
        defer self.allocator.free(transfers);
        try testing.expectEqual(@as(usize, 1), transfers.len);

        decoded.* = try amqp.decodeMessage(
            self.allocator,
            harness.transferPayload(self.allocator, transfers[0]).?,
        );
        return decoded.message.application_properties.?;
    }
};

test "an event hub read puts the exact application properties on the wire" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    var ids = [_]AmqpValue{ .{ .string = "0" }, .{ .string = "1" } };
    // A list rather than an array: uamqp's array encoder writes a wrong
    // length prefix (cataggar/azure-uamqp-zig), so an array cannot yet make
    // the round trip through a real frame. Decoding an array is covered
    // directly above.
    var body_map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "my-hub" }),
        mapEntry(reply.partition_ids, .{ .list = &ids }),
        mapEntry(reply.created_at, .{ .timestamp = 1_700_000_000_000 }),
        mapEntry(reply.georeplication_factor, .{ .int = 3 }),
    };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);
    try scriptReply(peer, allocator, 1, 200, "OK", .{ .value = .{ .map = &body_map } }, 0);

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted = try Scripted.init(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    mem.clearWritten();
    var props = try getEventHubProperties(
        allocator,
        scripted.client,
        "my-hub",
        "SharedAccessSignature sr=x&sig=y",
        10_000,
    );
    defer props.deinit();

    var decoded: amqp.message_codec.Decoded = undefined;
    const sent = try scripted.sentProperties(&decoded);
    defer decoded.deinit();

    try testing.expectEqualStrings("READ", propertyValue(sent, "operation").?.string);
    try testing.expectEqualStrings(entity_type_eventhub, propertyValue(sent, "type").?.string);
    try testing.expectEqualStrings("my-hub", propertyValue(sent, "name").?.string);
    try testing.expectEqualStrings(
        "SharedAccessSignature sr=x&sig=y",
        propertyValue(sent, "security_token").?.string,
    );
    // A hub read must not name a partition, or the broker answers the
    // partition operation instead.
    try testing.expect(propertyValue(sent, partition_key) == null);

    try testing.expectEqualStrings("my-hub", props.name);
    try testing.expectEqual(@as(usize, 2), props.partition_ids.len);
    try testing.expect(props.geo_replication_enabled);
}

test "a partition read names the partition and uses the partition entity type" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    var body_map = [_]MapEntry{
        mapEntry(reply.name, .{ .string = "my-hub" }),
        mapEntry(reply.partition, .{ .string = "3" }),
        mapEntry(reply.begin_sequence_number, .{ .long = 5 }),
        mapEntry(reply.last_enqueued_sequence_number, .{ .long = 99 }),
        mapEntry(reply.last_enqueued_offset, .{ .string = "4242" }),
        mapEntry(reply.last_enqueued_time_utc, .{ .timestamp = 1_700_000_000_000 }),
        mapEntry(reply.is_partition_empty, .{ .boolean = false }),
    };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);
    try scriptReply(peer, allocator, 1, 200, "OK", .{ .value = .{ .map = &body_map } }, 0);

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted = try Scripted.init(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    mem.clearWritten();
    var props = try getPartitionProperties(allocator, scripted.client, "my-hub", "3", "token", 10_000);
    defer props.deinit();

    var decoded: amqp.message_codec.Decoded = undefined;
    const sent = try scripted.sentProperties(&decoded);
    defer decoded.deinit();

    try testing.expectEqualStrings("READ", propertyValue(sent, "operation").?.string);
    try testing.expectEqualStrings(entity_type_partition, propertyValue(sent, "type").?.string);
    // `name` is the hub, not the partition — the partition goes in its own
    // property. Swapping them is the obvious mistake and the broker answers
    // with a not-found rather than an error that says so.
    try testing.expectEqualStrings("my-hub", propertyValue(sent, "name").?.string);
    try testing.expectEqualStrings("3", propertyValue(sent, partition_key).?.string);
    try testing.expectEqualStrings("token", propertyValue(sent, "security_token").?.string);

    try testing.expectEqualStrings("3", props.id);
    try testing.expectEqualStrings("my-hub", props.event_hub_name);
    try testing.expectEqual(@as(i64, 5), props.beginning_sequence_number);
    try testing.expectEqualStrings("4242", props.last_enqueued_offset.?);
}

test "a management error status surfaces with the broker's description" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);
    try scriptReply(peer, allocator, 1, 404, "The messaging entity could not be found.", .empty, 0);

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted = try Scripted.init(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    try testing.expectError(
        error.RequestFailed,
        getEventHubProperties(allocator, scripted.client, "missing-hub", null, 10_000),
    );

    // A Zig error carries no payload, so the status and description are read
    // back off the client.
    const status = scripted.client.last_error.?;
    try testing.expectEqual(@as(i32, 404), status.code);
    try testing.expectEqualStrings("The messaging entity could not be found.", status.description.?);
}

test "a not-found status is classified as fatal rather than retried" {
    const allocator = testing.allocator;
    var mem = MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: driver.ManualClock = .{};
    const peer = Peer{ .allocator = allocator, .mem = &mem };

    try scriptAttach(peer, 10);
    try scriptSettle(peer, 1);
    try scriptReply(peer, allocator, 1, 404, "not found", .empty, 0);

    var conn = try driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var scripted = try Scripted.init(allocator, &mem, &clock, &conn);
    defer scripted.deinit();

    // A no-op sleeper: a fatal failure must not reach a backoff at all, so any
    // sleep here would be a bug.
    var sleeper = errors.Sleeper{ .sleepFn = &struct {
        fn noSleep(_: *errors.Sleeper, _: u64) errors.SleepError!void {
            return error.Canceled;
        }
    }.noSleep };
    var prng = std.Random.DefaultPrng.init(0);

    const outcome = getEventHubPropertiesWithRetry(
        allocator,
        scripted.client,
        "missing-hub",
        null,
        10_000,
        .{ .sleeper = &sleeper, .random = prng.random() },
    );

    switch (outcome) {
        .ok => |props| {
            var owned = props;
            owned.deinit();
            return error.TestUnexpectedResult;
        },
        .failed => |failure| {
            // One attempt: 404 maps to `amqp:not-found`, which is fatal, so
            // the retrier stopped immediately rather than backing off.
            try testing.expectEqual(@as(u32, 1), failure.attempts);
            try testing.expectEqualStrings(errors.condition.not_found, failure.info.amqp_condition.?);
            try testing.expectEqualStrings("not found", failure.info.description.?);
        },
    }
}
