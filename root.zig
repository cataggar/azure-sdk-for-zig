///! Azure Event Hubs client — producer and consumer.
///!
///! Built on top of azure-sdk-core-amqp.
const std = @import("std");
const core = @import("azure_sdk_core");
const uamqp = @import("uamqp");
const amqp = @import("azure_sdk_amqp");
const messaging_common = @import("azure_sdk_messaging_common");
const checkpoint = @import("checkpoint.zig");
const event_data = @import("event_data.zig");
const errors = @import("errors.zig");

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

pub const ErrorCode = errors.ErrorCode;
pub const EventHubsError = errors.EventHubsError;
pub const RecoveryKind = errors.RecoveryKind;
pub const amqp_condition = errors.condition;
pub const recoveryKindForCondition = errors.recoveryKindForCondition;
pub const errorCodeForCondition = errors.errorCodeForCondition;
pub const RetryOptions = errors.RetryOptions;
pub const RetryConfig = errors.RetryConfig;
pub const Sleeper = errors.Sleeper;
pub const IoSleeper = errors.IoSleeper;
pub const SleepError = errors.SleepError;
pub const Attempt = errors.Attempt;
pub const Outcome = errors.Outcome;
pub const retry = errors.retry;

// ─────────────────────── Models ───────────────────────

// Not re-exported as a namespace: `batch` is the natural name for a
// parameter throughout this file, and Zig forbids the shadowing.
const batching = @import("batch.zig");
pub const batch_message_format = batching.batch_message_format;
pub const default_max_message_size = batching.default_max_message_size;
pub const BatchError = batching.BatchError;
pub const EventDataBatchOptions = batching.EventDataBatchOptions;
pub const EventDataBatch = batching.EventDataBatch;

pub const sending = @import("sender.zig");
pub const SenderPool = sending.SenderPool;
pub const SendError = sending.SendError;
pub const entityPathFor = sending.entityPathFor;

/// Metadata models and the `$management` operations that produce them. Both
/// carry an optional arena, so a decoded value owns its strings and one built
/// by hand borrows them; `deinit` is correct either way.
pub const management = @import("management.zig");
pub const PartitionProperties = management.PartitionProperties;
pub const EventHubProperties = management.EventHubProperties;

// Start positions. Kept in their own file so `receiver.zig` can use them
// without importing this one back. Not re-exported as a namespace: `position`
// is the natural name for a local here, and Zig forbids the shadowing.
const start_position_types = @import("position.zig");
pub const StartLocation = start_position_types.StartLocation;
pub const EventPosition = start_position_types.EventPosition;
pub const StartPositions = start_position_types.StartPositions;

pub const receiving = @import("receiver.zig");
pub const PartitionClient = receiving.PartitionClient;
pub const PartitionClientOptions = receiving.PartitionClientOptions;
pub const ReceiverPool = receiving.ReceiverPool;
pub const ReceiveError = receiving.ReceiveError;
pub const consumerPathFor = receiving.consumerPathFor;
pub const default_prefetch = receiving.default_prefetch;
pub const max_credit = receiving.max_credit;

// ─────────────────── AMQP Transport ──────────────────

/// Internal transport interface for AMQP operations.
/// Abstracts over uamqp to enable unit testing.
pub const AmqpTransport = struct {
    sendBatchFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) anyerror!void,
    receiveFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) anyerror![]ReceivedEventData,
    getHubPropertiesFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8) anyerror!EventHubProperties,
    getPartitionPropertiesFn: *const fn (self: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8, partition_id: []const u8) anyerror!PartitionProperties,
    /// The peer's `max-message-size` for `address`, or null when it advertised
    /// no limit or the transport cannot ask. `createBatch` sizes itself by it.
    maxMessageSizeFn: *const fn (self: *AmqpTransport, address: []const u8) anyerror!?u64,
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

    pub fn maxMessageSize(self: *AmqpTransport, address: []const u8) !?u64 {
        return self.maxMessageSizeFn(self, address);
    }

    pub fn close(self: *AmqpTransport) void {
        self.closeFn(self);
    }
};

