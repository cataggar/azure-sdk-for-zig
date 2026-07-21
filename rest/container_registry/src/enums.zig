//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_core");

/// Sort options for ordering tags in a collection.
pub const ArtifactTagOrder = union(enum) {
    none,
    last_updated_on_descending,
    last_updated_on_ascending,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .last_updated_on_descending = "timedesc",
        .last_updated_on_ascending = "timeasc",
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

/// Sort options for ordering manifests in a collection.
pub const ArtifactManifestOrder = union(enum) {
    none,
    last_updated_on_descending,
    last_updated_on_ascending,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .last_updated_on_descending = "timedesc",
        .last_updated_on_ascending = "timeasc",
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

/// The artifact platform's architecture.
pub const ArtifactArchitecture = union(enum) {
    i386,
    amd64,
    arm,
    arm64,
    mips,
    mips_le,
    mips64,
    mips64le,
    ppc64,
    ppc64le,
    risc_v64,
    s390x,
    wasm,
    unrecognized: []const u8,

    const wire_names = .{
        .i386 = "386",
        .amd64 = "amd64",
        .arm = "arm",
        .arm64 = "arm64",
        .mips = "mips",
        .mips_le = "mipsle",
        .mips64 = "mips64",
        .mips64le = "mips64le",
        .ppc64 = "ppc64",
        .ppc64le = "ppc64le",
        .risc_v64 = "riscv64",
        .s390x = "s390x",
        .wasm = "wasm",
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

/// The artifact platform's operating system.
pub const ArtifactOperatingSystem = union(enum) {
    aix,
    android,
    darwin,
    dragonfly,
    free_bsd,
    illumos,
    i_os,
    js,
    linux,
    net_bsd,
    open_bsd,
    plan9,
    solaris,
    windows,
    unrecognized: []const u8,

    const wire_names = .{
        .aix = "aix",
        .android = "android",
        .darwin = "darwin",
        .dragonfly = "dragonfly",
        .free_bsd = "freebsd",
        .illumos = "illumos",
        .i_os = "ios",
        .js = "js",
        .linux = "linux",
        .net_bsd = "netbsd",
        .open_bsd = "openbsd",
        .plan9 = "plan9",
        .solaris = "solaris",
        .windows = "windows",
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

/// Can take a value of access_token_refresh_token, or access_token, or
/// refresh_token
pub const PostContentSchemaGrantType = union(enum) {
    access_token_refresh_token,
    access_token,
    refresh_token,
    unrecognized: []const u8,

    const wire_names = .{
        .access_token_refresh_token = "access_token_refresh_token",
        .access_token = "access_token",
        .refresh_token = "refresh_token",
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
    v2021_07_01,
};

/// Grant type is expected to be refresh_token
pub const TokenGrantType = union(enum) {
    refresh_token,
    password,
    unrecognized: []const u8,

    const wire_names = .{
        .refresh_token = "refresh_token",
        .password = "password",
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
