//! Offline benchmarks for the Service Bus encode, decode and receive paths.
//!
//! Nothing here touches the network. Every benchmark measures pure CPU and
//! allocation cost, so a result is reproducible and a regression is
//! attributable to a specific code change rather than to service latency.
//!
//! Run with:
//!   zig build bench -Doptimize=ReleaseFast
//!
//! Allocation counts are the primary signal. Wall-clock numbers on a shared or
//! virtualised host move between runs; `allocs/op` and `B/op` do not, so treat
//! those as the regression gate and the timings as advisory.
//!
//! Everything is driven through the package's public API, so these measure
//! what a consumer actually pays.

const std = @import("std");
const builtin = @import("builtin");
const core = @import("azure_sdk_core");
const sb = @import("azure_sdk_servicebus");
const amqp = @import("azure_sdk_amqp");

const perf = core.perf;

var runtime_io: std.Io = undefined;
var unused_http_context: u8 = 0;

const unused_http_vtable: core.http.HttpTransport.VTable = .{
    .send = struct {
        fn send(_: *anyopaque, _: *core.http.Request) !core.http.Response {
            return error.UnexpectedHttpRequest;
        }
    }.send,
};

/// Representative Service Bus payload: a small JSON order.
const small_body = "{\"order\":\"SO-4821\",\"total\":19.95,\"currency\":\"USD\"}";

fn makeMessage(allocator: std.mem.Allocator) sb.ServiceBusMessage {
    var msg = sb.ServiceBusMessage.init(allocator, small_body);
    msg.content_type = "application/json";
    msg.message_id = "SO-4821";
    msg.session_id = "customer-77";
    msg.correlation_id = "batch-9";
    return msg;
}

// ─────────────────── Encode ───────────────────

/// The `Scratch` a send loop keeps across messages, as `sendMessages` does
/// with `&self.scratch`. Hoisting it here is not a convenience: it is the
/// arrangement under test, and the two `toAmqpMessage` cases below are only
/// meaningful because this outlives them.
var send_scratch: sb.message_codec.Scratch = undefined;

/// A message carrying application properties, built once. Filling the
/// `StringHashMap` allocates, and doing it inside a measured function charges
/// that to the codec — which is a fixture cost, not a cost a sender pays per
/// message.
var message_with_properties: sb.ServiceBusMessage = undefined;

/// What a send loop pays per message with the `Scratch` hoisted out of it,
/// which is the arrangement `sendMessages` uses. A message with no
/// application properties never touches the scratch buffer at all, so this
/// reads zero — but so would a version that rebuilt the scratch per call,
/// because `Scratch.init` is lazy. The case below is the one that tells them
/// apart.
fn benchToAmqpMessage(allocator: std.mem.Allocator) !void {
    var msg = makeMessage(allocator);
    defer msg.deinit();

    const amqp_msg = try sb.toAmqpMessage(msg, &send_scratch);
    std.mem.doNotOptimizeAway(&amqp_msg);
}

/// The same conversion for a message that *does* carry application
/// properties. This is the discriminating case: the property array is the one
/// thing `Scratch` allocates, and a hoisted scratch grows to the largest count
/// seen and is never shrunk, so it is paid once for the whole loop rather than
/// once per message. Zero here is a real claim about `sendMessages`; rebuild
/// the scratch per call instead and it reads one.
fn benchToAmqpMessageWithProperties(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const amqp_msg = try sb.toAmqpMessage(message_with_properties, &send_scratch);
    std.mem.doNotOptimizeAway(&amqp_msg);
}

/// The same message all the way to the bytes of one transfer.
///
/// Most of this is the dependency: `amqp.encodeMessageAlloc` fills a growing
/// buffer and then dupes it to size, so the count tracks how many times that
/// buffer doubles on the way to the final length rather than anything this
/// package does.
fn benchEncodeMessage(allocator: std.mem.Allocator) !void {
    var msg = makeMessage(allocator);
    defer msg.deinit();

    const bytes = try sb.encodeMessage(allocator, msg);
    allocator.free(bytes);
}

