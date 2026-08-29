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

pub const version: []const u8 = @import("build_options").version;

pub const ConnectionStringProperties = messaging_common.ConnectionStringProperties;
pub const Checkpoint = checkpoint.Checkpoint;
pub const PartitionOwnership = checkpoint.PartitionOwnership;
pub const CheckpointStore = checkpoint.CheckpointStore;
pub const freeCheckpoints = checkpoint.freeCheckpoints;
pub const freeOwnerships = checkpoint.freeOwnerships;
pub const InMemoryCheckpointStore = checkpoint.InMemoryCheckpointStore;
pub const Clock = checkpoint.Clock;
pub const SystemClock = checkpoint.SystemClock;
pub const ManualClock = checkpoint.ManualClock;
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
pub const fromAmqpMessage = event_data.fromAmqpMessage;

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
pub const default_max_in_flight = sending.default_max_in_flight;
pub const SendError = sending.SendError;
pub const entityPathFor = sending.entityPathFor;
pub const entityPathInto = sending.entityPathInto;

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

// Connection-level options. Named `connection_options` rather than
// `options`, which would shadow the many locals called that.
pub const connection_options = @import("connection_options.zig");
pub const ConnectionOptions = connection_options.ConnectionOptions;
pub const CustomEndpoint = connection_options.CustomEndpoint;
pub const TlsSettings = connection_options.TlsSettings;
pub const WebSocketHook = connection_options.WebSocketHook;
pub const AmqpConnectionFactory = connection_options.AmqpConnectionFactory;

// The processor. Named for the file: `processor` reads better as a local.
pub const processing = @import("processor.zig");
pub const Processor = processing.Processor;
pub const ProcessorPartitionClient = processing.ProcessorPartitionClient;
pub const PartitionOpener = processing.PartitionOpener;
pub const freePartitionIds = processing.freePartitionIds;

// Load balancing. Named for the file: `balancer` reads better as a local.
pub const load_balancing = @import("load_balancer.zig");
pub const LoadBalancer = load_balancing.LoadBalancer;
pub const LoadBalancingStrategy = load_balancing.LoadBalancingStrategy;
pub const ProcessorOptions = load_balancing.ProcessorOptions;
pub const OwnershipDetails = load_balancing.OwnershipDetails;
pub const resolveStartPosition = load_balancing.resolveStartPosition;
pub const isGeoReplicationOffsetError = load_balancing.isGeoReplicationOffsetError;
pub const geo_replication_fallback = load_balancing.geo_replication_fallback;
pub const relinquished_owner_id = load_balancing.relinquished_owner_id;