/// A transport backed by real AMQP links.
///
/// Metadata operations are `$management` RPCs and sends go out over sender
/// links attached to the entity address. It borrows an already-open management
/// client and session rather than opening them, because the connection and its
/// CBS authorisation outlive any single operation and are owned by the caller.
pub const LinkTransport = struct {
    management_client: *amqp.Management,
    /// Sender links, attached on demand. Sending fails as unimplemented while
    /// this is null, which is what a metadata-only client wants.
    senders: ?*SenderPool = null,
    /// Receiver links, attached on demand. Null leaves receiving
    /// unimplemented, as for a producer-only or metadata-only client.
    receivers: ?*ReceiverPool = null,
    /// The CBS token for the hub audience. Event Hubs wants it on the message
    /// as well as on the link.
    security_token: ?[]const u8 = null,
    deadline_ms: i64,
    /// When set, operations run under the Event Hubs retry schedule.
    retry: ?errors.RetryConfig = null,
    transport: AmqpTransport,

    pub fn init(management_client: *amqp.Management, options: Options) LinkTransport {
        return .{
            .management_client = management_client,
            .senders = options.senders,
            .receivers = options.receivers,
            .security_token = options.security_token,
            .deadline_ms = options.deadline_ms,
            .retry = options.retry,
            .transport = .{
                .sendBatchFn = &sendBatchImpl,
                .receiveFn = &receiveImpl,
                .getHubPropertiesFn = &getHubPropsImpl,
                .getPartitionPropertiesFn = &getPartitionPropsImpl,
                .maxMessageSizeFn = &maxMessageSizeImpl,
                .closeFn = &closeImpl,
            },
        };
    }

    pub const Options = struct {
        senders: ?*SenderPool = null,
        receivers: ?*ReceiverPool = null,
        security_token: ?[]const u8 = null,
        deadline_ms: i64,
        retry: ?errors.RetryConfig = null,
    };

    pub fn asTransport(self: *LinkTransport) *AmqpTransport {
        return &self.transport;
    }

    /// The broker's status and description for the most recent failed
    /// metadata operation, which a Zig error cannot carry.
    pub fn lastError(self: *LinkTransport) ?amqp.ManagementStatusError {
        return self.management_client.last_error;
    }

    /// Why the broker refused the most recent send.
    pub fn lastSendError(self: *LinkTransport) ?errors.EventHubsError {
        const pool = self.senders orelse return null;
        return pool.lastError();
    }

    fn sendBatchImpl(t: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) !void {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        const pool = self.senders orelse return error.Unimplemented;
        if (self.retry) |config| {
            return switch (pool.sendWithRetry(allocator, target, batch, config)) {
                .ok => {},
                .failed => |failure| failure.err,
            };
        }
        return pool.send(allocator, target, batch);
    }

    fn maxMessageSizeImpl(t: *AmqpTransport, address: []const u8) !?u64 {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        const pool = self.senders orelse return null;
        return pool.maxMessageSize(address);
    }

    /// `filter` applies only to the first call for a given source: after
    /// that the partition client holds a position advanced past everything it
    /// has already delivered, and reapplying the original filter would replay.
    fn receiveImpl(t: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) ![]ReceivedEventData {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        const pool = self.receivers orelse return error.Unimplemented;
        return pool.receive(allocator, source, filter, max_count);
    }

    /// Why the broker detached the receiver link for `source`.
    pub fn lastReceiveError(self: *LinkTransport, source: []const u8) ?errors.EventHubsError {
        const pool = self.receivers orelse return null;
        return pool.lastError(source);
    }

    fn getHubPropsImpl(t: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8) !EventHubProperties {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        if (self.retry) |config| {
            return switch (management.getEventHubPropertiesWithRetry(
                allocator,
                self.management_client,
                hub_name,
                self.security_token,
                self.deadline_ms,
                config,
            )) {
                .ok => |props| props,
                .failed => |failure| failure.err,
            };
        }
        return management.getEventHubProperties(
            allocator,
            self.management_client,
            hub_name,
            self.security_token,
            self.deadline_ms,
        );
    }

    fn getPartitionPropsImpl(t: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8, partition_id: []const u8) !PartitionProperties {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        if (self.retry) |config| {
            return switch (management.getPartitionPropertiesWithRetry(
                allocator,
                self.management_client,
                hub_name,
                partition_id,
                self.security_token,
                self.deadline_ms,
                config,
            )) {
                .ok => |props| props,
                .failed => |failure| failure.err,
            };
        }
        return management.getPartitionProperties(
            allocator,
            self.management_client,
            hub_name,
            partition_id,
            self.security_token,
            self.deadline_ms,
        );
    }

    fn closeImpl(t: *AmqpTransport) void {
        _ = t;
    }
};

