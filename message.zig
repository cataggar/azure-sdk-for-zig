//! AMQP 1.0 message encoding and decoding (§3.2).
//!
//! `uamqp.message.Message` models a message but ships no codec, so a message
//! cannot be put on the wire. This module encodes the bare message sections in
//! the order the specification requires and decodes them back.
//!
//! Section slices borrow from the `Decoded` that produced them and become
//! invalid once it is released.

const std = @import("std");
const uamqp = @import("uamqp");
const perf = @import("performative.zig");

const Allocator = std.mem.Allocator;
const AmqpValue = uamqp.AmqpValue;
const MapEntry = uamqp.MapEntry;
const encoder = uamqp.encoder;
const decoder = uamqp.decoder;
const descriptor = uamqp.definitions.descriptor;

pub const Fields = perf.Fields;

/// Aliased to uamqp's error set rather than restated, so a new encoder
/// failure mode cannot silently fail to compile here again.
pub const EncodeError = encoder.EncodeError;

pub const DecodeError = error{
    OutOfMemory,
    MalformedBody,
    /// A section appeared that is not a legal message section.
    UnexpectedSection,
};

/// header (§3.2.1).
pub const Header = struct {
    durable: bool = false,
    priority: ?u8 = null,
    ttl: ?u32 = null,
    first_acquirer: bool = false,
    delivery_count: ?u32 = null,

    fn isEmpty(self: Header) bool {
        return !self.durable and self.priority == null and self.ttl == null and
            !self.first_acquirer and self.delivery_count == null;
    }
};

/// properties (§3.2.4).
pub const Properties = struct {
    message_id: ?AmqpValue = null,
    user_id: ?[]const u8 = null,
    to: ?[]const u8 = null,
    subject: ?[]const u8 = null,
    reply_to: ?[]const u8 = null,
    correlation_id: ?AmqpValue = null,
    content_type: ?[]const u8 = null,
    content_encoding: ?[]const u8 = null,
    absolute_expiry_time: ?i64 = null,
    creation_time: ?i64 = null,
    group_id: ?[]const u8 = null,
    group_sequence: ?u32 = null,
    reply_to_group_id: ?[]const u8 = null,

    fn isEmpty(self: Properties) bool {
        inline for (@typeInfo(Properties).@"struct".fields) |f| {
            if (@field(self, f.name) != null) return false;
        }
        return true;
    }
};

/// The message body (§3.2.5-3.2.7).
///
/// `data` holds one or more binary sections; Event Hubs uses a single one for
/// an event, and a sequence of them for a batch envelope.
pub const Body = union(enum) {
    empty,
    data: []const []const u8,
    sequence: []const []const AmqpValue,
    value: AmqpValue,
};

/// A bare AMQP message plus its annotations.
pub const Message = struct {
    header: Header = .{},
    delivery_annotations: ?Fields = null,
    message_annotations: ?Fields = null,
    properties: Properties = .{},
    application_properties: ?Fields = null,
    body: Body = .empty,
    footer: ?Fields = null,
};

// ─────────────────────── Encoding ───────────────────────

fn writeDescriptor(code: u64, buf: *encoder.Buffer) EncodeError!void {
    try buf.writeByte(0x00);
    try encoder.encode(.{ .ulong = code }, buf);
}

/// Write a described list, dropping trailing null fields.
fn writeList(
    allocator: Allocator,
    code: u64,
    values: []const ?AmqpValue,
    buf: *encoder.Buffer,
) EncodeError!void {
    var count = values.len;
    while (count > 0 and values[count - 1] == null) count -= 1;

    try writeDescriptor(code, buf);
    if (count == 0) return buf.writeByte(0x45);

    var body = encoder.Buffer.initDynamic(allocator);
    defer body.deinit();
    for (values[0..count]) |v| {
        if (v) |value| try encoder.encode(value, &body) else try body.writeByte(0x40);
    }

    const bytes = body.written();
    if (bytes.len + 1 <= 0xff and count <= 0xff) {
        try buf.writeByte(0xc0);
        try buf.writeByte(@intCast(bytes.len + 1));
        try buf.writeByte(@intCast(count));
    } else {
        try buf.writeByte(0xd0);
        var size: [4]u8 = undefined;
        std.mem.writeInt(u32, &size, @intCast(bytes.len + 4), .big);
        try buf.writeAll(&size);
        std.mem.writeInt(u32, &size, @intCast(count), .big);
        try buf.writeAll(&size);
    }
    try buf.writeAll(bytes);
}

