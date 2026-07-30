//! Azure Service Bus client — sender, receiver, and administration.
//!
//! Messaging runs over `azure_sdk_amqp`, the same AMQP 1.0 stack Event Hubs
//! uses, so both packages share one connection driver, link implementation,
//! credit window, and settlement path. Administration runs over the
//! `azure_sdk_core` HTTP pipeline.
const std = @import("std");
const messaging_common = @import("azure_sdk_messaging_common");

pub const ConnectionStringProperties = messaging_common.ConnectionStringProperties;

pub const message_codec = @import("message.zig");
pub const admin = @import("admin.zig");
pub const management = @import("management.zig");
pub const transport = @import("amqp_transport.zig");

// The real AMQP transport, re-exported so a consumer only imports the package.
pub const AmqpTransport = transport.AmqpTransport;
pub const Credential = transport.Credential;
pub const ConnectionOptions = transport.ConnectionOptions;
pub const CustomEndpoint = transport.CustomEndpoint;
pub const TlsSettings = transport.TlsSettings;

// Administration surface, re-exported so a consumer only imports the package.
pub const QueueProperties = admin.QueueProperties;
pub const TopicProperties = admin.TopicProperties;
pub const SubscriptionProperties = admin.SubscriptionProperties;
pub const AdministrationClientOptions = admin.AdministrationClientOptions;
pub const ServiceBusAdministrationClient = admin.ServiceBusAdministrationClient;

// Message codec surface.
pub const toAmqpMessage = message_codec.toAmqpMessage;
pub const encodeMessage = message_codec.encode;
pub const fromAmqpMessage = message_codec.fromAmqpMessage;
pub const annotation = message_codec.annotation;
pub const application_property = message_codec.application_property;
pub const annotationOf = message_codec.annotationOf;
pub const applicationPropertyOf = message_codec.applicationPropertyOf;

// Zig only analyses a file something references, so the re-exports above are
// not enough to make these files' tests run.
test {
    _ = message_codec;
    _ = admin;
    _ = management;
    _ = transport;
}

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
///
/// Every slice borrows from the `ReceivedMessages` batch the message came in,
/// so a received message is valid exactly as long as that batch is. See
/// `message.zig`.
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
    /// When the peek-lock on this message expires, in milliseconds since the
    /// epoch. Absent in `receive_and_delete` mode, where there is no lock.
    locked_until: ?i64 = null,
    partition_key: ?[]const u8 = null,
    delivery_count: ?u32 = null,
    dead_letter_source: ?[]const u8 = null,
    dead_letter_reason: ?[]const u8 = null,
    dead_letter_description: ?[]const u8 = null,
    /// The message's application properties, exactly as they arrived.
    ///
    /// Left as AMQP fields rather than copied into a map: a map would cost an
    /// allocation on every received message, and Service Bus allows typed
    /// values that a string map could not hold. Read them with
    /// `applicationPropertyOf`.
    application_properties: ?message_codec.Fields = null,
    /// Opaque delivery tag, which for Service Bus is the message's lock
    /// token. Carried for the management operations that take one, such as
    /// renewing a lock.
    delivery_tag: ?[]const u8 = null,
    /// The AMQP delivery id, which is what a disposition names.
    ///
    /// Settlement works on ids rather than tags: a disposition covers a
    /// `first`..`last` range (§2.7.6), so a whole batch settles in one frame
    /// where tags would need one lookup and one frame each.
    delivery_id: ?u32 = null,
    /// The entity this message was received from, so settlement can find the
    /// link it arrived on. Owned by the batch, like every other slice here.
    entity: ?[]const u8 = null,
};