/// Mock AMQP transport for unit testing.
pub const MockAmqpTransport = struct {
    send_called: bool = false,
    send_batch_count: u32 = 0,
    /// The address the most recent send was routed to, so a test can assert
    /// partition targeting without a peer. Copied, because the caller builds
    /// the address on the stack or frees it as soon as the call returns.
    send_target_buf: [256]u8 = undefined,
    send_target_len: ?usize = null,
    /// Returned verbatim by `receive`, unlike a real transport which allocates.
    /// Tests keep ownership and must not call `freeReceivedEvents` on it.
    receive_result: []ReceivedEventData = &.{},
    hub_properties: EventHubProperties = .{ .name = "test-hub" },
    partition_properties: PartitionProperties = .{ .id = "0" },
    /// Stands in for a sender link's negotiated limit.
    link_max_message_size: ?u64 = null,
    transport: AmqpTransport,

    pub fn init() MockAmqpTransport {
        return .{
            .transport = .{
                .sendBatchFn = &sendBatchImpl,
                .receiveFn = &receiveImpl,
                .getHubPropertiesFn = &getHubPropsImpl,
                .getPartitionPropertiesFn = &getPartitionPropsImpl,
                .maxMessageSizeFn = &maxMessageSizeImpl,
                .closeFn = &closeImpl,
            },
        };
    }

    pub fn asTransport(self: *MockAmqpTransport) *AmqpTransport {
        return &self.transport;
    }

    fn sendBatchImpl(t: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) !void {
        _ = allocator;
        const self: *MockAmqpTransport = @fieldParentPtr("transport", t);
        self.send_called = true;
        self.send_batch_count += @intCast(batch.count());
        const len = @min(target.len, self.send_target_buf.len);
        @memcpy(self.send_target_buf[0..len], target[0..len]);
        self.send_target_len = len;
    }

    /// The address of the most recent send, or null if there was none.
    pub fn sendTarget(self: *const MockAmqpTransport) ?[]const u8 {
        const len = self.send_target_len orelse return null;
        return self.send_target_buf[0..len];
    }

    fn maxMessageSizeImpl(t: *AmqpTransport, address: []const u8) !?u64 {
        _ = address;
        const self: *MockAmqpTransport = @fieldParentPtr("transport", t);
        return self.link_max_message_size;
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

// ─────────────────────── Authentication ───────────────────────

/// The AAD scope Event Hubs issues tokens for. Go and Rust both use it.
pub const token_scope = "https://eventhubs.azure.net/.default";

/// The audience a token is requested for, and the CBS `name` it is put under.
///
/// `messaging_common.audienceFor` always writes `amqps://`, but the emulator
/// serves plaintext AMQP, so the scheme comes from the connection string here.
/// Caller owns the result.
pub fn audienceFor(
    allocator: std.mem.Allocator,
    scheme: []const u8,
    fully_qualified_namespace: []const u8,
    entity: ?[]const u8,
) ![]u8 {
    if (entity) |path| {
        if (path.len > 0) {
            return std.fmt.allocPrint(allocator, "{s}://{s}/{s}", .{ scheme, fully_qualified_namespace, path });
        }
    }
    return std.fmt.allocPrint(allocator, "{s}://{s}/", .{ scheme, fully_qualified_namespace });
}

/// How a client proves its identity.
///
/// A SAS credential is held by value rather than by pointer because
/// `SasCredential` recovers itself with `@fieldParentPtr`, so it has to live
/// at a stable address. Storing a pointer taken before `fromConnectionString`
/// returned would dangle the moment the client was moved.
pub const Credential = union(enum) {
    /// An AAD credential. The caller owns it and must outlive the client.
    token: *core.credentials.TokenCredential,
    /// Built from a connection string and owned by the client.
    sas: messaging_common.SasCredential,

    /// Resolve to the abstract credential. Takes a pointer so the SAS case
    /// hands out an address that stays valid.
    pub fn tokenCredential(self: *Credential) *core.credentials.TokenCredential {
        return switch (self.*) {
            .token => |c| c,
            .sas => |*sas| sas.asCredential(),
        };
    }

    /// The CBS `type` the broker expects for this credential.
    pub fn cbsTokenType(self: Credential) []const u8 {
        return switch (self) {
            .token => messaging_common.cbs_token_type_jwt,
            .sas => messaging_common.cbs_token_type_sas,
        };
    }

    /// Whether a new token can be minted once the current one expires. A
    /// pre-formed signature from a connection string cannot be re-signed.
    pub fn isRefreshable(self: Credential) bool {
        return switch (self) {
            .token => true,
            .sas => |sas| sas.isRefreshable(),
        };
    }

    /// Acquire a token for `audience`, using the Event Hubs scope for AAD.
    /// The SAS case ignores the scope and signs the audience it was built
    /// with.
    pub fn getToken(
        self: *Credential,
        ctx: core.context.Context,
    ) !core.credentials.AccessToken {
        return self.tokenCredential().getToken(.{ .scopes = &.{token_scope} }, ctx);
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
    credential: Credential,
    amqp_transport: *AmqpTransport,
    /// The audience tokens are issued for. Owned only when built from a
    /// connection string, since `SasCredential` borrows it.
    owned_audience: ?[]u8 = null,
    allocator: ?std.mem.Allocator = null,

    pub fn init(
        options: ProducerClientOptions,
        credential: *core.credentials.TokenCredential,
        amqp_transport: *AmqpTransport,
    ) ProducerClient {
        return .{
            .options = options,
            .credential = .{ .token = credential },
            .amqp_transport = amqp_transport,
        };
    }

    /// Create from a connection string, signing with its shared access key.
    ///
    /// The connection string must outlive the client: the parsed namespace,
    /// hub name, and key all borrow from it.
    pub fn fromConnectionString(
        allocator: std.mem.Allocator,
        connection_string: []const u8,
        event_hub_name: ?[]const u8,
        amqp_transport: *AmqpTransport,
    ) !ProducerClient {
        const cs = try ConnectionStringProperties.parse(connection_string);
        const hub = event_hub_name orelse cs.entity_path orelse return error.MissingEventHubName;

        const aud = try audienceFor(allocator, cs.scheme(), cs.fully_qualified_namespace, hub);
        errdefer allocator.free(aud);

        return .{
            .options = .{
                .fully_qualified_namespace = cs.fully_qualified_namespace,
                .event_hub_name = hub,
            },
            .credential = .{
                .sas = try messaging_common.SasCredential.initFromConnectionString(allocator, cs, aud),
            },
            .amqp_transport = amqp_transport,
            .owned_audience = aud,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ProducerClient) void {
        if (self.allocator) |allocator| {
            if (self.owned_audience) |aud| allocator.free(aud);
        }
        self.owned_audience = null;
    }

    /// The audience a token is put to CBS under, `amqps://{fqns}/{hub}`.
    /// Caller owns the result.
    pub fn entityAudience(self: *ProducerClient, allocator: std.mem.Allocator) ![]u8 {
        if (self.owned_audience) |owned| return allocator.dupe(u8, owned);
        return audienceFor(allocator, "amqps", self.options.fully_qualified_namespace, self.options.event_hub_name);
    }

    /// Acquire a token for this hub, for putting to CBS before a link
    /// attaches.
    pub fn getToken(self: *ProducerClient, ctx: core.context.Context) !core.credentials.AccessToken {
        return self.credential.getToken(ctx);
    }

    /// The AMQP address a batch is published to: the hub, letting the service
    /// pick a partition, or `{hub}/Partitions/{id}`. Caller owns the result.
    pub fn entityPath(
        self: *ProducerClient,
        allocator: std.mem.Allocator,
        partition_id: ?[]const u8,
    ) ![]u8 {
        return entityPathFor(allocator, self.options.event_hub_name, partition_id);
    }

    /// Send a batch of events over AMQP.
    pub fn sendBatch(self: *ProducerClient, allocator: std.mem.Allocator, batch: EventDataBatch) !void {
        if (batch.count() == 0) return SendError.EmptyBatch;
        const address = try self.entityPath(allocator, batch.partition_id);
        defer allocator.free(address);
        return self.amqp_transport.sendBatch(allocator, address, batch);
    }

    /// Create a batch sized for this producer.
    ///
    /// The limit comes from the sender link's negotiated `max-message-size`
    /// when the transport can report one, and stays at
    /// `default_max_message_size` otherwise. Go likewise attaches the link
    /// inside `NewEventDataBatch` so the batch knows its real ceiling.
    pub fn createBatch(
        self: *ProducerClient,
        allocator: std.mem.Allocator,
        options: EventDataBatchOptions,
    ) !EventDataBatch {
        var new_batch = try EventDataBatch.init(options);
        errdefer new_batch.deinit(allocator);

        const address = try self.entityPath(allocator, options.partition_id);
        defer allocator.free(address);

        if (try self.amqp_transport.maxMessageSize(address)) |limit| {
            try new_batch.applyLinkMaxMessageSize(@intCast(limit));
        }
        return new_batch;
    }

    pub fn getEventHubProperties(self: *ProducerClient, allocator: std.mem.Allocator) !EventHubProperties {
        return self.amqp_transport.getHubProperties(allocator, self.options.event_hub_name);
    }

    pub fn getPartitionProperties(self: *ProducerClient, allocator: std.mem.Allocator, partition_id: []const u8) !PartitionProperties {
        return self.amqp_transport.getPartitionProperties(allocator, self.options.event_hub_name, partition_id);
    }

    pub fn close(self: *ProducerClient) void {
        self.amqp_transport.close();
        self.deinit();
    }
};

pub const ConsumerClientOptions = struct {
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    consumer_group: []const u8 = "$Default",
    /// Identifies this reader to the broker, so a stolen link names who took
    /// it. Borrowed, and must outlive the client.
    instance_id: ?[]const u8 = null,
};

/// Used when the caller supplies no instance id, matching the link-name
/// suffix the producer side already uses.
pub const default_instance_id = "eventhubs";

/// Receives events from an Event Hub partition.
pub const ConsumerClient = struct {
    options: ConsumerClientOptions,
    credential: Credential,
    amqp_transport: *AmqpTransport,
    /// The audience tokens are issued for. Owned only when built from a
    /// connection string, since `SasCredential` borrows it.
    owned_audience: ?[]u8 = null,
    allocator: ?std.mem.Allocator = null,

    pub fn init(
        options: ConsumerClientOptions,
        credential: *core.credentials.TokenCredential,
        amqp_transport: *AmqpTransport,
    ) ConsumerClient {
        return .{
            .options = options,
            .credential = .{ .token = credential },
            .amqp_transport = amqp_transport,
        };
    }

    /// Create from a connection string, signing with its shared access key.
    ///
    /// The connection string must outlive the client: the parsed namespace,
    /// hub name, and key all borrow from it.
    pub fn fromConnectionString(
        allocator: std.mem.Allocator,
        connection_string: []const u8,
        event_hub_name: ?[]const u8,
        amqp_transport: *AmqpTransport,
    ) !ConsumerClient {
        const cs = try ConnectionStringProperties.parse(connection_string);
        const hub = event_hub_name orelse cs.entity_path orelse return error.MissingEventHubName;

        const aud = try audienceFor(allocator, cs.scheme(), cs.fully_qualified_namespace, hub);
        errdefer allocator.free(aud);

        return .{
            .options = .{
                .fully_qualified_namespace = cs.fully_qualified_namespace,
                .event_hub_name = hub,
            },
            .credential = .{
                .sas = try messaging_common.SasCredential.initFromConnectionString(allocator, cs, aud),
            },
            .amqp_transport = amqp_transport,
            .owned_audience = aud,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ConsumerClient) void {
        if (self.allocator) |allocator| {
            if (self.owned_audience) |aud| allocator.free(aud);
        }
        self.owned_audience = null;
    }

    /// The audience a token is put to CBS under, `amqps://{fqns}/{hub}`.
    /// Caller owns the result.
    pub fn entityAudience(self: *ConsumerClient, allocator: std.mem.Allocator) ![]u8 {
        if (self.owned_audience) |owned| return allocator.dupe(u8, owned);
        return audienceFor(allocator, "amqps", self.options.fully_qualified_namespace, self.options.event_hub_name);
    }

    /// The audience for a partition receiver, which authorises the consumer
    /// group path rather than the hub.
    pub fn partitionAudience(
        self: *ConsumerClient,
        allocator: std.mem.Allocator,
        partition_id: []const u8,
    ) ![]u8 {
        const path = try std.fmt.allocPrint(allocator, "{s}/ConsumerGroups/{s}/Partitions/{s}", .{
            self.options.event_hub_name,
            self.options.consumer_group,
            partition_id,
        });
        defer allocator.free(path);
        return audienceFor(allocator, "amqps", self.options.fully_qualified_namespace, path);
    }

    /// Acquire a token for this hub, for putting to CBS before a link
    /// attaches.
    pub fn getToken(self: *ConsumerClient, ctx: core.context.Context) !core.credentials.AccessToken {
        return self.credential.getToken(ctx);
    }

    /// The AMQP address a partition is read from. Caller owns the result.
    ///
    /// This is an entity path, not a URL: the namespace comes from the
    /// connection, so prefixing it here would attach to a link that does not
    /// exist.
    pub fn consumerPath(
        self: *ConsumerClient,
        allocator: std.mem.Allocator,
        partition_id: []const u8,
    ) ![]u8 {
        return consumerPathFor(
            allocator,
            self.options.event_hub_name,
            self.options.consumer_group,
            partition_id,
        );
    }

    /// The name this reader attaches under.
    pub fn instanceId(self: *ConsumerClient) []const u8 {
        return self.options.instance_id orelse default_instance_id;
    }

    /// Open a client that reads one partition over a link it keeps attached.
    ///
    /// Initialise in place; `client` must outlive neither `session` nor the
    /// allocator. This mirrors Go's `NewPartitionClient` and is the path that
    /// supports prefetch, owner level, and resuming without replay.
    pub fn newPartitionClient(
        self: *ConsumerClient,
        client: *PartitionClient,
        allocator: std.mem.Allocator,
        session: *amqp.Session,
        partition_id: []const u8,
        deadline_ms: i64,
        options: PartitionClientOptions,
    ) !void {
        const source = try self.consumerPath(allocator, partition_id);
        defer allocator.free(source);

        try client.open(allocator, session, .{
            .source_address = source,
            .instance_id = self.instanceId(),
            .deadline_ms = deadline_ms,
        }, options);
    }

    /// Receive events from a specific partition.
    ///
    /// A one-shot convenience over the transport. Use `newPartitionClient`
    /// when the reader needs prefetch control, an owner level, or to resume
    /// where it left off: each call here re-applies `start_position`, and a
    /// link-backed transport only honours it on the first call.
    ///
    /// The returned slice comes from the transport. A link-backed transport
    /// allocates it, so free it with `freeReceivedEvents`; `MockAmqpTransport`
    /// returns the slice a test handed it and keeps ownership.
    pub fn receiveEvents(
        self: *ConsumerClient,
        allocator: std.mem.Allocator,
        partition_id: []const u8,
        start_position: EventPosition,
        max_count: u32,
    ) ![]ReceivedEventData {
        const address = try self.consumerPath(allocator, partition_id);
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
        self.deinit();
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
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), mock_amqp.asTransport());
    var batch = try producer.createBatch(allocator, .{});
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
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), mock_amqp.asTransport());

    var batch = try producer.createBatch(allocator, .{});
    defer batch.deinit(allocator);
    var e1 = EventData.init("event-1");
    defer e1.deinit(allocator);
    _ = try batch.tryAdd(allocator, e1);

    try producer.sendBatch(allocator, batch);
    try std.testing.expect(mock_amqp.send_called);
    try std.testing.expectEqual(@as(u32, 1), mock_amqp.send_batch_count);
}

test "ProducerClient sendBatch targets the hub, or one partition when pinned" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_sdk_core").identity.client_secret;
    var mock_http = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock_http.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock_http.asTransport(), "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), mock_amqp.asTransport());

    var event = EventData.init("event-1");
    defer event.deinit(allocator);

    // Unpinned: the service picks the partition, so the link targets the hub.
    // The namespace is not part of the address; it is the connection's.
    var any = try producer.createBatch(allocator, .{});
    defer any.deinit(allocator);
    _ = try any.tryAdd(allocator, event);
    try producer.sendBatch(allocator, any);
    try std.testing.expectEqualStrings("my-hub", mock_amqp.sendTarget().?);

    var pinned = try producer.createBatch(allocator, .{ .partition_id = "3" });
    defer pinned.deinit(allocator);
    _ = try pinned.tryAdd(allocator, event);
    try producer.sendBatch(allocator, pinned);
    try std.testing.expectEqualStrings("my-hub/Partitions/3", mock_amqp.sendTarget().?);
}

test "createBatch adopts the sender link's max-message-size" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_sdk_core").identity.client_secret;
    var mock_http = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock_http.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock_http.asTransport(), "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), mock_amqp.asTransport());

    // Premium namespaces negotiate well above the 1 MiB default, and a batch
    // that kept the default would refuse events the broker would have taken.
    mock_amqp.link_max_message_size = 20 * 1024 * 1024;
    var large = try producer.createBatch(allocator, .{});
    defer large.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 20 * 1024 * 1024), large.max_size_bytes);

    // An explicit smaller ceiling still wins.
    var capped = try producer.createBatch(allocator, .{ .max_bytes = 4096 });
    defer capped.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 4096), capped.max_size_bytes);

    // Asking for more than the link allows is refused rather than silently
    // truncated, so an oversized batch cannot reach the broker.
    try std.testing.expectError(
        BatchError.MaxBytesExceedsLinkLimit,
        producer.createBatch(allocator, .{ .max_bytes = 32 * 1024 * 1024 }),
    );
}

