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
const DataSection = uamqp.message.DataSection;

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
    /// Whether the keys and values belong to the map or to whoever filled it.
    ///
    /// `put` copies, so the map frees what it holds. `putBorrowed` does not,
    /// because a decoded event points every property at its own backing block
    /// and `deinit` must then release only the map's own storage.
    ///
    /// Recording that here rather than leaving it to the caller to remember
    /// is what keeps `deinit` correct on both, and so keeps `EventData.deinit`
    /// — a public method on a public field of every received event — from
    /// freeing interior pointers into a block it knows nothing about.
    borrowed: bool = false,

    pub const empty: PropertyMap = .{};

    pub fn deinit(self: *PropertyMap, allocator: std.mem.Allocator) void {
        if (!self.borrowed) {
            var it = self.entries.iterator();
            while (it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(allocator);
            }
        }
        self.entries.deinit(allocator);
        self.* = .empty;
    }

    /// Store a deep copy of `value` under a copy of `key`, replacing any
    /// existing entry.
    pub fn put(
        self: *PropertyMap,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: AmqpValue,
    ) !void {
        // Mixing the two would leave the map half owning its contents, which
        // no single `deinit` can then get right. Adding to a received event's
        // properties means copying the event out first.
        std.debug.assert(!self.borrowed);

        var cloned = try value.clone(allocator);
        errdefer cloned.deinit(allocator);

        const owned_key = try allocator.dupe(u8, key);
        errdefer allocator.free(owned_key);

        const gop = try self.entries.getOrPut(allocator, owned_key);
        if (gop.found_existing) {
            allocator.free(owned_key);
            // The assert above is compiled out in ReleaseFast, which is how
            // this library is built. Without this guard the same misuse is a
            // leak for a new key but an invalid free for a colliding one, and
            // overwriting a decoded property is the likelier mistake of the
            // two. Degrade to the leak.
            if (!self.borrowed) gop.value_ptr.deinit(allocator);
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

    /// Insert `key` and `value` without copying either.
    ///
    /// `allocator` is used only for the map's own storage; the caller owns the
    /// key and value bytes and must keep them alive at least as long as the
    /// map, and `deinit` will not free them.
    ///
    /// `ReceivedEventData` is the only user: every property it decodes already
    /// lives in the event's backing block.
    pub fn putBorrowed(
        self: *PropertyMap,
        allocator: std.mem.Allocator,
        key: []const u8,
        value: AmqpValue,
    ) !void {
        std.debug.assert(self.borrowed or self.entries.count() == 0);

        const gop = try self.entries.getOrPut(allocator, key);
        gop.value_ptr.* = value;
        self.borrowed = true;
    }

    /// Size the map for exactly `n` entries, so a run of `putBorrowed` neither
    /// grows it nor leaves it holding slack it will never use.
    ///
    /// `setCapacity` rather than `ensureTotalCapacity`, which applies a
    /// super-linear growth factor on top of what it is asked for.
    pub fn reserveExact(self: *PropertyMap, allocator: std.mem.Allocator, n: usize) !void {
        try self.entries.entries.setCapacity(allocator, n);
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

        // The body belongs to the message's arena, so `deinit` reclaims it.
        // This used to reserve capacity and append with the caller's allocator
        // to dodge `addBodyData` leaking its duplicate when the list failed to
        // grow; since uamqp v0.3.0 the arena reclaims that duplicate anyway,
        // and using the caller's allocator here would leak both the copy and
        // the list, because `deinit` only releases the arena.
        try message.addBodyData(self.body);

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

/// How many application properties a `BorrowedMessage` can describe without
/// allocating. Eight covers the small tag sets events are normally stamped
/// with; beyond it the entries go to the heap rather than being refused.
pub const inline_property_slots: usize = 8;

/// A `Message` whose sections alias an `EventData` instead of copying it.
///
/// `EventDataBatch.tryAdd` encodes and discards each AMQP message before it
/// returns, while the caller's `EventData` outlives the call. This avoids
/// paying for the owning `toAmqpMessage` conversion on that path.
///
/// `init` fills this object in place. Do not move or copy it afterwards: the
/// message's body, annotation, and property slices point into this struct.
pub const BorrowedMessage = struct {
    message: Message,
    body_storage: [1]DataSection,
    annotation_storage: [1]MapEntry,
    property_storage: [inline_property_slots]MapEntry,
    heap_properties: ?[]MapEntry,
    allocator: std.mem.Allocator,

    pub fn init(
        self: *BorrowedMessage,
        allocator: std.mem.Allocator,
        event: EventData,
        partition_key: ?[]const u8,
    ) !void {
        self.* = .{
            .message = Message.init(allocator),
            .body_storage = undefined,
            .annotation_storage = undefined,
            .property_storage = undefined,
            .heap_properties = null,
            .allocator = allocator,
        };
        errdefer self.deinit();

        self.body_storage[0] = .{ .bytes = event.body };
        self.message.body_type = .data;
        self.message.body_data_sections.items = self.body_storage[0..1];
        self.message.body_data_sections.capacity = 1;

        // Go always attaches a properties section, even when every field is
        // unset, so the wire shape stays identical across SDKs.
        self.message.properties = .{};
        if (event.message_id) |message_id| {
            self.message.properties.?.message_id = message_id.toAmqpValue();
        }
        if (event.correlation_id) |correlation_id| {
            self.message.properties.?.correlation_id = correlation_id.toAmqpValue();
        }
        if (event.content_type) |content_type| {
            self.message.properties.?.content_type = content_type;
        }

        const property_count = event.properties.count();
        if (property_count > 0) {
            const entries = if (property_count <= inline_property_slots)
                self.property_storage[0..property_count]
            else entries: {
                const heap = try allocator.alloc(MapEntry, property_count);
                self.heap_properties = heap;
                break :entries heap;
            };
            for (event.properties.keys(), event.properties.values(), entries) |key, value, *entry| {
                entry.* = .{ .key = .{ .string = key }, .value = value };
            }
            self.message.application_properties = entries;
        }

        if (partition_key) |key| {
            self.annotation_storage[0] = .{
                .key = .{ .symbol = partition_key_annotation },
                .value = .{ .string = key },
            };
            self.message.message_annotations = self.annotation_storage[0..1];
        }
    }

    pub fn deinit(self: *BorrowedMessage) void {
        if (self.heap_properties) |entries| {
            self.allocator.free(entries);
            self.heap_properties = null;
        }
        self.message.deinit();
    }
};

/// An event returned by `ConsumerClient`, including the fields Event Hubs
/// populates on the service side.
///
/// Every decoded byte — the body, the ids, the annotations, and both property
/// maps' keys and values — lives in one `backing` block, so an event costs a
/// single allocation rather than one per field. The maps keep their own index
/// storage on the allocator, which is the only other thing `deinit` frees.
///
/// The consequence is that the fields are not individually owned: do not free
/// one, replace one with allocated memory, or add to `properties` with
/// `PropertyMap.put`. Free the event with `deinit` or `freeReceivedEvents`.
///
/// Read the two maps through `properties` and `systemProperties`, which return
/// `*const` so that releasing one through the accessor is a compile error
/// rather than a double free. Zig has no private fields, so `event_data` and
/// `system_properties` are still reachable directly and copying either out by
/// value still yields a map whose `deinit` frees storage the event will free
/// again; the accessors make the path a caller is likely to find the safe one,
/// they do not make the unsafe one unreachable.
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
    /// The one block every decoded field points into. See the type docs.
    backing: []align(block_alignment) u8 = &.{},

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

    /// The event's application properties.
    ///
    /// Returned by pointer, not by value. A `PropertyMap` copy shares the
    /// original's storage but not its identity, so `deinit` on the copy frees
    /// that storage and empties only the copy, leaving the event holding a
    /// dangling `entries` that `ReceivedEventData.deinit` then frees a second
    /// time. `borrowed` does not save it: it suppresses freeing the keys and
    /// values, never the map's own storage. A `*const` result makes that
    /// mistake a compile error, because `deinit` needs a mutable pointer.
    pub fn properties(self: *const ReceivedEventData) *const PropertyMap {
        return &self.event_data.properties;
    }

    /// The annotations not surfaced as dedicated fields. `*const` for the
    /// same reason as `properties`.
    pub fn systemProperties(self: *const ReceivedEventData) *const PropertyMap {
        return &self.system_properties;
    }

    /// Calling this twice on the same event is harmless: it is left empty, so
    /// the second call has nothing to free.
    ///
    /// That is not ownership tracking. A `ReceivedEventData` copied by value
    /// and then released through one copy leaves the other holding freed
    /// pointers, because emptying one struct cannot reach the other.
    pub fn deinit(self: *ReceivedEventData, allocator: std.mem.Allocator) void {
        self.event_data.properties.deinit(allocator);
        self.system_properties.deinit(allocator);
        allocator.free(self.backing);
        self.* = .{};
    }
};

pub fn freeReceivedEvents(allocator: std.mem.Allocator, events: []ReceivedEventData) void {
    for (events) |*event| event.deinit(allocator);
    allocator.free(events);
}

/// Free a message produced by `EventData.toAmqpMessage`, including any
/// annotations added afterwards by `setPartitionKeyAnnotation`.
///
/// Only the sections this module allocates with `allocator` are released here.
/// The body is not among them: it lives in the message's arena, which
/// `Message.deinit` releases.
pub fn freeAmqpMessage(allocator: std.mem.Allocator, message: *Message) void {
    if (message.application_properties) |entries| {
        freeMapEntries(allocator, entries);
        message.application_properties = null;
    }
    if (message.message_annotations) |entries| {
        freeMapEntries(allocator, entries);
        message.message_annotations = null;
    }
    if (message.properties) |*properties| {
        if (properties.message_id) |*message_id| message_id.deinit(allocator);
        if (properties.correlation_id) |*correlation_id| correlation_id.deinit(allocator);
        if (properties.content_type) |content_type| allocator.free(content_type);
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

/// Stamp `x-opt-partition-key` on a message built by `EventData.toAmqpMessage`.
///
/// Event Hubs hashes this annotation to pick a partition, and Go applies it to
/// every message as it enters a batch so the encoded size accounts for it.
pub fn setPartitionKeyAnnotation(
    allocator: std.mem.Allocator,
    message: *Message,
    partition_key: []const u8,
) !void {
    const entries = try allocator.alloc(MapEntry, 1);
    errdefer allocator.free(entries);

    const key = try allocator.dupe(u8, partition_key_annotation);
    errdefer allocator.free(key);
    const value = try allocator.dupe(u8, partition_key);

    entries[0] = .{ .key = .{ .symbol = key }, .value = .{ .string = value } };
    if (message.message_annotations) |existing| freeMapEntries(allocator, existing);
    message.message_annotations = entries;
}

// ─────────────────── Message serialization ───────────────────

/// Encode a message into AMQP 1.0 wire format, section by section
/// (AMQP 1.0 section 3.2).
///
/// `uamqp` encodes individual values but has no message serializer, so the
/// sections are assembled here. Batching needs this to measure real sizes
/// instead of estimating them.
pub fn encodeMessage(allocator: std.mem.Allocator, message: *const Message) ![]u8 {
    return encodeMessageSections(allocator, message, true);
}

/// Encode every section except the body.
///
/// A batch transfer reuses the first message's sections as the envelope around
/// the per-message data sections, so its size is measured without a body.
pub fn encodeMessageEnvelope(allocator: std.mem.Allocator, message: *const Message) ![]u8 {
    return encodeMessageSections(allocator, message, false);
}

fn encodeMessageSections(
    allocator: std.mem.Allocator,
    message: *const Message,
    include_body: bool,
) ![]u8 {
    var buffer = uamqp.encoder.Buffer.initDynamic(allocator);
    errdefer buffer.deinit();

    if (message.header) |header| {
        var fields = [_]AmqpValue{
            .{ .boolean = header.durable },
            .{ .ubyte = header.priority },
            if (header.ttl) |ttl| .{ .uint = ttl } else .null,
            .{ .boolean = header.first_acquirer },
            .{ .uint = header.delivery_count },
        };
        try encodeSection(&buffer, uamqp.definitions.descriptor.header, .{
            .list = trimTrailingNulls(&fields),
        });
    }

    if (message.delivery_annotations) |entries| {
        try encodeSection(&buffer, uamqp.definitions.descriptor.delivery_annotations, .{
            .map = entries,
        });
    }

    if (message.message_annotations) |entries| {
        try encodeSection(&buffer, uamqp.definitions.descriptor.message_annotations, .{
            .map = entries,
        });
    }

    if (message.properties) |properties| {
        var fields = [_]AmqpValue{
            properties.message_id orelse .null,
            optionalBinary(properties.user_id),
            optionalString(properties.to),
            optionalString(properties.subject),
            optionalString(properties.reply_to),
            properties.correlation_id orelse .null,
            optionalSymbol(properties.content_type),
            optionalSymbol(properties.content_encoding),
            if (properties.absolute_expiry_time) |v| .{ .timestamp = v } else .null,
            if (properties.creation_time) |v| .{ .timestamp = v } else .null,
            optionalString(properties.group_id),
            if (properties.group_sequence) |v| .{ .uint = v } else .null,
            optionalString(properties.reply_to_group_id),
        };
        try encodeSection(&buffer, uamqp.definitions.descriptor.properties, .{
            .list = trimTrailingNulls(&fields),
        });
    }

    if (message.application_properties) |entries| {
        try encodeSection(&buffer, uamqp.definitions.descriptor.application_properties, .{
            .map = entries,
        });
    }

    if (include_body) {
        switch (message.body_type) {
            .none => {},
            .data => for (message.body_data_sections.items) |section| {
                try encodeSection(&buffer, uamqp.definitions.descriptor.data, .{
                    .binary = section.bytes,
                });
            },
            .sequence => for (message.body_sequence_sections.items) |sequence| {
                try encodeSection(&buffer, uamqp.definitions.descriptor.amqp_sequence, .{
                    .list = sequence,
                });
            },
            .value => if (message.body_value) |value| {
                try encodeSection(&buffer, uamqp.definitions.descriptor.amqp_value, value);
            },
        }
    }

    if (message.footer) |entries| {
        try encodeSection(&buffer, uamqp.definitions.descriptor.footer, .{ .map = entries });
    }

    // `toOwnedSlice` shrinks the buffer's own allocation to the written length
    // and hands it over. Duplicating `written()` instead would allocate a
    // second full-size buffer and copy every byte into it, on the per-event
    // path of every batch.
    return buffer.toOwnedSlice();
}

/// Append one data section per payload to an already encoded prefix.
///
/// This is how an Event Hubs batch is laid out: the envelope from
/// `encodeMessageEnvelope` followed by the contained messages, each wrapped in
/// its own data section. `EventData.toAmqpMessage` produces no footer, so
/// nothing in the envelope has to follow the body.
pub fn encodeDataSections(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    payloads: []const []u8,
) ![]u8 {
    // The exact size is plain arithmetic here — `dataSectionSize` is the same
    // constant-overhead formula batching already charges per event — so the
    // whole concatenation is one allocation. Growing a dynamic buffer instead
    // costs a doubling series of reallocations across a batch that may reach
    // the 1 MiB message limit, and then a full copy of the result.
    var total: usize = prefix.len;
    for (payloads) |payload| total += dataSectionSize(payload.len);

    const bytes = try allocator.alloc(u8, total);
    errdefer allocator.free(bytes);

    var buffer = uamqp.encoder.Buffer.initFixed(bytes);
    try buffer.writeAll(prefix);
    for (payloads) |payload| {
        try encodeSection(&buffer, uamqp.definitions.descriptor.data, .{ .binary = payload });
    }

    // `dataSectionSize` is exact, so this holds; shrinking rather than
    // asserting means a future disagreement returns correct bytes instead of a
    // buffer with a garbage tail.
    if (buffer.pos != total) return try allocator.realloc(bytes, buffer.pos);
    return bytes;
}

/// Encoded size of the data section wrapping a payload of `payload_len` bytes:
/// a described-type constructor, the descriptor, and a binary length prefix.
/// Go's `calcActualSizeForPayload` uses the same constants.
///
/// Batching charges this per event without encoding anything, so it has to
/// agree with what `encodeDataSections` writes; sharing one function rather
/// than restating the constants is what keeps them from drifting apart.
pub fn dataSectionSize(payload_len: usize) usize {
    const vbin8_overhead = 5;
    const vbin32_overhead = 8;
    return if (payload_len < 256) vbin8_overhead + payload_len else vbin32_overhead + payload_len;
}

fn encodeSection(buffer: *uamqp.encoder.Buffer, code: u64, value: AmqpValue) !void {
    var descriptor: AmqpValue = .{ .ulong = code };
    var section = value;
    try uamqp.encoder.encode(
        .{ .described = .{ .descriptor = &descriptor, .value = &section } },
        buffer,
    );
}

/// AMQP composite types may omit trailing null fields, which every real
/// encoder does and which keeps measured batch sizes realistic.
fn trimTrailingNulls(fields: []AmqpValue) []AmqpValue {
    var len = fields.len;
    while (len > 0 and fields[len - 1] == .null) len -= 1;
    return fields[0..len];
}

fn optionalString(value: ?[]const u8) AmqpValue {
    return if (value) |text| .{ .string = text } else .null;
}

fn optionalSymbol(value: ?[]const u8) AmqpValue {
    return if (value) |text| .{ .symbol = text } else .null;
}

fn optionalBinary(value: ?[]const u8) AmqpValue {
    return if (value) |bytes| .{ .binary = bytes } else .null;
}

/// The parts of an AMQP message an Event Hubs event is decoded from.
///
/// A neutral shape, so a message decoded by any codec can be converted without
/// first being rebuilt as a `uamqp.message.Message`.
pub const RawMessage = struct {
    /// The single data section Event Hubs uses for an event body. Null when
    /// the message has none or has several, which Go treats the same way.
    body: ?[]const u8 = null,
    message_annotations: ?[]const MapEntry = null,
    application_properties: ?[]const MapEntry = null,
    message_id: ?AmqpValue = null,
    correlation_id: ?AmqpValue = null,
    content_type: ?[]const u8 = null,
};

/// Decode the parts of an AMQP message into a received event.
///
/// Everything is borrowed and copied out, so the result stays valid after the
/// message it came from is freed.
///
/// The copy goes into one block, sized by `blockBytes` before anything is
/// written. That costs a second walk of the message but turns a decode that
/// allocated once per field into one that allocates once per event.
pub fn fromRawMessage(
    allocator: std.mem.Allocator,
    raw: RawMessage,
) !ReceivedEventData {
    var received: ReceivedEventData = .{};
    errdefer received.deinit(allocator);

    const layout = plan(raw);
    received.backing = try allocator.alignedAlloc(u8, .fromByteUnits(block_alignment), layout.bytes);
    var fixed = std.heap.FixedBufferAllocator.init(received.backing);
    const block = fixed.allocator();

    received.event_data.body = try block.dupe(u8, raw.body orelse "");

    if (raw.content_type) |content_type| {
        received.event_data.content_type = try block.dupe(u8, content_type);
    }
    if (raw.correlation_id) |correlation_id| {
        if (MessageId.fromAmqpValue(correlation_id)) |parsed| {
            received.event_data.correlation_id = try parsed.clone(block);
        }
    }
    if (raw.message_id) |message_id| {
        if (MessageId.fromAmqpValue(message_id)) |parsed| {
            received.event_data.message_id = try parsed.clone(block);
        }
    }

    if (raw.application_properties) |entries| {
        // Exactly the number of puts that follow, so the map is sized once
        // rather than grown into, and never past what it holds.
        if (layout.properties > 0) {
            try received.event_data.properties.reserveExact(allocator, layout.properties);
        }
        for (entries) |entry| {
            const key = keyOf(entry.key) orelse continue;
            try received.event_data.properties.putBorrowed(
                allocator,
                try block.dupe(u8, key),
                try entry.value.clone(block),
            );
        }
    }

    if (raw.message_annotations) |entries| {
        if (layout.system_properties > 0) {
            try received.system_properties.reserveExact(allocator, layout.system_properties);
        }
        try applyAnnotations(allocator, block, entries, &received);
    }

    return received;
}

/// Alignment of a received event's backing block, and the granularity every
/// reservation in `blockBytes` is rounded to.
///
/// No allocation made from the block needs more than this: the widest thing
/// carved out of it is an `AmqpValue`, and the rest are byte slices.
const block_alignment = @alignOf(AmqpValue);

comptime {
    std.debug.assert(@alignOf(MapEntry) <= block_alignment);
}

/// Rounding each reservation up to the block's alignment is what makes their
/// sum an upper bound no matter what order the allocations happen in: a
/// cursor that starts at a multiple of the alignment and has consumed at most
/// the sum so far can never be pushed past it by realigning for the next.
fn reserve(n: usize) usize {
    return std.mem.alignForward(usize, n, block_alignment);
}

/// Bytes `value.clone` takes from the block.
///
/// This mirrors `AmqpValue.clone` allocation for allocation, so the switch is
/// deliberately exhaustive rather than defaulting: a type added to `AmqpValue`
/// upstream has to fail to compile here rather than silently under-reserve
/// and turn into an `OutOfMemory` at decode time.
fn cloneSize(value: AmqpValue) usize {
    return switch (value) {
        .null,
        .boolean,
        .ubyte,
        .ushort,
        .uint,
        .ulong,
        .byte,
        .short,
        .int,
        .long,
        .float,
        .double,
        .char,
        .timestamp,
        .uuid,
        => 0,
        .binary, .string, .symbol => |bytes| reserve(bytes.len),
        .list, .array => |items| total: {
            var total = reserve(items.len * @sizeOf(AmqpValue));
            for (items) |item| total += cloneSize(item);
            break :total total;
        },
        .map => |entries| total: {
            var total = reserve(entries.len * @sizeOf(MapEntry));
            for (entries) |entry| total += cloneSize(entry.key) + cloneSize(entry.value);
            break :total total;
        },
        .described => |described| reserve(@sizeOf(AmqpValue)) * 2 +
            cloneSize(described.descriptor.*) + cloneSize(described.value.*),
    };
}

/// What one decode needs, measured before anything is written.
const Layout = struct {
    /// Size of the backing block.
    bytes: usize = 0,
    /// Application properties that will be stored, so the map is sized once.
    properties: usize = 0,
    /// Annotations that are not surfaced as dedicated fields.
    system_properties: usize = 0,
};

/// Measure what the decode will take. Walks exactly the fields
/// `fromRawMessage` copies, skipping exactly the ones it skips.
fn plan(raw: RawMessage) Layout {
    var layout: Layout = .{};
    layout.bytes = reserve(if (raw.body) |body| body.len else 0);
    if (raw.content_type) |content_type| layout.bytes += reserve(content_type.len);
    if (raw.correlation_id) |value| layout.bytes += messageIdSize(value);
    if (raw.message_id) |value| layout.bytes += messageIdSize(value);

    if (raw.application_properties) |entries| {
        for (entries) |entry| {
            const key = keyOf(entry.key) orelse continue;
            layout.properties += 1;
            layout.bytes += reserve(key.len) + cloneSize(entry.value);
        }
    }

    if (raw.message_annotations) |entries| {
        for (entries) |entry| {
            const key = keyOf(entry.key) orelse continue;
            switch (annotationOf(key)) {
                // Read straight out of the value; nothing is copied.
                .sequence_number, .enqueued_time => {},
                // Copied only when the value is a string. Anything else is an
                // error, and an error needs no room.
                .partition_key, .offset => layout.bytes += switch (entry.value) {
                    .string => |text| reserve(text.len),
                    else => 0,
                },
                .other => {
                    layout.system_properties += 1;
                    layout.bytes += reserve(key.len) + cloneSize(entry.value);
                },
            }
        }
    }

    return layout;
}

fn messageIdSize(value: AmqpValue) usize {
    const parsed = MessageId.fromAmqpValue(value) orelse return 0;
    return switch (parsed) {
        .binary, .string => |bytes| reserve(bytes.len),
        .ulong, .uuid => 0,
    };
}

/// The annotations Event Hubs stamps on a received event.
///
/// Shared by the sizing pass and the decode so the two cannot disagree about
/// which annotation is handled how — both switch on it exhaustively, so a new
/// one has to be given a size as well as a meaning.
const Annotation = enum { sequence_number, partition_key, enqueued_time, offset, other };

fn annotationOf(key: []const u8) Annotation {
    if (std.mem.eql(u8, key, sequence_number_annotation)) return .sequence_number;
    if (std.mem.eql(u8, key, partition_key_annotation)) return .partition_key;
    if (std.mem.eql(u8, key, enqueued_time_annotation)) return .enqueued_time;
    if (std.mem.eql(u8, key, offset_annotation)) return .offset;
    return .other;
}

/// Decode an AMQP message into a received event.
///
/// `message` is borrowed and every field is copied out, so the result stays
/// valid after the message is freed. Only a single data section is treated as
/// a body; sequence and value bodies, multiple data sections, the header, and
/// the footer are not modelled by `ReceivedEventData`.
pub fn fromAmqpMessage(
    allocator: std.mem.Allocator,
    message: *const Message,
) !ReceivedEventData {
    // Go only treats a message as having a body when there is exactly one data
    // section.
    const body: ?[]const u8 = if (message.body_data_sections.items.len == 1)
        message.body_data_sections.items[0].bytes
    else
        null;

    return fromRawMessage(allocator, .{
        .body = body,
        .message_annotations = message.message_annotations,
        .application_properties = message.application_properties,
        .message_id = if (message.properties) |p| p.message_id else null,
        .correlation_id = if (message.properties) |p| p.correlation_id else null,
        .content_type = if (message.properties) |p| p.content_type else null,
    });
}

fn applyAnnotations(
    allocator: std.mem.Allocator,
    block: std.mem.Allocator,
    entries: []const MapEntry,
    received: *ReceivedEventData,
) !void {
    for (entries) |entry| {
        const key = keyOf(entry.key) orelse continue;
        switch (annotationOf(key)) {
            .sequence_number => {
                received.sequence_number = toInt64(entry.value) orelse
                    return ConversionError.InvalidSequenceNumberAnnotation;
            },
            .partition_key => {
                if (received.partition_key != null) return ConversionError.DuplicateAnnotation;
                const value = switch (entry.value) {
                    .string => |text| text,
                    else => return ConversionError.InvalidPartitionKeyAnnotation,
                };
                received.partition_key = try block.dupe(u8, value);
            },
            .enqueued_time => {
                received.enqueued_time = switch (entry.value) {
                    .timestamp => |value| value,
                    else => return ConversionError.InvalidEnqueuedTimeAnnotation,
                };
            },
            .offset => {
                if (received.offset != null) return ConversionError.DuplicateAnnotation;
                const value = switch (entry.value) {
                    .string => |text| text,
                    else => return ConversionError.InvalidOffsetAnnotation,
                };
                received.offset = try block.dupe(u8, value);
            },
            .other => try received.system_properties.putBorrowed(
                allocator,
                try block.dupe(u8, key),
                try entry.value.clone(block),
            ),
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

test "setPartitionKeyAnnotation stamps the annotation Event Hubs hashes" {
    const allocator = std.testing.allocator;

    var event = EventData.init("body");
    defer event.deinit(allocator);

    var message = try event.toAmqpMessage(allocator);
    defer freeAmqpMessage(allocator, &message);

    try setPartitionKeyAnnotation(allocator, &message, "pk-9");
    try setPartitionKeyAnnotation(allocator, &message, "pk-10");

    var decoded = try fromAmqpMessage(allocator, &message);
    defer decoded.deinit(allocator);
    try std.testing.expectEqualStrings("pk-10", decoded.partition_key.?);
}

fn expectBorrowedMessageMatchesOwned(
    allocator: std.mem.Allocator,
    event: EventData,
    partition_key: ?[]const u8,
) !void {
    var owned = try event.toAmqpMessage(allocator);
    defer freeAmqpMessage(allocator, &owned);
    if (partition_key) |key| try setPartitionKeyAnnotation(allocator, &owned, key);

    const owned_encoded = try encodeMessage(allocator, &owned);
    defer allocator.free(owned_encoded);
    const owned_envelope = try encodeMessageEnvelope(allocator, &owned);
    defer allocator.free(owned_envelope);

    var borrowed: BorrowedMessage = undefined;
    try borrowed.init(allocator, event, partition_key);
    defer borrowed.deinit();

    const borrowed_encoded = try encodeMessage(allocator, &borrowed.message);
    defer allocator.free(borrowed_encoded);
    const borrowed_envelope = try encodeMessageEnvelope(allocator, &borrowed.message);
    defer allocator.free(borrowed_envelope);

    try std.testing.expectEqualSlices(u8, owned_encoded, borrowed_encoded);
    try std.testing.expectEqualSlices(u8, owned_envelope, borrowed_envelope);
}

test "BorrowedMessage encodes byte-identically to owning EventData conversion" {
    const allocator = std.testing.allocator;

    {
        var event = EventData.init("plain");
        defer event.deinit(allocator);
        try expectBorrowedMessageMatchesOwned(allocator, event, null);
    }
    {
        var event = EventData.init("typed");
        defer event.deinit(allocator);
        event.content_type = "application/json";
        try expectBorrowedMessageMatchesOwned(allocator, event, null);
    }
    {
        var event = EventData.init("string ids");
        defer event.deinit(allocator);
        event.message_id = .{ .string = "msg-1" };
        event.correlation_id = .{ .string = "corr-1" };
        try expectBorrowedMessageMatchesOwned(allocator, event, null);
    }
    {
        var event = EventData.init("numeric ids");
        defer event.deinit(allocator);
        event.message_id = .{ .ulong = 42 };
        event.correlation_id = .{ .ulong = 9001 };
        try expectBorrowedMessageMatchesOwned(allocator, event, null);
    }
    {
        var event = EventData.init("inline props");
        defer event.deinit(allocator);
        try event.setStringProperty(allocator, "tenant", "contoso");
        try event.setProperty(allocator, "attempt", .{ .long = 3 });
        try event.setProperty(allocator, "enabled", .{ .boolean = true });
        try expectBorrowedMessageMatchesOwned(allocator, event, null);
    }
    {
        var event = EventData.init("heap props");
        defer event.deinit(allocator);
        const keys = [_][]const u8{ "p0", "p1", "p2", "p3", "p4", "p5", "p6", "p7", "p8", "p9" };
        for (keys, 0..) |key, i| {
            try event.setProperty(allocator, key, .{ .long = @intCast(i) });
        }
        try std.testing.expect(keys.len > inline_property_slots);
        try expectBorrowedMessageMatchesOwned(allocator, event, null);
    }
    // The two counts either side of the inline/heap boundary, because an
    // off-by-one in that comparison is invisible at 3 and at 10: taking the
    // inline path for one property too many overruns `property_storage`,
    // and taking the heap path one property too early still encodes
    // correctly and so would go unnoticed.
    inline for (.{ inline_property_slots, inline_property_slots + 1 }) |count| {
        var event = EventData.init("boundary props");
        defer event.deinit(allocator);
        var buf: [8]u8 = undefined;
        for (0..count) |i| {
            const key = try std.fmt.bufPrint(&buf, "k{d}", .{i});
            try event.setProperty(allocator, key, .{ .long = @intCast(i) });
        }
        try std.testing.expectEqual(count, event.properties.count());
        try expectBorrowedMessageMatchesOwned(allocator, event, null);
    }
    {
        var event = EventData.init("partitioned");
        defer event.deinit(allocator);
        event.content_type = "text/plain";
        try expectBorrowedMessageMatchesOwned(allocator, event, "pk-1");
    }
}

test "encodeMessage emits a data section in AMQP wire format" {
    const allocator = std.testing.allocator;

    var message = Message.init(allocator);
    defer message.deinit();
    try message.addBodyData("hi");

    const encoded = try encodeMessage(allocator, &message);
    defer allocator.free(encoded);

    // 0x00 described constructor, 0x53 smallulong descriptor 0x75 (data),
    // 0xa0 binary with a one-byte length of 2.
    try std.testing.expectEqualSlices(
        u8,
        &[_]u8{ 0x00, 0x53, 0x75, 0xa0, 0x02, 'h', 'i' },
        encoded,
    );
}

test "encoded sections decode back with the right descriptors" {
    const allocator = std.testing.allocator;

    var event = EventData.init("payload");
    defer event.deinit(allocator);
    event.content_type = "application/json";
    try event.setStringProperty(allocator, "tenant", "contoso");

    var message = try event.toAmqpMessage(allocator);
    defer freeAmqpMessage(allocator, &message);
    try setPartitionKeyAnnotation(allocator, &message, "pk-1");

    const encoded = try encodeMessage(allocator, &message);
    defer allocator.free(encoded);

    const expected = [_]u64{
        uamqp.definitions.descriptor.message_annotations,
        uamqp.definitions.descriptor.properties,
        uamqp.definitions.descriptor.application_properties,
        uamqp.definitions.descriptor.data,
    };

    var offset: usize = 0;
    for (expected) |descriptor_code| {
        var result = try uamqp.decoder.decode(allocator, encoded[offset..]);
        defer result.value.deinit(allocator);
        try std.testing.expectEqual(descriptor_code, result.value.described.descriptor.ulong);
        offset += result.bytes_consumed;
    }
    try std.testing.expectEqual(encoded.len, offset);
}

test "encodeMessageEnvelope drops the body" {
    const allocator = std.testing.allocator;

    var event = EventData.init("a fairly long payload that dominates the encoded size");
    defer event.deinit(allocator);
    event.content_type = "text/plain";

    var message = try event.toAmqpMessage(allocator);
    defer freeAmqpMessage(allocator, &message);

    const full = try encodeMessage(allocator, &message);
    defer allocator.free(full);
    const envelope = try encodeMessageEnvelope(allocator, &message);
    defer allocator.free(envelope);

    try std.testing.expect(envelope.len < full.len);
    try std.testing.expectEqualSlices(u8, envelope, full[0..envelope.len]);
}

test "dataSectionSize matches what encodeDataSections writes" {
    const allocator = std.testing.allocator;

    // `encodeDataSections` allocates exactly `dataSectionSize` per payload and
    // encodes into a fixed buffer, so a disagreement would truncate the wire
    // payload. The vbin8/vbin32 boundary is where the two would drift first.
    const lengths = [_]usize{ 0, 1, 254, 255, 256, 257, 1024 };

    for (lengths) |len| {
        const payload = try allocator.alloc(u8, len);
        defer allocator.free(payload);
        @memset(payload, 0x5a);

        const payloads = [_][]u8{payload};
        const encoded = try encodeDataSections(allocator, "", &payloads);
        defer allocator.free(encoded);

        try std.testing.expectEqual(dataSectionSize(len), encoded.len);

        var result = try uamqp.decoder.decode(allocator, encoded);
        defer result.value.deinit(allocator);
        try std.testing.expectEqual(
            uamqp.definitions.descriptor.data,
            result.value.described.descriptor.ulong,
        );
        try std.testing.expectEqualSlices(u8, payload, result.value.described.value.binary);
        try std.testing.expectEqual(encoded.len, result.bytes_consumed);
    }
}

test "encodeDataSections keeps the prefix and appends one section per payload" {
    const allocator = std.testing.allocator;

    var first = [_]u8{ 1, 2, 3 };
    var second = [_]u8{ 4, 5 };
    const payloads = [_][]u8{ &first, &second };

    const encoded = try encodeDataSections(allocator, "PREFIX", &payloads);
    defer allocator.free(encoded);

    try std.testing.expectEqualSlices(u8, "PREFIX", encoded[0..6]);
    try std.testing.expectEqual(
        6 + dataSectionSize(first.len) + dataSectionSize(second.len),
        encoded.len,
    );

    var offset: usize = 6;
    for ([_][]const u8{ &first, &second }) |expected| {
        var result = try uamqp.decoder.decode(allocator, encoded[offset..]);
        defer result.value.deinit(allocator);
        try std.testing.expectEqualSlices(u8, expected, result.value.described.value.binary);
        offset += result.bytes_consumed;
    }
    try std.testing.expectEqual(encoded.len, offset);
}

test "trailing null fields are omitted from composite sections" {
    const allocator = std.testing.allocator;

    var with_content_type = Message.init(allocator);
    defer with_content_type.deinit();
    with_content_type.properties = .{ .content_type = "text/plain" };

    var empty_properties = Message.init(allocator);
    defer empty_properties.deinit();
    empty_properties.properties = .{};

    const long = try encodeMessage(allocator, &with_content_type);
    defer allocator.free(long);
    const short = try encodeMessage(allocator, &empty_properties);
    defer allocator.free(short);

    // An all-null properties section collapses to the empty-list format code.
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x00, 0x53, 0x73, 0x45 }, short);
    try std.testing.expect(long.len > short.len);
}

test "a decoded event is one block plus its property maps" {
    const allocator = std.testing.allocator;

    var counting = CountingAllocator.init(allocator);
    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = sequence_number_annotation }, .value = .{ .long = 7 } },
        .{ .key = .{ .symbol = offset_annotation }, .value = .{ .string = "12345" } },
        .{ .key = .{ .symbol = partition_key_annotation }, .value = .{ .string = "pk" } },
    };
    var properties = [_]MapEntry{
        .{ .key = .{ .string = "a" }, .value = .{ .string = "one" } },
        .{ .key = .{ .string = "b" }, .value = .{ .int = 2 } },
    };

    var decoded = try fromRawMessage(counting.allocator(), .{
        .body = "hello",
        .content_type = "text/plain",
        .message_id = .{ .string = "id" },
        .message_annotations = &annotations,
        .application_properties = &properties,
    });
    defer decoded.deinit(counting.allocator());

    // One for the block, one for the property map. The annotations all map to
    // dedicated fields, so `system_properties` stays empty and unallocated.
    try std.testing.expectEqual(@as(usize, 2), counting.allocations);

    // And the map was sized for exactly what it holds, so that one allocation
    // is neither grown into nor left holding slack.
    try std.testing.expectEqual(
        decoded.properties().count(),
        decoded.event_data.properties.entries.entries.capacity,
    );
}

test "every AMQP value shape fits the block it was measured for" {
    const allocator = std.testing.allocator;

    // Application properties are supposed to be simple types, but nothing
    // stops a peer sending otherwise and the decode clones whatever arrives.
    // Anything `AmqpValue.clone` allocates, `cloneSize` has to have counted.
    var inner = [_]AmqpValue{ .{ .string = "deep" }, .{ .binary = "bytes" } };
    var inner_map = [_]MapEntry{.{ .key = .{ .symbol = "nested-key" }, .value = .{ .list = &inner } }};
    var descriptor: AmqpValue = .{ .symbol = "com.example:thing" };
    var described_value: AmqpValue = .{ .map = &inner_map };

    var properties = [_]MapEntry{
        .{ .key = .{ .string = "null" }, .value = .null },
        .{ .key = .{ .string = "boolean" }, .value = .{ .boolean = true } },
        .{ .key = .{ .string = "ubyte" }, .value = .{ .ubyte = 1 } },
        .{ .key = .{ .string = "ushort" }, .value = .{ .ushort = 2 } },
        .{ .key = .{ .string = "uint" }, .value = .{ .uint = 3 } },
        .{ .key = .{ .string = "ulong" }, .value = .{ .ulong = 4 } },
        .{ .key = .{ .string = "byte" }, .value = .{ .byte = -1 } },
        .{ .key = .{ .string = "short" }, .value = .{ .short = -2 } },
        .{ .key = .{ .string = "int" }, .value = .{ .int = -3 } },
        .{ .key = .{ .string = "long" }, .value = .{ .long = -4 } },
        .{ .key = .{ .string = "float" }, .value = .{ .float = 1.5 } },
        .{ .key = .{ .string = "double" }, .value = .{ .double = 2.5 } },
        .{ .key = .{ .string = "char" }, .value = .{ .char = 'z' } },
        .{ .key = .{ .string = "timestamp" }, .value = .{ .timestamp = 1700000000 } },
        .{ .key = .{ .string = "uuid" }, .value = .{ .uuid = @splat(7) } },
        .{ .key = .{ .string = "binary" }, .value = .{ .binary = "raw" } },
        .{ .key = .{ .string = "string" }, .value = .{ .string = "text" } },
        .{ .key = .{ .string = "symbol" }, .value = .{ .symbol = "sym" } },
        .{ .key = .{ .string = "list" }, .value = .{ .list = &inner } },
        .{ .key = .{ .string = "map" }, .value = .{ .map = &inner_map } },
        .{ .key = .{ .string = "array" }, .value = .{ .array = &inner } },
        .{
            .key = .{ .string = "described" },
            .value = .{ .described = .{ .descriptor = &descriptor, .value = &described_value } },
        },
        // A key that is neither a string nor a symbol is skipped, and must be
        // skipped by the measuring pass too or the block is oversized.
        .{ .key = .{ .int = 9 }, .value = .{ .string = "unreachable" } },
    };
    // The same shapes again as annotations, which land in `system_properties`.
    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = "x-opt-vendor-list" }, .value = .{ .list = &inner } },
        .{
            .key = .{ .symbol = "x-opt-vendor-described" },
            .value = .{ .described = .{ .descriptor = &descriptor, .value = &described_value } },
        },
    };

    var decoded = try fromRawMessage(allocator, .{
        .body = "body",
        .message_annotations = &annotations,
        .application_properties = &properties,
    });
    defer decoded.deinit(allocator);

    try std.testing.expectEqual(properties.len - 1, decoded.properties().count());
    try std.testing.expectEqual(@as(usize, 2), decoded.system_properties.count());
    try std.testing.expect(decoded.properties().get("list").?.eql(.{ .list = &inner }));
    try std.testing.expect(decoded.properties().get("map").?.eql(.{ .map = &inner_map }));
    try std.testing.expect(decoded.system_properties.get("x-opt-vendor-described").?.eql(
        .{ .described = .{ .descriptor = &descriptor, .value = &described_value } },
    ));
    try std.testing.expect(decoded.properties().get("unreachable") == null);
}

