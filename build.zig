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
    const test_filter = b.option([]const u8, "test-filter", "Run matching adapter tests");
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
        .filters = if (test_filter) |filter| &.{filter} else &.{},
    });
    b.default_step.dependOn(&tests.step);
    const test_step = b.step("test", "Run offline adapter and published Core transport conformance");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    if (b.option(bool, "paired-tls", "Enable qualification requiring the canonical paired TLS API") orelse false) {
        const certificates = b.createModule(.{
            .root_source_file = httpx.path("src/tls/trust_fixtures.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        });
        // Generate bytes in a separate std-only executable. Importing HTTPX's
        // private fixture file into another test module violates Zig ownership.
        const generator = b.addExecutable(.{
            .name = "azure-httpx-test-certificates",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tls_fixture_data.zig"),
                .target = b.graph.host,
                .optimize = optimize,
                .imports = &.{.{ .name = "httpx_test_certificates", .module = certificates }},
            }),
        });
        const generated = b.addRunArtifact(generator).addOutputDirectoryArg("certificates");
        const fixture_data = b.createModule(.{
            .root_source_file = generated.path(b, "fixtures.zig"),
            .target = target,
            .optimize = optimize,
        });
        const paired_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tls_qualification.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "azure_sdk_core_httpx", .module = adapter },
                    .{ .name = "httpx", .module = httpx_module },
                    .{ .name = "tls_fixture_data", .module = fixture_data },
                    .{ .name = "azure_sdk_core_http_conformance", .module = core.module("azure_sdk_core_http_conformance") },
                },
            }),
            .filters = if (test_filter) |filter| &.{filter} else &.{},
        });
        b.default_step.dependOn(&paired_tests.step);
        test_step.dependOn(&b.addRunArtifact(paired_tests).step);
        const paired_step = b.step("paired-tls-test", "Run hermetic standard-provider TLS qualification through the SDK");
        paired_step.dependOn(&b.addRunArtifact(paired_tests).step);
        const probe = b.addExecutable(.{
            .name = "azure-httpx-public-https",
            .root_module = b.createModule(.{
                .root_source_file = b.path("public_https.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "azure_sdk_core_httpx", .module = adapter }},
            }),
        });
        const run_probe = b.addRunArtifact(probe);
        if (b.args) |args| run_probe.addArgs(args);
        const public_step = b.step("qualify-public-https", "Opt-in unauthenticated Azure HTTPS with canonical system trust");
        public_step.dependOn(&run_probe.step);
    }
}
