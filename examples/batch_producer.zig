//! Fill batches to the link's real maximum and send each as it fills.
//!
//! Usage:
//!   EVENTHUB_CONNECTION_STRING=... ./zig-out/bin/eventhubs-batch-producer <hub> <count>
//!
//! `tryAdd` returns false rather than failing when an event would not fit, so
//! the caller sends what it has and starts a new batch. The ceiling comes
//! from the sender link's negotiated `max-message-size`, which is why
//! `createBatch` is a client method rather than a free function.

const std = @import("std");
const eh = @import("azure_sdk_eventhubs");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const hub_name = args.next() orelse return error.MissingEventHubName;
    const count_text = args.next() orelse "1000";
    const count = try std.fmt.parseInt(usize, count_text, 10);

    const connection_string = init.environ_map.get("EVENTHUB_CONNECTION_STRING") orelse
        return error.MissingConnectionString;
    const properties = try eh.ConnectionStringProperties.parse(connection_string);

    var hub: eh.HubConnection = undefined;
    hub.open(.{
        .allocator = allocator,
        .io = init.io,
        .fully_qualified_namespace = properties.fully_qualified_namespace,
        .container_id = "eventhubs-batch-producer",
    });
    defer hub.deinit();

    var producer = try eh.ProducerClient.fromConnectionString(
        allocator,
        connection_string,
        hub_name,
        hub.asTransport(),
    );
    defer producer.close();

    const audience = try producer.entityAudience(allocator);
    defer allocator.free(audience);
    try hub.bind(&producer.credential, audience);

    var stdout_file = std.Io.File.stdout();
    var buffer: [256]u8 = undefined;
    var stdout = stdout_file.writer(init.io, &buffer);
    const out = &stdout.interface;
    defer out.flush() catch {};

    // A partition key routes related events to one partition without naming
    // it, so a rebalance cannot split an ordered stream.
    var batch = try producer.createBatch(allocator, .{ .partition_key = "orders" });
    var sent: usize = 0;
    var batches: usize = 0;

    var i: usize = 0;
    while (i < count) {
        var body_buf: [128]u8 = undefined;
        const body = try std.fmt.bufPrint(&body_buf, "order {d}", .{i});

        if (try batch.tryAdd(allocator, eh.EventData.init(body))) {
            i += 1;
            continue;
        }

        // Full. Send it, then retry this event against a fresh batch.
        if (batch.count() == 0) return error.EventTooLarge;
        try producer.sendBatch(allocator, batch);
        sent += batch.count();
        batches += 1;
        batch.deinit(allocator);
        batch = try producer.createBatch(allocator, .{ .partition_key = "orders" });
    }

    defer batch.deinit(allocator);
    if (batch.count() > 0) {
        try producer.sendBatch(allocator, batch);
        sent += batch.count();
        batches += 1;
    }

    try out.print("sent {d} events in {d} batches\n", .{ sent, batches });
}
