const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const common_dep = b.dependency("azure_sdk_kusto_common", .{
        .target = target,
        .optimize = optimize,
    });
    const common_mod = common_dep.module("azure_sdk_kusto_common");

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    common_mod.addImport("azure_sdk_core", core_mod);
    common_mod.addImport("serde", serde_mod);

    const data_mod = b.addModule("azure_sdk_kusto_data", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "azure_sdk_kusto_common", .module = common_mod },
            .{ .name = "serde", .module = serde_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_kusto_common", .module = common_mod },
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Kusto Data tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const example = b.addExecutable(.{
        .name = "kusto-data-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_kusto_common", .module = common_mod },
                .{ .name = "azure_sdk_kusto_data", .module = data_mod },
            },
        }),
    });
    const examples_step = b.step("examples", "Compile Kusto Data examples");
    examples_step.dependOn(&example.step);
    test_step.dependOn(&example.step);

    const run_example = b.addRunArtifact(example);
    if (b.args) |args| run_example.addArgs(args);
    const run_example_step = b.step("run-example", "Run a Kusto Data example");
    run_example_step.dependOn(&run_example.step);

    const live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/live_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_kusto_common", .module = common_mod },
                .{ .name = "azure_sdk_kusto_data", .module = data_mod },
            },
        }),
    });
    const live_test_step = b.step(
        "live-test",
        "Run opt-in Kusto Data live tests; unconfigured tests skip",
    );
    live_test_step.dependOn(&b.addRunArtifact(live_tests).step);
}
