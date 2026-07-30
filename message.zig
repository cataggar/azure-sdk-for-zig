//! Service Bus ↔ AMQP 1.0 message translation.
//!
//! Service Bus carries its broker metadata in ordinary AMQP places: the bare
//! message's `properties` section, the `header`'s delivery count, and a set of
//! `x-opt-*` message annotations. This module is only that mapping —
//! `azure_sdk_amqp` owns the wire codec.
//!
//! The decode side **borrows**: every slice on a `ServiceBusReceivedMessage`
//! points into the arena its `amqp.Message` was decoded into, and dies when
//! that arena does — at `Decoded.deinit`, or at the reset if the receive path
//! uses `decodeMessageInto`. It does *not* borrow from the delivery payload:
//! `azure_sdk_amqp`'s decoder dupes strings and binaries into the arena, so
//! holding the payload bytes alive does not keep a received message valid.
//! Nothing here allocates on decode, so a caller that needs a message to
//! outlive its arena must copy it.

const std = @import("std");
const amqp = @import("azure_sdk_amqp");
const sb = @import("root.zig");

const Allocator = std.mem.Allocator;
const AmqpValue = amqp.AmqpValue;
const MapEntry = amqp.MapEntry;
/// A symbol-keyed AMQP map, as annotations and application properties arrive.
pub const Fields = amqp.message_codec.Fields;

const ServiceBusMessage = sb.ServiceBusMessage;
const ServiceBusReceivedMessage = sb.ServiceBusReceivedMessage;

pub const EncodeError = amqp.message_codec.EncodeError || error{TimeToLiveOutOfRange};

/// Message-annotation keys Service Bus reads and writes.
///
/// Annotation keys go on the wire as symbols, but a broker or emulator may
/// send them as strings, so `annotationOf` matches on the text either way.
pub const annotation = struct {
    pub const partition_key = "x-opt-partition-key";
    pub const scheduled_enqueue_time = "x-opt-scheduled-enqueue-time";
    pub const sequence_number = "x-opt-sequence-number";
    pub const enqueued_time = "x-opt-enqueued-time";
    pub const locked_until = "x-opt-locked-until";
    pub const dead_letter_source = "x-opt-deadletter-source";
};

/// Application-property keys the broker sets on a dead-lettered message.
pub const application_property = struct {
    pub const dead_letter_reason = "DeadLetterReason";
    pub const dead_letter_description = "DeadLetterErrorDescription";
};

/// The most annotations `toAmqpMessage` can produce, so the array backing them
/// can live on the caller's stack rather than the heap.
///
/// Sized exactly, not generously: slack here would let an off-by-one in the
/// write loop go unnoticed. Raise it in the same change that adds an
/// annotation.
pub const max_outgoing_annotations = 2;

/// Scratch a caller lends to `toAmqpMessage` for the sections it must build.
///
/// The returned message borrows from this, so it has to outlive the message.
/// Keeping it out here is what lets a message with no application properties
/// encode without allocating at all — the case that dominates, and the one a
/// per-message `StringHashMap` would have taxed.
pub const Scratch = struct {
    annotations: [max_outgoing_annotations]MapEntry = undefined,
    /// The one-element slice the body's data section is built from.
    ///
    /// `toAmqpMessage` takes its message by value, so a `data` section
    /// pointing at that copy's `body` field would dangle the moment it
    /// returned. The section lives here instead, alongside the caller.
    body: [1][]const u8 = undefined,
    properties: []MapEntry = &.{},
    allocator: ?Allocator = null,

    pub fn deinit(self: *Scratch) void {
        if (self.allocator) |allocator| allocator.free(self.properties);
        self.properties = &.{};
        self.allocator = null;
    }
};

