///! Azure Event Hubs client — producer and consumer.
///!
///! Built on top of azure-sdk-core-amqp.
const std = @import("std");
const core = @import("azure_sdk_core");
const uamqp = @import("uamqp");
const messaging_common = @import("azure_sdk_messaging_common");
const checkpoint = @import("checkpoint.zig");
const event_data = @import("event_data.zig");

pub const ConnectionStringProperties = messaging_common.ConnectionStringProperties;
pub const Checkpoint = checkpoint.Checkpoint;
pub const PartitionOwnership = checkpoint.PartitionOwnership;
pub const CheckpointStore = checkpoint.CheckpointStore;
pub const freeCheckpoints = checkpoint.freeCheckpoints;
pub const freeOwnerships = checkpoint.freeOwnerships;
pub const checkpoint_store_blob = @import("checkpoint_store.zig");

pub const AmqpValue = event_data.AmqpValue;
pub const EventData = event_data.EventData;
pub const ReceivedEventData = event_data.ReceivedEventData;
pub const MessageId = event_data.MessageId;
pub const PropertyMap = event_data.PropertyMap;
pub const ConversionError = event_data.ConversionError;
pub const PropertyError = event_data.PropertyError;
pub const freeReceivedEvents = event_data.freeReceivedEvents;
pub const freeAmqpMessage = event_data.freeAmqpMessage;
pub const freeDecodedMessage = event_data.freeDecodedMessage;
pub const fromAmqpMessage = event_data.fromAmqpMessage;
pub const fromOwnedAmqpMessage = event_data.fromOwnedAmqpMessage;

// ─────────────────────── Models ───────────────────────

/// AMQP message format identifying an Event Hubs batch transfer.
pub const batch_message_format: u32 = 0x80013700;

/// Size assumed before a sender link negotiates `max-message-size`. Event Hubs
/// standard tiers allow 1 MiB.
pub const default_max_message_size: usize = 1024 * 1024;

pub const BatchError = error{
    /// A batch targets either a partition or a partition key, never both.
    PartitionKeyAndIdBothSet,
    /// The event cannot fit an empty batch, so no batch size would accept it.
    EventDataTooLarge,
    /// The requested `max_bytes` is above what the sender link negotiated.
    MaxBytesExceedsLinkLimit,
    /// The link limit can only be adopted before events are added.
    BatchNotEmpty,
};

pub const EventDataBatchOptions = struct {
    /// Upper bound on the encoded batch size. Defaults to the sender link's
    /// negotiated maximum, or `default_max_message_size` until one exists.
    max_bytes: ?usize = null,
    /// Route related events to one partition by hash. Mutually exclusive with
    /// `partition_id`.
    partition_key: ?[]const u8 = null,
    /// Send to an explicit partition. Mutually exclusive with `partition_key`.
    partition_id: ?[]const u8 = null,
};

/// Packs events into a single AMQP batch transfer.
///
/// Events are encoded as they are added and the batch tracks the real byte
/// count, so a batch that reports as fitting actually fits. Go and Rust both
/// work this way; estimating from body length under-counts properties,
/// annotations, and per-message framing.
pub const EventDataBatch = struct {
    /// Fully encoded sub-messages, each of which becomes one data section of
    /// the batch transfer.
    marshaled: std.ArrayList([]u8) = .empty,
    /// Encoded non-body sections of the first event, which become the batch
    /// envelope. Go reuses the first message this way.
    envelope: ?[]u8 = null,
    max_size_bytes: usize = default_max_message_size,
    current_size: usize = 0,
    partition_key: ?[]const u8 = null,
    partition_id: ?[]const u8 = null,
    /// Set when the caller pinned `max_bytes`, so a link cannot raise it.
    requested_max_bytes: ?usize = null,

    pub fn init(options: EventDataBatchOptions) BatchError!EventDataBatch {
        if (options.partition_key != null and options.partition_id != null) {
            return BatchError.PartitionKeyAndIdBothSet;
        }
        return .{
            .max_size_bytes = options.max_bytes orelse default_max_message_size,
            .partition_key = options.partition_key,
            .partition_id = options.partition_id,
            .requested_max_bytes = options.max_bytes,
        };
    }

    pub fn deinit(self: *EventDataBatch, allocator: std.mem.Allocator) void {
        for (self.marshaled.items) |encoded| allocator.free(encoded);
        self.marshaled.deinit(allocator);
        if (self.envelope) |envelope| allocator.free(envelope);
        self.envelope = null;
        self.current_size = 0;
    }

    /// Adopt the `max-message-size` a sender link negotiated.
    ///
    /// An explicitly requested `max_bytes` is kept when it is smaller and
    /// rejected when it exceeds what the link allows, matching Go.
    pub fn applyLinkMaxMessageSize(
        self: *EventDataBatch,
        link_max_bytes: usize,
    ) BatchError!void {
        if (self.marshaled.items.len > 0) return BatchError.BatchNotEmpty;
        if (self.requested_max_bytes) |requested| {
            if (requested > link_max_bytes) return BatchError.MaxBytesExceedsLinkLimit;
            return;
        }
        self.max_size_bytes = link_max_bytes;
    }

    /// Encode `event` and add it if the batch still has room.
    ///
    /// Returns `false` when the event does not fit alongside what is already
    /// batched, and `BatchError.EventDataTooLarge` when it would not fit even
    /// an empty batch.
    pub fn tryAdd(self: *EventDataBatch, allocator: std.mem.Allocator, event: EventData) !bool {
        var message = try event.toAmqpMessage(allocator);
        defer event_data.freeAmqpMessage(allocator, &message);

        if (self.partition_key) |partition_key| {
            try event_data.setPartitionKeyAnnotation(allocator, &message, partition_key);
        }

        // Both buffers are discarded unless the event is actually adopted,
        // which includes the `false` return when it simply does not fit.
        var adopted = false;

        const encoded = try event_data.encodeMessage(allocator, &message);
        defer if (!adopted) allocator.free(encoded);

        // The first event also fixes the envelope, so its cost is charged here.
        const is_first = self.marshaled.items.len == 0;
        const envelope: ?[]u8 = if (is_first)
            try event_data.encodeMessageEnvelope(allocator, &message)
        else
            null;
        defer if (!adopted) {
            if (envelope) |bytes| allocator.free(bytes);
        };

        const envelope_size = if (envelope) |bytes| bytes.len else 0;
        const projected = self.current_size + envelope_size + dataSectionSize(encoded.len);
        if (projected > self.max_size_bytes) {
            if (is_first) return BatchError.EventDataTooLarge;
            return false;
        }

        try self.marshaled.append(allocator, encoded);
        if (envelope) |bytes| self.envelope = bytes;
        self.current_size = projected;
        adopted = true;
        return true;
    }

    pub fn count(self: EventDataBatch) usize {
        return self.marshaled.items.len;
    }

    /// Encoded size of the batch as it would go on the wire.
    pub fn sizeInBytes(self: EventDataBatch) usize {
        return self.current_size;
    }
};

