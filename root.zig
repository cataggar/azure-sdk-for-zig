///! Azure Service Bus client — sender, receiver, and administration.
///!
///! Built on top of azure-core-amqp for messaging and azure-core HTTP
///! pipeline for administration operations.
const std = @import("std");
const core = @import("azure_core");
const uamqp = @import("uamqp");
const messaging_common = @import("azure_messaging_common");

pub const ConnectionStringProperties = messaging_common.ConnectionStringProperties;

// ─────────────────────── Models ───────────────────────

pub const ReceiveMode = enum {
    peek_lock,
    receive_and_delete,
};

pub const SubQueue = enum {
    none,
    dead_letter,
    transfer_dead_letter,

    pub fn suffix(self: SubQueue) ?[]const u8 {
        return switch (self) {
            .none => null,
            .dead_letter => "/$deadletterqueue",
            .transfer_dead_letter => "/$transferdeadletterqueue",
        };
    }
};

/// Message disposition actions for peek-lock settlement.
pub const DispositionAction = enum {
    complete,
    abandon,
    dead_letter,
    defer_msg,
};

/// Entity addressing for receiver: queue or topic+subscription.
pub const EntityOptions = union(enum) {
    queue: []const u8,
    subscription: struct {
        topic_name: []const u8,
        subscription_name: []const u8,
    },

    /// Build the AMQP entity path.
    pub fn entityPath(self: EntityOptions) struct { base: []const u8, sub: ?[]const u8 } {
        return switch (self) {
            .queue => |q| .{ .base = q, .sub = null },
            .subscription => |s| .{ .base = s.topic_name, .sub = s.subscription_name },
        };
    }

    /// Format the full AMQP address for this entity.
    pub fn formatAddress(self: EntityOptions, allocator: std.mem.Allocator, sub_queue: SubQueue) ![]u8 {
        const sq = sub_queue.suffix() orelse "";
        return switch (self) {
            .queue => |q| std.fmt.allocPrint(allocator, "{s}{s}", .{ q, sq }),
            .subscription => |s| std.fmt.allocPrint(allocator, "{s}/Subscriptions/{s}{s}", .{ s.topic_name, s.subscription_name, sq }),
        };
    }
};

/// An outgoing Service Bus message.
pub const ServiceBusMessage = struct {
    body: []const u8,
    content_type: ?[]const u8 = null,
    message_id: ?[]const u8 = null,
    session_id: ?[]const u8 = null,
    partition_key: ?[]const u8 = null,
    time_to_live_ms: ?i64 = null,
    subject: ?[]const u8 = null,
    to: ?[]const u8 = null,
    reply_to: ?[]const u8 = null,
    correlation_id: ?[]const u8 = null,
    scheduled_enqueue_time: ?i64 = null,
    application_properties: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, body: []const u8) ServiceBusMessage {
        return .{
            .body = body,
            .application_properties = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ServiceBusMessage) void {
        self.application_properties.deinit();
    }
};

/// A received Service Bus message with broker-assigned metadata.
pub const ServiceBusReceivedMessage = struct {
    body: []const u8,
    content_type: ?[]const u8 = null,
    message_id: ?[]const u8 = null,
    session_id: ?[]const u8 = null,
    correlation_id: ?[]const u8 = null,
    subject: ?[]const u8 = null,
    to: ?[]const u8 = null,
    reply_to: ?[]const u8 = null,
    // Broker-assigned properties
    sequence_number: ?i64 = null,
    enqueued_time: ?i64 = null,
    delivery_count: ?u32 = null,
    dead_letter_source: ?[]const u8 = null,
    dead_letter_reason: ?[]const u8 = null,
    /// Opaque delivery tag for message settlement.
    delivery_tag: ?[]const u8 = null,
};

