const std = @import("std");
const builtin = @import("builtin");

/// Single source of truth for the package version: the manifest.
const package_version = @import("build.zig.zon").version;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const serde_dep = b.dependency("serde", .{
        .target = target,
        .optimize = optimize,
    });
    const serde_mod = serde_dep.module("serde");

    const options = b.addOptions();
    options.addOption([]const u8, "version", package_version);
    const options_mod = options.createModule();

    const core_mod = b.addModule("azure_sdk_core", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "serde", .module = serde_mod },
            .{ .name = "build_options", .module = options_mod },
        },
    });

    const conformance_fakes_mod = b.createModule(.{
        .root_source_file = b.path("conformance/fakes.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
        },
    });
    const http_conformance_mod = b.addModule("azure_sdk_core_http_conformance", .{
        .root_source_file = b.path("conformance/http_transport.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{
                .name = "azure_sdk_core_conformance_fakes",
                .module = conformance_fakes_mod,
            },
        },
    });
    const crypto_conformance_mod = b.addModule("azure_sdk_core_crypto_conformance", .{
        .root_source_file = b.path("conformance/crypto_provider.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core", .module = core_mod },
            .{
                .name = "azure_sdk_core_conformance_fakes",
                .module = conformance_fakes_mod,
            },
        },
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("root.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "serde", .module = serde_mod },
                .{ .name = "build_options", .module = options_mod },
            },
        }),
    });
    const http_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("conformance/http_transport.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{
                    .name = "azure_sdk_core_conformance_fakes",
                    .module = conformance_fakes_mod,
                },
            },
        }),
    });
    const crypto_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("conformance/crypto_provider.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{
                    .name = "azure_sdk_core_conformance_fakes",
                    .module = conformance_fakes_mod,
                },
            },
        }),
    });
    const wasi_adapter_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("wasi_adapter_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const consumer_check = b.addObject(.{
        .name = "core-conformance-consumer-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("conformance/consumer.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = core_mod },
                .{
                    .name = "azure_sdk_core_http_conformance",
                    .module = http_conformance_mod,
                },
                .{
                    .name = "azure_sdk_core_crypto_conformance",
                    .module = crypto_conformance_mod,
                },
            },
        }),
    });

    const package_archive = b.addSystemCommand(&.{"tar"});
    if (builtin.target.os.tag == .windows) {
        package_archive.addArg("--force-local");
    }
    package_archive.addArg("-czf");
    package_archive.has_side_effects = true;
    const archive = package_archive.addOutputFileArg(
        "azure_sdk_core-manifest-filtered.tar.gz",
    );
    package_archive.addArg("-C");
    package_archive.addArg(b.pathFromRoot("."));
    inline for (@import("build.zig.zon").paths) |included_path| {
        package_archive.addArg(included_path);
    }

    const package_consumer_files = b.addWriteFiles();
    _ = package_consumer_files.addCopyFile(
        b.path("conformance/package_consumer/build.zig"),
        "build.zig",
    );
    _ = package_consumer_files.addCopyFile(
        b.path("conformance/package_consumer/build.zig.zon"),
        "build.zig.zon",
    );
    _ = package_consumer_files.addCopyFile(
        b.path("conformance/package_consumer/consumer.zig"),
        "consumer.zig",
    );
    const package_consumer_dir = package_consumer_files.getDirectory();

    const package_fetch = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "fetch",
        "--save=core",
    });
    package_fetch.setCwd(package_consumer_dir);
    package_fetch.addFileArg(archive);

    const package_consumer_test = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "build",
        "test",
        "--summary",
        "all",
    });
    package_consumer_test.setCwd(package_consumer_dir);
    package_consumer_test.step.dependOn(&package_fetch.step);

    const wasi_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .wasi,
    });
    const wasi_serde_dep = b.dependency("serde", .{
        .target = wasi_target,
        .optimize = optimize,
    });
    const wasi_core_mod = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = wasi_target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "serde", .module = wasi_serde_dep.module("serde") },
            .{ .name = "build_options", .module = options_mod },
        },
    });
    const wasi_check = b.addObject(.{
        .name = "core-wasi-build-check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("conformance/wasi_build_check.zig"),
            .target = wasi_target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "azure_sdk_core", .module = wasi_core_mod },
            },
        }),
    });

    const test_step = b.step("test", "Run Core tests");
    test_step.dependOn(&b.addRunArtifact(tests).step);
    test_step.dependOn(&b.addRunArtifact(http_conformance_tests).step);
    test_step.dependOn(&b.addRunArtifact(crypto_conformance_tests).step);
    test_step.dependOn(&b.addRunArtifact(wasi_adapter_tests).step);
    test_step.dependOn(&consumer_check.step);
    test_step.dependOn(&package_consumer_test.step);
    test_step.dependOn(&wasi_check.step);

    const conformance_consumer_step = b.step(
        "conformance-consumer-check",
        "Compile a consumer of the exported conformance modules",
    );
    conformance_consumer_step.dependOn(&consumer_check.step);

    const package_consumer_step = b.step(
        "package-consumer-check",
        "Test conformance modules from the manifest-filtered package archive",
    );
    package_consumer_step.dependOn(&package_consumer_test.step);

    const wasi_step = b.step(
        "wasi-check",
        "Build-check the Core WASI HTTP transport (no runtime coverage)",
    );
    wasi_step.dependOn(&wasi_check.step);
}
