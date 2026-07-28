///! Event Hubs message models and AMQP conversion.
///!
///! `EventData` carries only what a producer sends. `ReceivedEventData` adds
///! the service-populated fields a consumer reads back, mirroring the split
///! the Go (`EventData`/`ReceivedEventData`) and Rust (`EventData`/
///! `ReceivedEventData`) SDKs use.
const std = @import("std");
const uamqp = @import("uamqp");

pub const AmqpValue = uamqp.AmqpValue;
pub const MapEntry = uamqp.MapEntry;
pub const Message = uamqp.message.Message;

/// Message annotations Event Hubs stamps on every received event. Values match
/// the Go SDK's `event_data.go` constants byte for byte.
pub const partition_key_annotation = "x-opt-partition-key";
pub const sequence_number_annotation = "x-opt-sequence-number";
pub const offset_annotation = "x-opt-offset";
pub const enqueued_time_annotation = "x-opt-enqueued-time";

pub const ConversionError = error{
    InvalidSequenceNumberAnnotation,
    InvalidPartitionKeyAnnotation,
    InvalidEnqueuedTimeAnnotation,
    InvalidOffsetAnnotation,
    DuplicateAnnotation,
};

/// AMQP 1.0 section 3.2.5 restricts application-property values to simple
/// types, so lists, maps, arrays, and described types are rejected up front
/// rather than by the service.
pub const PropertyError = error{UnsupportedPropertyValue};

fn isSimpleValue(value: AmqpValue) bool {
    return switch (value) {
        .list, .map, .array, .described => false,
        else => true,
    };
}

/// Application-defined identifier for a message.
///
/// AMQP permits four representations and Event Hubs round-trips whichever one
/// the producer chose, so the type is a union rather than a string.
pub const MessageId = union(enum) {
    binary: []const u8,
    string: []const u8,
    ulong: u64,
    uuid: [16]u8,

    pub fn clone(self: MessageId, allocator: std.mem.Allocator) !MessageId {
        return switch (self) {
            .binary => |b| .{ .binary = try allocator.dupe(u8, b) },
            .string => |s| .{ .string = try allocator.dupe(u8, s) },
            .ulong, .uuid => self,
        };
    }

    /// Free an identifier decoded from a message. Values built from literals
    /// do not need this.
    pub fn deinit(self: MessageId, allocator: std.mem.Allocator) void {
        switch (self) {
            .binary => |b| allocator.free(b),
            .string => |s| allocator.free(s),
            .ulong, .uuid => {},
        }
    }

    pub fn toAmqpValue(self: MessageId) AmqpValue {
        return switch (self) {
            .binary => |b| .{ .binary = b },
            .string => |s| .{ .string = s },
            .ulong => |n| .{ .ulong = n },
            .uuid => |u| .{ .uuid = u },
        };
    }

    /// Interpret an AMQP value as a message id, or return null when the value
    /// uses a type AMQP does not allow for `message-id`.
    pub fn fromAmqpValue(value: AmqpValue) ?MessageId {
        return switch (value) {
            .binary => |b| .{ .binary = b },
            .string => |s| .{ .string = s },
            .ulong => |n| .{ .ulong = n },
            .uuid => |u| .{ .uuid = u },
            else => null,
        };
    }

    pub fn eql(self: MessageId, other: MessageId) bool {
        if (std.meta.activeTag(self) != std.meta.activeTag(other)) return false;
        return switch (self) {
            .binary => |b| std.mem.eql(u8, b, other.binary),
            .string => |s| std.mem.eql(u8, s, other.string),
            .ulong => |n| n == other.ulong,
            .uuid => |u| std.mem.eql(u8, &u, &other.uuid),
        };
    }
};

