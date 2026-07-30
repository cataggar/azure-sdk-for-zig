//! The Service Bus `$management` operations.
//!
//! Scheduling, cancellation, lock renewal and peeking are not link operations
//! at all: they are request/response calls to a well-known address, carried by
//! the same `RpcLink` pair `$cbs` uses. What is specific to Service Bus is the
//! shape — an `operation` property naming a `com.microsoft:` verb, and an
//! `amqp-value` body holding a map.
//!
//! Everything here is a function over values, with no link and no session, so
//! the wire format can be tested against what the broker expects without a
//! broker being involved. `amqp_transport.zig` owns the link and the calls.
//!
//! `azure_sdk_amqp` has a `Management` client already, but it is shaped for
//! Event Hubs: it puts `type` and `name` properties on every request, which
//! Service Bus neither sends nor expects. This talks to `RpcLink` directly.

const std = @import("std");
const Allocator = std.mem.Allocator;

const amqp = @import("azure_sdk_amqp");

const AmqpValue = amqp.AmqpValue;
const MapEntry = amqp.MapEntry;

/// The `operation` property's value, which is what selects the verb.
pub const operation = struct {
    pub const schedule_message = "com.microsoft:schedule-message";
    pub const cancel_scheduled_message = "com.microsoft:cancel-scheduled-message";
    pub const renew_lock = "com.microsoft:renew-lock";
    pub const peek_message = "com.microsoft:peek-message";
};

/// Application-property keys on a management request.
pub const property = struct {
    pub const operation = "operation";
    /// How long the broker may take, in milliseconds. Distinct from the
    /// client's own deadline, which also has to cover the round trip.
    pub const server_timeout = "com.microsoft:server-timeout";
    /// The entity link this request belongs with — the sender for scheduling,
    /// the receiver for renewal and peeking. It is how the broker ties a
    /// management call to the link whose lock or session it concerns.
    pub const associated_link_name = "associated-link-name";
};

/// Keys inside the request and reply body maps.
pub const body_key = struct {
    pub const messages = "messages";
    pub const message = "message";
    pub const message_id = "message-id";
    pub const partition_key = "partition-key";
    pub const session_id = "session-id";
    pub const sequence_numbers = "sequence-numbers";
    pub const lock_tokens = "lock-tokens";
    pub const expirations = "expirations";
    pub const from_sequence_number = "from-sequence-number";
    pub const message_count = "message-count";
};

pub const Error = error{
    /// A reply arrived without the field the operation is defined to return.
    MalformedReply,
    /// The delivery tag was not the 16 bytes a lock token is.
    InvalidLockToken,
};

/// A lock token, as the broker wants it on the wire.
pub const LockToken = [16]u8;

/// Read a lock token out of the delivery tag the message arrived with.
///
/// Service Bus puts the token in the delivery tag as a .NET `Guid` — that is,
/// with the first three fields little-endian, which is what `Guid.ToByteArray`
/// produces. An AMQP `uuid` is RFC 4122, so those three fields have to be
/// reversed on the way out. Getting this wrong does not fail loudly: the
/// broker simply does not recognise the token and the renewal is refused.
pub fn lockTokenFromDeliveryTag(tag: []const u8) Error!LockToken {
    if (tag.len != 16) return error.InvalidLockToken;
    var token: LockToken = undefined;
    token[0] = tag[3];
    token[1] = tag[2];
    token[2] = tag[1];
    token[3] = tag[0];
    token[4] = tag[5];
    token[5] = tag[4];
    token[6] = tag[7];
    token[7] = tag[6];
    @memcpy(token[8..16], tag[8..16]);
    return token;
}

/// One message being scheduled, already encoded.
pub const Scheduled = struct {
    /// The broker keys the scheduled entry by this, and returns a sequence
    /// number the caller cancels by.
    message_id: ?[]const u8,
    /// The whole encoded message — every section, not just the body — since
    /// the broker stores it verbatim and delivers it later.
    encoded: []const u8,
    partition_key: ?[]const u8 = null,
    session_id: ?[]const u8 = null,
};