/// `encodeMessage` is the convenience entry point, and unlike `sendMessages`
/// it builds a fresh `Scratch` per call and drops it. So the property array is
/// paid on every op here — there is no amortisation to be had, which is
/// exactly why the send path does not use this function.
///
/// The gap to `encodeMessage` is that array plus one more turn of the encode
/// buffer's growth, the properties having made the payload longer.
fn benchEncodeWithProperties(allocator: std.mem.Allocator) !void {
    const bytes = try sb.encodeMessage(allocator, message_with_properties);
    allocator.free(bytes);
}

// ─────────────────── Decode ───────────────────

/// Receive-side conversion. The AMQP message is decoded once and borrowed, so
/// this measures only what a consumer pays turning it into a Service Bus
/// message.
///
/// Its `0.00 allocs/op` is not a measurement and must not be read as one:
/// `fromAmqpMessage` takes no allocator, so the counting allocator cannot
/// reach it and no other answer is representable. The guard against a copy
/// creeping in is the signature, and it is `zig build test` compiling this
/// file that enforces it. The timing is the only number here worth reading.
var decoded_message: amqp.Message = undefined;

fn benchFromAmqpMessage(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const received = sb.fromAmqpMessage(decoded_message);
    std.mem.doNotOptimizeAway(&received);
}

// ─────────────────── Management ───────────────────

/// Building a batched schedule request: one arena holding a map, a list, and
/// one entry map per message. This is what `scheduleMessages` pays on top of
/// encoding the messages themselves.
fn benchScheduleBody(allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var entries: [100]sb.management.Scheduled = undefined;
    for (&entries) |*slot| {
        slot.* = .{
            .message_id = "SO-4821",
            .encoded = small_body,
            .partition_key = null,
            .session_id = "customer-77",
        };
    }

    const body = try sb.management.scheduleBody(a, &entries);
    std.mem.doNotOptimizeAway(&body);
}

/// Reading a peek reply: walking the returned list and pulling the encoded
/// message out of each entry. The decode of those bytes is what
/// `peekMessages` does next, and is measured by the receive cases below.
var peek_reply: amqp.AmqpValue = undefined;

fn benchReadPeekedMessages(allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const encoded = try sb.management.readPeekedMessages(
        arena.allocator(),
        .{ .value = peek_reply },
    );
    std.mem.doNotOptimizeAway(&encoded);
}

// ─────────────────── Receive over a scripted peer ───────────────────
//
// Everything above measures one message in isolation. This measures the loop:
// frames off the transport, deliveries reassembled, messages decoded, Service
// Bus messages converted, the batch arena filled. That is where a receiver
// actually spends its time, and where the batching and buffering work in this
// package either pays off or does not — none of it is visible one message at
// a time.
//
// The peer is a byte script built once, so an iteration pays a memcpy for it
// rather than re-encoding a thousand transfers into the measurement.
//
// The two cases share a byte-identical handshake, CBS exchange and attach, and
// differ only in how many transfers follow. Subtract them, divide by 999, and
// what is left is one received message with the setup cancelled out.
//
// Each case gets a script holding exactly the transfers it consumes, and that
// is load-bearing rather than tidy. `AmqpTransport.deinit` closes the receiver,
// and `Receiver.detach` pumps until the peer detaches; a scripted peer never
// does, so the loop drains whatever is still buffered — decoding and duping
// every transfer nobody asked for. Hand the x1 case a thousand-transfer script
// and its teardown quietly decodes about ninety of them, which does not cancel
// because it *shrinks* as the count grows. Measured, that reported 1.81
// allocations per message where the truth is 2.00.
//
// What is left uncancelled is handing the peer its script: ~180 KB copied into
// a 270 KB buffer for x1000 against 540 bytes for x1. That is one allocation in
// either case, so the allocation subtraction is exact — but it is nowhere near
// free in time, because a freshly mapped 270 KB region is faulted in a page at
// a time as the copy touches it, which costs far more than the copy. The
// `script fixture` case below measures it, so the reader can subtract it rather
// than trust a number written here; on this machine it is ~88 us, about seven
// percent of what x1000 spends. Subtract it before dividing if the timing
// matters as much as the allocation count.

