//! Tests for the generated Azure DevOps clients.
//!
//! Kept in a separate file so the emitter can overwrite every
//! `clients.zig` without losing test coverage. Wired into the
//! package's test step via `root.zig`.
//!
//! This file is **operator-owned**: `codegen/scripts/sync.sh` marks
//! it as operator-managed and never overwrites an existing copy.

const std = @import("std");
const root = @import("root.zig");

test "every API area is reachable from the package root" {
    try std.testing.expect(@hasDecl(root, "git"));
    try std.testing.expect(@hasDecl(root, "build"));
}

test "operation groups are reachable from an area root client" {
    try std.testing.expect(@hasDecl(root.git.GitClient, "repositories"));
    try std.testing.expect(@hasDecl(root.build.BuildClient, "builds"));
}