test "a link transport without sender links refuses to send" {
    const allocator = std.testing.allocator;
    var mgmt: amqp.Management = undefined;
    var transport = LinkTransport.init(&mgmt, .{ .deadline_ms = 10_000 });

    var empty = try EventDataBatch.init(.{});
    defer empty.deinit(allocator);
    var event = EventData.init("x");
    defer event.deinit(allocator);
    _ = try empty.tryAdd(allocator, event);

    // Reporting success without a link is the bug this replaced; the
    // management client is never touched, so it may stay uninitialised.
    try std.testing.expectError(
        error.Unimplemented,
        transport.asTransport().sendBatch(allocator, "my-hub", empty),
    );
    try std.testing.expectEqual(@as(?u64, null), try transport.asTransport().maxMessageSize("my-hub"));
}

test "ProducerClient sendBatch empty returns error" {
    const allocator = std.testing.allocator;
    const cred_mod = @import("azure_sdk_core").identity.client_secret;
    var mock_http = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer mock_http.deinit();
    var cred = cred_mod.ClientSecretCredential.init(allocator, mock_http.asTransport(), "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), mock_amqp.asTransport());

    var batch = try producer.createBatch(allocator, .{});
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
    var mock_amqp = MockAmqpTransport.init();
    mock_amqp.hub_properties = .{ .name = "my-hub", .partition_ids = &.{ "0", "1", "2" } };
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), mock_amqp.asTransport());

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
    var mock_amqp = MockAmqpTransport.init();
    var consumer = ConsumerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), mock_amqp.asTransport());

    const events = try consumer.receiveEvents(allocator, "0", EventPosition.earliest(), 10);
    try std.testing.expectEqual(@as(usize, 0), events.len);
}