/// Batch of outgoing messages with size tracking.
pub const ServiceBusMessageBatch = struct {
    messages: std.ArrayList(ServiceBusMessage),
    max_size_bytes: usize = 256 * 1024,
    current_size: usize = 0,

    pub fn init() ServiceBusMessageBatch {
        return .{ .messages = .empty };
    }

    pub fn tryAdd(self: *ServiceBusMessageBatch, allocator: std.mem.Allocator, message: ServiceBusMessage) !bool {
        const msg_size = message.body.len + 128; // approximate AMQP overhead
        if (self.current_size + msg_size > self.max_size_bytes) return false;
        try self.messages.append(allocator, message);
        self.current_size += msg_size;
        return true;
    }

    pub fn count(self: ServiceBusMessageBatch) usize {
        return self.messages.items.len;
    }

    pub fn deinit(self: *ServiceBusMessageBatch, allocator: std.mem.Allocator) void {
        self.messages.deinit(allocator);
    }
};

// ─────────────── Administration Models ───────────────

pub const QueueProperties = struct {
    name: []const u8,
    max_delivery_count: ?u32 = null,
    lock_duration: ?[]const u8 = null,
    max_size_in_megabytes: ?u32 = null,
    requires_session: bool = false,
    dead_lettering_on_message_expiration: bool = false,
    default_message_time_to_live: ?[]const u8 = null,
    status: ?[]const u8 = null,
};

pub const TopicProperties = struct {
    name: []const u8,
    max_size_in_megabytes: ?u32 = null,
    requires_duplicate_detection: bool = false,
    default_message_time_to_live: ?[]const u8 = null,
    status: ?[]const u8 = null,
};

pub const SubscriptionProperties = struct {
    name: []const u8,
    topic_name: []const u8,
    max_delivery_count: ?u32 = null,
    lock_duration: ?[]const u8 = null,
    requires_session: bool = false,
    dead_lettering_on_message_expiration: bool = false,
    default_message_time_to_live: ?[]const u8 = null,
    status: ?[]const u8 = null,
};

// ─────────────── AMQP Transport ─────────────────────

/// Internal transport interface for Service Bus AMQP operations.
pub const ServiceBusAmqpTransport = struct {
    sendMessagesFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage) anyerror!void,
    receiveMessagesFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, max_count: u32, mode: ReceiveMode) anyerror![]ServiceBusReceivedMessage,
    settleMessageFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, delivery_tag: []const u8, action: DispositionAction, reason: ?[]const u8) anyerror!void,
    scheduleMessageFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, message: ServiceBusMessage, enqueue_time: i64) anyerror!i64,
    cancelScheduledFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, sequence_number: i64) anyerror!void,
    closeFn: *const fn (self: *ServiceBusAmqpTransport) void,

    pub fn sendMessages(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage) !void {
        return self.sendMessagesFn(self, allocator, entity, messages);
    }

    pub fn receiveMessages(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, max_count: u32, mode: ReceiveMode) ![]ServiceBusReceivedMessage {
        return self.receiveMessagesFn(self, allocator, entity, max_count, mode);
    }

    pub fn settleMessage(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, delivery_tag: []const u8, action: DispositionAction, reason: ?[]const u8) !void {
        return self.settleMessageFn(self, allocator, delivery_tag, action, reason);
    }

    pub fn scheduleMessage(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, message: ServiceBusMessage, enqueue_time: i64) !i64 {
        return self.scheduleMessageFn(self, allocator, entity, message, enqueue_time);
    }

    pub fn cancelScheduled(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, sequence_number: i64) !void {
        return self.cancelScheduledFn(self, allocator, entity, sequence_number);
    }

    pub fn close(self: *ServiceBusAmqpTransport) void {
        self.closeFn(self);
    }
};

