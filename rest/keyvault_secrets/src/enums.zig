//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

/// Reflects the deletion recovery level currently in effect for secrets in the current vault. If it contains 'Purgeable', the secret can be permanently deleted by a privileged user; otherwise, only the system can purge the secret, at the end of the retention interval.
pub const DeletionRecoveryLevel = union(enum) {
    purgeable,
    recoverable_purgeable,
    recoverable,
    recoverable_protected_subscription,
    customized_recoverable_purgeable,
    customized_recoverable,
    customized_recoverable_protected_subscription,
    unrecognized: []const u8,

    const wire_names = .{
        .purgeable = "Purgeable",
        .recoverable_purgeable = "Recoverable+Purgeable",
        .recoverable = "Recoverable",
        .recoverable_protected_subscription = "Recoverable+ProtectedSubscription",
        .customized_recoverable_purgeable = "CustomizedRecoverable+Purgeable",
        .customized_recoverable = "CustomizedRecoverable",
        .customized_recoverable_protected_subscription = "CustomizedRecoverable+ProtectedSubscription",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
};

/// The media type (MIME type).
pub const ContentType = union(enum) {
    pfx,
    pem,
    unrecognized: []const u8,

    const wire_names = .{
        .pfx = "application/x-pkcs12",
        .pem = "application/x-pem-file",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }
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