/// A batch of received messages and the storage they were decoded into.
///
/// The batch owns an arena and every message points into it, so releasing one
/// message is not a thing that can be done — free the batch when the last of
/// its messages has been settled or copied out.
///
/// A batch owning its own arena, rather than the transport reusing one across
/// calls, is what makes it safe to receive again while an earlier batch is
/// still in hand: settlement happens after processing, and a shared arena
/// would turn the second receive into a silent overwrite of the first batch.
pub const ReceivedMessages = struct {
    messages: []ServiceBusReceivedMessage = &.{},
    /// Null for a batch that allocated nothing, including every empty one.
    arena: ?*std.heap.ArenaAllocator = null,

    pub fn deinit(self: *ReceivedMessages) void {
        if (self.arena) |arena| {
            const child = arena.child_allocator;
            arena.deinit();
            child.destroy(arena);
        }
        self.* = .{};
    }

    pub fn count(self: ReceivedMessages) usize {
        return self.messages.len;
    }
};

/// What to record on a message being moved to the dead-letter queue.
///
/// Both land in the rejection's `info` map, where the broker copies them onto
/// the dead-lettered message as `DeadLetterReason` and
/// `DeadLetterErrorDescription`.
pub const DeadLetterOptions = struct {
    reason: ?[]const u8 = null,
    error_description: ?[]const u8 = null,
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

// ─────────────── AMQP Transport ─────────────────────

/// Internal transport interface for Service Bus AMQP operations.
pub const ServiceBusAmqpTransport = struct {
    sendMessagesFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage) anyerror!void,
    receiveMessagesFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, max_count: u32, mode: ReceiveMode) anyerror!ReceivedMessages,
    /// Settle a run of messages in one go.
    ///
    /// Takes a slice rather than a message at a time because a disposition
    /// names a range: settling a drained prefetch window one call at a time
    /// costs a frame per message. Messages need not share an entity — the
    /// implementation is expected to break the run wherever they do not.
    settleMessagesFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, messages: []const ServiceBusReceivedMessage, action: DispositionAction, dead_letter: DeadLetterOptions) anyerror!void,
    /// Schedule a run of messages, writing one sequence number per message
    /// into `out` and returning how many were written.
    ///
    /// Writes into a caller slice rather than returning an allocation because
    /// the count is known before the call — it is `messages.len` — so the
    /// common case of scheduling one message needs no allocation at all.
    scheduleMessagesFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage, enqueue_time: i64, out: []i64) anyerror!usize,
    /// Cancel a run of scheduled messages by sequence number.
    cancelScheduledFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, sequence_numbers: []const i64) anyerror!void,
    /// Renew the peek-lock on `message`, returning when the new lock expires
    /// in milliseconds since the epoch.
    ///
    /// Takes the whole message rather than a token because the renewal needs
    /// both the lock token, which is the delivery tag, and the entity the
    /// message arrived from.
    renewMessageLockFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) anyerror!i64,
    /// Read up to `max_count` messages from `from_sequence_number` onwards
    /// without locking or removing any of them.
    peekMessagesFn: *const fn (self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, from_sequence_number: i64, max_count: u32) anyerror!ReceivedMessages,
    closeFn: *const fn (self: *ServiceBusAmqpTransport) void,

    pub fn sendMessages(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage) !void {
        return self.sendMessagesFn(self, allocator, entity, messages);
    }

    pub fn receiveMessages(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, max_count: u32, mode: ReceiveMode) !ReceivedMessages {
        return self.receiveMessagesFn(self, allocator, entity, max_count, mode);
    }

    pub fn settleMessages(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, messages: []const ServiceBusReceivedMessage, action: DispositionAction, dead_letter: DeadLetterOptions) !void {
        return self.settleMessagesFn(self, allocator, messages, action, dead_letter);
    }

    pub fn scheduleMessages(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage, enqueue_time: i64, out: []i64) !usize {
        return self.scheduleMessagesFn(self, allocator, entity, messages, enqueue_time, out);
    }

    pub fn cancelScheduled(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, sequence_numbers: []const i64) !void {
        return self.cancelScheduledFn(self, allocator, entity, sequence_numbers);
    }

    pub fn renewMessageLock(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !i64 {
        return self.renewMessageLockFn(self, allocator, message);
    }

    pub fn peekMessages(self: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, from_sequence_number: i64, max_count: u32) !ReceivedMessages {
        return self.peekMessagesFn(self, allocator, entity, from_sequence_number, max_count);
    }

    pub fn close(self: *ServiceBusAmqpTransport) void {
        self.closeFn(self);
    }
};

