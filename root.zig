///! Azure Event Hubs client — producer and consumer.
///!
///! Built on top of azure-sdk-core-amqp.
const std = @import("std");
const core = @import("azure_sdk_core");
const uamqp = @import("uamqp");
const messaging_common = @import("azure_sdk_messaging_common");
const checkpoint = @import("checkpoint.zig");

pub const ConnectionStringProperties = messaging_common.ConnectionStringProperties;
pub const Checkpoint = checkpoint.Checkpoint;
pub const PartitionOwnership = checkpoint.PartitionOwnership;
pub const CheckpointStore = checkpoint.CheckpointStore;
pub const checkpoint_store_blob = @import("checkpoint_store.zig");

// ─────────────────────── Models ───────────────────────

pub const EventData = struct {
    body: []const u8,
    properties: std.StringHashMap([]const u8),
    partition_key: ?[]const u8 = null,
    sequence_number: ?i64 = null,
    offset: ?[]const u8 = null,
    enqueued_time: ?i64 = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, body: []const u8) EventData {
        return .{
            .body = body,
            .properties = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EventData) void {
        self.properties.deinit();
    }
};

pub const EventDataBatch = struct {
    events: std.ArrayList(EventData),
    max_size_bytes: usize = 1024 * 1024,
    current_size: usize = 0,

    pub fn init(allocator: std.mem.Allocator) EventDataBatch {
        _ = allocator;
        return .{
            .events = .empty,
        };
    }

    pub fn tryAdd(self: *EventDataBatch, allocator: std.mem.Allocator, event: EventData) !bool {
        const event_size = event.body.len + 64; // approximate overhead
        if (self.current_size + event_size > self.max_size_bytes) return false;
        try self.events.append(allocator, event);
        self.current_size += event_size;
        return true;
    }

    pub fn count(self: EventDataBatch) usize {
        return self.events.items.len;
    }

    pub fn deinit(self: *EventDataBatch, allocator: std.mem.Allocator) void {
        self.events.deinit(allocator);
    }
};

pub const PartitionProperties = struct {
    id: []const u8,
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
};

/// Starting position for reading events from a partition.
pub const EventPosition = struct {
    offset: ?[]const u8 = null,
    sequence_number: ?i64 = null,
    enqueued_time: ?i64 = null,
    is_inclusive: bool = false,

    /// Start from the beginning of the partition.
    pub fn earliest() EventPosition {
        return .{ .offset = "-1" };
    }

    /// Start from the end of the partition (new events only).
    pub fn latest() EventPosition {
        return .{ .offset = "@latest" };
    }

    /// Start from a specific offset.
    pub fn fromOffset(offset: []const u8, inclusive: bool) EventPosition {
        return .{ .offset = offset, .is_inclusive = inclusive };
    }

    /// Start from a specific sequence number.
    pub fn fromSequenceNumber(seq: i64, inclusive: bool) EventPosition {
        return .{ .sequence_number = seq, .is_inclusive = inclusive };
    }

    /// Start from a specific enqueued time (Unix ms).
    pub fn fromEnqueuedTime(time: i64) EventPosition {
        return .{ .enqueued_time = time };
    }

    /// Render the AMQP filter expression for this position.
    pub fn toFilterExpression(self: EventPosition, allocator: std.mem.Allocator) ![]u8 {
        const op: []const u8 = if (self.is_inclusive) ">=" else ">";
        if (self.offset) |offset| {
            return std.fmt.allocPrint(allocator, "amqp.annotation.x-opt-offset {s} '{s}'", .{ op, offset });
        }
        if (self.sequence_number) |seq| {
            return std.fmt.allocPrint(allocator, "amqp.annotation.x-opt-sequence-number {s} '{d}'", .{ op, seq });
        }
        if (self.enqueued_time) |time| {
            return std.fmt.allocPrint(allocator, "amqp.annotation.x-opt-enqueued-time {s} '{d}'", .{ op, time });
        }
        return error.InvalidEventPosition;
    }
};

// ─────────────────── AMQP Transport ──────────────────

/// Internal transport interface for AMQP operations.
/// Abstracts over uamqp to enable unit testing.
pub const AmqpTransport = struct {
    sendBatchFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) anyerror!void,
    receiveFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) anyerror![]EventData,
    getHubPropertiesFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8) anyerror!EventHubProperties,
    getPartitionPropertiesFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8, partition_id: []const u8) anyerror!PartitionProperties,
    closeFn: *const fn (self: *AmqpTransport) void,

    pub fn sendBatch(self: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) !void {
        return self.sendBatchFn(self, allocator, target, batch);
    }

    pub fn receive(self: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) ![]EventData {
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

        for (batch.events.items) |event| {
            var msg = uamqp.message.Message.init(allocator);
            defer msg.deinit();
            try msg.addBodyData(event.body);
        }
    }

    fn receiveImpl(t: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) ![]EventData {
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
        _ = hub_name;
        return .{ .id = partition_id };
    }

    fn closeImpl(t: *AmqpTransport) void {
        _ = t;
    }
};

/// Mock AMQP transport for unit testing.
pub const MockAmqpTransport = struct {
    send_called: bool = false,
    send_batch_count: u32 = 0,
    receive_result: []EventData = &.{},
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

    fn receiveImpl(t: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) ![]EventData {
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

    pub fn createBatch(self: *ProducerClient, _: std.mem.Allocator) EventDataBatch {
        _ = self;
        return .{ .events = .empty };
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
    pub fn receiveEvents(
        self: *ConsumerClient,
        allocator: std.mem.Allocator,
        partition_id: []const u8,
        start_position: EventPosition,
        max_count: u32,
    ) ![]EventData {
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
    var event = EventData.init(allocator, "hello world");
    defer event.deinit();
    try event.properties.put("source", "test");
    try std.testing.expectEqualStrings("hello world", event.body);
}

test "EventDataBatch tryAdd" {
    const allocator = std.testing.allocator;
    var batch = EventDataBatch.init(allocator);
    defer batch.deinit(allocator);
    var e1 = EventData.init(allocator, "event-1");
    defer e1.deinit();
    const added = try batch.tryAdd(allocator, e1);
    try std.testing.expect(added);
    try std.testing.expectEqual(@as(usize, 1), batch.count());
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
    var batch = producer.createBatch(allocator);
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

    var batch = producer.createBatch(allocator);
    defer batch.deinit(allocator);
    var e1 = EventData.init(allocator, "event-1");
    defer e1.deinit();
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

    var batch = producer.createBatch(allocator);
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

    var batch = EventDataBatch.init(allocator);
    defer batch.deinit(allocator);
    var e1 = EventData.init(allocator, "hello");
    defer e1.deinit();
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