/// Wrapping a payload in a data section costs a described-type constructor, the
/// descriptor, and a binary length prefix. Go's `calcActualSizeForPayload`
/// uses the same constants.
fn dataSectionSize(payload_len: usize) usize {
    const vbin8_overhead = 5;
    const vbin32_overhead = 8;
    return if (payload_len < 256) vbin8_overhead + payload_len else vbin32_overhead + payload_len;
}

pub const PartitionProperties = struct {
    id: []const u8,
    /// Name of the Event Hub the partition belongs to.
    event_hub_name: []const u8 = "",
    beginning_sequence_number: i64 = 0,
    last_enqueued_sequence_number: i64 = 0,
    last_enqueued_offset: ?[]const u8 = null,
    last_enqueued_time: ?i64 = null,
    is_empty: bool = true,
};

pub const EventHubProperties = struct {
    name: []const u8,
    partition_ids: []const []const u8 = &.{},
    created_on: ?i64 = null,
    /// True when the namespace has geo-replication enabled, which the service
    /// reports as a geo-replication factor greater than one.
    geo_replication_enabled: bool = false,
};

/// Where in a partition a consumer starts reading.
///
/// Rust models this as a `StartLocation` enum and Go as a set of optional
/// fields that it rejects when more than one is set. A tagged union makes the
/// conflict unrepresentable.
pub const StartLocation = union(enum) {
    /// The oldest event the partition still retains.
    earliest,
    /// Only events enqueued after the consumer attaches. This is the default
    /// in Go and Rust alike.
    latest,
    /// An opaque offset token, which is not necessarily numeric.
    offset: []const u8,
    sequence_number: i64,
    /// Unix milliseconds.
    enqueued_time: i64,
};