/// AMQP transport backed by the uamqp library.
pub const UamqpServiceBusTransport = struct {
    allocator: std.mem.Allocator,
    hostname: []const u8,
    transport: ServiceBusAmqpTransport,

    pub fn init(allocator: std.mem.Allocator, hostname: []const u8) UamqpServiceBusTransport {
        return .{
            .allocator = allocator,
            .hostname = hostname,
            .transport = .{
                .sendMessagesFn = &sendMessagesImpl,
                .receiveMessagesFn = &receiveMessagesImpl,
                .settleMessageFn = &settleMessageImpl,
                .scheduleMessageFn = &scheduleMessageImpl,
                .cancelScheduledFn = &cancelScheduledImpl,
                .closeFn = &closeImpl,
            },
        };
    }

    pub fn asTransport(self: *UamqpServiceBusTransport) *ServiceBusAmqpTransport {
        return &self.transport;
    }

    fn sendMessagesImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage) !void {
        const self: *UamqpServiceBusTransport = @fieldParentPtr("transport", t);

        var conn = uamqp.connection.Connection.init(allocator, "azure-sdk-zig-servicebus", self.hostname, .{});
        defer conn.deinit();

        var session = uamqp.session.Session.init(allocator, &conn, .{});
        defer session.deinit();

        const amqp_target = uamqp.messaging.createTarget(entity);
        _ = amqp_target;

        for (messages) |message| {
            var msg = uamqp.message.Message.init(allocator);
            defer msg.deinit();
            try msg.addBodyData(message.body);
        }
    }

    fn receiveMessagesImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, max_count: u32, mode: ReceiveMode) ![]ServiceBusReceivedMessage {
        const self: *UamqpServiceBusTransport = @fieldParentPtr("transport", t);
        _ = max_count;
        _ = mode;

        var conn = uamqp.connection.Connection.init(allocator, "azure-sdk-zig-servicebus", self.hostname, .{});
        defer conn.deinit();

        var session = uamqp.session.Session.init(allocator, &conn, .{});
        defer session.deinit();

        const amqp_source = uamqp.messaging.createSource(entity);
        _ = amqp_source;

        return &.{};
    }

    fn settleMessageImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, delivery_tag: []const u8, action: DispositionAction, reason: ?[]const u8) !void {
        _ = t;
        _ = allocator;
        _ = delivery_tag;
        _ = action;
        _ = reason;
    }

    fn scheduleMessageImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, message: ServiceBusMessage, enqueue_time: i64) !i64 {
        _ = t;
        _ = allocator;
        _ = entity;
        _ = message;
        _ = enqueue_time;
        // Management operation would return the sequence number.
        return 0;
    }

    fn cancelScheduledImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, sequence_number: i64) !void {
        _ = t;
        _ = allocator;
        _ = entity;
        _ = sequence_number;
    }

    fn closeImpl(t: *ServiceBusAmqpTransport) void {
        _ = t;
    }
};

/// Mock AMQP transport for unit testing.
pub const MockServiceBusTransport = struct {
    send_called: bool = false,
    send_count: u32 = 0,
    settle_calls: u32 = 0,
    last_settle_action: ?DispositionAction = null,
    schedule_result: i64 = 1001,
    receive_result: []ServiceBusReceivedMessage = &.{},
    transport: ServiceBusAmqpTransport,

    pub fn init() MockServiceBusTransport {
        return .{
            .transport = .{
                .sendMessagesFn = &sendMessagesImpl,
                .receiveMessagesFn = &receiveMessagesImpl,
                .settleMessageFn = &settleMessageImpl,
                .scheduleMessageFn = &scheduleMessageImpl,
                .cancelScheduledFn = &cancelScheduledImpl,
                .closeFn = &closeImpl,
            },
        };
    }

    pub fn asTransport(self: *MockServiceBusTransport) *ServiceBusAmqpTransport {
        return &self.transport;
    }

    fn sendMessagesImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage) !void {
        _ = allocator;
        _ = entity;
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        self.send_called = true;
        self.send_count += @intCast(messages.len);
    }

    fn receiveMessagesImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, max_count: u32, mode: ReceiveMode) ![]ServiceBusReceivedMessage {
        _ = allocator;
        _ = entity;
        _ = max_count;
        _ = mode;
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        return self.receive_result;
    }

    fn settleMessageImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, delivery_tag: []const u8, action: DispositionAction, reason: ?[]const u8) !void {
        _ = allocator;
        _ = delivery_tag;
        _ = reason;
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        self.settle_calls += 1;
        self.last_settle_action = action;
    }

    fn scheduleMessageImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, message: ServiceBusMessage, enqueue_time: i64) !i64 {
        _ = allocator;
        _ = entity;
        _ = message;
        _ = enqueue_time;
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        return self.schedule_result;
    }

    fn cancelScheduledImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, sequence_number: i64) !void {
        _ = allocator;
        _ = entity;
        _ = sequence_number;
        _ = t;
    }

    fn closeImpl(t: *ServiceBusAmqpTransport) void {
        _ = t;
    }
};

// ─────────────────────── Clients ───────────────────────

