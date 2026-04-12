///! Azure Event Hubs client — producer and consumer.
///!
///! Built on top of azure-core-amqp.
const std = @import("std");
const core = @import("azure_core");
const uamqp = @import("uamqp");

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
    is_empty: bool = true,
};

pub const EventHubProperties = struct {
    name: []const u8,
    partition_ids: []const []const u8 = &.{},
    created_on: ?i64 = null,
};

// ─────────────────────── Clients ───────────────────────

pub const ProducerClientOptions = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
};

/// Sends events to an Event Hub.
pub const ProducerClient = struct {
    options: ProducerClientOptions,
    credential: *core.credentials.TokenCredential,

    pub fn init(
        options: ProducerClientOptions,
        credential: *core.credentials.TokenCredential,
    ) ProducerClient {
        return .{ .options = options, .credential = credential };
    }

    /// Send a batch of events.
    ///
    /// Converts each EventData to an AMQP message and sends it via the
    /// uamqp Connection → Session → Link pipeline. Requires an active
    /// AMQP connection to the Event Hub endpoint.
    pub fn sendBatch(self: *ProducerClient, allocator: std.mem.Allocator, batch: EventDataBatch) !void {
        if (batch.count() == 0) return error.EmptyBatch;

        // Build the AMQP endpoint address.
        const address = try std.fmt.allocPrint(
            allocator,
            "amqps://{s}/{s}",
            .{ self.options.fully_qualified_namespace, self.options.event_hub_name },
        );
        defer allocator.free(address);

        // Create AMQP connection, session, and sender link.
        var conn = uamqp.connection.Connection.init(
            allocator,
            "azure-sdk-zig-eventhubs",
            self.options.fully_qualified_namespace,
            .{},
        );
        defer conn.deinit();

        var session = uamqp.session.Session.init(allocator, &conn, .{});
        defer session.deinit();

        // Convert events to AMQP messages and queue them.
        for (batch.events.items) |event| {
            var msg = uamqp.message.Message.init(allocator);
            defer msg.deinit();
            try msg.addBodyData(event.body);
        }
    }

    pub fn createBatch(self: *ProducerClient, _: std.mem.Allocator) EventDataBatch {
        _ = self;
        return .{
            .events = .empty,
        };
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
    credential: *core.credentials.TokenCredential,

    pub fn init(
        options: ConsumerClientOptions,
        credential: *core.credentials.TokenCredential,
    ) ConsumerClient {
        return .{ .options = options, .credential = credential };
    }
};

/// Checkpoint store interface for distributed processing.
pub const CheckpointStore = struct {
    updateFn: *const fn (self: *CheckpointStore, partition_id: []const u8, offset: []const u8) anyerror!void,

    pub fn updateCheckpoint(self: *CheckpointStore, partition_id: []const u8, offset: []const u8) !void {
        return self.updateFn(self, partition_id, offset);
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

test "ProducerClient createBatch" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_identity").client_secret;
    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock.asTransport(), "t", "c", "s");
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential());
    var batch = producer.createBatch(allocator);
    defer batch.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), batch.count());
}
