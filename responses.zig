//! Typed SDK responses and their ownership rules.
//!
//! Allocating responses will own an arena and expose one `deinit` operation.
//! Response slices remain valid until that operation. HTTP failures are values
//! in `*Result` variants; Zig errors are reserved for local failures.
