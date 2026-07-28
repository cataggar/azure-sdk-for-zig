//! Event Hubs error classification and the retry schedule built on top of it.
//!
//! The classification tables mirror Go's `internal/errors.go`, and the backoff
//! schedule mirrors Go's `internal/utils/retrier.go`, so a Zig client backs off
//! on the same wire conditions and at the same rate as the other Azure SDKs.

const std = @import("std");

/// AMQP error conditions the service is known to return.
///
/// The `amqp:` conditions are from AMQP 1.0 §2.8.15; the `com.microsoft:`
/// conditions are Event Hubs extensions.
pub const condition = struct {
    pub const internal_error = "amqp:internal-error";
    pub const not_found = "amqp:not-found";
    pub const not_allowed = "amqp:not-allowed";
    pub const unauthorized_access = "amqp:unauthorized-access";
    pub const resource_limit_exceeded = "amqp:resource-limit-exceeded";
    pub const connection_forced = "amqp:connection:forced";
    pub const detach_forced = "amqp:link:detach-forced";
    pub const transfer_limit_exceeded = "amqp:link:transfer-limit-exceeded";
    pub const message_size_exceeded = "amqp:link:message-size-exceeded";
    /// Sent when another consumer attaches with an equal or higher owner level,
    /// which detaches this one.
    pub const link_stolen = "amqp:link:stolen";

    pub const server_busy = "com.microsoft:server-busy";
    pub const timeout = "com.microsoft:timeout";
    pub const operation_cancelled = "com.microsoft:operation-cancelled";
    pub const entity_disabled = "com.microsoft:entity-disabled";
    pub const session_cannot_be_locked = "com.microsoft:session-cannot-be-locked";
    /// Returned for, among other things, a partition id that does not exist.
    pub const argument_out_of_range = "com.microsoft:argument-out-of-range";
    pub const message_lock_lost = "com.microsoft:message-lock-lost";
    /// Returned when an integer offset is used against a geo-replicated hub.
    pub const georeplication_invalid_offset = "com.microsoft:georeplication:invalid-offset";
};

/// Stable, programmatically inspectable error codes.
///
/// The set matches Go's `exported.ErrorCode` plus `send_rejected`, which Go
/// reports through a separate type but Rust models as
/// `ErrorKind::SendRejected`.
pub const ErrorCode = enum {
    /// The credentials are not valid for this entity, or have expired.
    unauthorized_access,
    /// The connection was lost and every retry attempt failed.
    connection_lost,
    /// Another consumer attached to this partition with an equal or higher
    /// owner level. When using a processor, this is expected during rebalance.
    ownership_lost,
    /// The broker rejected a published message.
    send_rejected,

    /// The wire spelling, which is what Go surfaces to users and what appears
    /// in log output across the SDKs.
    pub fn wireName(self: ErrorCode) []const u8 {
        return switch (self) {
            .unauthorized_access => "unauthorized",
            .connection_lost => "connlost",
            .ownership_lost => "ownershiplost",
            .send_rejected => "sendrejected",
        };
    }
};

/// How much of the AMQP stack has to be rebuilt to recover from a failure.
///
/// Mirrors Go's `RecoveryKind`. Recovery itself is not implemented here; this
/// only classifies.
pub const RecoveryKind = enum {
    /// Transient. Retry the operation as-is.
    none,
    /// The link must be reattached.
    link,
    /// The whole connection must be rebuilt.
    connection,
    /// Unrecoverable. Never retry.
    fatal,
};

const Classification = struct {
    condition: []const u8,
    kind: RecoveryKind,
};