/// Build the `amqp-value` body of a `schedule-message` request.
///
/// `a` should be an arena: the body is a tree of maps and lists that is
/// discarded as soon as the request has been written.
pub fn scheduleBody(a: Allocator, messages: []const Scheduled) !AmqpValue {
    const entries = try a.alloc(AmqpValue, messages.len);
    for (messages, entries) |scheduled, *slot| {
        var fields: std.ArrayList(MapEntry) = .empty;
        // `message-id` first, matching the order the other SDKs write, so a
        // capture from this client and one from theirs compare byte for byte.
        if (scheduled.message_id) |id| {
            try fields.append(a, .{
                .key = .{ .string = body_key.message_id },
                .value = .{ .string = id },
            });
        }
        try fields.append(a, .{
            .key = .{ .string = body_key.message },
            .value = .{ .binary = scheduled.encoded },
        });
        if (scheduled.partition_key) |key| {
            try fields.append(a, .{
                .key = .{ .string = body_key.partition_key },
                .value = .{ .string = key },
            });
        }
        if (scheduled.session_id) |id| {
            try fields.append(a, .{
                .key = .{ .string = body_key.session_id },
                .value = .{ .string = id },
            });
        }
        slot.* = .{ .map = fields.items };
    }

    // A list rather than an array: the entries are maps of differing shape,
    // and an AMQP array requires one constructor for every element.
    const outer = try a.alloc(MapEntry, 1);
    outer[0] = .{
        .key = .{ .string = body_key.messages },
        .value = .{ .list = entries },
    };
    return .{ .map = outer };
}

/// Build the body of a `cancel-scheduled-message` request.
pub fn cancelBody(a: Allocator, sequence_numbers: []const i64) !AmqpValue {
    const items = try a.alloc(AmqpValue, sequence_numbers.len);
    for (sequence_numbers, items) |number, *slot| slot.* = .{ .long = number };

    const outer = try a.alloc(MapEntry, 1);
    outer[0] = .{
        .key = .{ .string = body_key.sequence_numbers },
        // An array, not a list: every element is a long, and the broker
        // decodes it as a typed array.
        .value = .{ .array = items },
    };
    return .{ .map = outer };
}

/// Build the body of a `renew-lock` request.
pub fn renewLockBody(a: Allocator, tokens: []const LockToken) !AmqpValue {
    const items = try a.alloc(AmqpValue, tokens.len);
    for (tokens, items) |token, *slot| slot.* = .{ .uuid = token };

    const outer = try a.alloc(MapEntry, 1);
    outer[0] = .{
        .key = .{ .string = body_key.lock_tokens },
        .value = .{ .array = items },
    };
    return .{ .map = outer };
}

/// Build the body of a `peek-message` request.
pub fn peekBody(a: Allocator, from_sequence_number: i64, max_count: u32) !AmqpValue {
    const outer = try a.alloc(MapEntry, 2);
    outer[0] = .{
        .key = .{ .string = body_key.from_sequence_number },
        .value = .{ .long = from_sequence_number },
    };
    outer[1] = .{
        .key = .{ .string = body_key.message_count },
        // An `int`, not a long: the broker reads a 32-bit count here.
        .value = .{ .int = @intCast(max_count) },
    };
    return .{ .map = outer };
}

/// The value stored under `key` in an `amqp-value` map body, if the body is a
/// map and the key is in it.
///
/// A reply with no body at all is not an error here — a peek that found
/// nothing answers 204 with nothing in it — so this reports absence rather
/// than failing, and each caller decides whether absence is allowed.
pub fn bodyField(body: amqp.message_codec.Body, key: []const u8) ?AmqpValue {
    const value = switch (body) {
        .value => |v| v,
        else => return null,
    };
    const entries = switch (value) {
        .map => |m| m,
        else => return null,
    };
    for (entries) |entry| {
        const name = switch (entry.key) {
            .string, .symbol => |s| s,
            else => continue,
        };
        if (std.mem.eql(u8, name, key)) return entry.value;
    }
    return null;
}

/// The elements of a value that is either an array or a list.
///
/// The two are the same thing to a reader, and brokers have been observed to
/// use either, so refusing one of them would be a distinction without a
/// difference.
fn elementsOf(value: AmqpValue) ?[]const AmqpValue {
    return switch (value) {
        .array, .list => |items| items,
        else => null,
    };
}