/// Build the AMQP message for `msg`, borrowing its strings and `scratch`.
///
/// Releases anything `scratch` held from a previous call, so one `Scratch`
/// can be hoisted out of a send loop — which is the point of it existing.
pub fn toAmqpMessage(
    allocator: Allocator,
    msg: ServiceBusMessage,
    scratch: *Scratch,
) EncodeError!amqp.Message {
    scratch.deinit();

    var count: usize = 0;
    if (msg.partition_key) |key| {
        scratch.annotations[count] = .{
            .key = .{ .symbol = annotation.partition_key },
            .value = .{ .string = key },
        };
        count += 1;
    }
    if (msg.scheduled_enqueue_time) |at| {
        scratch.annotations[count] = .{
            .key = .{ .symbol = annotation.scheduled_enqueue_time },
            .value = .{ .timestamp = at },
        };
        count += 1;
    }

    const property_count = msg.application_properties.count();
    if (property_count > 0) {
        const entries = try allocator.alloc(MapEntry, property_count);
        scratch.properties = entries;
        scratch.allocator = allocator;
        var it = msg.application_properties.iterator();
        var i: usize = 0;
        while (it.next()) |entry| : (i += 1) {
            entries[i] = .{
                .key = .{ .string = entry.key_ptr.* },
                .value = .{ .string = entry.value_ptr.* },
            };
        }
    }

    // §3.2.1 states `ttl` in milliseconds as a `uint`, so a negative or
    // oversized lifetime has no representation and is rejected rather than
    // wrapped into a lifetime the caller did not ask for.
    const ttl: ?u32 = if (msg.time_to_live_ms) |ms| blk: {
        if (ms < 0) return error.TimeToLiveOutOfRange;
        break :blk std.math.cast(u32, ms) orelse return error.TimeToLiveOutOfRange;
    } else null;

    scratch.body[0] = msg.body;

    return .{
        .header = .{ .ttl = ttl },
        .message_annotations = if (count > 0) scratch.annotations[0..count] else null,
        .properties = .{
            .message_id = if (msg.message_id) |id| .{ .string = id } else null,
            .to = msg.to,
            .subject = msg.subject,
            .reply_to = msg.reply_to,
            .correlation_id = if (msg.correlation_id) |id| .{ .string = id } else null,
            .content_type = msg.content_type,
            .group_id = msg.session_id,
        },
        .application_properties = if (property_count > 0) scratch.properties else null,
        .body = .{ .data = &scratch.body },
    };
}

/// Encode `msg` as the bare AMQP message bytes of one transfer.
///
/// One allocation for the encoded bytes, plus one more only when the message
/// carries application properties.
pub fn encode(allocator: Allocator, msg: ServiceBusMessage) EncodeError![]u8 {
    var scratch: Scratch = .{};
    defer scratch.deinit();
    const amqp_msg = try toAmqpMessage(allocator, msg, &scratch);
    return amqp.encodeMessageAlloc(allocator, amqp_msg);
}

/// The text of a string or symbol value, or null for anything else.
///
/// Service Bus sends string ids, but §3.2.4 also allows a uuid, ulong or
/// binary `message-id`. Rendering those would mean allocating, which this
/// module does not do, so they read as absent rather than as a wrong answer.
pub fn textOf(value: AmqpValue) ?[]const u8 {
    return switch (value) {
        .string, .symbol => |s| s,
        else => null,
    };
}

/// Look up an annotation by name, accepting a symbol or string key.
pub fn annotationOf(fields: ?Fields, name: []const u8) ?AmqpValue {
    return lookup(fields, name);
}

/// Look up an application property by name.
pub fn applicationPropertyOf(fields: ?Fields, name: []const u8) ?AmqpValue {
    return lookup(fields, name);
}

fn lookup(fields: ?Fields, name: []const u8) ?AmqpValue {
    const entries = fields orelse return null;
    for (entries) |entry| {
        const key = textOf(entry.key) orelse continue;
        if (std.mem.eql(u8, key, name)) return entry.value;
    }
    return null;
}

fn timestampOf(value: ?AmqpValue) ?i64 {
    const v = value orelse return null;
    return switch (v) {
        .timestamp, .long => |t| t,
        else => null,
    };
}

fn textAnnotation(fields: ?Fields, name: []const u8) ?[]const u8 {
    const v = lookup(fields, name) orelse return null;
    return textOf(v);
}