const classifications = [_]Classification{
    // Transient service conditions; the operation can simply be retried.
    .{ .condition = condition.server_busy, .kind = .none },
    .{ .condition = condition.timeout, .kind = .none },
    .{ .condition = condition.operation_cancelled, .kind = .none },

    .{ .condition = condition.detach_forced, .kind = .link },
    .{ .condition = condition.transfer_limit_exceeded, .kind = .link },

    .{ .condition = condition.connection_forced, .kind = .connection },
    .{ .condition = condition.internal_error, .kind = .connection },

    // Retrying any of these would fail identically every time.
    .{ .condition = condition.resource_limit_exceeded, .kind = .fatal },
    .{ .condition = condition.message_size_exceeded, .kind = .fatal },
    .{ .condition = condition.unauthorized_access, .kind = .fatal },
    .{ .condition = condition.not_found, .kind = .fatal },
    .{ .condition = condition.not_allowed, .kind = .fatal },
    .{ .condition = condition.entity_disabled, .kind = .fatal },
    .{ .condition = condition.session_cannot_be_locked, .kind = .fatal },
    .{ .condition = condition.argument_out_of_range, .kind = .fatal },
    .{ .condition = condition.message_lock_lost, .kind = .fatal },
    .{ .condition = condition.georeplication_invalid_offset, .kind = .fatal },
    // Ownership is gone; a caller that retried would just steal it back from
    // whoever legitimately holds it now.
    .{ .condition = condition.link_stolen, .kind = .fatal },
};

/// Classify an AMQP error condition.
///
/// An unrecognised condition rebuilds the connection, matching the final
/// fallthrough of Go's `GetRecoveryKind`: an error nobody has seen before is
/// assumed to have left the connection in an unknown state.
pub fn recoveryKindForCondition(amqp_condition: []const u8) RecoveryKind {
    for (classifications) |entry| {
        if (std.mem.eql(u8, entry.condition, amqp_condition)) return entry.kind;
    }
    return .connection;
}

/// Map an AMQP error condition to a public error code, if it has one.
///
/// Ordering matters and follows Go's `TransformError`: ownership loss is
/// checked before anything else, then bad credentials, and only then does the
/// recovery kind decide.
pub fn errorCodeForCondition(amqp_condition: []const u8) ?ErrorCode {
    if (std.mem.eql(u8, amqp_condition, condition.link_stolen)) return .ownership_lost;
    if (std.mem.eql(u8, amqp_condition, condition.unauthorized_access)) return .unauthorized_access;
    return switch (recoveryKindForCondition(amqp_condition)) {
        .link, .connection => .connection_lost,
        .none, .fatal => null,
    };
}

/// An Event Hubs failure with a stable code and the AMQP detail behind it.
///
/// Slices are borrowed from the AMQP error they were read out of and must
/// outlive the value.
pub const EventHubsError = struct {
    code: ErrorCode,
    /// The AMQP error condition, when the failure came from the broker.
    amqp_condition: ?[]const u8 = null,
    /// The broker's human-readable description. Not part of the stable API.
    description: ?[]const u8 = null,

    /// Build an error from a broker-supplied condition, or null when the
    /// condition has no stable code (transient conditions such as
    /// `com.microsoft:server-busy`, which the caller should retry rather than
    /// surface).
    pub fn fromCondition(amqp_condition: []const u8, description: ?[]const u8) ?EventHubsError {
        const code = errorCodeForCondition(amqp_condition) orelse return null;
        return .{ .code = code, .amqp_condition = amqp_condition, .description = description };
    }

    /// Whether this failure can never succeed on retry.
    pub fn isFatal(self: EventHubsError) bool {
        if (self.amqp_condition) |c| return recoveryKindForCondition(c) == .fatal;
        return self.code == .unauthorized_access or self.code == .ownership_lost;
    }

    pub fn format(self: EventHubsError, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("({s})", .{self.code.wireName()});
        if (self.amqp_condition) |c| try writer.print(" {s}", .{c});
        if (self.description) |d| try writer.print(": {s}", .{d});
    }
};

