//! tspconfigs — manage eng/codegen/tspconfigs.yaml
//!
//! Subcommands:
//!   update   Reconcile entries against ../azure-rest-api-specs (add/remove
//!            groups based on whether each tspconfig.yaml exists). Preserves
//!            previously-resolved fields (js/zig).
//!   resolve  For each entry, parse the underlying tspconfig.yaml in
//!            ../azure-rest-api-specs and derive:
//!              js   — the @azure-tools/typespec-ts package-details name
//!                     verbatim (e.g. "@azure/ai-agents",
//!                     "@azure-rest/ai-document-intelligence")
//!              zig  — js with any leading "@scope/" namespace stripped
//!                     and '-' replaced by '_'
//!                     (e.g. "ai_agents", "ai_document_intelligence")
//!
//! Working directory is expected to be the repository root. The build steps
//! in build.zig set this via setCwd.

const std = @import("std");

const PACKAGES_TXT = "eng/codegen/typespec-packages.txt";
const OUT_YAML = "eng/codegen/tspconfigs.yaml";
const SPECS_ROOT = "../azure-rest-api-specs";

const Entry = struct {
    path: []const u8,
    js: []const u8 = "",
    zig: []const u8 = "",
};

pub fn main(init: std.process.Init) !u8 {
    const alloc = init.arena.allocator();
    const io = init.io;

    const args = try init.minimal.args.toSlice(alloc);
    if (args.len < 2) {
        std.debug.print("usage: tspconfigs <update|resolve>\n", .{});
        return 2;
    }
    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "update")) {
        try cmdUpdate(alloc, io);
    } else if (std.mem.eql(u8, cmd, "resolve")) {
        try cmdResolve(alloc, io);
    } else {
        std.debug.print("unknown command: {s}\n", .{cmd});
        return 2;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// update
// ---------------------------------------------------------------------------

fn cmdUpdate(alloc: std.mem.Allocator, io: std.Io) !void {
    const txt = try readFile(alloc, io, PACKAGES_TXT, 16 * 1024 * 1024);

    var paths: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, txt, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0) continue;
        if (line[0] == '#') continue;
        try paths.append(alloc, line);
    }
    std.mem.sort([]const u8, paths.items, {}, lessThanStr);

    var existing = try loadYaml(alloc, io, OUT_YAML);

    var out: std.ArrayList(Entry) = .empty;
    var added: usize = 0;
    var kept: usize = 0;
    var removed: usize = 0;

    var seen_in_txt = std.StringHashMap(void).init(alloc);
    for (paths.items) |p| {
        try seen_in_txt.put(p, {});
        const abs = try std.fs.path.join(alloc, &.{ SPECS_ROOT, p });
        const exists = fileExists(io, abs);
        if (!exists) {
            if (existing.contains(p)) removed += 1;
            continue;
        }
        if (existing.get(p)) |e| {
            try out.append(alloc, e);
            kept += 1;
        } else {
            try out.append(alloc, .{ .path = p });
            added += 1;
        }
    }

    var ex_iter = existing.iterator();
    while (ex_iter.next()) |kv| {
        if (!seen_in_txt.contains(kv.key_ptr.*)) removed += 1;
    }

    try writeYaml(alloc, io, OUT_YAML, out.items);

    std.debug.print(
        "tspconfigs update: {d} entries ({d} added, {d} kept, {d} removed)\n",
        .{ out.items.len, added, kept, removed },
    );
}

// ---------------------------------------------------------------------------
// resolve
// ---------------------------------------------------------------------------

fn cmdResolve(alloc: std.mem.Allocator, io: std.Io) !void {
    var existing = try loadYaml(alloc, io, OUT_YAML);

    var keys: std.ArrayList([]const u8) = .empty;
    var it = existing.iterator();
    while (it.next()) |kv| try keys.append(alloc, kv.key_ptr.*);
    std.mem.sort([]const u8, keys.items, {}, lessThanStr);

    var out: std.ArrayList(Entry) = .empty;
    var resolved: usize = 0;
    var unresolved: usize = 0;

    for (keys.items) |k| {
        var e = existing.get(k).?;
        const abs = try std.fs.path.join(alloc, &.{ SPECS_ROOT, k });
        const maybe_name = extractTsPackageName(alloc, io, abs) catch null;
        if (maybe_name) |js_name| {
            e.js = js_name;
            e.zig = try toZigName(alloc, js_name);
            resolved += 1;
        } else {
            unresolved += 1;
        }
        try out.append(alloc, e);
    }

    try writeYaml(alloc, io, OUT_YAML, out.items);

    std.debug.print(
        "tspconfigs resolve: {d} resolved, {d} unresolved\n",
        .{ resolved, unresolved },
    );
}

// ---------------------------------------------------------------------------
// I/O helpers
// ---------------------------------------------------------------------------

fn readFile(alloc: std.mem.Allocator, io: std.Io, sub_path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.readFileAlloc(.cwd(), io, sub_path, alloc, .limited(limit));
}

fn readFileOptional(alloc: std.mem.Allocator, io: std.Io, sub_path: []const u8, limit: usize) !?[]u8 {
    return std.Io.Dir.readFileAlloc(.cwd(), io, sub_path, alloc, .limited(limit)) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
}

fn fileExists(io: std.Io, sub_path: []const u8) bool {
    _ = std.Io.Dir.statFile(.cwd(), io, sub_path, .{}) catch return false;
    return true;
}

fn writeFile(io: std.Io, sub_path: []const u8, data: []const u8) !void {
    try std.Io.Dir.writeFile(.cwd(), io, .{ .sub_path = sub_path, .data = data });
}