/// Starting position for reading events from a partition.
///
/// Slices are borrowed and must outlive the position.
pub const EventPosition = struct {
    location: StartLocation = .latest,
    /// Include the event at `location` rather than starting after it. Ignored
    /// for `earliest` and `latest`, which have no event to include.
    is_inclusive: bool = false,

    /// Start from the beginning of the partition.
    pub fn earliest() EventPosition {
        return .{ .location = .earliest };
    }

    /// Start from the end of the partition (new events only).
    pub fn latest() EventPosition {
        return .{ .location = .latest };
    }

    /// Start from a specific offset.
    pub fn fromOffset(offset: []const u8, inclusive: bool) EventPosition {
        return .{ .location = .{ .offset = offset }, .is_inclusive = inclusive };
    }

    /// Start from a specific sequence number.
    pub fn fromSequenceNumber(seq: i64, inclusive: bool) EventPosition {
        return .{ .location = .{ .sequence_number = seq }, .is_inclusive = inclusive };
    }

    /// Start from a specific enqueued time (Unix ms).
    pub fn fromEnqueuedTime(time: i64) EventPosition {
        return .{ .location = .{ .enqueued_time = time } };
    }

    /// Render the AMQP filter expression for this position.
    ///
    /// A default-constructed position renders as `@latest` rather than
    /// failing, matching Go's `getStartExpression` and Rust's
    /// `StartPosition::start_expression`.
    pub fn toFilterExpression(self: EventPosition, allocator: std.mem.Allocator) ![]u8 {
        const op: []const u8 = if (self.is_inclusive) ">=" else ">";
        return switch (self.location) {
            // Go and Rust both emit `>` for these two regardless of
            // inclusivity, because `-1` and `@latest` are sentinels that
            // already sit outside the event range.
            .earliest => allocator.dupe(u8, "amqp.annotation.x-opt-offset > '-1'"),
            .latest => allocator.dupe(u8, "amqp.annotation.x-opt-offset > '@latest'"),
            .offset => |offset| std.fmt.allocPrint(
                allocator,
                "amqp.annotation.x-opt-offset {s} '{s}'",
                .{ op, offset },
            ),
            .sequence_number => |seq| std.fmt.allocPrint(
                allocator,
                "amqp.annotation.x-opt-sequence-number {s} '{d}'",
                .{ op, seq },
            ),
            .enqueued_time => |time| std.fmt.allocPrint(
                allocator,
                "amqp.annotation.x-opt-enqueued-time {s} '{d}'",
                .{ op, time },
            ),
        };
    }
};

/// Per-partition starting positions, used when a partition has no checkpoint.
///
/// Partition ids are copied; every other slice is borrowed.
pub const StartPositions = struct {
    per_partition: std.StringArrayHashMapUnmanaged(EventPosition) = .empty,
    /// Used for any partition absent from `per_partition`.
    default: EventPosition = .{},

    pub fn deinit(self: *StartPositions, allocator: std.mem.Allocator) void {
        for (self.per_partition.keys()) |key| allocator.free(key);
        self.per_partition.deinit(allocator);
    }

    pub fn put(
        self: *StartPositions,
        allocator: std.mem.Allocator,
        partition_id: []const u8,
        position: EventPosition,
    ) !void {
        const owned_id = try allocator.dupe(u8, partition_id);
        errdefer allocator.free(owned_id);

        const gop = try self.per_partition.getOrPut(allocator, owned_id);
        if (gop.found_existing) allocator.free(owned_id);
        gop.value_ptr.* = position;
    }

    /// Resolve the position for a partition, falling back to `default`.
    pub fn forPartition(self: StartPositions, partition_id: []const u8) EventPosition {
        return self.per_partition.get(partition_id) orelse self.default;
    }
};

// ─────────────────── AMQP Transport ──────────────────

/// Internal transport interface for AMQP operations.
/// Abstracts over uamqp to enable unit testing.
pub const AmqpTransport = struct {
    sendBatchFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) anyerror!void,
    receiveFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) anyerror![]ReceivedEventData,
    getHubPropertiesFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8) anyerror!EventHubProperties,
    getPartitionPropertiesFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8, partition_id: []const u8) anyerror!PartitionProperties,
    closeFn: *const fn (self: *AmqpTransport) void,

    pub fn sendBatch(self: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) !void {
        return self.sendBatchFn(self, allocator, target, batch);
    }

    pub fn receive(self: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) ![]ReceivedEventData {
        return self.receiveFn(self, allocator, source, filter, max_count);
    }

    pub fn getHubProperties(self: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8) !EventHubProperties {
        return self.getHubPropertiesFn(self, allocator, hub_name);
    }

    pub fn getPartitionProperties(self: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8, partition_id: []const u8) !PartitionProperties {
        return self.getPartitionPropertiesFn(self, allocator, hub_name, partition_id);
    }

    pub fn close(self: *AmqpTransport) void {
        self.closeFn(self);
    }
};

