const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseSmall,
    });
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });

    const core_dependency = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_module = core_dependency.module("azure_sdk_core");
    const arm_avs_dependency = b.dependency("azure_rest_arm_avs", .{
        .target = target,
        .optimize = optimize,
    });
    const arm_avs_module = arm_avs_dependency.module("azure_rest_arm_avs");

    const executable = b.addExecutable(.{
        .name = "avs.core",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_module },
                .{ .name = "azure_rest_arm_avs", .module = arm_avs_module },
            },
        }),
    });
    executable.entry = .disabled;
    executable.rdynamic = true;
    executable.use_llvm = false;
    executable.use_lld = false;
    b.installArtifact(executable);

    const test_step = b.step("test", "Compile the WASI example");
    test_step.dependOn(&executable.step);
    _ = b.step("live-test", "Live tests require a WASI component runtime");
}