test "each value shape is measured with nothing to spare" {
    const allocator = std.testing.allocator;

    // Every key and string here is a multiple of the block alignment, so the
    // measured size is exact rather than rounded up, and each shape is the
    // only thing in its message. A term missing from `plan` or `cloneSize`
    // then runs the decode out of block. The broad test above cannot do this
    // job: across two dozen properties its rounding slack is large enough to
    // swallow a miscount of a whole nested value.
    var pair = [_]AmqpValue{ .{ .string = "aaaaaaaa" }, .{ .binary = "bbbbbbbb" } };
    var pair_map = [_]MapEntry{
        .{ .key = .{ .symbol = "cccccccc" }, .value = .{ .string = "dddddddd" } },
    };
    var descriptor: AmqpValue = .{ .symbol = "eeeeeeee" };
    var described_value: AmqpValue = .{ .map = &pair_map };

    const shapes = [_]AmqpValue{
        .{ .string = "gggggggg" },
        .{ .binary = "hhhhhhhh" },
        .{ .symbol = "iiiiiiii" },
        .{ .list = &pair },
        .{ .array = &pair },
        .{ .map = &pair_map },
        .{ .described = .{ .descriptor = &descriptor, .value = &described_value } },
    };

    for (shapes) |shape| {
        var properties = [_]MapEntry{.{ .key = .{ .string = "kkkkkkkk" }, .value = shape }};
        var annotations = [_]MapEntry{.{ .key = .{ .symbol = "mmmmmmmm" }, .value = shape }};

        var decoded = try fromRawMessage(allocator, .{
            .application_properties = &properties,
            .message_annotations = &annotations,
        });
        defer decoded.deinit(allocator);

        try std.testing.expect(decoded.properties().get("kkkkkkkk").?.eql(shape));
        try std.testing.expect(decoded.system_properties.get("mmmmmmmm").?.eql(shape));
    }
}

