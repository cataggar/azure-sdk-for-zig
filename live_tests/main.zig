//! Destructive, explicit opt-in Azure Event Hubs live coverage.
//!
//! Every test skips when the environment is not configured, so this compiles
//! and runs in CI without any Azure resources. Configure it with:
//!
//! - `AZURE_EVENTHUBS_LIVE_TESTS=1` — opt in. Without it every test skips,
//!   and any other value is an error rather than a silent skip.
//! - `AZURE_EVENTHUBS_CONNECTION_STRING` — namespace connection string, with
//!   or without an `EntityPath`.
//! - `AZURE_EVENTHUBS_HUB_NAME` — the hub, required when the connection
//!   string carries no `EntityPath`.
//! - `AZURE_EVENTHUBS_CONSUMER_GROUP` — optional, defaults to `$Default`.
//! - `AZURE_EVENTHUBS_STORAGE_ENDPOINT`, `AZURE_EVENTHUBS_STORAGE_CONTAINER`,
//!   and `AZURE_TOKEN` — optional; only the checkpoint-store test needs them,
//!   and it skips without all three.
//!
//! These tests publish to the hub and write checkpoint blobs, so point them
//! at resources you do not mind polluting.

const std = @import("std");
const core = @import("azure_sdk_core");
const blobs = @import("azure_sdk_storage_blobs");
const eh = @import("azure_sdk_eventhubs");

const testing = std.testing;

const Config = struct {
    connection_string: []const u8,
    hub_name: ?[]const u8,
    consumer_group: []const u8,
    storage: ?Storage,

    const Storage = struct {
        endpoint: []const u8,
        container: []const u8,
        token: []const u8,
    };

    /// Null means "not configured", which the caller turns into a skip. A
    /// malformed opt-in is an error: silently skipping a run someone asked
    /// for is worse than failing it.
    fn fromEnvironment(env: *const std.process.Environ.Map) !?Config {
        const enabled = nonEmpty(env.get("AZURE_EVENTHUBS_LIVE_TESTS")) orelse
            return null;
        if (!std.mem.eql(u8, enabled, "1"))
            return error.InvalidEventHubsLiveTestOptIn;
        const connection_string = nonEmpty(
            env.get("AZURE_EVENTHUBS_CONNECTION_STRING"),
        ) orelse return error.EventHubsConnectionStringRequired;
        const hub_name = nonEmpty(env.get("AZURE_EVENTHUBS_HUB_NAME"));
        // Fail here rather than at the first operation: the hub name decides
        // every address the tests build.
        const parsed = try eh.ConnectionStringProperties.parse(connection_string);
        if (hub_name == null and parsed.entity_path == null)
            return error.EventHubsHubNameRequired;
        return .{
            .connection_string = connection_string,
            .hub_name = hub_name,
            .consumer_group = nonEmpty(
                env.get("AZURE_EVENTHUBS_CONSUMER_GROUP"),
            ) orelse "$Default",
            .storage = storageFrom(env),
        };
    }

    fn storageFrom(env: *const std.process.Environ.Map) ?Storage {
        return .{
            .endpoint = nonEmpty(env.get("AZURE_EVENTHUBS_STORAGE_ENDPOINT")) orelse
                return null,
            .container = nonEmpty(env.get("AZURE_EVENTHUBS_STORAGE_CONTAINER")) orelse
                return null,
            .token = nonEmpty(env.get("AZURE_TOKEN")) orelse return null,
        };
    }

    fn hub(self: Config) ![]const u8 {
        if (self.hub_name) |name| return name;
        const parsed = try eh.ConnectionStringProperties.parse(self.connection_string);
        return parsed.entity_path.?;
    }

    fn namespace(self: Config) ![]const u8 {
        const parsed = try eh.ConnectionStringProperties.parse(self.connection_string);
        return parsed.fully_qualified_namespace;
    }
};

fn nonEmpty(value: ?[]const u8) ?[]const u8 {
    const v = value orelse return null;
    return if (v.len == 0) null else v;
}

