//! Release-input coherence gate; it does not grant review or qualification approval.
const std = @import("std");

const Dependency = struct {
    url: []const u8,
    hash: []const u8,
    path: ?[]const u8 = null,
};
const Manifest = struct {
    dependencies: struct {
        azure_sdk_core: Dependency,
        httpx: Dependency,
    },
};

fn fullCommit(value: []const u8) bool {
    if (value.len != 40) return false;
    for (value) |byte| if (!std.ascii.isDigit(byte) and (byte < 'a' or byte > 'f')) return false;
    return true;
}

fn immutable(dependency: Dependency) bool {
    if (dependency.path != null) return false;
    if (!std.mem.startsWith(u8, dependency.url, "git+https://github.com/")) return false;
    const marker = std.mem.lastIndexOfScalar(u8, dependency.url, '#') orelse return false;
    return fullCommit(dependency.url[marker + 1 ..]) and dependency.hash.len != 0;
}

fn same(a: Dependency, b: Dependency) bool {
    return std.mem.eql(u8, a.url, b.url) and std.mem.eql(u8, a.hash, b.hash);
}

fn validate(expected: []const u8, actual: []const u8, provider: Manifest, adapter: Manifest) !void {
    if (!fullCommit(expected)) return error.PendingImmutableSdkAdapterRelease;
    if (!std.mem.eql(u8, expected, actual)) return error.UnexpectedSdkAdapterCheckout;
    inline for (.{ provider.dependencies.azure_sdk_core, provider.dependencies.httpx, adapter.dependencies.azure_sdk_core, adapter.dependencies.httpx }) |dependency| {
        if (!immutable(dependency)) return error.NonImmutableDependency;
    }
    if (!same(provider.dependencies.azure_sdk_core, adapter.dependencies.azure_sdk_core))
        return error.CoreDependencyMismatch;
    if (!same(provider.dependencies.httpx, adapter.dependencies.httpx))
        return error.HttpxDependencyMismatch;
}

fn load(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Manifest {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024));
    defer allocator.free(bytes);
    const text = try allocator.dupeZ(u8, bytes);
    defer allocator.free(text);
    return std.zon.parse.fromSliceAlloc(Manifest, allocator, text, null, .{ .ignore_unknown_fields = true });
}

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    var args_arena = std.heap.ArenaAllocator.init(allocator);
    defer args_arena.deinit();
    const args = try init.minimal.args.toSlice(args_arena.allocator());
    if (args.len != 5) return error.ExpectedProviderManifestAdapterManifestExpectedCommitActualCommit;
    const provider = try load(allocator, init.io, args[1]);
    defer std.zon.parse.free(allocator, provider);
    const adapter = try load(allocator, init.io, args[2]);
    defer std.zon.parse.free(allocator, adapter);
    try validate(args[3], args[4], provider, adapter);
    std.debug.print("verified exact SDK checkout and matching immutable Core/HTTPX URL+hash inputs\n", .{});
}

const commit = "a" ** 40;
const fixture: Manifest = .{ .dependencies = .{
    .azure_sdk_core = .{ .url = "git+https://github.com/example/core#" ++ commit, .hash = "core-fixture" },
    .httpx = .{ .url = "git+https://github.com/example/httpx#" ++ commit, .hash = "httpx-fixture" },
} };

test "CI requires explicit immutable adapter input and exact checkout" {
    try std.testing.expectError(error.PendingImmutableSdkAdapterRelease, validate("", commit, fixture, fixture));
    try std.testing.expectError(error.PendingImmutableSdkAdapterRelease, validate("main", commit, fixture, fixture));
    try std.testing.expectError(error.UnexpectedSdkAdapterCheckout, validate(commit, "b" ** 40, fixture, fixture));
    try validate(commit, commit, fixture, fixture);
}

test "CI rejects differing Core and HTTPX package identities" {
    var other = fixture;
    other.dependencies.httpx.hash = "different";
    try std.testing.expectError(error.HttpxDependencyMismatch, validate(commit, commit, fixture, other));
    other = fixture;
    other.dependencies.azure_sdk_core.hash = "different";
    try std.testing.expectError(error.CoreDependencyMismatch, validate(commit, commit, fixture, other));
    other = fixture;
    other.dependencies.httpx.url = "git+https://github.com/example/httpx#" ++ "b" ** 40;
    try std.testing.expectError(error.HttpxDependencyMismatch, validate(commit, commit, fixture, other));
    other.dependencies.httpx.url = "git+https://github.com/example/httpx#main";
    try std.testing.expectError(error.NonImmutableDependency, validate(commit, commit, fixture, other));
}

test "CI reads ZON manifests without accepting path dependencies" {
    const allocator = std.testing.allocator;
    const text =
        \\.{
        \\ .name = .test_package,
        \\ .dependencies = .{
        \\  .azure_sdk_core = .{ .url = "git+https://github.com/example/core#aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", .hash = "core-fixture" },
        \\  .httpx = .{ .url = "git+https://github.com/example/httpx#aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", .hash = "httpx-fixture", .lazy = true },
        \\ },
        \\}
    ;
    const parsed = try std.zon.parse.fromSliceAlloc(Manifest, allocator, text, null, .{ .ignore_unknown_fields = true });
    defer std.zon.parse.free(allocator, parsed);
    try validate(commit, commit, fixture, parsed);
    const local = ".{ .dependencies = .{ .azure_sdk_core = .{ .path = \"../core\" }, .httpx = .{ .path = \"../httpx\" } } }";
    try std.testing.expectError(error.ParseZon, std.zon.parse.fromSliceAlloc(Manifest, allocator, local, null, .{ .ignore_unknown_fields = true }));
}

test "CI rejects local paths even when immutable pin fields are also present" {
    const allocator = std.testing.allocator;
    const text =
        \\.{
        \\ .dependencies = .{
        \\  .azure_sdk_core = .{ .url = "git+https://github.com/example/core#aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", .hash = "core-fixture" },
        \\  .httpx = .{ .url = "git+https://github.com/example/httpx#aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", .hash = "httpx-fixture", .path = "../httpx" },
        \\ },
        \\}
    ;
    const parsed = try std.zon.parse.fromSliceAlloc(Manifest, allocator, text, null, .{ .ignore_unknown_fields = true });
    defer std.zon.parse.free(allocator, parsed);
    try std.testing.expectError(error.NonImmutableDependency, validate(commit, commit, fixture, parsed));
    try std.testing.expectError(error.NonImmutableDependency, validate(commit, commit, parsed, fixture));
}