test "ProducerClient fromConnectionString" {
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://mynamespace.servicebus.windows.net/;SharedAccessKeyName=mykey;SharedAccessKey=abc123=;EntityPath=myhub";
    var producer = try ProducerClient.fromConnectionString(allocator, cs, null, mock_amqp.asTransport());
    defer producer.deinit();
    try std.testing.expectEqualStrings("mynamespace.servicebus.windows.net", producer.options.fully_qualified_namespace);
    try std.testing.expectEqualStrings("myhub", producer.options.event_hub_name);
    try std.testing.expect(producer.credential == .sas);
    try std.testing.expectEqualStrings(
        "amqps://mynamespace.servicebus.windows.net/myhub",
        producer.owned_audience.?,
    );
}

test "ProducerClient fromConnectionString with override" {
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=hub1";
    var producer = try ProducerClient.fromConnectionString(allocator, cs, "hub2", mock_amqp.asTransport());
    defer producer.deinit();
    try std.testing.expectEqualStrings("hub2", producer.options.event_hub_name);
    try std.testing.expectEqualStrings("amqps://ns.servicebus.windows.net/hub2", producer.owned_audience.?);
}

test "ProducerClient fromConnectionString missing hub" {
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v";
    const result = ProducerClient.fromConnectionString(std.testing.allocator, cs, null, mock_amqp.asTransport());
    try std.testing.expectError(error.MissingEventHubName, result);
}