/// One authorised connection to a hub, plus a producer over it.
///
/// Heap-allocated and initialised in place because it holds interior
/// pointers: the CBS authorizer points at the producer's credential, and the
/// transport at the connection. Copying it by value would leave both dangling.
const LiveSession = struct {
    allocator: std.mem.Allocator,
    http: core.http.StdHttpTransport,
    crypto: core.crypto.StdCryptoProvider,
    runtime: core.http.HttpRuntime,
    hub: eh.HubConnection,
    producer: eh.ProducerClient,
    audience: []u8,

    fn create(
        allocator: std.mem.Allocator,
        io: std.Io,
        config: Config,
    ) !*LiveSession {
        const self = try allocator.create(LiveSession);
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.http = core.http.StdHttpTransport.init(allocator, io);
        errdefer self.http.deinit();
        self.crypto = core.crypto.StdCryptoProvider.init(io);
        self.runtime = core.http.HttpRuntime.init(
            self.http.asTransport(),
            self.crypto.asProvider(),
        );

        self.hub.open(.{
            .allocator = allocator,
            .io = io,
            .fully_qualified_namespace = try config.namespace(),
            .container_id = "azure-sdk-for-zig-live",
        });
        errdefer self.hub.deinit();

        self.producer = try eh.ProducerClient.fromConnectionString(
            allocator,
            self.runtime,
            config.connection_string,
            config.hub_name,
            self.hub.asTransport(),
        );
        errdefer self.producer.deinit();

        self.audience = try self.producer.entityAudience(allocator);
        errdefer allocator.free(self.audience);
        try self.hub.bind(
            &self.producer.credential,
            self.audience,
            self.producer.options.runtime,
        );
        return self;
    }

    /// A consumer sharing this session's connection and claim.
    ///
    /// The connection is already authorised for the hub, so this only needs
    /// its own client state; the receiver links attach over the same session.
    fn consumer(self: *LiveSession, config: Config) !eh.ConsumerClient {
        var client = try eh.ConsumerClient.fromConnectionString(
            self.allocator,
            self.runtime,
            config.connection_string,
            config.hub_name,
            self.hub.asTransport(),
        );
        client.options.consumer_group = config.consumer_group;
        return client;
    }

    fn deinit(self: *LiveSession) void {
        self.allocator.free(self.audience);
        self.producer.deinit();
        self.hub.deinit();
        self.http.deinit();
        self.allocator.destroy(self);
    }
};

test "live: a batch sent to a partition is read back from it" {
    const allocator = testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const config = (try Config.fromEnvironment(&env)) orelse
        return error.SkipZigTest;

    const session = try LiveSession.create(allocator, std.testing.io, config);
    defer session.deinit();

    // Address one partition explicitly. Without a partition id the service
    // picks, and the events could land anywhere, so the read would be racy.
    var properties = try session.producer.getEventHubProperties(allocator);
    defer properties.deinit();
    try testing.expect(properties.partition_ids.len > 0);
    const partition_id = properties.partition_ids[0];

    // The watermark before the send is where the read resumes from, so it
    // sees exactly what this test wrote rather than the whole partition.
    var before = try session.producer.getPartitionProperties(allocator, partition_id);
    defer before.deinit();

    var batch = try session.producer.createBatch(allocator, .{
        .partition_id = partition_id,
    });
    defer batch.deinit(allocator);
    try testing.expect(try batch.tryAdd(allocator, eh.EventData.init("live-test-one")));
    try testing.expect(try batch.tryAdd(allocator, eh.EventData.init("live-test-two")));
    try testing.expectEqual(@as(usize, 2), batch.count());
    try session.producer.sendBatch(allocator, batch);

    var after = try session.producer.getPartitionProperties(allocator, partition_id);
    defer after.deinit();
    try testing.expectEqual(
        before.last_enqueued_sequence_number + 2,
        after.last_enqueued_sequence_number,
    );

    var consumer = try session.consumer(config);
    defer consumer.deinit();

    const events = try consumer.receiveEvents(
        allocator,
        partition_id,
        eh.EventPosition.fromSequenceNumber(before.last_enqueued_sequence_number, false),
        2,
    );
    defer eh.freeReceivedEvents(allocator, events);

    try testing.expectEqual(@as(usize, 2), events.len);
    try testing.expectEqualStrings("live-test-one", events[0].body());
    try testing.expectEqualStrings("live-test-two", events[1].body());
}

test "live: hub and partition properties describe the same hub" {
    const allocator = testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const config = (try Config.fromEnvironment(&env)) orelse
        return error.SkipZigTest;

    const session = try LiveSession.create(allocator, std.testing.io, config);
    defer session.deinit();

    var properties = try session.producer.getEventHubProperties(allocator);
    defer properties.deinit();

    try testing.expectEqualStrings(try config.hub(), properties.name);
    try testing.expect(properties.partition_ids.len > 0);

    for (properties.partition_ids) |partition_id| {
        var partition = try session.producer.getPartitionProperties(
            allocator,
            partition_id,
        );
        defer partition.deinit();

        try testing.expectEqualStrings(partition_id, partition.id);
        try testing.expectEqualStrings(properties.name, partition.event_hub_name);
        // An empty partition reports a last sequence number one below the
        // first, so this holds either way.
        try testing.expect(
            partition.last_enqueued_sequence_number >=
                partition.beginning_sequence_number - 1,
        );
    }
}

