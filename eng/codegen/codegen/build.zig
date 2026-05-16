const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    // wamr does not call `b.addModule(...)` (see upstream build.zig
    // comment); we build the wamr module ourselves against its source
    // tree, mirroring the pattern wamr itself uses for `wabt`.
    const wamr_dep = b.dependency("wamr", .{});
    const wamr_mod = makeWamrModule(b, wamr_dep, target, optimize);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "serde", .module = serde_mod },
            .{ .name = "wamr", .module = wamr_mod },
        },
    });

    const exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the codegen CLI");
    const run = b.addRunArtifact(exe);
    run.step.dependOn(b.getInstallStep());
    if (b.args) |args| run.addArgs(args);
    run_step.dependOn(&run.step);

    // -- Tests --
    const test_step = b.step("test", "Run unit tests");
    const t = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "serde", .module = serde_mod },
                .{ .name = "wamr", .module = wamr_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(t).step);
}

/// Build a module pointing at wamr's `src/root.zig`, with a synthesized
/// `config` build-options module. wamr reads its compile-time feature
/// flags from `@import("config")`; we provide just enough to enable the
/// Component Model + interpreter path that this codegen tool exercises.
fn makeWamrModule(
    b: *std.Build,
    wamr_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const opts = b.addOptions();
    opts.addOption([]const u8, "version", "azure-sdk-codegen");
    opts.addOption(bool, "interp", true);
    opts.addOption(bool, "fast_interp", true);
    opts.addOption(bool, "aot", false);
    opts.addOption(bool, "wamr_compiler", false);
    opts.addOption(bool, "jit", false);
    opts.addOption(bool, "fast_jit", false);
    opts.addOption(bool, "libc_builtin", true);
    opts.addOption(bool, "libc_wasi", true);
    opts.addOption(bool, "simd", true);
    opts.addOption(bool, "ref_types", true);
    opts.addOption(bool, "bulk_memory", true);
    opts.addOption(bool, "multi_module", false);
    opts.addOption(bool, "component_model", true);

    const config_mod = opts.createModule();
    const mod = b.createModule(.{
        .root_source_file = wamr_dep.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addImport("config", config_mod);
    return mod;
}
