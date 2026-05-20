///! Long-Running Operation (LRO) poller for Azure services.
///!
///! Azure APIs that return HTTP 202 Accepted include headers like
///! `Operation-Location` or `Azure-AsyncOperation` with URLs to poll.
///! This module supports multiple polling strategies and auto-detection.
const std = @import("std");
const serde = @import("serde");
const http = @import("http/transport.zig");
const pipeline_mod = @import("http/pipeline.zig");

fn sleepMs(ms: u64) void {
    var threaded: std.Io.Threaded = .init_single_threaded;
    threaded.io().sleep(.fromMilliseconds(@intCast(ms)), .real) catch {};
}

pub const OperationStatus = enum {
    not_started,
    in_progress,
    succeeded,
    failed,
    cancelled,

    pub fn fromString(s: []const u8) OperationStatus {
        if (eqlIgnoreCase(s, "Succeeded")) return .succeeded;
        if (eqlIgnoreCase(s, "Failed")) return .failed;
        if (eqlIgnoreCase(s, "Cancelled") or eqlIgnoreCase(s, "Canceled")) return .cancelled;
        if (eqlIgnoreCase(s, "InProgress") or eqlIgnoreCase(s, "Running") or
            eqlIgnoreCase(s, "Updating") or eqlIgnoreCase(s, "Creating") or
            eqlIgnoreCase(s, "Deleting") or eqlIgnoreCase(s, "Activating") or
            eqlIgnoreCase(s, "Completed") or eqlIgnoreCase(s, "inprogress"))
            return .in_progress;
        if (eqlIgnoreCase(s, "NotStarted")) return .not_started;
        // Unknown status is treated as in-progress (non-terminal).
        return .in_progress;
    }

    pub fn isTerminal(self: OperationStatus) bool {
        return self == .succeeded or self == .failed or self == .cancelled;
    }
};

/// How to discover the poll URL and read status from the response.
pub const PollingStrategy = enum {
    /// Poll the `Operation-Location` header URL. Status from `status` in body.
    operation_location,
    /// Poll the `Azure-AsyncOperation` header URL. Status from `status` in body.
    azure_async_operation,
    /// Poll the `Location` header URL. HTTP 202 = in-progress, 200/201 = done.
    location,
    /// Re-GET the original URL. Status from `properties.provisioningState`.
    provisioning_state,
};

/// How to obtain the final result after the operation completes.
pub const FinalResultMode = enum {
    /// The last poll response body is the final result.
    last_poll_body,
    /// Do a final GET to the original request URL.
    original_url,
    /// No meaningful final result (e.g., DELETE operations).
    none,
};

