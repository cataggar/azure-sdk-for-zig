//! Send events to an Event Hub with Azure Active Directory credentials.
//!
//! Usage:
//!   zig build examples
//!   ./zig-out/bin/eventhubs-send-events <namespace> <hub>
//!
//! e.g. <namespace> = my-namespace.servicebus.windows.net
//!
//! Authentication uses `DefaultAzureCredential`, so an `az login` session or
//! the usual `AZURE_*` environment variables work out of the box. Managed
//! identity is not in the default chain, because its IMDS probe stalls
//! outside Azure; set `AZURE_TOKEN_CREDENTIALS=prod` on a deployed service to
//! enable it.

const std = @import("std");
const core = @import("azure_sdk_core");
const eh = @import("azure_sdk_eventhubs");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const namespace = args.next() orelse return error.MissingNamespace;
    const hub_name = args.next() orelse return error.MissingEventHubName;

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();
    var crypto_provider = core.crypto.StdCryptoProvider.init(init.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto_provider.asProvider(),
    );

    var credential = try core.identity.DefaultAzureCredential.init(
        allocator,
        init.io,
        init.environ_map,
    );
    defer credential.deinit();

    // Nothing dials until the first operation: the connection is opened
    // lazily and rebuilt underneath the client if it drops.
    var hub: eh.HubConnection = undefined;
    hub.open(.{
        .allocator = allocator,
        .io = init.io,
        .fully_qualified_namespace = namespace,
        .container_id = "eventhubs-send-events",
    });
    defer hub.deinit();

    var producer = eh.ProducerClient.init(.{
        .runtime = runtime,
        .fully_qualified_namespace = namespace,
        .event_hub_name = hub_name,
    }, credential.asCredential(), hub.asTransport());
    defer producer.close();

    // The authorizer needs the client's credential, and the client needed
    // the transport, so binding is the last step rather than part of `open`.
    const audience = try producer.entityAudience(allocator);
    defer allocator.free(audience);
    try hub.bind(&producer.credential, audience, producer.options.runtime);

    var batch = try producer.createBatch(allocator, .{});
    defer batch.deinit(allocator);

    for (0..5) |i| {
        var body_buf: [64]u8 = undefined;
        const body = try std.fmt.bufPrint(&body_buf, "event {d}", .{i});
        if (!try batch.tryAdd(allocator, eh.EventData.init(body))) {
            return error.BatchFull;
        }
    }

    try producer.sendBatch(allocator, batch);

    var stdout_file = std.Io.File.stdout();
    var buffer: [256]u8 = undefined;
    var stdout = stdout_file.writer(init.io, &buffer);
    defer stdout.interface.flush() catch {};
    try stdout.interface.print("sent {d} events to {s}\n", .{ batch.count(), hub_name });
}
