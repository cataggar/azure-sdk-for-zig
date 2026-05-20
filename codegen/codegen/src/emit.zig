//! Emitter: walks a `CodeModel` and writes a tree of Zig source files
//! plus `build.zig` / `build.zig.zon` / `README.md` for an orphan
//! branch.
//!
//! The output looks like:
//!
//!   <out-dir>/
//!     build.zig
//!     build.zig.zon
//!     README.md
//!     tsp-location.yaml      (optional, written when caller supplies)
//!     src/
//!       root.zig             # re-exports
//!       clients.zig          # one struct per client
//!       models.zig
//!       enums.zig

const std = @import("std");
const cm = @import("codemodel.zig");
const naming = @import("naming.zig");
const types = @import("types.zig");
const ids = @import("identifiers.zig");

pub const EmitOptions = struct {
    /// Optional override of the package name. Defaults to
    /// `code_model.package_name`.
    package_name: ?[]const u8 = null,
    /// Commit SHA of the `azure-sdk-for-zig` main branch that the
    /// generated `build.zig.zon` should pin `azure_core` to. May be
    /// null during local development; in that case the generated
    /// build.zig.zon references `azure_core` by a local `path =` entry
    /// pointing relative to the worktree root.
    azure_core_commit: ?[]const u8 = null,
    /// Reserved for future use; running `zig fmt` is currently the
    /// caller's responsibility because the Zig 0.16 process API is in
    /// flux. The driver script in `codegen/scripts/generate.sh`
    /// runs `zig fmt` after emitting.
    run_zig_fmt: bool = true,
};

pub fn emit(
    allocator: std.mem.Allocator,
    io: std.Io,
    model: cm.CodeModel,
    out_dir_path: []const u8,
    opts: EmitOptions,
) !void {
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, out_dir_path);
    const src_path = try std.fs.path.join(allocator, &.{ out_dir_path, "src" });
    defer allocator.free(src_path);
    try cwd.createDirPath(io, src_path);

    const pkg_name = opts.package_name orelse model.package_name;

    {
        const s = try renderRoot(allocator, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir_path, "src/root.zig", s);
    }
    {
        const s = try renderClients(allocator, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir_path, "src/clients.zig", s);
    }
    {
        const s = try renderModels(allocator, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir_path, "src/models.zig", s);
    }
    {
        const s = try renderEnums(allocator, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir_path, "src/enums.zig", s);
    }
    {
        const s = try renderBuildZig(allocator, pkg_name);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir_path, "build.zig", s);
    }
    {
        const s = try renderBuildZigZon(allocator, pkg_name, model.package_version, opts.azure_core_commit);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir_path, "build.zig.zon", s);
    }
    {
        const s = try renderReadme(allocator, pkg_name, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir_path, "README.md", s);
    }
    try writeFile(allocator, io, out_dir_path, ".gitignore", "zig-cache/\nzig-out/\n.zig-cache/\n");
}

fn writeFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    out_dir_path: []const u8,
    sub_path: []const u8,
    content: []const u8,
) !void {
    const full = try std.fs.path.join(allocator, &.{ out_dir_path, sub_path });
    defer allocator.free(full);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = full, .data = content });
}

// ─── root.zig ─────────────────────────────────────────────────────────

fn renderRoot(allocator: std.mem.Allocator, model: cm.CodeModel) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const w = &aw.writer;

    try w.print(
        \\//! {[name]s} — generated from TypeSpec.
        \\//!
        \\//! Do not edit by hand. Regenerate with `codegen`.
        \\
        \\const clients = @import("clients.zig");
        \\pub const models = @import("models.zig");
        \\pub const enums = @import("enums.zig");
        \\
    , .{ .name = model.package_name });

    for (model.clients) |c| {
        try w.print("pub const {s} = clients.{s};\n", .{ c.name, c.name });
    }
    return try aw.toOwnedSlice();
}