pub const PollerOptions = struct {
    poll_interval_ms: u64 = 1000,
    max_polls: u32 = 100,
    /// Explicit strategy. Null means auto-detect from the initial response.
    strategy: ?PollingStrategy = null,
    /// How to get the final result. Null means infer from strategy.
    final_result_mode: ?FinalResultMode = null,
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

/// Stateful poller for Azure Long-Running Operations.
///
/// Supports multiple polling strategies (Operation-Location, Azure-AsyncOperation,
/// Location header, provisioning state) with auto-detection from the initial
/// response headers.
///
/// Usage:
///   var poller = try Poller.init(allocator, pipeline, initial_response, original_url, .{});
///   defer poller.deinit();
///   var result = try poller.pollUntilDone();
///   defer result.deinit();
pub const Poller = struct {
    pipeline: pipeline_mod.HttpPipeline,
    poll_url: []u8,
    original_url: ?[]u8,
    allocator: std.mem.Allocator,
    strategy: PollingStrategy,
    final_result_mode: FinalResultMode,
    poll_interval_ms: u64,
    max_polls: u32,
    status: OperationStatus,
    last_body: ?[]u8,

    /// Create a poller from an initial HTTP response.
    ///
    /// Auto-detects the polling strategy from response headers unless
    /// `options.strategy` is explicitly set. Dupes all URL/body data
    /// so the caller can safely deinit the response after this call.
    pub fn init(
        allocator: std.mem.Allocator,
        pipeline: pipeline_mod.HttpPipeline,
        initial_response: http.Response,
        original_url: ?[]const u8,
        options: PollerOptions,
    ) !Poller {
        const strategy = options.strategy orelse try detectStrategy(initial_response);
        const poll_url_str = switch (strategy) {
            .operation_location => getHeaderIgnoreCase(initial_response.headers, "operation-location"),
            .azure_async_operation => getHeaderIgnoreCase(initial_response.headers, "azure-asyncoperation"),
            .location => getHeaderIgnoreCase(initial_response.headers, "location"),
            .provisioning_state => original_url,
        } orelse return error.NoPollUrl;

        const final_result_mode = options.final_result_mode orelse switch (strategy) {
            .operation_location => FinalResultMode.last_poll_body,
            .azure_async_operation => FinalResultMode.original_url,
            .location => FinalResultMode.last_poll_body,
            .provisioning_state => FinalResultMode.last_poll_body,
        };

        // Parse initial status from the response body (may already be terminal).
        const initial_status = switch (strategy) {
            .location => statusFromHttpCode(initial_response.status_code),
            .provisioning_state => parseProvisioningState(allocator, initial_response.body),
            else => parseStatus(allocator, initial_response.body),
        };

        return .{
            .pipeline = pipeline,
            .poll_url = try allocator.dupe(u8, poll_url_str),
            .original_url = if (original_url) |u| try allocator.dupe(u8, u) else null,
            .allocator = allocator,
            .strategy = strategy,
            .final_result_mode = final_result_mode,
            .poll_interval_ms = options.poll_interval_ms,
            .max_polls = options.max_polls,
            .status = initial_status,
            .last_body = try allocator.dupe(u8, initial_response.body),
        };
    }

    /// Perform a single poll. Returns the current operation status.
    pub fn poll(self: *Poller) !OperationStatus {
        var req = http.Request.init(self.allocator, .GET, self.poll_url);
        defer req.deinit();
        try req.setHeader("Accept", "application/json");

        var resp = try self.pipeline.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess() and self.strategy != .location) {
            return error.PollFailed;
        }

        // Extract status based on strategy.
        self.status = switch (self.strategy) {
            .location => statusFromHttpCode(resp.status_code),
            .provisioning_state => parseProvisioningState(self.allocator, resp.body),
            else => parseStatus(self.allocator, resp.body),
        };

        // Replace cached body.
        if (self.last_body) |old| self.allocator.free(old);
        self.last_body = try self.allocator.dupe(u8, resp.body);

        // Check for Retry-After header and update interval.
        if (getHeaderIgnoreCase(resp.headers, "retry-after")) |ra| {
            if (std.fmt.parseInt(u64, ra, 10)) |secs| {
                // Clamp to max 120 seconds.
                self.poll_interval_ms = @min(secs * 1000, 120_000);
            } else |_| {}
        }

        return self.status;
    }

    /// Poll until the operation reaches a terminal state.
    pub fn pollUntilDone(self: *Poller) !PollResult {
        // If already terminal from the initial response, return immediately.
        if (self.status.isTerminal()) {
            return try self.buildResult();
        }

        var polls: u32 = 0;
        while (polls < self.max_polls) : (polls += 1) {
            if (self.poll_interval_ms > 0) {
                sleepMs(self.poll_interval_ms);
            }

            const status = try self.poll();
            if (status.isTerminal()) {
                return try self.buildResult();
            }
        }
        return error.PollTimeout;
    }

    /// Get the current status without polling.
    pub fn getStatus(self: *const Poller) OperationStatus {
        return self.status;
    }

    /// Free all poller-owned resources.
    pub fn deinit(self: *Poller) void {
        self.allocator.free(self.poll_url);
        if (self.original_url) |u| self.allocator.free(u);
        if (self.last_body) |b| self.allocator.free(b);
        self.last_body = null;
        self.original_url = null;
    }

    fn buildResult(self: *Poller) !PollResult {
        // For azure_async_operation, do a final GET to original URL.
        if (self.final_result_mode == .original_url) {
            if (self.original_url) |orig| {
                var req = http.Request.init(self.allocator, .GET, orig);
                defer req.deinit();
                try req.setHeader("Accept", "application/json");

                var resp = try self.pipeline.send(&req);

                if (!resp.isSuccess()) {
                    defer resp.deinit();
                    return error.FinalResultFailed;
                }

                return .{
                    .status = self.status,
                    .raw_body = resp.body,
                    .allocator = resp.allocator,
                };
            }
        }

        // For last_poll_body or none: return the cached body.
        const body = self.last_body orelse return error.NoResultBody;
        self.last_body = null; // Transfer ownership to the PollResult.
        return .{
            .status = self.status,
            .raw_body = body,
            .allocator = self.allocator,
        };
    }
};

