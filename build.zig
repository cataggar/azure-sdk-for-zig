const std = @import("std");

const package_version = @import("build.zig.zon").version;

pub const Linkage = enum { dynamic, static };

const supported_targets =
    "x86_64-linux-gnu, aarch64-linux-gnu, x86_64-windows-msvc, aarch64-windows-msvc";

pub fn build(b: *std.Build) void {
    const default_target: std.Target.Query = if (b.graph.host.result.os.tag == .windows)
        .{
            .cpu_arch = b.graph.host.result.cpu.arch,
            .os_tag = .windows,
            .abi = .msvc,
        }
    else
        .{};
    const target = b.standardTargetOptions(.{ .default_target = default_target });
    const optimize = b.standardOptimizeOption(.{});
    const target_can_run = b.option(
        bool,
        "target_can_run",
        "Allow target execution when the runner is native but Zig itself is emulated",
    ) orelse canRunOnHost(b, target);
    const source_only = b.option(
        bool,
        "source_only",
        "Run source/package checks without configuring native SymCrypt",
    ) orelse false;

    const source_check = addSourceCheck(b);
    const package = addPackageArchive(b);
    const package_check = b.step(
        "package-check",
        "Validate the exact manifest-filtered source package",
    );
    package_check.dependOn(&package.fetch.step);

    if (source_only) return;
    if (!isSupportedTarget(target)) {
        const triple = target.result.zigTriple(b.allocator) catch @panic("OOM");
        std.log.err(
            "unsupported azure_sdk_core_symcrypt target '{s}'; supported: {s}; macOS, musl, Windows GNU, WASI, and 32-bit native linkage are unavailable; use -Dsource_only=true for source/package validation",
            .{ triple, supported_targets },
        );
        b.invalid_user_input = true;
        return;
    }

    const linkage = b.option(
        Linkage,
        "linkage",
        "SymCrypt linkage mode (dynamic or static)",
    ) orelse .dynamic;
    const libraries = b.option(
        []const std.Build.LazyPath,
        "symcrypt_libraries",
        "Ordered exact SymCrypt library files; repeat for each file",
    ) orelse &.{};
    const include_dir = b.option(
        std.Build.LazyPath,
        "symcrypt_include_dir",
        "Complete pinned SymCrypt public header directory",
    );
    const system_include_dirs = b.option(
        []const std.Build.LazyPath,
        "symcrypt_system_include_dirs",
        "Ordered target SDK/CRT include directories for cross-toolchains",
    ) orelse &.{};
    const checked = b.option(
        bool,
        "symcrypt_checked",
        "Match checked/DBG SymCrypt headers and libraries",
    ) orelse false;
    const provenance = b.option(
        std.Build.LazyPath,
        "symcrypt_provenance",
        "Verified SymCrypt 103.13.0 fixture provenance manifest",
    );
    const headers_only = b.option(
        bool,
        "headers_only",
        "Compile adapter/header ABI only without native libraries",
    ) orelse false;

    if (!headers_only and libraries.len == 0) {
        std.log.err(
            "no SymCrypt libraries supplied: pass ordered repeated -Dsymcrypt_libraries exact files; use -Dheaders_only=true for supported-target header compilation or -Dsource_only=true for package checks",
            .{},
        );
        b.invalid_user_input = true;
        return;
    }

    const core_dep = b.dependency("azure_sdk_core", .{
        .target = target,
        .optimize = optimize,
    });
    const symcrypt_dep = b.dependency("zig_symcrypt", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .symcrypt_libraries = libraries,
        .symcrypt_include_dir = include_dir,
        .symcrypt_system_include_dirs = system_include_dirs,
        .symcrypt_checked = checked,
        .symcrypt_provenance = provenance,
        .legacy = true,
        .enable_legacy_rsa_pkcs1_encryption = false,
        .enable_mlkem = false,
        .enable_tls_x25519_mlkem768 = false,
        .headers_only = headers_only,
    });

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", package_version);
    build_options.addOption(bool, "symcrypt_checked", checked);
    const build_options_mod = build_options.createModule();

    const adapter_mod = b.addModule("azure_sdk_core_symcrypt", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "azure_sdk_core",
                .module = core_dep.module("azure_sdk_core"),
            },
            .{ .name = "symcrypt", .module = symcrypt_dep.module("symcrypt") },
            .{ .name = "build_options", .module = build_options_mod },
        },
    });

    const header_object = b.addObject(.{
        .name = "azure-sdk-core-symcrypt-header-check",
        .root_module = adapter_mod,
    });
    const headers_step = b.step(
        "headers-check",
        "Compile the adapter and pinned SymCrypt headers without execution",
    );
    headers_step.dependOn(&header_object.step);
    b.getInstallStep().dependOn(&header_object.step);

    if (headers_only) return;

    const test_mod = b.createModule(.{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{
                .name = "azure_sdk_core",
                .module = core_dep.module("azure_sdk_core"),
            },
            .{ .name = "symcrypt", .module = symcrypt_dep.module("symcrypt") },
            .{ .name = "build_options", .module = build_options_mod },
            .{
                .name = "azure_sdk_core_crypto_conformance",
                .module = core_dep.module("azure_sdk_core_crypto_conformance"),
            },
        },
    });
    addLinuxDynamicRPath(test_mod, target, linkage, libraries);
    const tests = b.addTest(.{ .root_module = test_mod });

    const test_compile_step = b.step(
        "test-compile",
        "Compile and link adapter tests without running them",
    );
    test_compile_step.dependOn(&tests.step);

    const provenance_command = addProvenanceVerification(
        b,
        symcrypt_dep,
        target,
        linkage,
        provenance,
        libraries,
    );
    const provenance_step = b.step(
        "provenance-check",
        "Verify exact SymCrypt 103.13.0 fixture provenance and libraries",
    );
    provenance_step.dependOn(provenance_command);

    const test_step = b.step("test", "Run Core conformance and adapter tests");
    if (target_can_run) {
        const run = runArtifactStep(
            b,
            symcrypt_dep,
            tests,
            target,
            linkage,
            provenance,
            libraries,
        );
        run.dependOn(provenance_command);
        test_step.dependOn(run);
    } else {
        const fail = b.addFail(b.fmt(
            "target {s} cannot execute on host {s}-{s}; use 'zig build test-compile' for build-only coverage",
            .{
                canonicalTargetTriple(b, target),
                @tagName(b.graph.host.result.cpu.arch),
                @tagName(b.graph.host.result.os.tag),
            },
        ));
        test_step.dependOn(&fail.step);
    }

    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "azure_sdk_core_symcrypt", .module = adapter_mod },
        },
    });
    addLinuxDynamicRPath(example_mod, target, linkage, libraries);
    const example = b.addExecutable(.{
        .name = "azure-sdk-core-symcrypt-example",
        .root_module = example_mod,
    });
    const example_step = b.step("example", "Build the selected-linkage example");
    example_step.dependOn(&example.step);
    const example_run_step = b.step(
        "example-run",
        "Run the selected-linkage example",
    );
    if (target_can_run) {
        const run = runArtifactStep(
            b,
            symcrypt_dep,
            example,
            target,
            linkage,
            provenance,
            libraries,
        );
        run.dependOn(provenance_command);
        example_run_step.dependOn(run);
    } else {
        const fail = b.addFail(
            "the selected target is build-only on this host; use 'zig build example'",
        );
        example_run_step.dependOn(&fail.step);
    }

    const package_consumer = addPackageConsumerBuild(
        b,
        package,
        target,
        optimize,
        linkage,
        libraries,
        include_dir,
        system_include_dirs,
        checked,
        provenance,
    );
    const package_consumer_step = b.step(
        "package-consumer-check",
        "Compile a consumer of the manifest-filtered package archive",
    );
    package_consumer_step.dependOn(&package_consumer.step);
    package_consumer_step.dependOn(source_check);
}