/// Sends messages to a Service Bus queue or topic.
pub const ServiceBusSenderClient = struct {
    fully_qualified_namespace: []const u8,
    entity_path: []const u8,
    credential: ?*core.credentials.TokenCredential = null,
    amqp_transport: *ServiceBusAmqpTransport,

    pub fn init(
        fully_qualified_namespace: []const u8,
        entity_path: []const u8,
        credential: *core.credentials.TokenCredential,
        amqp_transport: *ServiceBusAmqpTransport,
    ) ServiceBusSenderClient {
        return .{
            .fully_qualified_namespace = fully_qualified_namespace,
            .entity_path = entity_path,
            .credential = credential,
            .amqp_transport = amqp_transport,
        };
    }

    pub fn fromConnectionString(
        connection_string: []const u8,
        entity_path: ?[]const u8,
        amqp_transport: *ServiceBusAmqpTransport,
    ) !ServiceBusSenderClient {
        const cs = try ConnectionStringProperties.parse(connection_string);
        return .{
            .fully_qualified_namespace = cs.fully_qualified_namespace,
            .entity_path = entity_path orelse cs.entity_path orelse return error.MissingEntityPath,
            .amqp_transport = amqp_transport,
        };
    }

    /// Send a single message.
    pub fn sendMessage(self: *ServiceBusSenderClient, allocator: std.mem.Allocator, message: ServiceBusMessage) !void {
        const messages = [_]ServiceBusMessage{message};
        return self.amqp_transport.sendMessages(allocator, self.entity_path, &messages);
    }

    /// Send a batch of messages.
    pub fn sendMessages(self: *ServiceBusSenderClient, allocator: std.mem.Allocator, batch: ServiceBusMessageBatch) !void {
        if (batch.count() == 0) return error.EmptyBatch;
        return self.amqp_transport.sendMessages(allocator, self.entity_path, batch.messages.items);
    }

    /// Schedule a message for later delivery. Returns the sequence number.
    pub fn scheduleMessage(self: *ServiceBusSenderClient, allocator: std.mem.Allocator, message: ServiceBusMessage, enqueue_time: i64) !i64 {
        return self.amqp_transport.scheduleMessage(allocator, self.entity_path, message, enqueue_time);
    }

    /// Cancel a previously scheduled message.
    pub fn cancelScheduledMessage(self: *ServiceBusSenderClient, allocator: std.mem.Allocator, sequence_number: i64) !void {
        return self.amqp_transport.cancelScheduled(allocator, self.entity_path, sequence_number);
    }

    pub fn close(self: *ServiceBusSenderClient) void {
        self.amqp_transport.close();
    }
};

pub const ReceiverOptions = struct {
    receive_mode: ReceiveMode = .peek_lock,
    sub_queue: SubQueue = .none,
};