test "each dedicated field is measured with nothing to spare" {
    const allocator = std.testing.allocator;

    // Same idea as above, for the fields that are copied out by name rather
    // than through `cloneSize`.
    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = offset_annotation }, .value = .{ .string = "oooooooo" } },
        .{ .key = .{ .symbol = partition_key_annotation }, .value = .{ .string = "pppppppp" } },
    };

    var decoded = try fromRawMessage(allocator, .{
        .body = "bbbbbbbb",
        .content_type = "tttttttt",
        .message_id = .{ .string = "iiiiiiii" },
        .correlation_id = .{ .binary = "cccccccc" },
        .message_annotations = &annotations,
    });
    defer decoded.deinit(allocator);

    try std.testing.expectEqualStrings("bbbbbbbb", decoded.body());
    try std.testing.expectEqualStrings("tttttttt", decoded.contentType().?);
    try std.testing.expectEqualStrings("iiiiiiii", decoded.messageId().?.string);
    try std.testing.expectEqualStrings("cccccccc", decoded.correlationId().?.binary);
    try std.testing.expectEqualStrings("oooooooo", decoded.offset.?);
    try std.testing.expectEqualStrings("pppppppp", decoded.partition_key.?);
}

test "a decoded event outlives every byte it was decoded from" {
    const allocator = std.testing.allocator;

    // The copy has to be deep: heap-allocate the source, then release it
    // before reading anything back.
    const body = try allocator.dupe(u8, "payload");
    const key = try allocator.dupe(u8, "tenant");
    const value = try allocator.dupe(u8, "contoso");
    const offset = try allocator.dupe(u8, "9001");

    var properties = [_]MapEntry{.{ .key = .{ .string = key }, .value = .{ .string = value } }};
    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = offset_annotation }, .value = .{ .string = offset } },
    };

    var decoded = try fromRawMessage(allocator, .{
        .body = body,
        .message_annotations = &annotations,
        .application_properties = &properties,
    });
    defer decoded.deinit(allocator);

    allocator.free(body);
    allocator.free(key);
    allocator.free(value);
    allocator.free(offset);

    try std.testing.expectEqualStrings("payload", decoded.body());
    try std.testing.expectEqualStrings("9001", decoded.offset.?);
    try std.testing.expectEqualStrings("contoso", decoded.properties().getString("tenant").?);
}