// ─── clients.zig ──────────────────────────────────────────────────────

fn renderClients(allocator: std.mem.Allocator, model: cm.CodeModel) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const w = &aw.writer;

    try w.writeAll(
        \\//! Generated service clients.
        \\
        \\const std = @import("std");
        \\const core = @import("azure_core");
        \\const models = @import("models.zig");
        \\const enums = @import("enums.zig");
        \\
        \\
    );

    for (model.clients) |c| {
        try renderClient(allocator, w, c);
        try w.writeAll("\n");
    }
    return try aw.toOwnedSlice();
}

fn renderClient(allocator: std.mem.Allocator, w: *std.Io.Writer, c: cm.Client) !void {
    if (c.doc) |d| try renderDocComment(w, d);
    try w.print("pub const {s} = struct {{\n", .{c.name});
    try w.writeAll(
        \\    allocator: std.mem.Allocator,
        \\    pipeline: core.pipeline.HttpPipeline,
        \\    endpoint: []const u8,
        \\
    );

    try w.print(
        \\
        \\    pub fn init(
        \\        allocator: std.mem.Allocator,
        \\        endpoint: []const u8,
        \\        credential: core.credentials.TokenCredential,
        \\        transport: core.http.Transport,
        \\        options: ClientOptions,
        \\    ) {s} {{
        \\        _ = options;
        \\        _ = credential;
        \\        return .{{
        \\            .allocator = allocator,
        \\            .endpoint = endpoint,
        \\            .pipeline = core.pipeline.HttpPipeline.init(allocator, transport),
        \\        }};
        \\    }}
        \\
        \\    pub const ClientOptions = struct {{}};
        \\
    , .{c.name});

    for (c.methods) |m| {
        try renderMethod(allocator, w, m);
    }

    try w.writeAll("};\n");
}

fn renderMethod(allocator: std.mem.Allocator, w: *std.Io.Writer, m: cm.Method) !void {
    if (m.doc) |d| try renderDocComment(w, d);
    const camel = try naming.toCamelCase(allocator, m.name);
    defer allocator.free(camel);

    try w.print("    pub fn {s}(self: *@This()", .{camel});
    for (m.parameters) |p| {
        if (std.mem.eql(u8, p.location, "endpoint") or
            std.mem.eql(u8, p.location, "credential")) continue;
        const ty = try renderFieldType(allocator, p.param_type, p.optional, .clients);
        defer allocator.free(ty);
        const id = try ids.quoteIfNeeded(allocator, p.name);
        defer allocator.free(id);
        try w.print(", {s}: {s}", .{ id, ty });
    }
    if (m.response.response_type) |rt| {
        const ret = try types.renderType(allocator, rt, .clients);
        defer allocator.free(ret);
        try w.print(") !{s} {{\n", .{ret});
    } else {
        try w.writeAll(") !void {\n");
    }
    try w.writeAll("        _ = self;\n");
    for (m.parameters) |p| {
        if (std.mem.eql(u8, p.location, "endpoint") or
            std.mem.eql(u8, p.location, "credential")) continue;
        const id = try ids.quoteIfNeeded(allocator, p.name);
        defer allocator.free(id);
        try w.print("        _ = {s};\n", .{id});
    }
    try w.writeAll(
        \\        return error.NotImplemented;
        \\    }
        \\
    );
}

// ─── models.zig ───────────────────────────────────────────────────────