/// Retry schedule configuration.
///
/// The defaults are Go's: 3 retries, a 4s base delay, and a 120s cap. Rust uses
/// a much shorter schedule (200ms base, 8 retries), but Go's is the one the
/// service documents.
///
/// Unlike Go these fields are unsigned, so zero means zero rather than
/// "unset"; Go only treats zero as unset because it has no way to distinguish
/// an unset struct field from an explicit zero.
pub const RetryOptions = struct {
    /// Retries after the initial attempt. Zero means a single try.
    max_retries: u32 = 3,
    /// Base delay, doubled on each retry before jitter and capping.
    retry_delay_ns: u64 = 4 * std.time.ns_per_s,
    /// Upper bound on any single delay. Use `std.math.maxInt(u64)` for no cap.
    max_retry_delay_ns: u64 = 120 * std.time.ns_per_s,

    /// Delay before retry number `attempt`, which is 1-based.
    ///
    /// The schedule is `((1 << attempt) - 1) * retry_delay`, jittered and then
    /// capped, matching Go's `calcDelay`. `jitter` is expected in [0.8, 1.3);
    /// see `jitterMultiplier`.
    pub fn delayFor(self: RetryOptions, attempt: u32, jitter: f64) u64 {
        std.debug.assert(attempt >= 1);

        const factor: u64 = if (attempt < 63)
            (@as(u64, 1) << @intCast(attempt)) - 1
        else
            std.math.maxInt(u64);

        const delay = std.math.mul(u64, factor, self.retry_delay_ns) catch std.math.maxInt(u64);

        const jittered_float = @as(f64, @floatFromInt(delay)) * jitter;
        const jittered: u64 = if (jittered_float >= @as(f64, @floatFromInt(std.math.maxInt(u64))))
            std.math.maxInt(u64)
        else
            @intFromFloat(jittered_float);

        return @min(jittered, self.max_retry_delay_ns);
    }
};

/// Go's jitter: a uniform multiplier in [0.8, 1.3), which spreads a thundering
/// herd of reconnecting clients over half a delay period.
pub fn jitterMultiplier(random: std.Random) f64 {
    return random.float(f64) / 2 + 0.8;
}

/// Cancellation, which is not retryable: the caller asked to stop.
pub const SleepError = error{Canceled};

/// Sleeps between retry attempts. Injected so tests can run the schedule
/// without spending the wall-clock time it describes.
pub const Sleeper = struct {
    sleepFn: *const fn (self: *Sleeper, delay_ns: u64) SleepError!void,

    pub fn sleep(self: *Sleeper, delay_ns: u64) SleepError!void {
        return self.sleepFn(self, delay_ns);
    }
};

/// A `Sleeper` backed by an `std.Io` implementation.
///
/// Sleeping went through `std.Io` in Zig 0.16, so the caller has to supply the
/// same `Io` the rest of its work runs on for cancellation to reach the
/// backoff.
pub const IoSleeper = struct {
    io: std.Io,
    sleeper: Sleeper = .{ .sleepFn = doSleep },

    pub fn init(io: std.Io) IoSleeper {
        return .{ .io = io };
    }

    fn doSleep(sleeper: *Sleeper, delay_ns: u64) SleepError!void {
        const self: *IoSleeper = @fieldParentPtr("sleeper", sleeper);
        // Backoff is a duration, not a deadline, so it must not shift when the
        // wall clock is stepped by NTP or an administrator.
        return self.io.sleep(.{ .nanoseconds = delay_ns }, .awake);
    }
};

/// State handed to each attempt of a retried operation.
pub const Attempt = struct {
    /// Zero-based attempt number. Zero is the initial try.
    index: u32 = 0,
    /// The error the previous attempt returned, if this is a retry.
    last_error: ?anyerror = null,
    /// Set by the operation when its failure carried an AMQP error condition,
    /// so the retrier can classify it. Cleared before every attempt.
    condition: ?[]const u8 = null,
    /// Set by the operation to describe its failure. Cleared before every
    /// attempt.
    description: ?[]const u8 = null,
    reset_requested: bool = false,

    /// Return the retry budget to full and take the next attempt without
    /// backing off.
    ///
    /// Used after recovering a link or connection, where the recovery itself
    /// consumed real time and the retry that follows is effectively a first
    /// try. Mirrors Go's `RetryFnArgs.ResetAttempts`.
    pub fn resetAttempts(self: *Attempt) void {
        self.reset_requested = true;
    }
};

pub const RetryConfig = struct {
    options: RetryOptions = .{},
    sleeper: *Sleeper,
    random: std.Random,
};

/// The result of a retried operation.
pub fn Outcome(comptime Result: type) type {
    return union(enum) {
        ok: Result,
        failed: struct {
            /// The error the last attempt returned.
            err: anyerror,
            /// The classified failure, for programmatic inspection.
            info: EventHubsError,
            /// Attempts made, including the initial try.
            attempts: u32,
        },
    };
}

