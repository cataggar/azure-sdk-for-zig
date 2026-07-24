const std = @import("std");
const package_history = @import("package_history_map.zig");

pub const PathMapping = package_history.PathMapping;

pub const ExampleHistory = struct {
    name: []const u8,
    branch: []const u8,
    current_source_path: []const u8,
    current_mappings: []const PathMapping,
    historical_mappings: []const PathMapping,
};

pub const all = [_]ExampleHistory{
    .{
        .name = "kusto",
        .branch = "example/kusto",
        .current_source_path = "examples/kusto",
        .current_mappings = &.{
            .{ .source = "examples/kusto/.gitignore", .destination = ".gitignore" },
            .{ .source = "examples/kusto/README.md", .destination = "README.md" },
            .{ .source = "examples/kusto/build.zig", .destination = "build.zig" },
            .{ .source = "examples/kusto/build.zig.zon", .destination = "build.zig.zon" },
            .{ .source = "examples/kusto/runner.zig", .destination = "runner.zig" },
            .{ .source = "examples/kusto/live_tests.zig", .destination = "live_tests.zig" },
            .{ .source = "examples/kusto/data/", .destination = "data/" },
            .{ .source = "examples/kusto/ingest/", .destination = "ingest/" },
            .{ .source = "examples/kusto/legacy/", .destination = "legacy/" },
        },
        .historical_mappings = &.{
            .{ .source = "sdk/kusto/data/examples/", .destination = "data/" },
            .{ .source = "sdk/kusto/ingest/examples/", .destination = "ingest/" },
            .{ .source = "examples/kusto/main.zig", .destination = "legacy/main.zig" },
            .{ .source = "examples/kusto/live_test.zig", .destination = "legacy/live_test.zig" },
        },
    },
};

pub fn find(name: []const u8) ?*const ExampleHistory {
    for (&all) |*entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry;
    }
    return null;
}

pub fn validate() !void {
    for (all, 0..) |entry, index| {
        try validatePath(entry.name, false);
        try validatePath(entry.branch, false);
        try validatePath(entry.current_source_path, false);
        if (!std.mem.startsWith(u8, entry.branch, "example/")) {
            return error.InvalidExampleBranch;
        }
        if (entry.current_mappings.len == 0) {
            return error.MissingCurrentExampleMappings;
        }
        for (all[index + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.name, other.name)) {
                return error.DuplicateExampleHistoryName;
            }
            if (std.mem.eql(u8, entry.branch, other.branch)) {
                return error.DuplicateExampleHistoryBranch;
            }
        }
        for (entry.current_mappings, 0..) |mapping, mapping_index| {
            try validateMapping(mapping);
            if (!std.mem.startsWith(u8, mapping.source, entry.current_source_path)) {
                return error.CurrentExampleMappingOutsideRoot;
            }
            try rejectDuplicateSource(
                mapping,
                entry.current_mappings[mapping_index + 1 ..],
            );
            try rejectDuplicateSource(mapping, entry.historical_mappings);
            try rejectOverlappingDestination(
                mapping,
                entry.current_mappings[mapping_index + 1 ..],
            );
        }
        for (entry.historical_mappings, 0..) |mapping, mapping_index| {
            try validateMapping(mapping);
            try rejectDuplicateSource(
                mapping,
                entry.historical_mappings[mapping_index + 1 ..],
            );
        }
    }
}

