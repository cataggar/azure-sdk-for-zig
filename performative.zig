//! AMQP 1.0 performative encoding and decoding.
//!
//! `azure-uamqp-zig` declares the performative structs but ships no codec for
//! them, so this module encodes and decodes them as described lists. Field
//! order follows the OASIS AMQP 1.0 specification §2.7 and §5.3; trailing null
//! fields are elided as §1.3 permits.
//!
//! Encoding is done directly rather than through `uamqp.encoder` because that
//! encoder writes array elements of variable-width types without their length
//! prefix, which no peer will accept. Decoding does use `uamqp.decoder`, whose
//! array handling is correct.

const std = @import("std");
const uamqp = @import("uamqp");

const Allocator = std.mem.Allocator;
const AmqpValue = uamqp.AmqpValue;
const MapEntry = uamqp.MapEntry;
const encoder = uamqp.encoder;
const decoder = uamqp.decoder;

pub const descriptor = uamqp.definitions.descriptor;
pub const SaslCode = uamqp.definitions.SaslCode;

/// Descriptor code for `error` (§2.8.15), which uamqp omits.
pub const error_descriptor: u64 = 0x000000000000001d;

pub const EncodeError = error{OutOfMemory};

pub const DecodeError = error{
    OutOfMemory,
    NotDescribed,
    UnknownDescriptor,
    MalformedBody,
};

/// A symbol-keyed map, the AMQP `fields` type.
pub const Fields = []const MapEntry;

/// An AMQP `error` (§2.8.15).
pub const AmqpError = struct {
    condition: []const u8,
    description: ?[]const u8 = null,
    info: ?Fields = null,
};

/// Open (§2.7.1).
pub const Open = struct {
    container_id: []const u8,
    hostname: ?[]const u8 = null,
    max_frame_size: u32 = std.math.maxInt(u32),
    channel_max: u16 = std.math.maxInt(u16),
    idle_time_out: ?u32 = null,
    outgoing_locales: ?[]const []const u8 = null,
    incoming_locales: ?[]const []const u8 = null,
    offered_capabilities: ?[]const []const u8 = null,
    desired_capabilities: ?[]const []const u8 = null,
    properties: ?Fields = null,
};

/// Begin (§2.7.2).
pub const Begin = struct {
    remote_channel: ?u16 = null,
    next_outgoing_id: u32 = 0,
    incoming_window: u32 = 0,
    outgoing_window: u32 = 0,
    handle_max: u32 = std.math.maxInt(u32),
    offered_capabilities: ?[]const []const u8 = null,
    desired_capabilities: ?[]const []const u8 = null,
    properties: ?Fields = null,
};

/// End (§2.7.8).
pub const End = struct {
    err: ?AmqpError = null,
};

/// Close (§2.7.9).
pub const Close = struct {
    err: ?AmqpError = null,
};

/// sasl-mechanisms (§5.3.2).
pub const SaslMechanisms = struct {
    sasl_server_mechanisms: []const []const u8,
};

/// sasl-init (§5.3.3).
pub const SaslInit = struct {
    mechanism: []const u8,
    initial_response: ?[]const u8 = null,
    hostname: ?[]const u8 = null,
};

/// sasl-outcome (§5.3.6).
pub const SaslOutcome = struct {
    code: SaslCode,
    additional_data: ?[]const u8 = null,
};

/// A performative the connection driver understands.
///
/// Slices borrow from the `Decoded` that produced them and become invalid once
/// it is released.
pub const Performative = union(enum) {
    open: Open,
    begin: Begin,
    end: End,
    close: Close,
    sasl_mechanisms: SaslMechanisms,
    sasl_init: SaslInit,
    sasl_outcome: SaslOutcome,

    pub fn descriptorCode(self: Performative) u64 {
        return switch (self) {
            .open => descriptor.open,
            .begin => descriptor.begin,
            .end => descriptor.end,
            .close => descriptor.close,
            .sasl_mechanisms => descriptor.sasl_mechanisms,
            .sasl_init => descriptor.sasl_init,
            .sasl_outcome => descriptor.sasl_outcome,
        };
    }
};

// ─────────────────────── Field encoding ───────────────────────

/// One slot of a described list.
///
/// `symbols` and `err` exist because neither has a faithful `AmqpValue`
/// representation: symbol multiples cannot round-trip through uamqp's array
/// encoder, and `error` is itself a described list.
const Field = union(enum) {
    null,
    value: AmqpValue,
    symbols: []const []const u8,
    err: AmqpError,
};

