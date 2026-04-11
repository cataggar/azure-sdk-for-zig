///! Long-Running Operation (LRO) poller for Azure services.
///!
///! Azure APIs that return HTTP 202 Accepted include an operation-location
///! or Azure-AsyncOperation header with a URL to poll for completion.

const std = @import("std");
const http = @import("http/transport.zig");
const pipeline_mod = @import("http/pipeline.zig");

pub const OperationStatus = enum {
    not_started,
    in_progress,
    succeeded,
    failed,
    cancelled,

    pub fn fromString(s: []const u8) OperationStatus {
        if (std.mem.eql(u8, s, "Succeeded") or std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "Failed") or std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "Cancelled") or std.mem.eql(u8, s, "cancelled")) return .cancelled;
        if (std.mem.eql(u8, s, "InProgress") or std.mem.eql(u8, s, "inProgress")) return .in_progress;
        return .not_started;
    }

    pub fn isTerminal(self: OperationStatus) bool {
        return self == .succeeded or self == .failed or self == .cancelled;
    }
};

/// Result of polling an LRO.
pub const PollResult = struct {
    status: OperationStatus,
    raw_body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *PollResult) void {
        self.allocator.free(self.raw_body);
    }
};

/// Polls an Azure LRO until it reaches a terminal state.
///
/// `operation_url` is the URL from the operation-location or
/// Azure-AsyncOperation response header.
pub fn pollUntilDone(
    allocator: std.mem.Allocator,
    pipeline: *pipeline_mod.HttpPipeline,
    operation_url: []const u8,
    poll_interval_ms: u64,
    max_polls: u32,
) !PollResult {
    var polls: u32 = 0;
    while (polls < max_polls) : (polls += 1) {
        var req = http.Request.init(allocator, .GET, operation_url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try pipeline.send(&req);

        if (!resp.isSuccess()) {
            defer resp.deinit();
            return error.PollFailed;
        }

        // Parse status from response body.
        const status = parseStatus(resp.body);
        if (status.isTerminal()) {
            return .{
                .status = status,
                .raw_body = resp.body,
                .allocator = resp.allocator,
            };
        }

        resp.deinit();

        if (poll_interval_ms > 0) {
            std.Thread.sleep(poll_interval_ms * std.time.ns_per_ms);
        }
    }
    return error.PollTimeout;
}

fn parseStatus(body: []const u8) OperationStatus {
    const parsed = std.json.parseFromSlice(
        std.json.Value,
        std.heap.page_allocator,
        body,
        .{},
    ) catch return .in_progress;
    defer parsed.deinit();

    if (parsed.value == .object) {
        if (parsed.value.object.get("status")) |v| {
            if (v == .string) return OperationStatus.fromString(v.string);
        }
    }
    return .in_progress;
}

// ─────────────────────── Tests ───────────────────────

test "OperationStatus fromString" {
    try std.testing.expectEqual(OperationStatus.succeeded, OperationStatus.fromString("Succeeded"));
    try std.testing.expectEqual(OperationStatus.failed, OperationStatus.fromString("Failed"));
    try std.testing.expectEqual(OperationStatus.in_progress, OperationStatus.fromString("InProgress"));
    try std.testing.expectEqual(OperationStatus.cancelled, OperationStatus.fromString("Cancelled"));
    try std.testing.expectEqual(OperationStatus.not_started, OperationStatus.fromString("Unknown"));
}

test "OperationStatus isTerminal" {
    try std.testing.expect(OperationStatus.succeeded.isTerminal());
    try std.testing.expect(OperationStatus.failed.isTerminal());
    try std.testing.expect(OperationStatus.cancelled.isTerminal());
    try std.testing.expect(!OperationStatus.in_progress.isTerminal());
    try std.testing.expect(!OperationStatus.not_started.isTerminal());
}

test "pollUntilDone succeeds after polling" {
    const allocator = std.testing.allocator;
    var seq = http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 200, .body = "{\"status\":\"InProgress\"}" },
        .{ .status = 200, .body = "{\"status\":\"Succeeded\",\"result\":\"done\"}" },
    });
    var empty = [_]*pipeline_mod.HttpPolicy{};
    var pip = pipeline_mod.HttpPipeline{ .policies = &empty, .transport_impl = seq.asTransport() };

    var result = try pollUntilDone(allocator, &pip, "https://vault.azure.net/operations/op1", 0, 10);
    defer result.deinit();

    try std.testing.expectEqual(OperationStatus.succeeded, result.status);
    try std.testing.expectEqual(@as(usize, 2), seq.call_count);
}

test "pollUntilDone times out" {
    const allocator = std.testing.allocator;
    var seq = http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 200, .body = "{\"status\":\"InProgress\"}" },
    });
    var empty = [_]*pipeline_mod.HttpPolicy{};
    var pip = pipeline_mod.HttpPipeline{ .policies = &empty, .transport_impl = seq.asTransport() };

    const result = pollUntilDone(allocator, &pip, "https://vault.azure.net/operations/op1", 0, 2);
    try std.testing.expectError(error.PollTimeout, result);
}