// ─────────────────── Typed Poller wrapper ──────────────────

/// Typed convenience wrapper over `Poller`. Used by generated ARM
/// clients so callers can `await` an LRO and receive the parsed
/// resource type instead of having to deserialize `PollResult.raw_body`
/// themselves.
///
/// Specialize `T = void` for operations with no body (e.g. ARM DELETE
/// LROs) — `pollUntilDone` then returns `void` without attempting to
/// parse the response body.
pub fn TypedPoller(comptime T: type) type {
    return struct {
        inner: Poller,

        const Self = @This();

        pub fn init(
            allocator: std.mem.Allocator,
            pipeline: pipeline_mod.HttpPipeline,
            initial_response: http.Response,
            original_url: ?[]const u8,
            options: PollerOptions,
        ) !Self {
            return .{ .inner = try Poller.init(allocator, pipeline, initial_response, original_url, options) };
        }

        /// Single poll step; returns the new status without driving to
        /// completion. Forwards to the embedded `Poller`.
        pub fn poll(self: *Self) !OperationStatus {
            return self.inner.poll();
        }

        /// Current cached status (does not perform I/O).
        pub fn getStatus(self: *const Self) OperationStatus {
            return self.inner.getStatus();
        }

        /// Drive the LRO to a terminal state and return the parsed `T`.
        /// `allocator` owns the returned value's heap data; the
        /// poll-result body is released before this method returns.
        pub fn pollUntilDone(self: *Self, allocator: std.mem.Allocator) !T {
            var raw = try self.inner.pollUntilDone();
            defer raw.deinit();
            if (T == void) return;
            return try serde.json.fromSlice(T, allocator, raw.raw_body);
        }

        pub fn deinit(self: *Self) void {
            self.inner.deinit();
        }
    };
}

// ─────────────────── Strategy Detection ────────────────────

fn detectStrategy(response: http.Response) !PollingStrategy {
    if (getHeaderIgnoreCase(response.headers, "operation-location") != null)
        return .operation_location;
    if (getHeaderIgnoreCase(response.headers, "azure-asyncoperation") != null)
        return .azure_async_operation;
    if (getHeaderIgnoreCase(response.headers, "location") != null and response.status_code == 202)
        return .location;
    return error.UnsupportedLroPattern;
}

// ─────────────────── Status Parsing ────────────────────────