/// AMQP transport backed by the uamqp library.
///
/// Creates proper AMQP objects (Connection, Session, Message encoding)
/// for Event Hub operations. Full network I/O integration requires
/// a TLS transport layer (see azure-uamqp-zig).
pub const UamqpTransport = struct {
    allocator: std.mem.Allocator,
    hostname: []const u8,
    transport: AmqpTransport,

    pub fn init(allocator: std.mem.Allocator, hostname: []const u8) UamqpTransport {
        return .{
            .allocator = allocator,
            .hostname = hostname,
            .transport = .{
                .sendBatchFn = &sendBatchImpl,
                .receiveFn = &receiveImpl,
                .getHubPropertiesFn = &getHubPropsImpl,
                .getPartitionPropertiesFn = &getPartitionPropsImpl,
                .closeFn = &closeImpl,
            },
        };
    }

    pub fn asTransport(self: *UamqpTransport) *AmqpTransport {
        return &self.transport;
    }

    fn sendBatchImpl(t: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) !void {
        const self: *UamqpTransport = @fieldParentPtr("transport", t);

        var conn = uamqp.connection.Connection.init(allocator, "azure-sdk-zig", self.hostname, .{});
        defer conn.deinit();

        var session = uamqp.session.Session.init(allocator, &conn, .{});
        defer session.deinit();

        const amqp_target = uamqp.messaging.createTarget(target);
        _ = amqp_target;

        // Each batched event is already encoded; a real send wraps them in the
        // batch envelope and writes one transfer with `batch_message_format`.
        for (batch.marshaled.items) |encoded| {
            std.debug.assert(encoded.len > 0);
        }
    }

    fn receiveImpl(t: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) ![]ReceivedEventData {
        const self: *UamqpTransport = @fieldParentPtr("transport", t);
        _ = max_count;
        _ = filter; // Filter applied via AMQP source filter map entries (requires I/O)

        var conn = uamqp.connection.Connection.init(allocator, "azure-sdk-zig", self.hostname, .{});
        defer conn.deinit();

        var session = uamqp.session.Session.init(allocator, &conn, .{});
        defer session.deinit();

        const amqp_source = uamqp.messaging.createSource(source);
        _ = amqp_source;

        return &.{};
    }

    fn getHubPropsImpl(t: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8) !EventHubProperties {
        _ = t;
        _ = allocator;
        return .{ .name = hub_name };
    }

    fn getPartitionPropsImpl(t: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8, partition_id: []const u8) !PartitionProperties {
        _ = t;
        _ = allocator;
        return .{ .id = partition_id, .event_hub_name = hub_name };
    }

    fn closeImpl(t: *AmqpTransport) void {
        _ = t;
    }
};

/// Mock AMQP transport for unit testing.
pub const MockAmqpTransport = struct {
    send_called: bool = false,
    send_batch_count: u32 = 0,
    /// Returned verbatim by `receive`, unlike a real transport which allocates.
    /// Tests keep ownership and must not call `freeReceivedEvents` on it.
    receive_result: []ReceivedEventData = &.{},
    hub_properties: EventHubProperties = .{ .name = "test-hub" },
    partition_properties: PartitionProperties = .{ .id = "0" },
    transport: AmqpTransport,

    pub fn init() MockAmqpTransport {
        return .{
            .transport = .{
                .sendBatchFn = &sendBatchImpl,
                .receiveFn = &receiveImpl,
                .getHubPropertiesFn = &getHubPropsImpl,
                .getPartitionPropertiesFn = &getPartitionPropsImpl,
                .closeFn = &closeImpl,
            },
        };
    }

    pub fn asTransport(self: *MockAmqpTransport) *AmqpTransport {
        return &self.transport;
    }

    fn sendBatchImpl(t: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) !void {
        _ = allocator;
        _ = target;
        const self: *MockAmqpTransport = @fieldParentPtr("transport", t);
        self.send_called = true;
        self.send_batch_count += @intCast(batch.count());
    }

    fn receiveImpl(t: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) ![]ReceivedEventData {
        _ = allocator;
        _ = source;
        _ = filter;
        _ = max_count;
        const self: *MockAmqpTransport = @fieldParentPtr("transport", t);
        return self.receive_result;
    }

    fn getHubPropsImpl(t: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8) !EventHubProperties {
        _ = allocator;
        _ = hub_name;
        const self: *MockAmqpTransport = @fieldParentPtr("transport", t);
        return self.hub_properties;
    }

    fn getPartitionPropsImpl(t: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8, partition_id: []const u8) !PartitionProperties {
        _ = allocator;
        _ = hub_name;
        _ = partition_id;
        const self: *MockAmqpTransport = @fieldParentPtr("transport", t);
        return self.partition_properties;
    }

    fn closeImpl(t: *AmqpTransport) void {
        _ = t;
    }
};

// ─────────────────────── Clients ───────────────────────

pub const ProducerClientOptions = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
};