fn writeMapSection(code: u64, map: Fields, buf: *encoder.Buffer) EncodeError!void {
    try writeDescriptor(code, buf);
    try encoder.encode(.{ .map = @constCast(map) }, buf);
}

fn optBool(v: bool) ?AmqpValue {
    return if (v) .{ .boolean = true } else null;
}

fn optString(v: ?[]const u8) ?AmqpValue {
    return if (v) |s| .{ .string = s } else null;
}

fn optBinary(v: ?[]const u8) ?AmqpValue {
    return if (v) |s| .{ .binary = s } else null;
}

fn optSymbol(v: ?[]const u8) ?AmqpValue {
    return if (v) |s| .{ .symbol = s } else null;
}

fn optUint(v: ?u32) ?AmqpValue {
    return if (v) |n| .{ .uint = n } else null;
}

fn optUbyte(v: ?u8) ?AmqpValue {
    return if (v) |n| .{ .ubyte = n } else null;
}

fn optTimestamp(v: ?i64) ?AmqpValue {
    return if (v) |n| .{ .timestamp = n } else null;
}

/// Encode a message into `buf` in the section order §3.2 mandates.
pub fn encode(allocator: Allocator, msg: Message, buf: *encoder.Buffer) EncodeError!void {
    if (!msg.header.isEmpty()) {
        const values = [_]?AmqpValue{
            optBool(msg.header.durable),
            optUbyte(msg.header.priority),
            optUint(msg.header.ttl),
            optBool(msg.header.first_acquirer),
            optUint(msg.header.delivery_count),
        };
        try writeList(allocator, descriptor.header, &values, buf);
    }

    if (msg.delivery_annotations) |m| {
        try writeMapSection(descriptor.delivery_annotations, m, buf);
    }
    if (msg.message_annotations) |m| {
        try writeMapSection(descriptor.message_annotations, m, buf);
    }

    if (!msg.properties.isEmpty()) {
        const p = msg.properties;
        const values = [_]?AmqpValue{
            p.message_id,
            optBinary(p.user_id),
            optString(p.to),
            optString(p.subject),
            optString(p.reply_to),
            p.correlation_id,
            optSymbol(p.content_type),
            optSymbol(p.content_encoding),
            optTimestamp(p.absolute_expiry_time),
            optTimestamp(p.creation_time),
            optString(p.group_id),
            optUint(p.group_sequence),
            optString(p.reply_to_group_id),
        };
        try writeList(allocator, descriptor.properties, &values, buf);
    }

    if (msg.application_properties) |m| {
        try writeMapSection(descriptor.application_properties, m, buf);
    }

    switch (msg.body) {
        .empty => {},
        .data => |sections| for (sections) |section| {
            try writeDescriptor(descriptor.data, buf);
            try encoder.encode(.{ .binary = section }, buf);
        },
        .sequence => |sections| for (sections) |section| {
            try writeDescriptor(descriptor.amqp_sequence, buf);
            try encoder.encode(.{ .list = @constCast(section) }, buf);
        },
        .value => |v| {
            try writeDescriptor(descriptor.amqp_value, buf);
            try encoder.encode(v, buf);
        },
    }

    if (msg.footer) |m| try writeMapSection(descriptor.footer, m, buf);
}

/// Encode a message into a freshly allocated buffer owned by the caller.
pub fn encodeAlloc(allocator: Allocator, msg: Message) EncodeError![]u8 {
    var buf = encoder.Buffer.initDynamic(allocator);
    defer buf.deinit();
    try encode(allocator, msg, &buf);
    return allocator.dupe(u8, buf.written());
}

