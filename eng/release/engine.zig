//! Registry-driven package release preparation and publication.
//! Port of eng/release/release.py.

const std = @import("std");
const registry = @import("registry.zig");
const zon = @import("zon.zig");

const Io = std.Io;
const Dir = std.Io.Dir;
const Allocator = std.mem.Allocator;
const Environ = std.process.Environ;
const Package = registry.Package;

pub const ReleaseError = error{Release};

const max_read: std.Io.Limit = .limited(512 * 1024 * 1024);

pub const forbidden_parts = [_][]const u8{
    ".git",
    ".release",
    ".zig-cache",
    "__pycache__",
    "zig-cache",
    "zig-out",
    "zig-pkg",
};
pub const required_paths = [_][]const u8{
    "build.zig",
    "build.zig.zon",
    "README.md",
    "LICENSE.txt",
};

pub const RemoteIdentity = struct {
    fetch_url: []const u8,
    push_url: []const u8,
    repository: []const u8,
    zig_url: []const u8,
};

pub const BranchState = struct {
    commit: ?[]const u8,
    previous_name: ?[]const u8,
    previous_version: ?[]const u8,
};

pub const FileEntry = struct {
    path: []const u8,
    size: u64,
    sha256: []const u8,
    executable: bool,
};

pub const DependencyRecord = struct {
    name: []const u8,
    branch: []const u8,
    commit: []const u8,
    hash: []const u8,
    url: []const u8,
};

pub const Inventory = struct {
    files: []FileEntry,
    digest: []const u8,
};

const SealSource = struct {
    ref: []const u8,
    commit: []const u8,
    remote_main_commit: []const u8,
};
const SealPackage = struct {
    name: []const u8,
    version: []const u8,
    source_path: []const u8,
    branch: []const u8,
    tag: []const u8,
};
const SealRemote = struct {
    name: []const u8,
    fetch_url: []const u8,
    push_url: []const u8,
    repository: []const u8,
    zig_url: []const u8,
};
const SealBranch = struct {
    expected_tip: ?[]const u8 = null,
    previous_name: ?[]const u8 = null,
    previous_version: ?[]const u8 = null,
};
pub const Seal = struct {
    schema: u32,
    source: SealSource,
    package: SealPackage,
    remote: SealRemote,
    branch: SealBranch,
    dependencies: []DependencyRecord,
    declared_paths: []const []const u8,
    files: []FileEntry,
    content_digest: []const u8,
};

fn termOk(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}

fn termCode(term: std.process.Child.Term) u32 {
    return switch (term) {
        .exited => |code| code,
        else => 255,
    };
}

fn runCmd(
    gpa: Allocator,
    io: Io,
    argv: []const []const u8,
    cwd_path: []const u8,
    env: ?*const Environ.Map,
) !std.process.RunResult {
    return std.process.run(gpa, io, .{
        .argv = argv,
        .cwd = .{ .path = cwd_path },
        .environ_map = env,
    });
}

fn trimAscii(text: []const u8) []const u8 {
    return std.mem.trim(u8, text, " \t\r\n");
}

fn sha256Hex(gpa: Allocator, data: []const u8) ![]const u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(data);
    var out: [32]u8 = undefined;
    hasher.final(&out);
    const hex = std.fmt.bytesToHex(out, .lower);
    return gpa.dupe(u8, &hex);
}

const WalkItem = struct { path: []const u8 };

fn lessWalkItem(_: void, a: WalkItem, b: WalkItem) bool {
    return std.mem.lessThan(u8, a.path, b.path);
}

/// Deterministic content inventory of a directory tree. Rejects forbidden
/// artifacts, symlinks, and non-regular files. Mirrors release.py file_inventory.
pub fn fileInventory(gpa: Allocator, io: Io, root: []const u8) !Inventory {
    var dir = Dir.cwd().openDir(io, root, .{ .iterate = true }) catch return error.Release;
    defer dir.close(io);

    var items: std.ArrayList(WalkItem) = .empty;
    var walker = dir.walk(gpa) catch return error.Release;
    defer walker.deinit();
    while (walker.next(io) catch return error.Release) |entry| {
        try items.append(gpa, .{ .path = try gpa.dupe(u8, entry.path) });
    }
    std.mem.sort(WalkItem, items.items, {}, lessWalkItem);

    var files: std.ArrayList(FileEntry) = .empty;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    for (items.items) |item| {
        var parts = std.mem.splitScalar(u8, item.path, '/');
        while (parts.next()) |part| {
            for (forbidden_parts) |forbidden| {
                if (std.mem.eql(u8, part, forbidden)) return error.Release;
            }
        }
        const st = dir.statFile(io, item.path, .{ .follow_symlinks = false }) catch
            return error.Release;
        if (st.kind == .sym_link) return error.Release;
        if (st.kind == .directory) continue;
        if (st.kind != .file) return error.Release;

        const data = dir.readFileAlloc(io, item.path, gpa, max_read) catch
            return error.Release;
        const executable = (st.permissions.toMode() & 0o100) != 0;

        var len4: [4]u8 = undefined;
        std.mem.writeInt(u32, &len4, @intCast(item.path.len), .big);
        hasher.update(&len4);
        hasher.update(item.path);
        hasher.update(&[_]u8{if (executable) 1 else 0});
        var len8: [8]u8 = undefined;
        std.mem.writeInt(u64, &len8, @intCast(data.len), .big);
        hasher.update(&len8);
        hasher.update(data);

        try files.append(gpa, .{
            .path = item.path,
            .size = @intCast(data.len),
            .sha256 = try sha256Hex(gpa, data),
            .executable = executable,
        });
    }

    var out: [32]u8 = undefined;
    hasher.final(&out);
    const hex = std.fmt.bytesToHex(out, .lower);
    return .{
        .files = try files.toOwnedSlice(gpa),
        .digest = try gpa.dupe(u8, &hex),
    };
}

/// `git -C <dir> <args...>`, returning trimmed stdout. Errors on failure.
pub fn gitOut(
    gpa: Allocator,
    io: Io,
    dir: []const u8,
    args: []const []const u8,
) ![]const u8 {
    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(gpa, &.{ "git", "-C", dir });
    try argv.appendSlice(gpa, args);
    const cwd = std.fs.path.dirname(dir) orelse dir;
    const result = try runCmd(gpa, io, argv.items, cwd, null);
    if (!termOk(result.term)) return error.Release;
    return trimAscii(result.stdout);
}

/// Resolve a single ref on a remote, returning its commit or null.
pub fn remoteRef(
    gpa: Allocator,
    io: Io,
    remote: []const u8,
    ref: []const u8,
    cwd: []const u8,
) !?[]const u8 {
    const output = try gitOut(gpa, io, cwd, &.{ "ls-remote", remote, ref });
    if (output.len == 0) return null;
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        var fields = std.mem.tokenizeAny(u8, line, " \t");
        const commit = fields.next() orelse continue;
        const name = fields.next() orelse continue;
        if (std.mem.eql(u8, name, ref)) return commit;
    }
    return null;
}

/// Resolve an annotated or lightweight tag on a remote to its commit.
pub fn remoteTagCommit(
    gpa: Allocator,
    io: Io,
    remote: []const u8,
    tag: []const u8,
    cwd: []const u8,
) !?[]const u8 {
    const ref = try std.fmt.allocPrint(gpa, "refs/tags/{s}", .{tag});
    const peeled = try std.fmt.allocPrint(gpa, "{s}^{{}}", .{ref});
    const output = try gitOut(gpa, io, cwd, &.{ "ls-remote", remote, ref, peeled });
    if (output.len == 0) return null;
    var direct: ?[]const u8 = null;
    var annotated: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, output, '\n');
    while (lines.next()) |line| {
        var fields = std.mem.tokenizeAny(u8, line, " \t");
        const commit = fields.next() orelse continue;
        const name = fields.next() orelse continue;
        if (std.mem.eql(u8, name, peeled)) {
            annotated = commit;
        } else if (std.mem.eql(u8, name, ref)) {
            direct = commit;
        }
    }
    return annotated orelse direct;
}

fn stripPrefix(value: []const u8, prefix: []const u8) []const u8 {
    if (std.mem.startsWith(u8, value, prefix)) return value[prefix.len..];
    return value;
}

fn stripSuffix(value: []const u8, suffix: []const u8) []const u8 {
    if (std.mem.endsWith(u8, value, suffix)) return value[0 .. value.len - suffix.len];
    return value;
}

fn toLower(gpa: Allocator, value: []const u8) ![]const u8 {
    const out = try gpa.alloc(u8, value.len);
    for (value, 0..) |c, i| out[i] = std.ascii.toLower(c);
    return out;
}

fn componentBytes(component: std.Uri.Component) []const u8 {
    return switch (component) {
        .raw => |raw| raw,
        .percent_encoded => |encoded| encoded,
    };
}

fn isUriSafe(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '-' or c == '.' or
        c == '_' or c == '~' or c == '/';
}

const ScpMatch = struct { host: []const u8, path: []const u8 };

/// Match `(?:[^@]+@)?([^:]+):(.+)` — an scp-style Git URL without a scheme.
fn parseScp(value: []const u8) ?ScpMatch {
    var rest = value;
    if (std.mem.indexOfScalar(u8, rest, '@')) |at| {
        if (std.mem.indexOfScalar(u8, rest, ':')) |colon| {
            if (at < colon) rest = rest[at + 1 ..];
        }
    }
    const colon = std.mem.indexOfScalar(u8, rest, ':') orelse return null;
    const host = rest[0..colon];
    const path = rest[colon + 1 ..];
    if (host.len == 0 or path.len == 0) return null;
    if (std.mem.indexOfScalar(u8, host, '/') != null) return null;
    return .{ .host = host, .path = path };
}

const Provenance = struct {
    ref: []const u8,
    commit: []const u8,
    remote_main_commit: []const u8,
};
const FetchedRepo = struct { repository: []const u8, commit: []const u8 };
const DepArchiveResult = struct { commit: []const u8, hash: []const u8, url: []const u8 };
const IndexEntry = struct { path: []const u8, mode: []const u8, oid: []const u8 };
const Worktree = struct { path: []const u8, branch: ?[]const u8 };
const ScpFull = struct { user_host: []const u8, path: []const u8 };

fn eqOpt(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null and b == null) return true;
    if (a == null or b == null) return false;
    return std.mem.eql(u8, a.?, b.?);
}

fn strListEqual(a: []const []const u8, b: []const []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (!std.mem.eql(u8, x, y)) return false;
    }
    return true;
}

fn samePathSet(a: []const []const u8, b: []const []const u8) bool {
    if (a.len != b.len) return false;
    for (a) |x| {
        if (!containsStr(b, x)) return false;
    }
    for (b) |x| {
        if (!containsStr(a, x)) return false;
    }
    return true;
}

