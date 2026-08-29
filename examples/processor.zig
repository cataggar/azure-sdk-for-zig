//! Run a `Processor` over a hub, checkpointing to Azure Blob Storage.
//!
//! Usage:
//!   EVENTHUB_CONNECTION_STRING=... AZURE_TOKEN=$(az account get-access-token \
//!       --resource https://storage.azure.com --query accessToken -o tsv) \
//!   ./zig-out/bin/eventhubs-processor <hub> <storage-endpoint> <container>
//!
//! Every processor in a fleet runs this same loop. They coordinate only
//! through the checkpoint store, so starting another copy of this program
//! against the same container takes over half the partitions.

const std = @import("std");
const core = @import("azure_sdk_core");
const blobs = @import("azure_sdk_storage_blobs");
const eh = @import("azure_sdk_eventhubs");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const hub_name = args.next() orelse return error.MissingEventHubName;
    const storage_endpoint = args.next() orelse return error.MissingStorageEndpoint;
    const container_name = args.next() orelse return error.MissingContainerName;

    const connection_string = init.environ_map.get("EVENTHUB_CONNECTION_STRING") orelse
        return error.MissingConnectionString;
    const properties = try eh.ConnectionStringProperties.parse(connection_string);

    // ── Checkpoint store ──────────────────────────────────────────────
    var http = core.http.StdHttpTransport.init(allocator, init.io);
    defer http.deinit();
    var crypto_provider = core.crypto.StdCryptoProvider.init(init.io);
    const runtime = core.http.HttpRuntime.init(
        http.asTransport(),
        crypto_provider.asProvider(),
    );

    var storage_credential = core.env_token.EnvTokenCredential.init(
        allocator,
        init.environ_map.get("AZURE_TOKEN") orelse return error.MissingAzureToken,
    );

    var auth_policy = core.http.BearerTokenAuthPolicy.init(
        allocator,
        storage_credential.asCredential(),
        blobs.auth_scopes,
    );
    defer auth_policy.deinit();
    var storage_policies = [_]*core.http.HttpPolicy{auth_policy.asPolicy()};
    const storage_pipeline = core.http.HttpPipeline.init(runtime, &storage_policies);
    var container = blobs.BlobContainerClient.init(storage_pipeline, .{
        .endpoint = storage_endpoint,
        .container_name = container_name,
    });

    var store = eh.checkpoint_store_blob.BlobCheckpointStore.init(&container);

    // ── Event Hubs ────────────────────────────────────────────────────
    var hub: eh.HubConnection = undefined;
    hub.open(.{
        .allocator = allocator,
        .io = init.io,
        .fully_qualified_namespace = properties.fully_qualified_namespace,
        .container_id = "eventhubs-processor",
    });
    defer hub.deinit();

    var consumer = try eh.ConsumerClient.fromConnectionString(
        allocator,
        runtime,
        connection_string,
        hub_name,
        hub.asTransport(),
    );
    defer consumer.close();

    const audience = try consumer.entityAudience(allocator);
    defer allocator.free(audience);
    try hub.bind(&consumer.credential, audience, consumer.options.runtime);

    var opener = consumer.partitionOpener(&hub.connection, 60_000);
    var clock = eh.load_balancing.SystemClock{ .io = init.io };
    var prng = std.Random.DefaultPrng.init(@bitCast(clock.clock.nowMillis()));

    var processor = consumer.newProcessor(
        allocator,
        store.asCheckpointStore(),
        opener.asOpener(),
        .{ .load_balancing_strategy = .balanced },
        &clock.clock,
        prng.random(),
    );
    // Relinquishes every partition it holds, so the rest of the fleet takes
    // over in one cycle rather than waiting out the expiry.
    defer processor.deinit();

    var stdout_file = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var stdout = stdout_file.writer(init.io, &buffer);
    const out = &stdout.interface;
    defer out.flush() catch {};

    // `runOnce` is one balancing cycle, not a thread: the loop, and its
    // shutdown, stay with the caller.
    for (0..10) |_| {
        try processor.runOnce();

        while (processor.nextPartitionClient()) |partition| {
            const events = partition.receiveEvents(allocator, 100) catch |err| {
                try out.print("partition {s}: {t}\n", .{ partition.partitionId(), err });
                continue;
            };
            defer eh.freeReceivedEvents(allocator, events);

            for (events) |event| {
                try out.print("[{s}/{d}] {s}\n", .{
                    partition.partitionId(),
                    event.sequence_number,
                    event.body(),
                });
            }
            // Checkpoint the last event of the batch: a later owner resumes
            // after it rather than replaying the whole partition.
            if (events.len > 0) {
                try partition.updateCheckpoint(allocator, events[events.len - 1]);
            }
        }

        try out.flush();
        try init.io.sleep(
            .{ .nanoseconds = @intCast(processor.nextIntervalMs() * std.time.ns_per_ms) },
            .awake,
        );
    }
}