pub const recovery = @import("recovery.zig");
pub const RecoverableConnection = recovery.RecoverableConnection;
pub const ConnectionFactory = recovery.ConnectionFactory;
pub const Plumbing = recovery.Plumbing;
pub const Authorizer = recovery.Authorizer;
pub const RecoveryError = recovery.RecoveryError;
pub const runWithRecovery = recovery.runWithRecovery;

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
    /// Send several batches with as few round trips as the transport can
    /// manage. Optional: a transport that cannot pipeline leaves it null and
    /// `sendBatches` sends them one at a time, which is correct but slower.
    sendBatchesFn: ?*const fn (self: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batches: []const EventDataBatch) anyerror!void = null,
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

    pub fn sendBatches(self: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batches: []const EventDataBatch) !void {
        if (self.sendBatchesFn) |f| return f(self, allocator, target, batches);
        for (batches) |batch| try self.sendBatch(allocator, target, batch);
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
    /// Set when the caller manages the connection itself. Null when
    /// `connection` provides it, since a rebuild replaces the client.
    management_client: ?*amqp.Management = null,
    /// Sender links, attached on demand. Sending fails as unimplemented while
    /// this is null, which is what a metadata-only client wants.
    senders: ?*SenderPool = null,
    /// Receiver links, attached on demand. Null leaves receiving
    /// unimplemented, as for a producer-only or metadata-only client.
    receivers: ?*ReceiverPool = null,
    /// When set, the transport owns neither the links nor the connection:
    /// both come from here and are rebuilt when an operation says they broke.
    connection: ?*RecoverableConnection = null,
    /// The CBS token for the hub audience. Event Hubs wants it on the message
    /// as well as on the link.
    security_token: ?[]const u8 = null,
    timeout_ms: i64,
    /// When set, operations run under the Event Hubs retry schedule.
    retry: ?errors.RetryConfig = null,
    transport: AmqpTransport,

    pub fn init(management_client: *amqp.Management, options: Options) LinkTransport {
        var self = initEmpty(options);
        self.management_client = management_client;
        self.senders = options.senders;
        self.receivers = options.receivers;
        return self;
    }

    /// Build a transport that recovers its own links and connection.
    ///
    /// Every operation runs under the retry schedule, because recovery is
    /// pointless without one: rebuilding and then not retrying just returns
    /// the original failure.
    pub fn initRecoverable(
        connection: *RecoverableConnection,
        retry_config: errors.RetryConfig,
        options: Options,
    ) LinkTransport {
        var self = initEmpty(options);
        self.connection = connection;
        self.retry = retry_config;
        return self;
    }

    fn initEmpty(options: Options) LinkTransport {
        return .{
            .security_token = options.security_token,
            .timeout_ms = options.deadline_ms,
            .retry = options.retry,
            .transport = .{
                .sendBatchFn = &sendBatchImpl,
                .sendBatchesFn = &sendBatchesImpl,
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
        /// Per-operation timeout duration in milliseconds. The legacy field
        /// name is retained for source compatibility.
        deadline_ms: i64,
        retry: ?errors.RetryConfig = null,
    };

    pub fn asTransport(self: *LinkTransport) *AmqpTransport {
        return &self.transport;
    }

    /// The broker's status and description for the most recent failed
    /// metadata operation, which a Zig error cannot carry.
    pub fn lastError(self: *LinkTransport) ?amqp.ManagementStatusError {
        const client = self.managementClient() catch return null;
        return client.last_error;
    }

    /// The management client to use, from the recoverable connection when
    /// there is one.
    fn managementClient(self: *LinkTransport) !*amqp.Management {
        if (self.connection) |conn| return conn.managementClient();
        return self.management_client orelse error.Unimplemented;
    }

    fn senderPool(self: *LinkTransport) !*SenderPool {
        if (self.connection) |conn| return conn.senderPool();
        return self.senders orelse error.Unimplemented;
    }

    fn receiverPool(self: *LinkTransport) !*ReceiverPool {
        if (self.connection) |conn| return conn.receiverPool();
        return self.receivers orelse error.Unimplemented;
    }

    /// Why the broker refused the most recent send.
    pub fn lastSendError(self: *LinkTransport) ?errors.EventHubsError {
        const pool = self.senderPool() catch return null;
        return pool.lastError();
    }

    fn sendBatchImpl(t: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batch: EventDataBatch) !void {
        const self: *LinkTransport = @fieldParentPtr("transport", t);

        if (self.connection) |conn| {
            const config = self.retry orelse return error.Unimplemented;
            var op = SendOp{ .connection = conn, .allocator = allocator, .target = target, .batch = batch };
            return switch (recovery.runWithRecovery(void, conn, target, &op, config)) {
                .ok => {},
                .failed => |failure| failure.err,
            };
        }

        const pool = self.senders orelse return error.Unimplemented;
        if (self.retry) |config| {
            return switch (pool.sendWithRetry(allocator, target, batch, config)) {
                .ok => {},
                .failed => |failure| failure.err,
            };
        }
        return pool.send(allocator, target, batch);
    }

    /// Send every batch, pipelining them and falling back for whatever the
    /// pipeline did not get accepted.
    ///
    /// The fast path keeps `max_in_flight` batches on the wire at once, so the
    /// round trip is paid once for the window rather than once per batch. It
    /// does not retry, so anything it did not land is re-sent through the
    /// ordinary retrying path — which also recovers the connection if that is
    /// what went wrong.
    ///
    /// The resend loop stops at the first failure, which is usually the batch
    /// the broker just refused — so the ones behind it in the window, whose
    /// verdicts were abandoned unread, are often neither re-sent nor reported.
    /// That costs nothing in safety: `accepted` only ever counts acceptances
    /// the broker stated, so the caller is never told a batch landed when it
    /// might not have.
    fn sendBatchesImpl(t: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batches: []const EventDataBatch) !void {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        if (batches.len == 0) return;

        var accepted: usize = 0;
        // A pool is not guaranteed — `senderPool` fails before the client is
        // connected — and the fallback reports that better than we can here.
        if (self.senderPool()) |pool| {
            const result = pool.sendPipelined(allocator, target, batches);
            if (result.err == null) return;
            accepted = result.accepted;
        } else |_| {}

        for (batches[accepted..]) |batch| {
            try sendBatchImpl(t, allocator, target, batch);
        }
    }

    /// One send attempt against whichever sender pool the connection has now.
    ///
    /// The pool is fetched inside `call` rather than captured, because a
    /// recovery between attempts replaces the links behind it.
    const SendOp = struct {
        connection: *RecoverableConnection,
        allocator: std.mem.Allocator,
        target: []const u8,
        batch: EventDataBatch,

        pub fn call(op: *const @This(), attempt: *errors.Attempt) anyerror!void {
            const pool = try op.connection.senderPool();
            return pool.send(op.allocator, op.target, op.batch) catch |err| {
                pool.recordFailure(op.target, attempt);
                return err;
            };
        }
    };

    /// One receive attempt against whichever receiver pool the connection has
    /// now.
    const ReceiveOp = struct {
        connection: *RecoverableConnection,
        allocator: std.mem.Allocator,
        source: []const u8,
        filter: ?[]const u8,
        max_count: u32,

        pub fn call(op: *const @This(), attempt: *errors.Attempt) anyerror![]ReceivedEventData {
            const pool = try op.connection.receiverPool();
            return pool.receive(op.allocator, op.source, op.filter, op.max_count) catch |err| {
                pool.recordFailure(op.source, attempt);
                return err;
            };
        }
    };

    fn maxMessageSizeImpl(t: *AmqpTransport, address: []const u8) !?u64 {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        const pool = self.senderPool() catch return null;
        return pool.maxMessageSize(address);
    }

    /// `filter` applies only to the first call for a given source: after
    /// that the partition client holds a position advanced past everything it
    /// has already delivered, and reapplying the original filter would replay.
    fn receiveImpl(t: *AmqpTransport, allocator: std.mem.Allocator, source: []const u8, filter: ?[]const u8, max_count: u32) ![]ReceivedEventData {
        const self: *LinkTransport = @fieldParentPtr("transport", t);

        if (self.connection) |conn| {
            const config = self.retry orelse return error.Unimplemented;
            var op = ReceiveOp{
                .connection = conn,
                .allocator = allocator,
                .source = source,
                .filter = filter,
                .max_count = max_count,
            };
            return switch (recovery.runWithRecovery([]ReceivedEventData, conn, source, &op, config)) {
                .ok => |events| events,
                .failed => |failure| failure.err,
            };
        }

        const pool = self.receivers orelse return error.Unimplemented;
        return pool.receive(allocator, source, filter, max_count);
    }

    /// Why the broker detached the receiver link for `source`.
    pub fn lastReceiveError(self: *LinkTransport, source: []const u8) ?errors.EventHubsError {
        const pool = self.receiverPool() catch return null;
        return pool.lastError(source);
    }

    fn getHubPropsImpl(t: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8) !EventHubProperties {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        const client = try self.managementClient();
        const deadline_ms = receiving.deadlineAfter(client.rpc_link.session, self.timeout_ms);
        if (self.retry) |config| {
            return switch (management.getEventHubPropertiesWithRetry(
                allocator,
                client,
                hub_name,
                self.security_token,
                deadline_ms,
                config,
            )) {
                .ok => |props| props,
                .failed => |failure| failure.err,
            };
        }
        return management.getEventHubProperties(
            allocator,
            client,
            hub_name,
            self.security_token,
            deadline_ms,
        );
    }

    fn getPartitionPropsImpl(t: *AmqpTransport, allocator: std.mem.Allocator, hub_name: []const u8, partition_id: []const u8) !PartitionProperties {
        const self: *LinkTransport = @fieldParentPtr("transport", t);
        const client = try self.managementClient();
        const deadline_ms = receiving.deadlineAfter(client.rpc_link.session, self.timeout_ms);
        if (self.retry) |config| {
            return switch (management.getPartitionPropertiesWithRetry(
                allocator,
                client,
                hub_name,
                partition_id,
                self.security_token,
                deadline_ms,
                config,
            )) {
                .ok => |props| props,
                .failed => |failure| failure.err,
            };
        }
        return management.getPartitionProperties(
            allocator,
            client,
            hub_name,
            partition_id,
            self.security_token,
            deadline_ms,
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
    /// One entry per `sendBatches` group, so a test can see how the client
    /// split its batches across links rather than only the total that arrived.
    groups: [8]Group = undefined,
    group_count: usize = 0,
    transport: AmqpTransport,

    pub const Group = struct {
        len: usize,
        target_buf: [256]u8,
        target_len: usize,

        pub fn target(self: *const Group) []const u8 {
            return self.target_buf[0..self.target_len];
        }
    };

    pub fn init() MockAmqpTransport {
        return .{
            .transport = .{
                .sendBatchFn = &sendBatchImpl,
                // Records the grouping, then hands every batch to
                // `sendBatchImpl` so the existing per-batch counts still hold.
                .sendBatchesFn = &sendBatchesImpl,
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

    fn sendBatchesImpl(t: *AmqpTransport, allocator: std.mem.Allocator, target: []const u8, batches: []const EventDataBatch) !void {
        const self: *MockAmqpTransport = @fieldParentPtr("transport", t);
        if (self.group_count < self.groups.len) {
            var group: Group = .{ .len = batches.len, .target_buf = undefined, .target_len = 0 };
            group.target_len = @min(target.len, group.target_buf.len);
            @memcpy(group.target_buf[0..group.target_len], target[0..group.target_len]);
            self.groups[self.group_count] = group;
            self.group_count += 1;
        }
        for (batches) |batch| try sendBatchImpl(t, allocator, target, batch);
    }

    /// The groups `sendBatches` was called with, in order.
    pub fn sentGroups(self: *const MockAmqpTransport) []const Group {
        return self.groups[0..self.group_count];
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
        runtime: core.http.HttpRuntime,
    ) !core.credentials.AccessToken {
        return self.tokenCredential().getToken(
            .{ .scopes = &.{token_scope} },
            ctx,
            runtime,
        );
    }
};

// ─────────────────────── Clients ───────────────────────

pub const ProducerClientOptions = struct {
    /// Copied runtime whose transport and crypto descriptors borrow backend
    /// contexts that must outlive this client and its credential calls.
    runtime: core.http.HttpRuntime,
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    /// Application id, custom endpoint, retry schedule, TLS, and WebSockets.
    connection: ConnectionOptions = .{},
};

/// Sends events to an Event Hub.
/// Whether two batches address the same link. Null is the gateway, which is a
/// distinct destination from any named partition rather than a wildcard.
fn samePartition(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.mem.eql(u8, a.?, b.?);
}

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
        runtime: core.http.HttpRuntime,
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
                .runtime = runtime,
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
        return self.credential.getToken(ctx, self.options.runtime);
    }

    /// Scratch space for an entity path that is only needed long enough to
    /// look a link up.
    ///
    /// Every send builds the same address to key `SenderPool` by, and it was
    /// costing an allocation each time. This holds it inline for any name
    /// Event Hubs accepts and only allocates for one it would not, so the
    /// longer name keeps working rather than becoming a client-side error.
    const EntityPath = struct {
        buf: [sending.entity_path_buffer_len]u8 = undefined,
        owned: ?[]u8 = null,

        fn resolve(
            self: *EntityPath,
            allocator: std.mem.Allocator,
            name: []const u8,
            partition_id: ?[]const u8,
        ) ![]const u8 {
            return sending.entityPathInto(&self.buf, name, partition_id) catch {
                const owned = try sending.entityPathFor(allocator, name, partition_id);
                self.owned = owned;
                return owned;
            };
        }

        fn deinit(self: *EntityPath, allocator: std.mem.Allocator) void {
            if (self.owned) |owned| allocator.free(owned);
        }
    };

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
        var entity_path: EntityPath = .{};
        defer entity_path.deinit(allocator);
        const address = try entity_path.resolve(allocator, self.options.event_hub_name, batch.partition_id);
        return self.amqp_transport.sendBatch(allocator, address, batch);
    }

    /// Send several batches, overlapping them on the wire instead of waiting
    /// for each to be confirmed before starting the next.
    ///
    /// This is `sendBatch` for callers that have more than one batch ready. A
    /// blocking send costs a full round trip per batch, so across a link with
    /// any real latency it is the round trips, not the encoding, that set the
    /// ceiling; overlapping them lifts it by roughly the window size.
    ///
    /// Batches are grouped into runs by partition, because each partition is a
    /// separate link and only batches sharing one can overlap. Passing them
    /// already grouped — which is the natural order if they were built per
    /// partition — makes every batch eligible.
    ///
    /// Retries and connection recovery are the same as `sendBatch`'s, and so
    /// is the guarantee: at-least-once, so a batch may be published twice if
    /// the broker accepted it but the acknowledgement was lost.
    ///
    /// Overlapping widens that window. When a send fails, the batches behind
    /// it are already on the wire and the broker may well accept them, but
    /// their verdicts are abandoned unread. They are then reported as not
    /// accepted and may be sent again, so a consumer can see them twice. The
    /// number at risk is bounded by `max_in_flight`, and the answer is the
    /// same as for `sendBatch`: give events an application property the
    /// consumer can deduplicate on.
    ///
    /// Nothing is silently dropped either way: a batch is only ever counted as
    /// accepted once the broker has said so.
    pub fn sendBatches(
        self: *ProducerClient,
        allocator: std.mem.Allocator,
        batches: []const EventDataBatch,
    ) !void {
        for (batches) |batch| {
            if (batch.count() == 0) return SendError.EmptyBatch;
        }

        var start: usize = 0;
        while (start < batches.len) {
            var end = start + 1;
            while (end < batches.len and samePartition(
                batches[start].partition_id,
                batches[end].partition_id,
            )) : (end += 1) {}

            var entity_path: EntityPath = .{};
            defer entity_path.deinit(allocator);
            const address = try entity_path.resolve(allocator, self.options.event_hub_name, batches[start].partition_id);
            try self.amqp_transport.sendBatches(allocator, address, batches[start..end]);

            start = end;
        }
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

        var entity_path: EntityPath = .{};
        defer entity_path.deinit(allocator);
        const address = try entity_path.resolve(allocator, self.options.event_hub_name, options.partition_id);

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
    /// Copied runtime whose transport and crypto descriptors borrow backend
    /// contexts that must outlive this client and its credential calls.
    runtime: core.http.HttpRuntime,
    fully_qualified_namespace: []const u8,
    event_hub_name: []const u8,
    consumer_group: []const u8 = "$Default",
    /// Identifies this reader to the broker, so a stolen link names who took
    /// it. Borrowed, and must outlive the client.
    instance_id: ?[]const u8 = null,
    /// Application id, custom endpoint, retry schedule, TLS, and WebSockets.
    connection: ConnectionOptions = .{},
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
        runtime: core.http.HttpRuntime,
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
                .runtime = runtime,
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
        return self.credential.getToken(ctx, self.options.runtime);
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
    /// `receive_timeout_ms` is renewed against the AMQP clock for every call.
    pub fn newPartitionClient(
        self: *ConsumerClient,
        client: *PartitionClient,
        allocator: std.mem.Allocator,
        session: *amqp.Session,
        partition_id: []const u8,
        receive_timeout_ms: i64,
        options: PartitionClientOptions,
    ) !void {
        const source = try self.consumerPath(allocator, partition_id);
        defer allocator.free(source);

        try client.open(allocator, session, .{
            .source_address = source,
            .instance_id = self.instanceId(),
            .deadline_ms = receive_timeout_ms,
        }, options);
    }

    /// A `PartitionOpener` over this client and one session.
    ///
    /// This is what a `Processor` reads through: it knows partition ids and
    /// how to attach a reader, which is everything the balancing loop needs
    /// from a connection. `timeout_ms` is a duration renewed against the
    /// current AMQP clock for every open and close attempt.
    pub fn partitionOpener(
        self: *ConsumerClient,
        connection: *recovery.RecoverableConnection,
        timeout_ms: i64,
    ) ConsumerPartitionOpener {
        return .{ .client = self, .connection = connection, .timeout_ms = timeout_ms };
    }

    /// Build a processor that reads this hub through `opener`.
    pub fn newProcessor(
        self: *ConsumerClient,
        allocator: std.mem.Allocator,
        store: *CheckpointStore,
        opener: *PartitionOpener,
        options: ProcessorOptions,
        clock: *load_balancing.Clock,
        random: std.Random,
    ) Processor {
        return Processor.init(allocator, store, opener, .{
            .fully_qualified_namespace = self.options.fully_qualified_namespace,
            .event_hub_name = self.options.event_hub_name,
            .consumer_group = self.options.consumer_group,
            .client_id = self.instanceId(),
        }, options, clock, random);
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

/// A `PartitionOpener` backed by a `ConsumerClient` and one session.
pub const ConsumerPartitionOpener = struct {
    client: *ConsumerClient,
    /// The session is resolved per open rather than held: a recovered
    /// connection has a new one, and a link attached to the old session would
    /// be attached to nothing.
    connection: *recovery.RecoverableConnection,
    /// Per-attempt duration. Each open and close converts it to a fresh
    /// absolute deadline on the current AMQP generation's clock.
    timeout_ms: i64,
    opener: PartitionOpener = .{
        .partitionIdsFn = partitionIds,
        .openFn = openPartition,
        .closeFn = closePartition,
        .abortFn = abortPartition,
    },

    pub fn asOpener(self: *ConsumerPartitionOpener) *PartitionOpener {
        return &self.opener;
    }

    fn partitionIds(o: *PartitionOpener, allocator: std.mem.Allocator) anyerror![][]const u8 {
        const self: *ConsumerPartitionOpener = @fieldParentPtr("opener", o);
        var props = try self.client.getEventHubProperties(allocator);
        defer props.deinit();

        const ids = try allocator.alloc([]const u8, props.partition_ids.len);
        errdefer allocator.free(ids);
        var filled: usize = 0;
        errdefer for (ids[0..filled]) |id| allocator.free(id);
        for (ids, props.partition_ids) |*slot, id| {
            slot.* = try allocator.dupe(u8, id);
            filled += 1;
        }
        return ids;
    }

    fn openPartition(
        o: *PartitionOpener,
        allocator: std.mem.Allocator,
        partition_id: []const u8,
        position: EventPosition,
        options: PartitionClientOptions,
    ) anyerror!*PartitionClient {
        const self: *ConsumerPartitionOpener = @fieldParentPtr("opener", o);

        const client = try allocator.create(PartitionClient);
        errdefer allocator.destroy(client);

        const generation = try self.connection.ensureOpen();
        const session = try self.connection.session();
        const source = try self.client.consumerPath(allocator, partition_id);
        defer allocator.free(source);
        var with_position = options;
        with_position.start_position = position;
        client.open(allocator, session, .{
            .source_address = source,
            .instance_id = self.client.instanceId(),
            .deadline_ms = self.timeout_ms,
            .generation_guard = .{
                .context = self.connection,
                .generation = generation,
                .isCurrentFn = generationIsCurrent,
            },
        }, with_position) catch |err| {
            // A replicated namespace refuses an offset carried over from
            // before a failover. Say so in the error so the processor can
            // restart the partition rather than abandon it.
            const geo_rejected =
                err == error.LinkDetached and sawGeoReplicationRejection(session);
            self.connection.invalidateGeneration(generation);
            if (geo_rejected) {
                return error.GeoReplicationOffsetRejected;
            }
            return err;
        };
        return client;
    }

    /// Whether the attach that just failed was refused for a geo-replicated
    /// offset. The link never attached, so the condition is only readable
    /// from the detached receiver the session still holds.
    fn sawGeoReplicationRejection(session: *amqp.Session) bool {
        for (session.receivers.items) |receiver| {
            const remote = receiver.detach_error orelse continue;
            if (load_balancing.isGeoReplicationOffsetError(remote.condition)) return true;
        }
        return false;
    }

    fn closePartition(o: *PartitionOpener, client: *PartitionClient) anyerror!void {
        const self: *ConsumerPartitionOpener = @fieldParentPtr("opener", o);
        const generation = client.generation();
        client.closeAfter(self.timeout_ms) catch |err| {
            if (err != error.DetachUnconfirmed) return err;
            if (generation) |value| self.connection.invalidateGeneration(value);
            client.deinit();
        };
        client.allocator.destroy(client);
    }

    fn abortPartition(o: *PartitionOpener, client: *PartitionClient) void {
        const self: *ConsumerPartitionOpener = @fieldParentPtr("opener", o);
        const generation = client.generation();
        client.closeAfter(self.timeout_ms) catch {
            if (generation) |value| self.connection.invalidateGeneration(value);
            client.deinit();
        };
        client.allocator.destroy(client);
    }

    fn generationIsCurrent(context: *anyopaque, generation: u64) bool {
        const connection: *recovery.RecoverableConnection = @ptrCast(@alignCast(context));
        return connection.isGenerationCurrent(generation);
    }
};

// ─────────────────────── Connecting ───────────────────────

/// Puts the client's CBS token on a session before any link attaches.
///
/// A rebuilt connection carries no claims, so recovery re-authorises through
/// this before reattaching. The `$cbs` link pair is opened and torn down per
/// authorisation: it is only needed for the round trip, and holding it across
/// a rebuild would leave a link pointing at a dead session.
pub const CbsAuthorizer = struct {
    allocator: std.mem.Allocator,
    /// The credential to sign with. Bound after the client is built, because
    /// a connection-string client owns the credential it creates.
    credential: ?*Credential = null,
    /// `amqps://{fqns}/{hub}`. Owned when `bind` copied it.
    audience: ?[]u8 = null,
    /// Copied descriptor whose backend contexts remain caller-owned.
    runtime: ?core.http.HttpRuntime = null,
    link_id: []const u8 = "eventhubs",
    ctx: core.context.Context = .none,
    authorizer: recovery.Authorizer = .{ .authorizeFn = authorize },

    pub fn bind(
        self: *CbsAuthorizer,
        credential: *Credential,
        audience: []const u8,
        runtime: core.http.HttpRuntime,
    ) !void {
        const owned = try self.allocator.dupe(u8, audience);
        if (self.audience) |old| self.allocator.free(old);
        self.audience = owned;
        self.credential = credential;
        self.runtime = runtime;
    }

    pub fn deinit(self: *CbsAuthorizer) void {
        if (self.audience) |audience| self.allocator.free(audience);
        self.audience = null;
    }

    pub fn asAuthorizer(self: *CbsAuthorizer) *recovery.Authorizer {
        return &self.authorizer;
    }

    fn authorize(a: *recovery.Authorizer, session: *amqp.Session, deadline_ms: i64) anyerror!void {
        const self: *CbsAuthorizer = @fieldParentPtr("authorizer", a);
        const credential = self.credential orelse return error.CredentialNotBound;
        const audience = self.audience orelse return error.CredentialNotBound;
        const runtime = self.runtime orelse return error.CredentialNotBound;

        var token = try credential.getToken(self.ctx, runtime);
        defer token.deinit();

        const client = try amqp.Cbs.open(session, .{ .link_id = self.link_id }, deadline_ms);
        defer client.deinit();

        try client.putToken(audience, .{
            .token = token.token,
            .expires_on_ms = token.expires_on * std.time.ms_per_s,
            .kind = switch (credential.*) {
                .token => .jwt,
                .sas => .sas,
            },
            .refreshable = credential.isRefreshable(),
        }, deadline_ms);
        client.close(deadline_ms) catch {};
    }
};

/// Everything a client needs to reach a namespace, assembled.
///
/// The pieces are individually usable — this only saves a caller from wiring
/// a factory, an authorizer, a recoverable connection, and a transport by
/// hand. It holds interior pointers, so initialise it in place and never copy
/// it after `open`.
pub const HubConnection = struct {
    allocator: std.mem.Allocator,
    sleeper: errors.IoSleeper,
    prng: std.Random.DefaultPrng,
    factory: connection_options.AmqpConnectionFactory,
    authorizer: CbsAuthorizer,
    connection: recovery.RecoverableConnection,
    transport: LinkTransport,

    pub const Options = struct {
        allocator: std.mem.Allocator,
        io: std.Io,
        fully_qualified_namespace: []const u8,
        /// Identifies this connection to the service. Go uses a GUID.
        container_id: []const u8 = "azure-sdk-for-zig",
        /// Distinguishes this client's links from any other on the connection.
        link_id: []const u8 = "eventhubs",
        /// How many batches a sender link may have on the wire unconfirmed.
        /// This is what lets `sendBatches` overlap them; `sendBatch` waits for
        /// each one either way.
        max_in_flight: u32 = sending.default_max_in_flight,
        /// Identifies this reader to the broker, and is what a stolen-link
        /// message names.
        instance_id: []const u8 = default_instance_id,
        connection: ConnectionOptions = .{},
        partition_client: PartitionClientOptions = .{},
        /// How long any one operation may take, including its recovery.
        deadline_ms: i64 = 60_000,
        /// Seed for the retry jitter.
        seed: u64 = 0,
    };

    /// Initialise in place. Nothing dials until the first operation runs.
    pub fn open(self: *HubConnection, options: Options) void {
        self.* = .{
            .allocator = options.allocator,
            .sleeper = errors.IoSleeper.init(options.io),
            .prng = std.Random.DefaultPrng.init(options.seed),
            .factory = .{
                .allocator = options.allocator,
                .io = options.io,
                .fully_qualified_namespace = options.fully_qualified_namespace,
                .container_id = options.container_id,
                .options = options.connection,
            },
            .authorizer = .{ .allocator = options.allocator },
            .connection = undefined,
            .transport = undefined,
        };
        self.connection = recovery.RecoverableConnection.init(options.allocator, .{
            .factory = &self.factory.factory,
            .authorizer = self.authorizer.asAuthorizer(),
            .deadline_ms = options.deadline_ms,
            .instance_id = options.instance_id,
            .link_id = options.link_id,
            .max_in_flight = options.max_in_flight,
            .partition_client = options.partition_client,
        });
        self.transport = LinkTransport.initRecoverable(
            &self.connection,
            options.connection.retryConfig(&self.sleeper.sleeper, self.prng.random()),
            .{ .deadline_ms = options.deadline_ms },
        );
    }

    /// Point the authorizer at the client's credential.
    ///
    /// Separate from `open` because a connection-string client owns the
    /// credential it parses, so the credential does not exist until after the
    /// client is built, and the client needs this transport to be built.
    pub fn bind(
        self: *HubConnection,
        credential: *Credential,
        audience: []const u8,
        runtime: core.http.HttpRuntime,
    ) !void {
        return self.authorizer.bind(credential, audience, runtime);
    }

    pub fn asTransport(self: *HubConnection) *AmqpTransport {
        return self.transport.asTransport();
    }

    pub fn deinit(self: *HubConnection) void {
        self.connection.deinit();
        self.authorizer.deinit();
    }
};

// ─────────────────────── Tests ───────────────────────

test "package version comes from the manifest" {
    try std.testing.expectEqualStrings("0.6.0", version);
}

// Zig only analyses a file it is told to. Re-exporting a type is not
// telling it: the decl is lazy, so the file's tests silently do not exist.
test {
    _ = @import("load_balancer.zig");
    _ = @import("processor.zig");
    _ = ConsumerPartitionOpener;
}

var testing_crypto_provider = core.crypto.StdCryptoProvider.init(std.testing.io);
var unused_http_context: u8 = 0;
const unused_http_vtable: core.http.HttpTransport.VTable = .{
    .send = struct {
        fn send(_: *anyopaque, _: *core.http.Request) anyerror!core.http.Response {
            return error.UnexpectedHttpRequest;
        }
    }.send,
};

fn testRuntime() core.http.HttpRuntime {
    return testRuntimeWithCrypto(testing_crypto_provider.asProvider());
}

fn testRuntimeWithCrypto(
    provider: core.crypto.CryptoProvider,
) core.http.HttpRuntime {
    return core.http.HttpRuntime.init(
        .{ .context = &unused_http_context, .vtable = &unused_http_vtable },
        provider,
    );
}

const TestCryptoProvider = struct {
    hmac_calls: usize = 0,
    fail: bool = false,

    const vtable: core.crypto.CryptoProvider.VTable = .{
        .random_bytes = &unusedRandomBytes,
        .md5 = &unusedMd5,
        .sha256 = &unusedSha256,
        .hmac_sha256 = &hmacSha256,
        .sha256_init = &unusedSha256Init,
    };

    fn provider(self: *TestCryptoProvider) core.crypto.CryptoProvider {
        return .{ .context = self, .vtable = &vtable };
    }

    fn unusedRandomBytes(_: *anyopaque, _: []u8) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn unusedMd5(_: *anyopaque, _: []const u8, _: *core.crypto.Md5Digest) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn unusedSha256(_: *anyopaque, _: []const u8, _: *core.crypto.Sha256Digest) !void {
        return error.UnexpectedCryptoOperation;
    }

    fn hmacSha256(
        context: *anyopaque,
        _: []const u8,
        _: []const u8,
        out: *core.crypto.HmacSha256Digest,
    ) !void {
        const self: *TestCryptoProvider = @ptrCast(@alignCast(context));
        self.hmac_calls += 1;
        if (self.fail) return error.ProviderFailure;
        @memset(out, 0xa5);
    }

    fn unusedSha256Init(
        _: *anyopaque,
        _: std.mem.Allocator,
    ) !core.crypto.Sha256Operation {
        return error.UnexpectedCryptoOperation;
    }
};

test "a hub connection wires itself up without dialling" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var hub: HubConnection = undefined;
    hub.open(.{
        .allocator = allocator,
        .io = threaded.io(),
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .container_id = "test",
    });
    defer hub.deinit();

    // Nothing has dialled, so there is no plumbing and no claim yet.
    try std.testing.expect(hub.connection.plumbing == null);
    try std.testing.expect(hub.authorizer.credential == null);

    var credential = Credential{ .sas = undefined };
    try hub.bind(
        &credential,
        "amqps://ns.servicebus.windows.net/hub",
        testRuntime(),
    );
    try std.testing.expectEqualStrings(
        "amqps://ns.servicebus.windows.net/hub",
        hub.authorizer.audience.?,
    );

    // Binding twice replaces rather than leaks: recovery rebinds after a
    // credential is swapped.
    try hub.bind(
        &credential,
        "amqps://ns.servicebus.windows.net/other",
        testRuntime(),
    );
    try std.testing.expectEqualStrings(
        "amqps://ns.servicebus.windows.net/other",
        hub.authorizer.audience.?,
    );
}

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
    for (0..batch.count()) |i| {
        const encoded = batch.payloadAt(i);
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
    var cred = cred_mod.ClientSecretCredential.init(allocator, "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .runtime = testRuntime(),
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
    var cred = cred_mod.ClientSecretCredential.init(allocator, "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .runtime = testRuntime(),
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
    var cred = cred_mod.ClientSecretCredential.init(allocator, "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .runtime = testRuntime(),
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
    var cred = cred_mod.ClientSecretCredential.init(allocator, "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .runtime = testRuntime(),
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
    var cred = cred_mod.ClientSecretCredential.init(allocator, "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var producer = ProducerClient.init(.{
        .runtime = testRuntime(),
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
    var cred = cred_mod.ClientSecretCredential.init(allocator, "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    mock_amqp.hub_properties = .{ .name = "my-hub", .partition_ids = &.{ "0", "1", "2" } };
    var producer = ProducerClient.init(.{
        .runtime = testRuntime(),
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
    var cred = cred_mod.ClientSecretCredential.init(allocator, "t", "c", "s");
    var mock_amqp = MockAmqpTransport.init();
    var consumer = ConsumerClient.init(.{
        .runtime = testRuntime(),
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "my-hub",
    }, cred.asCredential(), mock_amqp.asTransport());

    const events = try consumer.receiveEvents(allocator, "0", EventPosition.earliest(), 10);
    try std.testing.expectEqual(@as(usize, 0), events.len);
}

test "a client passes its window down to the connection that sizes the links" {
    const allocator = std.testing.allocator;
    var threaded: std.Io.Threaded = .init_single_threaded;
    defer threaded.deinit();

    var hub: HubConnection = undefined;
    hub.open(.{
        .allocator = allocator,
        .io = threaded.io(),
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .max_in_flight = 6,
    });
    defer hub.deinit();
    try std.testing.expectEqual(@as(u32, 6), hub.connection.sender_options.max_in_flight);
}

test "the pipeline refuses a link somebody else is still waiting on" {
    // Its accounting reads the link's depth as its own, and it empties the
    // whole ring on the way out, so sharing would both misreport which
    // batches landed and throw away a verdict its caller was waiting for.
    const allocator = std.testing.allocator;
    const harness = amqp.test_peer;

    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: amqp.connection_driver.ManualClock = .{};
    const peer = harness.Peer{ .allocator = allocator, .mem = &mem };

    try harness.scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = "my-hub-sender-eventhubs",
        .handle = 0,
        .role = .receiver,
        .max_message_size = null,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 20,
    } });

    var conn = try amqp.connection_driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var fixture = try harness.Fixture.init(allocator, &mem, &clock, &conn);
    defer fixture.deinit();

    var pool = SenderPool.init(allocator, &fixture.session, .{
        .deadline_ms = 10_000,
        .max_in_flight = 4,
    });
    defer pool.deinit();

    var batch = try EventDataBatch.init(.{});
    defer batch.deinit(allocator);
    var event = EventData.init("x");
    defer event.deinit(allocator);
    try std.testing.expect(try batch.tryAdd(allocator, event));

    // Someone takes a token and has not collected its verdict yet.
    _ = try pool.sendAsync(allocator, "my-hub", batch);
    try std.testing.expectEqual(@as(usize, 1), try pool.unconfirmed("my-hub"));

    const batches = [_]EventDataBatch{batch};
    const result = pool.sendPipelined(allocator, "my-hub", &batches);
    try std.testing.expectEqual(@as(usize, 0), result.accepted);
    try std.testing.expectEqual(@as(?anyerror, error.DeliveriesInFlight), result.err);

    // Refused rather than half-done: the other delivery is untouched, and
    // nothing of this call's was put on the wire.
    try std.testing.expectEqual(@as(usize, 1), try pool.unconfirmed("my-hub"));
}

test "the pipeline's fallback resends exactly the batches it was not told were accepted" {
    // `accepted` is the one number standing between a duplicated batch and a
    // dropped one, and `LinkTransport` is the only place it is turned into a
    // resend slice. So drive a real pool over a scripted peer and count what
    // actually reaches the wire.
    const allocator = std.testing.allocator;
    const harness = amqp.test_peer;

    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: amqp.connection_driver.ManualClock = .{};
    const peer = harness.Peer{ .allocator = allocator, .mem = &mem };

    try harness.scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = "my-hub-sender-eventhubs",
        .handle = 0,
        .role = .receiver,
        .max_message_size = null,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 20,
    } });

    // Window of two, three batches. The pipeline sends 0 and 1, retires 0 to
    // make room, sends 2, then collects 1 — which is refused. Delivery 2 is
    // still on the wire and gets abandoned, so the fallback owes batches 1
    // and 2, which it sends as deliveries 3 and 4.
    for ([_]struct { u32, bool }{ .{ 0, true }, .{ 1, false }, .{ 3, true }, .{ 4, true } }) |d| {
        try peer.push(0, .{ .disposition = .{
            .role = .receiver,
            .first = d[0],
            .last = d[0],
            .settled = true,
            .state = if (d[1]) .accepted else .{ .rejected = .{
                .condition = "amqp:link:message-size-exceeded",
                .description = "too big",
            } },
        } });
    }

    var conn = try amqp.connection_driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var fixture = try harness.Fixture.init(allocator, &mem, &clock, &conn);
    defer fixture.deinit();

    var pool = SenderPool.init(allocator, &fixture.session, .{
        .deadline_ms = 10_000,
        .max_in_flight = 2,
    });
    defer pool.deinit();

    var transport = LinkTransport.initEmpty(.{ .deadline_ms = 10_000 });
    transport.senders = &pool;

    var batches: [3]EventDataBatch = undefined;
    for (&batches, 0..) |*b, i| {
        b.* = try EventDataBatch.init(.{});
        var event = EventData.init(&[_]u8{@intCast('a' + i)});
        defer event.deinit(allocator);
        try std.testing.expect(try b.tryAdd(allocator, event));
    }
    defer for (&batches) |*b| b.deinit(allocator);

    try transport.transport.sendBatches(allocator, "my-hub", &batches);

    var frames = try harness.EmittedFrames.parse(allocator, mem.written());
    defer frames.deinit();
    const transfers = try frames.of(allocator, amqp.performative.descriptor.transfer);
    defer allocator.free(transfers);

    // Five, not six: the accepted batch 0 is never sent again. Six would mean
    // a duplicate, four would mean the refused batch was silently dropped.
    try std.testing.expectEqual(@as(usize, 5), transfers.len);
}

test "sendBatches leaves the link idle enough for an ordinary send afterwards" {
    // The failure path abandons deliveries, and a sender holding any refuses
    // every blocking send. If that were not cleaned up, the very next
    // `sendBatch` on the same client would fail for an unrelated reason.
    const allocator = std.testing.allocator;
    const harness = amqp.test_peer;

    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    var clock: amqp.connection_driver.ManualClock = .{};
    const peer = harness.Peer{ .allocator = allocator, .mem = &mem };

    try harness.scriptHandshake(peer, 512);
    try peer.push(0, .{ .attach = .{
        .name = "my-hub-sender-eventhubs",
        .handle = 0,
        .role = .receiver,
        .max_message_size = null,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1000,
        .next_outgoing_id = 1,
        .outgoing_window = 1000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 20,
    } });
    // Refuse the first, then accept the two resends and the later plain send.
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .{ .rejected = .{ .condition = "amqp:internal-error", .description = "no" } },
    } });
    for ([_]u32{ 2, 3, 4 }) |id| {
        try peer.push(0, .{ .disposition = .{
            .role = .receiver,
            .first = id,
            .last = id,
            .settled = true,
            .state = .accepted,
        } });
    }

    var conn = try amqp.connection_driver.Driver.init(allocator, mem.transport(), clock.clock(), harness.driver_options);
    defer conn.deinit();
    var fixture = try harness.Fixture.init(allocator, &mem, &clock, &conn);
    defer fixture.deinit();

    var pool = SenderPool.init(allocator, &fixture.session, .{
        .deadline_ms = 10_000,
        .max_in_flight = 2,
    });
    defer pool.deinit();
    var transport = LinkTransport.initEmpty(.{ .deadline_ms = 10_000 });
    transport.senders = &pool;

    var batches: [2]EventDataBatch = undefined;
    for (&batches) |*b| {
        b.* = try EventDataBatch.init(.{});
        var event = EventData.init("x");
        defer event.deinit(allocator);
        try std.testing.expect(try b.tryAdd(allocator, event));
    }
    defer for (&batches) |*b| b.deinit(allocator);

    // Batch 0 is refused, so both are resent; the resends are accepted.
    try transport.transport.sendBatches(allocator, "my-hub", &batches);
    try std.testing.expectEqual(@as(usize, 0), try pool.unconfirmed("my-hub"));

    // And a plain send still works on the same link.
    try transport.transport.sendBatch(allocator, "my-hub", batches[0]);
}

test "sendBatches groups batches by the link each one addresses" {
    // Only batches sharing a partition share a link, so only they can overlap
    // on the wire. Everything else has to be split.
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=hub";
    var producer = try ProducerClient.fromConnectionString(allocator, testRuntime(), cs, null, mock_amqp.asTransport());
    defer producer.deinit();

    const partitions = [_]?[]const u8{ "0", "0", "1", null, null };
    var batches: [partitions.len]EventDataBatch = undefined;
    for (&batches, partitions) |*b, partition| {
        b.* = try EventDataBatch.init(.{ .partition_id = partition });
        var event = EventData.init("hello");
        defer event.deinit(allocator);
        try std.testing.expect(try b.tryAdd(allocator, event));
    }
    defer for (&batches) |*b| b.deinit(allocator);

    try producer.sendBatches(allocator, &batches);

    const groups = mock_amqp.sentGroups();
    try std.testing.expectEqual(@as(usize, 3), groups.len);

    try std.testing.expectEqual(@as(usize, 2), groups[0].len);
    try std.testing.expectEqualStrings("hub/Partitions/0", groups[0].target());

    try std.testing.expectEqual(@as(usize, 1), groups[1].len);
    try std.testing.expectEqualStrings("hub/Partitions/1", groups[1].target());

    // Null is the gateway, a destination of its own rather than a wildcard
    // that could be folded into either partition's run.
    try std.testing.expectEqual(@as(usize, 2), groups[2].len);
    try std.testing.expectEqualStrings("hub", groups[2].target());

    // And every batch reached the wire exactly once.
    try std.testing.expectEqual(@as(u32, 5), mock_amqp.send_batch_count);
}

test "sendBatches keeps one run whole when every batch shares a partition" {
    // The case worth optimising: batches built per partition arrive already
    // grouped, so the whole slice is eligible to pipeline.
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=hub";
    var producer = try ProducerClient.fromConnectionString(allocator, testRuntime(), cs, null, mock_amqp.asTransport());
    defer producer.deinit();

    var batches: [4]EventDataBatch = undefined;
    for (&batches) |*b| {
        b.* = try EventDataBatch.init(.{ .partition_id = "3" });
        var event = EventData.init("hello");
        defer event.deinit(allocator);
        try std.testing.expect(try b.tryAdd(allocator, event));
    }
    defer for (&batches) |*b| b.deinit(allocator);

    try producer.sendBatches(allocator, &batches);

    const groups = mock_amqp.sentGroups();
    try std.testing.expectEqual(@as(usize, 1), groups.len);
    try std.testing.expectEqual(@as(usize, 4), groups[0].len);
    try std.testing.expectEqualStrings("hub/Partitions/3", groups[0].target());
}

test "sendBatches refuses an empty batch before sending anything" {
    // Checked up front rather than per batch: a caller that gets an error
    // should not have to work out how much of its slice went out first.
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=hub";
    var producer = try ProducerClient.fromConnectionString(allocator, testRuntime(), cs, null, mock_amqp.asTransport());
    defer producer.deinit();

    var full = try EventDataBatch.init(.{});
    defer full.deinit(allocator);
    var event = EventData.init("hello");
    defer event.deinit(allocator);
    try std.testing.expect(try full.tryAdd(allocator, event));

    var empty = try EventDataBatch.init(.{});
    defer empty.deinit(allocator);

    const batches = [_]EventDataBatch{ full, empty };
    try std.testing.expectError(SendError.EmptyBatch, producer.sendBatches(allocator, &batches));
    try std.testing.expect(!mock_amqp.send_called);
}

test "a transport that cannot pipeline still sends every batch" {
    // `sendBatchesFn` is optional so an implementation outside this package
    // keeps compiling and keeps working; the default just costs a round trip
    // per batch.
    const allocator = std.testing.allocator;

    const Serial = struct {
        transport: AmqpTransport,
        count: u32 = 0,

        fn sendBatchImpl(t: *AmqpTransport, _: std.mem.Allocator, _: []const u8, _: EventDataBatch) !void {
            const self: *@This() = @fieldParentPtr("transport", t);
            self.count += 1;
        }
        fn unreachableReceive(_: *AmqpTransport, _: std.mem.Allocator, _: []const u8, _: ?[]const u8, _: u32) ![]ReceivedEventData {
            return error.Unimplemented;
        }
        fn unreachableHub(_: *AmqpTransport, _: std.mem.Allocator, _: []const u8) !EventHubProperties {
            return error.Unimplemented;
        }
        fn unreachablePartition(_: *AmqpTransport, _: std.mem.Allocator, _: []const u8, _: []const u8) !PartitionProperties {
            return error.Unimplemented;
        }
        fn noLimit(_: *AmqpTransport, _: []const u8) !?u64 {
            return null;
        }
        fn closeImpl(_: *AmqpTransport) void {}
    };

    var serial = Serial{ .transport = .{
        .sendBatchFn = &Serial.sendBatchImpl,
        .receiveFn = &Serial.unreachableReceive,
        .getHubPropertiesFn = &Serial.unreachableHub,
        .getPartitionPropertiesFn = &Serial.unreachablePartition,
        .maxMessageSizeFn = &Serial.noLimit,
        .closeFn = &Serial.closeImpl,
    } };
    try std.testing.expect(serial.transport.sendBatchesFn == null);

    var batches: [3]EventDataBatch = undefined;
    for (&batches) |*b| {
        b.* = try EventDataBatch.init(.{});
        var event = EventData.init("hello");
        defer event.deinit(allocator);
        try std.testing.expect(try b.tryAdd(allocator, event));
    }
    defer for (&batches) |*b| b.deinit(allocator);

    try serial.transport.sendBatches(allocator, "hub", &batches);
    try std.testing.expectEqual(@as(u32, 3), serial.count);
}

test "ProducerClient fromConnectionString" {
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://mynamespace.servicebus.windows.net/;SharedAccessKeyName=mykey;SharedAccessKey=abc123=;EntityPath=myhub";
    var producer = try ProducerClient.fromConnectionString(allocator, testRuntime(), cs, null, mock_amqp.asTransport());
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
    var producer = try ProducerClient.fromConnectionString(allocator, testRuntime(), cs, "hub2", mock_amqp.asTransport());
    defer producer.deinit();
    try std.testing.expectEqualStrings("hub2", producer.options.event_hub_name);
    try std.testing.expectEqualStrings("amqps://ns.servicebus.windows.net/hub2", producer.owned_audience.?);
}

test "ProducerClient fromConnectionString missing hub" {
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v";
    const result = ProducerClient.fromConnectionString(std.testing.allocator, testRuntime(), cs, null, mock_amqp.asTransport());
    try std.testing.expectError(error.MissingEventHubName, result);
}

test "ConsumerClient fromConnectionString" {
    const allocator = std.testing.allocator;
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=v;EntityPath=hub";
    var consumer = try ConsumerClient.fromConnectionString(allocator, testRuntime(), cs, null, mock_amqp.asTransport());
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
        _: core.http.HttpRuntime,
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
    var producer = try ProducerClient.fromConnectionString(allocator, testRuntime(), cs, null, mock_amqp.asTransport());
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

test "connection string credential uses the selected runtime crypto provider" {
    const allocator = std.testing.allocator;
    var provider = TestCryptoProvider{};
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=policy;SharedAccessKey=c2VjcmV0;EntityPath=hub";
    var producer = try ProducerClient.fromConnectionString(
        allocator,
        testRuntimeWithCrypto(provider.provider()),
        cs,
        null,
        mock_amqp.asTransport(),
    );
    defer producer.deinit();

    var token = try producer.getToken(.none);
    defer token.deinit();
    try std.testing.expectEqual(@as(usize, 1), provider.hmac_calls);
}

test "connection string credential propagates runtime crypto provider failure" {
    const allocator = std.testing.allocator;
    var provider = TestCryptoProvider{ .fail = true };
    var mock_amqp = MockAmqpTransport.init();
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=policy;SharedAccessKey=c2VjcmV0;EntityPath=hub";
    var producer = try ProducerClient.fromConnectionString(
        allocator,
        testRuntimeWithCrypto(provider.provider()),
        cs,
        null,
        mock_amqp.asTransport(),
    );
    defer producer.deinit();

    try std.testing.expectError(error.ProviderFailure, producer.getToken(.none));
    try std.testing.expectEqual(@as(usize, 1), provider.hmac_calls);
}

test "AAD credential is asked for the Event Hubs scope" {
    var mock_amqp = MockAmqpTransport.init();
    var recorder = ScopeRecordingCredential.init();
    var producer = ProducerClient.init(.{
        .runtime = testRuntime(),
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
        .runtime = testRuntime(),
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
    var producer = try ProducerClient.fromConnectionString(allocator, testRuntime(), cs, null, mock_amqp.asTransport());
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

test "the entity path stays on the stack for a real hub and falls back for a long one" {
    const allocator = std.testing.allocator;

    {
        var entity_path: ProducerClient.EntityPath = .{};
        defer entity_path.deinit(allocator);
        const address = try entity_path.resolve(allocator, "my-hub", "3");
        try std.testing.expectEqualStrings("my-hub/Partitions/3", address);
        // Nothing was allocated: the path points into the struct's own buffer.
        try std.testing.expect(entity_path.owned == null);
        try std.testing.expect(@intFromPtr(address.ptr) == @intFromPtr(&entity_path.buf));
    }

    {
        var entity_path: ProducerClient.EntityPath = .{};
        defer entity_path.deinit(allocator);
        const address = try entity_path.resolve(allocator, "hub-with-no-partition", null);
        try std.testing.expectEqualStrings("hub-with-no-partition", address);
        try std.testing.expect(entity_path.owned == null);
    }

    {
        // Longer than Event Hubs accepts, so the inline buffer cannot hold it.
        // It has to keep working rather than become a client-side error, which
        // is the whole reason the fallback exists.
        const long_name = "n" ** (sending.entity_path_buffer_len + 16);
        var entity_path: ProducerClient.EntityPath = .{};
        defer entity_path.deinit(allocator);
        const address = try entity_path.resolve(allocator, long_name, "7");
        try std.testing.expectEqualStrings(long_name ++ "/Partitions/7", address);
        // And this one did allocate, so `deinit` has something to release.
        try std.testing.expect(entity_path.owned != null);
    }
}
