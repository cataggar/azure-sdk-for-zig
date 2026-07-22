const std = @import("std");

pub const Kind = enum {
    rest,
    sdk,
    aggregate,
};

pub const MigrationState = enum {
    monolithic,
    package,
};

pub const Package = struct {
    kind: Kind,
    state: MigrationState = .monolithic,
    source_path: []const u8,
    root_source_file: []const u8,
    current_root_source_file: ?[]const u8 = null,
    name: []const u8,
    module_name: []const u8,
    branch: []const u8,
    identity_override: bool = false,
    version: []const u8 = "0.1.0",
    legacy_names: []const []const u8 = &.{},
    dependencies: []const []const u8 = &.{},
    external_dependencies: []const []const u8 = &.{},
    publish_paths: []const []const u8 = &.{},
    test_command: ?[]const u8 = "zig build test --summary all",
    examples_command: ?[]const u8 = null,
    live_test_command: ?[]const u8 = null,
    regeneration_command: ?[]const u8 = null,
};

const all_implementation_packages = &.{
    "azure_sdk_core_tracing",
    "azure_sdk_core_perf",
    "azure_sdk_core_amqp",
    "azure_sdk_core",
    "azure_sdk_core_testing",
    "azure_rest_arm_avs",
    "azure_rest_keyvault_secrets",
    "azure_rest_container_registry",
    "azure_sdk_container_registry",
    "azure_sdk_storage_common",
    "azure_sdk_storage_blobs",
    "azure_sdk_storage_queues",
    "azure_sdk_storage_files_shares",
    "azure_sdk_storage_files_datalake",
    "azure_sdk_keyvault",
    "azure_sdk_data_tables",
    "azure_sdk_data_cosmos",
    "azure_sdk_data_appconfiguration",
    "azure_sdk_attestation",
    "azure_sdk_messaging_common",
    "azure_sdk_eventhubs",
    "azure_sdk_servicebus",
    "azure_sdk_kusto_common",
    "azure_sdk_kusto_data",
    "azure_sdk_kusto_ingest",
};

