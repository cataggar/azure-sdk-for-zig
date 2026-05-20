//! Canonical-ABI binding for the imported function
//!     azure:codegen/tcgc#compile(string, string) -> result<string, string>
//!
//! When this Zig binary is wrapped into a component (via
//! `wabt component embed` + `wabt component new`) and then composed
//! with `tcgc.wasm` (via `wabt component compose`), the component
//! model linker resolves this import to TCGC's exported function.
//!
//! ## Canonical ABI lowering
//!
//! Params: each `string` → `(ptr: i32, len: i32)` → 4 i32 total.
//!
//! Return `result<string, string>` flattens to 3 i32
//! `(disc, ptr, len)`. With `MAX_FLAT_RESULTS = 1` (default) this
//! exceeds the inline budget, so the result spills: the import
//! signature gains a trailing `retptr: i32` and the importee writes
//! the 3 i32 result fields to that 12-byte (align 4) area.
//!
//! Return layout written by the importee:
//!
//!     +0  i32  discriminant (0 = ok, 1 = err)
//!     +4  i32  string-ptr (into our linear memory)
//!     +8  i32  string-len
//!
//! The string memory itself lives in our linear memory; the importee
//! allocates it by calling our exported `cabi_realloc`.
//!
//! ## cabi_realloc
//!
//! Exported below as a single bump-style realloc on top of
//! `std.heap.page_allocator`. Free (new_size == 0) is a no-op; the
//! WASI process exits after one `compile()` call so leaks are
//! reclaimed at exit. Resize is implemented as alloc+memcpy+leak-old.

const std = @import("std");

pub const Error = error{
    CompileFailed,
    OutOfMemory,
    NotImplemented,
};

// ── Imported core-wasm function ──────────────────────────────────
//
// `wabt component embed -w cli` reads the `component-type` custom
// section it appends (derived from `wit/world.wit`) to lift this
// core import into the typed component import
// `azure:codegen/tcgc#compile`.
extern "azure:codegen/tcgc" fn compile(
    project_path_ptr: i32,
    project_path_len: i32,
    emitter_options_ptr: i32,
    emitter_options_len: i32,
    retptr: i32,
) void;

// ── cabi_realloc export ──────────────────────────────────────────
//
// Called by the tcgc subcomponent to allocate / resize buffers in
// our linear memory. The component model requires this name and
// signature exactly.
//
// We force-export via `@export` (a plain `export fn` is dead-code
// eliminated because nothing inside this module references it).
fn cabiRealloc(
    old_ptr: ?[*]u8,
    old_size: usize,
    alignment: usize,
    new_size: usize,
) callconv(.c) ?[*]u8 {
    const alloc = std.heap.page_allocator;
    const align_v: std.mem.Alignment = .fromByteUnits(@max(alignment, 1));

    if (new_size == 0) {
        // Free: leak (process exits after one call). Returning null
        // satisfies the canonical-ABI contract for free.
        return null;
    }

    if (old_ptr == null or old_size == 0) {
        return alloc.rawAlloc(new_size, align_v, @returnAddress());
    }

    const new_ptr = alloc.rawAlloc(new_size, align_v, @returnAddress()) orelse return null;
    const copy_len = @min(old_size, new_size);
    @memcpy(new_ptr[0..copy_len], old_ptr.?[0..copy_len]);
    return new_ptr;
}

comptime {
    @export(&cabiRealloc, .{ .name = "cabi_realloc", .linkage = .strong });
}

/// Invoke `azure:codegen/tcgc.compile(project_path, emitter_options)`.
///
/// On success returns the JSON code model string (caller owns; freed
/// via `allocator.free`). On TCGC-side failure returns
/// `error.CompileFailed` and prints the human-readable message to
/// stderr.
pub fn invoke(
    allocator: std.mem.Allocator,
    project_path: []const u8,
    emitter_options: []const u8,
) Error![]u8 {
    var retbuf align(4) = [_]u32{ 0, 0, 0 };

    compile(
        @intCast(@intFromPtr(project_path.ptr)),
        @intCast(project_path.len),
        @intCast(@intFromPtr(emitter_options.ptr)),
        @intCast(emitter_options.len),
        @intCast(@intFromPtr(&retbuf)),
    );

    const disc = retbuf[0];
    const ptr = retbuf[1];
    const len = retbuf[2];

    if (len == 0) {
        // Empty payload on either branch — return an empty owned
        // slice rather than dereferencing a possibly-null pointer.
        if (disc == 1) {
            std.debug.print("tcgc compile failed (empty error message)\n", .{});
            return error.CompileFailed;
        }
        return try allocator.dupe(u8, "");
    }

    const src = @as([*]const u8, @ptrFromInt(@as(usize, ptr)))[0..@as(usize, len)];
    const out = try allocator.dupe(u8, src);

    if (disc == 1) {
        std.debug.print("tcgc compile error: {s}\n", .{out});
        allocator.free(out);
        return error.CompileFailed;
    }
    return out;
}
