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

/// Aliased to uamqp's error set rather than restated, so a new encoder
/// failure mode cannot silently fail to compile here again.
pub const EncodeError = encoder.EncodeError;

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

// ─────────────────────── Link layer ───────────────────────

/// Descriptor code for the standard selector filter.
///
/// `<descriptor name="apache.org:selector-filter:string" code="0x0000468C:0x00000004"/>`.
/// Event Hubs uses it to carry the starting offset expression.
pub const selector_filter_name = "apache.org:selector-filter:string";
pub const selector_filter_code: u64 = 0x0000468C00000004;

pub const Role = enum(u1) {
    sender = 0,
    receiver = 1,

    pub fn isReceiver(self: Role) bool {
        return self == .receiver;
    }
};

/// sender-settle-mode (§3.8.7).
pub const SenderSettleMode = enum(u8) {
    unsettled = 0,
    settled = 1,
    mixed = 2,
};

/// receiver-settle-mode (§3.8.8).
pub const ReceiverSettleMode = enum(u8) {
    /// Settle on the first disposition. What Event Hubs expects.
    first = 0,
    second = 1,
};

/// One entry of a filter-set: a symbol key naming a described value.
pub const Filter = struct {
    name: []const u8,
    /// Descriptor code; when null the `name` symbol is used as the descriptor.
    code: ?u64 = null,
    value: AmqpValue,

    /// The selector filter Event Hubs reads the starting position from.
    pub fn selector(expression: []const u8) Filter {
        return .{
            .name = selector_filter_name,
            .code = selector_filter_code,
            .value = .{ .string = expression },
        };
    }
};

/// Source (§3.5.3). Only the fields Event Hubs uses are modelled.
pub const Source = struct {
    address: ?[]const u8 = null,
    durable: u32 = 0,
    expiry_policy: ?[]const u8 = null,
    timeout: ?u32 = null,
    dynamic: bool = false,
    distribution_mode: ?[]const u8 = null,
    filters: ?[]const Filter = null,
    capabilities: ?[]const []const u8 = null,
};

/// Target (§3.5.4).
pub const Target = struct {
    address: ?[]const u8 = null,
    durable: u32 = 0,
    expiry_policy: ?[]const u8 = null,
    timeout: ?u32 = null,
    dynamic: bool = false,
    capabilities: ?[]const []const u8 = null,
};

/// A terminal delivery state (§3.4).
pub const DeliveryState = union(enum) {
    accepted,
    released,
    rejected: ?AmqpError,
    modified: Modified,

    pub const Modified = struct {
        delivery_failed: bool = false,
        undeliverable_here: bool = false,
        message_annotations: ?Fields = null,
    };

    pub fn descriptorCode(self: DeliveryState) u64 {
        return switch (self) {
            .accepted => descriptor.accepted,
            .released => descriptor.released,
            .rejected => descriptor.rejected,
            .modified => descriptor.modified,
        };
    }
};

/// Attach (§2.7.3).
pub const Attach = struct {
    name: []const u8,
    handle: u32,
    role: Role,
    snd_settle_mode: SenderSettleMode = .mixed,
    rcv_settle_mode: ReceiverSettleMode = .first,
    source: ?Source = null,
    target: ?Target = null,
    incomplete_unsettled: bool = false,
    initial_delivery_count: ?u32 = null,
    max_message_size: ?u64 = null,
    offered_capabilities: ?[]const []const u8 = null,
    desired_capabilities: ?[]const []const u8 = null,
    properties: ?Fields = null,
};

/// Flow (§2.7.4).
pub const Flow = struct {
    next_incoming_id: ?u32 = null,
    incoming_window: u32,
    next_outgoing_id: u32,
    outgoing_window: u32,
    handle: ?u32 = null,
    delivery_count: ?u32 = null,
    link_credit: ?u32 = null,
    available: ?u32 = null,
    drain: bool = false,
    echo: bool = false,
    properties: ?Fields = null,
};

/// Transfer (§2.7.5). The message payload follows the performative in the
/// same frame and is not part of the described list.
pub const Transfer = struct {
    handle: u32,
    delivery_id: ?u32 = null,
    delivery_tag: ?[]const u8 = null,
    message_format: ?u32 = null,
    settled: ?bool = null,
    more: bool = false,
    rcv_settle_mode: ?ReceiverSettleMode = null,
    state: ?DeliveryState = null,
    resume_: bool = false,
    aborted: bool = false,
    batchable: bool = false,
};