pub const all = [_]Package{
    .{
        .kind = .sdk,
        .state = .package,
        .source_path = "sdk/core/tracing",
        .root_source_file = "root.zig",
        .name = "azure_sdk_core_tracing",
        .module_name = "azure_sdk_core_tracing",
        .branch = "sdk/core_tracing",
        .publish_paths = &.{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "root.zig",
            "README.md",
            "LICENSE.txt",
        },
    },
    .{
        .kind = .sdk,
        .state = .package,
        .source_path = "sdk/core/perf",
        .root_source_file = "root.zig",
        .name = "azure_sdk_core_perf",
        .module_name = "azure_sdk_core_perf",
        .branch = "sdk/core_perf",
        .publish_paths = &.{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "root.zig",
            "README.md",
            "LICENSE.txt",
        },
    },
    .{
        .kind = .sdk,
        .state = .package,
        .source_path = "sdk/core/amqp",
        .root_source_file = "root.zig",
        .name = "azure_sdk_core_amqp",
        .module_name = "azure_sdk_core_amqp",
        .branch = "sdk/core_amqp",
        .external_dependencies = &.{"uamqp"},
        .publish_paths = &.{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "root.zig",
            "README.md",
            "LICENSE.txt",
        },
    },
    .{
        .kind = .sdk,
        .state = .package,
        .source_path = "sdk/core",
        .root_source_file = "root.zig",
        .name = "azure_sdk_core",
        .module_name = "azure_sdk_core",
        .branch = "sdk/core",
        .dependencies = &.{"azure_sdk_core_tracing"},
        .external_dependencies = &.{"serde"},
        .publish_paths = &.{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "root.zig",
            "arm",
            "credentials",
            "http",
            "identity",
            "base64.zig",
            "case_insensitive_map.zig",
            "cloud.zig",
            "context.zig",
            "datetime.zig",
            "dotenv.zig",
            "errors.zig",
            "lro.zig",
            "open_enum.zig",
            "pager.zig",
            "response.zig",
            "safe_debug.zig",
            "url.zig",
            "uuid.zig",
            "README.md",
            "LICENSE.txt",
        },
    },
    .{
        .kind = .sdk,
        .state = .package,
        .source_path = "sdk/core/testing",
        .root_source_file = "root.zig",
        .name = "azure_sdk_core_testing",
        .module_name = "azure_sdk_core_testing",
        .branch = "sdk/core_testing",
        .dependencies = &.{"azure_sdk_core"},
        .publish_paths = &.{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "root.zig",
            "README.md",
            "LICENSE.txt",
        },
    },
    .{
        .kind = .rest,
        .source_path = "rest/arm_avs",
        .root_source_file = "src/root.zig",
        .name = "azure_rest_arm_avs",
        .module_name = "azure_rest_arm_avs",
        .branch = "rest/arm_avs",
        .legacy_names = &.{"arm_avs"},
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
        .examples_command = "zig build",
        .regeneration_command = "codegen/scripts/sync.sh arm_avs",
    },
    .{
        .kind = .rest,
        .source_path = "rest/keyvault_secrets",
        .root_source_file = "src/root.zig",
        .name = "azure_rest_keyvault_secrets",
        .module_name = "azure_rest_keyvault_secrets",
        .branch = "rest/keyvault_secrets",
        .legacy_names = &.{"keyvault_secrets"},
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
        .regeneration_command = "codegen/scripts/sync.sh keyvault_secrets",
    },
    .{
        .kind = .rest,
        .state = .package,
        .source_path = "rest/container_registry",
        .root_source_file = "src/root.zig",
        .name = "azure_rest_container_registry",
        .module_name = "azure_rest_container_registry",
        .branch = "rest/container_registry",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
        .publish_paths = &.{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "src",
            "README.md",
            "LICENSE.txt",
        },
        .regeneration_command = "(cd codegen/cli && zig build generate-container-registry-package)",
    },
    .{
        .kind = .sdk,
        .state = .package,
        .source_path = "sdk/container_registry",
        .root_source_file = "src/root.zig",
        .name = "azure_sdk_container_registry",
        .module_name = "azure_sdk_container_registry",
        .branch = "sdk/container_registry",
        .dependencies = &.{
            "azure_sdk_core",
            "azure_rest_container_registry",
        },
        .publish_paths = &.{
            ".gitignore",
            "build.zig",
            "build.zig.zon",
            "src",
            "examples",
            "live_tests",
            "README.md",
            "LICENSE.txt",
        },
        .examples_command = "zig build examples",
        .live_test_command = "zig build live-test",
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/storage/common",
        .root_source_file = "root.zig",
        .name = "azure_sdk_storage_common",
        .module_name = "azure_sdk_storage_common",
        .branch = "sdk/storage_common",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/storage/blobs",
        .root_source_file = "root.zig",
        .name = "azure_sdk_storage_blobs",
        .module_name = "azure_sdk_storage_blobs",
        .branch = "sdk/storage_blobs",
        .dependencies = &.{
            "azure_sdk_core",
            "azure_sdk_storage_common",
        },
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/storage/queues",
        .root_source_file = "root.zig",
        .name = "azure_sdk_storage_queues",
        .module_name = "azure_sdk_storage_queues",
        .branch = "sdk/storage_queues",
        .dependencies = &.{
            "azure_sdk_core",
            "azure_sdk_storage_common",
        },
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/storage/files/shares",
        .root_source_file = "root.zig",
        .name = "azure_sdk_storage_files_shares",
        .module_name = "azure_sdk_storage_files_shares",
        .branch = "sdk/storage_files_shares",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/storage/files/datalake",
        .root_source_file = "root.zig",
        .name = "azure_sdk_storage_files_datalake",
        .module_name = "azure_sdk_storage_files_datalake",
        .branch = "sdk/storage_files_datalake",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/keyvault",
        .root_source_file = "root.zig",
        .name = "azure_sdk_keyvault",
        .module_name = "azure_sdk_keyvault",
        .branch = "sdk/keyvault",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/data/tables",
        .root_source_file = "root.zig",
        .name = "azure_sdk_data_tables",
        .module_name = "azure_sdk_data_tables",
        .branch = "sdk/data_tables",
        .dependencies = &.{"azure_sdk_core"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/data/cosmos",
        .root_source_file = "root.zig",
        .name = "azure_sdk_data_cosmos",
        .module_name = "azure_sdk_data_cosmos",
        .branch = "sdk/data_cosmos",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/data/appconfiguration",
        .root_source_file = "root.zig",
        .name = "azure_sdk_data_appconfiguration",
        .module_name = "azure_sdk_data_appconfiguration",
        .branch = "sdk/data_appconfiguration",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/attestation",
        .root_source_file = "root.zig",
        .name = "azure_sdk_attestation",
        .module_name = "azure_sdk_attestation",
        .branch = "sdk/attestation",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/messaging/common",
        .root_source_file = "root.zig",
        .current_root_source_file = "sdk/messaging/common.zig",
        .name = "azure_sdk_messaging_common",
        .module_name = "azure_sdk_messaging_common",
        .branch = "sdk/messaging_common",
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/messaging/eventhubs",
        .root_source_file = "root.zig",
        .name = "azure_sdk_eventhubs",
        .module_name = "azure_sdk_eventhubs",
        .branch = "sdk/eventhubs",
        .identity_override = true,
        .dependencies = &.{
            "azure_sdk_core",
            "azure_sdk_messaging_common",
            "azure_sdk_storage_blobs",
        },
        .external_dependencies = &.{ "uamqp", "serde" },
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/messaging/servicebus",
        .root_source_file = "root.zig",
        .name = "azure_sdk_servicebus",
        .module_name = "azure_sdk_servicebus",
        .branch = "sdk/servicebus",
        .identity_override = true,
        .dependencies = &.{
            "azure_sdk_core",
            "azure_sdk_messaging_common",
        },
        .external_dependencies = &.{ "uamqp", "serde" },
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/kusto/common",
        .root_source_file = "root.zig",
        .current_root_source_file = "sdk/kusto/common.zig",
        .name = "azure_sdk_kusto_common",
        .module_name = "azure_sdk_kusto_common",
        .branch = "sdk/kusto_common",
        .dependencies = &.{"azure_sdk_core"},
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/kusto/data",
        .root_source_file = "root.zig",
        .name = "azure_sdk_kusto_data",
        .module_name = "azure_sdk_kusto_data",
        .branch = "sdk/kusto_data",
        .dependencies = &.{
            "azure_sdk_core",
            "azure_sdk_kusto_common",
        },
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .sdk,
        .source_path = "sdk/kusto/ingest",
        .root_source_file = "root.zig",
        .name = "azure_sdk_kusto_ingest",
        .module_name = "azure_sdk_kusto_ingest",
        .branch = "sdk/kusto_ingest",
        .dependencies = &.{
            "azure_sdk_core",
            "azure_sdk_kusto_common",
            "azure_sdk_kusto_data",
            "azure_sdk_storage_common",
            "azure_sdk_storage_blobs",
            "azure_sdk_storage_queues",
        },
        .external_dependencies = &.{"serde"},
    },
    .{
        .kind = .aggregate,
        .source_path = "sdk/aggregate",
        .root_source_file = "src/root.zig",
        .name = "azure_sdk",
        .module_name = "azure_sdk",
        .branch = "sdk/aggregate",
        .dependencies = all_implementation_packages,
    },
};

pub fn find(entries: []const Package, name: []const u8) ?usize {
    for (entries, 0..) |entry, index| {
        if (std.mem.eql(u8, entry.name, name)) return index;
    }
    return null;
}

pub fn tagAlloc(allocator: std.mem.Allocator, entry: Package) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/v{s}", .{ entry.name, entry.version });
}