fn addSourceCheck(b: *std.Build) *std.Build.Step {
    const format = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "fmt",
        "--check",
        "build.zig",
        "build.zig.zon",
        "root.zig",
        "examples",
        "conformance",
    });
    const step = b.step("source-check", "Check all package Zig source formatting");
    step.dependOn(&format.step);
    return step;
}

const PackageArchive = struct {
    archive: std.Build.LazyPath,
    consumer_dir: std.Build.LazyPath,
    fetch: *std.Build.Step.Run,
};

fn addPackageArchive(b: *std.Build) PackageArchive {
    const archive_command = b.addSystemCommand(&.{
        "python3",
        "-c",
        \\import pathlib, sys, tarfile
        \\output = pathlib.Path(sys.argv[1])
        \\root = pathlib.Path(sys.argv[2])
        \\with tarfile.open(output, "w:gz") as archive:
        \\    for name in sys.argv[3:]:
        \\        archive.add(root / name, arcname=name, recursive=True)
    });
    archive_command.has_side_effects = true;
    const archive = archive_command.addOutputFileArg(
        "azure_sdk_core_symcrypt-manifest-filtered.tar.gz",
    );
    archive_command.addArg(b.pathFromRoot("."));
    inline for (@import("build.zig.zon").paths) |included_path| {
        archive_command.addArg(included_path);
    }

    const files = b.addWriteFiles();
    _ = files.addCopyFile(
        b.path("conformance/package_consumer/build.zig"),
        "build.zig",
    );
    _ = files.addCopyFile(
        b.path("conformance/package_consumer/build.zig.zon"),
        "build.zig.zon",
    );
    _ = files.addCopyFile(
        b.path("conformance/package_consumer/consumer.zig"),
        "consumer.zig",
    );
    const consumer_dir = files.getDirectory();

    const fetch = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "fetch",
        "--save=adapter",
    });
    fetch.setCwd(consumer_dir);
    fetch.addFileArg(archive);
    return .{
        .archive = archive,
        .consumer_dir = consumer_dir,
        .fetch = fetch,
    };
}