const bench_entity = "orders";
const bench_link_id = "servicebus";
const bench_receiver_name = bench_link_id ++ "-receiver-" ++ bench_entity;

/// Well past what these messages need, so the loop is not measuring frame
/// reassembly a real Service Bus connection would never do.
const bench_max_frame = 65_536;

const bench_options = amqp.DriverOptions{
    .container_id = "bench-container",
    .hostname = "ns.servicebus.windows.net",
    .sasl = .none,
    .max_frame_size = bench_max_frame,
    .idle_timeout_ms = 0,
};

/// Far enough out that the cached token never goes stale mid-benchmark, which
/// would put a second CBS round trip into one iteration and not the others.
const bench_token_expires_on: i64 = 4_102_444_800;

const BenchCredential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = get },

    fn get(
        c: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        ctx: core.context.Context,
        runtime: core.http.HttpRuntime,
    ) anyerror!core.credentials.AccessToken {
        _ = .{ c, request_context, ctx, runtime };
        return .{ .token = "bench-jwt", .expires_on = bench_token_expires_on };
    }
};

/// The peer's whole side of the conversation: handshake, the `$cbs` pair and
/// its put-token reply, the entity attach, and one transfer per message. The
/// two differ only in that trailing run of transfers.
var receive_script_one: []u8 = &.{};
var receive_script_many: []u8 = &.{};

fn buildReceiveScript(allocator: std.mem.Allocator, count: u32) ![]u8 {
    var scratch = amqp.MemoryTransport.init(allocator);
    defer scratch.deinit();

    const peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &scratch };
    try amqp.test_peer.scriptHandshake(peer, bench_max_frame);

    // `Cbs.open` attaches sender then receiver, taking handles 0 and 1, so the
    // entity link is handle 2.
    try peer.push(0, .{ .attach = .{
        .name = "$cbs-sender-" ++ bench_link_id,
        .handle = 0,
        .role = .receiver,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .attach = .{
        .name = "$cbs-receiver-" ++ bench_link_id,
        .handle = 1,
        .role = .sender,
        .initial_delivery_count = 0,
    } });
    try peer.push(0, .{ .flow = .{
        .next_incoming_id = 0,
        .incoming_window = 1_000_000,
        .next_outgoing_id = 1,
        .outgoing_window = 1_000_000,
        .handle = 0,
        .delivery_count = 0,
        .link_credit = 10,
    } });
    try peer.push(0, .{ .disposition = .{
        .role = .receiver,
        .first = 0,
        .last = 0,
        .settled = true,
        .state = .accepted,
    } });

    const status = [_]amqp.MapEntry{
        .{ .key = .{ .string = "statusCode" }, .value = .{ .int = 202 } },
    };
    const reply = try amqp.encodeMessageAlloc(allocator, .{
        .properties = .{
            .correlation_id = .{ .string = "cbs-reply-to-" ++ bench_link_id ++ ":1" },
        },
        .application_properties = &status,
    });
    defer allocator.free(reply);
    try peer.pushTransfer(0, .{
        .handle = 1,
        .delivery_id = 0,
        .delivery_tag = "r",
        .message_format = 0,
        .settled = true,
        .more = false,
    }, reply);

    try peer.push(0, .{ .attach = .{
        .name = bench_receiver_name,
        .handle = 2,
        .role = .sender,
        .initial_delivery_count = 0,
    } });

    var annotations = [_]amqp.MapEntry{
        .{
            .key = .{ .symbol = sb.annotation.sequence_number },
            .value = .{ .long = 0 },
        },
        .{
            .key = .{ .symbol = sb.annotation.locked_until },
            .value = .{ .timestamp = 1_800_000_000_000 },
        },
    };
    const sections = [_][]const u8{small_body};

    var id: u32 = 0;
    while (id < count) : (id += 1) {
        annotations[0].value = .{ .long = @intCast(id) };
        const payload = try amqp.encodeMessageAlloc(allocator, .{
            .message_annotations = &annotations,
            .properties = .{ .content_type = "application/json" },
            .body = .{ .data = &sections },
        });
        defer allocator.free(payload);

        const tag = std.mem.asBytes(&id);
        try peer.pushTransfer(0, .{
            .handle = 2,
            // Delivery id 0 belongs to the put-token, so the messages start
            // at 1.
            .delivery_id = id + 1,
            .delivery_tag = tag,
            .message_format = 0,
            .settled = false,
            .more = false,
        }, payload);
    }

    return allocator.dupe(u8, scratch.inbound.items);
}

