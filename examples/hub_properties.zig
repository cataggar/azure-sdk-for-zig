//! Read a hub's metadata and each partition's high and low watermarks.
//!
//! Usage:
//!   EVENTHUB_CONNECTION_STRING=... ./zig-out/bin/eventhubs-properties <hub>
//!
//! Both operations run over the `$management` link rather than a data link,
//! so neither sends nor receives events.

const std = @import("std");
const core = @import("azure_sdk_core");
const eh = @import("azure_sdk_eventhubs");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const hub_name = args.next() orelse return error.MissingEventHubName;

    const connection_string = init.environ_map.get("EVENTHUB_CONNECTION_STRING") orelse
        return error.MissingConnectionString;
    const properties = try eh.ConnectionStringProperties.parse(connection_string);

    var http = core.http.StdHttpTransport.init(allocator, init.io);
    defer http.deinit();
    var crypto_provider = core.crypto.StdCryptoProvider.init(init.io);
    const runtime = core.http.HttpRuntime.init(
        http.asTransport(),
        crypto_provider.asProvider(),
    );

    var hub: eh.HubConnection = undefined;
    hub.open(.{
        .allocator = allocator,
        .io = init.io,
        .fully_qualified_namespace = properties.fully_qualified_namespace,
        .container_id = "eventhubs-properties",
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

    var stdout_file = std.Io.File.stdout();
    var buffer: [4096]u8 = undefined;
    var stdout = stdout_file.writer(init.io, &buffer);
    const out = &stdout.interface;
    defer out.flush() catch {};

    var hub_properties = try consumer.getEventHubProperties(allocator);
    defer hub_properties.deinit();

    try out.print("{s}: {d} partition(s), geo-replication {s}\n", .{
        hub_properties.name,
        hub_properties.partition_ids.len,
        if (hub_properties.geo_replication_enabled) "on" else "off",
    });

    for (hub_properties.partition_ids) |partition_id| {
        var partition = try consumer.getPartitionProperties(allocator, partition_id);
        defer partition.deinit();

        if (partition.is_empty) {
            try out.print("  partition {s}: empty\n", .{partition_id});
            continue;
        }
        try out.print("  partition {s}: sequence {d}..{d}, offset {s}\n", .{
            partition_id,
            partition.beginning_sequence_number,
            partition.last_enqueued_sequence_number,
            partition.last_enqueued_offset orelse "?",
        });
    }
}