fn optionalString(v: ?[]const u8) Field {
    return if (v) |s| .{ .value = .{ .string = s } } else .null;
}

fn optionalSymbol(v: ?[]const u8) Field {
    return if (v) |s| .{ .value = .{ .symbol = s } } else .null;
}

fn optionalBinary(v: ?[]const u8) Field {
    return if (v) |s| .{ .value = .{ .binary = s } } else .null;
}

fn optionalUint(v: ?u32) Field {
    return if (v) |n| .{ .value = .{ .uint = n } } else .null;
}

fn optionalUshort(v: ?u16) Field {
    return if (v) |n| .{ .value = .{ .ushort = n } } else .null;
}

fn optionalFields(v: ?Fields) Field {
    return if (v) |m| .{ .value = .{ .map = @constCast(m) } } else .null;
}

fn optionalError(v: ?AmqpError) Field {
    return if (v) |e| .{ .err = e } else .null;
}

fn optionalSymbols(v: ?[]const []const u8) Field {
    const list = v orelse return .null;
    if (list.len == 0) return .null;
    return .{ .symbols = list };
}

/// Write a descriptor code using the shortest legal ulong encoding.
fn writeDescriptor(code: u64, buf: *encoder.Buffer) EncodeError!void {
    try buf.writeByte(0x00);
    try encoder.encode(.{ .ulong = code }, buf);
}

fn encodeField(allocator: Allocator, field: Field, buf: *encoder.Buffer) EncodeError!void {
    switch (field) {
        .null => try buf.writeByte(0x40),
        .value => |v| try encoder.encode(v, buf),
        .symbols => |s| try encodeSymbolMultiple(s, buf),
        .err => |e| try encodeError(allocator, e, buf),
    }
}

/// Encode a described list, dropping trailing null fields.
fn encodeDescribedList(
    allocator: Allocator,
    code: u64,
    fields: []const Field,
    buf: *encoder.Buffer,
) EncodeError!void {
    var count = fields.len;
    while (count > 0 and fields[count - 1] == .null) count -= 1;

    try writeDescriptor(code, buf);

    if (count == 0) return buf.writeByte(0x45); // list0

    var body = encoder.Buffer.initDynamic(allocator);
    defer body.deinit();
    for (fields[0..count]) |field| try encodeField(allocator, field, &body);

    const bytes = body.written();
    if (bytes.len + 1 <= 0xff and count <= 0xff) {
        try buf.writeByte(0xc0); // list8
        try buf.writeByte(@intCast(bytes.len + 1));
        try buf.writeByte(@intCast(count));
    } else {
        try buf.writeByte(0xd0); // list32
        var size_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &size_bytes, @intCast(bytes.len + 4), .big);
        try buf.writeAll(&size_bytes);
        std.mem.writeInt(u32, &size_bytes, @intCast(count), .big);
        try buf.writeAll(&size_bytes);
    }
    try buf.writeAll(bytes);
}

/// Encode an AMQP `multiple` of symbols.
///
/// A lone symbol is written bare, which `multiple` permits and every reference
/// client accepts; two or more become a symbol array.
fn encodeSymbolMultiple(symbols: []const []const u8, buf: *encoder.Buffer) EncodeError!void {
    if (symbols.len == 0) return buf.writeByte(0x40);
    if (symbols.len == 1) return encoder.encode(.{ .symbol = symbols[0] }, buf);

    var wide = symbols.len > 0xff;
    for (symbols) |s| {
        if (s.len > 0xff) wide = true;
    }

    var narrow_len: usize = 1; // shared constructor
    for (symbols) |s| narrow_len += 1 + s.len;
    if (!wide and narrow_len + 1 > 0xff) wide = true;

    if (!wide) {
        try buf.writeByte(0xe0); // array8
        try buf.writeByte(@intCast(narrow_len + 1));
        try buf.writeByte(@intCast(symbols.len));
        try buf.writeByte(0xa3); // sym8
        for (symbols) |s| {
            try buf.writeByte(@intCast(s.len));
            try buf.writeAll(s);
        }
        return;
    }

    var wide_len: usize = 1;
    for (symbols) |s| wide_len += 4 + s.len;

    try buf.writeByte(0xf0); // array32
    var size_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &size_bytes, @intCast(wide_len + 4), .big);
    try buf.writeAll(&size_bytes);
    std.mem.writeInt(u32, &size_bytes, @intCast(symbols.len), .big);
    try buf.writeAll(&size_bytes);
    try buf.writeByte(0xb3); // sym32
    for (symbols) |s| {
        std.mem.writeInt(u32, &size_bytes, @intCast(s.len), .big);
        try buf.writeAll(&size_bytes);
        try buf.writeAll(s);
    }
}