/// Sends events to an Event Hub.
pub const ProducerClient = struct {
    options: ProducerClientOptions,
    credential: ?*core.credentials.TokenCredential = null,
    amqp_transport: *AmqpTransport,

    pub fn init(
        options: ProducerClientOptions,
        credential: *core.credentials.TokenCredential,
        amqp_transport: *AmqpTransport,
    ) ProducerClient {
        return .{
            .options = options,
            .credential = credential,
            .amqp_transport = amqp_transport,
        };
    }

    /// Create from a connection string (SAS key auth, no TokenCredential needed).
    pub fn fromConnectionString(
        connection_string: []const u8,
        event_hub_name: ?[]const u8,
        amqp_transport: *AmqpTransport,
    ) !ProducerClient {
        const cs = try ConnectionStringProperties.parse(connection_string);
        return .{
            .options = .{
                .fully_qualified_namespace = cs.fully_qualified_namespace,
                .event_hub_name = event_hub_name orelse cs.entity_path orelse return error.MissingEventHubName,
            },
            .amqp_transport = amqp_transport,
        };
    }

    /// Send a batch of events over AMQP.
    pub fn sendBatch(self: *ProducerClient, allocator: std.mem.Allocator, batch: EventDataBatch) !void {
        if (batch.count() == 0) return error.EmptyBatch;
        const address = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}",
            .{ self.options.fully_qualified_namespace, self.options.event_hub_name },
        );
        defer allocator.free(address);
        return self.amqp_transport.sendBatch(allocator, address, batch);
    }

    /// Create a batch sized for this producer.
    ///
    /// The limit stays at `default_max_message_size` until a sender link
    /// negotiates `max-message-size`, at which point `applyLinkMaxMessageSize`
    /// adopts it.
    pub fn createBatch(
        self: *ProducerClient,
        options: EventDataBatchOptions,
    ) BatchError!EventDataBatch {
        _ = self;
        return EventDataBatch.init(options);
    }

    pub fn getEventHubProperties(self: *ProducerClient, allocator: std.mem.Allocator) !EventHubProperties {
        return self.amqp_transport.getHubProperties(allocator, self.options.event_hub_name);
    }

    pub fn getPartitionProperties(self: *ProducerClient, allocator: std.mem.Allocator, partition_id: []const u8) !PartitionProperties {
        return self.amqp_transport.getPartitionProperties(allocator, self.options.event_hub_name, partition_id);
    }

    pub fn close(self: *ProducerClient) void {
        self.amqp_transport.close();
    }
};

pub const ConsumerClientOptions = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    consumer_group: []const u8 = "$Default",
};

/// Receives events from an Event Hub partition.
pub const ConsumerClient = struct {
    options: ConsumerClientOptions,
    credential: ?*core.credentials.TokenCredential = null,
    amqp_transport: *AmqpTransport,

    pub fn init(
        options: ConsumerClientOptions,
        credential: *core.credentials.TokenCredential,
        amqp_transport: *AmqpTransport,
    ) ConsumerClient {
        return .{
            .options = options,
            .credential = credential,
            .amqp_transport = amqp_transport,
        };
    }

    /// Create from a connection string (SAS key auth, no TokenCredential needed).
    pub fn fromConnectionString(
        connection_string: []const u8,
        event_hub_name: ?[]const u8,
        amqp_transport: *AmqpTransport,
    ) !ConsumerClient {
        const cs = try ConnectionStringProperties.parse(connection_string);
        return .{
            .options = .{
                .fully_qualified_namespace = cs.fully_qualified_namespace,
                .event_hub_name = event_hub_name orelse cs.entity_path orelse return error.MissingEventHubName,
            },
            .amqp_transport = amqp_transport,
        };
    }

    /// Receive events from a specific partition.
    ///
    /// The returned slice comes from the transport. `UamqpTransport` allocates
    /// it, so free it with `freeReceivedEvents`; `MockAmqpTransport` returns
    /// the slice a test handed it and keeps ownership.
    pub fn receiveEvents(
        self: *ConsumerClient,
        allocator: std.mem.Allocator,
        partition_id: []const u8,
        start_position: EventPosition,
        max_count: u32,
    ) ![]ReceivedEventData {
        const address = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/ConsumerGroups/{s}/Partitions/{s}",
            .{
                self.options.fully_qualified_namespace,
                self.options.event_hub_name,
                self.options.consumer_group,
                partition_id,
            },
        );
        defer allocator.free(address);

        const filter = try start_position.toFilterExpression(allocator);
        defer allocator.free(filter);

        return self.amqp_transport.receive(allocator, address, filter, max_count);
    }

    pub fn getEventHubProperties(self: *ConsumerClient, allocator: std.mem.Allocator) !EventHubProperties {
        return self.amqp_transport.getHubProperties(allocator, self.options.event_hub_name);
    }

    pub fn getPartitionProperties(self: *ConsumerClient, allocator: std.mem.Allocator, partition_id: []const u8) !PartitionProperties {
        return self.amqp_transport.getPartitionProperties(allocator, self.options.event_hub_name, partition_id);
    }

    pub fn close(self: *ConsumerClient) void {
        self.amqp_transport.close();
    }
};

// ─────────────────────── Tests ───────────────────────

test "EventData init" {
    const allocator = std.testing.allocator;
    var event = EventData.init("hello world");
    defer event.deinit(allocator);
    try event.setStringProperty(allocator, "source", "test");
    try std.testing.expectEqualStrings("hello world", event.body);
    try std.testing.expectEqualStrings("test", event.properties.getString("source").?);
}

test "EventDataBatch tryAdd" {
    const allocator = std.testing.allocator;
    var batch = try EventDataBatch.init(.{});
    defer batch.deinit(allocator);
    var e1 = EventData.init("event-1");
    defer e1.deinit(allocator);
    const added = try batch.tryAdd(allocator, e1);
    try std.testing.expect(added);
    try std.testing.expectEqual(@as(usize, 1), batch.count());
    try std.testing.expect(batch.sizeInBytes() > 0);
    try std.testing.expect(batch.envelope != null);
}