test "ConsumerClient fromConnectionString" {
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=hub";
    var consumer = try ConsumerClient.fromConnectionString(allocator, cs, null, mock_amqp.asTransport());
    defer consumer.deinit();
    try std.testing.expectEqualStrings("ns.servicebus.windows.net", consumer.options.fully_qualified_namespace);
    try std.testing.expectEqualStrings("hub", consumer.options.event_hub_name);
    try std.testing.expectEqualStrings("$Default", consumer.options.consumer_group);
    try std.testing.expect(consumer.credential == .sas);
}

/// Records the scopes it was asked for, so tests can assert Event Hubs uses
/// the right AAD scope.
const ScopeRecordingCredential = struct {
    credential: core.credentials.TokenCredential,
    last_scopes: []const []const u8 = &.{},

    fn init() ScopeRecordingCredential {
        return .{ .credential = .{ .getTokenFn = &getTokenImpl } };
    }

    fn asCredential(self: *ScopeRecordingCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        credential: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        ctx: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        _ = ctx;
        const self: *ScopeRecordingCredential = @fieldParentPtr("credential", credential);
        self.last_scopes = request_context.scopes;
        return .{ .token = "aad-token", .expires_on = 1234 };
    }
};

test "audienceFor uses the connection string scheme" {
    const allocator = std.testing.allocator;

    const secure = try audienceFor(allocator, "amqps", "ns.servicebus.windows.net", "hub");
    defer allocator.free(secure);
    try std.testing.expectEqualStrings("amqps://ns.servicebus.windows.net/hub", secure);

    // The emulator serves plaintext AMQP on localhost.
    const plain = try audienceFor(allocator, "amqp", "localhost", "hub");
    defer allocator.free(plain);
    try std.testing.expectEqualStrings("amqp://localhost/hub", plain);

    const namespace_only = try audienceFor(allocator, "amqps", "ns.servicebus.windows.net", null);
    defer allocator.free(namespace_only);
    try std.testing.expectEqualStrings("amqps://ns.servicebus.windows.net/", namespace_only);
}

