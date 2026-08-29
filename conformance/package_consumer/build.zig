const std = @import("std");

const Linkage = enum { dynamic, static };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const linkage = b.option(Linkage, "linkage", "SymCrypt linkage") orelse .dynamic;
    const libraries = b.option(
        []const std.Build.LazyPath,
        "symcrypt_libraries",
        "Ordered exact SymCrypt libraries",
    ) orelse &.{};
    const include_dir = b.option(
        std.Build.LazyPath,
        "symcrypt_include_dir",
        "Complete pinned SymCrypt public headers",
    );
    const system_include_dirs = b.option(
        []const std.Build.LazyPath,
        "symcrypt_system_include_dirs",
        "Target SDK/CRT include directories",
    ) orelse &.{};
    const checked = b.option(
        bool,
        "symcrypt_checked",
        "Match checked/DBG SymCrypt inputs",
    ) orelse false;
    const provenance = b.option(
        std.Build.LazyPath,
        "symcrypt_provenance",
        "Exact fixture provenance",
    );

    const adapter = b.dependency("adapter", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .symcrypt_libraries = libraries,
        .symcrypt_include_dir = include_dir,
        .symcrypt_system_include_dirs = system_include_dirs,
        .symcrypt_checked = checked,
        .symcrypt_provenance = provenance,
    });
    const module = b.createModule(.{
        .root_source_file = b.path("consumer.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "azure_sdk_core_symcrypt",
                .module = adapter.module("azure_sdk_core_symcrypt"),
            },
        },
    });
    if (target.result.os.tag == .linux and linkage == .dynamic) {
        module.addRPath(libraries[libraries.len - 1].dirname());
    }
    const tests = b.addTest(.{ .root_module = module });
    const compile_step = b.step(
        "test-compile",
        "Compile and link the external package consumer",
    );
    compile_step.dependOn(&tests.step);
    const test_step = b.step("test", "Run the external package consumer");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