fn parseStatus(allocator: std.mem.Allocator, body: []const u8) OperationStatus {
    const StatusSchema = struct {
        status: ?[]const u8 = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(StatusSchema, arena.allocator(), body) catch return .in_progress;
    if (parsed.status) |s| return OperationStatus.fromString(s);
    return .in_progress;
}

fn parseProvisioningState(allocator: std.mem.Allocator, body: []const u8) OperationStatus {
    const PropsSchema = struct {
        provisioningState: ?[]const u8 = null,
    };
    const ProvisioningSchema = struct {
        properties: ?PropsSchema = null,
        // Some ARM resources put provisioningState at the top level.
        provisioningState: ?[]const u8 = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(ProvisioningSchema, arena.allocator(), body) catch return .in_progress;
    if (parsed.properties) |props| {
        if (props.provisioningState) |s| return OperationStatus.fromString(s);
    }
    if (parsed.provisioningState) |s| return OperationStatus.fromString(s);
    return .in_progress;
}

fn statusFromHttpCode(code: u16) OperationStatus {
    if (code == 200 or code == 201) return .succeeded;
    if (code == 202) return .in_progress;
    if (code >= 400) return .failed;
    return .in_progress;
}

// ─────────────────── Header Helpers ────────────────────────

fn getHeaderIgnoreCase(headers: std.StringHashMap([]const u8), key: []const u8) ?[]const u8 {
    // Direct lookup first.
    if (headers.get(key)) |v| return v;
    // Case-insensitive scan.
    var it = headers.iterator();
    while (it.next()) |entry| {
        if (eqlIgnoreCase(entry.key_ptr.*, key)) return entry.value_ptr.*;
    }
    return null;
}

fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (std.ascii.toLower(ca) != std.ascii.toLower(cb)) return false;
    }
    return true;
}

// ─────────────────── Legacy Compat ─────────────────────────

/// Polls an Azure LRO until it reaches a terminal state.
///
/// This is the original simple poller. For new code, prefer `Poller.init`
/// which supports multiple strategies and auto-detection.
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
        const status = parseStatus(resp.allocator, resp.body);
        if (status.isTerminal()) {
            return .{
                .status = status,
                .raw_body = resp.body,
                .allocator = resp.allocator,
            };
        }

        resp.deinit();

        if (poll_interval_ms > 0) {
            sleepMs(poll_interval_ms);
        }
    }
    return error.PollTimeout;
}

// ─────────────────────── Tests ───────────────────────

test "OperationStatus fromString" {
    try std.testing.expectEqual(OperationStatus.succeeded, OperationStatus.fromString("Succeeded"));
    try std.testing.expectEqual(OperationStatus.succeeded, OperationStatus.fromString("succeeded"));
    try std.testing.expectEqual(OperationStatus.failed, OperationStatus.fromString("Failed"));
    try std.testing.expectEqual(OperationStatus.in_progress, OperationStatus.fromString("InProgress"));
    try std.testing.expectEqual(OperationStatus.in_progress, OperationStatus.fromString("Running"));
    try std.testing.expectEqual(OperationStatus.cancelled, OperationStatus.fromString("Cancelled"));
    try std.testing.expectEqual(OperationStatus.cancelled, OperationStatus.fromString("Canceled"));
    // Unknown strings are non-terminal.
    try std.testing.expectEqual(OperationStatus.in_progress, OperationStatus.fromString("SomeUnknownState"));
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

test "Poller operation-location strategy" {
    const allocator = std.testing.allocator;

    // Initial response with Operation-Location header.
    var initial_headers = std.StringHashMap([]const u8).init(allocator);
    try initial_headers.put(
        try allocator.dupe(u8, "Operation-Location"),
        try allocator.dupe(u8, "https://vault.azure.net/operations/op1"),
    );
    const initial_resp = http.Response{
        .status_code = 202,
        .headers = initial_headers,
        .body = try allocator.dupe(u8, "{\"status\":\"InProgress\"}"),
        .allocator = allocator,
    };
    defer {
        var resp = initial_resp;
        resp.deinit();
    }

    // Mock transport for poll responses.
    var seq = http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 200, .body = "{\"status\":\"Succeeded\",\"result\":42}" },
    });
    var empty = [_]*pipeline_mod.HttpPolicy{};

    var poller = try Poller.init(
        allocator,
        .{ .policies = &empty, .transport_impl = seq.asTransport() },
        initial_resp,
        "https://vault.azure.net/keys/mykey",
        .{ .poll_interval_ms = 0 },
    );
    defer poller.deinit();

    try std.testing.expectEqual(PollingStrategy.operation_location, poller.strategy);
    try std.testing.expectEqual(OperationStatus.in_progress, poller.status);

    var result = try poller.pollUntilDone();
    defer result.deinit();

    try std.testing.expectEqual(OperationStatus.succeeded, result.status);
}