test "releasing a decoded event's EventData frees only the property map" {
    const allocator = std.testing.allocator;

    var properties = [_]MapEntry{
        .{ .key = .{ .string = "tenant" }, .value = .{ .string = "contoso" } },
    };
    var decoded = try fromRawMessage(allocator, .{
        .body = "payload",
        .application_properties = &properties,
    });
    defer decoded.deinit(allocator);

    // `event_data` is a public field and `EventData.deinit` a public method,
    // so this call is reachable and used to be the correct way to release
    // just the property map. Now that the keys and values are interior
    // pointers into `backing`, it has to free the map's own storage and
    // nothing else, or it hands the allocator memory it never issued.
    decoded.event_data.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), decoded.properties().count());
    // The block is untouched, and releasing the event still works.
    try std.testing.expectEqualStrings("payload", decoded.body());
}

test "a borrowed property map survives being released twice" {
    const allocator = std.testing.allocator;

    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = "x-opt-vendor" }, .value = .{ .string = "v" } },
    };
    var properties = [_]MapEntry{.{ .key = .{ .string = "k" }, .value = .{ .string = "v" } }};

    var decoded = try fromRawMessage(allocator, .{
        .body = "b",
        .message_annotations = &annotations,
        .application_properties = &properties,
    });

    decoded.event_data.properties.deinit(allocator);
    decoded.system_properties.deinit(allocator);
    decoded.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), decoded.system_properties.count());
}

