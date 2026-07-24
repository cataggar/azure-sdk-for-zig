//! Build the `codegen-cli` wasm32-wasi binary.
//!
//! Output: `zig-out/bin/codegen-cli.wasm` — a preview1 command that
//! imports `wasi_snapshot_preview1.*` and one custom import (the
//! `compile` function from `azure:codegen/tcgc`, when the
//! component-type metadata is embedded).
//!
//! Wrapping into a component, embedding the world metadata, and
//! composing with `tcgc.wasm` is done by
//! `scripts/build-component.sh` (or invoked via `zig build component`).

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });
    const optimize = b.standardOptimizeOption(.{});
    const codemodel_mod = b.createModule(.{
        .root_source_file = b.path("src/codemodel.zig"),
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("codemodel", codemodel_mod);

    const exe = b.addExecutable(.{
        .name = "codegen-cli",
        .root_module = exe_mod,
    });
    // `@export(&cabi_realloc, …)` alone isn't enough — wasm-ld's
    // `--gc-sections` strips it because nothing reachable from
    // `_start` references it. `rdynamic = true` forces all
    // `@export`-marked symbols into the wasm exports section so the
    // tcgc subcomponent can call it for canonical-ABI allocation.
    exe.rdynamic = true;
    b.installArtifact(exe);

    // Tests run against the host target (the emitter is pure logic;
    // tcgc_import.zig's stub is target-agnostic too).
    const host_target = b.standardTargetOptions(.{});
    const test_step = b.step("test", "Run unit tests");
    const test_root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = host_target,
        .optimize = optimize,
    });
    test_root.addImport("codemodel", codemodel_mod);
    const t = b.addTest(.{
        .root_module = test_root,
    });
    test_step.dependOn(&b.addRunArtifact(t).step);

    const fixture_test_mod = b.createModule(.{
        .root_source_file = b.path("../fixtures/container_registry_test.zig"),
        .target = host_target,
        .optimize = optimize,
    });
    fixture_test_mod.addImport("codemodel", codemodel_mod);
    const emit_mod = b.createModule(.{
        .root_source_file = b.path("src/emit.zig"),
        .target = host_target,
        .optimize = optimize,
    });
    emit_mod.addImport("codemodel", codemodel_mod);
    fixture_test_mod.addImport("emit", emit_mod);
    const fixture_test = b.addTest(.{
        .root_module = fixture_test_mod,
    });
    test_step.dependOn(&b.addRunArtifact(fixture_test).step);

    const fixture_generator_mod = b.createModule(.{
        .root_source_file = b.path("../fixtures/generate_container_registry_package.zig"),
        .target = host_target,
        .optimize = optimize,
    });
    fixture_generator_mod.addImport("emit", emit_mod);
    const fixture_generator = b.addExecutable(.{
        .name = "generate-container-registry-package",
        .root_module = fixture_generator_mod,
    });
    const generate_fixture = b.addRunArtifact(fixture_generator);
    const generated_fixture_dir =
        generate_fixture.addOutputDirectoryArg("container-registry-package");

    const generate_container_registry = b.addRunArtifact(fixture_generator);
    generate_container_registry.setCwd(b.path("."));
    generate_container_registry.has_side_effects = true;
    const container_registry_output = b.option(
        []const u8,
        "container-registry-output",
        "Container Registry package output directory",
    );
    generate_container_registry.addArg(
        container_registry_output orelse
            "../../.release/container_registry/generated-rest",
    );
    const azure_sdk_core_commit = b.option(
        []const u8,
        "azure-sdk-core-commit",
        "Commit for the independently published azure_sdk_core package",
    );
    const azure_sdk_core_hash = b.option(
        []const u8,
        "azure-sdk-core-hash",
        "Zig package hash for -Dazure-sdk-core-commit",
    );
    const azure_sdk_core_path = b.option(
        []const u8,
        "azure-sdk-core-path",
        "Local azure_sdk_core dependency path in generated build.zig.zon",
    );
    if ((azure_sdk_core_commit == null) != (azure_sdk_core_hash == null)) {
        std.debug.panic(
            "-Dazure-sdk-core-commit and -Dazure-sdk-core-hash must be supplied together",
            .{},
        );
    }
    if (container_registry_output != null and
        azure_sdk_core_commit == null and
        azure_sdk_core_path == null)
    {
        std.debug.panic(
            "an explicit output requires -Dazure-sdk-core-path or an immutable Core commit/hash pin",
            .{},
        );
    }
    if (azure_sdk_core_commit) |commit| {
        generate_container_registry.addArgs(&.{
            "--azure-sdk-core-commit",
            commit,
            "--azure-sdk-core-hash",
            azure_sdk_core_hash.?,
        });
    } else {
        generate_container_registry.addArgs(&.{
            "--azure-sdk-core-path",
            azure_sdk_core_path orelse "../../../sdk/core",
        });
    }
    const generate_container_registry_step = b.step(
        "generate-container-registry-package",
        "Regenerate Container Registry into an external package worktree",
    );
    generate_container_registry_step.dependOn(&generate_container_registry.step);

    const azure_sdk_core_dep = b.dependency("azure_sdk_core", .{
        .target = host_target,
        .optimize = optimize,
    });
    const serde_dep = b.dependency("serde", .{
        .target = host_target,
        .optimize = optimize,
    });
    const generated_fixture_mod = b.createModule(.{
        .root_source_file = generated_fixture_dir.path(b, "src/root.zig"),
        .target = host_target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = azure_sdk_core_dep.module("azure_sdk_core") },
            .{ .name = "serde", .module = serde_dep.module("serde") },
        },
    });
    const generated_fixture_test = b.addTest(.{
        .root_module = generated_fixture_mod,
    });
    test_step.dependOn(&b.addRunArtifact(generated_fixture_test).step);

    // ── Componentization step ────────────────────────────────────
    //
    // Drives wabt + wac to produce the composed component:
    //   1. wabt component embed -w cli wit/ codegen-cli.wasm
    //   2. wabt component new --adapt …upstream preview1 adapter…
    //   3. wabt component compose codegen-cli.comp.wasm -d tcgc.wasm
    //
    // Implemented as a shell script to keep build.zig short and so
    // it can be run standalone for debugging.
    const component_step = b.step("component", "Build the composed component (wabt embed + new + compose)");
    const sh = b.addSystemCommand(&.{ "bash", "scripts/build-component.sh" });
    sh.step.dependOn(b.getInstallStep());
    component_step.dependOn(&sh.step);
}
