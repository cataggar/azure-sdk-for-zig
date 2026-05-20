//! Tests for the generated `clients.zig`.
//!
//! Kept in a separate file so the emitter can overwrite
//! `clients.zig` without losing test coverage. Wired into the
//! package's test step via `root.zig`.
//!
//! This file is **operator-owned**: `codegen/scripts/sync.sh`
//! marks it as operator-managed and never overwrites an
//! existing copy. Add tests freely.

const std = @import("std");