/// Insertion-ordered `string -> AmqpValue` map that owns its keys and values.
///
/// Application properties are not limited to strings: Go models them as
/// `map[string]any` and Rust as `HashMap<String, AmqpSimpleValue>`, so any
/// AMQP simple type has to survive a round trip.
pub const PropertyMap = struct {
    entries: std.StringArrayHashMapUnmanaged(AmqpValue) = .empty,

    pub const empty: PropertyMap = .{};

    pub fn deinit(self: *PropertyMap, allocator: std.mem.Allocator) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(allocator);
        }
        self.entries.deinit(allocator);
    }

    /// Store a deep copy of `value` under a copy of `key`, replacing any
    /// existing entry.
    pub fn put(
        self: *PropertyMap,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: AmqpValue,
    ) !void {
        var cloned = try value.clone(allocator);
        errdefer cloned.deinit(allocator);

        const owned_key = try allocator.dupe(u8, key);
        errdefer allocator.free(owned_key);

        const gop = try self.entries.getOrPut(allocator, owned_key);
        if (gop.found_existing) {
            allocator.free(owned_key);
            gop.value_ptr.deinit(allocator);
        }
        gop.value_ptr.* = cloned;
    }

    pub fn putString(
        self: *PropertyMap,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: []const u8,
    ) !void {
        return self.put(allocator, key, .{ .string = value });
    }

    pub fn get(self: PropertyMap, key: []const u8) ?AmqpValue {
        return self.entries.get(key);
    }

    /// Convenience accessor for the common case of a string-valued property.
    pub fn getString(self: PropertyMap, key: []const u8) ?[]const u8 {
        const value = self.entries.get(key) orelse return null;
        return switch (value) {
            .string, .symbol => |s| s,
            else => null,
        };
    }

    pub fn count(self: PropertyMap) usize {
        return self.entries.count();
    }

    pub fn keys(self: PropertyMap) []const []const u8 {
        return self.entries.keys();
    }

    pub fn values(self: PropertyMap) []const AmqpValue {
        return self.entries.values();
    }
};

/// An event to publish with `ProducerClient`.
///
/// Every slice is borrowed. Only `properties` allocates, so `deinit` frees
/// just that map; `ReceivedEventData.deinit` frees the decoded fields.
pub const EventData = struct {
    body: []const u8 = &.{},
    properties: PropertyMap = .empty,
    /// RFC 2045 content type of `body`, for example `application/json`.
    content_type: ?[]const u8 = null,
    /// Client-defined value used to correlate messages across clients. AMQP
    /// restricts `correlation-id` to the same four representations as
    /// `message-id`.
    correlation_id: ?MessageId = null,
    message_id: ?MessageId = null,

    pub fn init(body: []const u8) EventData {
        return .{ .body = body };
    }

    pub fn deinit(self: *EventData, allocator: std.mem.Allocator) void {
        self.properties.deinit(allocator);
    }

    pub fn setProperty(
        self: *EventData,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: AmqpValue,
    ) !void {
        if (!isSimpleValue(value)) return PropertyError.UnsupportedPropertyValue;
        return self.properties.put(allocator, key, value);
    }

    pub fn setStringProperty(
        self: *EventData,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: []const u8,
    ) !void {
        return self.properties.putString(allocator, key, value);
    }

    pub fn getProperty(self: EventData, key: []const u8) ?AmqpValue {
        return self.properties.get(key);
    }

    /// Encode this event as an AMQP message. Free the result with
    /// `freeAmqpMessage`.
    pub fn toAmqpMessage(self: EventData, allocator: std.mem.Allocator) !Message {
        var message = Message.init(allocator);
        errdefer freeAmqpMessage(allocator, &message);

        // `Message.addBodyData` duplicates the body before growing its list and
        // leaks that duplicate if the growth fails, so reserve first and append
        // infallibly instead.
        try message.body_data_sections.ensureUnusedCapacity(allocator, 1);
        const owned_body = try allocator.dupe(u8, self.body);
        message.body_type = .data;
        message.body_data_sections.appendAssumeCapacity(.{ .bytes = owned_body });

        // Go always attaches a properties section, even when every field is
        // unset, so the wire shape stays identical across SDKs. It is attached
        // before anything fallible so `freeAmqpMessage` can reach whatever was
        // allocated if a later step fails.
        message.properties = .{};
        if (self.message_id) |message_id| {
            const owned = try message_id.clone(allocator);
            message.properties.?.message_id = owned.toAmqpValue();
        }
        if (self.correlation_id) |correlation_id| {
            const owned = try correlation_id.clone(allocator);
            message.properties.?.correlation_id = owned.toAmqpValue();
        }
        if (self.content_type) |content_type| {
            message.properties.?.content_type = try allocator.dupe(u8, content_type);
        }

        if (self.properties.count() > 0) {
            const entries = try allocator.alloc(MapEntry, self.properties.count());
            var filled: usize = 0;
            errdefer {
                for (entries[0..filled]) |*entry| {
                    entry.key.deinit(allocator);
                    entry.value.deinit(allocator);
                }
                allocator.free(entries);
            }
            for (self.properties.keys(), self.properties.values()) |key, value| {
                const owned_key = try allocator.dupe(u8, key);
                errdefer allocator.free(owned_key);
                entries[filled] = .{
                    .key = .{ .string = owned_key },
                    .value = try value.clone(allocator),
                };
                filled += 1;
            }
            message.application_properties = entries;
        }

        return message;
    }
};