/// Read the `sequence-numbers` a `schedule-message` reply returns.
///
/// Writes into `out` and returns how many were written, so the common case of
/// scheduling a handful of messages needs no allocation. Extra numbers beyond
/// `out.len` are dropped: the caller asked for that many and the broker
/// answers one per message.
pub fn readSequenceNumbers(body: amqp.message_codec.Body, out: []i64) Error!usize {
    const field = bodyField(body, body_key.sequence_numbers) orelse return error.MalformedReply;
    const items = elementsOf(field) orelse return error.MalformedReply;
    var n: usize = 0;
    for (items) |item| {
        if (n == out.len) break;
        out[n] = switch (item) {
            .long => |v| v,
            .int => |v| v,
            else => return error.MalformedReply,
        };
        n += 1;
    }
    return n;
}

/// Read the `expirations` a `renew-lock` reply returns, as milliseconds since
/// the Unix epoch.
pub fn readExpirations(body: amqp.message_codec.Body, out: []i64) Error!usize {
    const field = bodyField(body, body_key.expirations) orelse return error.MalformedReply;
    const items = elementsOf(field) orelse return error.MalformedReply;
    var n: usize = 0;
    for (items) |item| {
        if (n == out.len) break;
        out[n] = switch (item) {
            .timestamp => |v| v,
            .long => |v| v,
            else => return error.MalformedReply,
        };
        n += 1;
    }
    return n;
}

/// The encoded messages a `peek-message` reply carries, in order.
///
/// The slices point into the reply, so they live only as long as it does.
/// A reply with no body is an empty peek rather than a malformed one.
pub fn readPeekedMessages(a: Allocator, body: amqp.message_codec.Body) ![]const []const u8 {
    const field = bodyField(body, body_key.messages) orelse return &.{};
    const items = elementsOf(field) orelse return error.MalformedReply;

    const out = try a.alloc([]const u8, items.len);
    for (items, out) |item, *slot| {
        const fields = switch (item) {
            .map => |m| m,
            else => return error.MalformedReply,
        };
        slot.* = blk: {
            for (fields) |entry| {
                const name = switch (entry.key) {
                    .string, .symbol => |s| s,
                    else => continue,
                };
                if (!std.mem.eql(u8, name, body_key.message)) continue;
                break :blk switch (entry.value) {
                    .binary => |b| b,
                    else => return error.MalformedReply,
                };
            }
            return error.MalformedReply;
        };
    }
    return out;
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;

test "a lock token reverses the three little-endian fields of the delivery tag" {
    // The tag as .NET's `Guid.ToByteArray` writes it, and the same GUID in
    // RFC 4122 order. Spelled out rather than derived, because deriving one
    // from the other with the code under test would assert nothing.
    const tag = [16]u8{
        0x78, 0x56, 0x34, 0x12,
        0xbc, 0x9a, 0xf0, 0xde,
        0x01, 0x23, 0x45, 0x67,
        0x89, 0xab, 0xcd, 0xef,
    };
    const token = try lockTokenFromDeliveryTag(&tag);
    try testing.expectEqualSlices(u8, &.{
        0x12, 0x34, 0x56, 0x78,
        0x9a, 0xbc, 0xde, 0xf0,
        0x01, 0x23, 0x45, 0x67,
        0x89, 0xab, 0xcd, 0xef,
    }, &token);
}

test "a delivery tag that is not sixteen bytes is not a lock token" {
    // Service Bus always sends sixteen, but an emulator or a message that
    // arrived by some other route may not, and a short read here would be a
    // buffer overrun rather than a refusal.
    try testing.expectError(error.InvalidLockToken, lockTokenFromDeliveryTag("short"));
    try testing.expectError(error.InvalidLockToken, lockTokenFromDeliveryTag(&[_]u8{0} ** 17));
}

test "the schedule body carries every message whole, under the keys the broker reads" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const body = try scheduleBody(a, &.{
        .{ .message_id = "id-1", .encoded = "ENCODED-1", .partition_key = "pk" },
        .{ .message_id = null, .encoded = "ENCODED-2", .session_id = "s" },
    });

    const messages = bodyField(.{ .value = body }, "messages").?;
    const list = messages.list;
    try testing.expectEqual(@as(usize, 2), list.len);

    // First: id, message, partition key — and no session id, which was not set.
    const first = list[0].map;
    try testing.expectEqual(@as(usize, 3), first.len);
    try testing.expectEqualStrings("message-id", first[0].key.string);
    try testing.expectEqualStrings("id-1", first[0].value.string);
    try testing.expectEqualStrings("message", first[1].key.string);
    try testing.expectEqualStrings("ENCODED-1", first[1].value.binary);
    try testing.expectEqualStrings("partition-key", first[2].key.string);

    // Second: no id at all rather than a null one, and a session id.
    const second = list[1].map;
    try testing.expectEqual(@as(usize, 2), second.len);
    try testing.expectEqualStrings("message", second[0].key.string);
    try testing.expectEqualStrings("session-id", second[1].key.string);
    try testing.expectEqualStrings("s", second[1].value.string);
}