/// Run `op.call(&attempt)` until it succeeds, fails fatally, or runs out of
/// retries.
///
/// `op` is a pointer to a struct with a
/// `fn call(self: @TypeOf(op), attempt: *Attempt) anyerror!Result` method. An
/// operation that fails with an AMQP condition should set `attempt.condition`
/// before returning, otherwise the failure is treated as an unknown error and
/// classified as connection-recoverable, exactly as Go does.
pub fn retry(comptime Result: type, op: anytype, config: RetryConfig) Outcome(Result) {
    var attempt = Attempt{};
    var index: u32 = 0;
    var attempts: u32 = 0;
    var last_error: anyerror = error.RetryBudgetExhausted;
    var last_info = EventHubsError{ .code = .connection_lost };

    // The increment wraps, which is how a reset gets back to index 0 without
    // re-running the loop head. Go does the same thing with a signed -1.
    while (index <= config.options.max_retries) : (index +%= 1) {
        if (index > 0) {
            const delay = config.options.delayFor(index, jitterMultiplier(config.random));
            config.sleeper.sleep(delay) catch |sleep_err| {
                // A cancelled backoff is not a retryable failure.
                return .{ .failed = .{ .err = sleep_err, .info = last_info, .attempts = attempts } };
            };
        }

        attempt.index = index;
        attempt.condition = null;
        attempt.description = null;
        attempt.reset_requested = false;
        attempts += 1;

        const result = op.call(&attempt);

        if (attempt.reset_requested) {
            // The wrapping increment turns this back into 0, so the next
            // attempt runs immediately and with the budget restored.
            index = std.math.maxInt(u32);
        }

        const err = if (result) |value| {
            return .{ .ok = value };
        } else |e| e;

        last_error = err;
        attempt.last_error = err;

        if (attempt.condition) |c| {
            last_info = .{
                .code = errorCodeForCondition(c) orelse .connection_lost,
                .amqp_condition = c,
                .description = attempt.description,
            };
            if (recoveryKindForCondition(c) == .fatal) {
                return .{ .failed = .{ .err = err, .info = last_info, .attempts = attempts } };
            }
        } else {
            last_info = .{ .code = .connection_lost, .description = attempt.description };
        }
    }

    // The budget is spent, so whatever the last failure was, the caller can no
    // longer reach the service. Go reports this as `connlost`.
    return .{ .failed = .{
        .err = last_error,
        .info = .{
            .code = .connection_lost,
            .amqp_condition = last_info.amqp_condition,
            .description = last_info.description,
        },
        .attempts = attempts,
    } };
}

test "conditions classify into Go's recovery buckets" {
    try std.testing.expectEqual(RecoveryKind.none, recoveryKindForCondition(condition.server_busy));
    try std.testing.expectEqual(RecoveryKind.none, recoveryKindForCondition(condition.timeout));
    try std.testing.expectEqual(RecoveryKind.link, recoveryKindForCondition(condition.detach_forced));
    try std.testing.expectEqual(
        RecoveryKind.link,
        recoveryKindForCondition(condition.transfer_limit_exceeded),
    );
    try std.testing.expectEqual(
        RecoveryKind.connection,
        recoveryKindForCondition(condition.connection_forced),
    );
    try std.testing.expectEqual(
        RecoveryKind.connection,
        recoveryKindForCondition(condition.internal_error),
    );
}

test "the fatal set matches Go's" {
    const fatal = [_][]const u8{
        condition.resource_limit_exceeded,
        condition.message_size_exceeded,
        condition.unauthorized_access,
        condition.not_found,
        condition.not_allowed,
        condition.entity_disabled,
        condition.session_cannot_be_locked,
        condition.argument_out_of_range,
        condition.message_lock_lost,
        condition.georeplication_invalid_offset,
    };
    for (fatal) |c| {
        try std.testing.expectEqual(RecoveryKind.fatal, recoveryKindForCondition(c));
    }
}

test "an unknown condition rebuilds the connection" {
    try std.testing.expectEqual(
        RecoveryKind.connection,
        recoveryKindForCondition("com.example:never-seen-before"),
    );
    try std.testing.expectEqual(
        ErrorCode.connection_lost,
        errorCodeForCondition("com.example:never-seen-before").?,
    );
}

