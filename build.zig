const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    if (target.result.os.tag == .wasi) {
        @panic("azure_sdk_core_httpx is optional native transport; use Core's WASI host backend");
    }
    const core = b.dependency("azure_sdk_core", .{ .target = target, .optimize = optimize });
    const httpx = b.dependency("httpx", .{ .target = target, .optimize = optimize });
    const httpx_module = httpx.module("httpx");
    // Re-export the actual module, not another compilation of the HTTPX source.
    b.modules.put(b.allocator, "httpx", httpx_module) catch @panic("out of memory");
    b.modules.put(b.allocator, "azure_sdk_core", core.module("azure_sdk_core")) catch @panic("out of memory");
    const adapter = b.addModule("azure_sdk_core_httpx", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core.module("azure_sdk_core") },
            .{ .name = "httpx", .module = httpx_module },
        },
    });
    // Propagate HTTPX's Windows socket imports to consumers, not just tests.
    if (target.result.os.tag == .windows) {
        adapter.linkSystemLibrary("ws2_32", .{});
        adapter.linkSystemLibrary("mswsock", .{});
    }
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core_httpx", .module = adapter },
                .{ .name = "httpx", .module = httpx_module },
                .{ .name = "azure_sdk_core_http_conformance", .module = core.module("azure_sdk_core_http_conformance") },
            },
        }),
        .filters = if (b.option([]const u8, "test-filter", "Run matching adapter tests")) |filter| &.{filter} else &.{},
    });
    b.default_step.dependOn(&tests.step);
    const test_step = b.step("test", "Run offline adapter and published Core transport conformance");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}