/// Disposition (§2.7.6).
pub const Disposition = struct {
    role: Role,
    first: u32,
    last: ?u32 = null,
    settled: bool = false,
    state: ?DeliveryState = null,
    batchable: bool = false,
};

/// Detach (§2.7.7).
pub const Detach = struct {
    handle: u32,
    closed: bool = false,
    err: ?AmqpError = null,
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
    attach: Attach,
    flow: Flow,
    transfer: Transfer,
    disposition: Disposition,
    detach: Detach,
    sasl_mechanisms: SaslMechanisms,
    sasl_init: SaslInit,
    sasl_outcome: SaslOutcome,

    pub fn descriptorCode(self: Performative) u64 {
        return switch (self) {
            .open => descriptor.open,
            .begin => descriptor.begin,
            .end => descriptor.end,
            .close => descriptor.close,
            .attach => descriptor.attach,
            .flow => descriptor.flow,
            .transfer => descriptor.transfer,
            .disposition => descriptor.disposition,
            .detach => descriptor.detach,
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
    source: Source,
    target: Target,
    delivery_state: DeliveryState,
    /// A filter-set: a symbol-keyed map whose values are described.
    filters: []const Filter,
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

fn optionalBool(v: ?bool) Field {
    return if (v) |b| .{ .value = .{ .boolean = b } } else .null;
}

/// A boolean that is only written when it differs from the spec default.
fn defaultedBool(v: bool, default: bool) Field {
    return if (v == default) .null else .{ .value = .{ .boolean = v } };
}

fn optionalUlong(v: ?u64) Field {
    return if (v) |n| .{ .value = .{ .ulong = n } } else .null;
}

fn optionalSource(v: ?Source) Field {
    return if (v) |x| .{ .source = x } else .null;
}

fn optionalTarget(v: ?Target) Field {
    return if (v) |x| .{ .target = x } else .null;
}

fn optionalDeliveryState(v: ?DeliveryState) Field {
    return if (v) |x| .{ .delivery_state = x } else .null;
}

fn optionalFilters(v: ?[]const Filter) Field {
    const list = v orelse return .null;
    if (list.len == 0) return .null;
    return .{ .filters = list };
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
        .source => |v| try encodeSource(allocator, v, buf),
        .target => |v| try encodeTarget(allocator, v, buf),
        .delivery_state => |v| try encodeDeliveryState(allocator, v, buf),
        .filters => |v| try encodeFilterSet(allocator, v, buf),
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

pub fn encodeSource(allocator: Allocator, src: Source, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        optionalString(src.address),
        .{ .value = .{ .uint = src.durable } },
        optionalSymbol(src.expiry_policy),
        optionalUint(src.timeout),
        defaultedBool(src.dynamic, false),
        .null, // dynamic-node-properties
        optionalSymbol(src.distribution_mode),
        optionalFilters(src.filters),
        .null, // default-outcome
        .null, // outcomes
        optionalSymbols(src.capabilities),
    };
    try encodeDescribedList(allocator, descriptor.source, &fields, buf);
}

pub fn encodeTarget(allocator: Allocator, tgt: Target, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        optionalString(tgt.address),
        .{ .value = .{ .uint = tgt.durable } },
        optionalSymbol(tgt.expiry_policy),
        optionalUint(tgt.timeout),
        defaultedBool(tgt.dynamic, false),
        .null, // dynamic-node-properties
        optionalSymbols(tgt.capabilities),
    };
    try encodeDescribedList(allocator, descriptor.target, &fields, buf);
}

/// Encode a filter-set: a symbol-keyed map of described values (§3.5.8).
fn encodeFilterSet(allocator: Allocator, filters: []const Filter, buf: *encoder.Buffer) EncodeError!void {
    var body = encoder.Buffer.initDynamic(allocator);
    defer body.deinit();

    for (filters) |f| {
        try encoder.encode(.{ .symbol = f.name }, &body);
        try body.writeByte(0x00);
        if (f.code) |code| {
            try encoder.encode(.{ .ulong = code }, &body);
        } else {
            try encoder.encode(.{ .symbol = f.name }, &body);
        }
        try encoder.encode(f.value, &body);
    }

    const bytes = body.written();
    const count = filters.len * 2;
    if (bytes.len + 1 <= 0xff and count <= 0xff) {
        try buf.writeByte(0xc1); // map8
        try buf.writeByte(@intCast(bytes.len + 1));
        try buf.writeByte(@intCast(count));
    } else {
        try buf.writeByte(0xd1); // map32
        var size_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &size_bytes, @intCast(bytes.len + 4), .big);
        try buf.writeAll(&size_bytes);
        std.mem.writeInt(u32, &size_bytes, @intCast(count), .big);
        try buf.writeAll(&size_bytes);
    }
    try buf.writeAll(bytes);
}

pub fn encodeDeliveryState(
    allocator: Allocator,
    state: DeliveryState,
    buf: *encoder.Buffer,
) EncodeError!void {
    switch (state) {
        .accepted, .released => try encodeDescribedList(allocator, state.descriptorCode(), &.{}, buf),
        .rejected => |e| {
            const fields = [_]Field{optionalError(e)};
            try encodeDescribedList(allocator, descriptor.rejected, &fields, buf);
        },
        .modified => |m| {
            const fields = [_]Field{
                defaultedBool(m.delivery_failed, false),
                defaultedBool(m.undeliverable_here, false),
                optionalFields(m.message_annotations),
            };
            try encodeDescribedList(allocator, descriptor.modified, &fields, buf);
        },
    }
}

// ─────────────────────── Performative encoding ───────────────────────

/// Encode any supported performative into `buf`.
pub fn encode(allocator: Allocator, p: Performative, buf: *encoder.Buffer) EncodeError!void {
    switch (p) {
        .open => |v| try encodeOpen(allocator, v, buf),
        .begin => |v| try encodeBegin(allocator, v, buf),
        .end => |v| try encodeEnd(allocator, v, buf),
        .close => |v| try encodeClose(allocator, v, buf),
        .attach => |v| try encodeAttach(allocator, v, buf),
        .flow => |v| try encodeFlow(allocator, v, buf),
        .transfer => |v| try encodeTransfer(allocator, v, buf),
        .disposition => |v| try encodeDisposition(allocator, v, buf),
        .detach => |v| try encodeDetach(allocator, v, buf),
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

pub fn encodeAttach(allocator: Allocator, attach: Attach, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        .{ .value = .{ .string = attach.name } },
        .{ .value = .{ .uint = attach.handle } },
        .{ .value = .{ .boolean = attach.role.isReceiver() } },
        .{ .value = .{ .ubyte = @intFromEnum(attach.snd_settle_mode) } },
        .{ .value = .{ .ubyte = @intFromEnum(attach.rcv_settle_mode) } },
        optionalSource(attach.source),
        optionalTarget(attach.target),
        .null, // unsettled
        defaultedBool(attach.incomplete_unsettled, false),
        optionalUint(attach.initial_delivery_count),
        optionalUlong(attach.max_message_size),
        optionalSymbols(attach.offered_capabilities),
        optionalSymbols(attach.desired_capabilities),
        optionalFields(attach.properties),
    };
    try encodeDescribedList(allocator, descriptor.attach, &fields, buf);
}

pub fn encodeFlow(allocator: Allocator, flow: Flow, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        optionalUint(flow.next_incoming_id),
        .{ .value = .{ .uint = flow.incoming_window } },
        .{ .value = .{ .uint = flow.next_outgoing_id } },
        .{ .value = .{ .uint = flow.outgoing_window } },
        optionalUint(flow.handle),
        optionalUint(flow.delivery_count),
        optionalUint(flow.link_credit),
        optionalUint(flow.available),
        defaultedBool(flow.drain, false),
        defaultedBool(flow.echo, false),
        optionalFields(flow.properties),
    };
    try encodeDescribedList(allocator, descriptor.flow, &fields, buf);
}

/// Encode the transfer performative only; the payload is appended by the
/// caller so a message can be split across frames.
pub fn encodeTransfer(allocator: Allocator, xfer: Transfer, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        .{ .value = .{ .uint = xfer.handle } },
        optionalUint(xfer.delivery_id),
        optionalBinary(xfer.delivery_tag),
        optionalUint(xfer.message_format),
        optionalBool(xfer.settled),
        defaultedBool(xfer.more, false),
        if (xfer.rcv_settle_mode) |m| Field{ .value = .{ .ubyte = @intFromEnum(m) } } else .null,
        optionalDeliveryState(xfer.state),
        defaultedBool(xfer.resume_, false),
        defaultedBool(xfer.aborted, false),
        defaultedBool(xfer.batchable, false),
    };
    try encodeDescribedList(allocator, descriptor.transfer, &fields, buf);
}