test "link stolen is ownership lost and fatal" {
    try std.testing.expectEqual(RecoveryKind.fatal, recoveryKindForCondition(condition.link_stolen));
    try std.testing.expectEqual(ErrorCode.ownership_lost, errorCodeForCondition(condition.link_stolen).?);

    const err = EventHubsError.fromCondition(condition.link_stolen, "higher epoch attached").?;
    try std.testing.expectEqual(ErrorCode.ownership_lost, err.code);
    try std.testing.expect(err.isFatal());
    try std.testing.expectEqualStrings("ownershiplost", err.code.wireName());
}

test "unauthorized access maps to its own code" {
    const err = EventHubsError.fromCondition(condition.unauthorized_access, null).?;
    try std.testing.expectEqual(ErrorCode.unauthorized_access, err.code);
    try std.testing.expect(err.isFatal());
    try std.testing.expectEqualStrings("unauthorized", err.code.wireName());
}

test "transient conditions have no public error code" {
    try std.testing.expectEqual(@as(?ErrorCode, null), errorCodeForCondition(condition.server_busy));
    try std.testing.expectEqual(@as(?EventHubsError, null), EventHubsError.fromCondition(
        condition.operation_cancelled,
        null,
    ));
}

test "fatal conditions without a dedicated code have none" {
    try std.testing.expectEqual(@as(?ErrorCode, null), errorCodeForCondition(condition.not_found));
    try std.testing.expectEqual(RecoveryKind.fatal, recoveryKindForCondition(condition.not_found));
}

test "EventHubsError formats like Go's Error()" {
    var buffer: [256]u8 = undefined;
    const rendered = try std.fmt.bufPrint(&buffer, "{f}", .{EventHubsError{
        .code = .ownership_lost,
        .amqp_condition = condition.link_stolen,
        .description = "New receiver with higher epoch",
    }});
    try std.testing.expectEqualStrings(
        "(ownershiplost) amqp:link:stolen: New receiver with higher epoch",
        rendered,
    );
}

test "the backoff schedule matches Go's calcDelay" {
    const options = RetryOptions{};
    try std.testing.expectEqual(@as(u64, 3), options.max_retries);
    try std.testing.expectEqual(@as(u64, 4 * std.time.ns_per_s), options.retry_delay_ns);
    try std.testing.expectEqual(@as(u64, 120 * std.time.ns_per_s), options.max_retry_delay_ns);

    // ((1 << n) - 1) * 4s, with jitter pinned to 1.0.
    try std.testing.expectEqual(@as(u64, 4 * std.time.ns_per_s), options.delayFor(1, 1.0));
    try std.testing.expectEqual(@as(u64, 12 * std.time.ns_per_s), options.delayFor(2, 1.0));
    try std.testing.expectEqual(@as(u64, 28 * std.time.ns_per_s), options.delayFor(3, 1.0));
    try std.testing.expectEqual(@as(u64, 60 * std.time.ns_per_s), options.delayFor(4, 1.0));

    // The cap holds from the attempt where the raw delay would exceed it.
    try std.testing.expectEqual(@as(u64, 120 * std.time.ns_per_s), options.delayFor(5, 1.0));
    try std.testing.expectEqual(@as(u64, 120 * std.time.ns_per_s), options.delayFor(40, 1.0));
}

test "jitter scales the delay and stays capped" {
    const options = RetryOptions{};
    try std.testing.expectEqual(
        @as(u64, @intFromFloat(4.0 * @as(f64, std.time.ns_per_s) * 0.8)),
        options.delayFor(1, 0.8),
    );
    try std.testing.expectEqual(
        @as(u64, @intFromFloat(12.0 * @as(f64, std.time.ns_per_s) * 1.25)),
        options.delayFor(2, 1.25),
    );
    // 28s * 1.29 is over 36s, still under the 120s cap.
    try std.testing.expect(options.delayFor(3, 1.29) < options.max_retry_delay_ns);
}

test "an enormous attempt number saturates instead of overflowing" {
    const options = RetryOptions{ .max_retry_delay_ns = std.math.maxInt(u64) };
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64)), options.delayFor(63, 1.0));
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64)), options.delayFor(64, 1.0));
}

