const std = @import("std");
const registry = @import("packages.zig");

test "registry contains a valid twenty-six-package dependency graph" {
    try std.testing.expectEqual(@as(usize, 26), registry.all.len);
    try registry.validate(std.testing.allocator, &registry.all);
    for (registry.all) |entry| {
        try std.testing.expectEqual(registry.MigrationState.package, entry.state);
    }
}

test "topological order places dependencies before dependents" {
    const order = try registry.topologicalOrder(std.testing.allocator, &registry.all);
    defer std.testing.allocator.free(order);

    for (registry.all, 0..) |entry, entry_index| {
        const entry_position = position(order, entry_index).?;
        for (entry.dependencies) |dependency| {
            const dependency_index = registry.find(&registry.all, dependency).?;
            try std.testing.expect(position(order, dependency_index).? < entry_position);
        }
    }
    try std.testing.expectEqual(
        registry.find(&registry.all, "azure_sdk").?,
        order[order.len - 1],
    );
}

test "package tags are package scoped" {
    const tag = try registry.tagAlloc(std.testing.allocator, registry.all[0]);
    defer std.testing.allocator.free(tag);
    try std.testing.expectEqualStrings("azure_sdk_core_tracing/v0.1.0", tag);
}

test "registry rejects duplicate names" {
    const entries = [_]registry.Package{
        testPackage("sdk/a", "azure_sdk_a", "sdk/a", &.{}),
        testPackage("sdk/b", "azure_sdk_a", "sdk/b", &.{}),
    };
    try std.testing.expectError(
        error.DuplicatePackageName,
        registry.validate(std.testing.allocator, &entries),
    );
}

test "registry rejects unknown dependencies" {
    const entries = [_]registry.Package{
        testPackage("sdk/a", "azure_sdk_a", "sdk/a", &.{"azure_sdk_missing"}),
    };
    try std.testing.expectError(
        error.UnknownDependency,
        registry.validate(std.testing.allocator, &entries),
    );
}

test "registry rejects dependency cycles" {
    const entries = [_]registry.Package{
        testPackage("sdk/a", "azure_sdk_a", "sdk/a", &.{"azure_sdk_b"}),
        testPackage("sdk/b", "azure_sdk_b", "sdk/b", &.{"azure_sdk_a"}),
    };
    try std.testing.expectError(
        error.DependencyCycle,
        registry.validate(std.testing.allocator, &entries),
    );
}

test "registry rejects invalid derived identities and versions" {
    var wrong_name = testPackage("sdk/a", "azure_sdk_wrong", "sdk/a", &.{});
    try std.testing.expectError(
        error.InvalidPackageName,
        registry.validate(std.testing.allocator, (&[_]registry.Package{wrong_name})[0..]),
    );

    wrong_name = testPackage("sdk/a", "azure_sdk_a", "sdk/a", &.{});
    wrong_name.version = "1.0";
    try std.testing.expectError(
        error.InvalidVersion,
        registry.validate(std.testing.allocator, (&[_]registry.Package{wrong_name})[0..]),
    );

    var long_name = testPackage(
        "sdk/a",
        "azure_sdk_package_name_over_thirty_two",
        "sdk/a",
        &.{},
    );
    long_name.identity_override = true;
    try std.testing.expectError(
        error.PackageNameTooLong,
        registry.validate(std.testing.allocator, (&[_]registry.Package{long_name})[0..]),
    );
}

test "registry requires release metadata" {
    var missing_test = testPackage("sdk/a", "azure_sdk_a", "sdk/a", &.{});
    missing_test.test_command = null;
    try std.testing.expectError(
        error.MissingTestCommand,
        registry.validate(std.testing.allocator, (&[_]registry.Package{missing_test})[0..]),
    );

    var missing_readme = testPackage("sdk/a", "azure_sdk_a", "sdk/a", &.{});
    missing_readme.publish_paths = &.{
        "build.zig",
        "build.zig.zon",
        "LICENSE.txt",
    };
    try std.testing.expectError(
        error.MissingRequiredPublishPath,
        registry.validate(std.testing.allocator, (&[_]registry.Package{missing_readme})[0..]),
    );
}

fn testPackage(
    source_path: []const u8,
    name: []const u8,
    branch: []const u8,
    dependencies: []const []const u8,
) registry.Package {
    return .{
        .kind = .sdk,
        .source_path = source_path,
        .root_source_file = "root.zig",
        .name = name,
        .module_name = name,
        .branch = branch,
        .dependencies = dependencies,
        .publish_paths = &.{
            "build.zig",
            "build.zig.zon",
            "README.md",
            "LICENSE.txt",
        },
    };
}

fn position(order: []const usize, wanted: usize) ?usize {
    for (order, 0..) |value, index| {
        if (value == wanted) return index;
    }
    return null;
}
