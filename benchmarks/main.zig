//! Offline benchmarks for the Event Hubs encode and decode paths.
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
const eh = @import("azure_sdk_eventhubs");
const amqp = @import("azure_sdk_amqp");
const uamqp = @import("uamqp");

const perf = core.perf;

/// Representative telemetry event: a small JSON body plus a content type.
const small_body = "{\"device\":\"sensor-01\",\"temp\":21.5,\"ts\":1730000000}";

fn makeEvent() eh.EventData {
    var event = eh.EventData.init(small_body);
    event.content_type = "application/json";
    return event;
}

fn benchToAmqpMessage(allocator: std.mem.Allocator) !void {
    const event = makeEvent();
    var message = try event.toAmqpMessage(allocator);
    eh.freeAmqpMessage(allocator, &message);
}

fn addToBatch(allocator: std.mem.Allocator, count: usize) !void {
    var batch = try eh.EventDataBatch.init(.{});
    defer batch.deinit(allocator);

    var i: usize = 0;
    while (i < count) : (i += 1) {
        _ = try batch.tryAdd(allocator, makeEvent());
    }
}

fn benchBatchAdd1(allocator: std.mem.Allocator) !void {
    try addToBatch(allocator, 1);
}

fn benchBatchAdd100(allocator: std.mem.Allocator) !void {
    try addToBatch(allocator, 100);
}

fn benchBatchAdd1000(allocator: std.mem.Allocator) !void {
    try addToBatch(allocator, 1000);
}

/// Laying a full batch out on the wire: the envelope followed by one data
/// section per event. This is what a `sendEventBatch` pays on top of the
/// per-event `tryAdd` cost, and it is the only place a single allocation
/// spans the whole batch.
fn benchEncodeBatchTransfer(allocator: std.mem.Allocator) !void {
    var batch = try eh.EventDataBatch.init(.{});
    defer batch.deinit(allocator);

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        _ = try batch.tryAdd(allocator, makeEvent());
    }

    const payload = try eh.sending.encodeBatchTransfer(allocator, batch);
    allocator.free(payload);
}

/// The annotations Event Hubs stamps on every received event, plus a few
/// application properties, so the decode path does representative work.
var annotations = [_]uamqp.MapEntry{
    .{ .key = .{ .symbol = "x-opt-sequence-number" }, .value = .{ .long = 4242 } },
    .{ .key = .{ .symbol = "x-opt-offset" }, .value = .{ .string = "98765" } },
    .{ .key = .{ .symbol = "x-opt-partition-key" }, .value = .{ .string = "device-01" } },
};

var properties = [_]uamqp.MapEntry{
    .{ .key = .{ .string = "tenant" }, .value = .{ .string = "contoso" } },
    .{ .key = .{ .string = "retries" }, .value = .{ .long = 3 } },
    .{ .key = .{ .string = "enabled" }, .value = .{ .boolean = true } },
};

/// Receive-side decode. The message is built once and borrowed, so this
/// measures only the conversion a consumer pays per event.
var receive_message: uamqp.message.Message = undefined;

fn benchFromAmqpMessage(allocator: std.mem.Allocator) !void {
    var received = try eh.fromAmqpMessage(allocator, &receive_message);
    received.deinit(allocator);
}

// ─────────────────── Receive over a scripted peer ───────────────────
//
// Everything above measures one message in isolation. This measures the loop:
// frames off the transport, deliveries reassembled, messages decoded, events
// converted, dispositions written back. That is where a receiver actually
// spends its time, and where the batching and buffering work in this package
// either pays off or does not — none of it is visible one message at a time.
//
// The peer is a byte script built once, so an iteration pays a memcpy for it
// rather than re-encoding a thousand transfers into the measurement.
//
// Both cases replay the same script and differ only in how many events they
// ask for, so the handshake, the attach, the session and that memcpy are
// identical in each. Subtract them and divide by 999 and what is left is one
// received event, with every fixed cost cancelled out.

const bench_source = "my-hub/ConsumerGroups/$default/Partitions/0";
const bench_instance = "bench-reader";
const bench_link_name = bench_source ++ "-receiver-" ++ bench_instance;

/// Well past what these events need, so the loop is not measuring frame
/// reassembly that a real Event Hubs connection would never do.
const bench_max_frame = 65_536;

const bench_options = amqp.connection_driver.Options{
    .container_id = "bench-container",
    .hostname = "ns.servicebus.windows.net",
    .sasl = .none,
    .max_frame_size = bench_max_frame,
    .idle_timeout_ms = 0,
};

/// The peer's whole side of the conversation: handshake, attach, and one
/// settled transfer per event.
var receive_script: []u8 = &.{};