test "jitterMultiplier stays within Go's range" {
    var prng = std.Random.DefaultPrng.init(0x5eed);
    const random = prng.random();
    for (0..1000) |_| {
        const jitter = jitterMultiplier(random);
        try std.testing.expect(jitter >= 0.8);
        try std.testing.expect(jitter < 1.3);
    }
}

const RecordingSleeper = struct {
    sleeper: Sleeper = .{ .sleepFn = record },
    delays: std.ArrayList(u64) = .empty,
    allocator: std.mem.Allocator,

    fn record(sleeper: *Sleeper, delay_ns: u64) SleepError!void {
        const self: *RecordingSleeper = @fieldParentPtr("sleeper", sleeper);
        self.delays.append(self.allocator, delay_ns) catch @panic("out of memory");
    }

    fn deinit(self: *RecordingSleeper) void {
        self.delays.deinit(self.allocator);
    }
};

/// A jitter source pinned to 1.0, so a test observes the unjittered schedule.
const FixedRandom = struct {
    fn fill(context: *anyopaque, buffer: []u8) void {
        _ = context;
        // random.float(f64) builds its mantissa from these bytes, so all-zero
        // yields 0.0 and a multiplier of exactly 0.8, the low end of Go's
        // jitter range.
        @memset(buffer, 0);
    }

    fn random() std.Random {
        return .{ .ptr = undefined, .fillFn = fill };
    }
};

const FailingOp = struct {
    condition: ?[]const u8,
    calls: u32 = 0,
    succeed_on: ?u32 = null,

    fn call(self: *FailingOp, attempt: *Attempt) anyerror!u32 {
        self.calls += 1;
        if (self.succeed_on) |target| {
            if (attempt.index == target) return attempt.index;
        }
        attempt.condition = self.condition;
        attempt.description = "synthetic failure";
        return error.Synthetic;
    }
};

test "retry follows the full delay schedule before giving up" {
    var sleeper = RecordingSleeper{ .allocator = std.testing.allocator };
    defer sleeper.deinit();

    var op = FailingOp{ .condition = condition.server_busy };
    const outcome = retry(u32, &op, .{
        .sleeper = &sleeper.sleeper,
        .random = FixedRandom.random(),
    });

    // Three retries after the initial try, so three sleeps at 0.8 jitter.
    try std.testing.expectEqual(@as(u32, 4), op.calls);
    try std.testing.expectEqual(@as(usize, 3), sleeper.delays.items.len);
    const options = RetryOptions{};
    try std.testing.expectEqual(options.delayFor(1, 0.8), sleeper.delays.items[0]);
    try std.testing.expectEqual(options.delayFor(2, 0.8), sleeper.delays.items[1]);
    try std.testing.expectEqual(options.delayFor(3, 0.8), sleeper.delays.items[2]);

    try std.testing.expectEqual(@as(u32, 4), outcome.failed.attempts);
    try std.testing.expectEqual(error.Synthetic, outcome.failed.err);
    // A spent budget means the service is unreachable, whatever the condition.
    try std.testing.expectEqual(ErrorCode.connection_lost, outcome.failed.info.code);
    try std.testing.expectEqualStrings(condition.server_busy, outcome.failed.info.amqp_condition.?);
}

test "a fatal condition returns immediately without consuming retries" {
    var sleeper = RecordingSleeper{ .allocator = std.testing.allocator };
    defer sleeper.deinit();

    var op = FailingOp{ .condition = condition.unauthorized_access };
    const outcome = retry(u32, &op, .{
        .sleeper = &sleeper.sleeper,
        .random = FixedRandom.random(),
    });

    try std.testing.expectEqual(@as(u32, 1), op.calls);
    try std.testing.expectEqual(@as(usize, 0), sleeper.delays.items.len);
    try std.testing.expectEqual(ErrorCode.unauthorized_access, outcome.failed.info.code);
    try std.testing.expectEqualStrings("synthetic failure", outcome.failed.info.description.?);
}

test "ownership loss is not retried" {
    var sleeper = RecordingSleeper{ .allocator = std.testing.allocator };
    defer sleeper.deinit();

    var op = FailingOp{ .condition = condition.link_stolen };
    const outcome = retry(u32, &op, .{
        .sleeper = &sleeper.sleeper,
        .random = FixedRandom.random(),
    });

    try std.testing.expectEqual(@as(u32, 1), op.calls);
    try std.testing.expectEqual(ErrorCode.ownership_lost, outcome.failed.info.code);
}