test "EventDataBatch rejects a partition key and id together" {
    try std.testing.expectError(
        BatchError.PartitionKeyAndIdBothSet,
        EventDataBatch.init(.{ .partition_key = "pk", .partition_id = "0" }),
    );
    const by_key = try EventDataBatch.init(.{ .partition_key = "pk" });
    try std.testing.expectEqualStrings("pk", by_key.partition_key.?);
    const by_id = try EventDataBatch.init(.{ .partition_id = "3" });
    try std.testing.expectEqualStrings("3", by_id.partition_id.?);
}

test "EventDataBatch defaults to one mebibyte" {
    const batch = try EventDataBatch.init(.{});
    try std.testing.expectEqual(default_max_message_size, batch.max_size_bytes);
    try std.testing.expectEqual(@as(usize, 1024 * 1024), default_max_message_size);
}

test "EventDataBatch fills up without exceeding max_bytes" {
    const allocator = std.testing.allocator;
    var batch = try EventDataBatch.init(.{ .max_bytes = 512 });
    defer batch.deinit(allocator);

    var event = EventData.init("x" ** 32);
    defer event.deinit(allocator);

    var added: usize = 0;
    while (try batch.tryAdd(allocator, event)) : (added += 1) {
        try std.testing.expect(batch.sizeInBytes() <= 512);
    }

    try std.testing.expect(added > 1);
    try std.testing.expectEqual(added, batch.count());
    try std.testing.expect(batch.sizeInBytes() <= 512);
    // The next event still does not fit, and that stays a `false` rather than
    // an error because the batch is not empty.
    try std.testing.expect(!try batch.tryAdd(allocator, event));
}

test "EventDataBatch reports an oversized event distinctly" {
    const allocator = std.testing.allocator;
    var batch = try EventDataBatch.init(.{ .max_bytes = 32 });
    defer batch.deinit(allocator);

    var event = EventData.init("y" ** 256);
    defer event.deinit(allocator);

    try std.testing.expectError(BatchError.EventDataTooLarge, batch.tryAdd(allocator, event));
    try std.testing.expectEqual(@as(usize, 0), batch.count());
    try std.testing.expectEqual(@as(usize, 0), batch.sizeInBytes());
    try std.testing.expect(batch.envelope == null);
}

test "EventDataBatch size matches the encoded bytes" {
    const allocator = std.testing.allocator;
    var batch = try EventDataBatch.init(.{});
    defer batch.deinit(allocator);

    var first = EventData.init("first event");
    defer first.deinit(allocator);
    try first.setStringProperty(allocator, "tenant", "contoso");
    var second = EventData.init("second event body which is a little longer");
    defer second.deinit(allocator);

    try std.testing.expect(try batch.tryAdd(allocator, first));
    try std.testing.expect(try batch.tryAdd(allocator, second));

    var expected = batch.envelope.?.len;
    for (batch.marshaled.items) |encoded| {
        expected += if (encoded.len < 256) 5 + encoded.len else 8 + encoded.len;
    }
    try std.testing.expectEqual(expected, batch.sizeInBytes());
}

test "EventDataBatch charges for the partition key annotation" {
    const allocator = std.testing.allocator;

    var event = EventData.init("event");
    defer event.deinit(allocator);

    var plain = try EventDataBatch.init(.{});
    defer plain.deinit(allocator);
    try std.testing.expect(try plain.tryAdd(allocator, event));

    var keyed = try EventDataBatch.init(.{ .partition_key = "a-partition-key" });
    defer keyed.deinit(allocator);
    try std.testing.expect(try keyed.tryAdd(allocator, event));

    try std.testing.expect(keyed.sizeInBytes() > plain.sizeInBytes());
}

test "EventDataBatch adopts the link negotiated size" {
    const allocator = std.testing.allocator;

    var negotiated = try EventDataBatch.init(.{});
    try negotiated.applyLinkMaxMessageSize(256 * 1024);
    try std.testing.expectEqual(@as(usize, 256 * 1024), negotiated.max_size_bytes);

    var smaller = try EventDataBatch.init(.{ .max_bytes = 4096 });
    try smaller.applyLinkMaxMessageSize(256 * 1024);
    try std.testing.expectEqual(@as(usize, 4096), smaller.max_size_bytes);

    var too_large = try EventDataBatch.init(.{ .max_bytes = 2 * 1024 * 1024 });
    try std.testing.expectError(
        BatchError.MaxBytesExceedsLinkLimit,
        too_large.applyLinkMaxMessageSize(1024 * 1024),
    );

    var started = try EventDataBatch.init(.{});
    defer started.deinit(allocator);
    var event = EventData.init("event");
    defer event.deinit(allocator);
    try std.testing.expect(try started.tryAdd(allocator, event));
    try std.testing.expectError(
        BatchError.BatchNotEmpty,
        started.applyLinkMaxMessageSize(256 * 1024),
    );
}

test "EventPosition earliest filter" {
    const allocator = std.testing.allocator;
    const pos = EventPosition.earliest();
    const expr = try pos.toFilterExpression(allocator);
    defer allocator.free(expr);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-offset > '-1'", expr);
}

