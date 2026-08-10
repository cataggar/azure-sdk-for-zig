const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const azure_sdk_core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const azure_sdk_core_mod = azure_sdk_core_dep.module("azure_sdk_core");

    const rest_dep = b.dependency("azure_rest_devops", .{
        .target = target,
        .optimize = optimize,
    });
    const rest_mod = rest_dep.module("azure_rest_devops");
    // The REST dependency also declares Core. Replace its module import with
    // this package's direct Core dependency to avoid duplicate source owners.
    rest_mod.addImport("azure_sdk_core", azure_sdk_core_mod);

    const sdk_mod = b.addModule("azure_sdk_devops", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
            .{ .name = "azure_rest_devops", .module = rest_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
                .{ .name = "azure_rest_devops", .module = rest_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Azure DevOps SDK tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const support_mod = b.createModule(.{
        .root_source_file = b.path("examples/support.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
            .{ .name = "azure_sdk_devops", .module = sdk_mod },
        },
    });
    const examples_step = b.step("examples", "Compile all Azure DevOps examples");
    const example_sources = [_]struct {
        name: []const u8,
        source: []const u8,
    }{
        .{
            .name = "devops-list-repositories",
            .source = "examples/list_repositories.zig",
        },
        .{
            .name = "devops-list-projects",
            .source = "examples/list_projects.zig",
        },
        .{
            .name = "devops-list-builds",
            .source = "examples/list_builds.zig",
        },
        .{
            .name = "devops-query-work-items",
            .source = "examples/query_work_items.zig",
        },
        .{
            .name = "devops-page-audit-log",
            .source = "examples/page_audit_log.zig",
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
                    .{ .name = "azure_sdk_devops", .module = sdk_mod },
                    .{ .name = "devops_example_support", .module = support_mod },
                },
            }),
        });
        examples_step.dependOn(&b.addInstallArtifact(executable, .{}).step);
        test_step.dependOn(&executable.step);
    }

    const live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("live_tests/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = azure_sdk_core_mod },
                .{ .name = "azure_sdk_devops", .module = sdk_mod },
            },
        }),
    });
    const live_test_step = b.step(
        "live-test",
        "Run opt-in Azure DevOps live tests; unconfigured tests skip",
    );
    live_test_step.dependOn(&b.addRunArtifact(live_tests).step);
}