fn encodeError(allocator: Allocator, e: AmqpError, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        .{ .value = .{ .symbol = e.condition } },
        optionalString(e.description),
        optionalFields(e.info),
    };
    try encodeDescribedList(allocator, error_descriptor, &fields, buf);
}

// ─────────────────────── Performative encoding ───────────────────────

/// Encode any supported performative into `buf`.
pub fn encode(allocator: Allocator, p: Performative, buf: *encoder.Buffer) EncodeError!void {
    switch (p) {
        .open => |v| try encodeOpen(allocator, v, buf),
        .begin => |v| try encodeBegin(allocator, v, buf),
        .end => |v| try encodeEnd(allocator, v, buf),
        .close => |v| try encodeClose(allocator, v, buf),
        .sasl_mechanisms => |v| try encodeSaslMechanisms(allocator, v, buf),
        .sasl_init => |v| try encodeSaslInit(allocator, v, buf),
        .sasl_outcome => |v| try encodeSaslOutcome(allocator, v, buf),
    }
}

/// Encode a performative into a freshly allocated buffer owned by the caller.
pub fn encodeAlloc(allocator: Allocator, p: Performative) EncodeError![]u8 {
    var buf = encoder.Buffer.initDynamic(allocator);
    defer buf.deinit();
    try encode(allocator, p, &buf);
    return allocator.dupe(u8, buf.written());
}

pub fn encodeOpen(allocator: Allocator, open: Open, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        .{ .value = .{ .string = open.container_id } },
        optionalString(open.hostname),
        .{ .value = .{ .uint = open.max_frame_size } },
        .{ .value = .{ .ushort = open.channel_max } },
        optionalUint(open.idle_time_out),
        optionalSymbols(open.outgoing_locales),
        optionalSymbols(open.incoming_locales),
        optionalSymbols(open.offered_capabilities),
        optionalSymbols(open.desired_capabilities),
        optionalFields(open.properties),
    };
    try encodeDescribedList(allocator, descriptor.open, &fields, buf);
}

pub fn encodeBegin(allocator: Allocator, begin: Begin, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        optionalUshort(begin.remote_channel),
        .{ .value = .{ .uint = begin.next_outgoing_id } },
        .{ .value = .{ .uint = begin.incoming_window } },
        .{ .value = .{ .uint = begin.outgoing_window } },
        .{ .value = .{ .uint = begin.handle_max } },
        optionalSymbols(begin.offered_capabilities),
        optionalSymbols(begin.desired_capabilities),
        optionalFields(begin.properties),
    };
    try encodeDescribedList(allocator, descriptor.begin, &fields, buf);
}

pub fn encodeEnd(allocator: Allocator, end: End, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{optionalError(end.err)};
    try encodeDescribedList(allocator, descriptor.end, &fields, buf);
}

pub fn encodeClose(allocator: Allocator, close: Close, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{optionalError(close.err)};
    try encodeDescribedList(allocator, descriptor.close, &fields, buf);
}

pub fn encodeSaslInit(allocator: Allocator, init: SaslInit, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        optionalSymbol(init.mechanism),
        optionalBinary(init.initial_response),
        optionalString(init.hostname),
    };
    try encodeDescribedList(allocator, descriptor.sasl_init, &fields, buf);
}

/// Only a scripted peer emits this; the driver decodes it.
pub fn encodeSaslMechanisms(
    allocator: Allocator,
    mechanisms: SaslMechanisms,
    buf: *encoder.Buffer,
) EncodeError!void {
    const fields = [_]Field{optionalSymbols(mechanisms.sasl_server_mechanisms)};
    try encodeDescribedList(allocator, descriptor.sasl_mechanisms, &fields, buf);
}