test "Poller location strategy" {
    const allocator = std.testing.allocator;

    var initial_headers = std.StringHashMap([]const u8).init(allocator);
    try initial_headers.put(
        try allocator.dupe(u8, "Location"),
        try allocator.dupe(u8, "https://example.com/status/123"),
    );
    const initial_resp = http.Response{
        .status_code = 202,
        .headers = initial_headers,
        .body = try allocator.dupe(u8, ""),
        .allocator = allocator,
    };
    defer {
        var resp = initial_resp;
        resp.deinit();
    }

    var seq = http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 202, .body = "{\"status\":\"running\"}" },
        .{ .status = 200, .body = "{\"id\":\"resource-1\",\"name\":\"done\"}" },
    });
    var empty = [_]*pipeline_mod.HttpPolicy{};

    var poller = try Poller.init(
        allocator,
        .{ .policies = &empty, .transport_impl = seq.asTransport() },
        initial_resp,
        "https://example.com/resources/1",
        .{ .poll_interval_ms = 0 },
    );
    defer poller.deinit();

    try std.testing.expectEqual(PollingStrategy.location, poller.strategy);

    var result = try poller.pollUntilDone();
    defer result.deinit();

    try std.testing.expectEqual(OperationStatus.succeeded, result.status);
}

test "Poller provisioning-state strategy" {
    const allocator = std.testing.allocator;

    // No LRO headers — must provide explicit strategy.
    const empty_headers = std.StringHashMap([]const u8).init(allocator);
    const initial_resp = http.Response{
        .status_code = 201,
        .headers = empty_headers,
        .body = try allocator.dupe(u8, "{\"properties\":{\"provisioningState\":\"Creating\"}}"),
        .allocator = allocator,
    };
    defer {
        var resp = initial_resp;
        resp.deinit();
    }

    var seq = http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 200, .body = "{\"properties\":{\"provisioningState\":\"Succeeded\"},\"name\":\"my-resource\"}" },
    });
    var empty = [_]*pipeline_mod.HttpPolicy{};

    var poller = try Poller.init(
        allocator,
        .{ .policies = &empty, .transport_impl = seq.asTransport() },
        initial_resp,
        "https://management.azure.com/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1",
        .{ .poll_interval_ms = 0, .strategy = .provisioning_state },
    );
    defer poller.deinit();

    try std.testing.expectEqual(PollingStrategy.provisioning_state, poller.strategy);

    var result = try poller.pollUntilDone();
    defer result.deinit();

    try std.testing.expectEqual(OperationStatus.succeeded, result.status);
}

test "Poller azure-async-operation with final GET" {
    const allocator = std.testing.allocator;

    var initial_headers = std.StringHashMap([]const u8).init(allocator);
    try initial_headers.put(
        try allocator.dupe(u8, "Azure-AsyncOperation"),
        try allocator.dupe(u8, "https://example.com/operations/op42"),
    );
    const initial_resp = http.Response{
        .status_code = 202,
        .headers = initial_headers,
        .body = try allocator.dupe(u8, ""),
        .allocator = allocator,
    };
    defer {
        var resp = initial_resp;
        resp.deinit();
    }

    // Poll returns Succeeded, then final GET returns the resource.
    var seq = http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 200, .body = "{\"status\":\"Succeeded\"}" },
        .{ .status = 200, .body = "{\"id\":\"res-1\",\"name\":\"my-resource\"}" },
    });
    var empty = [_]*pipeline_mod.HttpPolicy{};

    var poller = try Poller.init(
        allocator,
        .{ .policies = &empty, .transport_impl = seq.asTransport() },
        initial_resp,
        "https://example.com/resources/1",
        .{ .poll_interval_ms = 0 },
    );
    defer poller.deinit();

    try std.testing.expectEqual(PollingStrategy.azure_async_operation, poller.strategy);
    try std.testing.expectEqual(FinalResultMode.original_url, poller.final_result_mode);

    var result = try poller.pollUntilDone();
    defer result.deinit();

    try std.testing.expectEqual(OperationStatus.succeeded, result.status);
    // The result body should be from the final GET, not the poll.
    try std.testing.expect(std.mem.find(u8, result.raw_body, "my-resource") != null);
}