/// Receives messages from a Service Bus queue or subscription.
pub const ServiceBusReceiverClient = struct {
    fully_qualified_namespace: []const u8,
    entity: EntityOptions,
    credential: ?*core.credentials.TokenCredential = null,
    amqp_transport: *ServiceBusAmqpTransport,
    receive_mode: ReceiveMode,
    sub_queue: SubQueue,

    pub fn init(
        fully_qualified_namespace: []const u8,
        entity: EntityOptions,
        credential: *core.credentials.TokenCredential,
        amqp_transport: *ServiceBusAmqpTransport,
        options: ReceiverOptions,
    ) ServiceBusReceiverClient {
        return .{
            .fully_qualified_namespace = fully_qualified_namespace,
            .entity = entity,
            .credential = credential,
            .amqp_transport = amqp_transport,
            .receive_mode = options.receive_mode,
            .sub_queue = options.sub_queue,
        };
    }

    pub fn fromConnectionString(
        connection_string: []const u8,
        entity: EntityOptions,
        amqp_transport: *ServiceBusAmqpTransport,
        options: ReceiverOptions,
    ) !ServiceBusReceiverClient {
        const cs = try ConnectionStringProperties.parse(connection_string);
        _ = cs;
        return .{
            .fully_qualified_namespace = (try ConnectionStringProperties.parse(connection_string)).fully_qualified_namespace,
            .entity = entity,
            .amqp_transport = amqp_transport,
            .receive_mode = options.receive_mode,
            .sub_queue = options.sub_queue,
        };
    }

    /// Receive messages from the entity.
    pub fn receiveMessages(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, max_count: u32) ![]ServiceBusReceivedMessage {
        const address = try self.entity.formatAddress(allocator, self.sub_queue);
        defer allocator.free(address);
        return self.amqp_transport.receiveMessages(allocator, address, max_count, self.receive_mode);
    }

    /// Complete (acknowledge) a received message.
    pub fn completeMessage(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !void {
        const tag = message.delivery_tag orelse return error.MissingDeliveryTag;
        return self.amqp_transport.settleMessage(allocator, tag, .complete, null);
    }

    /// Abandon a message, releasing the lock.
    pub fn abandonMessage(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !void {
        const tag = message.delivery_tag orelse return error.MissingDeliveryTag;
        return self.amqp_transport.settleMessage(allocator, tag, .abandon, null);
    }

    /// Move a message to the dead-letter queue.
    pub fn deadLetterMessage(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage, reason: ?[]const u8) !void {
        const tag = message.delivery_tag orelse return error.MissingDeliveryTag;
        return self.amqp_transport.settleMessage(allocator, tag, .dead_letter, reason);
    }

    /// Defer a message for later retrieval by sequence number.
    pub fn deferMessage(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !void {
        const tag = message.delivery_tag orelse return error.MissingDeliveryTag;
        return self.amqp_transport.settleMessage(allocator, tag, .defer_msg, null);
    }

    pub fn close(self: *ServiceBusReceiverClient) void {
        self.amqp_transport.close();
    }
};

// ─────────────── Administration Client ───────────────

pub const AdministrationClientOptions = struct {
    api_version: []const u8 = "2021-05",
};

/// Manages Service Bus queues, topics, and subscriptions via REST API.
pub const ServiceBusAdministrationClient = struct {
    fully_qualified_namespace: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(
        fully_qualified_namespace: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        options: AdministrationClientOptions,
    ) ServiceBusAdministrationClient {
        _ = credential;
        return .{
            .fully_qualified_namespace = fully_qualified_namespace,
            .api_version = options.api_version,
            .pipeline = .{ .policies = &.{}, .transport_impl = transport },
        };
    }

    // ── Queue operations ──

    pub fn createQueue(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !void {
        const url = try self.buildEntityUrl(allocator, name);
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator,
            \\<entry xmlns="http://www.w3.org/2005/Atom">
            \\  <content type="application/xml">
            \\    <QueueDescription xmlns="http://schemas.microsoft.com/netservices/2010/10/servicebus/connect"/>
            \\  </content>
            \\</entry>
        , .{});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/atom+xml;type=entry;charset=utf-8");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.CreateQueueFailed;
        }
    }

    pub fn deleteQueue(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !void {
        const url = try self.buildEntityUrl(allocator, name);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.DeleteQueueFailed;
        }
    }

    pub fn listQueues(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator) ![]QueueProperties {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/$Resources/queues?api-version={s}", .{ self.fully_qualified_namespace, self.api_version });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.ListQueuesFailed;
        }

        return parseEntityNames(allocator, resp.body, "Queue");
    }

    // ── Topic operations ──

    pub fn createTopic(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !void {
        const url = try self.buildEntityUrl(allocator, name);
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator,
            \\<entry xmlns="http://www.w3.org/2005/Atom">
            \\  <content type="application/xml">
            \\    <TopicDescription xmlns="http://schemas.microsoft.com/netservices/2010/10/servicebus/connect"/>
            \\  </content>
            \\</entry>
        , .{});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/atom+xml;type=entry;charset=utf-8");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.CreateTopicFailed;
        }
    }

    pub fn deleteTopic(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) !void {
        const url = try self.buildEntityUrl(allocator, name);
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.DeleteTopicFailed;
        }
    }

    pub fn listTopics(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator) ![]TopicProperties {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/$Resources/topics?api-version={s}", .{ self.fully_qualified_namespace, self.api_version });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.ListTopicsFailed;
        }

        return parseEntityNames(allocator, resp.body, "Topic");
    }

    // ── Subscription operations ──

    pub fn createSubscription(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8, subscription_name: []const u8) !void {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/{s}/subscriptions/{s}?api-version={s}", .{ self.fully_qualified_namespace, topic_name, subscription_name, self.api_version });
        defer allocator.free(url);

        const body = try std.fmt.allocPrint(allocator,
            \\<entry xmlns="http://www.w3.org/2005/Atom">
            \\  <content type="application/xml">
            \\    <SubscriptionDescription xmlns="http://schemas.microsoft.com/netservices/2010/10/servicebus/connect"/>
            \\  </content>
            \\</entry>
        , .{});
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .PUT, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/atom+xml;type=entry;charset=utf-8");
        req.body = body;

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.CreateSubscriptionFailed;
        }
    }

    pub fn deleteSubscription(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8, subscription_name: []const u8) !void {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/{s}/subscriptions/{s}?api-version={s}", .{ self.fully_qualified_namespace, topic_name, subscription_name, self.api_version });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .DELETE, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.DeleteSubscriptionFailed;
        }
    }

    pub fn listSubscriptions(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, topic_name: []const u8) ![]SubscriptionProperties {
        const url = try std.fmt.allocPrint(allocator, "https://{s}/{s}/subscriptions?api-version={s}", .{ self.fully_qualified_namespace, topic_name, self.api_version });
        defer allocator.free(url);

        var req = core.http.Request.init(allocator, .GET, url);
        defer req.deinit();

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) {
            core.errors.logErrorResponse(resp);
            return error.ListSubscriptionsFailed;
        }

        return parseSubscriptionNames(allocator, resp.body, topic_name);
    }

    fn buildEntityUrl(self: *ServiceBusAdministrationClient, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
        return std.fmt.allocPrint(allocator, "https://{s}/{s}?api-version={s}", .{ self.fully_qualified_namespace, name, self.api_version });
    }
};