pub fn validate(allocator: std.mem.Allocator, entries: []const Package) !void {
    if (entries.len == 0) return error.EmptyRegistry;

    for (entries, 0..) |entry, index| {
        try validateEntry(allocator, entry);
        for (entries[index + 1 ..]) |other| {
            if (std.mem.eql(u8, entry.name, other.name)) return error.DuplicatePackageName;
            if (std.mem.eql(u8, entry.module_name, other.module_name)) return error.DuplicateModuleName;
            if (std.mem.eql(u8, entry.source_path, other.source_path)) return error.DuplicateSourcePath;
            if (std.mem.eql(u8, entry.branch, other.branch)) return error.DuplicateBranch;
        }
        for (entry.dependencies) |dependency| {
            if (std.mem.eql(u8, dependency, entry.name)) return error.DependencyCycle;
            if (find(entries, dependency) == null) return error.UnknownDependency;
        }
    }

    const states = try allocator.alloc(VisitState, entries.len);
    defer allocator.free(states);
    @memset(states, .unvisited);
    for (entries, 0..) |_, index| try visit(entries, states, index);
}

pub fn topologicalOrder(
    allocator: std.mem.Allocator,
    entries: []const Package,
) ![]usize {
    try validate(allocator, entries);

    const indegrees = try allocator.alloc(usize, entries.len);
    defer allocator.free(indegrees);
    const emitted = try allocator.alloc(bool, entries.len);
    defer allocator.free(emitted);
    @memset(emitted, false);
    for (entries, 0..) |entry, index| indegrees[index] = entry.dependencies.len;

    var order: std.ArrayList(usize) = .empty;
    errdefer order.deinit(allocator);
    while (order.items.len < entries.len) {
        const next = for (entries, 0..) |_, index| {
            if (!emitted[index] and indegrees[index] == 0) break index;
        } else return error.DependencyCycle;

        emitted[next] = true;
        try order.append(allocator, next);
        for (entries, 0..) |entry, index| {
            if (emitted[index]) continue;
            for (entry.dependencies) |dependency| {
                if (std.mem.eql(u8, dependency, entries[next].name)) {
                    indegrees[index] -= 1;
                    break;
                }
            }
        }
    }
    return order.toOwnedSlice(allocator);
}

