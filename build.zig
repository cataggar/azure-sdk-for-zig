const std = @import("std");

pub fn build(b: *std.Build) void {
    // Force a WASI command core. wabt/wasm-tools' wasi-preview1 -> preview2
    // adapter wraps it into a component during packaging (see package.sh).
    const target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const azure_sdk_dep = b.dependency("azure_sdk", .{ .target = target, .optimize = optimize });
    const azure_core_mod = azure_sdk_dep.module("azure_core");

    const arm_avs_dep = b.dependency("arm_avs", .{ .target = target, .optimize = optimize });
    const arm_avs_mod = arm_avs_dep.module("arm_avs");

    const exe = b.addExecutable(.{
        .name = "avs.core",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "arm_avs", .module = arm_avs_mod },
                .{ .name = "azure_core", .module = azure_core_mod },
            },
        }),
    });
    // Emit a no-start-section command core that exports `_start` (the wasi
    // command entry the adapter calls) and `cabi_realloc` (canonical-ABI
    // return-value materialization for the wasi:http imports).
    exe.entry = .disabled;
    exe.rdynamic = true;
    // Use Zig's self-hosted wasm backend and linker instead of LLVM/LLD.
    exe.use_llvm = false;
    exe.use_lld = false;
    b.installArtifact(exe);
}