fn buildReceiveScript(allocator: std.mem.Allocator, events: u32) ![]u8 {
    var scratch = amqp.MemoryTransport.init(allocator);
    defer scratch.deinit();

    const peer = amqp.test_peer.Peer{ .allocator = allocator, .mem = &scratch };
    try amqp.test_peer.scriptHandshake(peer, bench_max_frame);
    try peer.push(0, .{ .attach = .{
        .name = bench_link_name,
        .handle = 0,
        .role = .sender,
        .initial_delivery_count = 0,
    } });

    var bench_annotations = [_]uamqp.MapEntry{
        .{ .key = .{ .symbol = "x-opt-sequence-number" }, .value = .{ .long = 0 } },
        .{ .key = .{ .symbol = "x-opt-offset" }, .value = .{ .string = "100" } },
        .{ .key = .{ .symbol = "x-opt-partition-key" }, .value = .{ .string = "device-01" } },
    };
    const bodies = [_][]const u8{small_body};

    var id: u32 = 0;
    while (id < events) : (id += 1) {
        bench_annotations[0].value = .{ .long = @intCast(id) };
        const payload = try amqp.encodeMessageAlloc(allocator, .{
            .message_annotations = &bench_annotations,
            .application_properties = &properties,
            .properties = .{ .content_type = "application/json" },
            .body = .{ .data = &bodies },
        });
        defer allocator.free(payload);

        const tag = std.mem.asBytes(&id);
        try peer.pushTransfer(0, .{
            .handle = 0,
            .delivery_id = id,
            .delivery_tag = tag,
            .message_format = 0,
            .settled = true,
            .more = false,
        }, payload);
    }

    return allocator.dupe(u8, scratch.inbound.items);
}

/// Receive every event the script holds, through the public pool.
fn receiveScripted(allocator: std.mem.Allocator, count: u32) !void {
    var mem = amqp.MemoryTransport.init(allocator);
    defer mem.deinit();
    try mem.pushPeerBytes(receive_script);

    var clock: amqp.connection_driver.ManualClock = .{};
    var conn = try amqp.connection_driver.Driver.init(
        allocator,
        mem.transport(),
        clock.clock(),
        bench_options,
    );
    defer conn.deinit();

    var fixture = try amqp.test_peer.Fixture.init(allocator, &mem, &clock, &conn);
    defer fixture.deinit();

    var pool = eh.ReceiverPool.init(allocator, &fixture.session, .{
        .instance_id = bench_instance,
        .deadline_ms = 10_000,
    });
    defer pool.deinit();

    const events = try pool.receive(allocator, bench_source, null, count);
    defer eh.freeReceivedEvents(allocator, events);

    if (events.len != count) return error.ShortReceive;
}

fn benchReceive1(allocator: std.mem.Allocator) !void {
    return receiveScripted(allocator, 1);
}

fn benchReceive1000(allocator: std.mem.Allocator) !void {
    return receiveScripted(allocator, bench_receive_events);
}

const bench_receive_events: u32 = 1000;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    receive_message = uamqp.message.Message.init(allocator);
    defer receive_message.deinit();
    try receive_message.addBodyData(small_body);
    receive_message.message_annotations = &annotations;
    receive_message.application_properties = &properties;
    receive_message.properties = .{ .content_type = "application/json" };

    receive_script = try buildReceiveScript(allocator, bench_receive_events);
    defer allocator.free(receive_script);

    std.debug.print("Event Hubs benchmarks (mode: {s})\n", .{@tagName(builtin.mode)});
    if (builtin.mode == .Debug) {
        std.debug.print(
            "  NOTE: Debug build. Re-run with -Doptimize=ReleaseFast for timings that\n" ++
                "  mean anything; allocation counts are valid in either mode.\n",
            .{},
        );
    }

    const cases = .{
        .{ "toAmqpMessage", 10_000, benchToAmqpMessage },
        .{ "batch.tryAdd x1", 10_000, benchBatchAdd1 },
        .{ "batch.tryAdd x100", 200, benchBatchAdd100 },
        .{ "batch.tryAdd x1000", 20, benchBatchAdd1000 },
        .{ "encodeBatchTransfer x1000", 20, benchEncodeBatchTransfer },
        .{ "fromAmqpMessage", 10_000, benchFromAmqpMessage },
        // Session setup dominates the x1 case; the difference between the two,
        // divided by 999, is what one event costs on the receive path.
        .{ "receive x1 (scripted peer)", 500, benchReceive1 },
        .{ "receive x1000 (scripted peer)", 20, benchReceive1000 },
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
