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

/// Return the wire string for an open-enum union value. Known void
/// variants are looked up in `wire_names`; `unrecognized` returns its
/// inner string. The returned slice is borrowed (either a string
/// literal from `wire_names` or the union's own backing storage) and
/// is therefore valid only as long as `value` itself.
pub fn toWire(value: anytype, comptime wire_names: anytype) []const u8 {
    const T = @TypeOf(value);
    const Tag = std.meta.Tag(T);
    inline for (comptime std.meta.fields(T)) |field| {
        if (@as(Tag, value) == @field(Tag, field.name)) {
            if (comptime std.mem.eql(u8, field.name, "unrecognized")) {
                return @field(value, "unrecognized");
            }
            const wire: []const u8 = @field(wire_names, field.name);
            return wire;
        }
    }
    unreachable;
}

/// Parse a wire string into an open-enum union value. Known values map to
/// their void variant; unlisted values are captured in the `unrecognized`
/// variant, whose backing string is duplicated with `allocator` so it
/// outlives the borrowed input. The caller owns the returned value.
pub fn fromWire(
    comptime T: type,
    comptime wire_names: anytype,
    allocator: std.mem.Allocator,
    s: []const u8,
) std.mem.Allocator.Error!T {
    inline for (comptime std.meta.fields(@TypeOf(wire_names))) |f| {
        const wire: []const u8 = @field(wire_names, f.name);
        if (std.mem.eql(u8, s, wire)) return @unionInit(T, f.name, {});
    }
    return @unionInit(T, "unrecognized", try allocator.dupe(u8, s));
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

    pub fn toWire(self: @This()) []const u8 {
        return @import("open_enum.zig").toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return @import("open_enum.zig").fromWire(@This(), wire_names, allocator, s);
    }
};

test "open enum: toWire returns mapped wire name" {
    try testing.expectEqualStrings("One", Sample.toWire(.one));
    try testing.expectEqualStrings("Two", Sample.toWire(.two));
}

test "open enum: fromWire maps known wire name" {
    try testing.expectEqual(Sample.one, try Sample.fromWire(testing.allocator, "One"));
    try testing.expectEqual(Sample.two, try Sample.fromWire(testing.allocator, "Two"));
}

test "open enum: fromWire captures unrecognized wire value" {
    const out = try Sample.fromWire(testing.allocator, "Floomp");
    defer switch (out) {
        .unrecognized => |s| testing.allocator.free(s),
        else => {},
    };
    switch (out) {
        .unrecognized => |s| try testing.expectEqualStrings("Floomp", s),
        else => return error.ExpectedUnrecognized,
    }
}

test "open enum: toWire returns inner string for unrecognized" {
    try testing.expectEqualStrings("Floomp", Sample.toWire(.{ .unrecognized = "Floomp" }));
}

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
