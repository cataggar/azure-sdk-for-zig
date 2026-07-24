//! Unified Kusto Data and Ingest example runner.
const std = @import("std");
const data_examples = @import("data/main.zig");
const ingest_examples = @import("ingest/main.zig");

const Invocation = union(enum) {
    data: []const u8,
    ingest: []const u8,
    all,
};

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    defer args.deinit();
    _ = args.next();

    var values: [2][]const u8 = undefined;
    var count: usize = 0;
    while (args.next()) |value| {
        if (count == values.len) {
            usage();
            return error.UnexpectedKustoExampleArgument;
        }
        values[count] = value;
        count += 1;
    }

    const invocation = parseInvocation(values[0..count]) catch |err| {
        usage();
        return err;
    };
    try run(init, invocation);
}

fn run(init: std.process.Init, invocation: Invocation) !void {
    switch (invocation) {
        .data => |scenario| try data_examples.run(init, scenario),
        .ingest => |scenario| try ingest_examples.run(init, scenario),
        .all => {
            try data_examples.run(init, "all");
            try ingest_examples.run(init, "all");
        },
    }
}

fn parseInvocation(args: []const []const u8) !Invocation {
    if (args.len == 1 and std.mem.eql(u8, args[0], "all")) return .all;
    if (args.len != 2) return error.KustoExampleFamilyAndScenarioRequired;
    if (std.mem.eql(u8, args[0], "data")) return .{ .data = args[1] };
    if (std.mem.eql(u8, args[0], "ingest")) return .{ .ingest = args[1] };
    return error.UnknownKustoExampleFamily;
}

fn usage() void {
    std.debug.print(
        \\Usage:
        \\  zig build run-example -- data <scenario>
        \\  zig build run-example -- ingest <scenario>
        \\  zig build run-example -- all
        \\
        \\Data scenarios: default-query, typed-query, management, progressive, all
        \\Ingest scenarios: streaming, queued, managed, status, all
        \\
    , .{});
}

test "parse Data and Ingest invocations" {
    const data = try parseInvocation(&.{ "data", "progressive" });
    try std.testing.expectEqualStrings("progressive", data.data);
    const ingest = try parseInvocation(&.{ "ingest", "status" });
    try std.testing.expectEqualStrings("status", ingest.ingest);
    try std.testing.expectEqual(Invocation.all, try parseInvocation(&.{"all"}));
}

test "reject invalid invocation shapes" {
    try std.testing.expectError(
        error.KustoExampleFamilyAndScenarioRequired,
        parseInvocation(&.{}),
    );
    try std.testing.expectError(
        error.KustoExampleFamilyAndScenarioRequired,
        parseInvocation(&.{ "data", "progressive", "extra" }),
    );
    try std.testing.expectError(
        error.UnknownKustoExampleFamily,
        parseInvocation(&.{ "unknown", "scenario" }),
    );
}
