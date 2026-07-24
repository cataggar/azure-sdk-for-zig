const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const kusto_dep = b.dependency("azure_sdk_kusto", .{
        .target = target,
        .optimize = optimize,
    });
    const kusto_mod = kusto_dep.module("azure_sdk_kusto");

    const imports = [_]std.Build.Module.Import{
        .{ .name = "azure_sdk_core", .module = core_mod },
        .{ .name = "azure_sdk_kusto", .module = kusto_mod },
    };
    const example = b.addExecutable(.{
        .name = "kusto-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("runner.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
    });

    const examples_step = b.step("examples", "Compile Kusto examples");
    examples_step.dependOn(&example.step);

    const run_example = b.addRunArtifact(example);
    if (b.args) |args| run_example.addArgs(args);
    const run_example_step = b.step("run-example", "Run a Kusto example");
    run_example_step.dependOn(&run_example.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("runner.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
    });
    const test_step = b.step("test", "Run Kusto example tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    test_step.dependOn(&example.step);

    const live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("live_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
    });
    const live_test_step = b.step(
        "live-test",
        "Run opt-in Kusto live tests; unconfigured tests skip",
    );
    live_test_step.dependOn(&b.addRunArtifact(live_tests).step);
}
