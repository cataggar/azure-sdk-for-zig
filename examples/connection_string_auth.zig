//! Send events using a connection string rather than Azure Active Directory.
//!
//! Usage:
//!   EVENTHUB_CONNECTION_STRING="Endpoint=sb://...;SharedAccessKeyName=...;SharedAccessKey=..." \
//!   ./zig-out/bin/eventhubs-connection-string [hub]
//!
//! The hub name is optional when the connection string carries an
//! `EntityPath`.

const std = @import("std");
const eh = @import("azure_sdk_eventhubs");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const hub_name = args.next();

    // The connection string must outlive the client: the namespace, hub name,
    // and key are all borrowed from it rather than copied.
    const connection_string = init.environ_map.get("EVENTHUB_CONNECTION_STRING") orelse
        return error.MissingConnectionString;

    const properties = try eh.ConnectionStringProperties.parse(connection_string);

    var hub: eh.HubConnection = undefined;
    hub.open(.{
        .allocator = allocator,
        .io = init.io,
        .fully_qualified_namespace = properties.fully_qualified_namespace,
        .container_id = "eventhubs-connection-string",
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

    var batch = try producer.createBatch(allocator, .{});
    defer batch.deinit(allocator);
    _ = try batch.tryAdd(allocator, eh.EventData.init("hello from a connection string"));

    try producer.sendBatch(allocator, batch);
}