/// Read a received message out of a decoded AMQP message.
///
/// Every slice borrows from `msg`, so the result is valid exactly as long as
/// `msg` is — which for a receive path means until the next `receive`.
pub fn fromAmqpMessage(msg: amqp.Message) ServiceBusReceivedMessage {
    const annotations = msg.message_annotations;
    const properties = msg.application_properties;

    return .{
        .body = switch (msg.body) {
            .data => |sections| if (sections.len > 0) sections[0] else "",
            else => "",
        },
        .content_type = msg.properties.content_type,
        .message_id = if (msg.properties.message_id) |id| textOf(id) else null,
        .session_id = msg.properties.group_id,
        .correlation_id = if (msg.properties.correlation_id) |id| textOf(id) else null,
        .subject = msg.properties.subject,
        .to = msg.properties.to,
        .reply_to = msg.properties.reply_to,
        .sequence_number = switch (lookup(annotations, annotation.sequence_number) orelse AmqpValue.null) {
            .long, .timestamp => |n| n,
            .int => |n| n,
            else => null,
        },
        .enqueued_time = timestampOf(lookup(annotations, annotation.enqueued_time)),
        .locked_until = timestampOf(lookup(annotations, annotation.locked_until)),
        .partition_key = textAnnotation(annotations, annotation.partition_key),
        // §3.2.1 counts *previous unsuccessful* attempts, so it is 0 on a
        // first delivery; Service Bus's `DeliveryCount` — the number
        // `MaxDeliveryCount` is compared against — is 1. Add one so the
        // obvious comparison is right, matching the Go and .NET SDKs.
        // A peeked message keeps the raw value, since it was never delivered.
        .delivery_count = if (msg.header.delivery_count) |d| d +| 1 else null,
        .dead_letter_source = textAnnotation(annotations, annotation.dead_letter_source),
        .dead_letter_reason = textAnnotation(properties, application_property.dead_letter_reason),
        .dead_letter_description = textAnnotation(properties, application_property.dead_letter_description),
        .application_properties = properties,
    };
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;

test "building the AMQP message allocates only for application properties" {
    const allocator = testing.allocator;

    // `toAmqpMessage`, not `encode`: the encoder grows its output buffer, so
    // an allocation count taken around `encode` measures uamqp's doubling
    // series rather than anything this module decides. What this module
    // decides is that the annotations ride on the caller's stack and only the
    // application-property array reaches the heap.
    var plain = ServiceBusMessage.init(allocator, "hello");
    defer plain.deinit();
    plain.partition_key = "pk";
    plain.scheduled_enqueue_time = 1_700_000_000_000;

    var counting = CountingAllocator.init(allocator);
    var scratch: Scratch = .{};
    _ = try toAmqpMessage(counting.allocator(), plain, &scratch);
    scratch.deinit();
    try testing.expectEqual(@as(usize, 0), counting.allocs);

    var with_properties = ServiceBusMessage.init(allocator, "hello");
    defer with_properties.deinit();
    try with_properties.application_properties.put("tenant", "contoso");
    try with_properties.application_properties.put("region", "westus");

    counting = CountingAllocator.init(allocator);
    var scratch2: Scratch = .{};
    _ = try toAmqpMessage(counting.allocator(), with_properties, &scratch2);
    scratch2.deinit();
    try testing.expectEqual(@as(usize, 1), counting.allocs);
}

test "the standard properties round-trip through the wire" {
    const allocator = testing.allocator;

    var msg = ServiceBusMessage.init(allocator, "payload");
    defer msg.deinit();
    msg.message_id = "m-1";
    msg.correlation_id = "c-1";
    msg.content_type = "text/plain";
    msg.subject = "greetings";
    msg.to = "somewhere";
    msg.reply_to = "back-here";
    msg.session_id = "session-7";
    msg.time_to_live_ms = 30_000;

    const bytes = try encode(allocator, msg);
    defer allocator.free(bytes);

    var decoded = try amqp.decodeMessage(allocator, bytes);
    defer decoded.deinit();

    // Assert against the AMQP sections directly, not through
    // `fromAmqpMessage`. Reading a value back through this module's own
    // mapping proves only that encode and decode agree with each other: a
    // wrong-but-symmetric mapping (`session_id` to `reply-to-group-id`, say,
    // which silently disables session-enabled queues) passes such a test.
    const props = decoded.message.properties;
    try testing.expectEqualStrings("m-1", props.message_id.?.string);
    try testing.expectEqualStrings("c-1", props.correlation_id.?.string);
    try testing.expectEqualStrings("text/plain", props.content_type.?);
    try testing.expectEqualStrings("greetings", props.subject.?);
    try testing.expectEqualStrings("somewhere", props.to.?);
    try testing.expectEqualStrings("back-here", props.reply_to.?);
    try testing.expectEqualStrings("session-7", props.group_id.?);
    try testing.expectEqual(@as(?[]const u8, null), props.reply_to_group_id);
    try testing.expectEqual(@as(?u32, 30_000), decoded.message.header.ttl);

    const got = fromAmqpMessage(decoded.message);
    try testing.expectEqualStrings("payload", got.body);
    try testing.expectEqualStrings("m-1", got.message_id.?);
    try testing.expectEqualStrings("c-1", got.correlation_id.?);
    try testing.expectEqualStrings("text/plain", got.content_type.?);
    try testing.expectEqualStrings("greetings", got.subject.?);
    try testing.expectEqualStrings("somewhere", got.to.?);
    try testing.expectEqualStrings("back-here", got.reply_to.?);
    try testing.expectEqualStrings("session-7", got.session_id.?);
}

test "partition key and scheduled time go into message annotations" {
    const allocator = testing.allocator;

    var msg = ServiceBusMessage.init(allocator, "payload");
    defer msg.deinit();
    msg.partition_key = "pk-3";
    msg.scheduled_enqueue_time = 1_700_000_000_000;

    const bytes = try encode(allocator, msg);
    defer allocator.free(bytes);

    var decoded = try amqp.decodeMessage(allocator, bytes);
    defer decoded.deinit();

    const annotations = decoded.message.message_annotations;
    // Literal keys, not the module's constants: these strings are the
    // contract with the broker, and a test that reads them back through the
    // same constant it wrote cannot tell a right key from a wrong one.
    try testing.expectEqualStrings(
        "pk-3",
        textOf(annotationOf(annotations, "x-opt-partition-key").?).?,
    );
    try testing.expectEqual(
        @as(i64, 1_700_000_000_000),
        annotationOf(annotations, "x-opt-scheduled-enqueue-time").?.timestamp,
    );
}

test "the annotation and property keys are the ones the broker uses" {
    // Pinned against the Go SDK's azservicebus/message.go. A typo in any of
    // these is silent data loss that every round-trip test would still pass.
    try testing.expectEqualStrings("x-opt-partition-key", annotation.partition_key);
    try testing.expectEqualStrings("x-opt-scheduled-enqueue-time", annotation.scheduled_enqueue_time);
    try testing.expectEqualStrings("x-opt-sequence-number", annotation.sequence_number);
    try testing.expectEqualStrings("x-opt-enqueued-time", annotation.enqueued_time);
    try testing.expectEqualStrings("x-opt-locked-until", annotation.locked_until);
    try testing.expectEqualStrings("x-opt-deadletter-source", annotation.dead_letter_source);
    try testing.expectEqualStrings("DeadLetterReason", application_property.dead_letter_reason);
    try testing.expectEqualStrings("DeadLetterErrorDescription", application_property.dead_letter_description);
}

test "application properties round-trip" {
    const allocator = testing.allocator;

    var msg = ServiceBusMessage.init(allocator, "payload");
    defer msg.deinit();
    try msg.application_properties.put("tenant", "contoso");

    const bytes = try encode(allocator, msg);
    defer allocator.free(bytes);

    var decoded = try amqp.decodeMessage(allocator, bytes);
    defer decoded.deinit();

    const got = fromAmqpMessage(decoded.message);
    try testing.expectEqualStrings(
        "contoso",
        textOf(applicationPropertyOf(got.application_properties, "tenant").?).?,
    );
}

test "an out-of-range time to live is refused rather than wrapped" {
    const allocator = testing.allocator;

    var msg = ServiceBusMessage.init(allocator, "payload");
    defer msg.deinit();

    msg.time_to_live_ms = -1;
    try testing.expectError(error.TimeToLiveOutOfRange, encode(allocator, msg));

    msg.time_to_live_ms = @as(i64, std.math.maxInt(u32)) + 1;
    try testing.expectError(error.TimeToLiveOutOfRange, encode(allocator, msg));

    msg.time_to_live_ms = std.math.maxInt(u32);
    const bytes = try encode(allocator, msg);
    allocator.free(bytes);
}

test "broker metadata is read from the annotations, header and properties" {
    const allocator = testing.allocator;

    const annotations = [_]MapEntry{
        .{ .key = .{ .symbol = annotation.sequence_number }, .value = .{ .long = 42 } },
        .{ .key = .{ .symbol = annotation.enqueued_time }, .value = .{ .timestamp = 1_700_000_000_000 } },
        .{ .key = .{ .symbol = annotation.locked_until }, .value = .{ .timestamp = 1_700_000_030_000 } },
        .{ .key = .{ .symbol = annotation.dead_letter_source }, .value = .{ .string = "orders" } },
        .{ .key = .{ .symbol = annotation.partition_key }, .value = .{ .string = "pk-9" } },
    };
    const properties = [_]MapEntry{
        .{ .key = .{ .string = application_property.dead_letter_reason }, .value = .{ .string = "MaxDeliveryCountExceeded" } },
        .{ .key = .{ .string = application_property.dead_letter_description }, .value = .{ .string = "tried ten times" } },
    };

    const bytes = try amqp.encodeMessageAlloc(allocator, .{
        .header = .{ .delivery_count = 10 },
        .message_annotations = &annotations,
        .application_properties = &properties,
        .body = .{ .data = &.{"dead"} },
    });
    defer allocator.free(bytes);

    var decoded = try amqp.decodeMessage(allocator, bytes);
    defer decoded.deinit();

    const got = fromAmqpMessage(decoded.message);
    try testing.expectEqual(@as(?i64, 42), got.sequence_number);
    try testing.expectEqual(@as(?i64, 1_700_000_000_000), got.enqueued_time);
    try testing.expectEqual(@as(?i64, 1_700_000_030_000), got.locked_until);
    try testing.expectEqual(@as(?u32, 11), got.delivery_count);
    try testing.expectEqualStrings("orders", got.dead_letter_source.?);
    try testing.expectEqualStrings("pk-9", got.partition_key.?);
    try testing.expectEqualStrings("MaxDeliveryCountExceeded", got.dead_letter_reason.?);
    try testing.expectEqualStrings("tried ten times", got.dead_letter_description.?);
}

test "a string-keyed annotation reads the same as a symbol-keyed one" {
    const annotations = [_]MapEntry{
        .{ .key = .{ .string = annotation.sequence_number }, .value = .{ .long = 7 } },
    };
    const got = fromAmqpMessage(.{ .message_annotations = &annotations });
    try testing.expectEqual(@as(?i64, 7), got.sequence_number);
}

test "a non-text message id reads as absent rather than as wrong text" {
    const got = fromAmqpMessage(.{
        .properties = .{ .message_id = .{ .ulong = 9 } },
        .body = .{ .data = &.{"x"} },
    });
    try testing.expectEqual(@as(?[]const u8, null), got.message_id);
}

test "a message with no body decodes to an empty body" {
    const empty = fromAmqpMessage(.{});
    try testing.expectEqualStrings("", empty.body);

    // A `data` body with no sections is legal on the wire and is what an
    // index straight into `sections[0]` would panic on.
    const no_sections = fromAmqpMessage(.{ .body = .{ .data = &.{} } });
    try testing.expectEqualStrings("", no_sections.body);
}

test "one scratch can be reused across messages without leaking" {
    const allocator = testing.allocator;

    // `Scratch` exists so a send loop can hoist it; the batch sender will do
    // exactly that. Each call must release what the previous one allocated.
    var scratch: Scratch = .{};
    defer scratch.deinit();

    for (0..3) |_| {
        var msg = ServiceBusMessage.init(allocator, "payload");
        defer msg.deinit();
        try msg.application_properties.put("tenant", "contoso");
        _ = try toAmqpMessage(allocator, msg, &scratch);
    }

    // A message with no properties must also clear the previous array,
    // rather than leave it dangling behind a stale `properties` slice.
    var plain = ServiceBusMessage.init(allocator, "payload");
    defer plain.deinit();
    const built = try toAmqpMessage(allocator, plain, &scratch);
    try testing.expectEqual(@as(?Fields, null), built.application_properties);
    try testing.expectEqual(@as(usize, 0), scratch.properties.len);
}

test "delivery count is the Service Bus count, not the raw AMQP one" {
    // §3.2.1 counts previous *failed* attempts, so a first delivery arrives
    // as 0 on the wire. Service Bus's DeliveryCount, which MaxDeliveryCount
    // is compared against, is 1 there. Exposing the raw value would make the
    // obvious `count >= max_delivery_count` check off by one.
    const first = fromAmqpMessage(.{ .header = .{ .delivery_count = 0 } });
    try testing.expectEqual(@as(?u32, 1), first.delivery_count);

    const redelivered = fromAmqpMessage(.{ .header = .{ .delivery_count = 9 } });
    try testing.expectEqual(@as(?u32, 10), redelivered.delivery_count);

    const absent = fromAmqpMessage(.{});
    try testing.expectEqual(@as(?u32, null), absent.delivery_count);

    // Saturating, so a hostile or corrupt maxInt cannot wrap to 0 and make a
    // message look freshly delivered forever.
    const huge = fromAmqpMessage(.{ .header = .{ .delivery_count = std.math.maxInt(u32) } });
    try testing.expectEqual(@as(?u32, std.math.maxInt(u32)), huge.delivery_count);
}

/// Counts allocations so a test can assert the cost of a call rather than
/// merely that it worked.
const CountingAllocator = struct {
    child: Allocator,
    allocs: usize = 0,

    fn init(child: Allocator) CountingAllocator {
        return .{ .child = child };
    }

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
        const p = self.child.rawAlloc(len, alignment, ra);
        if (p != null) self.allocs += 1;
        return p;
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawResize(buf, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.child.rawRemap(buf, alignment, new_len, ra);
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.child.rawFree(buf, alignment, ra);
    }
};