/// An event returned by `ConsumerClient`, including the fields Event Hubs
/// populates on the service side.
///
/// Everything is allocator-owned; free with `deinit` or `freeReceivedEvents`.
pub const ReceivedEventData = struct {
    event_data: EventData = .{},
    /// UTC time the service accepted the event, in Unix milliseconds.
    enqueued_time: ?i64 = null,
    /// Partition key chosen by the producer, if any.
    partition_key: ?[]const u8 = null,
    /// Opaque offset token. Event Hubs offsets are not numbers under
    /// geo-disaster-recovery, so they stay strings.
    offset: ?[]const u8 = null,
    sequence_number: i64 = 0,
    /// Message annotations that are not surfaced as dedicated fields.
    system_properties: PropertyMap = .empty,
    /// The message this event was decoded from, reachable for sections this
    /// type does not model (multiple data sections, sequence or value bodies,
    /// header, and footer). Owned: `deinit` frees it. Only
    /// `fromOwnedAmqpMessage` populates it.
    raw_amqp_message: ?*Message = null,

    pub fn body(self: ReceivedEventData) []const u8 {
        return self.event_data.body;
    }

    pub fn contentType(self: ReceivedEventData) ?[]const u8 {
        return self.event_data.content_type;
    }

    pub fn messageId(self: ReceivedEventData) ?MessageId {
        return self.event_data.message_id;
    }

    pub fn correlationId(self: ReceivedEventData) ?MessageId {
        return self.event_data.correlation_id;
    }

    pub fn properties(self: ReceivedEventData) PropertyMap {
        return self.event_data.properties;
    }

    pub fn deinit(self: *ReceivedEventData, allocator: std.mem.Allocator) void {
        allocator.free(self.event_data.body);
        if (self.event_data.content_type) |content_type| allocator.free(content_type);
        if (self.event_data.correlation_id) |correlation_id| correlation_id.deinit(allocator);
        if (self.event_data.message_id) |message_id| message_id.deinit(allocator);
        self.event_data.properties.deinit(allocator);
        self.system_properties.deinit(allocator);
        if (self.partition_key) |partition_key| allocator.free(partition_key);
        if (self.offset) |offset| allocator.free(offset);
        if (self.raw_amqp_message) |message| {
            freeDecodedMessage(allocator, message);
            allocator.destroy(message);
        }
    }
};

pub fn freeReceivedEvents(allocator: std.mem.Allocator, events: []ReceivedEventData) void {
    for (events) |*event| event.deinit(allocator);
    allocator.free(events);
}