test "connection string credential signs the parsed entity" {
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=policy;SharedAccessKey=c2VjcmV0;EntityPath=hub";
    var producer = try ProducerClient.fromConnectionString(allocator, cs, null, mock_amqp.asTransport());
    defer producer.deinit();

    try std.testing.expect(producer.credential == .sas);
    try std.testing.expectEqualStrings(
        messaging_common.cbs_token_type_sas,
        producer.credential.cbsTokenType(),
    );
    try std.testing.expect(producer.credential.isRefreshable());

    var token = try producer.getToken(.{});
    defer token.deinit();

    try std.testing.expect(std.mem.startsWith(u8, token.token, "SharedAccessSignature "));
    // The signature covers the hub the connection string named, not the bare
    // namespace.
    try std.testing.expect(std.mem.indexOf(u8, token.token, "sr=amqps%3a%2f%2fns.servicebus.windows.net%2fhub") != null);
    try std.testing.expect(std.mem.indexOf(u8, token.token, "skn=policy") != null);
    try std.testing.expect(std.mem.indexOf(u8, token.token, "sig=") != null);
    try std.testing.expect(token.expires_on > 0);
}

test "AAD credential is asked for the Event Hubs scope" {
    var mock_amqp = MockAmqpTransport.init();
    var recorder = ScopeRecordingCredential.init();
    var producer = ProducerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "hub",
    }, recorder.asCredential(), mock_amqp.asTransport());
    defer producer.deinit();

    try std.testing.expect(producer.credential == .token);
    try std.testing.expectEqualStrings(
        messaging_common.cbs_token_type_jwt,
        producer.credential.cbsTokenType(),
    );
    try std.testing.expect(producer.credential.isRefreshable());

    var token = try producer.getToken(.{});
    defer token.deinit();

    try std.testing.expectEqualStrings("aad-token", token.token);
    try std.testing.expectEqual(@as(usize, 1), recorder.last_scopes.len);
    try std.testing.expectEqualStrings("https://eventhubs.azure.net/.default", recorder.last_scopes[0]);
}