test "a late success stops the retry loop" {
    var sleeper = RecordingSleeper{ .allocator = std.testing.allocator };
    defer sleeper.deinit();

    var op = FailingOp{ .condition = condition.detach_forced, .succeed_on = 2 };
    const outcome = retry(u32, &op, .{
        .sleeper = &sleeper.sleeper,
        .random = FixedRandom.random(),
    });

    try std.testing.expectEqual(@as(u32, 3), op.calls);
    try std.testing.expectEqual(@as(usize, 2), sleeper.delays.items.len);
    try std.testing.expectEqual(@as(u32, 2), outcome.ok);
}

test "a failure with no condition is treated as connection loss" {
    var sleeper = RecordingSleeper{ .allocator = std.testing.allocator };
    defer sleeper.deinit();

    var op = FailingOp{ .condition = null };
    const outcome = retry(u32, &op, .{
        .sleeper = &sleeper.sleeper,
        .random = FixedRandom.random(),
    });

    try std.testing.expectEqual(@as(u32, 4), op.calls);
    try std.testing.expectEqual(ErrorCode.connection_lost, outcome.failed.info.code);
    try std.testing.expectEqual(@as(?[]const u8, null), outcome.failed.info.amqp_condition);
}

test "zero retries means a single attempt" {
    var sleeper = RecordingSleeper{ .allocator = std.testing.allocator };
    defer sleeper.deinit();

    var op = FailingOp{ .condition = condition.server_busy };
    const outcome = retry(u32, &op, .{
        .options = .{ .max_retries = 0 },
        .sleeper = &sleeper.sleeper,
        .random = FixedRandom.random(),
    });

    try std.testing.expectEqual(@as(u32, 1), op.calls);
    try std.testing.expectEqual(@as(usize, 0), sleeper.delays.items.len);
    try std.testing.expectEqual(@as(u32, 1), outcome.failed.attempts);
}

test "resetAttempts restores the budget and skips the backoff" {
    const ResettingOp = struct {
        calls: u32 = 0,
        resets: u32 = 0,

        fn call(self: *@This(), attempt: *Attempt) anyerror!u32 {
            self.calls += 1;
            // Recover the link once, which should hand back a full budget and
            // an immediate retry.
            if (self.resets == 0 and attempt.index == 1) {
                self.resets += 1;
                attempt.resetAttempts();
            }
            if (self.calls >= 6) return self.calls;
            attempt.condition = condition.server_busy;
            return error.Synthetic;
        }
    };

    var sleeper = RecordingSleeper{ .allocator = std.testing.allocator };
    defer sleeper.deinit();

    var op = ResettingOp{};
    const outcome = retry(u32, &op, .{
        .sleeper = &sleeper.sleeper,
        .random = FixedRandom.random(),
    });

    // Attempts run at index 0, 1 (reset), then 0, 1, 2, 3. Only the four
    // non-zero indices sleep, so the reset bought two extra attempts.
    try std.testing.expectEqual(@as(u32, 6), op.calls);
    try std.testing.expectEqual(@as(usize, 4), sleeper.delays.items.len);
    try std.testing.expectEqual(@as(u32, 6), outcome.ok);
}

test "a cancelled backoff aborts the retry loop" {
    const CancellingSleeper = struct {
        sleeper: Sleeper = .{ .sleepFn = cancel },
        calls: u32 = 0,

        fn cancel(sleeper: *Sleeper, delay_ns: u64) SleepError!void {
            _ = delay_ns;
            const self: *@This() = @fieldParentPtr("sleeper", sleeper);
            self.calls += 1;
            return error.Canceled;
        }
    };

    var sleeper = CancellingSleeper{};
    var op = FailingOp{ .condition = condition.server_busy };
    const outcome = retry(u32, &op, .{
        .sleeper = &sleeper.sleeper,
        .random = FixedRandom.random(),
    });

    try std.testing.expectEqual(@as(u32, 1), op.calls);
    try std.testing.expectEqual(@as(u32, 1), sleeper.calls);
    try std.testing.expectEqual(error.Canceled, outcome.failed.err);
}
