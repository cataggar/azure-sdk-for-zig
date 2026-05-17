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

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "codegen-cli",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    // Tests run against the host target (the emitter is pure logic;
    // tcgc_import.zig's stub is target-agnostic too).
    const host_target = b.standardTargetOptions(.{});
    const test_step = b.step("test", "Run unit tests");
    const t = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = host_target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(t).step);

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
