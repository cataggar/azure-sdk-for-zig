const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const core_mod = core_dep.module("azure_sdk_core");

    const common_dep = b.dependency("azure_sdk_messaging_common", .{
        .target = target,
        .optimize = optimize,
    });
    const common_mod = common_dep.module("azure_sdk_messaging_common");

    const amqp_dep = b.dependency("azure_sdk_amqp", .{
        .target = target,
        .optimize = optimize,
    });
    const amqp_mod = amqp_dep.module("azure_sdk_amqp");

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    const imports = [_]std.Build.Module.Import{
        .{ .name = "azure_sdk_core", .module = core_mod },
        .{ .name = "azure_sdk_messaging_common", .module = common_mod },
        .{ .name = "azure_sdk_amqp", .module = amqp_mod },
        .{ .name = "serde", .module = serde_mod },
    };

    _ = b.addModule("azure_sdk_servicebus", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .imports = &imports,
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
    });
    const test_step = b.step("test", "Run Service Bus tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // Offline encode/decode/receive benchmarks. Built with the tests so a
    // signature change cannot silently rot them, but only run on demand: they
    // are far too slow for every `zig build test`.
    const sdk_mod = b.modules.get("azure_sdk_servicebus").?;
    const benchmarks = b.addExecutable(.{
        .name = "servicebus-bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("benchmarks/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{ .name = "azure_sdk_servicebus", .module = sdk_mod },
                // For the scripted peer the receive benchmarks read from.
                .{ .name = "azure_sdk_amqp", .module = amqp_mod },
            },
        }),
    });
    const bench_step = b.step(
        "bench",
        "Run Service Bus encode/decode benchmarks (use -Doptimize=ReleaseFast)",
    );
    bench_step.dependOn(&b.addRunArtifact(benchmarks).step);
    test_step.dependOn(&benchmarks.step);
}
