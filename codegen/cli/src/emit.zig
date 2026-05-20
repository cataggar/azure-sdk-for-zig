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
    /// Optional human-readable label used in `README.md`'s H1 and the
    /// top-of-file doc comment in `src/root.zig`. Defaults to whatever
    /// `package_name` resolves to.
    ///
    /// In practice operators set this to the dash-cased package label
    /// (e.g. `arm-avs`, `keyvault-secrets`) so the docs read naturally
    /// while Zig module identifiers stay snake_case. Source: stripped
    /// from the `js:` field in `codegen/tspconfigs.yaml`
    /// (e.g. `@azure/arm-avs` → `arm-avs`).
    display_name: ?[]const u8 = null,
    /// Commit SHA of the `azure-sdk-for-zig` main branch that the
    /// generated `build.zig.zon` should pin `azure_core` to. May be
    /// null during local development; in that case the generated
    /// build.zig.zon references `azure_core` by a local `path =` entry
    /// pointing relative to the worktree root.
    azure_core_commit: ?[]const u8 = null,
    /// Run the in-process formatter (`std.zig.Ast.parse` +
    /// `renderAlloc`) on every `.zig` and `.zon` file before writing
    /// it out. Set to `false` to skip — useful when debugging emitter
    /// output that the parser rejects, since unparseable text would
    /// otherwise be written through as-is anyway (we fall back on
    /// parse failure to keep build errors visible).
    run_zig_fmt: bool = true,
};

pub fn emit(
    allocator: std.mem.Allocator,
    io: std.Io,
    out_dir: std.Io.Dir,
    model: cm.CodeModel,
    opts: EmitOptions,
) !void {
    try out_dir.createDirPath(io, "src");

    const pkg_name = opts.package_name orelse model.package_name;
    const display_name = opts.display_name orelse pkg_name;

    {
        const s = try renderRoot(allocator, model, display_name);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir, "src/root.zig", s, opts.run_zig_fmt);
    }
    {
        const s = try renderClients(allocator, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir, "src/clients.zig", s, opts.run_zig_fmt);
    }
    {
        const s = try renderModels(allocator, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir, "src/models.zig", s, opts.run_zig_fmt);
    }
    {
        const s = try renderEnums(allocator, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir, "src/enums.zig", s, opts.run_zig_fmt);
    }
    {
        const s = try renderBuildZig(allocator, pkg_name);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir, "build.zig", s, opts.run_zig_fmt);
    }
    {
        const s = try renderBuildZigZon(allocator, pkg_name, model.package_version, opts.azure_core_commit);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir, "build.zig.zon", s, opts.run_zig_fmt);
    }
    {
        const s = try renderReadme(allocator, display_name, model);
        defer allocator.free(s);
        try writeFile(allocator, io, out_dir, "README.md", s, opts.run_zig_fmt);
    }
    try writeFile(allocator, io, out_dir, ".gitignore", "zig-cache/\nzig-out/\n.zig-cache/\n", opts.run_zig_fmt);
}

/// Write `content` to `<out_dir>/<sub_path>`. When `fmt_enabled` is true
/// and the path looks like Zig (`.zig`) or ZON (`.zig.zon`), run the
/// in-process formatter (std.zig.Ast.parse + renderAlloc) first.
/// Parse failures fall back to writing the raw content so the operator
/// can diagnose them via the next `zig build` instead of having them
/// swallowed silently.
fn writeFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    out_dir: std.Io.Dir,
    sub_path: []const u8,
    content: []const u8,
    fmt_enabled: bool,
) !void {
    if (fmt_enabled) {
        const mode: ?std.zig.Ast.Mode =
            if (std.mem.endsWith(u8, sub_path, ".zon")) .zon else if (std.mem.endsWith(u8, sub_path, ".zig")) .zig else null;
        if (mode) |m| {
            if (try maybeFormat(allocator, content, m)) |formatted| {
                defer allocator.free(formatted);
                try out_dir.writeFile(io, .{ .sub_path = sub_path, .data = formatted });
                return;
            }
        }
    }
    try out_dir.writeFile(io, .{ .sub_path = sub_path, .data = content });
}

/// Parse + re-render `source` with `std.zig.Ast`. Returns null when the
/// parser reports any error — callers should fall back to writing the
/// raw source so build failures stay visible.
fn maybeFormat(
    allocator: std.mem.Allocator,
    source: []const u8,
    mode: std.zig.Ast.Mode,
) !?[]u8 {
    const zsource = try allocator.dupeZ(u8, source);
    defer allocator.free(zsource);
    var tree = try std.zig.Ast.parse(allocator, zsource, mode);
    defer tree.deinit(allocator);
    if (tree.errors.len != 0) return null;
    return try tree.renderAlloc(allocator);
}

// ─── root.zig ─────────────────────────────────────────────────────────