pub fn validateCurrentTrees(allocator: std.mem.Allocator, io: std.Io) !void {
    for (all) |entry| {
        var directory = try std.Io.Dir.cwd().openDir(
            io,
            entry.current_source_path,
            .{ .iterate = true },
        );
        defer directory.close(io);
        var walker = try directory.walk(allocator);
        defer walker.deinit();
        while (try walker.next(io)) |item| {
            const item_path = try normalizedPath(allocator, item.path);
            defer allocator.free(item_path);
            if (isIgnoredBuildPath(item_path)) continue;
            if (item.kind == .directory) continue;
            if (item.kind == .sym_link) return error.ExampleHistoryTreeContainsSymlink;

            const source = try std.fmt.allocPrint(
                allocator,
                "{s}/{s}",
                .{ entry.current_source_path, item_path },
            );
            defer allocator.free(source);
            var matches: usize = 0;
            for (entry.current_mappings) |mapping| {
                if (mappingCovers(mapping.source, source)) matches += 1;
            }
            if (matches == 0) return error.UnmappedCurrentExampleFile;
            if (matches != 1) return error.AmbiguousCurrentExampleFile;
        }

        const source_prefix = try std.fmt.allocPrint(
            allocator,
            "{s}/",
            .{entry.current_source_path},
        );
        defer allocator.free(source_prefix);
        for (entry.current_mappings) |mapping| {
            if (!std.mem.startsWith(u8, mapping.source, source_prefix)) {
                return error.CurrentExampleMappingOutsideRoot;
            }
            const relative = mapping.source[source_prefix.len..];
            const path = std.mem.trimEnd(u8, relative, "/");
            const stat = directory.statFile(io, path, .{
                .follow_symlinks = false,
            }) catch
                return error.MissingCurrentExamplePath;
            if (stat.kind == .sym_link) {
                return error.ExampleHistoryTreeContainsSymlink;
            }
        }
    }
}

fn normalizedPath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const normalized = try allocator.dupe(u8, path);
    for (normalized) |*char| {
        if (char.* == '\\') char.* = '/';
    }
    return normalized;
}

fn rejectDuplicateSource(mapping: PathMapping, others: []const PathMapping) !void {
    for (others) |other| {
        if (std.mem.eql(u8, mapping.source, other.source)) {
            return error.DuplicateExampleHistorySource;
        }
    }
}

fn rejectOverlappingDestination(
    mapping: PathMapping,
    others: []const PathMapping,
) !void {
    for (others) |other| {
        if (mappingCovers(mapping.destination, other.destination) or
            mappingCovers(other.destination, mapping.destination))
        {
            return error.OverlappingCurrentExampleDestination;
        }
    }
}

fn mappingCovers(mapping_path: []const u8, file_path: []const u8) bool {
    if (std.mem.endsWith(u8, mapping_path, "/")) {
        return std.mem.startsWith(u8, file_path, mapping_path);
    }
    return std.mem.eql(u8, mapping_path, file_path);
}

fn isIgnoredBuildPath(path: []const u8) bool {
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (std.mem.eql(u8, segment, ".zig-cache") or
            std.mem.eql(u8, segment, "zig-cache") or
            std.mem.eql(u8, segment, "zig-out") or
            std.mem.eql(u8, segment, "zig-pkg"))
        {
            return true;
        }
    }
    return false;
}

fn validateMapping(mapping: PathMapping) !void {
    try validatePath(mapping.source, false);
    try validatePath(mapping.destination, true);
}

fn validatePath(path: []const u8, allow_empty: bool) !void {
    if (path.len == 0) {
        if (allow_empty) return;
        return error.EmptyExampleHistoryPath;
    }
    if (std.fs.path.isAbsolute(path) or
        std.mem.indexOf(u8, path, "..") != null or
        std.mem.indexOfScalar(u8, path, '\\') != null)
    {
        return error.InvalidExampleHistoryPath;
    }
}

test "Kusto example history separates current and historical paths" {
    try validate();
    try validateCurrentTrees(std.testing.allocator, std.testing.io);
    try std.testing.expectEqual(@as(usize, 1), all.len);
    const kusto = find("kusto").?;
    try std.testing.expectEqualStrings("example/kusto", kusto.branch);
    try std.testing.expectEqual(@as(usize, 9), kusto.current_mappings.len);
    try std.testing.expectEqual(@as(usize, 4), kusto.historical_mappings.len);
    try std.testing.expectEqualStrings(
        "legacy/main.zig",
        kusto.historical_mappings[2].destination,
    );
}

test "current example paths normalize Windows separators" {
    const normalized = try normalizedPath(std.testing.allocator, "data\\main.zig");
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("data/main.zig", normalized);
}
