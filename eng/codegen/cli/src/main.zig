//! `codegen-cli` — wasi:cli/run command that compiles a TypeSpec spec
//! into a Zig package.
//!
//! Run inside wasmtime against the composed component
//! (`codegen-cli + tcgc.wasm`):
//!
//!     wasmtime run --dir <spec>::/spec --dir <out>::/out \
//!         codegen-cli.composed.wasm /spec /out [--package-name foo]
//!
//! The composition is produced by `eng/codegen/cli/build.sh` from
//!
//!     codegen-cli.wasm  (this binary, compiled to wasm32-wasi and
//!                        wrapped into a component via wabt)
//!     tcgc.wasm         (eng/codegen/tcgc-component output)
//!
//! Architecture summary:
//!   * `main` parses argv (positional: spec-dir, out-dir; flag:
//!     --package-name, --package-version, --azure-core-commit,
//!     --no-fmt).
//!   * Calls `tcgc.compile(/spec, emitter-options-json)` via the
//!     hand-rolled canonical-ABI binding in `tcgc_import.zig`.
//!   * Parses the JSON code model via `codemodel.zig` (std.json).
//!   * Emits Zig source into `/out` via the existing `emit.zig`
//!     module.
//!
//! No host code on the embedder side: the entire pipeline runs as
//! WASI under wasmtime.

const std = @import("std");
const cm = @import("codemodel.zig");
const emit = @import("emit.zig");
const tcgc = @import("tcgc_import.zig");

// Force-instantiate the canonical-ABI surface (in particular
// `cabi_realloc`, which is dead-code-eliminated from a sibling
// module unless something here references it).
comptime {
    _ = tcgc;
}

const usage =
    \\codegen-cli — Azure SDK for Zig code generator (wasi:cli/run component)
    \\
    \\Usage:
    \\  codegen-cli <spec-dir> <out-dir>
    \\              [--package-name <name>] [--package-version <ver>]
    \\              [--azure-core-commit <sha>] [--no-fmt]
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    const io = init.io;

    var it = init.minimal.args.iterateAllocator(allocator) catch return 2;
    defer it.deinit();
    _ = it.skip();

    var spec_dir: ?[]const u8 = null;
    var out_dir: ?[]const u8 = null;
    var package_name: ?[]const u8 = null;
    var package_version: ?[]const u8 = null;
    var azure_core_commit: ?[]const u8 = null;
    var run_fmt = true;

    while (it.next()) |a| {
        if (std.mem.eql(u8, a, "--package-name")) {
            package_name = it.next() orelse return die("--package-name requires a value");
        } else if (std.mem.eql(u8, a, "--package-version")) {
            package_version = it.next() orelse return die("--package-version requires a value");
        } else if (std.mem.eql(u8, a, "--azure-core-commit")) {
            azure_core_commit = it.next() orelse return die("--azure-core-commit requires a value");
        } else if (std.mem.eql(u8, a, "--no-fmt")) {
            run_fmt = false;
        } else if (std.mem.eql(u8, a, "--help") or std.mem.eql(u8, a, "-h")) {
            std.debug.print("{s}", .{usage});
            return 0;
        } else if (std.mem.startsWith(u8, a, "--")) {
            std.debug.print("unknown flag: {s}\n\n{s}", .{ a, usage });
            return 2;
        } else if (spec_dir == null) {
            spec_dir = a;
        } else if (out_dir == null) {
            out_dir = a;
        } else {
            std.debug.print("unexpected positional arg: {s}\n\n{s}", .{ a, usage });
            return 2;
        }
    }

    const sd = spec_dir orelse return die("missing positional: <spec-dir>");
    const od = out_dir orelse return die("missing positional: <out-dir>");

    const sd_owned = try allocator.dupe(u8, sd);
    defer allocator.free(sd_owned);
    const od_owned = try allocator.dupe(u8, od);
    defer allocator.free(od_owned);

    var pkg_buf: ?[]u8 = null;
    defer if (pkg_buf) |b| allocator.free(b);
    if (package_name) |p| pkg_buf = try allocator.dupe(u8, p);

    var ver_buf: ?[]u8 = null;
    defer if (ver_buf) |b| allocator.free(b);
    if (package_version) |v| ver_buf = try allocator.dupe(u8, v);

    var commit_buf: ?[]u8 = null;
    defer if (commit_buf) |b| allocator.free(b);
    if (azure_core_commit) |c| commit_buf = try allocator.dupe(u8, c);

    // ── Build emitter-options JSON ────────────────────────────────────
    var opts_buf: std.ArrayList(u8) = .empty;
    defer opts_buf.deinit(allocator);
    try opts_buf.appendSlice(allocator, "{");
    var any: bool = false;
    if (pkg_buf) |n| {
        try opts_buf.appendSlice(allocator, "\"package-name\":\"");
        try opts_buf.appendSlice(allocator, n);
        try opts_buf.appendSlice(allocator, "\"");
        any = true;
    }
    if (ver_buf) |v| {
        if (any) try opts_buf.appendSlice(allocator, ",");
        try opts_buf.appendSlice(allocator, "\"package-version\":\"");
        try opts_buf.appendSlice(allocator, v);
        try opts_buf.appendSlice(allocator, "\"");
        any = true;
    }
    try opts_buf.appendSlice(allocator, "}");

    // ── Call into the TCGC component over the WIT boundary ────────────
    const json = tcgc.invoke(allocator, sd_owned, opts_buf.items) catch |err| switch (err) {
        error.CompileFailed => |e| {
            std.debug.print("tcgc compile failed\n", .{});
            return e;
        },
        else => |e| return e,
    };
    defer allocator.free(json);

    // ── Deserialize and emit ─────────────────────────────────────────
    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try emit.emit(allocator, io, parsed.value, od_owned, .{
        .package_name = pkg_buf,
        .azure_core_commit = commit_buf,
        .run_zig_fmt = run_fmt,
    });

    std.debug.print(
        "generated {s} → {s}\n",
        .{ parsed.value.package_name, od_owned },
    );
    return 0;
}

fn die(msg: []const u8) u8 {
    std.debug.print("{s}\n\n{s}", .{ msg, usage });
    return 2;
}

test {
    _ = @import("naming.zig");
    _ = @import("codemodel.zig");
    _ = @import("types.zig");
    _ = @import("emit.zig");
    _ = @import("identifiers.zig");
}