fn renderRoot(allocator: std.mem.Allocator, model: cm.CodeModel, display_name: []const u8) ![]u8 {
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
    , .{ .name = display_name });

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

    // Whether any generated struct will reference `core.arm.ResourceKind`.
    // If so, models.zig needs `const core = @import("azure_core");`.
    var needs_core = false;
    for (model.models) |m| {
        if (m.arm_resource_kind != null) {
            needs_core = true;
            break;
        }
    }

    try w.writeAll(
        \\//! Generated data-transfer-object models.
        \\
        \\const std = @import("std");
        \\const enums = @import("enums.zig");
        \\
    );
    if (needs_core) {
        try w.writeAll(
            \\const core = @import("azure_core");
            \\
        );
    }
    try w.writeAll("\n");

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
        // serde.zig honors this on (de)serialization: ARM and most data-plane
        // services emit camelCase JSON keys while Zig fields are snake_case.
        // Per-field `wireName` overrides from TCGC still win when present.
        try w.writeAll("\n    pub const serde = .{ .rename_all = .camel_case };\n");

        // ARM resource marker. Lets `core.arm` helpers like
        // `core.arm.id(&res)` / `core.arm.setTags(&res, ...)` dispatch
        // on the resource's base type at comptime, with zero runtime
        // cost. See `sdk/core/arm/resource.zig`.
        if (m.arm_resource_kind) |kind| {
            try w.print(
                "    pub const arm_resource_kind: core.arm.ResourceKind = .{s};\n",
                .{kind},
            );
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

    var any_extensible = false;
    for (model.enums) |e| {
        if (e.extensible) {
            any_extensible = true;
            break;
        }
    }

    try w.writeAll(
        \\//! Generated enums.
        \\//!
        \\//! Azure data-plane enums are typically *extensible* — the wire
        \\//! contract may grow with new values that older clients still
        \\//! need to round-trip. Represented as a tagged union with a
        \\//! catch-all `unrecognized` variant.
        \\
        \\const std = @import("std");
        \\
    );
    if (any_extensible) {
        try w.writeAll(
            \\const core = @import("azure_core");
            \\
        );
    }
    try w.writeAll("\n");
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
            try w.writeAll("    unrecognized: []const u8,\n\n");

            try w.writeAll("    const wire_names = .{\n");
            for (e.values) |v| {
                const snake = try naming.toSnakeCase(allocator, v.name);
                defer allocator.free(snake);
                const tag = try ids.quoteIfNeeded(allocator, snake);
                defer allocator.free(tag);
                const wire = wireNameForEnumValue(v);
                try w.print("        .{s} = \"{s}\",\n", .{ tag, wire });
            }
            try w.writeAll("    };\n\n");

            try w.writeAll(
                \\    pub fn zerdeDeserialize(
                \\        comptime T: type,
                \\        allocator: std.mem.Allocator,
                \\        deserializer: anytype,
                \\    ) @TypeOf(deserializer.*).Error!T {
                \\        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
                \\    }
                \\
                \\    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
                \\        return core.open_enum.serialize(self, wire_names, serializer);
                \\    }
                \\};
                \\
                \\
            );
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

/// Choose the JSON-wire string for an enum value. Prefers the explicit
/// `value` if it parsed as a string (TypeSpec allows `Foo: "wire-form"`);
/// falls back to the variant `name` otherwise.
fn wireNameForEnumValue(v: cm.EnumValue) []const u8 {
    return switch (v.value) {
        .string => |s| s,
        else => v.name,
    };
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

fn renderReadme(allocator: std.mem.Allocator, display_name: []const u8, model: cm.CodeModel) ![]u8 {
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
    , .{ .name = display_name });
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

// ─── tests ────────────────────────────────────────────────────────────

test "display_name surfaces in root.zig + README, not build.zig" {
    const testing = std.testing;
    const alloc = testing.allocator;

    const model: cm.CodeModel = .{
        .package_name = "arm_avs",
        .package_version = "0.1.0",
        .target_kind = "arm",
        .service_kind = "default",
    };

    const root = try renderRoot(alloc, model, "arm-avs");
    defer alloc.free(root);
    try testing.expect(std.mem.indexOf(u8, root, "//! arm-avs — generated") != null);
    try testing.expect(std.mem.indexOf(u8, root, "arm_avs") == null);

    const readme = try renderReadme(alloc, "arm-avs", model);
    defer alloc.free(readme);
    try testing.expect(std.mem.indexOf(u8, readme, "# arm-avs\n") != null);
    try testing.expect(std.mem.indexOf(u8, readme, "arm_avs") == null);

    // build.zig and build.zig.zon stay on the snake-cased package name —
    // Zig module identifiers (and `addModule` keys) must be snake_case.
    const build_zig = try renderBuildZig(alloc, "arm_avs");
    defer alloc.free(build_zig);
    try testing.expect(std.mem.indexOf(u8, build_zig, "\"arm_avs\"") != null);
    try testing.expect(std.mem.indexOf(u8, build_zig, "arm-avs") == null);

    const zon = try renderBuildZigZon(alloc, "arm_avs", "0.1.0", null);
    defer alloc.free(zon);
    try testing.expect(std.mem.indexOf(u8, zon, ".name = .arm_avs") != null);
    try testing.expect(std.mem.indexOf(u8, zon, "arm-avs") == null);
}
