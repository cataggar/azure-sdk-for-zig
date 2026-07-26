const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    _ = b.addModule("azure_sdk_data_tables", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
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
                .{ .name = "serde", .module = serde_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Data Tables tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    const negative_tests = b.addSystemCommand(&.{
        "sh",
        "-c",
        \\set -eu
        \\for fixture in entity_codec_compile_fail_*.zig; do
        \\  if output=$("$0" test --dep serde -Mroot="$fixture" --dep compat -Mserde=zig-pkg/serde-1.0.1-1DszT-e9DABp6u1PoDvGFzeGaST2hRp2KGtGn_CkIl0J/src/root.zig -Mcompat=zig-pkg/serde-1.0.1-1DszT-e9DABp6u1PoDvGFzeGaST2hRp2KGtGn_CkIl0J/src/compat_0_16.zig 2>&1); then
        \\    echo "expected $fixture to fail compilation" >&2
        \\    exit 1
        \\  fi
        \\  case "$output" in
        \\    *EntityCodec*) ;;
        \\    *) echo "$fixture did not fail with an EntityCodec diagnostic" >&2; exit 1 ;;
        \\  esac
        \\done
        ,
        b.graph.zig_exe,
    });
    test_step.dependOn(&negative_tests.step);
}