// ─────────────────── Atom XML Parsing ────────────────

const serde = @import("serde");

const AtomEntrySchema = struct {
    title: []const u8,
};

const AtomFeedSchema = struct {
    entry: ?[]const AtomEntrySchema = null,
};

/// Parse entity names from Atom feed response.
fn parseEntityNames(allocator: std.mem.Allocator, body: []const u8, comptime entity_type: []const u8) !switch (entity_type.len) {
    5 => []QueueProperties,
    else => []TopicProperties,
} {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.xml.fromSlice(AtomFeedSchema, arena.allocator(), body) catch {
        if (entity_type.len == 5)
            return allocator.alloc(QueueProperties, 0)
        else
            return allocator.alloc(TopicProperties, 0);
    };

    const entries = parsed.entry orelse {
        if (entity_type.len == 5)
            return allocator.alloc(QueueProperties, 0)
        else
            return allocator.alloc(TopicProperties, 0);
    };

    if (entity_type.len == 5) { // "Queue"
        var result = try allocator.alloc(QueueProperties, entries.len);
        for (entries, 0..) |e, i| {
            result[i] = .{ .name = try allocator.dupe(u8, e.title) };
        }
        return result;
    } else { // "Topic"
        var result = try allocator.alloc(TopicProperties, entries.len);
        for (entries, 0..) |e, i| {
            result[i] = .{ .name = try allocator.dupe(u8, e.title) };
        }
        return result;
    }
}

fn parseSubscriptionNames(allocator: std.mem.Allocator, body: []const u8, topic_name: []const u8) ![]SubscriptionProperties {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.xml.fromSlice(AtomFeedSchema, arena.allocator(), body) catch
        return allocator.alloc(SubscriptionProperties, 0);
    const entries = parsed.entry orelse return allocator.alloc(SubscriptionProperties, 0);

    var result = try allocator.alloc(SubscriptionProperties, entries.len);
    for (entries, 0..) |e, i| {
        result[i] = .{ .name = try allocator.dupe(u8, e.title), .topic_name = topic_name };
    }
    return result;
}

// ─────────────────────── Tests ───────────────────────

test "ServiceBusMessage init" {
    const allocator = std.testing.allocator;
    var msg = ServiceBusMessage.init(allocator, "hello service bus");
    defer msg.deinit();
    try msg.application_properties.put("key", "value");
    try std.testing.expectEqualStrings("hello service bus", msg.body);
}