/// Free a message produced by `EventData.toAmqpMessage`.
///
/// Only the sections that encoder sets are released, because `Message.deinit`
/// covers the body alone.
pub fn freeAmqpMessage(allocator: std.mem.Allocator, message: *Message) void {
    if (message.application_properties) |entries| {
        freeMapEntries(allocator, entries);
        message.application_properties = null;
    }
    if (message.properties) |*properties| {
        if (properties.message_id) |*message_id| message_id.deinit(allocator);
        if (properties.correlation_id) |*correlation_id| correlation_id.deinit(allocator);
        if (properties.content_type) |content_type| allocator.free(content_type);
        message.properties = null;
    }
    message.deinit();
}

/// Free a message and every section inside it, including the ones
/// `freeAmqpMessage` leaves alone.
///
/// Every field must have been allocated with `allocator`, which holds for
/// messages produced by an AMQP decoder.
pub fn freeDecodedMessage(allocator: std.mem.Allocator, message: *Message) void {
    if (message.application_properties) |entries| freeMapEntries(allocator, entries);
    if (message.message_annotations) |entries| freeMapEntries(allocator, entries);
    if (message.delivery_annotations) |entries| freeMapEntries(allocator, entries);
    if (message.footer) |entries| freeMapEntries(allocator, entries);
    message.application_properties = null;
    message.message_annotations = null;
    message.delivery_annotations = null;
    message.footer = null;
    if (message.properties) |*properties| {
        if (properties.message_id) |*message_id| message_id.deinit(allocator);
        if (properties.correlation_id) |*correlation_id| correlation_id.deinit(allocator);
        if (properties.user_id) |value| allocator.free(value);
        if (properties.to) |value| allocator.free(value);
        if (properties.subject) |value| allocator.free(value);
        if (properties.reply_to) |value| allocator.free(value);
        if (properties.content_type) |value| allocator.free(value);
        if (properties.content_encoding) |value| allocator.free(value);
        if (properties.group_id) |value| allocator.free(value);
        if (properties.reply_to_group_id) |value| allocator.free(value);
        message.properties = null;
    }
    message.deinit();
}

fn freeMapEntries(allocator: std.mem.Allocator, entries: []MapEntry) void {
    for (entries) |*entry| {
        entry.key.deinit(allocator);
        entry.value.deinit(allocator);
    }
    allocator.free(entries);
}

/// Decode an AMQP message into a received event.
///
/// `message` is borrowed and every field is copied out, so the result stays
/// valid after the message is freed. `raw_amqp_message` is left null; use
/// `fromOwnedAmqpMessage` when the raw message should be reachable.
pub fn fromAmqpMessage(
    allocator: std.mem.Allocator,
    message: *const Message,
) !ReceivedEventData {
    var received: ReceivedEventData = .{};
    errdefer received.deinit(allocator);

    // Go only treats a message as having a body when there is exactly one data
    // section; anything else is reachable through `raw_amqp_message`.
    received.event_data.body = if (message.body_data_sections.items.len == 1)
        try allocator.dupe(u8, message.body_data_sections.items[0].bytes)
    else
        try allocator.dupe(u8, "");

    if (message.properties) |properties| {
        if (properties.content_type) |content_type| {
            received.event_data.content_type = try allocator.dupe(u8, content_type);
        }
        if (properties.correlation_id) |correlation_id| {
            if (MessageId.fromAmqpValue(correlation_id)) |parsed| {
                received.event_data.correlation_id = try parsed.clone(allocator);
            }
        }
        if (properties.message_id) |message_id| {
            if (MessageId.fromAmqpValue(message_id)) |parsed| {
                received.event_data.message_id = try parsed.clone(allocator);
            }
        }
    }

    if (message.application_properties) |entries| {
        for (entries) |entry| {
            const key = keyOf(entry.key) orelse continue;
            try received.event_data.properties.put(allocator, key, entry.value);
        }
    }

    if (message.message_annotations) |entries| {
        try applyAnnotations(allocator, entries, &received);
    }

    return received;
}