/// Only a scripted peer emits this; the driver decodes it.
pub fn encodeSaslOutcome(
    allocator: Allocator,
    outcome: SaslOutcome,
    buf: *encoder.Buffer,
) EncodeError!void {
    const fields = [_]Field{
        .{ .value = .{ .ubyte = @intFromEnum(outcome.code) } },
        optionalBinary(outcome.additional_data),
    };
    try encodeDescribedList(allocator, descriptor.sasl_outcome, &fields, buf);
}

// ─────────────────────── Decoding ───────────────────────

/// A decoded performative together with the arena backing its slices.
pub const Decoded = struct {
    arena: *std.heap.ArenaAllocator,
    performative: Performative,

    pub fn deinit(self: *Decoded) void {
        const child = self.arena.child_allocator;
        self.arena.deinit();
        child.destroy(self.arena);
        self.* = undefined;
    }
};

/// Decode a frame body into a performative.
///
/// Returns `error.UnknownDescriptor` for performatives this driver does not
/// model, which callers treat as "ignore and continue".
pub fn decode(allocator: Allocator, body: []const u8) DecodeError!Decoded {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = .init(allocator);
    errdefer arena.deinit();

    const result = decoder.decode(arena.allocator(), body) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.MalformedBody,
    };
    const performative = try fromValue(arena.allocator(), result.value);
    return .{ .arena = arena, .performative = performative };
}

/// Peek at the descriptor code of a frame body without fully decoding it.
pub fn peekDescriptor(body: []const u8) ?u64 {
    if (body.len < 2 or body[0] != 0x00) return null;
    return switch (body[1]) {
        0x53 => if (body.len >= 3) @as(u64, body[2]) else null,
        0x44 => @as(u64, 0),
        0x80 => if (body.len >= 10) std.mem.readInt(u64, body[2..10], .big) else null,
        else => null,
    };
}

fn fromValue(allocator: Allocator, value: AmqpValue) DecodeError!Performative {
    if (value != .described) return error.NotDescribed;
    const code = switch (value.described.descriptor.*) {
        .ulong => |c| c,
        else => return error.NotDescribed,
    };
    const list: []const AmqpValue = switch (value.described.value.*) {
        .list => |items| items,
        .null => &.{},
        else => return error.MalformedBody,
    };

    return switch (code) {
        descriptor.open => .{ .open = .{
            .container_id = try stringAt(list, 0) orelse "",
            .hostname = try stringAt(list, 1),
            .max_frame_size = (try uintAt(list, 2)) orelse std.math.maxInt(u32),
            .channel_max = (try ushortAt(list, 3)) orelse std.math.maxInt(u16),
            .idle_time_out = try uintAt(list, 4),
            .outgoing_locales = try symbolsAt(allocator, list, 5),
            .incoming_locales = try symbolsAt(allocator, list, 6),
            .offered_capabilities = try symbolsAt(allocator, list, 7),
            .desired_capabilities = try symbolsAt(allocator, list, 8),
            .properties = try fieldsAt(list, 9),
        } },
        descriptor.begin => .{ .begin = .{
            .remote_channel = try ushortAt(list, 0),
            .next_outgoing_id = (try uintAt(list, 1)) orelse 0,
            .incoming_window = (try uintAt(list, 2)) orelse 0,
            .outgoing_window = (try uintAt(list, 3)) orelse 0,
            .handle_max = (try uintAt(list, 4)) orelse std.math.maxInt(u32),
            .offered_capabilities = try symbolsAt(allocator, list, 5),
            .desired_capabilities = try symbolsAt(allocator, list, 6),
            .properties = try fieldsAt(list, 7),
        } },
        descriptor.end => .{ .end = .{ .err = try errorAt(list, 0) } },
        descriptor.close => .{ .close = .{ .err = try errorAt(list, 0) } },
        descriptor.sasl_mechanisms => .{ .sasl_mechanisms = .{
            .sasl_server_mechanisms = (try symbolsAt(allocator, list, 0)) orelse &.{},
        } },
        descriptor.sasl_init => .{ .sasl_init = .{
            .mechanism = (try symbolAt(list, 0)) orelse "",
            .initial_response = try binaryAt(list, 1),
            .hostname = try stringAt(list, 2),
        } },
        descriptor.sasl_outcome => .{ .sasl_outcome = .{
            .code = saslCodeFromInt((try ubyteAt(list, 0)) orelse 0) orelse
                return error.MalformedBody,
            .additional_data = try binaryAt(list, 1),
        } },
        else => error.UnknownDescriptor,
    };
}