test "EventPosition latest filter" {
    const allocator = std.testing.allocator;
    const pos = EventPosition.latest();
    const expr = try pos.toFilterExpression(allocator);
    defer allocator.free(expr);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-offset > '@latest'", expr);
}

test "EventPosition fromSequenceNumber inclusive" {
    const allocator = std.testing.allocator;
    const pos = EventPosition.fromSequenceNumber(42, true);
    const expr = try pos.toFilterExpression(allocator);
    defer allocator.free(expr);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-sequence-number >= '42'", expr);
}

test "EventPosition fromEnqueuedTime" {
    const allocator = std.testing.allocator;
    const pos = EventPosition.fromEnqueuedTime(1617235200000);
    const expr = try pos.toFilterExpression(allocator);
    defer allocator.free(expr);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-enqueued-time > '1617235200000'", expr);
}

test "ProducerClient createBatch" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_sdk_core").identity.client_secret;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock.asTransport(), "t", "c", "s");
    var amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), amqp.asTransport());
    var batch = try producer.createBatch(.{});
    defer batch.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), batch.count());
}

test "ProducerClient sendBatch" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_sdk_core").identity.client_secret;
    var mock_http = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock_http.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock_http.asTransport(), "t", "c", "s");
    var amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), amqp.asTransport());

    var batch = try producer.createBatch(.{});
    defer batch.deinit(allocator);
    var e1 = EventData.init("event-1");
    defer e1.deinit(allocator);
    _ = try batch.tryAdd(allocator, e1);

    try producer.sendBatch(allocator, batch);
    try std.testing.expect(amqp.send_called);
    try std.testing.expectEqual(@as(u32, 1), amqp.send_batch_count);
}

test "ProducerClient sendBatch empty returns error" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_sdk_core").identity.client_secret;
    var mock_http = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock_http.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock_http.asTransport(), "t", "c", "s");
    var amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), amqp.asTransport());

    var batch = try producer.createBatch(.{});
    defer batch.deinit(allocator);

    const result = producer.sendBatch(allocator, batch);
    try std.testing.expectError(error.EmptyBatch, result);
}

test "ProducerClient getEventHubProperties" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_sdk_core").identity.client_secret;
    var mock_http = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock_http.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock_http.asTransport(), "t", "c", "s");
    var amqp = MockAmqpTransport.init();
    amqp.hub_properties = .{ .name = "my-hub", .partition_ids = &.{ "0", "1", "2" } };
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), amqp.asTransport());

    const props = try producer.getEventHubProperties(allocator);
    try std.testing.expectEqualStrings("my-hub", props.name);
    try std.testing.expectEqual(@as(usize, 3), props.partition_ids.len);
}

test "ConsumerClient receiveEvents" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_sdk_core").identity.client_secret;
    var mock_http = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock_http.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock_http.asTransport(), "t", "c", "s");
    var amqp = MockAmqpTransport.init();
    var consumer = ConsumerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), amqp.asTransport());

    const events = try consumer.receiveEvents(allocator, "0", EventPosition.earliest(), 10);
    try std.testing.expectEqual(@as(usize, 0), events.len);
}

test "UamqpTransport sendBatch encodes messages" {
    const allocator = std.testing.allocator;
    var transport = UamqpTransport.init(allocator, "ns.servicebus.windows.net");

    var batch = try EventDataBatch.init(.{});
    defer batch.deinit(allocator);
    var e1 = EventData.init("hello");
    defer e1.deinit(allocator);
    _ = try batch.tryAdd(allocator, e1);

    try transport.asTransport().sendBatch(allocator, "ns.servicebus.windows.net/my-hub", batch);
}

test "ProducerClient fromConnectionString" {
    var amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://mynamespace.servicebus.windows.net/;SharedAccessKeyName=mykey;SharedAccessKey=abc123=;EntityPath=myhub";
    const producer = try ProducerClient.fromConnectionString(cs, null, amqp.asTransport());
    try std.testing.expectEqualStrings("mynamespace.servicebus.windows.net", producer.options.fully_qualified_namespace);
    try std.testing.expectEqualStrings("myhub", producer.options.event_hub_name);
    try std.testing.expect(producer.credential == null);
}

test "ProducerClient fromConnectionString with override" {
    var amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=hub1";
    const producer = try ProducerClient.fromConnectionString(cs, "hub2", amqp.asTransport());
    try std.testing.expectEqualStrings("hub2", producer.options.event_hub_name);
}

test "ProducerClient fromConnectionString missing hub" {
    var amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v";
    const result = ProducerClient.fromConnectionString(cs, null, amqp.asTransport());
    try std.testing.expectError(error.MissingEventHubName, result);
}

