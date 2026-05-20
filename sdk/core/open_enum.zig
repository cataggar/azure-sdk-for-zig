//! Helpers for "open" (extensible) Azure string-valued enums.
//!
//! Open enums are generated as
//!
//!     pub const Foo = union(enum) {
//!         known_one,
//!         known_two,
//!         unrecognized: []const u8,
//!         ...
//!     };
//!
//! so wire values not listed in `wire_names` round-trip through the
//! catch-all `unrecognized` variant. The default serde `union(enum)`
//! deserializer refuses such unknown strings with
//! `error.UnexpectedToken`; the generated emitter therefore wires
//! each open enum to the helpers below via `zerdeDeserialize` /
//! `zerdeSerialize` hooks.
//!
//! Each open enum supplies a compile-time `wire_names` mapping from
//! the Zig variant identifier to the JSON wire string, e.g.
//!
//!     const wire_names = .{ .single_zone = "SingleZone", ... };
//!
//! The variant `unrecognized` is implicit and does not need a mapping.
//! Picking `unrecognized` (rather than `unknown`) avoids colliding
//! with TypeSpec specs that themselves declare an `Unknown` enum
//! literal — e.g. `DatastoreStatus { Unknown, Accessible, ... }`.

const std = @import("std");

/// Deserialize an open-enum union from a JSON string. Returns the
/// matching void variant, or `.unrecognized = "<raw>"` for values not
/// listed in `wire_names` (the raw string is allocator-owned by the
/// caller).
pub fn deserialize(
    comptime T: type,
    comptime wire_names: anytype,
    allocator: std.mem.Allocator,
    deserializer: anytype,
) @TypeOf(deserializer.*).Error!T {
    const s = try deserializer.deserializeString(allocator);
    inline for (comptime std.meta.fields(@TypeOf(wire_names))) |f| {
        const wire: []const u8 = @field(wire_names, f.name);
        if (std.mem.eql(u8, s, wire)) {
            allocator.free(s);
            return @unionInit(T, f.name, {});
        }
    }
    return @unionInit(T, "unrecognized", s);
}

/// Serialize an open-enum union as a JSON string. Known void variants
/// use their `wire_names` mapping; `unrecognized` writes its inner
/// string verbatim.
pub fn serialize(value: anytype, comptime wire_names: anytype, serializer: anytype) !void {
    const T = @TypeOf(value);
    const Tag = std.meta.Tag(T);
    inline for (comptime std.meta.fields(T)) |field| {
        if (@as(Tag, value) == @field(Tag, field.name)) {
            if (comptime std.mem.eql(u8, field.name, "unrecognized")) {
                return serializer.serializeString(@field(value, "unrecognized"));
            }
            const wire: []const u8 = @field(wire_names, field.name);
            return serializer.serializeString(wire);
        }
    }
    unreachable;
}

// ─────────────────────────── Tests ───────────────────────────

const testing = std.testing;

const Sample = union(enum) {
    one,
    two,
    unrecognized: []const u8,

    const wire_names = .{ .one = "One", .two = "Two" };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return serialize(self, wire_names, serializer);
    }
};

test "open enum: known variant deserializes via wire name" {
    const serde = @import("serde");
    const out = try serde.json.fromSlice(Sample, testing.allocator, "\"One\"");
    try testing.expectEqual(Sample.one, out);
}

test "open enum: unrecognized variant captures raw string" {
    const serde = @import("serde");
    const out = try serde.json.fromSlice(Sample, testing.allocator, "\"Floomp\"");
    defer switch (out) {
        .unrecognized => |s| testing.allocator.free(s),
        else => {},
    };
    switch (out) {
        .unrecognized => |s| try testing.expectEqualStrings("Floomp", s),
        else => return error.ExpectedUnrecognized,
    }
}

test "open enum: known variant serializes to wire name" {
    const serde = @import("serde");
    const out = try serde.json.toSlice(testing.allocator, Sample{ .two = {} });
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("\"Two\"", out);
}

test "open enum: unrecognized variant serializes its inner string" {
    const serde = @import("serde");
    const out = try serde.json.toSlice(testing.allocator, Sample{ .unrecognized = "Floomp" });
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("\"Floomp\"", out);
}
