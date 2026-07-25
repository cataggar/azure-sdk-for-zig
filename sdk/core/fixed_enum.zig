//! Helpers for "fixed" (non-extensible) Azure string-valued enums.
//!
//! Fixed enums are generated as a plain Zig `enum` whose variant
//! identifiers are snake_cased Zig names while the wire contract uses a
//! different spelling (usually PascalCase), e.g.
//!
//!     pub const BlobType = enum {
//!         block_blob,
//!         page_blob,
//!         append_blob,
//!         pub fn toWire(self: @This()) []const u8 { ... }   // .block_blob => "BlockBlob"
//!         pub fn fromWire(s: []const u8) ?@This() { ... }
//!     };
//!
//! serde's built-in enum (de)serializer matches by the Zig variant
//! identifier, so `"BlockBlob"` never matches `block_blob` and it
//! fails with `error.UnexpectedToken`. The generated emitter therefore
//! wires each fixed enum to the helpers below via `zerdeDeserialize` /
//! `zerdeSerialize` hooks, which route through the enum's own
//! `toWire` / `fromWire` wire mapping. This mirrors `open_enum` for the
//! extensible case.

const std = @import("std");

/// Deserialize a fixed enum from a wire string via `T.fromWire`.
/// Unknown wire values (not present in the enum) fail with
/// `error.UnexpectedToken`, matching the strictness of a closed enum.
pub fn deserialize(
    comptime T: type,
    allocator: std.mem.Allocator,
    deserializer: anytype,
) @TypeOf(deserializer.*).Error!T {
    const s = try deserializer.deserializeString(allocator);
    defer allocator.free(s);
    return T.fromWire(s) orelse error.UnexpectedToken;
}

/// Serialize a fixed enum as its wire string via `value.toWire()`.
pub fn serialize(value: anytype, serializer: anytype) !void {
    return serializer.serializeString(value.toWire());
}

// ─────────────────────────── Tests ───────────────────────────

const testing = std.testing;

const Sample = enum {
    block_blob,
    page_blob,
    append_blob,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .block_blob => "BlockBlob",
            .page_blob => "PageBlob",
            .append_blob => "AppendBlob",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "BlockBlob")) return .block_blob;
        if (std.mem.eql(u8, s, "PageBlob")) return .page_blob;
        if (std.mem.eql(u8, s, "AppendBlob")) return .append_blob;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return serialize(self, serializer);
    }
};

const serde = @import("serde");

test "fixed_enum round-trips known wire value via JSON" {
    const v = try serde.json.fromSlice(Sample, testing.allocator, "\"PageBlob\"");
    try testing.expectEqual(Sample.page_blob, v);

    const out = try serde.json.toSlice(testing.allocator, Sample.append_blob);
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("\"AppendBlob\"", out);
}

test "fixed_enum rejects unknown wire value" {
    try testing.expectError(error.UnexpectedToken, serde.json.fromSlice(Sample, testing.allocator, "\"NopeBlob\""));
}