test "Poller single poll" {
    const allocator = std.testing.allocator;

    var initial_headers = std.StringHashMap([]const u8).init(allocator);
    try initial_headers.put(
        try allocator.dupe(u8, "Operation-Location"),
        try allocator.dupe(u8, "https://example.com/ops/1"),
    );
    const initial_resp = http.Response{
        .status_code = 202,
        .headers = initial_headers,
        .body = try allocator.dupe(u8, "{\"status\":\"NotStarted\"}"),
        .allocator = allocator,
    };
    defer {
        var resp = initial_resp;
        resp.deinit();
    }

    var seq = http.SequenceMockTransport.init(allocator, &.{
        .{ .status = 200, .body = "{\"status\":\"InProgress\"}" },
        .{ .status = 200, .body = "{\"status\":\"Succeeded\"}" },
    });
    var empty = [_]*pipeline_mod.HttpPolicy{};

    var poller = try Poller.init(
        allocator,
        .{ .policies = &empty, .transport_impl = seq.asTransport() },
        initial_resp,
        null,
        .{ .poll_interval_ms = 0 },
    );
    defer poller.deinit();

    // First poll: still in progress.
    const s1 = try poller.poll();
    try std.testing.expectEqual(OperationStatus.in_progress, s1);

    // Second poll: succeeded.
    const s2 = try poller.poll();
    try std.testing.expectEqual(OperationStatus.succeeded, s2);
}

test "Poller auto-detect fails without headers" {
    const allocator = std.testing.allocator;
    const empty_headers = std.StringHashMap([]const u8).init(allocator);
    const initial_resp = http.Response{
        .status_code = 200,
        .headers = empty_headers,
        .body = try allocator.dupe(u8, "{}"),
        .allocator = allocator,
    };
    defer {
        var resp = initial_resp;
        resp.deinit();
    }

    var mock = http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    var empty = [_]*pipeline_mod.HttpPolicy{};

    const result = Poller.init(
        allocator,
        .{ .policies = &empty, .transport_impl = mock.asTransport() },
        initial_resp,
        null,
        .{},
    );
    try std.testing.expectError(error.UnsupportedLroPattern, result);
}

test "parseProvisioningState" {
    try std.testing.expectEqual(OperationStatus.succeeded, parseProvisioningState(std.testing.allocator,
        \\{"properties":{"provisioningState":"Succeeded"}}
    ));
    try std.testing.expectEqual(OperationStatus.in_progress, parseProvisioningState(std.testing.allocator,
        \\{"properties":{"provisioningState":"Creating"}}
    ));
    try std.testing.expectEqual(OperationStatus.failed, parseProvisioningState(std.testing.allocator,
        \\{"properties":{"provisioningState":"Failed"}}
    ));
    // Top-level fallback.
    try std.testing.expectEqual(OperationStatus.succeeded, parseProvisioningState(std.testing.allocator,
        \\{"provisioningState":"Succeeded"}
    ));
}

test "eqlIgnoreCase" {
    try std.testing.expect(eqlIgnoreCase("Operation-Location", "operation-location"));
    try std.testing.expect(eqlIgnoreCase("Content-Type", "content-type"));
    try std.testing.expect(!eqlIgnoreCase("abc", "abcd"));
    try std.testing.expect(!eqlIgnoreCase("abc", "xyz"));
}