test "the message is binary, not a string" {
    // An encoded message is arbitrary bytes and routinely contains a zero or
    // an invalid UTF-8 sequence. Sent as a string it would either be rejected
    // or silently truncated at the first zero byte.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const body = try scheduleBody(a, &.{
        .{ .message_id = null, .encoded = &[_]u8{ 0x00, 0x53, 0x00, 0xff } },
    });
    const list = bodyField(.{ .value = body }, "messages").?.list;
    try testing.expect(list[0].map[0].value == .binary);
}

test "sequence numbers and lock tokens go out as typed arrays, not lists" {
    // The broker decodes these as arrays of a single constructor. A list of
    // the same values encodes each element with its own type byte, which is
    // valid AMQP and the wrong shape.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const cancel = try cancelBody(a, &.{ 7, 8 });
    const numbers = bodyField(.{ .value = cancel }, "sequence-numbers").?;
    try testing.expect(numbers == .array);
    try testing.expectEqual(@as(i64, 7), numbers.array[0].long);

    const renew = try renewLockBody(a, &.{ [_]u8{1} ** 16, [_]u8{2} ** 16 });
    const tokens = bodyField(.{ .value = renew }, "lock-tokens").?;
    try testing.expect(tokens == .array);
    try testing.expect(tokens.array[0] == .uuid);
    try testing.expectEqualSlices(u8, &[_]u8{2} ** 16, &tokens.array[1].uuid);
}

test "a peek asks by sequence number as a long and by count as an int" {
    // Not interchangeable: the count is a 32-bit field and the sequence
    // number a 64-bit one, and a broker reading a long where it wants an int
    // rejects the request rather than coercing.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const body = try peekBody(a, 9_000_000_000, 12);
    try testing.expectEqual(
        @as(i64, 9_000_000_000),
        bodyField(.{ .value = body }, "from-sequence-number").?.long,
    );
    try testing.expectEqual(
        @as(i32, 12),
        bodyField(.{ .value = body }, "message-count").?.int,
    );
}

test "a reply's numbers are read whether the broker sent an array or a list" {
    var items = [_]AmqpValue{ .{ .long = 11 }, .{ .long = 12 } };
    var out: [4]i64 = undefined;

    var as_array = [_]MapEntry{.{
        .key = .{ .string = "sequence-numbers" },
        .value = .{ .array = &items },
    }};
    try testing.expectEqual(
        @as(usize, 2),
        try readSequenceNumbers(.{ .value = .{ .map = &as_array } }, &out),
    );
    try testing.expectEqual(@as(i64, 11), out[0]);

    var as_list = [_]MapEntry{.{
        .key = .{ .string = "sequence-numbers" },
        .value = .{ .list = &items },
    }};
    try testing.expectEqual(
        @as(usize, 2),
        try readSequenceNumbers(.{ .value = .{ .map = &as_list } }, &out),
    );
}