test "the property accessors alias the event's maps rather than copying them" {
    const allocator = std.testing.allocator;

    var annotations = [_]MapEntry{
        .{ .key = .{ .symbol = "x-opt-vendor" }, .value = .{ .string = "v" } },
    };
    var properties = [_]MapEntry{.{ .key = .{ .string = "k" }, .value = .{ .string = "v" } }};
    var decoded = try fromRawMessage(allocator, .{
        .body = "b",
        .message_annotations = &annotations,
        .application_properties = &properties,
    });
    defer decoded.deinit(allocator);

    const props = decoded.properties();
    const system = decoded.systemProperties();
    try std.testing.expectEqual(@as(usize, 1), props.count());
    try std.testing.expectEqual(@as(usize, 1), system.count());

    // Release both maps through the event. Each accessor result has to observe
    // that, which is only true if it aliases the field. An accessor returning
    // `PropertyMap` by value would hand back a copy that still reported one
    // entry and still pointed at the storage just freed - and whose own
    // `deinit` would free it a second time. That is the double free these
    // signatures exist to prevent, so the staleness is what this asserts.
    decoded.event_data.deinit(allocator);
    decoded.system_properties.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), props.count());
    try std.testing.expectEqual(@as(usize, 0), system.count());
    // The backing block is untouched by either release.
    try std.testing.expectEqualStrings("b", decoded.body());
}

