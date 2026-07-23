//! Send a message through a complete, service-issued Queue SAS URL.
//!
//! Usage:
//!   zig build complete-sas-message -- <queue-sas-url> <message>

const std = @import("std");
const core = @import("azure_sdk_core");
const queues = @import("azure_sdk_storage_queues");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    const sas_url = args.next() orelse return error.MissingQueueSasUrl;
    const message = args.next() orelse return error.MissingMessage;

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();
    var client = try queues.SasQueueClient.init(
        allocator,
        sas_url,
        transport.asTransport(),
    );
    defer client.deinit();

    const outcome = try client.sendMessage(message);
    var buffer: [512]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(init.io, &buffer);
    defer stdout.interface.flush() catch {};
    try stdout.interface.print("{f}\n", .{outcome});
}
