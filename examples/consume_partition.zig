//! Read events from one partition.
//!
//! Usage:
//!   EVENTHUB_CONNECTION_STRING=... ./zig-out/bin/eventhubs-consume-partition <hub> <partition>
//!
//! This reads a single partition by name. To spread a hub's partitions across
//! a fleet of consumers, use a `Processor` instead — see
//! `examples/processor.zig`.

const std = @import("std");
const eh = @import("azure_sdk_eventhubs");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const hub_name = args.next() orelse return error.MissingEventHubName;
    const partition_id = args.next() orelse "0";

    const connection_string = init.environ_map.get("EVENTHUB_CONNECTION_STRING") orelse
        return error.MissingConnectionString;
    const properties = try eh.ConnectionStringProperties.parse(connection_string);

    var hub: eh.HubConnection = undefined;
    hub.open(.{
        .allocator = allocator,
        .io = init.io,
        .fully_qualified_namespace = properties.fully_qualified_namespace,
        .container_id = "eventhubs-consume-partition",
        .instance_id = "example-reader",
    });
    defer hub.deinit();

    var consumer = try eh.ConsumerClient.fromConnectionString(
        allocator,
        connection_string,
        hub_name,
        hub.asTransport(),
    );
    defer consumer.close();

    const audience = try consumer.entityAudience(allocator);
    defer allocator.free(audience);
    try hub.bind(&consumer.credential, audience);

    var stdout_file = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var stdout = stdout_file.writer(init.io, &buffer);
    const out = &stdout.interface;
    defer out.flush() catch {};

    // Earliest replays the partition from the start; the default is latest,
    // which shows only events enqueued after the link attaches.
    const events = try consumer.receiveEvents(
        allocator,
        partition_id,
        eh.EventPosition.earliest(),
        20,
    );
    defer eh.freeReceivedEvents(allocator, events);

    for (events) |event| {
        try out.print("[{d}] {s}\n", .{ event.sequence_number, event.body() });
    }
    try out.print("→ {d} event(s) from partition {s}\n", .{ events.len, partition_id });
}