test "a repeated application property key keeps the last value" {
    const allocator = std.testing.allocator;

    var properties = [_]MapEntry{
        .{ .key = .{ .string = "k" }, .value = .{ .string = "first" } },
        .{ .key = .{ .string = "k" }, .value = .{ .string = "second" } },
    };

    var decoded = try fromRawMessage(allocator, .{
        .body = "b",
        .application_properties = &properties,
    });
    defer decoded.deinit(allocator);

    // The block is sized for both, so the superseded copy is simply left in
    // it. Reserving for both is also what keeps the map from growing.
    try std.testing.expectEqual(@as(usize, 1), decoded.properties().count());
    try std.testing.expectEqualStrings("second", decoded.properties().getString("k").?);
}

test "deinit leaves an event that can be deinitialised again" {
    const allocator = std.testing.allocator;

    var properties = [_]MapEntry{.{ .key = .{ .string = "k" }, .value = .{ .string = "v" } }};
    var decoded = try fromRawMessage(allocator, .{
        .body = "b",
        .application_properties = &properties,
    });

    decoded.deinit(allocator);
    // A second release of the same event must not free anything a second
    // time. `testing.allocator` is the assertion.
    decoded.deinit(allocator);

    try std.testing.expectEqualStrings("", decoded.body());
    try std.testing.expectEqual(@as(usize, 0), decoded.properties().count());
}

/// Counts the allocations a decode makes, which is the property under test in
/// `"a decoded event is one block plus its property maps"`.
const CountingAllocator = struct {
    parent: std.mem.Allocator,
    allocations: usize = 0,

    fn init(parent: std.mem.Allocator) CountingAllocator {
        return .{ .parent = parent };
    }

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        } };
    }

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.allocations += 1;
        return self.parent.rawAlloc(len, alignment, ra);
    }

    fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(buf, alignment, new_len, ra);
    }

    fn remap(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawRemap(buf, alignment, new_len, ra);
    }

    fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(buf, alignment, ra);
    }
};