fn containsStr(list: []const []const u8, value: []const u8) bool {
    for (list) |x| {
        if (std.mem.eql(u8, x, value)) return true;
    }
    return false;
}

fn fileEntriesEqual(a: []const FileEntry, b: []const FileEntry) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (!std.mem.eql(u8, x.path, y.path)) return false;
        if (x.size != y.size) return false;
        if (!std.mem.eql(u8, x.sha256, y.sha256)) return false;
        if (x.executable != y.executable) return false;
    }
    return true;
}

fn findIndexEntry(list: []const IndexEntry, path: []const u8) ?IndexEntry {
    for (list) |entry| {
        if (std.mem.eql(u8, entry.path, path)) return entry;
    }
    return null;
}

fn pathSetsMatch(actual: []const IndexEntry, expected: []const FileEntry) bool {
    if (actual.len != expected.len) return false;
    for (expected) |entry| {
        if (findIndexEntry(actual, entry.path) == null) return false;
    }
    return true;
}

fn isFullCommit(commit: []const u8) bool {
    if (commit.len != 40) return false;
    for (commit) |c| {
        const hex = (c >= '0' and c <= '9') or (c >= 'a' and c <= 'f');
        if (!hex) return false;
    }
    return true;
}

fn scpFull(value: []const u8) ?ScpFull {
    const at = std.mem.indexOfScalar(u8, value, '@') orelse return null;
    if (at == 0) return null;
    const colon = std.mem.indexOfScalarPos(u8, value, at, ':') orelse return null;
    if (colon <= at + 1) return null;
    const path = value[colon + 1 ..];
    if (path.len == 0) return null;
    return .{ .user_host = value[0..colon], .path = path };
}

fn zonErrorMessage(err: zon.ZonError) []const u8 {
    return switch (err) {
        error.MissingFingerprint => "missing or malformed .fingerprint",
        error.EmptyMinimumZigVersion => ".minimum_zig_version must not be empty",
        error.MalformedVersion => "malformed release version",
        error.UnbalancedBraces => "unbalanced braces in build.zig.zon",
        error.MissingField => "missing required manifest field",
        error.MalformedField => "malformed manifest field",
        error.UnterminatedString => "unterminated string in build.zig.zon",
        error.MissingTrailingComma => "missing trailing comma in build.zig.zon",
        error.DuplicateDependency => "duplicate dependency in build.zig.zon",
        error.MissingDependency => "missing dependency in build.zig.zon",
        error.NotLocalPath => "dependency must be a local path",
        error.NotImmutablePin => "dependency must be an immutable pin",
        error.OutOfMemory => "out of memory",
    };
}

