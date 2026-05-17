//! Canonical-ABI binding for the imported function
//!     azure:codegen/tcgc#compile(string, string) -> result<string, string>
//!
//! When this Zig binary is wrapped into a component (via
//! `wabt component embed` + `wabt component new`) and then composed
//! with `tcgc.wasm` (via `wabt component compose`), the component
//! model linker resolves this import to TCGC's exported function.
//!
//! The canonical ABI for our specific signature:
//!
//!     compile: func(project-path: string, emitter-options: string)
//!              -> result<string, string>
//!
//! Caller side (us, the importer):
//!   * Lower each `string` to `(ptr: i32, len: i32)`. Strings are
//!     valid UTF-8 already allocated in our linear memory.
//!   * Result `result<string, string>` is a discriminated union with
//!     two string payloads. The component model spilled result is
//!     returned via an out-pointer the caller supplies.
//!
//! Return layout (writable via the importee's `cabi_realloc` /
//! `cabi_import_realloc`):
//!
//!     +0  i32  discriminant: 0 = ok, 1 = err
//!     +4  i32  string-ptr
//!     +8  i32  string-len
//!
//! Total: 12 bytes, max-align 4.
//!
//! The `extern "azure:codegen/tcgc"` block declares the import. The
//! component encoder (wabt component embed) reads the
//! `component-type` custom section in the embed binary to know the
//! WIT type of this import; with the world declaration in
//! `wit/world.wit` saying `import azure:codegen/tcgc;`, the
//! encoder lifts the bare core import into a typed component import.
//!
//! All of this only fires *once we wire the actual extern below*.
//! Until then, `compile()` returns `error.NotImplemented` so the
//! binary builds and the rest of the pipeline can be smoke-tested
//! independently. The real declaration arrives with the next todo
//! (`cli-ffi-compile`).

const std = @import("std");

pub const Error = error{
    CompileFailed,
    OutOfMemory,
    NotImplemented,
};

/// Invoke `azure:codegen/tcgc.compile(project_path, emitter_options)`.
///
/// On success returns the JSON code model string (caller owns).
/// On TCGC-side failure returns `error.CompileFailed`; the human-
/// readable message is written to stderr by the component runtime
/// before we return.
pub fn compile(
    allocator: std.mem.Allocator,
    project_path: []const u8,
    emitter_options: []const u8,
) Error![]u8 {
    _ = allocator;
    _ = project_path;
    _ = emitter_options;
    return error.NotImplemented;
}