// ─────────────────────── Decoding ───────────────────────

/// A decoded message together with the arena backing its slices.
pub const Decoded = struct {
    arena: *std.heap.ArenaAllocator,
    message: Message,

    pub fn deinit(self: *Decoded) void {
        const child = self.arena.child_allocator;
        self.arena.deinit();
        child.destroy(self.arena);
        self.* = undefined;
    }
};

/// Decode a whole message payload, allocating from `allocator`.
///
/// Every slice in the result points into `allocator`, so this is meant for an
/// arena the caller can reset or drop wholesale. A receive loop that resets one
/// arena per message pays nothing per message once it is warm, where `decode`
/// pays an arena struct and its first pages every time. `decode` wraps this
/// with an arena of its own for callers that would rather not keep one.
///
/// The result borrows nothing from `payload`: the decoder dupes strings,
/// symbols and binaries into `allocator` rather than pointing into its input,
/// so the message outlives the buffer it was read from.
///
/// Two things a caller has to know, because `Message` has no destructor and
/// nothing here tracks what it allocated:
///
/// - `allocator` must be an arena the caller resets or drops. Handing this a
///   general-purpose allocator directly leaks the whole message with no way to
///   reclaim it — where `decode` would have been safe.
/// - On error, what was already allocated is *not* rolled back. A caller
///   reusing one arena across messages should reset it after a failed decode
///   rather than decoding the next message on top.
pub fn decodeInto(allocator: Allocator, payload: []const u8) DecodeError!Message {
    const a = allocator;
    var msg = Message{};

    var data: std.ArrayList([]const u8) = .empty;
    var sequences: std.ArrayList([]const AmqpValue) = .empty;

    var offset: usize = 0;
    while (offset < payload.len) {
        const result = decoder.decode(a, payload[offset..]) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.MalformedBody,
        };
        if (result.bytes_consumed == 0) return error.MalformedBody;
        offset += result.bytes_consumed;

        if (result.value != .described) return error.UnexpectedSection;
        const code = switch (result.value.described.descriptor.*) {
            .ulong => |c| c,
            else => return error.UnexpectedSection,
        };
        const inner = result.value.described.value.*;

        switch (code) {
            descriptor.header => msg.header = try headerFrom(inner),
            descriptor.delivery_annotations => msg.delivery_annotations = try mapFrom(inner),
            descriptor.message_annotations => msg.message_annotations = try mapFrom(inner),
            descriptor.properties => msg.properties = try propertiesFrom(inner),
            descriptor.application_properties => msg.application_properties = try mapFrom(inner),
            descriptor.data => try data.append(a, switch (inner) {
                .binary, .string => |b| b,
                else => return error.MalformedBody,
            }),
            descriptor.amqp_sequence => try sequences.append(a, switch (inner) {
                .list => |items| items,
                else => return error.MalformedBody,
            }),
            descriptor.amqp_value => msg.body = .{ .value = inner },
            descriptor.footer => msg.footer = try mapFrom(inner),
            else => return error.UnexpectedSection,
        }
    }

    if (data.items.len > 0) {
        msg.body = .{ .data = data.items };
    } else if (sequences.items.len > 0) {
        msg.body = .{ .sequence = sequences.items };
    }

    return msg;
}

/// Decode a whole message payload into an arena the result owns.
pub fn decode(allocator: Allocator, payload: []const u8) DecodeError!Decoded {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = .init(allocator);
    errdefer arena.deinit();

    return .{ .arena = arena, .message = try decodeInto(arena.allocator(), payload) };
}

fn listOf(value: AmqpValue) DecodeError![]const AmqpValue {
    return switch (value) {
        .list => |items| items,
        .null => &.{},
        else => error.MalformedBody,
    };
}

fn mapFrom(value: AmqpValue) DecodeError!Fields {
    return switch (value) {
        .map => |m| m,
        .null => &.{},
        else => error.MalformedBody,
    };
}