test "live: a checkpoint written to blob storage is listed back" {
    const allocator = testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const config = (try Config.fromEnvironment(&env)) orelse
        return error.SkipZigTest;
    const storage = config.storage orelse return error.SkipZigTest;

    var http = core.http.StdHttpTransport.init(allocator, std.testing.io);
    defer http.deinit();
    var crypto_provider = core.crypto.StdCryptoProvider.init(std.testing.io);
    const runtime = core.http.HttpRuntime.init(
        http.asTransport(),
        crypto_provider.asProvider(),
    );

    var credential = core.env_token.EnvTokenCredential.init(allocator, storage.token);
    var auth_policy = core.http.BearerTokenAuthPolicy.init(
        allocator,
        credential.asCredential(),
        blobs.auth_scopes,
    );
    defer auth_policy.deinit();
    var policies = [_]*core.http.HttpPolicy{auth_policy.asPolicy()};
    const pipeline = core.http.HttpPipeline.init(runtime, &policies);
    var container = blobs.BlobContainerClient.init(pipeline, .{
        .endpoint = storage.endpoint,
        .container_name = storage.container,
    });

    var blob_store = eh.checkpoint_store_blob.BlobCheckpointStore.init(&container);
    const store = blob_store.asCheckpointStore();

    const namespace = try config.namespace();
    const hub_name = try config.hub();
    // Its own consumer group, so this cannot disturb the ownership a real
    // fleet holds in the same container.
    const consumer_group = "azure-sdk-for-zig-live";

    try store.updateCheckpoint(allocator, .{
        .fully_qualified_namespace = namespace,
        .event_hub_name = hub_name,
        .consumer_group = consumer_group,
        .partition_id = "0",
        .sequence_number = 42,
        .offset = "42",
    });

    const checkpoints = try store.listCheckpoints(
        allocator,
        namespace,
        hub_name,
        consumer_group,
    );
    defer eh.freeCheckpoints(allocator, checkpoints);

    var found = false;
    for (checkpoints) |checkpoint| {
        if (!std.mem.eql(u8, checkpoint.partition_id, "0")) continue;
        found = true;
        try testing.expectEqual(@as(?i64, 42), checkpoint.sequence_number);
        try testing.expectEqualStrings("42", checkpoint.offset.?);
    }
    try testing.expect(found);

    // Ownership round-trips through the same container, and the store must
    // report back what it stamped rather than what we asked for.
    const claimed = try store.claimOwnership(allocator, &.{.{
        .fully_qualified_namespace = namespace,
        .event_hub_name = hub_name,
        .consumer_group = consumer_group,
        .partition_id = "0",
        .owner_id = "live-test",
    }});
    defer eh.freeOwnerships(allocator, claimed);
    try testing.expectEqual(@as(usize, 1), claimed.len);
    try testing.expectEqualStrings("live-test", claimed[0].owner_id);
    try testing.expect(claimed[0].etag != null);
    try testing.expect(claimed[0].last_modified_time != null);
}

test "live: a lone processor claims every partition" {
    const allocator = testing.allocator;
    var env = try std.process.Environ.createMap(std.testing.environ, allocator);
    defer env.deinit();
    const config = (try Config.fromEnvironment(&env)) orelse
        return error.SkipZigTest;

    const session = try LiveSession.create(allocator, std.testing.io, config);
    defer session.deinit();

    var properties = try session.producer.getEventHubProperties(allocator);
    defer properties.deinit();

    var consumer = try session.consumer(config);
    defer consumer.deinit();

    // In memory rather than blob-backed: this asserts the balancing loop
    // against a real hub, not the store, and it must not disturb the
    // ownership a real fleet holds in a shared container.
    var clock = eh.SystemClock{ .io = std.testing.io };
    var store = eh.InMemoryCheckpointStore{
        .allocator = allocator,
        .clock = &clock.clock,
    };
    defer store.deinit();

    var opener = consumer.partitionOpener(&session.hub.connection, 60_000);
    var prng = std.Random.DefaultPrng.init(@bitCast(clock.clock.nowMillis()));

    var processor = consumer.newProcessor(
        allocator,
        &store.store,
        opener.asOpener(),
        .{ .load_balancing_strategy = .greedy },
        &clock.clock,
        prng.random(),
    );
    // Relinquishes every claim, so a rerun starts from a clean slate.
    defer processor.deinit();

    // Greedy takes its whole fair share in one cycle, and alone that is
    // every partition.
    try processor.runOnce();
    try testing.expectEqual(
        properties.partition_ids.len,
        processor.ownedPartitions().len,
    );

    var handed_out: usize = 0;
    while (processor.nextPartitionClient()) |partition| : (handed_out += 1) {
        try testing.expect(partition.partitionId().len > 0);
        // A partition with nothing in it returns an empty slice rather than
        // blocking until the deadline.
        const events = try partition.receiveEvents(allocator, 1);
        defer eh.freeReceivedEvents(allocator, events);
    }
    try testing.expectEqual(properties.partition_ids.len, handed_out);
    try processor.close();
}
