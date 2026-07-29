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

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    receive_message = uamqp.message.Message.init(allocator);
    defer receive_message.deinit();
    try receive_message.addBodyData(small_body);
    receive_message.message_annotations = &annotations;
    receive_message.application_properties = &properties;
    receive_message.properties = .{ .content_type = "application/json" };

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
