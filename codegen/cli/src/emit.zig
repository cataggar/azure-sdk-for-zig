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
    // Operator-owned test file. The emitter writes a stub the first
    // time a package is generated; on subsequent regenerations the
    // sync helper marks it as operator-managed (SKIP-and-warn) so
    // operator-added tests are preserved.
    try writeFile(
        allocator,
        io,
        out_dir,
        "src/clients_test.zig",
        \\//! Tests for the generated `clients.zig`.
        \\//!
        \\//! Kept in a separate file so the emitter can overwrite
        \\//! `clients.zig` without losing test coverage. Wired into the
        \\//! package's test step via `root.zig`.
        \\//!
        \\//! This file is **operator-owned**: `codegen/scripts/sync.sh`
        \\//! marks it as operator-managed and never overwrites an
        \\//! existing copy. Add tests freely.
        \\
        \\const std = @import("std");
        \\
    ,
        opts.run_zig_fmt,
    );
    try writeFile(allocator, io, out_dir, ".gitignore", "zig-cache/\nzig-out/\nzig-pkg/\n.zig-cache/\n", opts.run_zig_fmt);
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

    // Only re-export root clients; sub-clients are reachable through
    // accessor methods on their parent.
    for (model.clients) |c| {
        if (!c.is_root) continue;
        try w.print("pub const {s} = clients.{s};\n", .{ c.name, c.name });
    }

    // Pull in an operator-owned test file (if it exists) so package
    // tests stay reachable from `zig build test` across regenerations.
    // The file itself is hand-written and never overwritten by the
    // emitter; if it does not exist, the build will fail loudly — drop
    // the import or land a `clients_test.zig` in `src/`.
    try w.writeAll(
        \\
        \\test {
        \\    _ = @import("clients_test.zig");
        \\}
        \\
    );
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
        \\const serde = @import("serde");
        \\const core = @import("azure_core");
        \\const models = @import("models.zig");
        \\const enums = @import("enums.zig");
        \\
        \\
    );

    // Per-family constants (endpoint default, api-version default, auth
    // scopes) emitted next to the root client so callers can override
    // them via `InitOptions`.
    for (model.clients) |c| {
        if (!c.is_root) continue;
        try renderRootConstants(w, c);
    }

    for (model.clients) |c| {
        try renderClient(allocator, w, c);
        try w.writeAll("\n");
    }
    return try aw.toOwnedSlice();
}

fn renderRootConstants(w: *std.Io.Writer, c: cm.Client) !void {
    if (c.endpoint.default_value) |ep| {
        try w.print("const default_endpoint = \"{s}\";\n", .{ep});
    }
    if (c.api_version_default) |ver| {
        try w.print("const default_api_version = \"{s}\";\n", .{ver});
    }
    try w.writeAll("const auth_scopes: []const []const u8 = &.{");
    for (c.credential_scopes, 0..) |s, i| {
        if (i != 0) try w.writeAll(", ");
        try w.print("\"{s}\"", .{s});
    }
    try w.writeAll("};\n\n");
}

fn renderClient(allocator: std.mem.Allocator, w: *std.Io.Writer, c: cm.Client) !void {
    if (c.doc) |d| try renderDocComment(w, d);
    try w.print("pub const {s} = struct {{\n", .{c.name});

    // Common state — present on root *and* sub-clients so the
    // accessor on the root can splat-assign in one literal.
    try w.writeAll(
        \\    endpoint: []const u8,
        \\    api_version: []const u8,
        \\    pipeline: core.pipeline.HttpPipeline,
        \\
    );
    for (c.init_parameters) |p| {
        const id = try ids.quoteIfNeeded(allocator, p.name);
        defer allocator.free(id);
        const ty = try renderFieldType(allocator, p.param_type, p.optional, .clients);
        defer allocator.free(ty);
        try w.print("    {s}: {s},\n", .{ id, ty });
    }

    if (c.is_root) {
        // Root-only: own the bearer-token policy + policy_ptrs slice
        // and expose `init()`/`deinit()`.
        try w.writeAll(
            \\    allocator: std.mem.Allocator,
            \\    auth_policy: *core.pipeline.BearerTokenAuthPolicy,
            \\    policy_ptrs: []*core.pipeline.HttpPolicy,
            \\
        );
        try renderRootInit(allocator, w, c);
        try renderRootDeinit(w);
    }

    for (c.sub_clients) |sc| {
        try renderSubClientAccessor(w, c, sc);
    }

    for (c.methods) |m| {
        try renderMethod(allocator, w, c, m);
    }

    try w.writeAll("};\n");
}