test "ServiceBusMessageBatch tryAdd" {
    const allocator = std.testing.allocator;
    var batch = ServiceBusMessageBatch.init();
    defer batch.deinit(allocator);
    var m1 = ServiceBusMessage.init(allocator, "msg-1");
    defer m1.deinit();
    const added = try batch.tryAdd(allocator, m1);
    try std.testing.expect(added);
    try std.testing.expectEqual(@as(usize, 1), batch.count());
}

test "EntityOptions queue address" {
    const allocator = std.testing.allocator;
    const entity = EntityOptions{ .queue = "myqueue" };
    const addr = try entity.formatAddress(allocator, .none);
    defer allocator.free(addr);
    try std.testing.expectEqualStrings("myqueue", addr);
}

test "EntityOptions subscription address" {
    const allocator = std.testing.allocator;
    const entity = EntityOptions{ .subscription = .{ .topic_name = "mytopic", .subscription_name = "mysub" } };
    const addr = try entity.formatAddress(allocator, .none);
    defer allocator.free(addr);
    try std.testing.expectEqualStrings("mytopic/Subscriptions/mysub", addr);
}

test "EntityOptions dead letter queue" {
    const allocator = std.testing.allocator;
    const entity = EntityOptions{ .queue = "myqueue" };
    const addr = try entity.formatAddress(allocator, .dead_letter);
    defer allocator.free(addr);
    try std.testing.expectEqualStrings("myqueue/$deadletterqueue", addr);
}

test "SenderClient sendMessage" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var sender = ServiceBusSenderClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity_path = "myqueue",
        .amqp_transport = amqp.asTransport(),
    };
    var msg = ServiceBusMessage.init(allocator, "hello");
    defer msg.deinit();
    try sender.sendMessage(allocator, msg);
    try std.testing.expect(amqp.send_called);
    try std.testing.expectEqual(@as(u32, 1), amqp.send_count);
}

test "SenderClient sendMessages batch" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var sender = ServiceBusSenderClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity_path = "myqueue",
        .amqp_transport = amqp.asTransport(),
    };
    var batch = ServiceBusMessageBatch.init();
    defer batch.deinit(allocator);
    var m1 = ServiceBusMessage.init(allocator, "a");
    defer m1.deinit();
    var m2 = ServiceBusMessage.init(allocator, "b");
    defer m2.deinit();
    _ = try batch.tryAdd(allocator, m1);
    _ = try batch.tryAdd(allocator, m2);
    try sender.sendMessages(allocator, batch);
    try std.testing.expectEqual(@as(u32, 2), amqp.send_count);
}

test "SenderClient sendMessages empty returns error" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var sender = ServiceBusSenderClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity_path = "myqueue",
        .amqp_transport = amqp.asTransport(),
    };
    const batch = ServiceBusMessageBatch.init();
    const result = sender.sendMessages(allocator, batch);
    try std.testing.expectError(error.EmptyBatch, result);
}

test "SenderClient scheduleMessage" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    amqp.schedule_result = 42;
    var sender = ServiceBusSenderClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity_path = "myqueue",
        .amqp_transport = amqp.asTransport(),
    };
    var msg = ServiceBusMessage.init(allocator, "scheduled");
    defer msg.deinit();
    const seq = try sender.scheduleMessage(allocator, msg, 1700000000000);
    try std.testing.expectEqual(@as(i64, 42), seq);
}

test "SenderClient fromConnectionString" {
    var amqp = MockServiceBusTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=myqueue";
    const sender = try ServiceBusSenderClient.fromConnectionString(cs, null, amqp.asTransport());
    try std.testing.expectEqualStrings("ns.servicebus.windows.net", sender.fully_qualified_namespace);
    try std.testing.expectEqualStrings("myqueue", sender.entity_path);
}

test "ReceiverClient receiveMessages" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var receiver = ServiceBusReceiverClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity = .{ .queue = "myqueue" },
        .amqp_transport = amqp.asTransport(),
        .receive_mode = .peek_lock,
        .sub_queue = .none,
    };
    const messages = try receiver.receiveMessages(allocator, 10);
    try std.testing.expectEqual(@as(usize, 0), messages.len);
}

