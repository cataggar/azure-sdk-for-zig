const std = @import("std");
const history = @import("package_history_map.zig");
const examples = @import("example_history_map.zig");

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    try history.validate(allocator);
    try examples.validate();
    if (args.len < 2) {
        usage();
        return 2;
    }
    if (std.mem.eql(u8, args[1], "check")) return 0;
    if (std.mem.eql(u8, args[1], "check-current-examples") and args.len == 2) {
        try examples.validateCurrentTrees(allocator, init.io);
        return 0;
    }

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file = std.Io.File.stdout();
    var stdout = stdout_file.writer(init.io, &stdout_buffer);
    const writer = &stdout.interface;
    defer writer.flush() catch {};

    if (std.mem.eql(u8, args[1], "list") and args.len == 2) {
        for (history.all) |entry| {
            try writer.print("{s}\t{s}\n", .{ entry.package, entry.branch });
        }
        return 0;
    }
    if (std.mem.eql(u8, args[1], "paths") and args.len == 3) {
        const entry = history.find(args[2]) orelse return error.UnknownPackage;
        for (entry.mappings) |mapping| {
            try writer.writeAll(mapping.source);
            try writer.writeByte('\t');
            try writer.writeAll(mapping.destination);
            try writer.writeByte('\n');
        }
        return 0;
    }
    if (std.mem.eql(u8, args[1], "example-list") and args.len == 2) {
        for (examples.all) |entry| {
            try writer.print(
                "{s}\t{s}\t{s}\n",
                .{ entry.name, entry.branch, entry.current_source_path },
            );
        }
        return 0;
    }
    if (std.mem.eql(u8, args[1], "example-paths") and args.len == 3) {
        const entry = examples.find(args[2]) orelse return error.UnknownExample;
        try printMappings(writer, entry.current_mappings);
        try printMappings(writer, entry.historical_mappings);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "example-current-paths") and args.len == 3) {
        const entry = examples.find(args[2]) orelse return error.UnknownExample;
        try printMappings(writer, entry.current_mappings);
        return 0;
    }
    if (std.mem.eql(u8, args[1], "example-current-root") and args.len == 3) {
        const entry = examples.find(args[2]) orelse return error.UnknownExample;
        try writer.print("{s}\n", .{entry.current_source_path});
        return 0;
    }
    if (std.mem.eql(u8, args[1], "rejections") and args.len == 2) {
        for (history.rejected_paths) |rejection| {
            try writer.print("{s}\t{s}\n", .{ rejection.path, rejection.reason });
        }
        return 0;
    }
    usage();
    return 2;
}

fn printMappings(writer: anytype, mappings: []const history.PathMapping) !void {
    for (mappings) |mapping| {
        try writer.writeAll(mapping.source);
        try writer.writeByte('\t');
        try writer.writeAll(mapping.destination);
        try writer.writeByte('\n');
    }
}

fn usage() void {
    std.debug.print(
        "usage: package-history-tool <check|check-current-examples|list|" ++
            "paths PACKAGE|example-list|" ++
            "example-paths EXAMPLE|example-current-paths EXAMPLE|" ++
            "example-current-root EXAMPLE|rejections>\n",
        .{},
    );
}
