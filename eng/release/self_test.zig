//! Offline regression coverage for the package release engine.
//! Port of eng/release/self_test.py.

const std = @import("std");
const engine = @import("engine.zig");

const Io = std.Io;
const Dir = std.Io.Dir;
const Allocator = std.mem.Allocator;
const Environ = std.process.Environ;
const Engine = engine.Engine;

pub const SelfTestError = error{SelfTest};

const TRACING = "azure_sdk_core_tracing";
const CORE = "azure_sdk_core";
const ARM = "azure_rest_arm_avs";
const SENTINEL = "AZURE_RELEASE_SELF_TEST_SENTINEL";
const PUBLICATION = "publication";

const max_read: std.Io.Limit = .limited(64 * 1024 * 1024);

fn fingerprintFor(name: []const u8) []const u8 {
    if (std.mem.eql(u8, name, TRACING)) return "0xe8429db77ded14e7";
    if (std.mem.eql(u8, name, CORE)) return "0x0fdf522a4b433c07";
    if (std.mem.eql(u8, name, ARM)) return "0xa125d6afd751e975";
    return "0xfdf7c70ce6c5b4b4";
}

const Dependency = struct { name: []const u8, path: []const u8 };

const Ctx = struct {
    gpa: Allocator,
    io: Io,
    env: *Environ.Map,
    test_root: []const u8,
    source: []const u8,
    remote: []const u8,
    other_remote: []const u8,
    release_root: []const u8,

    fn cat(self: *Ctx, parts: []const []const u8) ![]u8 {
        return std.mem.concat(self.gpa, u8, parts);
    }

    fn joinp(self: *Ctx, parts: []const []const u8) ![]const u8 {
        return std.fs.path.join(self.gpa, parts);
    }

    fn print(self: *Ctx, comptime fmt: []const u8, args: anytype) !void {
        var buffer: [4096]u8 = undefined;
        var file = std.Io.File.stdout();
        var writer = file.writer(self.io, &buffer);
        try writer.interface.print(fmt, args);
        try writer.interface.flush();
    }

    fn git(self: *Ctx, dir: []const u8, args: []const []const u8) ![]const u8 {
        return engine.gitOut(self.gpa, self.io, dir, args);
    }

    fn writeFile(self: *Ctx, path: []const u8, data: []const u8) !void {
        if (std.fs.path.dirname(path)) |parent| {
            Dir.cwd().createDirPath(self.io, parent) catch return error.SelfTest;
        }
        Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = data }) catch return error.SelfTest;
    }

    fn readFile(self: *Ctx, path: []const u8) ![]const u8 {
        return Dir.cwd().readFileAlloc(self.io, path, self.gpa, max_read) catch return error.SelfTest;
    }

    fn pathExists(self: *Ctx, path: []const u8) bool {
        _ = Dir.cwd().statFile(self.io, path, .{ .follow_symlinks = false }) catch return false;
        return true;
    }

    fn chmodExec(self: *Ctx, path: []const u8) !void {
        Dir.cwd().setFilePermissions(self.io, path, .fromMode(0o755), .{}) catch return error.SelfTest;
    }

    fn replaceOnce(self: *Ctx, text: []const u8, needle: []const u8, replacement: []const u8) ![]const u8 {
        return std.mem.replaceOwned(u8, self.gpa, text, needle, replacement);
    }

    fn newEngine(self: *Ctx, race: bool) !Engine {
        var e = try Engine.init(self.gpa, self.io, self.source, PUBLICATION, self.release_root, self.env);
        e.race_delete_branch = race;
        return e;
    }

    fn resolveOr(self: *Ctx, path: []const u8) []const u8 {
        return Dir.cwd().realPathFileAlloc(self.io, path, self.gpa) catch
            (std.fs.path.resolve(self.gpa, &.{path}) catch path);
    }

    fn fail2(self: *Ctx, comptime detail: []const u8) SelfTestError {
        self.print("self-test: " ++ detail ++ "\n", .{}) catch {};
        return error.SelfTest;
    }

    fn step(self: *Ctx, e: *Engine, result: anyerror!void, label: []const u8) !void {
        result catch |err| {
            try self.print("self-test step failed: {s}: {s}\n", .{ label, e.message orelse @errorName(err) });
            return err;
        };
    }

    fn engineErr(self: *Ctx, e: *Engine, label: []const u8, err: anyerror) anyerror {
        self.print("self-test step failed: {s}: {s}\n", .{ label, e.message orelse @errorName(err) }) catch {};
        return err;
    }

    fn unlink(self: *Ctx, path: []const u8) void {
        Dir.cwd().deleteFile(self.io, path) catch {};
    }

    fn countTokens(self: *Ctx, text: []const u8) usize {
        _ = self;
        var it = std.mem.tokenizeAny(u8, text, " \t\r\n");
        var count: usize = 0;
        while (it.next()) |_| count += 1;
        return count;
    }

    fn dropLinesPrefixed(self: *Ctx, text: []const u8, prefix: []const u8) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        var lines = std.mem.splitScalar(u8, text, '\n');
        var pieces: std.ArrayList([]const u8) = .empty;
        while (lines.next()) |line| try pieces.append(self.gpa, line);
        if (pieces.items.len != 0 and pieces.items[pieces.items.len - 1].len == 0)
            _ = pieces.pop();
        for (pieces.items) |line| {
            if (std.mem.startsWith(u8, std.mem.trim(u8, line, " \t\r"), prefix)) continue;
            try out.appendSlice(self.gpa, line);
            try out.append(self.gpa, '\n');
        }
        return out.items;
    }

    fn expectFailure(
        self: *Ctx,
        label: []const u8,
        result: anytype,
        message: ?[]const u8,
        expected: ?[]const u8,
    ) !void {
        if (result) |_| {
            try self.print("self-test expected failure was accepted: {s}\n", .{label});
            return error.SelfTest;
        } else |err| {
            if (err != error.Release) {
                try self.print("self-test {s} returned unexpected error: {s}\n", .{ label, @errorName(err) });
                return err;
            }
            if (expected) |exp| {
                const msg = message orelse "";
                if (std.mem.indexOf(u8, msg, exp) == null) {
                    try self.print("self-test {s} returned unexpected message: {s}\n", .{ label, msg });
                    return error.SelfTest;
                }
            }
        }
    }

    fn writeRegistry(self: *Ctx) !void {
        try self.writeFile(try self.joinp(&.{ self.source, ".gitignore" }), ".release/\n");
        const path = try self.joinp(&.{ self.source, "eng", "packages.zig" });
        const content = try self.cat(&.{
            "const Package = struct {};\n",
            "pub const all = [_]Package{\n",
            "    .{\n",
            "        .ownership = .main_owned,\n",
            "        .workspace_path = \"sdk/core/tracing\",\n",
            "        .historical_source_path = \"sdk/core/tracing\",\n",
            "        .name = \"",
            TRACING,
            "\",\n",
            "        .branch = \"sdk/core_tracing\",\n",
            "        .publish_paths = &.{\n",
            "            \".gitignore\",\n",
            "            \"build.zig\",\n",
            "            \"build.zig.zon\",\n",
            "            \"root.zig\",\n",
            "            \"README.md\",\n",
            "            \"LICENSE.txt\",\n",
            "        },\n",
            "        .test_command = \"zig build test --summary all\",\n",
            "    },\n",
            "    .{\n",
            "        .ownership = .main_owned,\n",
            "        .workspace_path = \"sdk/core\",\n",
            "        .historical_source_path = \"sdk/core\",\n",
            "        .name = \"",
            CORE,
            "\",\n",
            "        .branch = \"sdk/core\",\n",
            "        .dependencies = &.{\"",
            TRACING,
            "\"},\n",
            "        .publish_paths = &.{\n",
            "            \".gitignore\",\n",
            "            \"build.zig\",\n",
            "            \"build.zig.zon\",\n",
            "            \"root.zig\",\n",
            "            \"README.md\",\n",
            "            \"LICENSE.txt\",\n",
            "        },\n",
            "        .test_command = \"zig build test --summary all\",\n",
            "    },\n",
            "    .{\n",
            "        .ownership = .branch_owned,\n",
            "        .historical_source_path = \"rest/arm_avs\",\n",
            "        .name = \"",
            ARM,
            "\",\n",
            "        .branch = \"rest/arm_avs\",\n",
            "        .historical_names = &.{\"arm_avs\"},\n",
            "        .publish_paths = &.{\n",
            "            \".gitignore\",\n",
            "            \"build.zig\",\n",
            "            \"build.zig.zon\",\n",
            "            \"root.zig\",\n",
            "            \"README.md\",\n",
            "            \"LICENSE.txt\",\n",
            "        },\n",
            "        .test_command = \"zig build test --summary all\",\n",
            "    },\n",
            "};\n",
        });
        try self.writeFile(path, content);
    }

    fn writePackage(
        self: *Ctx,
        source_path: []const u8,
        name: []const u8,
        version: []const u8,
        dependencies: []const Dependency,
    ) !void {
        const package = try self.joinp(&.{ self.source, source_path });
        Dir.cwd().createDirPath(self.io, package) catch return error.SelfTest;
        try self.writeFile(try self.joinp(&.{ package, ".gitignore" }), ".zig-cache/\nzig-out/\nzig-pkg/\n");
        try self.writeFile(try self.joinp(&.{ package, "LICENSE.txt" }), "fixture license\n");
        try self.writeFile(try self.joinp(&.{ package, "README.md" }), try self.cat(&.{ "# ", name, " ", version, "\n" }));

        var imports: std.ArrayList(u8) = .empty;
        var test_body: std.ArrayList(u8) = .empty;
        for (dependencies) |dep| {
            try imports.appendSlice(self.gpa, try self.cat(&.{ "const ", dep.name, " = @import(\"", dep.name, "\");\n" }));
            if (test_body.items.len != 0) try test_body.append(self.gpa, '\n');
            try test_body.appendSlice(self.gpa, try self.cat(&.{ "    try std.testing.expect(", dep.name, ".release_fixture);" }));
        }
        if (test_body.items.len == 0) {
            try test_body.appendSlice(self.gpa, "    try std.testing.expect(release_fixture);");
        }
        const root_zig = try self.cat(&.{
            "const std = @import(\"std\");\n",
            imports.items,
            "\npub const release_fixture = true;\n",
            "\ntest \"release fixture\" {\n",
            "    var env = try std.process.Environ.createMap(\n",
            "        std.testing.environ,\n",
            "        std.testing.allocator,\n",
            "    );\n",
            "    defer env.deinit();\n",
            "    try std.testing.expect(\n",
            "        env.get(\"",
            SENTINEL,
            "\") == null,\n",
            "    );\n",
            test_body.items,
            "\n}\n",
        });
        try self.writeFile(try self.joinp(&.{ package, "root.zig" }), root_zig);

        var dependency_build: std.ArrayList(u8) = .empty;
        for (dependencies) |dep| {
            try dependency_build.appendSlice(self.gpa, try self.cat(&.{
                "\n    const ",                dep.name,                          "_dependency = b.dependency(\"", dep.name,                       "\", .{\n",
                "        .target = target,\n", "        .optimize = optimize,\n", "    });\n",                     "    test_module.addImport(\n", "        \"",
                dep.name,                      "\",\n",                           "        ",                      dep.name,                       "_dependency.module(\"",
                dep.name,                      "\"),\n",                          "    );\n",
            }));
        }
        const build_zig = try self.cat(&.{
            "const std = @import(\"std\");\n",
            "pub fn build(b: *std.Build) void {\n",
            "    const target = b.standardTargetOptions(.{});\n",
            "    const optimize = b.standardOptimizeOption(.{});\n",
            "    _ = b.addModule(\"",
            name,
            "\", .{\n",
            "        .root_source_file = b.path(\"root.zig\"),\n",
            "    });\n",
            "    const test_module = b.createModule(.{\n",
            "        .root_source_file = b.path(\"root.zig\"),\n",
            "        .target = target,\n",
            "        .optimize = optimize,\n",
            "    });\n",
            dependency_build.items,
            "    const tests = b.addTest(.{ .root_module = test_module });\n",
            "    const test_step = b.step(\"test\", \"fixture test\");\n",
            "    test_step.dependOn(&b.addRunArtifact(tests).step);\n",
            "}\n",
        });
        try self.writeFile(try self.joinp(&.{ package, "build.zig" }), build_zig);

        var dependency_text: std.ArrayList(u8) = .empty;
        for (dependencies) |dep| {
            try dependency_text.appendSlice(self.gpa, try self.cat(&.{
                "        .",              dep.name, " = .{\n",
                "            .path = \"", dep.path, "\",\n",
                "        },\n",
            }));
        }
        const zon_content = try self.cat(&.{
            ".{\n",
            "    .name = .",
            name,
            ",\n",
            "    .version = \"",
            version,
            "\",\n",
            "    .fingerprint = ",
            fingerprintFor(name),
            ",\n",
            "    .minimum_zig_version = \"0.16.0\",\n",
            "    .dependencies = .{\n",
            dependency_text.items,
            "    },\n",
            "    .paths = .{\n",
            "        \".gitignore\",\n",
            "        \"build.zig\",\n",
            "        \"build.zig.zon\",\n",
            "        \"root.zig\",\n",
            "        \"README.md\",\n",
            "        \"LICENSE.txt\",\n",
            "    },\n",
            "}\n",
        });
        try self.writeFile(try self.joinp(&.{ package, "build.zig.zon" }), zon_content);
    }

    fn commitAll(self: *Ctx, message: []const u8) ![]const u8 {
        _ = try self.git(self.source, &.{ "add", "--all" });
        _ = try self.git(self.source, &.{ "commit", "--quiet", "-m", message });
        return self.git(self.source, &.{ "rev-parse", "HEAD" });
    }

    fn pushMain(self: *Ctx) !void {
        _ = try self.git(self.source, &.{ "push", "--quiet", PUBLICATION, "main:refs/heads/main" });
    }

    fn updateVersions(self: *Ctx, tracing_version: []const u8, core_version: []const u8) !void {
        try self.writeRegistry();
        try self.writePackage("sdk/core/tracing", TRACING, tracing_version, &.{});
        try self.writePackage("sdk/core", CORE, core_version, &.{.{ .name = TRACING, .path = "tracing" }});
        try self.writePackage("rest/arm_avs", ARM, "0.1.0", &.{});
    }

    fn assertCleanup(self: *Ctx, e: *Engine) !void {
        const worktrees = try self.git(e.root, &.{ "worktree", "list", "--porcelain" });
        const release_root = self.resolveOr(e.release_root);
        const release_prefix = try self.cat(&.{ release_root, "/" });
        var lines = std.mem.splitScalar(u8, worktrees, '\n');
        while (lines.next()) |line| {
            if (!std.mem.startsWith(u8, line, "worktree ")) continue;
            const wt = self.resolveOr(line["worktree ".len..]);
            if (std.mem.eql(u8, wt, release_root) or std.mem.startsWith(u8, wt, release_prefix)) {
                try self.print("self-test: disposable worktree was not removed: {s}\n", .{wt});
                return error.SelfTest;
            }
        }
        const branches = try self.git(e.root, &.{ "branch", "--list", "package-release-*" });
        if (branches.len != 0) {
            try self.print("self-test: temporary publication branch was not removed\n", .{});
            return error.SelfTest;
        }
        if (self.pathExists(e.release_root)) {
            var dir = Dir.cwd().openDir(self.io, e.release_root, .{ .iterate = true }) catch return error.SelfTest;
            defer dir.close(self.io);
            var walker = dir.walk(self.gpa) catch return error.SelfTest;
            defer walker.deinit();
            while (walker.next(self.io) catch return error.SelfTest) |entry| {
                if (std.mem.indexOfScalar(u8, entry.path, '/') != null) continue;
                const work = try self.joinp(&.{ e.release_root, entry.path, "work" });
                if (self.pathExists(work)) {
                    try self.print("self-test: work directory was not removed: {s}\n", .{work});
                    return error.SelfTest;
                }
            }
        }
    }

    fn assertNoSourceArtifacts(self: *Ctx) !void {
        var dir = Dir.cwd().openDir(self.io, self.source, .{ .iterate = true }) catch return error.SelfTest;
        defer dir.close(self.io);
        var walker = dir.walk(self.gpa) catch return error.SelfTest;
        defer walker.deinit();
        while (walker.next(self.io) catch return error.SelfTest) |entry| {
            const base = std.fs.path.basename(entry.path);
            if (std.mem.eql(u8, base, ".zig-cache") or std.mem.eql(u8, base, "zig-cache") or
                std.mem.eql(u8, base, "zig-out") or std.mem.eql(u8, base, "zig-pkg"))
            {
                try self.print("self-test: package commands mutated source checkout: {s}\n", .{entry.path});
                return error.SelfTest;
            }
        }
    }
};

