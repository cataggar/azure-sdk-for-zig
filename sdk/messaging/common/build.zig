const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("azure_sdk_messaging_common", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const test_step = b.step("test", "Run Messaging Common tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