fn renderRootInit(allocator: std.mem.Allocator, w: *std.Io.Writer, c: cm.Client) !void {
    try w.writeAll(
        \\
        \\    pub const InitOptions = struct {
        \\
    );
    for (c.init_parameters) |p| {
        const id = try ids.quoteIfNeeded(allocator, p.name);
        defer allocator.free(id);
        const ty = try renderFieldType(allocator, p.param_type, p.optional, .clients);
        defer allocator.free(ty);
        try w.print("        {s}: {s},\n", .{ id, ty });
    }
    try w.writeAll(
        \\        credential: *core.credentials.TokenCredential,
        \\        transport: *core.http.HttpTransport,
        \\
    );
    if (c.endpoint.default_value != null) {
        try w.writeAll("        endpoint: []const u8 = default_endpoint,\n");
    } else {
        try w.writeAll("        endpoint: []const u8,\n");
    }
    if (c.api_version_default != null) {
        try w.writeAll("        api_version: []const u8 = default_api_version,\n");
    } else {
        try w.writeAll("        api_version: []const u8,\n");
    }
    try w.writeAll(
        \\    };
        \\
        \\
    );

    try w.print(
        \\    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !{s} {{
        \\        const auth_policy = try allocator.create(core.pipeline.BearerTokenAuthPolicy);
        \\        errdefer allocator.destroy(auth_policy);
        \\        auth_policy.* = core.pipeline.BearerTokenAuthPolicy.init(
        \\            allocator,
        \\            options.credential,
        \\            auth_scopes,
        \\        );
        \\
        \\        const policy_ptrs = try allocator.alloc(*core.pipeline.HttpPolicy, 1);
        \\        errdefer allocator.free(policy_ptrs);
        \\        policy_ptrs[0] = auth_policy.asPolicy();
        \\
        \\        return .{{
        \\            .allocator = allocator,
        \\            .endpoint = options.endpoint,
        \\            .api_version = options.api_version,
        \\            .auth_policy = auth_policy,
        \\            .policy_ptrs = policy_ptrs,
        \\            .pipeline = .{{
        \\                .policies = policy_ptrs,
        \\                .transport_impl = options.transport,
        \\            }},
        \\
    , .{c.name});
    for (c.init_parameters) |p| {
        const id = try ids.quoteIfNeeded(allocator, p.name);
        defer allocator.free(id);
        try w.print("            .{s} = options.{s},\n", .{ id, id });
    }
    try w.writeAll(
        \\        };
        \\    }
        \\
    );
}

fn renderRootDeinit(w: *std.Io.Writer) !void {
    try w.writeAll(
        \\
        \\    pub fn deinit(self: *@This()) void {
        \\        self.auth_policy.deinit();
        \\        self.allocator.destroy(self.auth_policy);
        \\        self.allocator.free(self.policy_ptrs);
        \\    }
        \\
    );
}

fn renderSubClientAccessor(w: *std.Io.Writer, parent: cm.Client, sc: cm.SubClient) !void {
    try w.print(
        \\
        \\    pub fn {[acc]s}(self: *@This()) {[name]s} {{
        \\        return .{{
        \\            .endpoint = self.endpoint,
        \\            .api_version = self.api_version,
        \\            .pipeline = self.pipeline,
        \\
    , .{ .acc = sc.accessor_camel, .name = sc.client_name });
    for (parent.init_parameters) |p| {
        try w.print("            .{s} = self.{s},\n", .{ p.name, p.name });
    }
    try w.writeAll(
        \\        };
        \\    }
        \\
    );
}

// ─── method bodies ────────────────────────────────────────────────────

fn renderMethod(allocator: std.mem.Allocator, w: *std.Io.Writer, c: cm.Client, m: cm.Method) !void {
    if (m.doc) |d| try renderDocComment(w, d);

    // Return type depends on method kind.
    const ReturnKind = enum { void_op, value_op, list_op, lro_op };
    const ret_kind: ReturnKind = if (m.long_running != null)
        .lro_op
    else if (std.mem.eql(u8, m.kind, "paging") or std.mem.eql(u8, m.kind, "lropaging"))
        .list_op
    else if (m.response.response_type == null)
        .void_op
    else
        .value_op;

    const ret_str = try renderReturnType(allocator, m, ret_kind);
    defer allocator.free(ret_str);

    // Signature: `pub fn <name>(self: *@This(), alloc: std.mem.Allocator, <user params>) !<ret> {`
    try w.print("\n    pub fn {s}(self: *@This(), alloc: std.mem.Allocator", .{m.name_camel});
    for (m.user_parameters) |p| {
        const id = try ids.quoteIfNeeded(allocator, p.name);
        defer allocator.free(id);
        const ty = try renderFieldType(allocator, p.param_type, p.optional, .clients);
        defer allocator.free(ty);
        try w.print(", {s}: {s}", .{ id, ty });
    }
    try w.print(") !{s} {{\n", .{ret_str});

    // URL build (path + query) — shared by every kind.
    try renderUrlBuild(allocator, w, m);

    switch (ret_kind) {
        .list_op => try renderListBody(allocator, w, m),
        .void_op => try renderVoidBody(allocator, w, c, m),
        .value_op => try renderValueBody(allocator, w, c, m),
        .lro_op => try renderLroBody(allocator, w, c, m),
    }

    try w.writeAll("    }\n");
}

fn renderReturnType(allocator: std.mem.Allocator, m: cm.Method, kind: anytype) ![]u8 {
    return switch (kind) {
        .void_op => try allocator.dupe(u8, "void"),
        .value_op => blk: {
            const t = m.response.response_type.?;
            const ty = try types.renderType(allocator, t, .clients);
            break :blk ty;
        },
        .list_op => blk: {
            // Item type from paging metadata when the envelope is the
            // standard `{ value, nextLink }` shape; otherwise fall back
            // to the response type (already an array).
            const item_type_ref: ?cm.TypeRef = if (m.paging) |p| p.item_type else null;
            if (item_type_ref) |it| {
                const ty = try types.renderType(allocator, it, .clients);
                defer allocator.free(ty);
                break :blk try std.fmt.allocPrint(allocator, "core.pager.PipelinePager({s})", .{ty});
            }
            // No item_type? Fall back to the response type's element.
            if (m.response.response_type) |t| {
                const ty = try types.renderType(allocator, t, .clients);
                defer allocator.free(ty);
                // ty is `[]const X`. Strip the prefix to get X.
                const prefix = "[]const ";
                if (std.mem.startsWith(u8, ty, prefix)) {
                    const elem = ty[prefix.len..];
                    break :blk try std.fmt.allocPrint(allocator, "core.pager.PipelinePager({s})", .{elem});
                }
                break :blk try std.fmt.allocPrint(allocator, "core.pager.PipelinePager({s})", .{ty});
            }
            break :blk try allocator.dupe(u8, "core.pager.PipelinePager(std.json.Value)");
        },
        .lro_op => blk: {
            const final = if (m.long_running) |l| l.final_response_type else null;
            if (final) |t| {
                const ty = try types.renderType(allocator, t, .clients);
                defer allocator.free(ty);
                break :blk try std.fmt.allocPrint(allocator, "core.lro.TypedPoller({s})", .{ty});
            }
            break :blk try allocator.dupe(u8, "core.lro.TypedPoller(void)");
        },
    };
}

/// Render the `const url = ...` block. Path placeholders are
/// substituted by walking the operation path character-by-character
/// and replacing `{<wire_name>}` runs with `{s}`. Required query
/// parameters are appended inline to the head `allocPrint`. Optional
/// query parameters (typed as `?T` in the Zig signature) are
/// appended afterwards, each gated by `if (param) |v| { ... }`, with
/// values percent-encoded via `core.url.percentEncode`. The final
/// owned `[]u8` is exposed as `const url` and freed via `defer`.
fn renderUrlBuild(allocator: std.mem.Allocator, w: *std.Io.Writer, m: cm.Method) !void {
    var fmt_buf: std.ArrayList(u8) = .empty;
    defer fmt_buf.deinit(allocator);
    var args_buf: std.ArrayList(u8) = .empty;
    defer args_buf.deinit(allocator);

    // Endpoint first.
    try fmt_buf.appendSlice(allocator, "{s}");
    try args_buf.appendSlice(allocator, "self.endpoint");

    // Walk the path, substituting placeholders.
    var i: usize = 0;
    const path = m.path;
    while (i < path.len) {
        if (path[i] == '{') {
            const close = std.mem.indexOfScalarPos(u8, path, i + 1, '}') orelse break;
            const wire_name = path[i + 1 .. close];
            try fmt_buf.appendSlice(allocator, "{s}");
            const expr = try valueExpression(allocator, m.path_parameters, wire_name);
            defer allocator.free(expr);
            try args_buf.appendSlice(allocator, ", ");
            try args_buf.appendSlice(allocator, expr);
            i = close + 1;
        } else {
            try fmt_buf.append(allocator, path[i]);
            i += 1;
        }
    }

    // Partition query parameters: required (incl. constants/client) go
    // inline into the head allocPrint; optional ones are appended via
    // an ArrayList with conditional `if (...) |v|` blocks.
    var has_required_query = false;
    for (m.query_parameters) |qp| {
        if (qp.optional) continue;
        if (!has_required_query) {
            try fmt_buf.append(allocator, '?');
            has_required_query = true;
        } else {
            try fmt_buf.append(allocator, '&');
        }
        try fmt_buf.print(allocator, "{s}={{s}}", .{qp.wire_name});
        const expr = try sourceExpression(allocator, qp.source);
        defer allocator.free(expr);
        try args_buf.appendSlice(allocator, ", ");
        try args_buf.appendSlice(allocator, expr);
    }

    // Count optional query parameters to choose between the
    // single-allocPrint form (no optionals) and the ArrayList form.
    var optional_count: usize = 0;
    for (m.query_parameters) |qp| {
        if (qp.optional) optional_count += 1;
    }

    if (optional_count == 0) {
        try w.print(
            \\        const url = try std.fmt.allocPrint(alloc, "{s}", .{{ {s} }});
            \\        defer alloc.free(url);
            \\
        , .{ fmt_buf.items, args_buf.items });
        return;
    }

    // ArrayList form. Build the head, then append optional params.
    try w.print(
        \\        var url_buf: std.ArrayList(u8) = .empty;
        \\        defer url_buf.deinit(alloc);
        \\        try url_buf.print(alloc, "{s}", .{{ {s} }});
        \\
    , .{ fmt_buf.items, args_buf.items });

    // First-optional separator: `?` if no required query params, `&`
    // otherwise. We track this at runtime via a boolean so that any
    // mixture of populated optionals produces the right separators
    // even when several are null. The flag is only needed when there
    // are zero required query params; otherwise we always emit `&`.
    if (!has_required_query) {
        try w.writeAll("        var has_query: bool = false;\n");
    }

    for (m.query_parameters) |qp| {
        if (!qp.optional) continue;
        if (qp.source.name == null) continue;
        const user_id = try ids.quoteIfNeeded(allocator, qp.source.name.?);
        defer allocator.free(user_id);
        const inner_kind = innerOptionKind(m, qp);

        if (!has_required_query) {
            try renderOptionalAppendNoRequired(w, user_id, qp.wire_name, inner_kind);
        } else {
            try renderOptionalAppendWithRequired(w, user_id, qp.wire_name, inner_kind);
        }
    }

    try w.writeAll(
        \\        const url = try url_buf.toOwnedSlice(alloc);
        \\        defer alloc.free(url);
        \\
    );
}

const InnerKind = enum { string_like, enum_or_union, numeric, boolean };

fn innerOptionKind(m: cm.Method, qp: cm.WireParameter) InnerKind {
    // Look up the user parameter and inspect the inner Option type.
    const name = qp.source.name orelse return .string_like;
    for (m.user_parameters) |p| {
        if (!std.mem.eql(u8, p.name, name)) continue;
        const t = p.param_type;
        if (!t.isOption()) {
            return classifyTypeRef(t);
        }
        // Unwrap Option to peek at the inner kind.
        switch (t.value) {
            .object => |o| {
                const kind_v = o.get("kind") orelse return .string_like;
                const inner_kind_str = switch (kind_v) {
                    .string => |s| s,
                    else => return .string_like,
                };
                const value_v = o.get("value") orelse std.json.Value{ .null = {} };
                const inner = cm.TypeRef{ .kind = inner_kind_str, .value = value_v };
                return classifyTypeRef(inner);
            },
            else => return .string_like,
        }
    }
    return .string_like;
}

fn classifyTypeRef(t: cm.TypeRef) InnerKind {
    if (t.isEnum() or std.mem.eql(u8, t.kind, "Union")) return .enum_or_union;
    if (t.isScalar()) {
        const name = t.scalarName() orelse return .string_like;
        if (std.mem.eql(u8, name, "bool")) return .boolean;
        if (std.mem.startsWith(u8, name, "int") or
            std.mem.startsWith(u8, name, "uint") or
            std.mem.startsWith(u8, name, "float") or
            std.mem.eql(u8, name, "safeint") or
            std.mem.eql(u8, name, "integer") or
            std.mem.eql(u8, name, "numeric"))
        {
            return .numeric;
        }
        return .string_like;
    }
    return .string_like;
}

fn renderOptionalAppendWithRequired(
    w: *std.Io.Writer,
    user_id: []const u8,
    wire_name: []const u8,
    kind: InnerKind,
) !void {
    switch (kind) {
        .string_like => try w.print(
            \\        if ({s}) |v| {{
            \\            const enc = try core.url.percentEncode(alloc, v);
            \\            defer alloc.free(enc);
            \\            try url_buf.print(alloc, "&{s}={{s}}", .{{enc}});
            \\        }}
            \\
        , .{ user_id, wire_name }),
        .enum_or_union => try w.print(
            \\        if ({s}) |v| {{
            \\            const enc = try core.url.percentEncode(alloc, v.toWire());
            \\            defer alloc.free(enc);
            \\            try url_buf.print(alloc, "&{s}={{s}}", .{{enc}});
            \\        }}
            \\
        , .{ user_id, wire_name }),
        .numeric => try w.print(
            \\        if ({s}) |v| {{
            \\            try url_buf.print(alloc, "&{s}={{d}}", .{{v}});
            \\        }}
            \\
        , .{ user_id, wire_name }),
        .boolean => try w.print(
            \\        if ({s}) |v| {{
            \\            try url_buf.print(alloc, "&{s}={{}}", .{{v}});
            \\        }}
            \\
        , .{ user_id, wire_name }),
    }
}

fn renderOptionalAppendNoRequired(
    w: *std.Io.Writer,
    user_id: []const u8,
    wire_name: []const u8,
    kind: InnerKind,
) !void {
    switch (kind) {
        .string_like => try w.print(
            \\        if ({s}) |v| {{
            \\            const sep: []const u8 = if (has_query) "&" else "?";
            \\            const enc = try core.url.percentEncode(alloc, v);
            \\            defer alloc.free(enc);
            \\            try url_buf.print(alloc, "{{s}}{s}={{s}}", .{{ sep, enc }});
            \\            has_query = true;
            \\        }}
            \\
        , .{ user_id, wire_name }),
        .enum_or_union => try w.print(
            \\        if ({s}) |v| {{
            \\            const sep: []const u8 = if (has_query) "&" else "?";
            \\            const enc = try core.url.percentEncode(alloc, v.toWire());
            \\            defer alloc.free(enc);
            \\            try url_buf.print(alloc, "{{s}}{s}={{s}}", .{{ sep, enc }});
            \\            has_query = true;
            \\        }}
            \\
        , .{ user_id, wire_name }),
        .numeric => try w.print(
            \\        if ({s}) |v| {{
            \\            const sep: []const u8 = if (has_query) "&" else "?";
            \\            try url_buf.print(alloc, "{{s}}{s}={{d}}", .{{ sep, v }});
            \\            has_query = true;
            \\        }}
            \\
        , .{ user_id, wire_name }),
        .boolean => try w.print(
            \\        if ({s}) |v| {{
            \\            const sep: []const u8 = if (has_query) "&" else "?";
            \\            try url_buf.print(alloc, "{{s}}{s}={{}}", .{{ sep, v }});
            \\            has_query = true;
            \\        }}
            \\
        , .{ user_id, wire_name }),
    }
}

fn valueExpression(allocator: std.mem.Allocator, params: []cm.WireParameter, wire_name: []const u8) ![]u8 {
    for (params) |p| {
        if (std.mem.eql(u8, p.wire_name, wire_name)) {
            return sourceExpression(allocator, p.source);
        }
    }
    // Fallback to the placeholder name as-is (snake-cased) — keeps the
    // file compiling so the reviewer can spot the missing wire mapping.
    return try std.fmt.allocPrint(allocator, "\"<missing:{s}>\"", .{wire_name});
}

fn sourceExpression(allocator: std.mem.Allocator, src: cm.WireSource) ![]u8 {
    if (std.mem.eql(u8, src.kind, "constant")) {
        return try std.fmt.allocPrint(allocator, "\"{s}\"", .{src.value orelse ""});
    }
    if (std.mem.eql(u8, src.kind, "client")) {
        return try std.fmt.allocPrint(allocator, "self.{s}", .{src.name orelse "<missing>"});
    }
    // user
    return try ids.quoteIfNeeded(allocator, src.name orelse "<missing>");
}

fn renderListBody(allocator: std.mem.Allocator, w: *std.Io.Writer, m: cm.Method) !void {
    // Determine the item type T.
    const item_type_ref: ?cm.TypeRef = if (m.paging) |p| p.item_type else null;
    var item_ty: []u8 = undefined;
    if (item_type_ref) |t| {
        item_ty = try types.renderType(allocator, t, .clients);
    } else if (m.response.response_type) |t| {
        const ty = try types.renderType(allocator, t, .clients);
        defer allocator.free(ty);
        const prefix = "[]const ";
        if (std.mem.startsWith(u8, ty, prefix)) {
            item_ty = try allocator.dupe(u8, ty[prefix.len..]);
        } else {
            item_ty = try allocator.dupe(u8, ty);
        }
    } else {
        item_ty = try allocator.dupe(u8, "std.json.Value");
    }
    defer allocator.free(item_ty);

    try w.print(
        \\        return core.pager.PipelinePager({s}).init(
        \\            self.pipeline,
        \\            url,
        \\            alloc,
        \\            core.pager.listPageParser({s}),
        \\            "application/json",
        \\        );
        \\
    , .{ item_ty, item_ty });
}

fn renderRequestSetup(allocator: std.mem.Allocator, w: *std.Io.Writer, m: cm.Method) !void {
    const verb = try httpVerbZig(allocator, m.http_method);
    defer allocator.free(verb);
    try w.print(
        \\        var req = core.http.Request.init(alloc, .{s}, url);
        \\        defer req.deinit();
        \\
    , .{verb});

    // Render headers — every entry tagged `kind: "constant"` becomes a
    // `req.setHeader("Name", "value")` line. User-sourced headers are
    // out of scope for the initial emitter cut (AVS has none).
    for (m.header_parameters) |hp| {
        if (std.mem.eql(u8, hp.source.kind, "constant")) {
            try w.print("        try req.setHeader(\"{s}\", \"{s}\");\n", .{ hp.wire_name, hp.source.value orelse "" });
        }
    }

    if (m.body_parameter) |bp| {
        const id = try ids.quoteIfNeeded(allocator, bp.user_param_name);
        defer allocator.free(id);
        try w.print(
            \\        const body_json = try serde.json.toSlice(alloc, {s});
            \\        defer alloc.free(body_json);
            \\        req.body = body_json;
            \\
        , .{id});
    }
}

fn httpVerbZig(allocator: std.mem.Allocator, http_method: []const u8) ![]u8 {
    var upper = try allocator.alloc(u8, http_method.len);
    for (http_method, 0..) |c, i| upper[i] = std.ascii.toUpper(c);
    return upper;
}

fn renderVoidBody(allocator: std.mem.Allocator, w: *std.Io.Writer, c: cm.Client, m: cm.Method) !void {
    try renderRequestSetup(allocator, w, m);
    try w.print(
        \\
        \\        var resp = try self.pipeline.send(&req);
        \\        defer resp.deinit();
        \\
        \\        if (!resp.isSuccess()) {{
        \\            core.pager.logHttpError("{[client]s}.{[method]s}", resp.status_code, resp.body);
        \\            return error.AzureRequestFailed;
        \\        }}
        \\        return;
        \\
    , .{ .client = c.name, .method = m.name_camel });
}

fn renderValueBody(allocator: std.mem.Allocator, w: *std.Io.Writer, c: cm.Client, m: cm.Method) !void {
    try renderRequestSetup(allocator, w, m);
    const ty = try types.renderType(allocator, m.response.response_type.?, .clients);
    defer allocator.free(ty);
    try w.print(
        \\
        \\        var resp = try self.pipeline.send(&req);
        \\        defer resp.deinit();
        \\
        \\        if (!resp.isSuccess()) {{
        \\            core.pager.logHttpError("{[client]s}.{[method]s}", resp.status_code, resp.body);
        \\            return error.AzureRequestFailed;
        \\        }}
        \\        return try serde.json.fromSlice({[ty]s}, alloc, resp.body);
        \\
    , .{ .client = c.name, .method = m.name_camel, .ty = ty });
}

fn renderLroBody(allocator: std.mem.Allocator, w: *std.Io.Writer, c: cm.Client, m: cm.Method) !void {
    try renderRequestSetup(allocator, w, m);
    const final_ty = if (m.long_running) |l| l.final_response_type else null;
    var ty_owned: []u8 = undefined;
    if (final_ty) |t| {
        ty_owned = try types.renderType(allocator, t, .clients);
    } else {
        ty_owned = try allocator.dupe(u8, "void");
    }
    defer allocator.free(ty_owned);
    try w.print(
        \\
        \\        var resp = try self.pipeline.send(&req);
        \\        defer resp.deinit();
        \\
        \\        if (!resp.isSuccess()) {{
        \\            core.pager.logHttpError("{[client]s}.{[method]s}", resp.status_code, resp.body);
        \\            return error.AzureRequestFailed;
        \\        }}
        \\        return try core.lro.TypedPoller({[ty]s}).init(alloc, self.pipeline, resp, url, .{{}});
        \\
    , .{ .client = c.name, .method = m.name_camel, .ty = ty_owned });
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
                \\
                \\    pub fn toWire(self: @This()) []const u8 {
                \\        return core.open_enum.toWire(self, wire_names);
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