pub fn encodeDisposition(
    allocator: Allocator,
    d: Disposition,
    buf: *encoder.Buffer,
) EncodeError!void {
    const fields = [_]Field{
        .{ .value = .{ .boolean = d.role.isReceiver() } },
        .{ .value = .{ .uint = d.first } },
        optionalUint(d.last),
        defaultedBool(d.settled, false),
        optionalDeliveryState(d.state),
        defaultedBool(d.batchable, false),
    };
    try encodeDescribedList(allocator, descriptor.disposition, &fields, buf);
}

pub fn encodeDetach(allocator: Allocator, d: Detach, buf: *encoder.Buffer) EncodeError!void {
    const fields = [_]Field{
        .{ .value = .{ .uint = d.handle } },
        defaultedBool(d.closed, false),
        optionalError(d.err),
    };
    try encodeDescribedList(allocator, descriptor.detach, &fields, buf);
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
        descriptor.attach => .{ .attach = .{
            .name = (try stringAt(list, 0)) orelse "",
            .handle = (try uintAt(list, 1)) orelse 0,
            .role = if ((try boolAt(list, 2)) orelse false) .receiver else .sender,
            .snd_settle_mode = senderModeFromInt((try ubyteAt(list, 3)) orelse 2) orelse
                return error.MalformedBody,
            .rcv_settle_mode = receiverModeFromInt((try ubyteAt(list, 4)) orelse 0) orelse
                return error.MalformedBody,
            .source = try sourceAt(allocator, list, 5),
            .target = try targetAt(allocator, list, 6),
            .incomplete_unsettled = (try boolAt(list, 8)) orelse false,
            .initial_delivery_count = try uintAt(list, 9),
            .max_message_size = try ulongAt(list, 10),
            .offered_capabilities = try symbolsAt(allocator, list, 11),
            .desired_capabilities = try symbolsAt(allocator, list, 12),
            .properties = try fieldsAt(list, 13),
        } },
        descriptor.flow => .{ .flow = .{
            .next_incoming_id = try uintAt(list, 0),
            .incoming_window = (try uintAt(list, 1)) orelse 0,
            .next_outgoing_id = (try uintAt(list, 2)) orelse 0,
            .outgoing_window = (try uintAt(list, 3)) orelse 0,
            .handle = try uintAt(list, 4),
            .delivery_count = try uintAt(list, 5),
            .link_credit = try uintAt(list, 6),
            .available = try uintAt(list, 7),
            .drain = (try boolAt(list, 8)) orelse false,
            .echo = (try boolAt(list, 9)) orelse false,
            .properties = try fieldsAt(list, 10),
        } },
        descriptor.transfer => .{ .transfer = .{
            .handle = (try uintAt(list, 0)) orelse 0,
            .delivery_id = try uintAt(list, 1),
            .delivery_tag = try binaryAt(list, 2),
            .message_format = try uintAt(list, 3),
            .settled = try boolAt(list, 4),
            .more = (try boolAt(list, 5)) orelse false,
            .rcv_settle_mode = if (try ubyteAt(list, 6)) |m|
                receiverModeFromInt(m) orelse return error.MalformedBody
            else
                null,
            .state = try deliveryStateAt(list, 7),
            .resume_ = (try boolAt(list, 8)) orelse false,
            .aborted = (try boolAt(list, 9)) orelse false,
            .batchable = (try boolAt(list, 10)) orelse false,
        } },
        descriptor.disposition => .{ .disposition = .{
            .role = if ((try boolAt(list, 0)) orelse false) .receiver else .sender,
            .first = (try uintAt(list, 1)) orelse 0,
            .last = try uintAt(list, 2),
            .settled = (try boolAt(list, 3)) orelse false,
            .state = try deliveryStateAt(list, 4),
            .batchable = (try boolAt(list, 5)) orelse false,
        } },
        descriptor.detach => .{ .detach = .{
            .handle = (try uintAt(list, 0)) orelse 0,
            .closed = (try boolAt(list, 1)) orelse false,
            .err = try errorAt(list, 2),
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

fn senderModeFromInt(value: u8) ?SenderSettleMode {
    return switch (value) {
        0 => .unsettled,
        1 => .settled,
        2 => .mixed,
        else => null,
    };
}

fn receiverModeFromInt(value: u8) ?ReceiverSettleMode {
    return switch (value) {
        0 => .first,
        1 => .second,
        else => null,
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

fn boolAt(list: []const AmqpValue, index: usize) DecodeError!?bool {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .boolean => |b| b,
        else => error.MalformedBody,
    };
}

fn ulongAt(list: []const AmqpValue, index: usize) DecodeError!?u64 {
    const v = at(list, index) orelse return null;
    return switch (v) {
        .ulong => |n| n,
        .uint => |n| n,
        .ushort => |n| n,
        .ubyte => |n| n,
        else => error.MalformedBody,
    };
}

/// Unwrap a described value at `index`, checking its descriptor code.
fn describedAt(
    list: []const AmqpValue,
    index: usize,
    code: u64,
) DecodeError!?[]const AmqpValue {
    const v = at(list, index) orelse return null;
    if (v != .described) return error.MalformedBody;
    const actual = switch (v.described.descriptor.*) {
        .ulong => |c| c,
        else => return error.MalformedBody,
    };
    if (actual != code) return error.MalformedBody;
    return switch (v.described.value.*) {
        .list => |items| items,
        .null => &.{},
        else => error.MalformedBody,
    };
}

fn sourceAt(allocator: Allocator, list: []const AmqpValue, index: usize) DecodeError!?Source {
    const inner = try describedAt(list, index, descriptor.source) orelse return null;
    return .{
        .address = try stringAt(inner, 0),
        .durable = (try uintAt(inner, 1)) orelse 0,
        .expiry_policy = try symbolAt(inner, 2),
        .timeout = try uintAt(inner, 3),
        .dynamic = (try boolAt(inner, 4)) orelse false,
        .distribution_mode = try symbolAt(inner, 6),
        .filters = try filtersAt(allocator, inner, 7),
        .capabilities = try symbolsAt(allocator, inner, 10),
    };
}

fn targetAt(allocator: Allocator, list: []const AmqpValue, index: usize) DecodeError!?Target {
    const inner = try describedAt(list, index, descriptor.target) orelse return null;
    return .{
        .address = try stringAt(inner, 0),
        .durable = (try uintAt(inner, 1)) orelse 0,
        .expiry_policy = try symbolAt(inner, 2),
        .timeout = try uintAt(inner, 3),
        .dynamic = (try boolAt(inner, 4)) orelse false,
        .capabilities = try symbolsAt(allocator, inner, 6),
    };
}

fn filtersAt(
    allocator: Allocator,
    list: []const AmqpValue,
    index: usize,
) DecodeError!?[]const Filter {
    const v = at(list, index) orelse return null;
    const entries = switch (v) {
        .map => |m| m,
        else => return error.MalformedBody,
    };
    const out = try allocator.alloc(Filter, entries.len);
    for (entries, 0..) |entry, i| {
        const name = switch (entry.key) {
            .symbol, .string => |sym| sym,
            else => return error.MalformedBody,
        };
        switch (entry.value) {
            .described => |d| out[i] = .{
                .name = name,
                .code = switch (d.descriptor.*) {
                    .ulong => |c| c,
                    else => null,
                },
                .value = d.value.*,
            },
            else => out[i] = .{ .name = name, .code = null, .value = entry.value },
        }
    }
    return out;
}

fn deliveryStateAt(list: []const AmqpValue, index: usize) DecodeError!?DeliveryState {
    const v = at(list, index) orelse return null;
    if (v != .described) return error.MalformedBody;
    const code = switch (v.described.descriptor.*) {
        .ulong => |c| c,
        else => return error.MalformedBody,
    };
    const inner: []const AmqpValue = switch (v.described.value.*) {
        .list => |items| items,
        .null => &.{},
        else => return error.MalformedBody,
    };
    return switch (code) {
        descriptor.accepted => .accepted,
        descriptor.released => .released,
        descriptor.rejected => .{ .rejected = try errorAt(inner, 0) },
        descriptor.modified => .{ .modified = .{
            .delivery_failed = (try boolAt(inner, 0)) orelse false,
            .undeliverable_here = (try boolAt(inner, 1)) orelse false,
            .message_annotations = try fieldsAt(inner, 2),
        } },
        // `received` and any non-terminal state are not modelled.
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
    // 0x42 is `sasl-challenge`, which this driver does not model.
    try testing.expectError(error.UnknownDescriptor, decode(allocator, &.{ 0x00, 0x53, 0x42, 0x45 }));
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

test "attach round-trips with source, target, and properties" {
    const allocator = testing.allocator;
    const props = [_]MapEntry{
        .{ .key = .{ .symbol = "com.microsoft:receiver-name" }, .value = .{ .string = "inst-1" } },
        .{ .key = .{ .symbol = "com.microsoft:epoch" }, .value = .{ .long = 3 } },
    };
    const filters = [_]Filter{Filter.selector("amqp.annotation.x-opt-offset > '42'")};

    const attach = Attach{
        .name = "eh/ConsumerGroups/$default/Partitions/0",
        .handle = 7,
        .role = .receiver,
        .snd_settle_mode = .mixed,
        .rcv_settle_mode = .first,
        .source = .{
            .address = "eh/ConsumerGroups/$default/Partitions/0",
            .filters = &filters,
        },
        .target = .{ .address = "inst-1" },
        .max_message_size = 1048576,
        .desired_capabilities = &.{"com.microsoft:georeplication"},
        .properties = &props,
    };

    const bytes = try encodeAlloc(allocator, .{ .attach = attach });
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();

    const got = decoded.performative.attach;
    try testing.expectEqualStrings(attach.name, got.name);
    try testing.expectEqual(@as(u32, 7), got.handle);
    try testing.expectEqual(Role.receiver, got.role);
    try testing.expectEqual(SenderSettleMode.mixed, got.snd_settle_mode);
    try testing.expectEqual(ReceiverSettleMode.first, got.rcv_settle_mode);
    try testing.expectEqualStrings(attach.source.?.address.?, got.source.?.address.?);
    try testing.expectEqualStrings("inst-1", got.target.?.address.?);
    try testing.expectEqual(@as(u64, 1048576), got.max_message_size.?);
    try testing.expectEqualStrings("com.microsoft:georeplication", got.desired_capabilities.?[0]);
    try testing.expectEqual(@as(usize, 2), got.properties.?.len);
    try testing.expectEqualStrings("inst-1", got.properties.?[0].value.string);
    try testing.expectEqual(@as(i64, 3), got.properties.?[1].value.long);

    const got_filter = got.source.?.filters.?[0];
    try testing.expectEqualStrings(selector_filter_name, got_filter.name);
    try testing.expectEqual(selector_filter_code, got_filter.code.?);
    try testing.expectEqualStrings("amqp.annotation.x-opt-offset > '42'", got_filter.value.string);
}

test "a selector filter encodes as a described value in a symbol-keyed map" {
    const allocator = testing.allocator;
    var buf = encoder.Buffer.initDynamic(allocator);
    defer buf.deinit();
    const filters = [_]Filter{Filter.selector("x")};
    try encodeFilterSet(allocator, &filters, &buf);

    // map8, size, count=2, sym8 "apache.org:selector-filter:string",
    // then 0x00 descriptor ulong 0x0000468C00000004, then str8 "x".
    const name = selector_filter_name;
    var expected = std.ArrayList(u8).empty;
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, &.{ 0xc1, 0, 2, 0xa3, @intCast(name.len) });
    try expected.appendSlice(allocator, name);
    try expected.appendSlice(allocator, &.{ 0x00, 0x80, 0x00, 0x00, 0x46, 0x8c, 0x00, 0x00, 0x00, 0x04 });
    try expected.appendSlice(allocator, &.{ 0xa1, 1, 'x' });
    // map8 size counts the body plus the count byte, not the size byte itself.
    expected.items[1] = @intCast(expected.items.len - 2);

    try testing.expectEqualSlices(u8, expected.items, buf.written());
}

test "flow and disposition round-trip" {
    const allocator = testing.allocator;
    const flow = Flow{
        .next_incoming_id = 3,
        .incoming_window = 2048,
        .next_outgoing_id = 9,
        .outgoing_window = 100,
        .handle = 1,
        .delivery_count = 42,
        .link_credit = 300,
        .drain = true,
    };
    const flow_bytes = try encodeAlloc(allocator, .{ .flow = flow });
    defer allocator.free(flow_bytes);
    var flow_decoded = try decode(allocator, flow_bytes);
    defer flow_decoded.deinit();
    try testing.expectEqual(flow, flow_decoded.performative.flow);

    const d = Disposition{
        .role = .receiver,
        .first = 5,
        .last = 9,
        .settled = true,
        .state = .accepted,
    };
    const d_bytes = try encodeAlloc(allocator, .{ .disposition = d });
    defer allocator.free(d_bytes);
    var d_decoded = try decode(allocator, d_bytes);
    defer d_decoded.deinit();
    const got = d_decoded.performative.disposition;
    try testing.expectEqual(Role.receiver, got.role);
    try testing.expectEqual(@as(u32, 5), got.first);
    try testing.expectEqual(@as(u32, 9), got.last.?);
    try testing.expect(got.settled);
    try testing.expectEqual(DeliveryState.accepted, got.state.?);
}

test "a rejected disposition carries the condition" {
    const allocator = testing.allocator;
    const d = Disposition{
        .role = .receiver,
        .first = 1,
        .state = .{ .rejected = .{
            .condition = "amqp:link:message-size-exceeded",
            .description = "too big",
        } },
    };
    const bytes = try encodeAlloc(allocator, .{ .disposition = d });
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();

    const err = decoded.performative.disposition.state.?.rejected.?;
    try testing.expectEqualStrings("amqp:link:message-size-exceeded", err.condition);
    try testing.expectEqualStrings("too big", err.description.?);
}

test "transfer round-trips and elides defaulted booleans" {
    const allocator = testing.allocator;
    const xfer = Transfer{
        .handle = 2,
        .delivery_id = 11,
        .delivery_tag = "\x00\x00\x00\x0b",
        .message_format = 0,
        .settled = false,
        .more = true,
    };
    const bytes = try encodeAlloc(allocator, .{ .transfer = xfer });
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();

    const got = decoded.performative.transfer;
    try testing.expectEqual(@as(u32, 2), got.handle);
    try testing.expectEqual(@as(u32, 11), got.delivery_id.?);
    try testing.expectEqualSlices(u8, "\x00\x00\x00\x0b", got.delivery_tag.?);
    try testing.expectEqual(@as(u32, 0), got.message_format.?);
    try testing.expectEqual(false, got.settled.?);
    try testing.expect(got.more);
    try testing.expect(!got.aborted);
    try testing.expect(!got.batchable);

    try testing.expectEqual(descriptor.transfer, peekDescriptor(bytes).?);
}

test "detach round-trips with a closed flag and an error" {
    const allocator = testing.allocator;
    const d = Detach{
        .handle = 4,
        .closed = true,
        .err = .{ .condition = "amqp:link:stolen", .description = "higher epoch" },
    };
    const bytes = try encodeAlloc(allocator, .{ .detach = d });
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();

    const got = decoded.performative.detach;
    try testing.expectEqual(@as(u32, 4), got.handle);
    try testing.expect(got.closed);
    try testing.expectEqualStrings("amqp:link:stolen", got.err.?.condition);
}

test "a modified delivery state round-trips" {
    const allocator = testing.allocator;
    const d = Disposition{
        .role = .receiver,
        .first = 0,
        .state = .{ .modified = .{ .delivery_failed = true, .undeliverable_here = true } },
    };
    const bytes = try encodeAlloc(allocator, .{ .disposition = d });
    defer allocator.free(bytes);
    var decoded = try decode(allocator, bytes);
    defer decoded.deinit();

    const m = decoded.performative.disposition.state.?.modified;
    try testing.expect(m.delivery_failed);
    try testing.expect(m.undeliverable_here);
}
