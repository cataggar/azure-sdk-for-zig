const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const uamqp_dep = b.dependency("uamqp", .{});
    // Registered by name rather than created anonymously so dependents can
    // reuse this exact module. Two `createModule` calls over the same source
    // produce two modules, and therefore two incompatible copies of every
    // type in them, which breaks any dependent that passes an `AmqpValue`
    // across the package boundary.
    const uamqp_mod = b.addModule("uamqp", .{
        .root_source_file = uamqp_dep.path("src/zig/uamqp.zig"),
        .target = target,
    });

    _ = b.addModule("azure_sdk_amqp", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "uamqp", .module = uamqp_mod },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "uamqp", .module = uamqp_mod },
            },
        }),
    });
    const test_step = b.step("test", "Run Core AMQP tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
