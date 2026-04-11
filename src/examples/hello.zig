const std = @import("std");
const core = @import("azure_core");

pub fn main() void {
    std.debug.print("Azure SDK for Zig {s}\n", .{core.version});

    // Quick demo: generate a UUID and format a timestamp.
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const id = core.uuid.Uuid.init(prng.random());
    std.debug.print("Request ID: {s}\n", .{id.toString()});

    const now = core.datetime.DateTime{
        .year = 2026,
        .month = 4,
        .day = 1,
        .hour = 14,
        .minute = 0,
        .second = 0,
    };
    var ts_buf: [32]u8 = undefined;
    const ts = now.toRfc3339(&ts_buf) catch "error";
    std.debug.print("Timestamp:  {s}\n", .{ts});
}
