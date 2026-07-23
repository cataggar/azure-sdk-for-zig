const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const azure_sdk_core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const azure_sdk_core_mod = azure_sdk_core_dep.module("azure_sdk_core");

    const rest_dep = b.dependency("azure_rest_container_registry", .{
        .target = target,
        .optimize = optimize,
    });
    const rest_mod = rest_dep.module("azure_rest_container_registry");
    // The REST dependency also declares Core. Replace its module import with
    // this package's direct Core dependency to avoid duplicate source owners.
    rest_mod.addImport("azure_sdk_core", azure_sdk_core_mod);

    const sdk_mod = b.addModule("azure_sdk_container_registry", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
            .{ .name = "azure_rest_container_registry", .module = rest_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
                .{ .name = "azure_rest_container_registry", .module = rest_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Container Registry SDK tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const support_mod = b.createModule(.{
        .root_source_file = b.path("examples/support.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
            .{ .name = "azure_sdk_container_registry", .module = sdk_mod },
        },
    });
    const examples_step = b.step(
        "examples",
        "Compile all Container Registry examples",
    );
    const example_sources = [_]struct {
        name: []const u8,
        source: []const u8,
    }{
        .{
            .name = "acr-list-repositories-tags",
            .source = "examples/list_repositories_tags.zig",
        },
        .{
            .name = "acr-anonymous-read",
            .source = "examples/anonymous_read.zig",
        },
        .{
            .name = "acr-oci-push-pull",
            .source = "examples/oci_push_pull.zig",
        },
        .{
            .name = "acr-delete-artifact",
            .source = "examples/delete_artifact.zig",
        },
    };
    for (example_sources) |example| {
        const executable = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.source),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
                    .{
                        .name = "azure_sdk_container_registry",
                        .module = sdk_mod,
                    },
                    .{ .name = "acr_example_support", .module = support_mod },
                },
            }),
        });
        examples_step.dependOn(&executable.step);
        test_step.dependOn(&executable.step);
    }

    const live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("live_tests/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
                .{ .name = "azure_sdk_container_registry", .module = sdk_mod },
            },
        }),
    });
    const live_test_step = b.step(
        "live-test",
        "Run destructive opt-in Container Registry live tests; unconfigured tests skip",
    );
    live_test_step.dependOn(&b.addRunArtifact(live_tests).step);
}