test "entityAudience matches the hub, partitionAudience the consumer group path" {
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    var recorder = ScopeRecordingCredential.init();
    var consumer = ConsumerClient.init(.{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "hub",
        .consumer_group = "cg",
    }, recorder.asCredential(), mock_amqp.asTransport());
    defer consumer.deinit();

    const entity = try consumer.entityAudience(allocator);
    defer allocator.free(entity);
    try std.testing.expectEqualStrings("amqps://ns.servicebus.windows.net/hub", entity);

    const partition = try consumer.partitionAudience(allocator, "3");
    defer allocator.free(partition);
    try std.testing.expectEqualStrings(
        "amqps://ns.servicebus.windows.net/hub/ConsumerGroups/cg/Partitions/3",
        partition,
    );
}

test "a SAS credential survives being returned by value" {
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=dg==;EntityPath=hub";

    // `SasCredential` recovers itself with `@fieldParentPtr`, so a pointer
    // taken before the client was moved would dangle. Resolving lazily
    // through the moved client must still produce a usable token.
    var producer = try ProducerClient.fromConnectionString(allocator, cs, null, mock_amqp.asTransport());
    defer producer.deinit();
    var moved = producer;
    producer.owned_audience = null;
    producer.allocator = null;
    defer moved.deinit();

    var token = try moved.getToken(.{});
    defer token.deinit();
    try std.testing.expect(std.mem.indexOf(u8, token.token, "skn=k") != null);
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

test {
    // These are re-exported but not called from this file, so without an
    // explicit reference Zig never analyses them and their tests never run.
    _ = errors;
    _ = event_data;
    _ = checkpoint;
}
