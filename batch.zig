//! Packing events into a single Event Hubs batch transfer.

const std = @import("std");
const event_data = @import("event_data.zig");

const EventData = event_data.EventData;

/// AMQP message format identifying an Event Hubs batch transfer.
pub const batch_message_format: u32 = 0x80013700;

/// Size assumed before a sender link negotiates `max-message-size`. Event Hubs
/// standard tiers allow 1 MiB.
pub const default_max_message_size: usize = 1024 * 1024;

pub const BatchError = error{
    /// A batch targets either a partition or a partition key, never both.
    PartitionKeyAndIdBothSet,
    /// The event cannot fit an empty batch, so no batch size would accept it.
    EventDataTooLarge,
    /// The requested `max_bytes` is above what the sender link negotiated.
    MaxBytesExceedsLinkLimit,
    /// The link limit can only be adopted before events are added.
    BatchNotEmpty,
};

pub const EventDataBatchOptions = struct {
    /// Upper bound on the encoded batch size. Defaults to the sender link's
    /// negotiated maximum, or `default_max_message_size` until one exists.
    max_bytes: ?usize = null,
    /// Route related events to one partition by hash. Mutually exclusive with
    /// `partition_id`.
    partition_key: ?[]const u8 = null,
    /// Send to an explicit partition. Mutually exclusive with `partition_key`.
    partition_id: ?[]const u8 = null,
};

/// Packs events into a single AMQP batch transfer.
///
/// Events are encoded as they are added and the batch tracks the real byte
/// count, so a batch that reports as fitting actually fits. Go and Rust both
/// work this way; estimating from body length under-counts properties,
/// annotations, and per-message framing.
pub const EventDataBatch = struct {
    /// Fully encoded sub-messages, each of which becomes one data section of
    /// the batch transfer.
    marshaled: std.ArrayList([]u8) = .empty,
    /// Encoded non-body sections of the first event, which become the batch
    /// envelope. Go reuses the first message this way.
    envelope: ?[]u8 = null,
    max_size_bytes: usize = default_max_message_size,
    current_size: usize = 0,
    partition_key: ?[]const u8 = null,
    partition_id: ?[]const u8 = null,
    /// Set when the caller pinned `max_bytes`, so a link cannot raise it.
    requested_max_bytes: ?usize = null,

    pub fn init(options: EventDataBatchOptions) BatchError!EventDataBatch {
        if (options.partition_key != null and options.partition_id != null) {
            return BatchError.PartitionKeyAndIdBothSet;
        }
        return .{
            .max_size_bytes = options.max_bytes orelse default_max_message_size,
            .partition_key = options.partition_key,
            .partition_id = options.partition_id,
            .requested_max_bytes = options.max_bytes,
        };
    }

    pub fn deinit(self: *EventDataBatch, allocator: std.mem.Allocator) void {
        for (self.marshaled.items) |encoded| allocator.free(encoded);
        self.marshaled.deinit(allocator);
        if (self.envelope) |envelope| allocator.free(envelope);
        self.envelope = null;
        self.current_size = 0;
    }

    /// Adopt the `max-message-size` a sender link negotiated.
    ///
    /// An explicitly requested `max_bytes` is kept when it is smaller and
    /// rejected when it exceeds what the link allows, matching Go.
    pub fn applyLinkMaxMessageSize(
        self: *EventDataBatch,
        link_max_bytes: usize,
    ) BatchError!void {
        if (self.marshaled.items.len > 0) return BatchError.BatchNotEmpty;
        if (self.requested_max_bytes) |requested| {
            if (requested > link_max_bytes) return BatchError.MaxBytesExceedsLinkLimit;
            return;
        }
        self.max_size_bytes = link_max_bytes;
    }

    /// Encode `event` and add it if the batch still has room.
    ///
    /// Returns `false` when the event does not fit alongside what is already
    /// batched, and `BatchError.EventDataTooLarge` when it would not fit even
    /// an empty batch.
    pub fn tryAdd(self: *EventDataBatch, allocator: std.mem.Allocator, event: EventData) !bool {
        var message = try event.toAmqpMessage(allocator);
        defer event_data.freeAmqpMessage(allocator, &message);

        if (self.partition_key) |partition_key| {
            try event_data.setPartitionKeyAnnotation(allocator, &message, partition_key);
        }

        // Both buffers are discarded unless the event is actually adopted,
        // which includes the `false` return when it simply does not fit.
        var adopted = false;

        const encoded = try event_data.encodeMessage(allocator, &message);
        defer if (!adopted) allocator.free(encoded);

        // The first event also fixes the envelope, so its cost is charged here.
        const is_first = self.marshaled.items.len == 0;
        const envelope: ?[]u8 = if (is_first)
            try event_data.encodeMessageEnvelope(allocator, &message)
        else
            null;
        defer if (!adopted) {
            if (envelope) |bytes| allocator.free(bytes);
        };

        const envelope_size = if (envelope) |bytes| bytes.len else 0;
        const projected = self.current_size + envelope_size + dataSectionSize(encoded.len);
        if (projected > self.max_size_bytes) {
            if (is_first) return BatchError.EventDataTooLarge;
            return false;
        }

        try self.marshaled.append(allocator, encoded);
        if (envelope) |bytes| self.envelope = bytes;
        self.current_size = projected;
        adopted = true;
        return true;
    }

    pub fn count(self: EventDataBatch) usize {
        return self.marshaled.items.len;
    }

    /// Encoded size of the batch as it would go on the wire.
    pub fn sizeInBytes(self: EventDataBatch) usize {
        return self.current_size;
    }
};

/// Wrapping a payload in a data section costs a described-type constructor, the
/// descriptor, and a binary length prefix. Go's `calcActualSizeForPayload`
/// uses the same constants.
fn dataSectionSize(payload_len: usize) usize {
    const vbin8_overhead = 5;
    const vbin32_overhead = 8;
    return if (payload_len < 256) vbin8_overhead + payload_len else vbin32_overhead + payload_len;
}