/// Decode an AMQP message and take ownership of it.
///
/// `message` must be heap-allocated with `allocator` and every field inside it
/// must be allocator-owned. The message is freed by `ReceivedEventData.deinit`
/// and is also freed if decoding fails, so ownership transfers unconditionally.
pub fn fromOwnedAmqpMessage(
    allocator: std.mem.Allocator,
    message: *Message,
) !ReceivedEventData {
    var received = fromAmqpMessage(allocator, message) catch |err| {
        freeDecodedMessage(allocator, message);
        allocator.destroy(message);
        return err;
    };
    received.raw_amqp_message = message;
    return received;
}

fn applyAnnotations(
    allocator: std.mem.Allocator,
    entries: []MapEntry,
    received: *ReceivedEventData,
) !void {
    for (entries) |entry| {
        const key = keyOf(entry.key) orelse continue;
        if (std.mem.eql(u8, key, sequence_number_annotation)) {
            received.sequence_number = toInt64(entry.value) orelse
                return ConversionError.InvalidSequenceNumberAnnotation;
        } else if (std.mem.eql(u8, key, partition_key_annotation)) {
            if (received.partition_key != null) return ConversionError.DuplicateAnnotation;
            const value = switch (entry.value) {
                .string => |text| text,
                else => return ConversionError.InvalidPartitionKeyAnnotation,
            };
            received.partition_key = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, key, enqueued_time_annotation)) {
            received.enqueued_time = switch (entry.value) {
                .timestamp => |value| value,
                else => return ConversionError.InvalidEnqueuedTimeAnnotation,
            };
        } else if (std.mem.eql(u8, key, offset_annotation)) {
            if (received.offset != null) return ConversionError.DuplicateAnnotation;
            const value = switch (entry.value) {
                .string => |text| text,
                else => return ConversionError.InvalidOffsetAnnotation,
            };
            received.offset = try allocator.dupe(u8, value);
        } else {
            try received.system_properties.put(allocator, key, entry.value);
        }
    }
}

/// Map keys arrive as either symbols or strings depending on the sender, so
/// both are accepted for lookups. Values are matched strictly, as in Go.
fn keyOf(value: AmqpValue) ?[]const u8 {
    return switch (value) {
        .string, .symbol => |text| text,
        else => null,
    };
}

/// Go's `eh.ConvertToInt64` accepts only signed integers, and Event Hubs never
/// sends anything else for a sequence number.
fn toInt64(value: AmqpValue) ?i64 {
    return switch (value) {
        .byte => |n| n,
        .short => |n| n,
        .int => |n| n,
        .long => |n| n,
        else => null,
    };
}

// ─────────────────────── Tests ───────────────────────

test "EventData owns only its property map" {
    const allocator = std.testing.allocator;
    var event = EventData.init("hello world");
    defer event.deinit(allocator);

    try event.setStringProperty(allocator, "source", "test");
    try event.setProperty(allocator, "attempt", .{ .int = 3 });

    try std.testing.expectEqualStrings("hello world", event.body);
    try std.testing.expectEqualStrings("test", event.properties.getString("source").?);
    try std.testing.expectEqual(@as(i32, 3), event.getProperty("attempt").?.int);
}

test "PropertyMap replaces an existing key without leaking" {
    const allocator = std.testing.allocator;
    var properties: PropertyMap = .empty;
    defer properties.deinit(allocator);

    try properties.putString(allocator, "k", "first");
    try properties.putString(allocator, "k", "second");

    try std.testing.expectEqual(@as(usize, 1), properties.count());
    try std.testing.expectEqualStrings("second", properties.getString("k").?);
}