fn optEq(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

pub fn runSelfTest(gpa: Allocator, io: Io, env: *Environ.Map, repository_root: []const u8) !void {
    const test_root = try std.fs.path.join(gpa, &.{ repository_root, ".release", "package-release-self-test" });
    const source = try std.fs.path.join(gpa, &.{ test_root, "source" });
    const remote = try std.fs.path.join(gpa, &.{ test_root, "remote.git" });
    const other_remote = try std.fs.path.join(gpa, &.{ test_root, "other-remote.git" });
    const release_root = try std.fs.path.join(gpa, &.{ source, ".release", "packages" });

    var ctx = Ctx{
        .gpa = gpa,
        .io = io,
        .env = env,
        .test_root = test_root,
        .source = source,
        .remote = remote,
        .other_remote = other_remote,
        .release_root = release_root,
    };
    const self = &ctx;

    if (self.pathExists(test_root)) Dir.cwd().deleteTree(io, test_root) catch return error.SelfTest;
    Dir.cwd().createDirPath(io, source) catch return error.SelfTest;

    defer {
        _ = self.git(source, &.{ "worktree", "prune" }) catch {};
        Dir.cwd().deleteTree(io, test_root) catch {};
    }

    _ = try self.git(source, &.{ "init", "--quiet" });
    _ = try self.git(source, &.{ "config", "user.name", "Release self-test" });
    _ = try self.git(source, &.{ "config", "user.email", "release-self-test@example.invalid" });
    _ = try self.git(source, &.{ "branch", "-M", "main" });
    _ = try self.git(test_root, &.{ "init", "--quiet", "--bare", remote });
    _ = try self.git(test_root, &.{ "init", "--quiet", "--bare", other_remote });
    _ = try self.git(source, &.{ "remote", "add", PUBLICATION, remote });

    try env.put(SENTINEL, "must-not-reach-package-commands");

    try self.updateVersions("0.1.0", "0.1.0");
    const initial_source = try self.commitAll("initial source");
    try self.pushMain();

    try self.writeFile(try self.joinp(&.{ source, "local-only.txt" }), "unpushed\n");
    _ = try self.commitAll("unpushed local main");
    const tree = try self.git(source, &.{ "rev-parse", try self.cat(&.{ initial_source, "^{tree}" }) });
    const remote_main = try self.git(source, &.{ "commit-tree", tree, "-p", initial_source, "-m", "remote main divergence" });
    _ = try self.git(source, &.{ "push", "--quiet", PUBLICATION, try self.cat(&.{ remote_main, ":refs/heads/main" }) });

    var e = try self.newEngine(false);
    {
        const r = e.verify(TRACING, true);
        try self.expectFailure("unpushed/diverged local main", r, e.message, "source HEAD does not match publication remote refs/heads/main");
    }
    _ = try self.git(source, &.{ "reset", "--quiet", "--hard", remote_main });

    _ = try self.git(source, &.{ "remote", "set-url", "--push", PUBLICATION, other_remote });
    {
        const r = e.verify(TRACING, true);
        try self.expectFailure("mismatched remote push repository", r, e.message, "publication remote fetch/push repository mismatch");
    }
    _ = try self.git(source, &.{ "remote", "set-url", "--push", PUBLICATION, remote });

    _ = try self.git(source, &.{ "remote", "set-url", "--add", "--push", PUBLICATION, other_remote });
    {
        const r = e.prepare(TRACING, true);
        try self.expectFailure("multiple remote push URLs", r, e.message, "publication remote must have exactly one push URL; found 2");
    }
    if ((try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core_tracing", source)) != null)
        return self.fail2("multiple push URLs published a branch");
    if ((try engine.remoteTagCommit(gpa, io, remote, try self.cat(&.{ TRACING, "/v0.1.0" }), source)) != null)
        return self.fail2("multiple push URLs published a tag");
    _ = try self.git(source, &.{ "config", "--unset-all", try self.cat(&.{ "remote.", PUBLICATION, ".pushurl" }) });
    _ = try self.git(source, &.{ "config", "--add", try self.cat(&.{ "remote.", PUBLICATION, ".pushurl" }), remote });

    const credential_url = "ssh://octocat:s3cr3t-token@example.invalid/repo.git";
    _ = try self.git(source, &.{ "remote", "set-url", PUBLICATION, credential_url });
    _ = try self.git(source, &.{ "remote", "set-url", "--push", PUBLICATION, credential_url });
    {
        const r = e.verify(TRACING, true);
        try self.expectFailure("password-bearing SSH remote", r, e.message, "remote URL must not contain an embedded password");
    }
    _ = try self.git(source, &.{ "remote", "set-url", PUBLICATION, remote });
    _ = try self.git(source, &.{ "remote", "set-url", "--push", PUBLICATION, remote });

    _ = try self.git(source, &.{ "config", "--add", "url.rewrite-one:.insteadOf", "release-alias:" });
    _ = try self.git(source, &.{ "config", "--add", "url.https://rewrite-two.invalid/.insteadOf", "rewrite-one:" });
    _ = try self.git(source, &.{ "remote", "set-url", PUBLICATION, "release-alias:repository" });
    {
        const r = e.prepare(TRACING, true);
        try self.expectFailure("chained Git URL rewrites", r, e.message, "effective Git URL rewrite configuration is not allowed");
    }
    if ((try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core_tracing", source)) != null)
        return self.fail2("URL rewrites published a branch");
    _ = try self.git(source, &.{ "remote", "set-url", PUBLICATION, remote });
    _ = try self.git(source, &.{ "config", "--unset-all", "url.rewrite-one:.insteadOf" });
    _ = try self.git(source, &.{ "config", "--unset-all", "url.https://rewrite-two.invalid/.insteadOf" });

    _ = try self.git(source, &.{ "switch", "--quiet", "-c", "feature-release" });
    {
        const r = e.verify(TRACING, true);
        try self.expectFailure("feature branch source provenance", r, e.message, "source branch must be main; found feature-release");
    }
    _ = try self.git(source, &.{ "switch", "--quiet", "main" });

    const hooks_dir = try self.joinp(&.{ source, ".git", "hooks" });
    const hook_marker = try self.joinp(&.{ source, ".git", "release-hook-ran" });
    const pre_commit = try self.joinp(&.{ hooks_dir, "pre-commit" });
    const post_commit = try self.joinp(&.{ hooks_dir, "post-commit" });
    const post_checkout = try self.joinp(&.{ hooks_dir, "post-checkout" });
    const pre_push = try self.joinp(&.{ hooks_dir, "pre-push" });
    try self.writeFile(pre_commit, try self.cat(&.{
        "#!/bin/sh\nset -eu\n",
        "printf 'release hook ran\\n' > \"",
        hook_marker,
        "\"\n",
        "if [ -f README.md ]; then\n",
        "    printf 'hook tampering\\n' >> README.md\n",
        "    git add README.md\nfi\n",
    }));
    try self.chmodExec(pre_commit);
    try self.writeFile(post_commit, try self.cat(&.{
        "#!/bin/sh\nset -eu\n",
        "printf 'release post-commit hook ran\\n' > \"",
        hook_marker,
        "\"\n",
    }));
    try self.chmodExec(post_commit);
    try self.writeFile(post_checkout, try self.cat(&.{
        "#!/bin/sh\nset -eu\n",
        "printf 'release post-checkout hook ran\\n' > \"",
        hook_marker,
        "\"\n",
        "if [ -f README.md ]; then\n",
        "    printf 'checkout hook tampering\\n' >> README.md\n",
        "    git add README.md\nfi\n",
    }));
    try self.chmodExec(post_checkout);
    try self.writeFile(pre_push, try self.cat(&.{
        "#!/bin/sh\nset -eu\n",
        "printf 'release pre-push hook ran\\n' > \"",
        hook_marker,
        "\"\n",
        "main=\"$(git --git-dir=\"",
        remote,
        "\" rev-parse refs/heads/main)\"\n",
        "git --git-dir=\"",
        remote,
        "\" update-ref refs/heads/hook-side-effect \"$main\"\n",
    }));
    try self.chmodExec(pre_push);

    try self.step(&e, e.verify(TRACING, true), "verify TRACING");
    try self.step(&e, e.verify(CORE, true), "verify CORE");
    {
        const r = e.verify(ARM, true);
        try self.expectFailure("branch-owned staged release", r, e.message, "branch-owned packages must be released from their package branch");
    }
    try self.assertCleanup(&e);
    try self.assertNoSourceArtifacts();
    if (self.pathExists(hook_marker)) return self.fail2("verification executed Git hooks");

    try self.step(&e, e.prepare(TRACING, true), "prepare TRACING");
    const tracing_v1 = e.publish(TRACING, false) catch |err| return self.engineErr(&e, "publish TRACING", err);
    if (!optEq(try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core_tracing", source), tracing_v1))
        return self.fail2("initial branch publication failed");
    if (!optEq(try engine.remoteTagCommit(gpa, io, remote, try self.cat(&.{ TRACING, "/v0.1.0" }), source), tracing_v1))
        return self.fail2("initial tag publication failed");
    if (self.countTokens(try self.git(source, &.{ "rev-list", "--parents", "-n", "1", tracing_v1 })) != 1)
        return self.fail2("initial release was not orphaned");

    try self.step(&e, e.prepare(CORE, true), "prepare CORE");
    const core_pkg = try e.package(CORE);
    {
        const seal_text = try self.readFile(try e.manifestPath(core_pkg));
        const seal = try std.json.parseFromSliceLeaky(engine.Seal, gpa, seal_text, .{ .ignore_unknown_fields = true });
        if (!std.mem.eql(u8, seal.source.remote_main_commit, try self.git(source, &.{ "rev-parse", "HEAD" })))
            return self.fail2("remote main provenance was not sealed");
        const dep = seal.dependencies[0];
        if (!std.mem.eql(u8, dep.commit, tracing_v1) or !std.mem.startsWith(u8, dep.hash, try self.cat(&.{ TRACING, "-" })))
            return self.fail2("dependency commit/hash resolution failed");
    }
    const core_v1 = e.publish(CORE, false) catch |err| return self.engineErr(&e, "publish CORE", err);
    if (self.pathExists(hook_marker)) return self.fail2("release publication executed Git hooks");
    if ((try engine.remoteRef(gpa, io, remote, "refs/heads/hook-side-effect", source)) != null)
        return self.fail2("pre-push hook changed the remote");
    self.unlink(pre_commit);
    self.unlink(post_commit);
    self.unlink(post_checkout);
    self.unlink(pre_push);

    const tracing_manifest = try self.joinp(&.{ source, "sdk/core/tracing/build.zig.zon" });
    const valid_tracing_manifest = try self.readFile(tracing_manifest);

    try self.writeFile(tracing_manifest, try self.dropLinesPrefixed(valid_tracing_manifest, ".fingerprint ="));
    _ = try self.commitAll("missing package fingerprint");
    try self.pushMain();
    e = try self.newEngine(false);
    {
        const r = e.prepare(TRACING, true);
        try self.expectFailure("missing package fingerprint", r, e.message, "missing or malformed .fingerprint");
    }
    try self.assertCleanup(&e);

    try self.writeFile(tracing_manifest, try self.replaceOnce(valid_tracing_manifest, ".minimum_zig_version = \"0.16.0\",", ".minimum_zig_version = \"\","));
    _ = try self.commitAll("empty minimum Zig version");
    try self.pushMain();
    e = try self.newEngine(false);
    {
        const r = e.prepare(TRACING, true);
        try self.expectFailure("empty minimum Zig version", r, e.message, ".minimum_zig_version must not be empty");
    }
    try self.assertCleanup(&e);

    try self.updateVersions("0.1.0", "0.1.0");
    try self.writeFile(tracing_manifest, try self.replaceOnce(try self.readFile(tracing_manifest), "        \"README.md\",", "        // \"README.md\","));
    _ = try self.commitAll("commented-out required package path");
    try self.pushMain();
    e = try self.newEngine(false);
    {
        const r = e.verify(TRACING, true);
        try self.expectFailure("commented-out required package path", r, e.message, ".paths must exactly match registry publish_paths");
    }
    try self.assertCleanup(&e);

    try self.updateVersions("0.1.0", "0.1.0");
    const core_manifest = try self.joinp(&.{ source, "sdk/core/build.zig.zon" });
    try self.writeFile(core_manifest, try self.replaceOnce(try self.readFile(core_manifest), ".path = \"tracing\",", ".path = \"../../rest/arm_avs\","));
    _ = try self.commitAll("wrong internal dependency path");
    try self.pushMain();
    e = try self.newEngine(false);
    {
        const r = e.verify(CORE, true);
        try self.expectFailure("wrong internal dependency path", r, e.message, try self.cat(&.{ "dependency ", TRACING, " path resolves to" }));
    }
    try self.assertCleanup(&e);

    try self.updateVersions("0.2.0", "0.1.0");
    _ = try self.commitAll("tracing 0.2.0 source");
    try self.pushMain();
    e = try self.newEngine(false);
    try self.step(&e, e.prepare(TRACING, true), "prepare TRACING 0.2.0");
    const dry_run_commit = e.publish(TRACING, true) catch |err| return self.engineErr(&e, "dry-run publish TRACING", err);
    if (!optEq(try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core_tracing", source), tracing_v1))
        return self.fail2("dry-run changed the remote branch");
    const tracing_v2 = e.publish(TRACING, false) catch |err| return self.engineErr(&e, "publish TRACING 0.2.0", err);
    if (!std.mem.eql(u8, try self.git(source, &.{ "rev-parse", try self.cat(&.{ tracing_v2, "^" }) }), tracing_v1))
        return self.fail2("second release is not a direct descendant");
    if (std.mem.eql(u8, dry_run_commit, tracing_v1))
        return self.fail2("dry-run did not create a prospective commit");

    try self.updateVersions("1.0", "0.1.0");
    _ = try self.commitAll("malformed version");
    try self.pushMain();
    e = try self.newEngine(false);
    {
        const r = e.prepare(TRACING, true);
        try self.expectFailure("malformed version", r, e.message, "malformed release version");
    }
    try self.assertCleanup(&e);

    try self.updateVersions("0.1.5", "0.1.0");
    _ = try self.commitAll("non-monotonic version");
    try self.pushMain();
    e = try self.newEngine(false);
    {
        const r = e.prepare(TRACING, true);
        try self.expectFailure("non-monotonic version", r, e.message, "is not greater than");
    }
    try self.assertCleanup(&e);

    // Re-releasing an existing version is stopped by the tag-collision
    // check, which runs before the history reuse scan. The reuse scan
    // itself needs a non-monotonic branch whose tag is absent, which
    // the monotonic check makes unreachable here.
    try self.updateVersions("0.2.0", "0.1.0");
    _ = try self.commitAll("reused version");
    try self.pushMain();
    e = try self.newEngine(false);
    {
        const r = e.prepare(TRACING, true);
        try self.expectFailure("prepare rejects an existing release tag", r, e.message, "release tag already exists");
    }
    try self.assertCleanup(&e);

    try self.updateVersions("0.2.0", "0.2.0");
    _ = try self.commitAll("core 0.2.0 source");
    try self.pushMain();
    e = try self.newEngine(false);
    try self.step(&e, e.prepare(CORE, true), "prepare CORE 0.2.0");
    const core_pkg2 = try e.package(CORE);
    {
        const seal_path = try e.manifestPath(core_pkg2);
        var current = try std.json.parseFromSliceLeaky(engine.Seal, gpa, try self.readFile(seal_path), .{ .ignore_unknown_fields = true });
        const correct_hash = current.dependencies[0].hash;
        const correct_commit = current.dependencies[0].commit;
        const staged_zon = try self.joinp(&.{ try e.stageDir(core_pkg2), "build.zig.zon" });
        var zon_text = try self.readFile(staged_zon);
        zon_text = try self.replaceOnce(zon_text, correct_hash, try self.cat(&.{ TRACING, "-0.0.0-wrong" }));
        zon_text = try self.replaceOnce(zon_text, correct_commit, core_v1);
        try self.writeFile(staged_zon, zon_text);
        const inv = try engine.fileInventory(gpa, io, try e.stageDir(core_pkg2));
        current.files = inv.files;
        current.content_digest = inv.digest;
        const new_seal = try std.json.Stringify.valueAlloc(gpa, current, .{ .whitespace = .indent_2 });
        try self.writeFile(seal_path, try self.cat(&.{ new_seal, "\n" }));
        const r = e.publish(CORE, true);
        try self.expectFailure("wrong dependency commit/hash", r, e.message, null);
    }
    try self.assertCleanup(&e);

    try self.step(&e, e.prepare(CORE, true), "re-prepare CORE for tamper");
    try self.writeFile(try self.joinp(&.{ try e.stageDir(core_pkg2), "README.md" }), "tampered\n");
    {
        const r = e.publish(CORE, true);
        try self.expectFailure("tampered stage", r, e.message, null);
    }
    try self.assertCleanup(&e);

    try self.step(&e, e.prepare(CORE, true), "re-prepare CORE for branch movement");
    const old_core_tip = (try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core", source)).?;
    const moved_tree = try self.git(source, &.{ "rev-parse", try self.cat(&.{ old_core_tip, "^{tree}" }) });
    const moved_commit = try self.git(source, &.{ "commit-tree", moved_tree, "-p", old_core_tip, "-m", "concurrent release" });
    _ = try self.git(source, &.{ "push", "--quiet", remote, try self.cat(&.{ moved_commit, ":refs/heads/sdk/core" }) });
    {
        const r = e.publish(CORE, true);
        try self.expectFailure("branch movement", r, e.message, null);
    }
    try self.assertCleanup(&e);
    _ = try self.git(source, &.{ "push", "--quiet", "--force", remote, try self.cat(&.{ old_core_tip, ":refs/heads/sdk/core" }) });

    const tracing_tag = try self.cat(&.{ "refs/tags/", TRACING, "/v0.2.0" });
    _ = try self.git(source, &.{ "push", "--quiet", "--delete", remote, tracing_tag });
    _ = try self.git(source, &.{ "push", "--quiet", remote, try self.cat(&.{ core_v1, ":", tracing_tag }) });
    e = try self.newEngine(false);
    {
        const r = e.prepare(CORE, true);
        try self.expectFailure("moved tag", r, e.message, null);
    }
    try self.assertCleanup(&e);
    _ = try self.git(source, &.{ "push", "--quiet", "--delete", remote, tracing_tag });
    _ = try self.git(source, &.{ "push", "--quiet", remote, try self.cat(&.{ tracing_v2, ":", tracing_tag }) });

    e = try self.newEngine(true);
    try self.step(&e, e.prepare(CORE, true), "prepare CORE for branch race");
    const branch_before = try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core", source);
    if (branch_before == null) return self.fail2("package branch is missing before race");
    const target_tag = try self.cat(&.{ CORE, "/v0.2.0" });
    {
        const r = e.publish(CORE, false);
        try self.expectFailure("package branch deletion before atomic push", r, e.message, null);
    }
    if ((try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core", source)) != null)
        return self.fail2("package branch race was not injected");
    if ((try engine.remoteTagCommit(gpa, io, remote, target_tag, source)) != null)
        return self.fail2("package branch race created the tag");
    try self.assertCleanup(&e);
    _ = try self.git(source, &.{ "push", "--quiet", PUBLICATION, try self.cat(&.{ branch_before.?, ":refs/heads/sdk/core" }) });

    e = try self.newEngine(false);
    try self.step(&e, e.prepare(CORE, true), "prepare CORE for tag collision");
    const colliding_tag = try self.cat(&.{ "refs/tags/", CORE, "/v0.2.0" });
    _ = try self.git(source, &.{ "push", "--quiet", remote, try self.cat(&.{ tracing_v2, ":", colliding_tag }) });
    const branch_before2 = try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core", source);
    {
        const r = e.publish(CORE, false);
        try self.expectFailure("publish rejects a tag created after prepare", r, e.message, "release tag already exists");
    }
    if (!optEq(try engine.remoteRef(gpa, io, remote, "refs/heads/sdk/core", source), branch_before2))
        return self.fail2("failed atomic push changed the branch");
    try self.assertCleanup(&e);
    _ = try self.git(source, &.{ "push", "--quiet", "--delete", remote, colliding_tag });

    try self.assertNoSourceArtifacts();

    try self.print(
        "release self-test passed: initial and descendant releases, " ++
            "dependency pins/paths, comment-aware manifest paths, manifest " ++
            "metadata and SemVer/reuse rejection, tamper/wrong-pin detection, " ++
            "disabled checkout/commit/push hooks, remote-main provenance, " ++
            "exact package-branch leases, isolated command environment, URL " ++
            "rewrite and single-destination remote checks, disposable Zig " ++
            "verification, branch/tag races, branch-owned release rejection, " ++
            "cleanup, and atomic local publication\n",
        .{},
    );
}
