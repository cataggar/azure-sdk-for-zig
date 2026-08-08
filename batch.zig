//! Packing events into a single Event Hubs batch transfer.

const std = @import("std");
const uamqp = @import("uamqp");
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
    /// Every encoded sub-message, concatenated. Each becomes one data section
    /// of the batch transfer. Held as one buffer rather than a slice per event
    /// so that adding an event allocates nothing once the blob has capacity.
    ///
    /// Slices into this are invalidated by any later `tryAdd`, so `payloadAt`
    /// results must not be held across one.
    blob: std.ArrayList(u8) = .empty,
    /// End offset in `blob` of each encoded sub-message.
    ends: std.ArrayList(usize) = .empty,
    /// Reused across events so encoding one does not allocate. Once this has
    /// grown to fit the largest event seen, every later event encodes into the
    /// capacity already there.
    scratch: uamqp.encoder.Buffer = .{
        .data = &.{},
        .pos = 0,
        .allocator = null,
        .is_fixed = false,
    },
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
        self.blob.deinit(allocator);
        self.ends.deinit(allocator);
        self.scratch.deinit();
        self.scratch = .{ .data = &.{}, .pos = 0, .allocator = null, .is_fixed = false };
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
        if (self.ends.items.len > 0) return BatchError.BatchNotEmpty;
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
        var borrowed: event_data.BorrowedMessage = undefined;
        try borrowed.init(allocator, event, self.partition_key);
        defer borrowed.deinit();
        const message = &borrowed.message;

        // Encoded into the reused scratch buffer rather than a fresh one, then
        // copied into `blob` only once the event is known to fit. Nothing is
        // committed before that check, so a rejected event needs no rollback.
        self.scratch.allocator = allocator;
        self.scratch.reset();
        try event_data.encodeMessageIntoBuffer(&self.scratch, message);
        const encoded = self.scratch.written();

        var adopted = false;

        // The first event also fixes the envelope, so its cost is charged here.
        const is_first = self.ends.items.len == 0;
        const envelope: ?[]u8 = if (is_first)
            try event_data.encodeMessageEnvelope(allocator, message)
        else
            null;
        defer if (!adopted) {
            if (envelope) |bytes| allocator.free(bytes);
        };

        const envelope_size = if (envelope) |bytes| bytes.len else 0;
        const projected = self.current_size + envelope_size + dataSectionSize(encoded.len);
        if (projected > self.max_size_bytes) {
            self.releaseOversizedScratch();
            if (is_first) return BatchError.EventDataTooLarge;
            return false;
        }

        // Both reservations happen before either container is mutated, so a
        // failure to grow one cannot leave the batch holding half an event.
        try self.blob.ensureUnusedCapacity(allocator, encoded.len);
        try self.ends.ensureUnusedCapacity(allocator, 1);
        self.blob.appendSliceAssumeCapacity(encoded);
        self.ends.appendAssumeCapacity(self.blob.items.len);

        if (envelope) |bytes| self.envelope = bytes;
        self.current_size = projected;
        adopted = true;
        return true;
    }

    /// Release `scratch` when a refused event grew it past anything the batch
    /// could ever accept.
    ///
    /// Reusing the buffer is what makes encoding free, but it also means the
    /// buffer keeps the high-water mark of every event *offered*, not every
    /// event adopted. The path this replaced allocated and freed each event's
    /// encoding immediately, so refusing a 10 MiB event cost nothing after the
    /// refusal; here it would park 10 MiB on the batch until `deinit`. An
    /// accepted event has to fit in `max_size_bytes` by definition, so
    /// anything above that is capacity no future event can use.
    fn releaseOversizedScratch(self: *EventDataBatch) void {
        if (self.scratch.data.len <= self.max_size_bytes) return;
        self.scratch.deinit();
        self.scratch = .{ .data = &.{}, .pos = 0, .allocator = null, .is_fixed = false };
    }

    pub fn count(self: EventDataBatch) usize {
        return self.ends.items.len;
    }

    /// The encoded bytes of event `index`.
    ///
    /// Invalidated by any later `tryAdd`, which may move `blob`.
    pub fn payloadAt(self: EventDataBatch, index: usize) []const u8 {
        const start = if (index == 0) 0 else self.ends.items[index - 1];
        return self.blob.items[start..self.ends.items[index]];
    }

    /// Encoded size of the batch as it would go on the wire.
    pub fn sizeInBytes(self: EventDataBatch) usize {
        return self.current_size;
    }
};

/// Shared with the encoder rather than restated here, so a batch cannot report
/// as fitting and then encode to something larger because only one of the two
/// was changed.
const dataSectionSize = event_data.dataSectionSize;