const VisitState = enum {
    unvisited,
    visiting,
    visited,
};

fn visit(entries: []const Package, states: []VisitState, index: usize) !void {
    switch (states[index]) {
        .visited => return,
        .visiting => return error.DependencyCycle,
        .unvisited => {},
    }
    states[index] = .visiting;
    for (entries[index].dependencies) |dependency| {
        try visit(entries, states, find(entries, dependency).?);
    }
    states[index] = .visited;
}

fn validateEntry(allocator: std.mem.Allocator, entry: Package) !void {
    if (!std.mem.eql(u8, entry.name, entry.module_name)) {
        return error.PackageModuleMismatch;
    }
    try validatePath(entry.source_path);
    try validateIdentifier(entry.name);
    try validateBranch(entry.branch);

    const version = std.SemanticVersion.parse(entry.version) catch {
        return error.InvalidVersion;
    };
    if (version.pre != null or version.build != null) return error.InvalidVersion;

    if (entry.kind == .aggregate) {
        if (!std.mem.eql(u8, entry.source_path, "sdk/aggregate") or
            !std.mem.eql(u8, entry.name, "azure_sdk") or
            !std.mem.eql(u8, entry.branch, "sdk/aggregate"))
        {
            return error.InvalidAggregateIdentity;
        }
        return;
    }

    if (entry.identity_override) return;

    const prefix = switch (entry.kind) {
        .sdk => "sdk/",
        .rest => "rest/",
        .aggregate => unreachable,
    };
    if (!std.mem.startsWith(u8, entry.source_path, prefix)) {
        return error.InvalidSourcePath;
    }
    const suffix = entry.source_path[prefix.len..];
    const identifier = try allocator.dupe(u8, suffix);
    defer allocator.free(identifier);
    std.mem.replaceScalar(u8, identifier, '/', '_');

    const expected_name = try std.fmt.allocPrint(
        allocator,
        "azure_{s}_{s}",
        .{ @tagName(entry.kind), identifier },
    );
    defer allocator.free(expected_name);
    if (!std.mem.eql(u8, entry.name, expected_name)) return error.InvalidPackageName;

    const expected_branch = try std.fmt.allocPrint(
        allocator,
        "{s}/{s}",
        .{ @tagName(entry.kind), identifier },
    );
    defer allocator.free(expected_branch);
    if (!std.mem.eql(u8, entry.branch, expected_branch)) return error.InvalidBranch;
}

fn validatePath(path: []const u8) !void {
    if (path.len == 0 or path[0] == '/' or std.mem.indexOfScalar(u8, path, '\\') != null) {
        return error.InvalidSourcePath;
    }
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (segment.len == 0 or
            std.mem.eql(u8, segment, ".") or
            std.mem.eql(u8, segment, ".."))
        {
            return error.InvalidSourcePath;
        }
    }
}

fn validateIdentifier(identifier: []const u8) !void {
    if (identifier.len == 0) return error.InvalidPackageName;
    if (identifier.len > 32) return error.PackageNameTooLong;
    for (identifier) |byte| switch (byte) {
        'a'...'z', '0'...'9', '_' => {},
        else => return error.InvalidPackageName,
    };
}

fn validateBranch(branch: []const u8) !void {
    try validatePath(branch);
    if (!std.mem.startsWith(u8, branch, "sdk/") and
        !std.mem.startsWith(u8, branch, "rest/"))
    {
        return error.InvalidBranch;
    }
}
