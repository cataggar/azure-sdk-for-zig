//! `codegen-cli` — wasi:cli/run command that compiles a TypeSpec spec
//! into a Zig package.
//!
//! Run inside wasmtime against the composed component
//! (`codegen-cli + tcgc.wasm`):
//!
//!     wasmtime run --dir <spec>::/spec --dir <out>::/out \
//!         codegen-cli.composed.wasm /spec /out [--package-name foo]
//!
//! The composition is produced by `codegen/cli/build.sh` from
//!
//!     codegen-cli.wasm  (this binary, compiled to wasm32-wasi and
//!                        wrapped into a component via wabt)
//!     tcgc.wasm         (codegen/tcgc-component output)
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

    // Resolve `<out-dir>` (a WASI preopen path like `/out`) to a
    // `std.Io.Dir`. WASI doesn't permit opening absolute paths from
    // an arbitrary fd, so we look up the preopen `start.zig` already
    // resolved at startup.
    const out_dir_handle = blk: {
        const res = init.preopens.get(od_owned) orelse {
            std.debug.print("no WASI preopen matches '{s}'\n", .{od_owned});
            return 2;
        };
        switch (res) {
            .dir => |d| break :blk d,
            .file => {
                std.debug.print("preopen '{s}' is a file, expected a directory\n", .{od_owned});
                return 2;
            },
        }
    };

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
    //
    // Emit JSON via std.json so embedded user values + the inlined
    // spec-files map (potentially MBs of TypeSpec source) are escaped
    // correctly.
    var stream: std.Io.Writer.Allocating = .init(allocator);
    defer stream.deinit();
    var ws = std.json.Stringify{ .writer = &stream.writer };

    try ws.beginObject();
    if (pkg_buf) |n| {
        try ws.objectField("package-name");
        try ws.write(n);
    }
    if (ver_buf) |v| {
        try ws.objectField("package-version");
        try ws.write(v);
    }
    try ws.objectField("__spec_files");
    try ws.beginObject();
    std.debug.print("collecting spec files from {s}\n", .{sd_owned});
    try collectFiles(allocator, init, &ws, sd_owned, .spec);
    // Walk every WASI preopen whose virtual path starts with
    // `/node_modules/` — those are stdlib package roots passed in by
    // the wrapper script (`scripts/run.sh`). Their `.tsp` and
    // `package.json` files are merged into the same `__spec_files`
    // object: the JS host's `virtualFsSources` map sees them at the
    // exact paths the TypeSpec resolver computes from package
    // metadata.
    {
        var pi = init.preopens.map.iterator();
        while (pi.next()) |kv| {
            const name = kv.key_ptr.*;
            if (!std.mem.startsWith(u8, name, "/node_modules/")) continue;
            std.debug.print("collecting stdlib files from {s}\n", .{name});
            try collectFiles(allocator, init, &ws, name, .stdlib);
        }
    }
    try ws.endObject();
    try ws.endObject();
    std.debug.print("emitter-options size = {d} bytes\n", .{stream.written().len});

    // ── Call into the TCGC component over the WIT boundary ────────────
    std.debug.print("calling tcgc.compile...\n", .{});
    const json = tcgc.invoke(allocator, sd_owned, stream.written()) catch |err| switch (err) {
        error.CompileFailed => |e| {
            std.debug.print("tcgc compile failed\n", .{});
            return e;
        },
        else => |e| return e,
    };
    defer allocator.free(json);
    std.debug.print("got {d} bytes back from tcgc.compile\n", .{json.len});

    // ── Deserialize and emit ─────────────────────────────────────────
    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        allocator,
        json,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try emit.emit(allocator, io, out_dir_handle, parsed.value, .{
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

/// Source kind for `collectFiles`.
///
/// - `.spec`  — user TypeSpec spec dir. Includes `.tsp` and the
///              auxiliary config formats TypeSpec may resolve from a
///              spec dir (`.yaml`, `.yml`, `.json`).
/// - `.stdlib` — vendored TypeSpec package root. Only `.tsp` files
///              and `package.json` are needed; everything else is
///              either bundled (`.js`) or irrelevant to module
///              resolution.
const SourceKind = enum { spec, stdlib };

/// Recursively walk `preopen_path` and emit object entries
/// `"<absolute-virtual-path>": "<file-contents>"` for each file the
/// `kind` filter accepts. `ws` must be inside an open object (the
/// caller emits the wrapping `{}`).
///
/// The JS side of the bridge merges every entry into its
/// `virtualFsSources` map before driving the TypeSpec compiler — the
/// compiler's resolver then sees the spec and stdlib files as plain
/// in-memory reads. This keeps the JS guest free of any wasi:filesystem
/// JS shim (StarlingMonkey doesn't polyfill `node:fs`), so the Zig
/// host is the sole filesystem consumer.
fn collectFiles(
    allocator: std.mem.Allocator,
    init: std.process.Init,
    ws: *std.json.Stringify,
    preopen_path: []const u8,
    kind: SourceKind,
) !void {
    const io = init.io;

    // WASI doesn't support opening absolute paths from an arbitrary
    // fd; resolve `preopen_path` to one of the preopens passed in by
    // wasmtime (`--dir <host>::<preopen_path>`). `init.preopens` is
    // populated by `start.zig` from `fd_prestat_get` enumeration.
    const resource = init.preopens.get(preopen_path) orelse {
        std.debug.print(
            "collectFiles: no WASI preopen matches '{s}'\n",
            .{preopen_path},
        );
        return error.PermissionDenied;
    };
    var dir = switch (resource) {
        .dir => |d| d,
        .file => {
            std.debug.print(
                "collectFiles: preopen '{s}' is a file, expected a directory\n",
                .{preopen_path},
            );
            return error.NotDir;
        },
    };

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (true) {
        const maybe_entry = walker.next(io) catch |err| {
            // WASI is strict about symlinks/relative paths that
            // escape the preopen — surface and skip rather than
            // failing the whole collection.
            std.debug.print("collectFiles: walk error: {s}\n", .{@errorName(err)});
            continue;
        };
        const entry = maybe_entry orelse break;
        if (entry.kind != .file) continue;
        if (!acceptFile(entry.basename, kind)) continue;

        // entry.path is relative to preopen_path; build the absolute
        // virtual path the JS bridge will key into virtualFsSources.
        const full = try std.fs.path.join(allocator, &.{ preopen_path, entry.path });
        defer allocator.free(full);

        const content = dir.readFileAlloc(io, entry.path, allocator, .limited(8 * 1024 * 1024)) catch |err| {
            std.debug.print("collectFiles: skipping {s}: {s}\n", .{ full, @errorName(err) });
            continue;
        };
        defer allocator.free(content);

        try ws.objectField(full);
        try ws.write(content);
    }
}

fn acceptFile(name: []const u8, kind: SourceKind) bool {
    return switch (kind) {
        .spec => for ([_][]const u8{ ".tsp", ".yaml", ".yml", ".json" }) |ext| {
            if (std.mem.endsWith(u8, name, ext)) break true;
        } else false,
        .stdlib => std.mem.endsWith(u8, name, ".tsp") or std.mem.eql(u8, name, "package.json"),
    };
}

test {
    _ = @import("naming.zig");
    _ = @import("codemodel.zig");
    _ = @import("types.zig");
    _ = @import("emit.zig");
    _ = @import("identifiers.zig");
}
