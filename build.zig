const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const uamqp_dep = b.dependency("uamqp", .{
        .target = target,
        .optimize = optimize,
    });
    // Re-export uamqp's own module instance rather than rebuilding one from
    // its source path. Rebuilding skips the wiring uamqp's build.zig does —
    // as of v0.3.0 it imports its own build.zig.zon so `uamqp.version` is not
    // a second copy of the version — and it would break again on any future
    // addition. Re-exporting also keeps a single instance: two modules over
    // the same source produce two incompatible copies of every type in them,
    // which breaks any dependent that passes an `AmqpValue` across the
    // package boundary.
    const uamqp_mod = uamqp_dep.module("uamqp");
    b.modules.put(b.graph.arena, b.dupe("uamqp"), uamqp_mod) catch @panic("OOM");

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
