const std = @import("std");
const registry = @import("packages.zig");

pub const PathMapping = struct {
    source: []const u8,
    destination: []const u8,
};

pub const PackageHistory = struct {
    package: []const u8,
    branch: []const u8,
    mappings: []const PathMapping,
};

pub const RejectedPath = struct {
    path: []const u8,
    reason: []const u8,
};

const current_only = struct {
    fn mappings(comptime path: []const u8) []const PathMapping {
        return &.{.{ .source = path ++ "/", .destination = "" }};
    }
};

pub const all = [_]PackageHistory{
    .{
        .package = "azure_rest_arm_avs",
        .branch = "rest/arm_avs",
        .mappings = current_only.mappings("rest/arm_avs"),
    },
    .{
        .package = "azure_rest_keyvault_secrets",
        .branch = "rest/keyvault_secrets",
        .mappings = current_only.mappings("rest/keyvault_secrets"),
    },
    .{
        .package = "azure_rest_container_registry",
        .branch = "rest/container_registry",
        .mappings = current_only.mappings("rest/container_registry"),
    },
    .{
        .package = "azure_sdk_container_registry",
        .branch = "sdk/container_registry",
        .mappings = current_only.mappings("sdk/container_registry"),
    },
    .{
        .package = "azure_sdk_storage_common",
        .branch = "sdk/storage_common",
        .mappings = &.{
            .{ .source = "sdk/storage/common/", .destination = "" },
            .{ .source = "src/azure/storage/common/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_storage_blobs",
        .branch = "sdk/storage_blobs",
        .mappings = &.{
            .{ .source = "sdk/storage/blobs/", .destination = "" },
            .{ .source = "src/azure/storage/blobs/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_storage_queues",
        .branch = "sdk/storage_queues",
        .mappings = &.{
            .{ .source = "sdk/storage/queues/", .destination = "" },
            .{ .source = "src/azure/storage/queues/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_storage_files_shares",
        .branch = "sdk/storage_files_shares",
        .mappings = &.{
            .{ .source = "sdk/storage/files/shares/", .destination = "" },
            .{ .source = "src/azure/storage/files/shares/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_storage_files_datalake",
        .branch = "sdk/storage_files_datalake",
        .mappings = &.{
            .{ .source = "sdk/storage/files/datalake/", .destination = "" },
            .{ .source = "src/azure/storage/files/datalake/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_keyvault",
        .branch = "sdk/keyvault",
        .mappings = &.{
            .{ .source = "sdk/keyvault/", .destination = "" },
            .{ .source = "src/azure/keyvault/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_data_tables",
        .branch = "sdk/data_tables",
        .mappings = &.{
            .{ .source = "sdk/data/tables/", .destination = "" },
            .{ .source = "src/azure/data/tables/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_data_cosmos",
        .branch = "sdk/data_cosmos",
        .mappings = &.{
            .{ .source = "sdk/data/cosmos/", .destination = "" },
            .{ .source = "src/azure/data/cosmos/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_data_appconfiguration",
        .branch = "sdk/data_appconfiguration",
        .mappings = &.{
            .{ .source = "sdk/data/appconfiguration/", .destination = "" },
            .{ .source = "src/azure/data/appconfiguration/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_attestation",
        .branch = "sdk/attestation",
        .mappings = &.{
            .{ .source = "sdk/attestation/", .destination = "" },
            .{ .source = "src/azure/attestation/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_messaging_common",
        .branch = "sdk/messaging_common",
        .mappings = &.{
            .{ .source = "sdk/messaging/common/", .destination = "" },
            .{ .source = "sdk/messaging/common.zig", .destination = "root.zig" },
            .{ .source = "src/azure/messaging/common.zig", .destination = "root.zig" },
        },
    },
    .{
        .package = "azure_sdk_eventhubs",
        .branch = "sdk/eventhubs",
        .mappings = &.{
            .{ .source = "sdk/messaging/eventhubs/", .destination = "" },
            .{ .source = "src/azure/messaging/eventhubs/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_servicebus",
        .branch = "sdk/servicebus",
        .mappings = &.{
            .{ .source = "sdk/messaging/servicebus/", .destination = "" },
            .{ .source = "src/azure/messaging/servicebus/", .destination = "" },
        },
    },
    .{
        .package = "azure_sdk_kusto",
        .branch = "sdk/kusto",
        .mappings = &.{
            .{ .source = "sdk/kusto/", .destination = "" },
            .{ .source = "src/azure/kusto/", .destination = "" },
        },
    },
};

pub const rejected_paths = [_]RejectedPath{
    .{
        .path = ".gitignore",
        .reason = "repository boilerplate has high rename similarity across unrelated packages",
    },
    .{
        .path = "LICENSE.txt",
        .reason = "copied license text does not establish package ancestry",
    },
    .{
        .path = "README.md",
        .reason = "generic headings produced false rename candidates",
    },
    .{
        .path = "build.zig",
        .reason = "package build scaffolding was copied during the split",
    },
    .{
        .path = "build.zig.zon",
        .reason = "package manifests were created from common templates",
    },
};

pub fn find(name: []const u8) ?*const PackageHistory {
    for (&all) |*entry| {
        if (std.mem.eql(u8, entry.package, name)) return entry;
    }
    return null;
}

pub fn validate(allocator: std.mem.Allocator) !void {
    var branch_owned: usize = 0;
    for (registry.all) |package| {
        if (package.ownership == .branch_owned) branch_owned += 1;
    }
    if (all.len != branch_owned) return error.HistoryPackageCountMismatch;

    for (all, 0..) |entry, index| {
        const package_index = registry.find(&registry.all, entry.package) orelse
            return error.UnknownHistoryPackage;
        const package = registry.all[package_index];
        if (package.ownership != .branch_owned) return error.MainOwnedHistoryPackage;
        if (!std.mem.eql(u8, package.branch, entry.branch)) {
            return error.HistoryBranchMismatch;
        }
        if (entry.mappings.len == 0) return error.MissingHistoryMapping;
        const expected_current = try std.fmt.allocPrint(
            allocator,
            "{s}/",
            .{package.historical_source_path},
        );
        defer allocator.free(expected_current);
        if (!std.mem.eql(u8, entry.mappings[0].source, expected_current) or
            entry.mappings[0].destination.len != 0)
        {
            return error.MissingCurrentRootMapping;
        }
        for (all[index + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.package, other.package)) {
                return error.DuplicateHistoryPackage;
            }
            if (std.mem.eql(u8, entry.branch, other.branch)) {
                return error.DuplicateHistoryBranch;
            }
        }
        for (entry.mappings, 0..) |mapping, mapping_index| {
            try validatePath(mapping.source, false);
            try validatePath(mapping.destination, true);
            for (entry.mappings[mapping_index + 1 ..]) |other| {
                if (std.mem.eql(u8, mapping.source, other.source)) {
                    return error.DuplicateHistorySource;
                }
            }
        }
    }
}

fn validatePath(path: []const u8, allow_empty: bool) !void {
    if (path.len == 0) {
        if (allow_empty) return;
        return error.EmptyHistoryPath;
    }
    if (std.fs.path.isAbsolute(path) or
        std.mem.indexOf(u8, path, "..") != null or
        std.mem.indexOfScalar(u8, path, '\\') != null)
    {
        return error.InvalidHistoryPath;
    }
}

test "history map covers every branch-owned package" {
    try validate(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 18), all.len);
    try std.testing.expectEqual(@as(usize, 5), rejected_paths.len);
    try std.testing.expect(find("azure_sdk_storage_blobs") != null);
    try std.testing.expect(find("azure_sdk_core") == null);
    const kusto = find("azure_sdk_kusto").?;
    try std.testing.expectEqual(@as(usize, 2), kusto.mappings.len);
    try std.testing.expectEqualStrings(
        "sdk/kusto/",
        kusto.mappings[0].source,
    );
    try std.testing.expectEqualStrings(
        "src/azure/kusto/",
        kusto.mappings[1].source,
    );
}