fn saslCodeFromInt(value: u8) ?SaslCode {
    return switch (value) {
        0 => .ok,
        1 => .auth,
        2 => .sys,
        3 => .sys_perm,
        4 => .sys_temp,
        else => null,
    };
}

fn at(list: []const AmqpValue, index: usize) ?AmqpValue {
    if (index >= list.len) return null;
    if (list[index] == .null) return null;
    return list[index];
}

fn stringAt(list: []const AmqpValue, index: usize) DecodeError!?[]const u8 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .string, .symbol => |s| s,
        else => error.MalformedBody,
    };
}

fn symbolAt(list: []const AmqpValue, index: usize) DecodeError!?[]const u8 {
    return stringAt(list, index);
}

fn binaryAt(list: []const AmqpValue, index: usize) DecodeError!?[]const u8 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .binary, .string, .symbol => |s| s,
        else => error.MalformedBody,
    };
}

fn uintAt(list: []const AmqpValue, index: usize) DecodeError!?u32 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .uint => |n| n,
        .ubyte => |n| n,
        .ushort => |n| n,
        .ulong => |n| std.math.cast(u32, n) orelse error.MalformedBody,
        else => error.MalformedBody,
    };
}

fn ushortAt(list: []const AmqpValue, index: usize) DecodeError!?u16 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .ushort => |n| n,
        .ubyte => |n| n,
        .uint => |n| std.math.cast(u16, n) orelse error.MalformedBody,
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

fn fieldsAt(list: []const AmqpValue, index: usize) DecodeError!?Fields {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .map => |m| m,
        else => error.MalformedBody,
    };
}

fn symbolsAt(
    allocator: Allocator,
    list: []const AmqpValue,
    index: usize,
) DecodeError!?[]const []const u8 {
    const v = at(list, index) orelse return null;
    switch (v) {
        // A `multiple` of one is written bare.
        .symbol, .string => |s| {
            const out = try allocator.alloc([]const u8, 1);
            out[0] = s;
            return out;
        },
        .array, .list => |items| {
            const out = try allocator.alloc([]const u8, items.len);
            for (items, 0..) |item, i| {
                out[i] = switch (item) {
                    .symbol, .string => |s| s,
                    else => return error.MalformedBody,
                };
            }
            return out;
        },
        else => return error.MalformedBody,
    }
}

fn errorAt(list: []const AmqpValue, index: usize) DecodeError!?AmqpError {
    const v = at(list, index) orelse return null;
    if (v != .described) return error.MalformedBody;
    const inner: []const AmqpValue = switch (v.described.value.*) {
        .list => |items| items,
        .null => &.{},
        else => return error.MalformedBody,
    };
    return .{
        .condition = (try symbolAt(inner, 0)) orelse return error.MalformedBody,
        .description = try stringAt(inner, 1),
        .info = try fieldsAt(inner, 2),
    };
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;

test "encode open elides trailing null fields" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .open = .{ .container_id = "abc" } });
    defer allocator.free(bytes);

    // 00 53 10          described, smallulong 0x10 (open)
    // c0 0f 04          list8, 15 bytes, 4 fields
    // a1 03 61 62 63    container-id "abc"
    // 40                hostname null
    // 70 ff ff ff ff    max-frame-size 0xFFFFFFFF
    // 60 ff ff          channel-max 0xFFFF
    try testing.expectEqualSlices(u8, &.{
        0x00, 0x53, 0x10,
        0xc0, 0x0f, 0x04,
        0xa1, 0x03, 'a',
        'b',  'c',  0x40,
        0x70, 0xff, 0xff,
        0xff, 0xff, 0x60,
        0xff, 0xff,
    }, bytes);
}

