const std = @import("std");
const core = @import("azure_core");

pub fn main(init: std.process.Init) !void {
    var buf: [4096]u8 = undefined;
    var file_writer = std.Io.File.stdout().writer(init.io, &buf);
    const stdout = &file_writer.interface;

    try stdout.print("Azure SDK for Zig {s}\n", .{core.version});

    // Quick demo: generate a UUID and format a timestamp.
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const id = core.uuid.Uuid.init(prng.random());
    try stdout.print("Request ID: {s}\n", .{id.toString()});

    const now = core.datetime.DateTime{
        .year = 2026,
        .month = 4,
        .day = 1,
        .hour = 14,
        .minute = 0,
        .second = 0,
    };
    var ts_buf: [32]u8 = undefined;
    const ts = try now.toRfc3339(&ts_buf);
    try stdout.print("Timestamp:  {s}\n", .{ts});
    try file_writer.flush();
}
