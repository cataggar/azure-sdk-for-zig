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

    const rest_dep = b.dependency("azure_rest_data_tables", .{
        .target = target,
        .optimize = optimize,
    });
    const rest_mod = rest_dep.module("azure_rest_data_tables");

    const sdk_mod = b.addModule("azure_sdk_data_tables", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "serde", .module = serde_mod },
            .{ .name = "azure_rest_data_tables", .module = rest_mod },
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
                .{ .name = "azure_rest_data_tables", .module = rest_mod },
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

    const examples_step = b.step("examples", "Compile all Data Tables examples");
    const example_sources = [_]struct {
        name: []const u8,
        source: []const u8,
    }{
        .{ .name = "data-tables-authentication", .source = "examples/authentication.zig" },
        .{ .name = "data-tables-entities", .source = "examples/entities.zig" },
        .{ .name = "data-tables-administration", .source = "examples/administration.zig" },
        .{ .name = "data-tables-transactions", .source = "examples/transactions.zig" },
    };
    const example_support_mod = b.createModule(.{
        .root_source_file = b.path("examples/support.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{ .name = "azure_sdk_data_tables", .module = sdk_mod },
        },
    });
    for (example_sources) |example| {
        const executable = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.source),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core", .module = core_mod },
                    .{ .name = "azure_sdk_data_tables", .module = sdk_mod },
                    .{ .name = "tables_example_support", .module = example_support_mod },
                },
            }),
        });
        examples_step.dependOn(&executable.step);
        test_step.dependOn(&executable.step);
    }

    const azurite_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("integration_tests/azurite.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_data_tables", .module = sdk_mod },
            },
        }),
    });
    const azurite_test_step = b.step(
        "azurite-test",
        "Run opt-in Azurite Tables integration tests; unconfigured tests skip",
    );
    azurite_test_step.dependOn(&b.addRunArtifact(azurite_tests).step);

    const live_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("live_tests/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_data_tables", .module = sdk_mod },
            },
        }),
    });
    const live_test_step = b.step(
        "live-test",
        "Run opt-in Azure Storage Tables live tests; unconfigured tests skip",
    );
    live_test_step.dependOn(&b.addRunArtifact(live_tests).step);
}
