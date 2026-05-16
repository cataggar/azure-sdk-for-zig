//! `codegen` — Azure SDK for Zig code generator CLI.
//!
//! Usage:
//!
//!     codegen --from-json <code-model.json> --out <output-dir>
//!     codegen --tsp <project-dir>           --out <output-dir>   (TODO: WASI host)
//!
//! In the JSON mode (P3 of the rollout) the generator skips the
//! TypeSpec stack entirely and reads a pre-built code model produced
//! by `eng/codegen/tcgc-component`. This lets the emitter be developed
//! and tested without the WASI host plumbing.

const std = @import("std");
const cm = @import("codemodel.zig");
const emit = @import("emit.zig");
const host = @import("host.zig");

const usage =
    \\codegen — Azure SDK for Zig code generator
    \\
    \\Usage:
    \\  codegen --from-json <code-model.json> --out <output-dir>
    \\          [--package-name <name>] [--azure-core-commit <sha>] [--no-fmt]
    \\
    \\  codegen --tsp <spec-dir> --wasm <tcgc.wasm> --out <output-dir>
    \\          [--package-name <name>] [--azure-core-commit <sha>] [--no-fmt]
    \\
;

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;

    var it = init.minimal.args.iterateAllocator(allocator) catch return 2;
    defer it.deinit();
    _ = it.skip();

    var json_path: ?[]const u8 = null;
    var tsp_dir: ?[]const u8 = null;
    var wasm_path: ?[]const u8 = null;
    var out_dir: ?[]const u8 = null;
    var package_name: ?[]const u8 = null;
    var azure_core_commit: ?[]const u8 = null;
    var run_fmt = true;

    while (it.next()) |a| {
        if (std.mem.eql(u8, a, "--from-json")) {
            json_path = it.next() orelse return die("--from-json requires a value");
        } else if (std.mem.eql(u8, a, "--tsp")) {
            tsp_dir = it.next() orelse return die("--tsp requires a value");
        } else if (std.mem.eql(u8, a, "--wasm")) {
            wasm_path = it.next() orelse return die("--wasm requires a value");
        } else if (std.mem.eql(u8, a, "--out")) {
            out_dir = it.next() orelse return die("--out requires a value");
        } else if (std.mem.eql(u8, a, "--package-name")) {
            package_name = it.next() orelse return die("--package-name requires a value");
        } else if (std.mem.eql(u8, a, "--azure-core-commit")) {
            azure_core_commit = it.next() orelse return die("--azure-core-commit requires a value");
        } else if (std.mem.eql(u8, a, "--no-fmt")) {
            run_fmt = false;
        } else if (std.mem.eql(u8, a, "--help") or std.mem.eql(u8, a, "-h")) {
            std.debug.print("{s}", .{usage});
            return 0;
        } else {
            std.debug.print("unknown arg: {s}\n\n{s}", .{ a, usage });
            return 2;
        }
    }

    if (json_path == null and tsp_dir == null) return die("--from-json or --tsp is required");
    if (tsp_dir != null and wasm_path == null) return die("--tsp requires --wasm <tcgc.wasm>");
    const od = out_dir orelse return die("--out is required");

    var pkg_name_buf: ?[]u8 = null;
    defer if (pkg_name_buf) |b| allocator.free(b);
    if (package_name) |p| pkg_name_buf = try allocator.dupe(u8, p);
    var commit_buf: ?[]u8 = null;
    defer if (commit_buf) |b| allocator.free(b);
    if (azure_core_commit) |c| commit_buf = try allocator.dupe(u8, c);

    const out_dir_owned = try allocator.dupe(u8, od);
    defer allocator.free(out_dir_owned);

    // Obtain the JSON code model — either from a precomputed file
    // (`--from-json`) or by invoking the WASI component (`--tsp`).
    var json_bytes_owned: []u8 = undefined;
    var json_owned_alloc = false;
    defer if (json_owned_alloc) allocator.free(json_bytes_owned);

    if (json_path) |jp| {
        const jp_owned = try allocator.dupe(u8, jp);
        defer allocator.free(jp_owned);
        json_bytes_owned = try std.Io.Dir.cwd().readFileAlloc(init.io, jp_owned, allocator, .limited(64 * 1024 * 1024));
        json_owned_alloc = true;
    } else {
        const td = tsp_dir.?;
        const wp = wasm_path.?;
        const td_owned = try allocator.dupe(u8, td);
        defer allocator.free(td_owned);
        const wp_owned = try allocator.dupe(u8, wp);
        defer allocator.free(wp_owned);

        const opts_json = if (pkg_name_buf) |n|
            try std.fmt.allocPrint(allocator, "{{\"package-name\":\"{s}\"}}", .{n})
        else
            try allocator.dupe(u8, "{}");
        defer allocator.free(opts_json);

        json_bytes_owned = try host.runFromFile(allocator, init.io, wp_owned, .{
            .spec_dir = td_owned,
            .emitter_options_json = opts_json,
        });
        json_owned_alloc = true;
    }

    var parsed = try std.json.parseFromSlice(
        cm.CodeModel,
        allocator,
        json_bytes_owned,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    try emit.emit(allocator, init.io, parsed.value, out_dir_owned, .{
        .package_name = pkg_name_buf,
        .azure_core_commit = commit_buf,
        .run_zig_fmt = run_fmt,
    });

    std.debug.print(
        "generated {s} → {s}\n",
        .{ parsed.value.package_name, out_dir_owned },
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
    _ = @import("host.zig");
}