/// Receive every message `script` holds, through the public transport.
fn receiveScripted(allocator: std.mem.Allocator, script: []const u8, count: u32) !void {
    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    try mem.pushPeerBytes(script);

    var clock: amqp.ManualClock = .{};
    var driver = try amqp.Driver.init(
        allocator,
        mem.transport(),
        clock.clock(),
        bench_options,
    );
    defer driver.deinit();
    try driver.open(10_000);

    var session = try amqp.Session.begin(allocator, &driver, 0, .{
        .incoming_window = 1_000_000,
        .outgoing_window = 1_000_000,
    }, 10_000);
    defer session.deinit();

    var credential: BenchCredential = .{};
    var crypto_provider = core.crypto.StdCryptoProvider.init(runtime_io);
    const runtime = core.http.HttpRuntime.init(
        .{ .context = &unused_http_context, .vtable = &unused_http_vtable },
        crypto_provider.asProvider(),
    );
    var transport: sb.AmqpTransport = undefined;
    transport.init(.{
        .allocator = allocator,
        .runtime = runtime,
        .fully_qualified_namespace = bench_options.hostname.?,
        .credential = .{ .token = &credential.credential },
        // No prefetch window, so the link is granted exactly what is asked
        // for and the benchmark is not measuring a refill that a different
        // `count` would place differently.
        .connection = .{ .link_id = bench_link_id, .prefetch = 0 },
        .session = &session,
    });
    defer transport.deinit();

    var batch = try transport.receiveMessages(allocator, bench_entity, count, .peek_lock);
    defer batch.deinit();

    if (batch.count() != count) return error.ShortReceive;
}

fn benchReceive1(allocator: std.mem.Allocator) !void {
    return receiveScripted(allocator, receive_script_one, 1);
}

fn benchReceive1000(allocator: std.mem.Allocator) !void {
    return receiveScripted(allocator, receive_script_many, bench_receive_count);
}

const bench_receive_count: u32 = 1000;

/// The harness floor. `benchmarkAllocating` brackets every iteration with two
/// `std.Io` clock reads, and those go through a vtable, so the floor is real
/// and machine-dependent; the cases here that come in under a hundred
/// nanoseconds are within small multiples of it. The body inlines away to
/// nothing — `func` is `comptime`, so there is no call to measure — which is
/// what makes this the floor rather than a reading. Measuring it on the same
/// machine in the same run beats asserting a number in a comment that nobody
/// re-checks.
fn benchNothing(allocator: std.mem.Allocator) !void {
    _ = allocator;
}

