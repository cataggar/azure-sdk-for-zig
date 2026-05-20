//! WASI component host for the `azure:codegen/tcgc` component.
//!
//! Loads `tcgc.wasm` via the wamr Component Model runtime, mounts the
//! spec directory as a WASI filesystem preopen, invokes the
//! `azure:codegen/tcgc#compile` export, and returns the JSON code
//! model.
//!
//! The component itself is produced by `jco componentize` from
//! `codegen/tcgc-component`. See `codegen/README.md` for the
//! end-to-end pipeline.

const std = @import("std");
const wamr = @import("wamr");
const ctypes = wamr.component_types;
const cl = wamr.component_loader;
const ci = wamr.component_instance;
const ce = wamr.component_executor;
const abi = wamr.canonical_abi;
const adapter_mod = wamr.wasi_cli_adapter;

pub const HostError = error{
    LoadFailed,
    InstantiateFailed,
    LinkFailed,
    NoCompileExport,
    InvokeFailed,
    GuestAllocFailed,
    BadResult,
    OutOfMemory,
};

pub const RunOptions = struct {
    /// Path on the host to a directory that contains the spec's `.tsp`
    /// files. Mounted into the guest as a WASI preopened directory
    /// named `/spec`.
    spec_dir: []const u8,
    /// JSON-encoded options blob forwarded as-is to the component.
    emitter_options_json: []const u8 = "{}",
};

/// Load the component bytes at `wasm_path`, run `compile` with `opts`,
/// and return the JSON code model. Caller owns the returned slice.
pub fn runFromFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    wasm_path: []const u8,
    opts: RunOptions,
) ![]u8 {
    const cwd = std.Io.Dir.cwd();
    const wasm_bytes = try cwd.readFileAlloc(io, wasm_path, allocator, .limited(64 * 1024 * 1024));
    defer allocator.free(wasm_bytes);
    return runFromBytes(allocator, io, wasm_bytes, opts);
}

/// Bytes-in / JSON-out variant of `runFromFile`.
pub fn runFromBytes(
    allocator: std.mem.Allocator,
    io: std.Io,
    wasm_bytes: []const u8,
    opts: RunOptions,
) ![]u8 {
    // 1. Parse the component binary.
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var component = cl.load(wasm_bytes, arena.allocator()) catch return error.LoadFailed;

    // 2. Instantiate.
    const inst = ci.instantiate(&component, allocator) catch return error.InstantiateFailed;
    defer inst.deinit();

    // 3. Build a WASI adapter and mount the spec dir as `/spec`.
    var adapter = adapter_mod.WasiCliAdapter.init(allocator);
    defer adapter.deinit();

    const spec_dir = try std.Io.Dir.cwd().openDir(io, opts.spec_dir, .{ .iterate = true });
    // adapter takes ownership of `spec_dir` on success.
    _ = try adapter.addPreopen("/spec", spec_dir);

    // 4. Wire imports and link.
    var providers: std.StringHashMapUnmanaged(ci.ImportBinding) = .empty;
    defer providers.deinit(allocator);
    try adapter_mod.populateWasiProviders(&adapter, &component, &providers);
    inst.linkImports(providers) catch return error.LinkFailed;

    // 5. Find the compile export. The WIT export becomes a top-level
    //    component-export. The exact key depends on what
    //    `wit-component` (run by jco) chose to alias as. Try common
    //    forms in order.
    const export_candidates = [_][]const u8{
        "azure:codegen/tcgc/compile",
        "azure:codegen/tcgc#compile",
        "azure:codegen/tcgc@0.0.0/compile",
    };
    const export_name = blk: {
        for (export_candidates) |n| {
            if (inst.getExport(n) != null) break :blk n;
        }
        std.debug.print("no compile export found; available:\n", .{});
        var it = inst.exported_funcs.iterator();
        while (it.next()) |e| std.debug.print("  {s}\n", .{e.key_ptr.*});
        return error.NoCompileExport;
    };

    // 6. Lower string args into guest memory.
    const path_in_guest = "/spec";
    const path_ptr = inst.hostAllocAndWrite(path_in_guest) orelse return error.GuestAllocFailed;
    const opts_ptr = inst.hostAllocAndWrite(opts.emitter_options_json) orelse return error.GuestAllocFailed;

    var args = [_]abi.InterfaceValue{
        .{ .string = .{ .ptr = path_ptr, .len = @intCast(path_in_guest.len) } },
        .{ .string = .{ .ptr = opts_ptr, .len = @intCast(opts.emitter_options_json.len) } },
    };
    var results: [1]abi.InterfaceValue = .{.{ .u32 = 0 }};
    defer for (results) |r| r.deinit(allocator);

    ce.callComponentFunc(inst, export_name, &args, &results, allocator) catch return error.InvokeFailed;

    // 7. Decode `result<string, string>`.
    const rv = switch (results[0]) {
        .result_val => |r| r,
        else => return error.BadResult,
    };
    const payload = rv.payload orelse return error.BadResult;
    const inner_str = switch (payload.*) {
        .string => |s| s,
        else => return error.BadResult,
    };
    const bytes = inst.readGuestBytes(inner_str.ptr, inner_str.len) orelse return error.BadResult;
    if (!rv.is_ok) {
        // Return the error message verbatim as the bad result.
        return error.InvokeFailed;
    }
    return try allocator.dupe(u8, bytes);
}