fn renderModels(allocator: std.mem.Allocator, model: cm.CodeModel) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const w = &aw.writer;

    try w.writeAll(
        \\//! Generated data-transfer-object models.
        \\
        \\const std = @import("std");
        \\const enums = @import("enums.zig");
        \\
        \\
    );
    for (model.models) |m| {
        if (m.doc) |d| try renderDocComment(w, d);
        try w.print("pub const {s} = struct {{\n", .{m.name});
        for (m.fields) |f| {
            if (f.doc) |d| {
                try w.writeAll("    ");
                try renderDocComment(w, d);
            }
            const ty = try renderFieldType(allocator, f.field_type, f.optional, .models);
            defer allocator.free(ty);
            const id = try ids.quoteIfNeeded(allocator, f.name);
            defer allocator.free(id);
            if (f.optional) {
                try w.print("    {s}: {s} = null,\n", .{ id, ty });
            } else {
                try w.print("    {s}: {s},\n", .{ id, ty });
            }
        }
        try w.writeAll("};\n\n");
    }
    return try aw.toOwnedSlice();
}

// ─── enums.zig ────────────────────────────────────────────────────────

fn renderEnums(allocator: std.mem.Allocator, model: cm.CodeModel) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const w = &aw.writer;

    try w.writeAll(
        \\//! Generated enums.
        \\//!
        \\//! Azure data-plane enums are typically *extensible* — the wire
        \\//! contract may grow with new values that older clients still
        \\//! need to round-trip. Represented as a tagged union with a
        \\//! catch-all `unknown` variant.
        \\
        \\const std = @import("std");
        \\
        \\
    );
    for (model.enums) |e| {
        if (e.doc) |d| try renderDocComment(w, d);
        if (e.extensible) {
            try w.print("pub const {s} = union(enum) {{\n", .{e.name});
            for (e.values) |v| {
                const snake = try naming.toSnakeCase(allocator, v.name);
                defer allocator.free(snake);
                const tag = try ids.quoteIfNeeded(allocator, snake);
                defer allocator.free(tag);
                try w.print("    {s},\n", .{tag});
            }
            try w.writeAll("    unknown: []const u8,\n};\n\n");
        } else {
            try w.print("pub const {s} = enum {{\n", .{e.name});
            for (e.values) |v| {
                const snake = try naming.toSnakeCase(allocator, v.name);
                defer allocator.free(snake);
                const tag = try ids.quoteIfNeeded(allocator, snake);
                defer allocator.free(tag);
                try w.print("    {s},\n", .{tag});
            }
            try w.writeAll("};\n\n");
        }
    }
    return try aw.toOwnedSlice();
}

// ─── build.zig / build.zig.zon ───────────────────────────────────────

fn renderBuildZig(allocator: std.mem.Allocator, pkg_name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\const std = @import("std");
        \\
        \\pub fn build(b: *std.Build) void {{
        \\    const target = b.standardTargetOptions(.{{}});
        \\    const optimize = b.standardOptimizeOption(.{{}});
        \\
        \\    const azure_sdk_dep = b.dependency("azure_sdk", .{{
        \\        .target = target,
        \\        .optimize = optimize,
        \\    }});
        \\    const azure_core_mod = azure_sdk_dep.module("azure_core");
        \\
        \\    _ = b.addModule("{[name]s}", .{{
        \\        .root_source_file = b.path("src/root.zig"),
        \\        .target = target,
        \\        .imports = &.{{
        \\            .{{ .name = "azure_core", .module = azure_core_mod }},
        \\        }},
        \\    }});
        \\
        \\    const t = b.addTest(.{{
        \\        .root_module = b.createModule(.{{
        \\            .root_source_file = b.path("src/root.zig"),
        \\            .target = target,
        \\            .optimize = optimize,
        \\            .imports = &.{{
        \\                .{{ .name = "azure_core", .module = azure_core_mod }},
        \\            }},
        \\        }}),
        \\    }});
        \\    const test_step = b.step("test", "Run unit tests");
        \\    test_step.dependOn(&b.addRunArtifact(t).step);
        \\}}
        \\
    , .{ .name = pkg_name });
}