test "a reply missing the field its operation is defined to return is malformed" {
    var out: [4]i64 = undefined;
    var wrong = [_]MapEntry{.{
        .key = .{ .string = "something-else" },
        .value = .{ .long = 1 },
    }};
    try testing.expectError(
        error.MalformedReply,
        readSequenceNumbers(.{ .value = .{ .map = &wrong } }, &out),
    );
    // An empty body is the same failure for these two: the broker answered
    // 200 and then said nothing, which is not an answer.
    try testing.expectError(error.MalformedReply, readSequenceNumbers(.empty, &out));
    try testing.expectError(error.MalformedReply, readExpirations(.empty, &out));
}

test "more numbers than were asked for are dropped rather than overrunning" {
    var items = [_]AmqpValue{ .{ .long = 1 }, .{ .long = 2 }, .{ .long = 3 } };
    var entries = [_]MapEntry{.{
        .key = .{ .string = "expirations" },
        .value = .{ .array = &items },
    }};
    var out: [2]i64 = undefined;
    try testing.expectEqual(
        @as(usize, 2),
        try readExpirations(.{ .value = .{ .map = &entries } }, &out),
    );
    try testing.expectEqual(@as(i64, 2), out[1]);
}

test "an expiration is read whether it arrives as a timestamp or a long" {
    // The type is `timestamp` on the wire, but both are milliseconds since
    // the epoch and an emulator that writes a long means the same thing.
    var out: [1]i64 = undefined;
    var stamped = [_]MapEntry{.{
        .key = .{ .string = "expirations" },
        .value = .{ .array = @constCast(&[_]AmqpValue{.{ .timestamp = 1_700_000_000_000 }}) },
    }};
    _ = try readExpirations(.{ .value = .{ .map = &stamped } }, &out);
    try testing.expectEqual(@as(i64, 1_700_000_000_000), out[0]);

    var plain = [_]MapEntry{.{
        .key = .{ .string = "expirations" },
        .value = .{ .array = @constCast(&[_]AmqpValue{.{ .long = 42 }}) },
    }};
    _ = try readExpirations(.{ .value = .{ .map = &plain } }, &out);
    try testing.expectEqual(@as(i64, 42), out[0]);
}

test "a peek that found nothing is an empty result, not a malformed reply" {
    // The broker answers 204 with no body at all. Treating that as malformed
    // would turn "the queue is empty" — the steady state — into an error.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const none = try readPeekedMessages(arena.allocator(), .empty);
    try testing.expectEqual(@as(usize, 0), none.len);
}

test "peeked messages come back in the order the broker listed them" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var first = [_]MapEntry{.{ .key = .{ .string = "message" }, .value = .{ .binary = "A" } }};
    var second = [_]MapEntry{.{ .key = .{ .string = "message" }, .value = .{ .binary = "B" } }};
    var items = [_]AmqpValue{ .{ .map = &first }, .{ .map = &second } };
    var entries = [_]MapEntry{.{
        .key = .{ .string = "messages" },
        .value = .{ .list = &items },
    }};

    const messages = try readPeekedMessages(a, .{ .value = .{ .map = &entries } });
    try testing.expectEqual(@as(usize, 2), messages.len);
    try testing.expectEqualStrings("A", messages[0]);
    try testing.expectEqualStrings("B", messages[1]);
}

test "a peeked entry with no message in it is malformed rather than skipped" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var empty = [_]MapEntry{.{ .key = .{ .string = "other" }, .value = .{ .long = 1 } }};
    var items = [_]AmqpValue{.{ .map = &empty }};
    var entries = [_]MapEntry{.{
        .key = .{ .string = "messages" },
        .value = .{ .list = &items },
    }};
    try testing.expectError(
        error.MalformedReply,
        readPeekedMessages(arena.allocator(), .{ .value = .{ .map = &entries } }),
    );
}

test "a body field is found whether its key was sent as a string or a symbol" {
    var symbolic = [_]MapEntry{.{
        .key = .{ .symbol = "sequence-numbers" },
        .value = .{ .array = @constCast(&[_]AmqpValue{.{ .long = 5 }}) },
    }};
    var out: [1]i64 = undefined;
    _ = try readSequenceNumbers(.{ .value = .{ .map = &symbolic } }, &out);
    try testing.expectEqual(@as(i64, 5), out[0]);
}