fn headerFrom(value: AmqpValue) DecodeError!Header {
    const list = try listOf(value);
    return .{
        .durable = (try boolAt(list, 0)) orelse false,
        .priority = try ubyteAt(list, 1),
        .ttl = try uintAt(list, 2),
        .first_acquirer = (try boolAt(list, 3)) orelse false,
        .delivery_count = try uintAt(list, 4),
    };
}

fn propertiesFrom(value: AmqpValue) DecodeError!Properties {
    const list = try listOf(value);
    return .{
        .message_id = at(list, 0),
        .user_id = try bytesAt(list, 1),
        .to = try bytesAt(list, 2),
        .subject = try bytesAt(list, 3),
        .reply_to = try bytesAt(list, 4),
        .correlation_id = at(list, 5),
        .content_type = try bytesAt(list, 6),
        .content_encoding = try bytesAt(list, 7),
        .absolute_expiry_time = try timestampAt(list, 8),
        .creation_time = try timestampAt(list, 9),
        .group_id = try bytesAt(list, 10),
        .group_sequence = try uintAt(list, 11),
        .reply_to_group_id = try bytesAt(list, 12),
    };
}

fn at(list: []const AmqpValue, index: usize) ?AmqpValue {
    if (index >= list.len) return null;
    if (list[index] == .null) return null;
    return list[index];
}

fn bytesAt(list: []const AmqpValue, index: usize) DecodeError!?[]const u8 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .string, .symbol, .binary => |s| s,
        else => error.MalformedBody,
    };
}

fn boolAt(list: []const AmqpValue, index: usize) DecodeError!?bool {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .boolean => |b| b,
        else => error.MalformedBody,
    };
}

fn uintAt(list: []const AmqpValue, index: usize) DecodeError!?u32 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .uint => |n| n,
        .ushort => |n| n,
        .ubyte => |n| n,
        else => error.MalformedBody,
    };
}

fn ubyteAt(list: []const AmqpValue, index: usize) DecodeError!?u8 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .ubyte => |n| n,
        .ushort => |n| std.math.cast(u8, n) orelse error.MalformedBody,
        .uint => |n| std.math.cast(u8, n) orelse error.MalformedBody,
        else => error.MalformedBody,
    };
}

fn timestampAt(list: []const AmqpValue, index: usize) DecodeError!?i64 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .timestamp, .long => |n| n,
        .int => |n| n,
        else => error.MalformedBody,
    };
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;

test "a data message round-trips" {
    const allocator = testing.allocator;
    const app_props = [_]MapEntry{
        .{ .key = .{ .string = "operation" }, .value = .{ .string = "put-token" } },
    };
    const msg = Message{
        .properties = .{ .message_id = .{ .string = "id-1" }, .to = "$cbs" },
        .application_properties = &app_props,
        .body = .{ .data = &.{"hello"} },
    };

    const bytes = try encodeAlloc(allocator, msg);
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();

    const got = decoded.message;
    try testing.expectEqualStrings("id-1", got.properties.message_id.?.string);
    try testing.expectEqualStrings("$cbs", got.properties.to.?);
    try testing.expectEqualStrings("operation", got.application_properties.?[0].key.string);
    try testing.expectEqualStrings("put-token", got.application_properties.?[0].value.string);
    try testing.expectEqual(@as(usize, 1), got.body.data.len);
    try testing.expectEqualStrings("hello", got.body.data[0]);
}

test "a value body round-trips" {
    const allocator = testing.allocator;
    const msg = Message{ .body = .{ .value = .{ .string = "SharedAccessSignature sr=..." } } };
    const bytes = try encodeAlloc(allocator, msg);
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();
    try testing.expectEqualStrings("SharedAccessSignature sr=...", decoded.message.body.value.string);
}

test "multiple data sections are kept in order" {
    const allocator = testing.allocator;
    const msg = Message{ .body = .{ .data = &.{ "one", "two", "three" } } };
    const bytes = try encodeAlloc(allocator, msg);
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();

    const sections = decoded.message.body.data;
    try testing.expectEqual(@as(usize, 3), sections.len);
    try testing.expectEqualStrings("one", sections[0]);
    try testing.expectEqualStrings("two", sections[1]);
    try testing.expectEqualStrings("three", sections[2]);
}

