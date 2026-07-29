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

/// Decode a whole message payload, which is a concatenation of sections.
pub fn decode(allocator: Allocator, payload: []const u8) DecodeError!Decoded {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = .init(allocator);
    errdefer arena.deinit();

    const a = arena.allocator();
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

    return .{ .arena = arena, .message = msg };
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
