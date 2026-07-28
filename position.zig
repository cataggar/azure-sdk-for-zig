//! Where a consumer starts reading a partition.
//!
//! Lives apart from the module root so the receiver can use it without
//! importing the root back.

const std = @import("std");

/// Where in a partition a consumer starts reading.
///
/// Rust models this as a `StartLocation` enum and Go as a set of optional
/// fields that it rejects when more than one is set. A tagged union makes the
/// conflict unrepresentable.
pub const StartLocation = union(enum) {
    /// The oldest event the partition still retains.
    earliest,
    /// Only events enqueued after the consumer attaches. This is the default
    /// in Go and Rust alike.
    latest,
    /// An opaque offset token, which is not necessarily numeric.
    offset: []const u8,
    sequence_number: i64,
    /// Unix milliseconds.
    enqueued_time: i64,
};

/// Starting position for reading events from a partition.
///
/// Slices are borrowed and must outlive the position.
pub const EventPosition = struct {
    location: StartLocation = .latest,
    /// Include the event at `location` rather than starting after it. Ignored
    /// for `earliest` and `latest`, which have no event to include.
    is_inclusive: bool = false,

    /// Start from the beginning of the partition.
    pub fn earliest() EventPosition {
        return .{ .location = .earliest };
    }

    /// Start from the end of the partition (new events only).
    pub fn latest() EventPosition {
        return .{ .location = .latest };
    }

    /// Start from a specific offset.
    pub fn fromOffset(offset: []const u8, inclusive: bool) EventPosition {
        return .{ .location = .{ .offset = offset }, .is_inclusive = inclusive };
    }

    /// Start from a specific sequence number.
    pub fn fromSequenceNumber(seq: i64, inclusive: bool) EventPosition {
        return .{ .location = .{ .sequence_number = seq }, .is_inclusive = inclusive };
    }

    /// Start from a specific enqueued time (Unix ms).
    pub fn fromEnqueuedTime(time: i64) EventPosition {
        return .{ .location = .{ .enqueued_time = time } };
    }

    /// Render the AMQP filter expression for this position.
    ///
    /// A default-constructed position renders as `@latest` rather than
    /// failing, matching Go's `getStartExpression` and Rust's
    /// `StartPosition::start_expression`.
    pub fn toFilterExpression(self: EventPosition, allocator: std.mem.Allocator) ![]u8 {
        const op: []const u8 = if (self.is_inclusive) ">=" else ">";
        return switch (self.location) {
            // Go and Rust both emit `>` for these two regardless of
            // inclusivity, because `-1` and `@latest` are sentinels that
            // already sit outside the event range.
            .earliest => allocator.dupe(u8, "amqp.annotation.x-opt-offset > '-1'"),
            .latest => allocator.dupe(u8, "amqp.annotation.x-opt-offset > '@latest'"),
            .offset => |offset| std.fmt.allocPrint(
                allocator,
                "amqp.annotation.x-opt-offset {s} '{s}'",
                .{ op, offset },
            ),
            .sequence_number => |seq| std.fmt.allocPrint(
                allocator,
                "amqp.annotation.x-opt-sequence-number {s} '{d}'",
                .{ op, seq },
            ),
            .enqueued_time => |time| std.fmt.allocPrint(
                allocator,
                "amqp.annotation.x-opt-enqueued-time {s} '{d}'",
                .{ op, time },
            ),
        };
    }
};

/// Per-partition starting positions, used when a partition has no checkpoint.
///
/// Partition ids are copied; every other slice is borrowed.
pub const StartPositions = struct {
    per_partition: std.StringArrayHashMapUnmanaged(EventPosition) = .empty,
    /// Used for any partition absent from `per_partition`.
    default: EventPosition = .{},

    pub fn deinit(self: *StartPositions, allocator: std.mem.Allocator) void {
        for (self.per_partition.keys()) |key| allocator.free(key);
        self.per_partition.deinit(allocator);
    }

    pub fn put(
        self: *StartPositions,
        allocator: std.mem.Allocator,
        partition_id: []const u8,
        position: EventPosition,
    ) !void {
        const owned_id = try allocator.dupe(u8, partition_id);
        errdefer allocator.free(owned_id);

        const gop = try self.per_partition.getOrPut(allocator, owned_id);
        if (gop.found_existing) allocator.free(owned_id);
        gop.value_ptr.* = position;
    }

    /// Resolve the position for a partition, falling back to `default`.
    pub fn forPartition(self: StartPositions, partition_id: []const u8) EventPosition {
        return self.per_partition.get(partition_id) orelse self.default;
    }
};
