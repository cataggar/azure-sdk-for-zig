//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unknown` variant.

const std = @import("std");

/// Reflects the deletion recovery level currently in effect for secrets in the current vault. If it contains 'Purgeable', the secret can be permanently deleted by a privileged user; otherwise, only the system can purge the secret, at the end of the retention interval.
pub const DeletionRecoveryLevel = union(enum) {
    purgeable,
    recoverable_purgeable,
    recoverable,
    recoverable_protected_subscription,
    customized_recoverable_purgeable,
    customized_recoverable,
    customized_recoverable_protected_subscription,
    unknown: []const u8,
};

/// The media type (MIME type).
pub const ContentType = union(enum) {
    pfx,
    pem,
    unknown: []const u8,
};

/// The available API versions.
pub const Versions = enum {
    @"v7.5",
    @"v7.6_preview.2",
    @"v7.6",
    v2025_06_01_preview,
    v2025_07_01,
    v2026_01_01_preview,
    v2026_03_01_preview,
};
