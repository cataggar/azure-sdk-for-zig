const std = @import("std");
const fixture = @import("fixture.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 1 or (args.len == 2 and std.mem.eql(u8, args[1], "capture"))) {
        const data = try fixture.capture(allocator, io);
        if (args.len == 2) {
            try writeExclusive(io, "request.json", data.json());
            try writeExclusive(io, "wire_traceparent.txt", &data.traceparent);
        } else {
            var buffer: [4096]u8 = undefined;
            var output = std.Io.File.stdout().writer(io, &buffer);
            try output.interface.writeAll(data.json());
            try output.interface.flush();
        }
        std.debug.print("Mock ConfigurationClient.getSetting: GET -> 200\ntraceparent: {s}\n", .{data.traceparent});
        return;
    }
    if (args.len == 6 and std.mem.eql(u8, args[1], "verify")) {
        var contents: [4][]const u8 = undefined;
        var count: usize = 0;
        defer for (contents[0..count]) |bytes| allocator.free(bytes);
        for (args[2..], 0..) |path, index| {
            contents[index] = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(fixture.max_bytes));
            count += 1;
        }
        try fixture.verify(allocator, contents[0], contents[1], contents[2], contents[3]);
        std.debug.print(
            "Collector accepted 1 matching client span; rejected spans: 0\n" ++
                "traceparent: {s}\n" ++
                "Verified resource, scope 0.3.1, parent, tracestate, flags, timestamps, GET/200 and safe HTTP attributes.\n",
            .{contents[1]},
        );
        return;
    }
    std.debug.print("Usage: otlp-collector-fixture [capture | verify REQUEST WIRE_TRACEPARENT RESPONSE ACCEPTED]\n", .{});
    return error.InvalidArguments;
}

fn writeExclusive(io: std.Io, path: []const u8, bytes: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{ .exclusive = true });
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}