fn addPackageConsumerBuild(
    b: *std.Build,
    package: PackageArchive,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: Linkage,
    libraries: []const std.Build.LazyPath,
    include_dir: ?std.Build.LazyPath,
    system_include_dirs: []const std.Build.LazyPath,
    checked: bool,
    provenance: ?std.Build.LazyPath,
) *std.Build.Step.Run {
    const command = b.addSystemCommand(&.{
        b.graph.zig_exe,
        "build",
        "test-compile",
        "--summary",
        "all",
        b.fmt("-Dtarget={s}", .{canonicalTargetTriple(b, target)}),
        b.fmt("-Doptimize={s}", .{@tagName(optimize)}),
        b.fmt("-Dlinkage={s}", .{@tagName(linkage)}),
        b.fmt("-Dsymcrypt_checked={s}", .{if (checked) "true" else "false"}),
    });
    command.setCwd(package.consumer_dir);
    command.step.dependOn(&package.fetch.step);
    for (libraries) |library| {
        command.addPrefixedFileArg("-Dsymcrypt_libraries=", library);
    }
    if (include_dir) |directory| {
        command.addPrefixedDirectoryArg("-Dsymcrypt_include_dir=", directory);
    }
    for (system_include_dirs) |directory| {
        command.addPrefixedDirectoryArg(
            "-Dsymcrypt_system_include_dirs=",
            directory,
        );
    }
    if (provenance) |manifest| {
        command.addPrefixedFileArg("-Dsymcrypt_provenance=", manifest);
    }
    return command;
}

fn addProvenanceVerification(
    b: *std.Build,
    symcrypt_dep: *std.Build.Dependency,
    target: std.Build.ResolvedTarget,
    linkage: Linkage,
    provenance: ?std.Build.LazyPath,
    libraries: []const std.Build.LazyPath,
) *std.Build.Step {
    const manifest = provenance orelse {
        const fail = b.addFail(
            "provenance-check and native execution require -Dsymcrypt_provenance=/exact/path/provenance.json",
        );
        return &fail.step;
    };
    const command = b.addSystemCommand(&.{"python3"});
    command.addFileArg(symcrypt_dep.path("tools/fixture_manifest.py"));
    command.addArgs(&.{
        "verify",
        "--manifest",
    });
    command.addFileArg(manifest);
    command.addArgs(&.{
        "--target",
        canonicalTargetTriple(b, target),
        "--linkage",
        @tagName(linkage),
    });
    for (libraries) |library| {
        command.addArg("--library");
        command.addFileArg(library);
    }
    return &command.step;
}

fn runArtifactStep(
    b: *std.Build,
    symcrypt_dep: *std.Build.Dependency,
    artifact: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    linkage: Linkage,
    provenance: ?std.Build.LazyPath,
    libraries: []const std.Build.LazyPath,
) *std.Build.Step {
    if (target.result.os.tag != .windows or linkage != .dynamic) {
        return &b.addRunArtifact(artifact).step;
    }
    const manifest = provenance orelse {
        const fail = b.addFail(
            "dynamic Windows execution requires -Dsymcrypt_provenance so the exact runtime DLL is verified and staged beside the executable",
        );
        return &fail.step;
    };
    const command = b.addSystemCommand(&.{"python3"});
    command.addFileArg(symcrypt_dep.path("tools/run_verified.py"));
    command.addArgs(&.{
        "--manifest",
    });
    command.addFileArg(manifest);
    command.addArgs(&.{
        "--target",
        canonicalTargetTriple(b, target),
    });
    for (libraries) |library| {
        command.addArg("--library");
        command.addFileArg(library);
    }
    command.addArtifactArg(artifact);
    return &command.step;
}

fn addLinuxDynamicRPath(
    module: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    linkage: Linkage,
    libraries: []const std.Build.LazyPath,
) void {
    if (target.result.os.tag == .linux and linkage == .dynamic) {
        module.addRPath(libraries[libraries.len - 1].dirname());
    }
}

fn isSupportedTarget(target: std.Build.ResolvedTarget) bool {
    const value = target.result;
    const arch_ok = value.cpu.arch == .x86_64 or value.cpu.arch == .aarch64;
    const linux_ok = value.os.tag == .linux and value.abi == .gnu;
    const windows_ok = value.os.tag == .windows and value.abi == .msvc;
    return arch_ok and (linux_ok or windows_ok);
}

fn canRunOnHost(b: *std.Build, target: std.Build.ResolvedTarget) bool {
    return target.result.cpu.arch == b.graph.host.result.cpu.arch and
        target.result.os.tag == b.graph.host.result.os.tag;
}

fn canonicalTargetTriple(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
) []const u8 {
    return b.fmt(
        "{s}-{s}-{s}",
        .{
            @tagName(target.result.cpu.arch),
            @tagName(target.result.os.tag),
            @tagName(target.result.abi),
        },
    );
}