test "header and annotations round-trip" {
    const allocator = testing.allocator;
    const annotations = [_]MapEntry{
        .{ .key = .{ .symbol = "x-opt-partition-key" }, .value = .{ .string = "pk" } },
    };
    const msg = Message{
        .header = .{ .durable = true, .priority = 4, .ttl = 60000 },
        .message_annotations = &annotations,
        .body = .{ .data = &.{"x"} },
    };
    const bytes = try encodeAlloc(allocator, msg);
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();

    const got = decoded.message;
    try testing.expect(got.header.durable);
    try testing.expectEqual(@as(u8, 4), got.header.priority.?);
    try testing.expectEqual(@as(u32, 60000), got.header.ttl.?);
    try testing.expectEqualStrings("pk", got.message_annotations.?[0].value.string);
}

test "an empty message encodes to nothing" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{});
    defer allocator.free(bytes);
    try testing.expectEqual(@as(usize, 0), bytes.len);

    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();
    try testing.expectEqual(Body.empty, decoded.message.body);
}

test "sections are written in the order the spec requires" {
    const allocator = testing.allocator;
    const app_props = [_]MapEntry{
        .{ .key = .{ .string = "k" }, .value = .{ .string = "v" } },
    };
    const annotations = [_]MapEntry{
        .{ .key = .{ .symbol = "a" }, .value = .{ .string = "b" } },
    };
    const msg = Message{
        .header = .{ .durable = true },
        .message_annotations = &annotations,
        .properties = .{ .to = "dest" },
        .application_properties = &app_props,
        .body = .{ .data = &.{"body"} },
        .footer = &annotations,
    };
    const bytes = try encodeAlloc(allocator, msg);
    defer allocator.free(bytes);

    // Walk the sections and check the descriptor codes appear in order.
    const expected = [_]u64{
        descriptor.header,
        descriptor.message_annotations,
        descriptor.properties,
        descriptor.application_properties,
        descriptor.data,
        descriptor.footer,
    };
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();

    var offset: usize = 0;
    var index: usize = 0;
    while (offset < bytes.len) : (index += 1) {
        const result = try decoder.decode(arena.allocator(), bytes[offset..]);
        offset += result.bytes_consumed;
        try testing.expectEqual(expected[index], result.value.described.descriptor.ulong);
    }
    try testing.expectEqual(expected.len, index);
}

test "a payload that is not a described section is rejected" {
    const allocator = testing.allocator;
    try testing.expectError(error.UnexpectedSection, decode(allocator, &.{0x41}));
}

test "decoding survives allocation failure" {
    const Case = struct {
        fn run(allocator: Allocator) !void {
            const app_props = [_]MapEntry{
                .{ .key = .{ .string = "operation" }, .value = .{ .string = "put-token" } },
            };
            const msg = Message{
                .properties = .{ .to = "$cbs" },
                .application_properties = &app_props,
                .body = .{ .data = &.{ "a", "b" } },
            };
            const bytes = try encodeAlloc(allocator, msg);
            defer allocator.free(bytes);
            var decoded = try decode(allocator, bytes);
            defer decoded.deinit();
            try testing.expectEqual(@as(usize, 2), decoded.message.body.data.len);
        }
    };
    try testing.checkAllAllocationFailures(testing.allocator, Case.run, .{});
}