/// The one cost the x1/x1000 subtraction does not cancel: handing the peer the
/// longer script. Measured here so it can be subtracted, for the reason given
/// above the receive section.
fn benchScriptPush(allocator: std.mem.Allocator) !void {
    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    try mem.pushPeerBytes(receive_script_many);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    runtime_io = io;

    const annotations = [_]amqp.MapEntry{.{
        .key = .{ .symbol = sb.annotation.sequence_number },
        .value = .{ .long = 4242 },
    }};
    const sections = [_][]const u8{small_body};
    const encoded = try amqp.encodeMessageAlloc(allocator, .{
        .message_annotations = &annotations,
        .properties = .{ .content_type = "application/json" },
        .body = .{ .data = &sections },
    });
    defer allocator.free(encoded);

    var decode_arena = std.heap.ArenaAllocator.init(allocator);
    defer decode_arena.deinit();
    decoded_message = try amqp.decodeMessageInto(decode_arena.allocator(), encoded);

    var peek_arena = std.heap.ArenaAllocator.init(allocator);
    defer peek_arena.deinit();
    peek_reply = try buildPeekReply(peek_arena.allocator(), encoded, 100);

    receive_script_one = try buildReceiveScript(allocator, 1);
    defer allocator.free(receive_script_one);
    receive_script_many = try buildReceiveScript(allocator, bench_receive_count);
    defer allocator.free(receive_script_many);

    send_scratch = .init(allocator);
    defer send_scratch.deinit();

    message_with_properties = makeMessage(allocator);
    defer message_with_properties.deinit();
    try message_with_properties.application_properties.put("tenant", "contoso");
    try message_with_properties.application_properties.put("region", "westus2");
    try message_with_properties.application_properties.put("priority", "high");

    std.debug.print("Service Bus benchmarks (mode: {s})\n", .{@tagName(builtin.mode)});
    if (builtin.mode == .Debug) {
        std.debug.print(
            "  NOTE: Debug build. Re-run with -Doptimize=ReleaseFast for timings that\n" ++
                "  mean anything; allocation counts are valid in either mode.\n",
            .{},
        );
    }

    const cases = .{
        // First, so every reading below can be compared against it.
        .{ "baseline (empty body)", 10_000, benchNothing },
        .{ "toAmqpMessage", 10_000, benchToAmqpMessage },
        .{ "toAmqpMessage + properties", 10_000, benchToAmqpMessageWithProperties },
        .{ "encodeMessage", 10_000, benchEncodeMessage },
        .{ "encodeMessage + properties", 10_000, benchEncodeWithProperties },
        .{ "fromAmqpMessage", 10_000, benchFromAmqpMessage },
        .{ "management.scheduleBody x100", 2_000, benchScheduleBody },
        .{ "management.readPeekedMessages x100", 2_000, benchReadPeekedMessages },
        // Connection setup dominates the x1 case; the difference between the
        // two, divided by 999, is what one message costs on the receive path.
        // Neither leaves an unread transfer buffered at teardown — see above
        // for why that matters, and for what `script fixture` is doing here.
        .{ "receive x1 (scripted peer)", 500, benchReceive1 },
        .{ "receive x1000 (scripted peer)", 20, benchReceive1000 },
        .{ "script fixture (x1000 script)", 500, benchScriptPush },
    };

    inline for (cases) |case| {
        perf.printResult(perf.benchmarkAllocating(
            io,
            case[0],
            case[1],
            allocator,
            case[2],
        ));
    }
}

/// A peek reply body holding `count` copies of `encoded`, in the shape the
/// broker sends: a map with one `messages` list of single-entry maps.
fn buildPeekReply(
    a: std.mem.Allocator,
    encoded: []const u8,
    count: usize,
) !amqp.AmqpValue {
    const items = try a.alloc(amqp.AmqpValue, count);
    for (items) |*slot| {
        const fields = try a.alloc(amqp.MapEntry, 1);
        fields[0] = .{
            .key = .{ .string = sb.management.body_key.message },
            .value = .{ .binary = encoded },
        };
        slot.* = .{ .map = fields };
    }

    const outer = try a.alloc(amqp.MapEntry, 1);
    outer[0] = .{
        .key = .{ .string = sb.management.body_key.messages },
        .value = .{ .list = items },
    };
    return .{ .map = outer };
}
