const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const core = b.dependency("azure_sdk_core", .{ .target = target, .optimize = optimize });
    const appconfiguration = b.dependency("azure_sdk_data_appconfiguration", .{
        .target = target,
        .optimize = optimize,
    });
    const service_module = appconfiguration.module("azure_sdk_data_appconfiguration");
    const core_module = core.module("azure_sdk_core");
    // Identical immutable pins and build options must resolve to one module.
    std.debug.assert(service_module.import_table.get("azure_sdk_core").? == core_module);
    const imports: []const std.Build.Module.Import = &.{
        .{ .name = "azure_sdk_core", .module = core_module },
        .{ .name = "azure_sdk_data_appconfiguration", .module = service_module },
    };
    const exe = b.addExecutable(.{
        .name = "otlp-collector-fixture",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);
    b.step("run", "Generate or verify mock service telemetry (no network)").dependOn(&run.step);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("fixture.zig"),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
    const test_step = b.step("test", "Test mock service tracing and verification offline");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    const http_module = b.createModule(.{
        .root_source_file = b.path("collector_http.zig"),
        .target = target,
        .optimize = optimize,
    });
    const http_tool = b.addExecutable(.{
        .name = "collector-http-fixture",
        .root_module = http_module,
    });
    const interop_tools = b.step("interop-tools", "Build the explicit loopback HTTP test tool (does not run it)");
    interop_tools.dependOn(&b.addInstallArtifact(http_tool, .{}).step);
    interop_tools.dependOn(b.getInstallStep());
    const http_tests = b.addTest(.{ .root_module = http_module });
    test_step.dependOn(&b.addRunArtifact(http_tests).step);
}
