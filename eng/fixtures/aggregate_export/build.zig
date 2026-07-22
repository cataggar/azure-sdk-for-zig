const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const provider = b.dependency("provider", .{
        .target = target,
        .optimize = optimize,
    });

    b.modules.put(
        b.graph.arena,
        b.dupe("fixture_module"),
        provider.module("fixture_module"),
    ) catch @panic("OOM");
}