test "ConsumerClient fromConnectionString" {
    var amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=hub";
    const consumer = try ConsumerClient.fromConnectionString(cs, null, amqp.asTransport());
    try std.testing.expectEqualStrings("ns.servicebus.windows.net", consumer.options.fully_qualified_namespace);
    try std.testing.expectEqualStrings("hub", consumer.options.event_hub_name);
    try std.testing.expectEqualStrings("$Default", consumer.options.consumer_group);
}

test "EventDataBatch survives allocation failure at every step" {
    const Case = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var batch = try EventDataBatch.init(.{ .partition_key = "pk-1" });
            defer batch.deinit(allocator);

            var event = EventData.init("payload");
            defer event.deinit(allocator);
            event.content_type = "application/json";
            try event.setStringProperty(allocator, "tenant", "contoso");

            _ = try batch.tryAdd(allocator, event);
            _ = try batch.tryAdd(allocator, event);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Case.run, .{});
}

test "EventDataBatch does not leak when an event does not fit" {
    const allocator = std.testing.allocator;
    var batch = try EventDataBatch.init(.{ .max_bytes = 128 });
    defer batch.deinit(allocator);

    var small = EventData.init("s");
    defer small.deinit(allocator);
    try std.testing.expect(try batch.tryAdd(allocator, small));

    var large = EventData.init("z" ** 200);
    defer large.deinit(allocator);
    try std.testing.expect(!try batch.tryAdd(allocator, large));
    try std.testing.expectEqual(@as(usize, 1), batch.count());
}

test "a default EventPosition starts at the latest event" {
    const allocator = std.testing.allocator;
    const expr = try (EventPosition{}).toFilterExpression(allocator);
    defer allocator.free(expr);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-offset > '@latest'", expr);
    try std.testing.expectEqual(StartLocation.latest, std.meta.activeTag((EventPosition{}).location));
}

test "earliest and latest ignore inclusivity like Go and Rust" {
    const allocator = std.testing.allocator;

    var inclusive_earliest = EventPosition.earliest();
    inclusive_earliest.is_inclusive = true;
    const earliest_expr = try inclusive_earliest.toFilterExpression(allocator);
    defer allocator.free(earliest_expr);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-offset > '-1'", earliest_expr);

    var inclusive_latest = EventPosition.latest();
    inclusive_latest.is_inclusive = true;
    const latest_expr = try inclusive_latest.toFilterExpression(allocator);
    defer allocator.free(latest_expr);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-offset > '@latest'", latest_expr);
}

test "EventPosition fromOffset honours inclusivity" {
    const allocator = std.testing.allocator;

    const exclusive = try EventPosition.fromOffset("12345", false).toFilterExpression(allocator);
    defer allocator.free(exclusive);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-offset > '12345'", exclusive);

    const inclusive = try EventPosition.fromOffset("12345", true).toFilterExpression(allocator);
    defer allocator.free(inclusive);
    try std.testing.expectEqualStrings("amqp.annotation.x-opt-offset >= '12345'", inclusive);
}

test "EventPosition enqueued time honours inclusivity" {
    const allocator = std.testing.allocator;

    var position = EventPosition.fromEnqueuedTime(1617235200000);
    position.is_inclusive = true;
    const expr = try position.toFilterExpression(allocator);
    defer allocator.free(expr);
    try std.testing.expectEqualStrings(
        "amqp.annotation.x-opt-enqueued-time >= '1617235200000'",
        expr,
    );
}

test "StartPositions prefers a per-partition entry over the default" {
    const allocator = std.testing.allocator;

    var positions = StartPositions{ .default = EventPosition.earliest() };
    defer positions.deinit(allocator);

    try positions.put(allocator, "3", EventPosition.fromSequenceNumber(99, true));

    const configured = positions.forPartition("3");
    try std.testing.expectEqual(@as(i64, 99), configured.location.sequence_number);
    try std.testing.expect(configured.is_inclusive);

    const fallback = positions.forPartition("7");
    try std.testing.expectEqual(StartLocation.earliest, std.meta.activeTag(fallback.location));
}

test "StartPositions defaults to latest and replaces entries" {
    const allocator = std.testing.allocator;

    var positions = StartPositions{};
    defer positions.deinit(allocator);

    try std.testing.expectEqual(
        StartLocation.latest,
        std.meta.activeTag(positions.forPartition("0").location),
    );

    try positions.put(allocator, "0", EventPosition.earliest());
    try positions.put(allocator, "0", EventPosition.fromOffset("42", false));

    try std.testing.expectEqual(@as(usize, 1), positions.per_partition.count());
    try std.testing.expectEqualStrings("42", positions.forPartition("0").location.offset);
}

test "StartPositions.put is failure atomic" {
    const Case = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var positions = StartPositions{};
            defer positions.deinit(allocator);

            try positions.put(allocator, "0", EventPosition.earliest());
            try positions.put(allocator, "1", EventPosition.latest());
            try positions.put(allocator, "0", EventPosition.fromOffset("7", true));

            try std.testing.expectEqual(@as(usize, 2), positions.per_partition.count());
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Case.run, .{});
}