// ---------------------------------------------------------------------------
// yaml read/write (narrow custom format)
// ---------------------------------------------------------------------------

const EntryMap = std.StringHashMap(Entry);

fn loadYaml(alloc: std.mem.Allocator, io: std.Io, file_path: []const u8) !EntryMap {
    var map = EntryMap.init(alloc);
    const maybe_data = try readFileOptional(alloc, io, file_path, 16 * 1024 * 1024);
    const data = maybe_data orelse return map;

    var cur_key: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len == 0) continue;
        if (line[0] == '#') continue;

        if (line[0] == '"') {
            const end_quote = std.mem.indexOfScalarPos(u8, line, 1, '"') orelse continue;
            const path = try alloc.dupe(u8, line[1..end_quote]);
            const gop = try map.getOrPut(path);
            gop.value_ptr.* = .{ .path = path };
            cur_key = gop.key_ptr.*;
            continue;
        }

        if (line[0] != ' ') {
            cur_key = null;
            continue;
        }
        const trimmed = std.mem.trim(u8, line, " \t");
        const colon = std.mem.indexOfScalar(u8, trimmed, ':') orelse continue;
        const key = trimmed[0..colon];
        var val = std.mem.trim(u8, trimmed[colon + 1 ..], " \t");
        if (val.len >= 2 and val[0] == '"' and val[val.len - 1] == '"') {
            val = val[1 .. val.len - 1];
        }
        const val_owned = try alloc.dupe(u8, val);
        if (cur_key) |ck| {
            const ePtr = map.getPtr(ck) orelse continue;
            if (std.mem.eql(u8, key, "js")) ePtr.js = val_owned
            else if (std.mem.eql(u8, key, "zig")) ePtr.zig = val_owned;
        }
    }
    return map;
}

fn writeYaml(alloc: std.mem.Allocator, io: std.Io, file_path: []const u8, entries: []const Entry) !void {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);

    try buf.appendSlice(alloc,
        \\# Auto-generated by `zig build tspconfigs-update` / `tspconfigs-resolve`.
        \\# Source: eng/codegen/typespec-packages.txt
        \\# Edit packages.txt to add/remove specs; the next `update` run will
        \\# reconcile this file against ../azure-rest-api-specs.
        \\
        \\
    );

    for (entries, 0..) |e, i| {
        if (i != 0) try buf.append(alloc, '\n');
        try buf.print(alloc, "\"{s}\":\n", .{e.path});
        try buf.print(alloc, "  js: \"{s}\"\n", .{e.js});
        try buf.print(alloc, "  zig: \"{s}\"\n", .{e.zig});
    }

    try writeFile(io, file_path, buf.items);
}

// ---------------------------------------------------------------------------
// tspconfig.yaml parsing — extract @azure-tools/typespec-ts package name
// ---------------------------------------------------------------------------

fn extractTsPackageName(alloc: std.mem.Allocator, io: std.Io, abs_path: []const u8) !?[]const u8 {
    const maybe = try readFileOptional(alloc, io, abs_path, 4 * 1024 * 1024);
    const data = maybe orelse return null;

    var in_ts = false;
    var ts_indent: usize = 0;
    var in_pkg_details = false;
    var pkg_indent: usize = 0;

    var lines = std.mem.splitScalar(u8, data, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len == 0) continue;
        const trimmed = std.mem.trimStart(u8, line, " \t");
        if (trimmed.len == 0) continue;
        if (trimmed[0] == '#') continue;
        const indent = line.len - trimmed.len;

        if (in_pkg_details) {
            if (indent <= pkg_indent) {
                in_pkg_details = false;
            } else if (std.mem.startsWith(u8, trimmed, "name:")) {
                var v = std.mem.trim(u8, trimmed[5..], " \t");
                if (v.len >= 2 and v[0] == '"' and v[v.len - 1] == '"') v = v[1 .. v.len - 1];
                if (v.len >= 2 and v[0] == '\'' and v[v.len - 1] == '\'') v = v[1 .. v.len - 1];
                if (v.len == 0) return null;
                return try alloc.dupe(u8, v);
            }
        }

        if (in_ts) {
            if (indent <= ts_indent) {
                in_ts = false;
                in_pkg_details = false;
            } else if (std.mem.startsWith(u8, trimmed, "package-details:")) {
                in_pkg_details = true;
                pkg_indent = indent;
                continue;
            }
        }

        if (isTypespecTsKey(trimmed)) {
            in_ts = true;
            ts_indent = indent;
            in_pkg_details = false;
        }
    }
    return null;
}

fn isTypespecTsKey(trimmed: []const u8) bool {
    const variants = [_][]const u8{
        "\"@azure-tools/typespec-ts\":",
        "'@azure-tools/typespec-ts':",
        "@azure-tools/typespec-ts:",
    };
    for (variants) |v| {
        if (std.mem.startsWith(u8, trimmed, v)) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// misc helpers
// ---------------------------------------------------------------------------

fn lessThanStr(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

/// Convert a JavaScript package name into the corresponding zig import name:
/// strip any leading "@scope/" namespace and replace '-' with '_'.
fn toZigName(alloc: std.mem.Allocator, js_name: []const u8) ![]const u8 {
    var s = js_name;
    if (s.len > 0 and s[0] == '@') {
        if (std.mem.indexOfScalar(u8, s, '/')) |slash| {
            s = s[slash + 1 ..];
        }
    }
    const out = try alloc.dupe(u8, s);
    for (out) |*c| if (c.* == '-') {
        c.* = '_';
    };
    return out;
}