test "MessageId round-trips through an AMQP value" {
    const cases = [_]MessageId{
        .{ .string = "id-1" },
        .{ .binary = "\x00\x01\x02" },
        .{ .ulong = 42 },
        .{ .uuid = [_]u8{7} ** 16 },
    };
    for (cases) |message_id| {
        const decoded = MessageId.fromAmqpValue(message_id.toAmqpValue()).?;
        try std.testing.expect(message_id.eql(decoded));
    }
    try std.testing.expect(MessageId.fromAmqpValue(.{ .int = 1 }) == null);
}

test "EventData encodes to an AMQP message and decodes back" {
    const allocator = std.testing.allocator;

    var event = EventData.init("payload");
    defer event.deinit(allocator);
    event.content_type = "application/json";
    event.correlation_id = .{ .string = "corr-1" };
    event.message_id = .{ .string = "msg-1" };
    try event.setStringProperty(allocator, "tenant", "contoso");
    try event.setProperty(allocator, "retries", .{ .long = 7 });
    try event.setProperty(allocator, "enabled", .{ .boolean = true });

    var message = try event.toAmqpMessage(allocator);
    defer freeAmqpMessage(allocator, &message);

    var decoded = try fromAmqpMessage(allocator, &message);
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings("payload", decoded.body());
    try std.testing.expectEqualStrings("application/json", decoded.contentType().?);
    try std.testing.expectEqualStrings("corr-1", decoded.correlationId().?.string);
    try std.testing.expect(decoded.messageId().?.eql(.{ .string = "msg-1" }));
    try std.testing.expectEqualStrings("contoso", decoded.properties().getString("tenant").?);
    try std.testing.expectEqual(@as(i64, 7), decoded.properties().get("retries").?.long);
    try std.testing.expectEqual(true, decoded.properties().get("enabled").?.boolean);
    try std.testing.expectEqual(@as(usize, 3), decoded.properties().count());
    try std.testing.expect(decoded.raw_amqp_message == null);
}

test "non-string property values survive the round trip" {
    const allocator = std.testing.allocator;

    var event = EventData.init("body");
    defer event.deinit(allocator);
    try event.setProperty(allocator, "double", .{ .double = 1.5 });
    try event.setProperty(allocator, "bytes", .{ .binary = "\xde\xad" });
    try event.setProperty(allocator, "when", .{ .timestamp = 1617235200000 });
    try event.setProperty(allocator, "id", .{ .uuid = [_]u8{3} ** 16 });
    try event.setProperty(allocator, "nothing", .null);

    var message = try event.toAmqpMessage(allocator);
    defer freeAmqpMessage(allocator, &message);

    var decoded = try fromAmqpMessage(allocator, &message);
    defer decoded.deinit(allocator);

    try std.testing.expectEqual(@as(f64, 1.5), decoded.properties().get("double").?.double);
    try std.testing.expectEqualStrings("\xde\xad", decoded.properties().get("bytes").?.binary);
    try std.testing.expectEqual(@as(i64, 1617235200000), decoded.properties().get("when").?.timestamp);
    try std.testing.expectEqualSlices(u8, &[_]u8{3} ** 16, &decoded.properties().get("id").?.uuid);
    try std.testing.expectEqual(AmqpValue.null, decoded.properties().get("nothing").?);
}

test "compound application property values are rejected" {
    const allocator = std.testing.allocator;

    var nested = [_]AmqpValue{ .{ .int = 1 }, .{ .string = "two" } };
    var entries = [_]MapEntry{.{ .key = .{ .string = "k" }, .value = .{ .int = 1 } }};

    var event = EventData.init("body");
    defer event.deinit(allocator);

    try std.testing.expectError(
        PropertyError.UnsupportedPropertyValue,
        event.setProperty(allocator, "list", .{ .list = &nested }),
    );
    try std.testing.expectError(
        PropertyError.UnsupportedPropertyValue,
        event.setProperty(allocator, "map", .{ .map = &entries }),
    );
    try std.testing.expectError(
        PropertyError.UnsupportedPropertyValue,
        event.setProperty(allocator, "array", .{ .array = &nested }),
    );
    try std.testing.expectEqual(@as(usize, 0), event.properties.count());
}