test "encode open with the fields Event Hubs needs" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .open = .{
        .container_id = "zig",
        .hostname = "ns.servicebus.windows.net",
        .max_frame_size = 65536,
        .channel_max = 65535,
        .idle_time_out = 60000,
        .desired_capabilities = &.{"com.microsoft:georeplication"},
    } });
    defer allocator.free(bytes);

    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    // Body, then the list header, then the descriptor.
    try expected.appendSlice(allocator, &.{ 0xa1, 0x03 });
    try expected.appendSlice(allocator, "zig");
    try expected.appendSlice(allocator, &.{ 0xa1, 25 });
    try expected.appendSlice(allocator, "ns.servicebus.windows.net");
    try expected.appendSlice(allocator, &.{ 0x70, 0x00, 0x01, 0x00, 0x00 });
    try expected.appendSlice(allocator, &.{ 0x60, 0xff, 0xff });
    try expected.appendSlice(allocator, &.{ 0x70, 0x00, 0x00, 0xea, 0x60 });
    try expected.appendSlice(allocator, &.{ 0x40, 0x40, 0x40 });
    try expected.appendSlice(allocator, &.{ 0xa3, 28 });
    try expected.appendSlice(allocator, "com.microsoft:georeplication");

    const body_len = expected.items.len;
    try expected.insertSlice(allocator, 0, &.{
        0x00, 0x53, 0x10, 0xc0, @intCast(body_len + 1), 9,
    });

    try testing.expectEqualSlices(u8, expected.items, bytes);
}

test "encode a symbol multiple of two as an array" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .open = .{
        .container_id = "c",
        .desired_capabilities = &.{ "ab", "cd" },
    } });
    defer allocator.free(bytes);

    // array8: e0 <size> <count> a3 02 'a' 'b' 02 'c' 'd'
    const array_bytes = [_]u8{ 0xe0, 0x08, 0x02, 0xa3, 0x02, 'a', 'b', 0x02, 'c', 'd' };
    try testing.expect(std.mem.indexOf(u8, bytes, &array_bytes) != null);
}

test "round trip open" {
    const allocator = testing.allocator;
    const props = [_]MapEntry{
        .{ .key = .{ .symbol = "product" }, .value = .{ .string = "azure-sdk-for-zig" } },
    };
    const bytes = try encodeAlloc(allocator, .{ .open = .{
        .container_id = "container",
        .hostname = "host",
        .max_frame_size = 4096,
        .channel_max = 17,
        .idle_time_out = 1234,
        .offered_capabilities = &.{ "one", "two" },
        .desired_capabilities = &.{"three"},
        .properties = &props,
    } });
    defer allocator.free(bytes);

    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();
    const open = decoded.performative.open;
    try testing.expectEqualStrings("container", open.container_id);
    try testing.expectEqualStrings("host", open.hostname.?);
    try testing.expectEqual(@as(u32, 4096), open.max_frame_size);
    try testing.expectEqual(@as(u16, 17), open.channel_max);
    try testing.expectEqual(@as(u32, 1234), open.idle_time_out.?);
    try testing.expectEqual(@as(usize, 2), open.offered_capabilities.?.len);
    try testing.expectEqualStrings("two", open.offered_capabilities.?[1]);
    try testing.expectEqual(@as(usize, 1), open.desired_capabilities.?.len);
    try testing.expectEqualStrings("three", open.desired_capabilities.?[0]);
    try testing.expectEqualStrings("product", open.properties.?[0].key.symbol);
}

test "round trip begin" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .begin = .{
        .remote_channel = 3,
        .next_outgoing_id = 1,
        .incoming_window = 100,
        .outgoing_window = 200,
        .handle_max = 42,
    } });
    defer allocator.free(bytes);

    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();
    const begin = decoded.performative.begin;
    try testing.expectEqual(@as(u16, 3), begin.remote_channel.?);
    try testing.expectEqual(@as(u32, 1), begin.next_outgoing_id);
    try testing.expectEqual(@as(u32, 100), begin.incoming_window);
    try testing.expectEqual(@as(u32, 200), begin.outgoing_window);
    try testing.expectEqual(@as(u32, 42), begin.handle_max);
}

test "encode close without an error is a bare descriptor" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .close = .{} });
    defer allocator.free(bytes);
    try testing.expectEqualSlices(u8, &.{ 0x00, 0x53, 0x18, 0x45 }, bytes);
}

test "round trip close with an error condition" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .close = .{ .err = .{
        .condition = "amqp:connection:forced",
        .description = "server is going away",
    } } });
    defer allocator.free(bytes);

    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();
    const err = decoded.performative.close.err.?;
    try testing.expectEqualStrings("amqp:connection:forced", err.condition);
    try testing.expectEqualStrings("server is going away", err.description.?);
}