test "a decoded message borrows nothing from the payload it was read from" {
    // `decodeInto` exists so a receive loop can reset one arena per message
    // instead of building one, which is only sound if the message does not
    // point back into the frame buffer the payload came out of — a buffer the
    // driver overwrites on the very next frame. Prove it by freeing the
    // payload before reading the message.
    const allocator = testing.allocator;
    const app_props = [_]MapEntry{
        .{ .key = .{ .string = "partition" }, .value = .{ .string = "7" } },
    };
    const annotations = [_]MapEntry{
        .{ .key = .{ .symbol = "x-opt-offset" }, .value = .{ .string = "12345" } },
    };
    // A compound value as well as flat strings. The decoder has a separate
    // path for arrays — small ones are staged through a stack buffer — so an
    // element that aliased its input would dangle into a dead frame rather
    // than into merely freed memory, and the flat fields would not show it.
    var array_items = [_]AmqpValue{
        .{ .string = "first" },
        .{ .string = "second" },
    };
    const nested = [_]MapEntry{
        .{ .key = .{ .symbol = "x-opt-list" }, .value = .{ .array = &array_items } },
    };
    const bytes = try encodeAlloc(allocator, .{
        .message_annotations = &annotations,
        .properties = .{ .message_id = .{ .string = "id-1" }, .to = "eh" },
        .application_properties = &app_props,
        .delivery_annotations = &nested,
        .body = .{ .data = &.{"the body"} },
    });

    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const msg = try decodeInto(arena.allocator(), bytes);

    // Scribble as well as free. Under the testing allocator a borrow trips the
    // use-after-free check first, but that check is a property of the harness;
    // the scribble is what makes the read a demonstrably wrong answer under
    // any allocator, which is the thing production actually does.
    @memset(bytes, 0xAA);
    allocator.free(bytes);

    try testing.expectEqualStrings("the body", msg.body.data[0]);
    try testing.expectEqualStrings("eh", msg.properties.to.?);
    try testing.expectEqualStrings("id-1", msg.properties.message_id.?.string);
    try testing.expectEqualStrings("partition", msg.application_properties.?[0].key.string);
    try testing.expectEqualStrings("7", msg.application_properties.?[0].value.string);
    try testing.expectEqualStrings("x-opt-offset", msg.message_annotations.?[0].key.symbol);
    try testing.expectEqualStrings("12345", msg.message_annotations.?[0].value.string);
    const decoded_array = msg.delivery_annotations.?[0].value.array;
    try testing.expectEqual(@as(usize, 2), decoded_array.len);
    try testing.expectEqualStrings("first", decoded_array[0].string);
    try testing.expectEqualStrings("second", decoded_array[1].string);
}

test "one arena reset per message decodes a batch without allocating per message" {
    // The point of the entry point: over a prefetch window the per-message
    // arena cost amortises to nothing, where `decode` pays it every time.
    const allocator = testing.allocator;
    var counting = CountingAllocator{ .child = allocator };
    const app_props = [_]MapEntry{
        .{ .key = .{ .string = "k" }, .value = .{ .string = "v" } },
    };
    const bytes = try encodeAlloc(allocator, .{
        .properties = .{ .to = "eh" },
        .application_properties = &app_props,
        .body = .{ .data = &.{"a 40-byte-ish body, near enough for this"} },
    });
    defer allocator.free(bytes);

    var arena: std.heap.ArenaAllocator = .init(counting.allocator());
    defer arena.deinit();

    // Warm the arena. Two rounds, not one: the first decode may land across
    // two pages, and the first reset consolidates them into a single node — so
    // counting from after one decode still sees that consolidation.
    _ = try decodeInto(arena.allocator(), bytes);
    _ = arena.reset(.retain_capacity);
    _ = try decodeInto(arena.allocator(), bytes);

    const before = counting.allocs;
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        _ = arena.reset(.retain_capacity);
        const msg = try decodeInto(arena.allocator(), bytes);
        try testing.expectEqualStrings("eh", msg.properties.to.?);
    }
    try testing.expectEqual(@as(usize, 0), counting.allocs - before);
}

/// Counts allocations so a test can assert that a code path performs none.
const CountingAllocator = struct {
    child: Allocator,
    allocs: usize = 0,

    fn allocator(self: *CountingAllocator) Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const out = self.child.rawAlloc(len, alignment, ra);
        if (out != null) self.allocs += 1;
        return out;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(buf, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const out = self.child.rawRemap(buf, alignment, new_len, ra);
        // Only a move is a new allocation; an in-place grow is not.
        if (out) |p| if (p != buf.ptr) {
            self.allocs += 1;
        };
        return out;
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(buf, alignment, ra);
    }
};