test "service annotations populate ReceivedEventData" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("event-body");

    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = sequence_number_annotation }, .value = .{ .long = 1234 } },
        .{ .key = .{ .symbol = offset_annotation }, .value = .{ .string = "9876" } },
        .{ .key = .{ .symbol = enqueued_time_annotation }, .value = .{ .timestamp = 1617235200000 } },
        .{ .key = .{ .symbol = partition_key_annotation }, .value = .{ .string = "pk-1" } },
        .{ .key = .{ .symbol = "x-opt-publisher" }, .value = .{ .string = "device-7" } },
    };
    message.message_annotations = &annotations;

    var decoded = try fromAmqpMessage(allocator, &message);
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings("event-body", decoded.body());
    try std.testing.expectEqual(@as(i64, 1234), decoded.sequence_number);
    try std.testing.expectEqualStrings("9876", decoded.offset.?);
    try std.testing.expectEqual(@as(i64, 1617235200000), decoded.enqueued_time.?);
    try std.testing.expectEqualStrings("pk-1", decoded.partition_key.?);
    try std.testing.expectEqual(@as(usize, 1), decoded.system_properties.count());
    try std.testing.expectEqualStrings(
        "device-7",
        decoded.system_properties.getString("x-opt-publisher").?,
    );
}

test "sequence number accepts any integral annotation encoding" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("body");

    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = sequence_number_annotation }, .value = .{ .int = 99 } },
    };
    message.message_annotations = &annotations;

    var decoded = try fromAmqpMessage(allocator, &message);
    defer decoded.deinit(allocator);
    try std.testing.expectEqual(@as(i64, 99), decoded.sequence_number);
}

test "mistyped annotations are rejected" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("body");

    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = offset_annotation }, .value = .{ .long = 12 } },
    };
    message.message_annotations = &annotations;

    try std.testing.expectError(
        ConversionError.InvalidOffsetAnnotation,
        fromAmqpMessage(allocator, &message),
    );

    var bad_sequence = [_]MapEntry{
        .{ .key = .{ .symbol = sequence_number_annotation }, .value = .{ .string = "12" } },
    };
    message.message_annotations = &bad_sequence;
    try std.testing.expectError(
        ConversionError.InvalidSequenceNumberAnnotation,
        fromAmqpMessage(allocator, &message),
    );
}

test "a message without a single data section decodes to an empty body" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("first");
    try message.addBodyData("second");

    var decoded = try fromAmqpMessage(allocator, &message);
    defer decoded.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), decoded.body().len);
    try std.testing.expectEqual(@as(usize, 2), message.bodyDataCount());
}

test "freeReceivedEvents releases a decoded slice" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("body");

    const events = try allocator.alloc(ReceivedEventData, 2);
    events[0] = try fromAmqpMessage(allocator, &message);
    events[1] = try fromAmqpMessage(allocator, &message);
    freeReceivedEvents(allocator, events);
}

test "fromOwnedAmqpMessage frees the message it adopts" {
    const allocator = std.testing.allocator;

    const message = try allocator.create(Message);
    message.* = Message.init(allocator);
    try message.addBodyData("adopted");

    const annotations = try allocator.alloc(MapEntry, 1);
    annotations[0] = .{
        .key = .{ .symbol = try allocator.dupe(u8, sequence_number_annotation) },
        .value = .{ .long = 5 },
    };
    message.message_annotations = annotations;
    message.properties = .{ .content_type = try allocator.dupe(u8, "text/plain") };

    var decoded = try fromOwnedAmqpMessage(allocator, message);
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings("adopted", decoded.body());
    try std.testing.expectEqual(@as(i64, 5), decoded.sequence_number);
    try std.testing.expect(decoded.raw_amqp_message == message);
    try std.testing.expectEqual(@as(usize, 1), decoded.raw_amqp_message.?.bodyDataCount());
}