test "round trip end with an error condition" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .end = .{ .err = .{
        .condition = "amqp:link:detach-forced",
    } } });
    defer allocator.free(bytes);

    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();
    try testing.expectEqualStrings("amqp:link:detach-forced", decoded.performative.end.err.?.condition);
    try testing.expect(decoded.performative.end.err.?.description == null);
}

test "encode sasl-init matches the anonymous payload Go sends" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .sasl_init = .{
        .mechanism = "ANONYMOUS",
        .initial_response = "anonymous",
    } });
    defer allocator.free(bytes);

    // 00 53 41  described, sasl-init
    // c0 17 02  list8, 23 bytes (22 body + count), 2 fields
    // a3 09 ANONYMOUS
    // a0 09 anonymous
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, &.{ 0x00, 0x53, 0x41, 0xc0, 0x17, 0x02, 0xa3, 0x09 });
    try expected.appendSlice(allocator, "ANONYMOUS");
    try expected.appendSlice(allocator, &.{ 0xa0, 0x09 });
    try expected.appendSlice(allocator, "anonymous");
    try testing.expectEqualSlices(u8, expected.items, bytes);
}

test "decode sasl-mechanisms written as a bare symbol" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .sasl_mechanisms = .{
        .sasl_server_mechanisms = &.{"ANONYMOUS"},
    } });
    defer allocator.free(bytes);

    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();
    const mechanisms = decoded.performative.sasl_mechanisms.sasl_server_mechanisms;
    try testing.expectEqual(@as(usize, 1), mechanisms.len);
    try testing.expectEqualStrings("ANONYMOUS", mechanisms[0]);
}

test "decode sasl-mechanisms written as an array" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .sasl_mechanisms = .{
        .sasl_server_mechanisms = &.{ "MSSBCBS", "ANONYMOUS", "EXTERNAL" },
    } });
    defer allocator.free(bytes);

    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();
    const mechanisms = decoded.performative.sasl_mechanisms.sasl_server_mechanisms;
    try testing.expectEqual(@as(usize, 3), mechanisms.len);
    try testing.expectEqualStrings("MSSBCBS", mechanisms[0]);
    try testing.expectEqualStrings("ANONYMOUS", mechanisms[1]);
    try testing.expectEqualStrings("EXTERNAL", mechanisms[2]);
}

test "round trip sasl-outcome" {
    const allocator = testing.allocator;
    for ([_]SaslCode{ .ok, .auth, .sys_temp }) |code| {
        const bytes = try encodeAlloc(allocator, .{ .sasl_outcome = .{ .code = code } });
        defer allocator.free(bytes);
        var decoded = try decode(allocator, bytes);
        defer decoded.deinit();
        try testing.expectEqual(code, decoded.performative.sasl_outcome.code);
    }
}

test "peekDescriptor reads the code without decoding" {
    const allocator = testing.allocator;
    const bytes = try encodeAlloc(allocator, .{ .close = .{} });
    defer allocator.free(bytes);
    try testing.expectEqual(@as(?u64, descriptor.close), peekDescriptor(bytes));
    try testing.expectEqual(@as(?u64, null), peekDescriptor(&.{}));
    try testing.expectEqual(@as(?u64, null), peekDescriptor(&.{ 0xa1, 0x00 }));
}

test "decode rejects bodies that are not described types" {
    const allocator = testing.allocator;
    try testing.expectError(error.NotDescribed, decode(allocator, &.{0x40}));
    try testing.expectError(error.MalformedBody, decode(allocator, &.{ 0x00, 0x53 }));
}

test "decode reports unknown descriptors" {
    const allocator = testing.allocator;
    // 0x12 is `attach`, which this driver does not model yet.
    try testing.expectError(error.UnknownDescriptor, decode(allocator, &.{ 0x00, 0x53, 0x12, 0x45 }));
}

test "encoding survives allocation failure" {
    const Case = struct {
        fn run(allocator: Allocator) !void {
            const bytes = try encodeAlloc(allocator, .{ .open = .{
                .container_id = "container",
                .hostname = "host",
                .idle_time_out = 30000,
                .desired_capabilities = &.{ "one", "two" },
            } });
            defer allocator.free(bytes);
            var decoded = try decode(allocator, bytes);
            defer decoded.deinit();
            try testing.expectEqualStrings("container", decoded.performative.open.container_id);
        }
    };
    try testing.checkAllAllocationFailures(testing.allocator, Case.run, .{});
}