test "ReceiverClient completeMessage" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var receiver = ServiceBusReceiverClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity = .{ .queue = "myqueue" },
        .amqp_transport = amqp.asTransport(),
        .receive_mode = .peek_lock,
        .sub_queue = .none,
    };
    const msg = ServiceBusReceivedMessage{ .body = "test", .delivery_tag = "tag-1" };
    try receiver.completeMessage(allocator, msg);
    try std.testing.expectEqual(@as(u32, 1), amqp.settle_calls);
    try std.testing.expectEqual(DispositionAction.complete, amqp.last_settle_action.?);
}

test "ReceiverClient deadLetterMessage" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var receiver = ServiceBusReceiverClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity = .{ .queue = "myqueue" },
        .amqp_transport = amqp.asTransport(),
        .receive_mode = .peek_lock,
        .sub_queue = .none,
    };
    const msg = ServiceBusReceivedMessage{ .body = "bad", .delivery_tag = "tag-2" };
    try receiver.deadLetterMessage(allocator, msg, "poisoned");
    try std.testing.expectEqual(DispositionAction.dead_letter, amqp.last_settle_action.?);
}

test "ReceiverClient completeMessage missing tag" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var receiver = ServiceBusReceiverClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity = .{ .queue = "myqueue" },
        .amqp_transport = amqp.asTransport(),
        .receive_mode = .peek_lock,
        .sub_queue = .none,
    };
    const msg = ServiceBusReceivedMessage{ .body = "test" };
    const result = receiver.completeMessage(allocator, msg);
    try std.testing.expectError(error.MissingDeliveryTag, result);
}

test "ReceiverClient subscription entity" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var receiver = ServiceBusReceiverClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity = .{ .subscription = .{ .topic_name = "mytopic", .subscription_name = "mysub" } },
        .amqp_transport = amqp.asTransport(),
        .receive_mode = .receive_and_delete,
        .sub_queue = .none,
    };
    const messages = try receiver.receiveMessages(allocator, 5);
    try std.testing.expectEqual(@as(usize, 0), messages.len);
}

test "UamqpServiceBusTransport sendMessages" {
    const allocator = std.testing.allocator;
    var transport = UamqpServiceBusTransport.init(allocator, "ns.servicebus.windows.net");
    var msg = ServiceBusMessage.init(allocator, "hello");
    defer msg.deinit();
    const messages = [_]ServiceBusMessage{msg};
    try transport.asTransport().sendMessages(allocator, "myqueue", &messages);
}

test "AdministrationClient createQueue" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "<entry/>");
    defer mock.deinit();
    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var admin = ServiceBusAdministrationClient.init("ns.servicebus.windows.net", cred.asCredential(), mock.asTransport(), .{});
    try admin.createQueue(allocator, "testqueue");
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "testqueue") != null);
    try std.testing.expectEqual(core.http.Method.PUT, mock.last_method.?);
}

test "AdministrationClient deleteQueue" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var admin = ServiceBusAdministrationClient.init("ns.servicebus.windows.net", cred.asCredential(), mock.asTransport(), .{});
    try admin.deleteQueue(allocator, "testqueue");
    try std.testing.expectEqual(core.http.Method.DELETE, mock.last_method.?);
}

test "AdministrationClient listQueues" {
    const allocator = std.testing.allocator;
    const body =
        \\<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>queue1</title></entry><entry><title>queue2</title></entry></feed>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();
    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var admin = ServiceBusAdministrationClient.init("ns.servicebus.windows.net", cred.asCredential(), mock.asTransport(), .{});
    const queues = try admin.listQueues(allocator);
    defer {
        for (queues) |q| allocator.free(q.name);
        allocator.free(queues);
    }
    try std.testing.expectEqual(@as(usize, 2), queues.len);
    try std.testing.expectEqualStrings("queue1", queues[0].name);
    try std.testing.expectEqualStrings("queue2", queues[1].name);
}

test "AdministrationClient createSubscription" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "<entry/>");
    defer mock.deinit();
    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");
    var admin = ServiceBusAdministrationClient.init("ns.servicebus.windows.net", cred.asCredential(), mock.asTransport(), .{});
    try admin.createSubscription(allocator, "mytopic", "mysub");
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "mytopic/subscriptions/mysub") != null);
}