test "fromOwnedAmqpMessage frees the message when decoding fails" {
    const allocator = std.testing.allocator;

    const message = try allocator.create(Message);
    message.* = Message.init(allocator);
    try message.addBodyData("body");

    const annotations = try allocator.alloc(MapEntry, 1);
    annotations[0] = .{
        .key = .{ .symbol = try allocator.dupe(u8, offset_annotation) },
        .value = .{ .long = 12 },
    };
    message.message_annotations = annotations;

    try std.testing.expectError(
        ConversionError.InvalidOffsetAnnotation,
        fromOwnedAmqpMessage(allocator, message),
    );
}

test "duplicate offset and partition key annotations are rejected" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("body");

    var duplicate_offset = [_]MapEntry{
        .{ .key = .{ .symbol = offset_annotation }, .value = .{ .string = "1" } },
        .{ .key = .{ .symbol = offset_annotation }, .value = .{ .string = "2" } },
    };
    message.message_annotations = &duplicate_offset;
    try std.testing.expectError(
        ConversionError.DuplicateAnnotation,
        fromAmqpMessage(allocator, &message),
    );

    var duplicate_key = [_]MapEntry{
        .{ .key = .{ .symbol = partition_key_annotation }, .value = .{ .string = "a" } },
        .{ .key = .{ .symbol = partition_key_annotation }, .value = .{ .string = "b" } },
    };
    message.message_annotations = &duplicate_key;
    try std.testing.expectError(
        ConversionError.DuplicateAnnotation,
        fromAmqpMessage(allocator, &message),
    );
}

test "enqueued time must be an AMQP timestamp" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("body");

    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = enqueued_time_annotation }, .value = .{ .long = 1 } },
    };
    message.message_annotations = &annotations;
    try std.testing.expectError(
        ConversionError.InvalidEnqueuedTimeAnnotation,
        fromAmqpMessage(allocator, &message),
    );
}

test "unsigned sequence numbers are rejected like Go" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("body");

    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = sequence_number_annotation }, .value = .{ .ulong = 5 } },
    };
    message.message_annotations = &annotations;
    try std.testing.expectError(
        ConversionError.InvalidSequenceNumberAnnotation,
        fromAmqpMessage(allocator, &message),
    );
}

test "correlation id round-trips every AMQP representation" {
    const allocator = std.testing.allocator;

    const cases = [_]MessageId{
        .{ .string = "corr" },
        .{ .binary = "\x01\x02" },
        .{ .ulong = 900 },
        .{ .uuid = [_]u8{9} ** 16 },
    };
    for (cases) |correlation_id| {
        var event = EventData.init("body");
        defer event.deinit(allocator);
        event.correlation_id = correlation_id;

        var message = try event.toAmqpMessage(allocator);
        defer freeAmqpMessage(allocator, &message);

        var decoded = try fromAmqpMessage(allocator, &message);
        defer decoded.deinit(allocator);

        try std.testing.expect(decoded.correlationId().?.eql(correlation_id));
    }
}

test "conversions survive allocation failure at every step" {
    const Case = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var event = EventData.init("payload");
            defer event.deinit(allocator);
            event.content_type = "application/json";
            event.correlation_id = .{ .string = "corr-1" };
            event.message_id = .{ .ulong = 12 };
            try event.setStringProperty(allocator, "tenant", "contoso");
            try event.setProperty(allocator, "retries", .{ .long = 7 });

            var message = try event.toAmqpMessage(allocator);
            defer freeAmqpMessage(allocator, &message);

            var decoded = try fromAmqpMessage(allocator, &message);
            defer decoded.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Case.run, .{});
}