/// Mock AMQP transport for unit testing.
pub const MockServiceBusTransport = struct {
    send_called: bool = false,
    send_count: u32 = 0,
    settle_calls: u32 = 0,
    settled_messages: u32 = 0,
    last_settle_action: ?DispositionAction = null,
    last_dead_letter: DeadLetterOptions = .{},
    schedule_result: i64 = 1001,
    scheduled_count: u32 = 0,
    cancelled_count: u32 = 0,
    renew_result: i64 = 0,
    renew_calls: u32 = 0,
    last_peek_from: i64 = 0,
    last_peek_count: u32 = 0,
    receive_result: []ServiceBusReceivedMessage = &.{},
    peek_result: []ServiceBusReceivedMessage = &.{},
    transport: ServiceBusAmqpTransport,

    pub fn init() MockServiceBusTransport {
        return .{
            .transport = .{
                .sendMessagesFn = &sendMessagesImpl,
                .receiveMessagesFn = &receiveMessagesImpl,
                .settleMessagesFn = &settleMessagesImpl,
                .scheduleMessagesFn = &scheduleMessagesImpl,
                .cancelScheduledFn = &cancelScheduledImpl,
                .renewMessageLockFn = &renewMessageLockImpl,
                .peekMessagesFn = &peekMessagesImpl,
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

    fn receiveMessagesImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, max_count: u32, mode: ReceiveMode) !ReceivedMessages {
        _ = allocator;
        _ = entity;
        _ = max_count;
        _ = mode;
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        // No arena: the result is the caller's own fixture, so `deinit` on
        // the batch must not try to free it.
        return .{ .messages = self.receive_result };
    }

    fn settleMessagesImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, messages: []const ServiceBusReceivedMessage, action: DispositionAction, dead_letter: DeadLetterOptions) !void {
        _ = allocator;
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        self.settle_calls += 1;
        self.settled_messages += @intCast(messages.len);
        self.last_settle_action = action;
        self.last_dead_letter = dead_letter;
    }

    fn scheduleMessagesImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, messages: []const ServiceBusMessage, enqueue_time: i64, out: []i64) !usize {
        _ = .{ allocator, entity, enqueue_time };
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        const n = @min(messages.len, out.len);
        for (out[0..n], 0..) |*slot, i| slot.* = self.schedule_result + @as(i64, @intCast(i));
        self.scheduled_count += @intCast(messages.len);
        return n;
    }

    fn cancelScheduledImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, sequence_numbers: []const i64) !void {
        _ = .{ allocator, entity };
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        self.cancelled_count += @intCast(sequence_numbers.len);
    }

    fn renewMessageLockImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !i64 {
        _ = .{ allocator, message };
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        self.renew_calls += 1;
        return self.renew_result;
    }

    fn peekMessagesImpl(t: *ServiceBusAmqpTransport, allocator: std.mem.Allocator, entity: []const u8, from_sequence_number: i64, max_count: u32) !ReceivedMessages {
        _ = .{ allocator, entity };
        const self: *MockServiceBusTransport = @fieldParentPtr("transport", t);
        self.last_peek_from = from_sequence_number;
        self.last_peek_count = max_count;
        // No arena, as in `receiveMessagesImpl`: the result is the caller's
        // own fixture and `deinit` must not try to free it.
        return .{ .messages = self.peek_result };
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
    amqp_transport: *ServiceBusAmqpTransport,

    pub fn init(
        fully_qualified_namespace: []const u8,
        entity_path: []const u8,
        amqp_transport: *ServiceBusAmqpTransport,
    ) ServiceBusSenderClient {
        return .{
            .fully_qualified_namespace = fully_qualified_namespace,
            .entity_path = entity_path,
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
        var out: [1]i64 = undefined;
        const n = try self.scheduleMessages(allocator, &.{message}, enqueue_time, &out);
        if (n != 1) return error.MalformedReply;
        return out[0];
    }

    /// Schedule a run of messages, writing one sequence number per message
    /// into `out` and returning how many were written.
    ///
    /// One round trip for the whole run, where calling `scheduleMessage` per
    /// message costs one each.
    pub fn scheduleMessages(
        self: *ServiceBusSenderClient,
        allocator: std.mem.Allocator,
        messages: []const ServiceBusMessage,
        enqueue_time: i64,
        out: []i64,
    ) !usize {
        return self.amqp_transport.scheduleMessages(allocator, self.entity_path, messages, enqueue_time, out);
    }

    /// Cancel a previously scheduled message.
    pub fn cancelScheduledMessage(self: *ServiceBusSenderClient, allocator: std.mem.Allocator, sequence_number: i64) !void {
        return self.cancelScheduledMessages(allocator, &.{sequence_number});
    }

    /// Cancel a run of previously scheduled messages in one round trip.
    pub fn cancelScheduledMessages(self: *ServiceBusSenderClient, allocator: std.mem.Allocator, sequence_numbers: []const i64) !void {
        return self.amqp_transport.cancelScheduled(allocator, self.entity_path, sequence_numbers);
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
    amqp_transport: *ServiceBusAmqpTransport,
    receive_mode: ReceiveMode,
    sub_queue: SubQueue,

    pub fn init(
        fully_qualified_namespace: []const u8,
        entity: EntityOptions,
        amqp_transport: *ServiceBusAmqpTransport,
        options: ReceiverOptions,
    ) ServiceBusReceiverClient {
        return .{
            .fully_qualified_namespace = fully_qualified_namespace,
            .entity = entity,
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
        return .{
            .fully_qualified_namespace = cs.fully_qualified_namespace,
            .entity = entity,
            .amqp_transport = amqp_transport,
            .receive_mode = options.receive_mode,
            .sub_queue = options.sub_queue,
        };
    }

    /// Receive up to `max_count` messages from the entity.
    ///
    /// Free the result with `ReceivedMessages.deinit`; every message in it
    /// borrows from the batch.
    pub fn receiveMessages(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, max_count: u32) !ReceivedMessages {
        const address = try self.entity.formatAddress(allocator, self.sub_queue);
        defer allocator.free(address);
        return self.amqp_transport.receiveMessages(allocator, address, max_count, self.receive_mode);
    }

    /// Settle a run of messages with one disposition where they allow it.
    ///
    /// The single-message helpers below are this with a one-element slice, so
    /// a caller draining a batch should prefer this: it is the difference
    /// between one frame and one per message.
    pub fn settleMessages(
        self: *ServiceBusReceiverClient,
        allocator: std.mem.Allocator,
        messages: []const ServiceBusReceivedMessage,
        action: DispositionAction,
        dead_letter: DeadLetterOptions,
    ) !void {
        return self.amqp_transport.settleMessages(allocator, messages, action, dead_letter);
    }

    /// Complete (acknowledge) a received message.
    pub fn completeMessage(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !void {
        return self.settleMessages(allocator, &.{message}, .complete, .{});
    }

    /// Abandon a message, releasing the lock.
    pub fn abandonMessage(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !void {
        return self.settleMessages(allocator, &.{message}, .abandon, .{});
    }

    /// Move a message to the dead-letter queue.
    pub fn deadLetterMessage(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage, options: DeadLetterOptions) !void {
        return self.settleMessages(allocator, &.{message}, .dead_letter, options);
    }

    /// Defer a message for later retrieval by sequence number.
    pub fn deferMessage(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !void {
        return self.settleMessages(allocator, &.{message}, .defer_msg, .{});
    }

    /// Extend the peek-lock on a message, returning when the new lock expires
    /// in milliseconds since the epoch.
    ///
    /// Only meaningful in `peek_lock` mode; `receive_and_delete` takes no lock
    /// to renew.
    pub fn renewMessageLock(self: *ServiceBusReceiverClient, allocator: std.mem.Allocator, message: ServiceBusReceivedMessage) !i64 {
        return self.amqp_transport.renewMessageLock(allocator, message);
    }

    /// Read up to `max_count` messages from `from_sequence_number` onwards
    /// without locking or removing them.
    ///
    /// Peeking does not settle, so a peeked message cannot be completed or
    /// abandoned — it carries no delivery id. To act on one, receive it.
    /// Free the result with `ReceivedMessages.deinit`.
    pub fn peekMessages(
        self: *ServiceBusReceiverClient,
        allocator: std.mem.Allocator,
        from_sequence_number: i64,
        max_count: u32,
    ) !ReceivedMessages {
        const address = try self.entity.formatAddress(allocator, self.sub_queue);
        defer allocator.free(address);
        return self.amqp_transport.peekMessages(allocator, address, from_sequence_number, max_count);
    }

    pub fn close(self: *ServiceBusReceiverClient) void {
        self.amqp_transport.close();
    }
};

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
    var messages = try receiver.receiveMessages(allocator, 10);
    defer messages.deinit();
    try std.testing.expectEqual(@as(usize, 0), messages.count());
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
    try receiver.deadLetterMessage(allocator, msg, .{ .reason = "poisoned", .error_description = "unparseable body" });
    try std.testing.expectEqual(DispositionAction.dead_letter, amqp.last_settle_action.?);
    try std.testing.expectEqualStrings("poisoned", amqp.last_dead_letter.reason.?);
    try std.testing.expectEqualStrings("unparseable body", amqp.last_dead_letter.error_description.?);
}

test "settling a run of messages is one call, not one per message" {
    const allocator = std.testing.allocator;
    var amqp = MockServiceBusTransport.init();
    var receiver = ServiceBusReceiverClient{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .entity = .{ .queue = "myqueue" },
        .amqp_transport = amqp.asTransport(),
        .receive_mode = .peek_lock,
        .sub_queue = .none,
    };
    const batch = [_]ServiceBusReceivedMessage{
        .{ .body = "a", .delivery_id = 0 },
        .{ .body = "b", .delivery_id = 1 },
        .{ .body = "c", .delivery_id = 2 },
    };
    try receiver.settleMessages(allocator, &batch, .complete, .{});
    try std.testing.expectEqual(@as(u32, 1), amqp.settle_calls);
    try std.testing.expectEqual(@as(u32, 3), amqp.settled_messages);
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
    var messages = try receiver.receiveMessages(allocator, 5);
    defer messages.deinit();
    try std.testing.expectEqual(@as(usize, 0), messages.count());
}

test "a receiver reads its namespace from the connection string" {
    var mock = MockServiceBusTransport.init();
    const client = try ServiceBusReceiverClient.fromConnectionString(
        "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=root;SharedAccessKey=c2VjcmV0",
        .{ .queue = "orders" },
        mock.asTransport(),
        .{},
    );
    try std.testing.expectEqualStrings("ns.servicebus.windows.net", client.fully_qualified_namespace);
    try std.testing.expectEqual(ReceiveMode.peek_lock, client.receive_mode);
}

test "a subscription address names the topic and the subscription" {
    const allocator = std.testing.allocator;
    const entity = EntityOptions{ .subscription = .{
        .topic_name = "orders",
        .subscription_name = "audit",
    } };

    const addr = try entity.formatAddress(allocator, .none);
    defer allocator.free(addr);
    try std.testing.expectEqualStrings("orders/Subscriptions/audit", addr);

    const dead = try entity.formatAddress(allocator, .dead_letter);
    defer allocator.free(dead);
    try std.testing.expectEqualStrings("orders/Subscriptions/audit/$deadletterqueue", dead);
}