fn renderBuildZigZon(
    allocator: std.mem.Allocator,
    pkg_name: []const u8,
    pkg_version: []const u8,
    azure_core_commit: ?[]const u8,
) ![]u8 {
    const azure_sdk_entry = if (azure_core_commit) |sha|
        try std.fmt.allocPrint(allocator,
            \\        .azure_sdk = .{{
            \\            .url = "git+https://github.com/cataggar/azure-sdk-for-zig#{s}",
            \\            // Hash is filled in by `zig fetch`; for now the orphan
            \\            // branch publishes without a pinned hash and the caller
            \\            // resolves it before commit.
            \\        }},
            \\
        , .{sha})
    else
        try allocator.dupe(u8,
            \\        .azure_sdk = .{
            \\            // During local development, point at the main worktree.
            \\            .path = "../azure-sdk-for-zig",
            \\        },
            \\
        );
    defer allocator.free(azure_sdk_entry);

    return std.fmt.allocPrint(allocator,
        \\.{{
        \\    .name = .{[name_id]s},
        \\    .version = "{[version]s}",
        \\    .fingerprint = 0x{[fp]x},
        \\    .minimum_zig_version = "0.16.0",
        \\    .dependencies = .{{
        \\{[sdk]s}    }},
        \\    .paths = .{{
        \\        "build.zig",
        \\        "build.zig.zon",
        \\        "src",
        \\        "README.md",
        \\    }},
        \\}}
        \\
    , .{
        .name_id = pkg_name,
        .version = pkg_version,
        .fp = computeFingerprint(pkg_name),
        .sdk = azure_sdk_entry,
    });
}

/// Build a build.zig.zon fingerprint that Zig will accept.
///
/// Zig requires the high 32 bits of the `.fingerprint` value to equal
/// CRC32-IEEE of the bare package name. The low 32 bits are a random /
/// project-specific value; we derive it deterministically from the
/// package name with Wyhash so successive regenerations don't churn the
/// file.
fn computeFingerprint(pkg_name: []const u8) u64 {
    const crc: u32 = std.hash.Crc32.hash(pkg_name);
    const wy: u64 = std.hash.Wyhash.hash(0xa11302, pkg_name);
    return (@as(u64, crc) << 32) | @as(u32, @truncate(wy));
}

fn renderReadme(allocator: std.mem.Allocator, pkg_name: []const u8, model: cm.CodeModel) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const w = &aw.writer;
    try w.print(
        \\# {[name]s}
        \\
        \\Generated Azure SDK client for Zig.
        \\
        \\This package is produced by `codegen` from the TypeSpec
        \\specification in [`Azure/azure-rest-api-specs`](https://github.com/Azure/azure-rest-api-specs).
        \\Do not edit the contents of `src/` by hand — they will be
        \\overwritten on the next regeneration.
        \\
        \\## Clients
        \\
    , .{ .name = pkg_name });
    for (model.clients) |c| {
        try w.print("- `{s}`\n", .{c.name});
    }
    try w.writeAll("\n");
    return try aw.toOwnedSlice();
}

// ─── helpers ──────────────────────────────────────────────────────────

fn renderDocComment(w: *std.Io.Writer, doc: []const u8) !void {
    var it = std.mem.splitScalar(u8, doc, '\n');
    while (it.next()) |line| try w.print("/// {s}\n", .{line});
}

/// Pick the right Zig type for a model field / method parameter:
///  * If the TypeRef is `Option<X>` we render `?X` regardless of the
///    `optional` flag.
///  * If `optional` is set but the TypeRef is not `Option<...>`, prefix
///    with `?` so the field can be omitted at serialization time.
///  * Otherwise render the TypeRef as-is.
fn renderFieldType(
    allocator: std.mem.Allocator,
    t: cm.TypeRef,
    optional: bool,
    scope: types.Scope,
) ![]u8 {
    if (t.isOption()) {
        return try types.renderType(allocator, t, scope);
    }
    if (optional) {
        const inner = try types.renderType(allocator, t, scope);
        defer allocator.free(inner);
        return try std.fmt.allocPrint(allocator, "?{s}", .{inner});
    }
    return try types.renderType(allocator, t, scope);
}