pub const Engine = struct {
    gpa: Allocator,
    io: Io,
    root: []const u8,
    remote: []const u8,
    release_root: []const u8,
    packages: registry.Registry,
    env: *Environ.Map,
    message: ?[]const u8 = null,
    race_delete_branch: bool = false,
    active_worktrees: std.ArrayList(Worktree) = .empty,

    pub fn init(
        gpa: Allocator,
        io: Io,
        root_in: []const u8,
        remote: []const u8,
        release_root_in: ?[]const u8,
        env: *Environ.Map,
    ) !Engine {
        const root = Dir.cwd().realPathFileAlloc(io, root_in, gpa) catch return error.Release;
        const registry_path = try std.fs.path.join(gpa, &.{ root, "eng", "packages.zig" });
        const text = Dir.cwd().readFileAlloc(io, registry_path, gpa, max_read) catch
            return error.Release;
        const reg = try registry.load(gpa, text);
        const release_root = if (release_root_in) |rr|
            rr
        else
            try std.fs.path.join(gpa, &.{ root, ".release", "packages" });
        return .{
            .gpa = gpa,
            .io = io,
            .root = root,
            .remote = remote,
            .release_root = release_root,
            .packages = reg,
            .env = env,
        };
    }

    fn fail(self: *Engine, comptime fmt: []const u8, args: anytype) error{Release} {
        self.message = std.fmt.allocPrint(self.gpa, fmt, args) catch "release error";
        return error.Release;
    }

    fn join(self: *Engine, parts: []const []const u8) ![]const u8 {
        return std.fs.path.join(self.gpa, parts);
    }

    pub fn package(self: *Engine, name: []const u8) !*Package {
        return self.packages.find(name) orelse
            self.fail("unknown registry package: {s}", .{name});
    }

    fn packageRoot(self: *Engine, pkg: *Package) ![]const u8 {
        const source_path = pkg.sourcePath() catch
            return self.fail("{s}: package is not present in this workspace", .{pkg.name});
        return self.join(&.{ self.root, source_path });
    }

    fn requireMainOwned(self: *Engine, pkg: *Package) !void {
        if (pkg.ownership != .main_owned) {
            return self.fail(
                "{s}: branch-owned packages must be released from their package branch",
                .{pkg.name},
            );
        }
    }

    fn stageBase(self: *Engine, pkg: *Package) ![]const u8 {
        return self.join(&.{ self.release_root, pkg.name });
    }

    pub fn stageDir(self: *Engine, pkg: *Package) ![]const u8 {
        return self.join(&.{ try self.stageBase(pkg), "stage" });
    }

    pub fn manifestPath(self: *Engine, pkg: *Package) ![]const u8 {
        return self.join(&.{ try self.stageBase(pkg), "stage-manifest.json" });
    }

    fn workDir(self: *Engine, pkg: *Package) ![]const u8 {
        return self.join(&.{ try self.stageBase(pkg), "work" });
    }

    fn emptyHooksPath(self: *Engine, work: []const u8) ![]const u8 {
        const hooks = try self.join(&.{ work, "empty-hooks" });
        Dir.cwd().createDirPath(self.io, hooks) catch return error.Release;
        return hooks;
    }

    fn print(self: *Engine, comptime fmt: []const u8, args: anytype) !void {
        var buffer: [4096]u8 = undefined;
        var file = std.Io.File.stdout();
        var writer = file.writer(self.io, &buffer);
        try writer.interface.print(fmt, args);
        try writer.interface.flush();
    }

    fn git(self: *Engine, args: []const []const u8, check: bool) ![]const u8 {
        return self.gitAt(self.root, args, check);
    }

    fn gitAt(self: *Engine, dir: []const u8, args: []const []const u8, check: bool) ![]const u8 {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(self.gpa, &.{ "git", "-C", dir });
        try argv.appendSlice(self.gpa, args);
        const cwd = std.fs.path.dirname(dir) orelse dir;
        const result = try runCmd(self.gpa, self.io, argv.items, cwd, self.env);
        if (check and !termOk(result.term)) {
            const joined = try std.mem.join(self.gpa, " ", argv.items);
            return self.fail("command failed ({s}): {s}", .{ joined, trimAscii(result.stderr) });
        }
        return trimAscii(result.stdout);
    }

    fn gitQuiet(self: *Engine, dir: []const u8, args: []const []const u8) void {
        const result = self.gitAt(dir, args, false) catch return;
        _ = result;
    }

    fn runOut(self: *Engine, cwd: []const u8, argv: []const []const u8) ![]u8 {
        const result = try runCmd(self.gpa, self.io, argv, cwd, self.env);
        if (!termOk(result.term)) {
            const joined = try std.mem.join(self.gpa, " ", argv);
            return self.fail("command failed ({s}): {s}", .{ joined, trimAscii(result.stderr) });
        }
        return result.stdout;
    }

    fn pathExists(self: *Engine, path: []const u8) bool {
        _ = Dir.cwd().statFile(self.io, path, .{}) catch return false;
        return true;
    }

    fn isFile(self: *Engine, path: []const u8) bool {
        const st = Dir.cwd().statFile(self.io, path, .{}) catch return false;
        return st.kind == .file;
    }

    fn isDir(self: *Engine, path: []const u8) bool {
        const st = Dir.cwd().statFile(self.io, path, .{}) catch return false;
        return st.kind == .directory;
    }

    fn resolvePath(self: *Engine, path: []const u8) ![]const u8 {
        return Dir.cwd().realPathFileAlloc(self.io, path, self.gpa) catch
            std.fs.path.resolve(self.gpa, &.{path});
    }

    fn relativeIgnored(self: *Engine) []const u8 {
        if (std.mem.startsWith(u8, self.release_root, self.root)) {
            var rel = self.release_root[self.root.len..];
            rel = std.mem.trimStart(u8, rel, "/");
            return std.mem.trimEnd(u8, rel, "/");
        }
        return self.release_root;
    }

    fn safeRemove(self: *Engine, path: []const u8, allowed_root: []const u8) !void {
        const st = Dir.cwd().statFile(self.io, path, .{ .follow_symlinks = false }) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return error.Release,
        };
        const parent = std.fs.path.dirname(path) orelse path;
        const resolved_parent = self.resolvePath(parent) catch
            return self.fail("refusing to remove path outside release root: {s}", .{path});
        const allowed = self.resolvePath(allowed_root) catch
            return self.fail("refusing to remove path outside release root: {s}", .{path});
        const ancestor = try std.fmt.allocPrint(self.gpa, "{s}/", .{allowed});
        const ok = std.mem.eql(u8, resolved_parent, allowed) or
            std.mem.startsWith(u8, resolved_parent, ancestor);
        if (!ok) return self.fail("refusing to remove path outside release root: {s}", .{path});
        if (st.kind == .directory) {
            Dir.cwd().deleteTree(self.io, path) catch return error.Release;
        } else {
            Dir.cwd().deleteFile(self.io, path) catch return error.Release;
        }
    }

    fn copyPath(self: *Engine, src: []const u8, dest: []const u8) !void {
        const st = Dir.cwd().statFile(self.io, src, .{ .follow_symlinks = false }) catch
            return error.Release;
        if (st.kind == .directory) {
            try self.copyTree(src, dest);
        } else {
            if (std.fs.path.dirname(dest)) |parent| {
                Dir.cwd().createDirPath(self.io, parent) catch return error.Release;
            }
            Dir.copyFile(.cwd(), src, .cwd(), dest, self.io, .{ .make_path = true, .replace = true }) catch
                return error.Release;
        }
    }

    fn copyTree(self: *Engine, src: []const u8, dest: []const u8) !void {
        Dir.cwd().createDirPath(self.io, dest) catch return error.Release;
        var dir = Dir.cwd().openDir(self.io, src, .{ .iterate = true }) catch return error.Release;
        defer dir.close(self.io);
        var walker = dir.walk(self.gpa) catch return error.Release;
        defer walker.deinit();
        while (walker.next(self.io) catch return error.Release) |entry| {
            const dpath = try self.join(&.{ dest, entry.path });
            const spath = try self.join(&.{ src, entry.path });
            const st = Dir.cwd().statFile(self.io, spath, .{ .follow_symlinks = false }) catch
                return error.Release;
            if (st.kind == .directory) {
                Dir.cwd().createDirPath(self.io, dpath) catch return error.Release;
            } else {
                if (std.fs.path.dirname(dpath)) |parent| {
                    Dir.cwd().createDirPath(self.io, parent) catch return error.Release;
                }
                Dir.copyFile(.cwd(), spath, .cwd(), dpath, self.io, .{ .make_path = true, .replace = true }) catch
                    return error.Release;
            }
        }
    }

    fn copyTopLevelInto(self: *Engine, stage: []const u8, worktree: []const u8) !void {
        var dir = Dir.cwd().openDir(self.io, stage, .{ .iterate = true }) catch return error.Release;
        defer dir.close(self.io);
        var walker = dir.walk(self.gpa) catch return error.Release;
        defer walker.deinit();
        while (walker.next(self.io) catch return error.Release) |entry| {
            if (std.mem.indexOfScalar(u8, entry.path, '/') != null) continue;
            const src = try self.join(&.{ stage, entry.path });
            const dst = try self.join(&.{ worktree, entry.path });
            try self.copyPath(src, dst);
        }
    }

    fn extractArchive(
        self: *Engine,
        repository: []const u8,
        commit: []const u8,
        destination: []const u8,
        pathspec: ?[]const u8,
    ) !void {
        try self.safeRemove(destination, std.fs.path.dirname(destination) orelse destination);
        Dir.cwd().createDirPath(self.io, destination) catch return error.Release;
        const repo_cwd = std.fs.path.dirname(repository) orelse repository;
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(self.gpa, &.{ "git", "-C", repository, "ls-tree", "-r", "-z", commit });
        if (pathspec) |ps| try argv.appendSlice(self.gpa, &.{ "--", ps });
        const listing = try self.runOut(repo_cwd, argv.items);
        var rows = std.mem.splitScalar(u8, listing, 0);
        while (rows.next()) |row| {
            if (row.len == 0) continue;
            const tab = std.mem.indexOfScalar(u8, row, '\t') orelse
                return self.fail("unsafe path in Git archive", .{});
            const meta = row[0..tab];
            const path = row[tab + 1 ..];
            var fields = std.mem.tokenizeAny(u8, meta, " ");
            const mode = fields.next() orelse return self.fail("unsafe path in Git archive", .{});
            const otype = fields.next() orelse return self.fail("unsafe path in Git archive", .{});
            const oid = fields.next() orelse return self.fail("unsafe path in Git archive", .{});
            if (std.mem.eql(u8, mode, "120000") or std.mem.eql(u8, mode, "160000")) {
                return self.fail("symlink in release archive: {s}", .{path});
            }
            if (!std.mem.eql(u8, otype, "blob")) return self.fail("unsafe path in Git archive", .{});
            if (std.fs.path.isAbsolute(path)) return self.fail("unsafe path in Git archive", .{});
            var segments = std.mem.splitScalar(u8, path, '/');
            while (segments.next()) |segment| {
                if (std.mem.eql(u8, segment, "..")) return self.fail("unsafe path in Git archive", .{});
            }
            const executable = std.mem.eql(u8, mode, "100755");
            const blob = try self.runOut(repo_cwd, &.{ "git", "-C", repository, "cat-file", "blob", oid });
            const dest_full = try self.join(&.{ destination, path });
            if (std.fs.path.dirname(dest_full)) |parent| {
                Dir.cwd().createDirPath(self.io, parent) catch return error.Release;
            }
            Dir.cwd().writeFile(self.io, .{ .sub_path = dest_full, .data = blob }) catch return error.Release;
            if (executable) {
                Dir.cwd().setFilePermissions(self.io, dest_full, .fromMode(0o755), .{}) catch
                    return error.Release;
            }
        }
    }

    fn isLocalPath(self: *Engine, value: []const u8) bool {
        if (std.mem.startsWith(u8, value, "/") or
            std.mem.startsWith(u8, value, "./") or
            std.mem.startsWith(u8, value, "../")) return true;
        const joined = self.join(&.{ self.root, value }) catch return false;
        return self.pathExists(joined);
    }

    fn operationUrl(self: *Engine, raw: []const u8) ![]const u8 {
        const value = stripPrefix(raw, "git+");
        if (self.isLocalPath(value)) {
            const absolute = if (std.fs.path.isAbsolute(value))
                value
            else
                try self.join(&.{ self.root, value });
            return self.resolvePath(absolute);
        }
        return raw;
    }

    fn canonicalRepository(self: *Engine, raw: []const u8) ![]const u8 {
        const value = stripPrefix(raw, "git+");
        if (self.isLocalPath(value)) {
            const absolute = if (std.fs.path.isAbsolute(value))
                value
            else
                try self.join(&.{ self.root, value });
            const resolved = try self.resolvePath(absolute);
            return std.fmt.allocPrint(self.gpa, "file:{s}", .{resolved});
        }
        if (std.mem.indexOf(u8, value, "://") == null) {
            if (parseScp(value)) |scp| {
                const host = try toLower(self.gpa, scp.host);
                var path = std.mem.trim(u8, scp.path, "/");
                path = stripSuffix(path, ".git");
                return std.fmt.allocPrint(self.gpa, "{s}/{s}", .{ host, path });
            }
        }
        const uri = std.Uri.parse(value) catch
            return self.fail("cannot identify publication repository URL", .{});
        if (std.mem.eql(u8, uri.scheme, "file")) {
            const resolved = try self.resolvePath(componentBytes(uri.path));
            return std.fmt.allocPrint(self.gpa, "file:{s}", .{resolved});
        }
        const host_component = uri.host orelse
            return self.fail("cannot identify publication repository URL", .{});
        const known = std.mem.eql(u8, uri.scheme, "git") or
            std.mem.eql(u8, uri.scheme, "http") or
            std.mem.eql(u8, uri.scheme, "https") or
            std.mem.eql(u8, uri.scheme, "ssh");
        if (!known) return self.fail("cannot identify publication repository URL", .{});
        if (uri.password != null) return self.fail("remote URL must not contain an embedded password", .{});
        const is_http = std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https");
        if (is_http and uri.user != null) {
            return self.fail("remote URL must not contain embedded credentials", .{});
        }
        var host = try toLower(self.gpa, componentBytes(host_component));
        const default_port: ?u16 = if (std.mem.eql(u8, uri.scheme, "http"))
            80
        else if (std.mem.eql(u8, uri.scheme, "https"))
            443
        else if (std.mem.eql(u8, uri.scheme, "ssh"))
            22
        else
            null;
        if (uri.port) |port| {
            if (default_port == null or port != default_port.?) {
                host = try std.fmt.allocPrint(self.gpa, "{s}:{d}", .{ host, port });
            }
        }
        var path = std.mem.trim(u8, componentBytes(uri.path), "/");
        path = stripSuffix(path, ".git");
        if (path.len == 0) return self.fail("remote URL has no repository path", .{});
        return std.fmt.allocPrint(self.gpa, "{s}/{s}", .{ host, path });
    }

    fn asFileUri(self: *Engine, abs_path: []const u8) ![]const u8 {
        var out: std.ArrayList(u8) = .empty;
        try out.appendSlice(self.gpa, "file://");
        const hex = "0123456789ABCDEF";
        for (abs_path) |c| {
            if (isUriSafe(c)) {
                try out.append(self.gpa, c);
            } else {
                try out.append(self.gpa, '%');
                try out.append(self.gpa, hex[c >> 4]);
                try out.append(self.gpa, hex[c & 0xF]);
            }
        }
        return out.toOwnedSlice(self.gpa);
    }

    fn computeZigUrl(self: *Engine, fetch_url: []const u8) ![]const u8 {
        var raw = fetch_url;
        const is_local = std.mem.startsWith(u8, raw, "/") or
            std.mem.startsWith(u8, raw, "./") or
            std.mem.startsWith(u8, raw, "../") or
            self.pathExists(raw);
        if (is_local) {
            const absolute = if (std.fs.path.isAbsolute(raw))
                raw
            else
                try self.join(&.{ self.root, raw });
            const resolved = try self.resolvePath(absolute);
            raw = try self.asFileUri(resolved);
        }
        if (std.mem.startsWith(u8, raw, "git+")) return raw;
        if (std.mem.startsWith(u8, raw, "https://") or
            std.mem.startsWith(u8, raw, "http://") or
            std.mem.startsWith(u8, raw, "ssh://") or
            std.mem.startsWith(u8, raw, "file://"))
        {
            return std.fmt.allocPrint(self.gpa, "git+{s}", .{raw});
        }
        if (scpFull(raw)) |scp| {
            return std.fmt.allocPrint(self.gpa, "git+ssh://{s}/{s}", .{ scp.user_host, scp.path });
        }
        return self.fail("cannot convert remote URL for Zig: {s}", .{raw});
    }

    fn rejectUrlRewrites(self: *Engine) !void {
        const argv = [_][]const u8{
            "git",           "config",
            "--show-origin", "--show-scope",
            "--get-regexp",  "^url\\..*\\.(insteadof|pushinsteadof)$",
        };
        const result = try runCmd(self.gpa, self.io, &argv, self.root, self.env);
        const code = termCode(result.term);
        if (code == 0 and result.stdout.len > 0) {
            return self.fail(
                "effective Git URL rewrite configuration is not allowed for package releases; remove all url.*.insteadOf and url.*.pushInsteadOf rules",
                .{},
            );
        }
        if (code != 0 and code != 1) {
            return self.fail("failed to inspect Git URL rewrite configuration: {s}", .{trimAscii(result.stderr)});
        }
    }

    fn remoteUrls(self: *Engine, push: bool) !?[][]const u8 {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(self.gpa, &.{ "git", "remote", "get-url" });
        if (push) try argv.append(self.gpa, "--push");
        try argv.append(self.gpa, "--all");
        try argv.append(self.gpa, self.remote);
        const result = try runCmd(self.gpa, self.io, argv.items, self.root, self.env);
        if (!termOk(result.term)) return null;
        var lines: std.ArrayList([]const u8) = .empty;
        var it = std.mem.splitScalar(u8, std.mem.trimEnd(u8, result.stdout, "\n"), '\n');
        while (it.next()) |line| {
            if (line.len > 0) try lines.append(self.gpa, line);
        }
        return try lines.toOwnedSlice(self.gpa);
    }

    fn resolveRemoteIdentity(self: *Engine) !RemoteIdentity {
        try self.rejectUrlRewrites();
        const fetch_urls = try self.remoteUrls(false);
        var fetch_url: []const u8 = undefined;
        var push_url: []const u8 = undefined;
        if (fetch_urls == null) {
            fetch_url = self.remote;
            push_url = self.remote;
        } else {
            if (fetch_urls.?.len != 1) {
                return self.fail("publication remote must have exactly one fetch URL; found {d}", .{fetch_urls.?.len});
            }
            const push_urls = if (try self.remoteUrls(true)) |urls| urls else &[_][]const u8{};
            if (push_urls.len != 1) {
                return self.fail("publication remote must have exactly one push URL; found {d}", .{push_urls.len});
            }
            fetch_url = fetch_urls.?[0];
            push_url = push_urls[0];
        }
        fetch_url = try self.operationUrl(fetch_url);
        push_url = try self.operationUrl(push_url);
        const fetch_repo = try self.canonicalRepository(fetch_url);
        const push_repo = try self.canonicalRepository(push_url);
        if (!std.mem.eql(u8, fetch_repo, push_repo)) {
            return self.fail(
                "publication remote fetch/push repository mismatch:\n  fetch: {s}\n  push:  {s}",
                .{ fetch_url, push_url },
            );
        }
        const zig_url = try self.computeZigUrl(fetch_url);
        return .{
            .fetch_url = fetch_url,
            .push_url = push_url,
            .repository = fetch_repo,
            .zig_url = zig_url,
        };
    }

    fn lessStr(_: void, a: []const u8, b: []const u8) bool {
        return std.mem.lessThan(u8, a, b);
    }

    fn readText(self: *Engine, path: []const u8) ![]const u8 {
        return Dir.cwd().readFileAlloc(self.io, path, self.gpa, max_read) catch return error.Release;
    }

    fn writeText(self: *Engine, path: []const u8, data: []const u8) !void {
        Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = data }) catch return error.Release;
    }

    fn isSymlink(self: *Engine, path: []const u8) bool {
        const st = Dir.cwd().statFile(self.io, path, .{ .follow_symlinks = false }) catch return false;
        return st.kind == .sym_link;
    }

    fn topLevelNames(self: *Engine, root: []const u8) ![][]const u8 {
        var dir = Dir.cwd().openDir(self.io, root, .{ .iterate = true }) catch return error.Release;
        defer dir.close(self.io);
        var walker = dir.walk(self.gpa) catch return error.Release;
        defer walker.deinit();
        var names: std.ArrayList([]const u8) = .empty;
        while (walker.next(self.io) catch return error.Release) |entry| {
            if (std.mem.indexOfScalar(u8, entry.path, '/') != null) continue;
            try names.append(self.gpa, try self.gpa.dupe(u8, entry.path));
        }
        return names.toOwnedSlice(self.gpa);
    }

    fn pyList(self: *Engine, items: []const []const u8) ![]const u8 {
        const sorted = try self.gpa.dupe([]const u8, items);
        std.mem.sort([]const u8, sorted, {}, lessStr);
        var out: std.ArrayList(u8) = .empty;
        try out.append(self.gpa, '[');
        for (sorted, 0..) |item, index| {
            if (index > 0) try out.appendSlice(self.gpa, ", ");
            try out.append(self.gpa, '\'');
            try out.appendSlice(self.gpa, item);
            try out.append(self.gpa, '\'');
        }
        try out.append(self.gpa, ']');
        return out.toOwnedSlice(self.gpa);
    }

    fn validateTree(
        self: *Engine,
        root: []const u8,
        pkg: *Package,
        published: bool,
        exact_top_level: bool,
    ) !zon.Manifest {
        if (!self.isDir(root)) return self.fail("package directory does not exist: {s}", .{root});
        var missing: std.ArrayList([]const u8) = .empty;
        for (required_paths) |req| {
            const path = try self.join(&.{ root, req });
            if (!self.isFile(path)) try missing.append(self.gpa, req);
        }
        if (missing.items.len != 0) {
            return self.fail("{s}: missing required files: {s}", .{ pkg.name, try self.pyList(missing.items) });
        }
        const actual_top = try self.topLevelNames(root);
        if (exact_top_level and !samePathSet(actual_top, pkg.publish_paths)) {
            return self.fail(
                "{s}: staged top-level entries differ: expected {s}, got {s}",
                .{ pkg.name, try self.pyList(pkg.publish_paths), try self.pyList(actual_top) },
            );
        }
        _ = fileInventory(self.gpa, self.io, root) catch
            return self.fail("{s}: invalid release tree", .{pkg.name});
        const zon_path = try self.join(&.{ root, "build.zig.zon" });
        const text = try self.readText(zon_path);
        const manifest = zon.parse(self.gpa, text) catch |err|
            return self.fail("{s}: {s}", .{ pkg.name, zonErrorMessage(err) });
        _ = zon.parseSemver(manifest.version) catch |err|
            return self.fail("{s}: {s}", .{ pkg.name, zonErrorMessage(err) });
        if (!std.mem.eql(u8, manifest.name, pkg.name)) {
            return self.fail("{s}: manifest package name is {s}", .{ pkg.name, manifest.name });
        }
        if (!samePathSet(manifest.paths, pkg.publish_paths)) {
            return self.fail("{s}: .paths must exactly match registry publish_paths", .{pkg.name});
        }
        var expected_names: std.ArrayList([]const u8) = .empty;
        try expected_names.appendSlice(self.gpa, pkg.dependencies);
        try expected_names.appendSlice(self.gpa, pkg.external_dependencies);
        var manifest_names: std.ArrayList([]const u8) = .empty;
        for (manifest.dependencies) |dep| try manifest_names.append(self.gpa, dep.name);
        if (!samePathSet(manifest_names.items, expected_names.items)) {
            return self.fail(
                "{s}: dependency keys differ: expected {s}, got {s}",
                .{ pkg.name, try self.pyList(expected_names.items), try self.pyList(manifest_names.items) },
            );
        }
        for (pkg.dependencies) |name| {
            const dep = manifest.findDependency(name).?;
            if (published) {
                if (dep.path != null) return self.fail("{s}: published path dependency: {s}", .{ pkg.name, name });
                const has_url = dep.url != null and dep.url.?.len != 0;
                const has_hash = dep.hash != null and dep.hash.?.len != 0;
                if (!has_url or !has_hash) return self.fail("{s}: incomplete immutable pin: {s}", .{ pkg.name, name });
            } else {
                if (dep.path == null or dep.url != null or dep.hash != null) {
                    return self.fail("{s}: {s} must be a local path on main", .{ pkg.name, name });
                }
            }
        }
        for (pkg.external_dependencies) |name| {
            const dep = manifest.findDependency(name).?;
            if (dep.path != null) return self.fail("{s}: external path dependency: {s}", .{ pkg.name, name });
            const has_url = dep.url != null and dep.url.?.len != 0;
            const has_hash = dep.hash != null and dep.hash.?.len != 0;
            if (!has_url or !has_hash) return self.fail("{s}: incomplete external dependency: {s}", .{ pkg.name, name });
        }
        return manifest;
    }

    fn validateSourceWorkspace(
        self: *Engine,
        pkg: *Package,
        package_root: []const u8,
        workspace_root: []const u8,
    ) !zon.Manifest {
        const manifest = try self.validateTree(package_root, pkg, false, false);
        for (pkg.dependencies) |dependency_name| {
            const dep = manifest.findDependency(dependency_name).?;
            const dependency_path = dep.path orelse
                return self.fail("{s}: missing local path for {s}", .{ pkg.name, dependency_name });
            const dependency = try self.package(dependency_name);
            if (std.fs.path.isAbsolute(dependency_path)) {
                return self.fail("{s}: dependency {s} path is absolute", .{ pkg.name, dependency_name });
            }
            const resolved = try self.resolvePath(try self.join(&.{ package_root, dependency_path }));
            const dep_source = dependency.sourcePath() catch
                return self.fail("{s}: dependency {s} is not present in this workspace", .{ pkg.name, dependency_name });
            const expected = try self.resolvePath(try self.join(&.{ workspace_root, dep_source }));
            if (!std.mem.eql(u8, resolved, expected)) {
                return self.fail(
                    "{s}: dependency {s} path resolves to {s}, expected {s}",
                    .{ pkg.name, dependency_name, resolved, expected },
                );
            }
            if (!self.isDir(expected)) {
                return self.fail("{s}: dependency source directory is missing: {s}", .{ pkg.name, expected });
            }
        }
        return manifest;
    }

    fn sourceProvenance(self: *Engine) !Provenance {
        const ref = try self.git(&.{ "symbolic-ref", "--quiet", "--short", "HEAD" }, false);
        if (ref.len == 0) return self.fail("source repository is detached", .{});
        if (!std.mem.eql(u8, ref, "main")) return self.fail("source branch must be main; found {s}", .{ref});
        const commit = try self.git(&.{ "rev-parse", "HEAD" }, true);
        if (!isFullCommit(commit)) return self.fail("source commit is not a full lowercase object ID", .{});
        const status = try self.git(&.{ "status", "--porcelain=v1", "--untracked-files=all" }, true);
        const ignored = self.relativeIgnored();
        var dirty: std.ArrayList([]const u8) = .empty;
        var lines = std.mem.splitScalar(u8, status, '\n');
        while (lines.next()) |line| {
            if (line.len < 3) continue;
            var path = line[3..];
            path = std.mem.trimEnd(u8, path, "/");
            const same = std.mem.eql(u8, path, ignored);
            const ignored_slash = try std.fmt.allocPrint(self.gpa, "{s}/", .{ignored});
            const under = std.mem.startsWith(u8, path, ignored_slash);
            const path_slash = try std.fmt.allocPrint(self.gpa, "{s}/", .{path});
            const parent_of = std.mem.startsWith(u8, ignored, path_slash);
            if (same or under or parent_of) continue;
            try dirty.append(self.gpa, line);
        }
        if (dirty.items.len != 0) {
            const joined = try std.mem.join(self.gpa, "\n", dirty.items);
            return self.fail("source repository is dirty:\n{s}", .{joined});
        }
        const ref_commit = try self.git(&.{ "rev-parse", ref }, true);
        if (!std.mem.eql(u8, ref_commit, commit)) return self.fail("named source ref does not point to HEAD", .{});

        const remote_identity = try self.resolveRemoteIdentity();
        const main_ref = "refs/heads/main";
        const advertised_main = try remoteRef(self.gpa, self.io, remote_identity.fetch_url, main_ref, self.root);
        if (advertised_main == null) return self.fail("publication remote is missing refs/heads/main", .{});
        _ = try self.git(&.{ "fetch", "--quiet", "--no-tags", remote_identity.fetch_url, main_ref }, true);
        const fetched_main = try self.git(&.{ "rev-parse", "FETCH_HEAD" }, true);
        const current_main = try remoteRef(self.gpa, self.io, remote_identity.fetch_url, main_ref, self.root);
        if (!eqOpt(fetched_main, advertised_main) or !eqOpt(current_main, fetched_main)) {
            return self.fail("publication remote main moved while resolving provenance", .{});
        }
        if (!std.mem.eql(u8, commit, fetched_main)) {
            return self.fail(
                "source HEAD does not match publication remote refs/heads/main:\n  source: {s}\n  remote: {s}",
                .{ commit, fetched_main },
            );
        }
        return .{ .ref = ref, .commit = commit, .remote_main_commit = fetched_main };
    }

    fn cleanWork(self: *Engine, pkg: *Package) ![]const u8 {
        const work = try self.workDir(pkg);
        try self.safeRemove(work, self.release_root);
        Dir.cwd().createDirPath(self.io, work) catch return error.Release;
        return work;
    }

    fn commandEnv(self: *Engine, work: []const u8) !Environ.Map {
        var env = Environ.Map.init(self.gpa);
        const whitelist = [_][]const u8{
            "PATH",          "SystemRoot",   "WINDIR",            "COMSPEC",
            "PATHEXT",       "SYSTEMDRIVE",  "SDKROOT",           "DEVELOPER_DIR",
            "SSL_CERT_FILE", "SSL_CERT_DIR", "NIX_SSL_CERT_FILE", "LANG",
            "LC_ALL",        "LC_CTYPE",     "TZ",
        };
        for (whitelist) |name| {
            if (self.env.get(name)) |value| try env.put(name, value);
        }
        if (env.get("PATH") == null) return self.fail("PATH is required to run package commands", .{});
        const local_cache = try self.join(&.{ work, "caches", "local" });
        const global_cache = try self.join(&.{ work, "caches", "global" });
        const temp = try self.join(&.{ work, "tmp" });
        const home = try self.join(&.{ work, "home" });
        const xdg_config = try self.join(&.{ home, ".config" });
        const xdg_cache = try self.join(&.{ work, "caches", "xdg" });
        const xdg_data = try self.join(&.{ home, ".local", "share" });
        const dirs = [_][]const u8{ local_cache, global_cache, temp, home, xdg_config, xdg_cache, xdg_data };
        for (dirs) |dir| Dir.cwd().createDirPath(self.io, dir) catch return error.Release;
        try env.put("HOME", home);
        try env.put("USERPROFILE", home);
        try env.put("TMPDIR", temp);
        try env.put("TMP", temp);
        try env.put("TEMP", temp);
        try env.put("ZIG_LOCAL_CACHE_DIR", local_cache);
        try env.put("ZIG_GLOBAL_CACHE_DIR", global_cache);
        try env.put("XDG_CONFIG_HOME", xdg_config);
        try env.put("XDG_CACHE_HOME", xdg_cache);
        try env.put("XDG_DATA_HOME", xdg_data);
        try env.put("APPDATA", xdg_config);
        try env.put("LOCALAPPDATA", xdg_data);
        try env.put("GIT_CONFIG_NOSYSTEM", "1");
        try env.put("GIT_CONFIG_GLOBAL", "/dev/null");
        try env.put("GIT_TERMINAL_PROMPT", "0");
        return env;
    }

    fn runPackageCommands(self: *Engine, pkg: *Package, directory: []const u8, work: []const u8) !void {
        var env = try self.commandEnv(work);
        const commands = [_]?[]const u8{ pkg.test_command, pkg.examples_command, pkg.live_test_command };
        for (commands) |maybe| {
            const command = maybe orelse continue;
            if (command.len == 0) continue;
            const argv = [_][]const u8{ "bash", "-euo", "pipefail", "-c", command };
            const result = try runCmd(self.gpa, self.io, &argv, directory, &env);
            if (!termOk(result.term)) {
                return self.fail("{s}: validation command failed: {s}", .{ pkg.name, command });
            }
        }
    }

    fn verifyRegeneration(self: *Engine, pkg: *Package, source_commit: []const u8, work: []const u8) !void {
        const command = pkg.regeneration_command orelse return;
        if (command.len == 0) return;
        const worktree = try self.join(&.{ work, "regeneration-worktree" });
        const empty_hooks = try self.emptyHooksPath(work);
        const hooks_arg = try std.fmt.allocPrint(self.gpa, "core.hooksPath={s}", .{empty_hooks});
        _ = try self.git(&.{ "-c", hooks_arg, "worktree", "add", "--quiet", "--detach", worktree, source_commit }, true);
        try self.active_worktrees.append(self.gpa, .{ .path = worktree, .branch = null });
        const result = self.verifyRegenerationInner(pkg, command, worktree, work);
        self.removeWorktree(worktree, null);
        return result;
    }

    fn verifyRegenerationInner(self: *Engine, pkg: *Package, command: []const u8, worktree: []const u8, work: []const u8) !void {
        var env = try self.commandEnv(try self.join(&.{ work, "regeneration" }));
        const argv = [_][]const u8{ "bash", "-euo", "pipefail", "-c", command };
        const result = try runCmd(self.gpa, self.io, &argv, worktree, &env);
        if (!termOk(result.term)) return self.fail("{s}: regeneration command failed", .{pkg.name});
        const source_path = try pkg.sourcePath();
        const changes = try self.gitAt(worktree, &.{ "status", "--porcelain=v1", "--untracked-files=all", "--", source_path }, true);
        if (changes.len != 0) return self.fail("{s}: regeneration is not byte-identical:\n{s}", .{ pkg.name, changes });
        _ = try self.validateSourceWorkspace(pkg, try self.join(&.{ worktree, source_path }), worktree);
    }

    fn runSourceCommands(self: *Engine, pkg: *Package, source_commit: []const u8, work: []const u8) !void {
        const worktree = try self.join(&.{ work, "command-worktree" });
        const empty_hooks = try self.emptyHooksPath(work);
        const hooks_arg = try std.fmt.allocPrint(self.gpa, "core.hooksPath={s}", .{empty_hooks});
        _ = try self.git(&.{ "-c", hooks_arg, "worktree", "add", "--quiet", "--detach", worktree, source_commit }, true);
        try self.active_worktrees.append(self.gpa, .{ .path = worktree, .branch = null });
        const result = self.runSourceCommandsInner(pkg, worktree, work);
        self.removeWorktree(worktree, null);
        return result;
    }

    fn runSourceCommandsInner(self: *Engine, pkg: *Package, worktree: []const u8, work: []const u8) !void {
        const source_path = try pkg.sourcePath();
        const package_root = try self.join(&.{ worktree, source_path });
        _ = try self.validateSourceWorkspace(pkg, package_root, worktree);
        try self.runPackageCommands(pkg, package_root, try self.join(&.{ work, "source-tests" }));
        const changes = try self.gitAt(worktree, &.{ "status", "--porcelain=v1", "--untracked-files=all", "--", source_path }, true);
        if (changes.len != 0) {
            return self.fail("{s}: package commands modified source files:\n{s}", .{ pkg.name, changes });
        }
    }

    pub fn verify(self: *Engine, name: []const u8, run_commands: bool) !void {
        const pkg = try self.package(name);
        try self.requireMainOwned(pkg);
        const prov = try self.sourceProvenance();
        _ = try self.validateSourceWorkspace(pkg, try self.packageRoot(pkg), self.root);
        const work = try self.cleanWork(pkg);
        const result = self.verifyInner(pkg, prov.commit, work, run_commands);
        self.safeRemove(work, self.release_root) catch {};
        try result;
        try self.print("verified {s} at source commit {s}\n", .{ pkg.name, prov.commit });
    }

    fn verifyInner(self: *Engine, pkg: *Package, source_commit: []const u8, work: []const u8, run_commands: bool) !void {
        try self.verifyRegeneration(pkg, source_commit, work);
        if (run_commands) try self.runSourceCommands(pkg, source_commit, work);
        _ = try self.validateSourceWorkspace(pkg, try self.packageRoot(pkg), self.root);
    }

    fn fetchBranchRepo(self: *Engine, pkg: *Package, work: []const u8) !?FetchedRepo {
        Dir.cwd().createDirPath(self.io, work) catch return error.Release;
        const remote_identity = try self.resolveRemoteIdentity();
        const branch_ref = try std.fmt.allocPrint(self.gpa, "refs/heads/{s}", .{pkg.branch});
        const commit = try remoteRef(self.gpa, self.io, remote_identity.fetch_url, branch_ref, self.root);
        if (commit == null) return null;
        const repository = try self.join(&.{ work, "branch-repository" });
        _ = try self.gitAt(work, &.{ "init", "--quiet", repository }, true);
        _ = try self.gitAt(repository, &.{ "fetch", "--quiet", "--no-tags", remote_identity.fetch_url, branch_ref }, true);
        const fetched = try self.gitAt(repository, &.{ "rev-parse", "FETCH_HEAD" }, true);
        if (!std.mem.eql(u8, fetched, commit.?)) {
            return self.fail("{s}: release branch moved while fetching", .{pkg.name});
        }
        return .{ .repository = repository, .commit = commit.? };
    }

    fn showManifest(self: *Engine, repository: []const u8, commit: []const u8) !zon.Manifest {
        const spec = try std.fmt.allocPrint(self.gpa, "{s}:build.zig.zon", .{commit});
        const text = try self.runOut(repository, &.{ "git", "show", spec });
        return zon.parse(self.gpa, text) catch |err|
            self.fail("published branch has malformed manifest: {s}", .{zonErrorMessage(err)});
    }

    fn inspectBranch(
        self: *Engine,
        pkg: *Package,
        target: []const u8,
        work: []const u8,
    ) !BranchState {
        const fetch_url = (try self.resolveRemoteIdentity()).fetch_url;
        const fetched = try self.fetchBranchRepo(pkg, work);
        const target_version = zon.parseSemver(target) catch
            return self.fail("{s}: malformed manifest version", .{pkg.name});
        const tag = try std.fmt.allocPrint(self.gpa, "{s}/v{s}", .{ pkg.name, target });
        if ((try remoteTagCommit(self.gpa, self.io, fetch_url, tag, self.root)) != null) {
            return self.fail("{s}: release tag already exists: {s}", .{ pkg.name, tag });
        }
        if (fetched == null) {
            const is_initial = target_version.major == 0 and target_version.minor == 1 and target_version.patch == 0;
            if (!is_initial) return self.fail("{s}: first canonical release must be 0.1.0", .{pkg.name});
            return .{ .commit = null, .previous_name = null, .previous_version = null };
        }
        const repository = fetched.?.repository;
        const commit = fetched.?.commit;
        const tip_manifest = try self.showManifest(repository, commit);
        const previous_version = zon.parseSemver(tip_manifest.version) catch
            return self.fail("{s}: release branch tip has malformed version", .{pkg.name});
        if (!std.mem.eql(u8, tip_manifest.name, pkg.name)) {
            return self.fail("{s}: release branch contains unexpected package {s}", .{ pkg.name, tip_manifest.name });
        }
        if (target_version.order(previous_version) != .gt) {
            return self.fail("{s}: version {s} is not greater than {s}", .{ pkg.name, target, tip_manifest.version });
        }
        const history = try self.gitAt(repository, &.{ "rev-list", commit }, true);
        var lines = std.mem.splitScalar(u8, history, '\n');
        while (lines.next()) |history_commit| {
            if (history_commit.len == 0) continue;
            const manifest = try self.showManifest(repository, history_commit);
            if (!std.mem.eql(u8, manifest.name, pkg.name)) continue;
            _ = zon.parseSemver(manifest.version) catch
                return self.fail("{s}: malformed version in release history", .{pkg.name});
            if (std.mem.eql(u8, manifest.version, target)) {
                return self.fail("{s}: version {s} was already used", .{ pkg.name, target });
            }
            const historical_tag = try std.fmt.allocPrint(self.gpa, "{s}/v{s}", .{ pkg.name, manifest.version });
            const tagged = try remoteTagCommit(self.gpa, self.io, fetch_url, historical_tag, self.root);
            if (tagged == null) return self.fail("{s}: historical tag is missing: {s}", .{ pkg.name, historical_tag });
            if (!std.mem.eql(u8, tagged.?, history_commit)) {
                return self.fail("{s}: historical tag moved: {s}", .{ pkg.name, historical_tag });
            }
        }
        return .{ .commit = commit, .previous_name = tip_manifest.name, .previous_version = tip_manifest.version };
    }

    fn dependencyArchive(self: *Engine, dependency: *Package, work: []const u8) !DepArchiveResult {
        const remote_identity = try self.resolveRemoteIdentity();
        const ref = try std.fmt.allocPrint(self.gpa, "refs/heads/{s}", .{dependency.branch});
        const commit = try remoteRef(self.gpa, self.io, remote_identity.fetch_url, ref, self.root);
        if (commit == null) return self.fail("{s}: dependency release branch does not exist", .{dependency.name});
        const repository = try self.join(&.{ work, try std.fmt.allocPrint(self.gpa, "{s}-repository", .{dependency.name}) });
        _ = try self.gitAt(work, &.{ "init", "--quiet", repository }, true);
        _ = try self.gitAt(repository, &.{ "fetch", "--quiet", "--no-tags", remote_identity.fetch_url, ref }, true);
        const fetched = try self.gitAt(repository, &.{ "rev-parse", "FETCH_HEAD" }, true);
        if (!std.mem.eql(u8, fetched, commit.?)) return self.fail("{s}: dependency branch moved", .{dependency.name});
        const archive = try self.join(&.{ work, try std.fmt.allocPrint(self.gpa, "{s}-archive", .{dependency.name}) });
        try self.extractArchive(repository, commit.?, archive, null);
        const manifest = try self.validateTree(archive, dependency, true, true);
        const tag = try std.fmt.allocPrint(self.gpa, "{s}/v{s}", .{ dependency.name, manifest.version });
        const tag_commit = try remoteTagCommit(self.gpa, self.io, remote_identity.fetch_url, tag, self.root);
        if (!eqOpt(tag_commit, commit.?)) return self.fail("{s}: dependency tag does not match branch tip", .{dependency.name});
        const cache = try self.join(&.{ work, "zig-global-cache" });
        const fetch_out = try self.runOut(work, &.{ "zig", "fetch", "--global-cache-dir", cache, archive });
        const package_hash = trimAscii(fetch_out);
        const prefix = try std.fmt.allocPrint(self.gpa, "{s}-", .{dependency.name});
        if (!std.mem.startsWith(u8, package_hash, prefix)) {
            return self.fail("{s}: Zig returned an unexpected package hash", .{dependency.name});
        }
        const zig_base = remote_identity.zig_url;
        const url = try std.fmt.allocPrint(self.gpa, "{s}#{s}", .{ zig_base, commit.? });
        if (!std.mem.startsWith(u8, zig_base, "git+file://")) {
            const url_out = try self.runOut(work, &.{ "zig", "fetch", "--global-cache-dir", cache, url });
            const url_hash = trimAscii(url_out);
            if (!std.mem.eql(u8, url_hash, package_hash)) {
                return self.fail("{s}: remote URL hash differs from fetched archive", .{dependency.name});
            }
        }
        return .{ .commit = commit.?, .hash = package_hash, .url = url };
    }

    fn stageSource(self: *Engine, pkg: *Package, commit: []const u8, work: []const u8) ![]const u8 {
        Dir.cwd().createDirPath(self.io, work) catch return error.Release;
        const archive = try self.join(&.{ work, "source-archive" });
        const source_path = try pkg.sourcePath();
        try self.extractArchive(self.root, commit, archive, source_path);
        const package_source = try self.join(&.{ archive, source_path });
        _ = try self.validateTree(package_source, pkg, false, false);
        const stage = try self.stageDir(pkg);
        try self.safeRemove(stage, self.release_root);
        Dir.cwd().createDirPath(self.io, stage) catch return error.Release;
        for (pkg.publish_paths) |declared| {
            const source = try self.join(&.{ package_source, declared });
            if (!self.pathExists(source) or self.isSymlink(source)) {
                return self.fail("{s}: declared source path missing or symlinked: {s}", .{ pkg.name, declared });
            }
            const destination = try self.join(&.{ stage, declared });
            try self.copyPath(source, destination);
        }
        _ = try self.validateTree(stage, pkg, false, true);
        return stage;
    }

    fn reconstructStage(self: *Engine, pkg: *Package, source_commit: []const u8, pins: []const zon.Pin, work: []const u8) ![]const u8 {
        Dir.cwd().createDirPath(self.io, work) catch return error.Release;
        const archive = try self.join(&.{ work, "source-archive" });
        const source_path = try pkg.sourcePath();
        try self.extractArchive(self.root, source_commit, archive, source_path);
        const source = try self.join(&.{ archive, source_path });
        _ = try self.validateTree(source, pkg, false, false);
        const expected = try self.join(&.{ work, "expected-stage" });
        Dir.cwd().createDirPath(self.io, expected) catch return error.Release;
        for (pkg.publish_paths) |declared| {
            const source_p = try self.join(&.{ source, declared });
            const destination = try self.join(&.{ expected, declared });
            try self.copyPath(source_p, destination);
        }
        const manifest_path = try self.join(&.{ expected, "build.zig.zon" });
        const original = try self.readText(manifest_path);
        const rewritten = zon.rewriteInternalDependencies(self.gpa, original, pins) catch |err|
            return self.fail("{s}: {s}", .{ pkg.name, zonErrorMessage(err) });
        try self.writeText(manifest_path, rewritten);
        _ = try self.validateTree(expected, pkg, true, true);
        return expected;
    }

    fn runPreparedCommands(
        self: *Engine,
        pkg: *Package,
        stage: []const u8,
        dependency_records: []const DependencyRecord,
        dependency_work: []const u8,
        work: []const u8,
    ) !void {
        const test_root = try self.join(&.{ work, "test-workspace" });
        const test_package = try self.join(&.{ test_root, "package" });
        Dir.cwd().createDirPath(self.io, test_root) catch return error.Release;
        try self.safeRemove(test_package, work);
        try self.copyTree(stage, test_package);

        var local_records: std.ArrayList(DependencyRecord) = .empty;
        for (dependency_records) |record| {
            if (std.mem.startsWith(u8, record.url, "git+file://")) try local_records.append(self.gpa, record);
        }
        if (local_records.items.len != 0) {
            if (local_records.items.len != dependency_records.len) {
                return self.fail("{s}: mixed local and network dependency pins", .{pkg.name});
            }
            var local_paths: std.ArrayList(zon.PathPin) = .empty;
            for (local_records.items) |record| {
                const archive = try self.join(&.{ dependency_work, try std.fmt.allocPrint(self.gpa, "{s}-archive", .{record.name}) });
                const destination = try self.join(&.{ test_root, "dependencies", record.name });
                if (std.fs.path.dirname(destination)) |parent| {
                    Dir.cwd().createDirPath(self.io, parent) catch return error.Release;
                }
                try self.copyTree(archive, destination);
                const rel = try std.fmt.allocPrint(self.gpa, "../dependencies/{s}", .{record.name});
                try local_paths.append(self.gpa, .{ .name = record.name, .path = rel });
            }
            const manifest_path = try self.join(&.{ test_package, "build.zig.zon" });
            const original = try self.readText(manifest_path);
            const rewritten = zon.rewriteInternalPaths(self.gpa, original, local_paths.items) catch |err|
                return self.fail("{s}: {s}", .{ pkg.name, zonErrorMessage(err) });
            try self.writeText(manifest_path, rewritten);
            _ = try self.validateTree(test_package, pkg, false, true);
        }
        try self.runPackageCommands(pkg, test_package, try self.join(&.{ work, "stage-tests" }));
    }

    pub fn prepare(self: *Engine, name: []const u8, run_commands: bool) !void {
        const pkg = try self.package(name);
        try self.requireMainOwned(pkg);
        const prov = try self.sourceProvenance();
        const manifest = try self.validateSourceWorkspace(pkg, try self.packageRoot(pkg), self.root);
        const work = try self.cleanWork(pkg);
        const result = self.prepareInner(pkg, manifest.version, prov, work, run_commands);
        self.safeRemove(work, self.release_root) catch {};
        try result;
        try self.print("prepared {s} {s}\n", .{ pkg.name, manifest.version });
        try self.print("stage: {s}\n", .{try self.stageDir(pkg)});
        try self.print("manifest: {s}\n", .{try self.manifestPath(pkg)});
    }

    fn prepareInner(
        self: *Engine,
        pkg: *Package,
        target: []const u8,
        prov: Provenance,
        work: []const u8,
        run_commands: bool,
    ) !void {
        try self.verifyRegeneration(pkg, prov.commit, work);
        const branch_state = try self.inspectBranch(pkg, target, try self.join(&.{ work, "release-state" }));
        const stage = try self.stageSource(pkg, prov.commit, try self.join(&.{ work, "source" }));

        var dependency_records: std.ArrayList(DependencyRecord) = .empty;
        var pins: std.ArrayList(zon.Pin) = .empty;
        const dependency_work = try self.join(&.{ work, "dependencies" });
        Dir.cwd().createDirPath(self.io, dependency_work) catch return error.Release;
        for (pkg.dependencies) |dependency_name| {
            const dependency = try self.package(dependency_name);
            const archive = try self.dependencyArchive(dependency, dependency_work);
            try dependency_records.append(self.gpa, .{
                .name = dependency.name,
                .branch = dependency.branch,
                .commit = archive.commit,
                .hash = archive.hash,
                .url = archive.url,
            });
            try pins.append(self.gpa, .{ .name = dependency.name, .url = archive.url, .hash = archive.hash });
        }

        const manifest_path = try self.join(&.{ stage, "build.zig.zon" });
        const original = try self.readText(manifest_path);
        const rewritten = zon.rewriteInternalDependencies(self.gpa, original, pins.items) catch |err|
            return self.fail("{s}: {s}", .{ pkg.name, zonErrorMessage(err) });
        try self.writeText(manifest_path, rewritten);
        const staged_manifest = try self.validateTree(stage, pkg, true, true);
        for (dependency_records.items) |record| {
            const dep = staged_manifest.findDependency(record.name).?;
            if (!eqOpt(dep.url, record.url) or !eqOpt(dep.hash, record.hash)) {
                return self.fail("{s}: staged dependency pin differs: {s}", .{ pkg.name, record.name });
            }
        }

        if (run_commands) {
            try self.runPreparedCommands(pkg, stage, dependency_records.items, dependency_work, work);
        }
        _ = try self.validateTree(stage, pkg, true, true);

        const inv = try fileInventory(self.gpa, self.io, stage);
        const remote_identity = try self.resolveRemoteIdentity();
        const tag = try std.fmt.allocPrint(self.gpa, "{s}/v{s}", .{ pkg.name, target });
        const source_path = try pkg.sourcePath();
        const seal = Seal{
            .schema = 1,
            .source = .{ .ref = prov.ref, .commit = prov.commit, .remote_main_commit = prov.remote_main_commit },
            .package = .{ .name = pkg.name, .version = target, .source_path = source_path, .branch = pkg.branch, .tag = tag },
            .remote = .{
                .name = self.remote,
                .fetch_url = remote_identity.fetch_url,
                .push_url = remote_identity.push_url,
                .repository = remote_identity.repository,
                .zig_url = remote_identity.zig_url,
            },
            .branch = .{
                .expected_tip = branch_state.commit,
                .previous_name = branch_state.previous_name,
                .previous_version = branch_state.previous_version,
            },
            .dependencies = dependency_records.items,
            .declared_paths = pkg.publish_paths,
            .files = inv.files,
            .content_digest = inv.digest,
        };
        try self.writeSeal(pkg, seal);
    }

    fn writeSeal(self: *Engine, pkg: *Package, seal: Seal) !void {
        const manifest_file = try self.manifestPath(pkg);
        if (std.fs.path.dirname(manifest_file)) |parent| {
            Dir.cwd().createDirPath(self.io, parent) catch return error.Release;
        }
        const json = std.json.Stringify.valueAlloc(self.gpa, seal, .{ .whitespace = .indent_2 }) catch
            return error.Release;
        const with_newline = try std.fmt.allocPrint(self.gpa, "{s}\n", .{json});
        try self.writeText(manifest_file, with_newline);
    }

    fn loadSeal(self: *Engine, pkg: *Package) !Seal {
        const path = try self.manifestPath(pkg);
        const text = self.readText(path) catch
            return self.fail("{s}: missing or malformed stage seal", .{pkg.name});
        const parsed = std.json.parseFromSliceLeaky(Seal, self.gpa, text, .{ .ignore_unknown_fields = true }) catch
            return self.fail("{s}: missing or malformed stage seal", .{pkg.name});
        if (parsed.schema != 1) return self.fail("{s}: unsupported stage seal schema", .{pkg.name});
        return parsed;
    }

    fn validateSeal(self: *Engine, pkg: *Package, seal: Seal, work: []const u8) !BranchState {
        const stage = try self.stageDir(pkg);
        const staged_manifest = try self.validateTree(stage, pkg, true, true);
        const inv = try fileInventory(self.gpa, self.io, stage);
        if (!fileEntriesEqual(inv.files, seal.files) or !std.mem.eql(u8, inv.digest, seal.content_digest)) {
            return self.fail("{s}: staged content was tampered with", .{pkg.name});
        }
        if (!strListEqual(seal.declared_paths, pkg.publish_paths)) {
            return self.fail("{s}: sealed declared paths differ", .{pkg.name});
        }
        const tag = try std.fmt.allocPrint(self.gpa, "{s}/v{s}", .{ pkg.name, staged_manifest.version });
        const source_path = try pkg.sourcePath();
        const pkg_ok = std.mem.eql(u8, seal.package.name, pkg.name) and
            std.mem.eql(u8, seal.package.version, staged_manifest.version) and
            std.mem.eql(u8, seal.package.source_path, source_path) and
            std.mem.eql(u8, seal.package.branch, pkg.branch) and
            std.mem.eql(u8, seal.package.tag, tag);
        if (!pkg_ok) return self.fail("{s}: sealed package metadata differs", .{pkg.name});
        const prov = try self.sourceProvenance();
        const src_ok = std.mem.eql(u8, seal.source.ref, prov.ref) and
            std.mem.eql(u8, seal.source.commit, prov.commit) and
            std.mem.eql(u8, seal.source.remote_main_commit, prov.remote_main_commit);
        if (!src_ok) return self.fail("{s}: source provenance changed", .{pkg.name});
        const remote_identity = try self.resolveRemoteIdentity();
        const rem_ok = std.mem.eql(u8, seal.remote.name, self.remote) and
            std.mem.eql(u8, seal.remote.fetch_url, remote_identity.fetch_url) and
            std.mem.eql(u8, seal.remote.push_url, remote_identity.push_url) and
            std.mem.eql(u8, seal.remote.repository, remote_identity.repository) and
            std.mem.eql(u8, seal.remote.zig_url, remote_identity.zig_url);
        if (!rem_ok) return self.fail("{s}: publication remote identity differs from prepare", .{pkg.name});
        const branch_state = try self.inspectBranch(pkg, staged_manifest.version, try self.join(&.{ work, "release-state" }));
        const branch_ok = eqOpt(branch_state.commit, seal.branch.expected_tip) and
            eqOpt(branch_state.previous_name, seal.branch.previous_name) and
            eqOpt(branch_state.previous_version, seal.branch.previous_version);
        if (!branch_ok) return self.fail("{s}: release branch moved after prepare", .{pkg.name});

        var seal_names: std.ArrayList([]const u8) = .empty;
        for (seal.dependencies) |item| try seal_names.append(self.gpa, item.name);
        if (!strListEqual(seal_names.items, pkg.dependencies)) {
            return self.fail("{s}: sealed dependencies differ", .{pkg.name});
        }
        const dependency_work = try self.join(&.{ work, "dependencies" });
        Dir.cwd().createDirPath(self.io, dependency_work) catch return error.Release;
        var pins: std.ArrayList(zon.Pin) = .empty;
        for (seal.dependencies) |item| {
            const dependency = try self.package(item.name);
            const archive = try self.dependencyArchive(dependency, dependency_work);
            const expected_ok = std.mem.eql(u8, item.name, dependency.name) and
                std.mem.eql(u8, item.branch, dependency.branch) and
                std.mem.eql(u8, item.commit, archive.commit) and
                std.mem.eql(u8, item.hash, archive.hash) and
                std.mem.eql(u8, item.url, archive.url);
            if (!expected_ok) return self.fail("{s}: dependency branch or hash changed: {s}", .{ pkg.name, dependency.name });
            const staged = staged_manifest.findDependency(dependency.name).?;
            if (!eqOpt(staged.url, archive.url) or !eqOpt(staged.hash, archive.hash)) {
                return self.fail("{s}: staged dependency pin is wrong: {s}", .{ pkg.name, dependency.name });
            }
            try pins.append(self.gpa, .{ .name = dependency.name, .url = archive.url, .hash = archive.hash });
        }
        const expected_stage = try self.reconstructStage(pkg, prov.commit, pins.items, try self.join(&.{ work, "reconstructed" }));
        const expected_inv = try fileInventory(self.gpa, self.io, expected_stage);
        if (!fileEntriesEqual(inv.files, expected_inv.files) or !std.mem.eql(u8, inv.digest, expected_inv.digest)) {
            return self.fail("{s}: stage differs from its recorded source commit", .{pkg.name});
        }
        return branch_state;
    }

    fn verifyIndex(self: *Engine, worktree: []const u8, stage: []const u8) !void {
        const inv = try fileInventory(self.gpa, self.io, stage);
        const raw = try self.runOut(worktree, &.{ "git", "ls-files", "-s", "-z" });
        var actual: std.ArrayList(IndexEntry) = .empty;
        var rows = std.mem.splitScalar(u8, raw, 0);
        while (rows.next()) |row| {
            if (row.len == 0) continue;
            const tab = std.mem.indexOfScalar(u8, row, '\t') orelse return self.fail("malformed index entry", .{});
            const metadata = row[0..tab];
            const path = row[tab + 1 ..];
            var fields = std.mem.tokenizeAny(u8, metadata, " ");
            const mode = fields.next() orelse return self.fail("malformed index entry", .{});
            const object_id = fields.next() orelse return self.fail("malformed index entry", .{});
            const stage_number = fields.next() orelse return self.fail("malformed index entry", .{});
            if (!std.mem.eql(u8, stage_number, "0")) return self.fail("unmerged publication index entry: {s}", .{path});
            try actual.append(self.gpa, .{ .path = path, .mode = mode, .oid = object_id });
        }
        if (!pathSetsMatch(actual.items, inv.files)) {
            return self.fail("publication index file list differs from sealed stage", .{});
        }
        for (inv.files) |item| {
            const spec = try std.fmt.allocPrint(self.gpa, ":{s}", .{item.path});
            const data = try self.runOut(worktree, &.{ "git", "show", spec });
            const source = try self.readText(try self.join(&.{ stage, item.path }));
            if (!std.mem.eql(u8, data, source)) return self.fail("publication index bytes differ: {s}", .{item.path});
            const entry = findIndexEntry(actual.items, item.path).?;
            const expected_mode: []const u8 = if (item.executable) "100755" else "100644";
            if (!std.mem.eql(u8, entry.mode, expected_mode)) return self.fail("publication index mode differs: {s}", .{item.path});
        }
    }

    fn verifyCommitTree(self: *Engine, worktree: []const u8, commit: []const u8, stage: []const u8) !void {
        const inv = try fileInventory(self.gpa, self.io, stage);
        const raw = try self.runOut(worktree, &.{ "git", "ls-tree", "-r", "-z", commit });
        var actual: std.ArrayList(IndexEntry) = .empty;
        var rows = std.mem.splitScalar(u8, raw, 0);
        while (rows.next()) |row| {
            if (row.len == 0) continue;
            const tab = std.mem.indexOfScalar(u8, row, '\t') orelse return self.fail("malformed tree entry", .{});
            const metadata = row[0..tab];
            const path = row[tab + 1 ..];
            var fields = std.mem.tokenizeAny(u8, metadata, " ");
            const mode = fields.next() orelse return self.fail("malformed tree entry", .{});
            const object_type = fields.next() orelse return self.fail("malformed tree entry", .{});
            const object_id = fields.next() orelse return self.fail("malformed tree entry", .{});
            if (!std.mem.eql(u8, object_type, "blob")) return self.fail("non-blob publication tree entry: {s}", .{path});
            try actual.append(self.gpa, .{ .path = path, .mode = mode, .oid = object_id });
        }
        if (!pathSetsMatch(actual.items, inv.files)) {
            return self.fail("publication commit file list differs from sealed stage", .{});
        }
        for (inv.files) |item| {
            const spec = try std.fmt.allocPrint(self.gpa, "{s}:{s}", .{ commit, item.path });
            const data = try self.runOut(worktree, &.{ "git", "show", spec });
            const source = try self.readText(try self.join(&.{ stage, item.path }));
            if (!std.mem.eql(u8, data, source)) return self.fail("publication commit bytes differ: {s}", .{item.path});
            const entry = findIndexEntry(actual.items, item.path).?;
            const expected_mode: []const u8 = if (item.executable) "100755" else "100644";
            if (!std.mem.eql(u8, entry.mode, expected_mode)) return self.fail("publication commit mode differs: {s}", .{item.path});
        }
    }

    fn atomicPush(
        self: *Engine,
        worktree: []const u8,
        pkg: *Package,
        tag: []const u8,
        expected_branch_commit: ?[]const u8,
        push_url: []const u8,
        hooks_path: []const u8,
    ) !void {
        const expected = expected_branch_commit orelse "";
        const hooks_arg = try std.fmt.allocPrint(self.gpa, "core.hooksPath={s}", .{hooks_path});
        const lease = try std.fmt.allocPrint(self.gpa, "--force-with-lease=refs/heads/{s}:{s}", .{ pkg.branch, expected });
        const branch_spec = try std.fmt.allocPrint(self.gpa, "HEAD:refs/heads/{s}", .{pkg.branch});
        const tag_spec = try std.fmt.allocPrint(self.gpa, "HEAD:refs/tags/{s}", .{tag});
        if (self.race_delete_branch and expected_branch_commit != null) {
            const del = try std.fmt.allocPrint(self.gpa, "refs/heads/{s}", .{pkg.branch});
            _ = try self.git(&.{ "push", "--delete", push_url, del }, true);
        }
        _ = try self.gitAt(worktree, &.{ "-c", hooks_arg, "push", "--quiet", "--atomic", "--no-verify", lease, push_url, branch_spec, tag_spec }, true);
    }

    fn removeWorktree(self: *Engine, worktree: []const u8, branch: ?[]const u8) void {
        if (self.pathExists(worktree)) {
            self.gitQuiet(self.root, &.{ "worktree", "remove", "--force", worktree });
        }
        if (self.pathExists(worktree)) {
            self.safeRemove(worktree, self.release_root) catch {};
        }
        self.gitQuiet(self.root, &.{ "worktree", "prune", "--expire", "now" });
        if (branch) |name| {
            self.gitQuiet(self.root, &.{ "branch", "-D", name });
        }
        var kept: std.ArrayList(Worktree) = .empty;
        for (self.active_worktrees.items) |item| {
            if (!std.mem.eql(u8, item.path, worktree)) kept.append(self.gpa, item) catch {};
        }
        self.active_worktrees = kept;
    }

    pub fn publish(self: *Engine, name: []const u8, dry_run: bool) ![]const u8 {
        const pkg = try self.package(name);
        try self.requireMainOwned(pkg);
        const seal = try self.loadSeal(pkg);
        const work = try self.cleanWork(pkg);
        const worktree = try self.join(&.{ work, "publication-worktree" });
        var temp_branch: ?[]const u8 = null;
        const result = self.publishInner(pkg, seal, work, worktree, &temp_branch, dry_run);
        self.removeWorktree(worktree, temp_branch);
        self.safeRemove(work, self.release_root) catch {};
        return result;
    }

    fn publishInner(
        self: *Engine,
        pkg: *Package,
        seal: Seal,
        work: []const u8,
        worktree: []const u8,
        temp_branch: *?[]const u8,
        dry_run: bool,
    ) ![]const u8 {
        const branch_state = try self.validateSeal(pkg, seal, work);
        const empty_hooks = try self.emptyHooksPath(work);
        const hooks_arg = try std.fmt.allocPrint(self.gpa, "core.hooksPath={s}", .{empty_hooks});
        _ = try self.git(&.{ "-c", hooks_arg, "worktree", "add", "--quiet", "--detach", "--no-checkout", worktree, "HEAD" }, true);
        if (branch_state.commit == null) {
            const now_ns = std.Io.Timestamp.now(self.io, .real).nanoseconds;
            temp_branch.* = try std.fmt.allocPrint(self.gpa, "package-release-{d}", .{now_ns});
            _ = try self.gitAt(worktree, &.{ "-c", hooks_arg, "switch", "--quiet", "--orphan", temp_branch.*.? }, true);
            const status = try self.gitAt(worktree, &.{ "status", "--porcelain=v1", "--untracked-files=all" }, true);
            if (status.len != 0) return self.fail("initial orphan publication worktree is not empty", .{});
        } else {
            const fetch_url = seal.remote.fetch_url;
            const branch_ref = try std.fmt.allocPrint(self.gpa, "refs/heads/{s}", .{pkg.branch});
            _ = try self.git(&.{ "fetch", "--quiet", "--no-tags", fetch_url, branch_ref }, true);
            const fetched = try self.git(&.{ "rev-parse", "FETCH_HEAD" }, true);
            if (!std.mem.eql(u8, fetched, branch_state.commit.?)) {
                return self.fail("release branch moved during publication setup", .{});
            }
            _ = try self.gitAt(worktree, &.{ "-c", hooks_arg, "switch", "--quiet", "--detach", fetched }, true);
            _ = try self.gitAt(worktree, &.{ "rm", "-r", "--quiet", "--ignore-unmatch", "--", "." }, true);
            _ = try self.gitAt(worktree, &.{ "clean", "-fdx", "--", "." }, true);
        }
        try self.active_worktrees.append(self.gpa, .{ .path = worktree, .branch = temp_branch.* });

        const stage = try self.stageDir(pkg);
        try self.copyTopLevelInto(stage, worktree);
        _ = try self.gitAt(worktree, &.{ "add", "--all", "--", "." }, true);
        try self.verifyIndex(worktree, stage);
        const message = try std.fmt.allocPrint(self.gpa, "{s}: release {s}\n\nSource-Commit: {s}", .{ pkg.name, seal.package.version, seal.source.commit });
        _ = try self.gitAt(worktree, &.{ "-c", hooks_arg, "commit", "--quiet", "--no-verify", "-m", message }, true);
        const release_commit = try self.gitAt(worktree, &.{ "rev-parse", "HEAD" }, true);
        try self.verifyCommitTree(worktree, release_commit, stage);
        const parents_out = try self.gitAt(worktree, &.{ "rev-list", "--parents", "-n", "1", "HEAD" }, true);
        var parents = std.mem.tokenizeAny(u8, parents_out, " \t");
        var parent_list: std.ArrayList([]const u8) = .empty;
        while (parents.next()) |parent| try parent_list.append(self.gpa, parent);
        if (branch_state.commit == null) {
            if (parent_list.items.len != 1) return self.fail("initial release commit has a parent", .{});
        } else {
            if (parent_list.items.len != 2 or !std.mem.eql(u8, parent_list.items[1], branch_state.commit.?)) {
                return self.fail("release commit is not a direct branch descendant", .{});
            }
        }

        const archive = try self.join(&.{ work, "prospective-package" });
        try self.extractArchive(worktree, release_commit, archive, null);
        _ = try self.validateTree(archive, pkg, true, true);
        const cache = try self.join(&.{ work, "prospective-cache" });
        const fetch_out = try self.runOut(work, &.{ "zig", "fetch", "--global-cache-dir", cache, archive });
        const release_hash = trimAscii(fetch_out);
        const prefix = try std.fmt.allocPrint(self.gpa, "{s}-", .{pkg.name});
        if (!std.mem.startsWith(u8, release_hash, prefix)) {
            return self.fail("{s}: Zig returned an unexpected release hash", .{pkg.name});
        }
        const tag = try std.fmt.allocPrint(self.gpa, "{s}/v{s}", .{ pkg.name, seal.package.version });
        try self.print("package: {s} {s}\n", .{ pkg.name, seal.package.version });
        try self.print("branch: {s}\n", .{pkg.branch});
        try self.print("parent: {s}\n", .{branch_state.commit orelse "<orphan>"});
        for (seal.dependencies) |dependency| {
            try self.print("dependency: {s} {s} {s}\n", .{ dependency.name, dependency.commit, dependency.hash });
        }
        try self.print("commit: {s}\n", .{release_commit});
        try self.print("hash: {s}\n", .{release_hash});
        try self.print("tag: {s}\n", .{tag});

        if (!dry_run) {
            _ = try self.validateSeal(pkg, seal, try self.join(&.{ work, "pre-push" }));
            try self.atomicPush(worktree, pkg, tag, branch_state.commit, seal.remote.push_url, empty_hooks);
            const push_url = seal.remote.push_url;
            const branch_ref = try std.fmt.allocPrint(self.gpa, "refs/heads/{s}", .{pkg.branch});
            const branch_remote = try remoteRef(self.gpa, self.io, push_url, branch_ref, self.root);
            const tag_remote = try remoteTagCommit(self.gpa, self.io, push_url, tag, self.root);
            const ok = branch_remote != null and std.mem.eql(u8, branch_remote.?, release_commit) and
                tag_remote != null and std.mem.eql(u8, tag_remote.?, release_commit);
            if (!ok) return self.fail("atomic publication verification failed", .{});
            try self.print("published {s} and {s} atomically\n", .{ pkg.branch, tag });
        } else {
            try self.print("dry-run: remote refs were not changed\n", .{});
        }
        return release_commit;
    }

    pub fn cleanup(self: *Engine) void {
        const items = self.gpa.dupe(Worktree, self.active_worktrees.items) catch return;
        var i = items.len;
        while (i > 0) {
            i -= 1;
            self.removeWorktree(items[i].path, items[i].branch);
        }
    }
};
