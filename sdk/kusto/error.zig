const std = @import("std");
const serde = @import("serde");
const http = @import("azure_core").http;

/// Kusto operation that produced a service failure.
pub const KustoOperation = enum {
    query,
    management,
    streaming_ingest,
};

/// Where Kusto reported a failure.
pub const KustoErrorSource = enum {
    http,
    dataset_completion,
    table_completion,
    data_table,
    query_status,
    v1_exception,
    transport,
};

/// What is known about the operation after a response or transport failure.
pub const KustoOperationOutcome = enum {
    partial,
    accepted,
    known_not_accepted,
    unknown,
};

/// Allocator-owned details from a OneAPI error, including its recursive cause.
pub const KustoErrorDetail = struct {
    code: ?[]u8 = null,
    message: ?[]u8 = null,
    error_type: ?[]u8 = null,
    description: ?[]u8 = null,
    permanent: ?bool = null,
    inner_error: ?*KustoErrorDetail = null,

    pub fn deinit(self: *KustoErrorDetail, allocator: std.mem.Allocator) void {
        if (self.code) |value| allocator.free(value);
        if (self.message) |value| allocator.free(value);
        if (self.error_type) |value| allocator.free(value);
        if (self.description) |value| allocator.free(value);
        if (self.inner_error) |inner| {
            inner.deinit(allocator);
            allocator.destroy(inner);
        }
        self.* = .{};
    }
};

/// An owned Kusto service failure. `retryable` is deliberately conservative:
/// only known transient non-2xx HTTP failures can be retryable.
pub const KustoError = struct {
    allocator: std.mem.Allocator,
    operation: KustoOperation,
    source: KustoErrorSource,
    outcome: KustoOperationOutcome,
    http_status: ?u16 = null,
    detail: KustoErrorDetail = .{},
    client_request_id: ?[]u8 = null,
    activity_id: ?[]u8 = null,
    transport_error: ?anyerror = null,
    retry_after_ms: ?u64 = null,
    permanent: ?bool = null,
    cancelled: bool = false,
    retryable: bool = false,

    pub fn deinit(self: *KustoError) void {
        self.detail.deinit(self.allocator);
        if (self.client_request_id) |value| self.allocator.free(value);
        if (self.activity_id) |value| self.allocator.free(value);
        self.client_request_id = null;
        self.activity_id = null;
    }

    pub fn format(self: KustoError, writer: anytype) !void {
        try writer.print("KustoError(operation={s}, source={s}, outcome={s}", .{
            @tagName(self.operation),
            @tagName(self.source),
            @tagName(self.outcome),
        });
        if (self.http_status) |status| try writer.print(", status={d}", .{status});
        if (self.detail.code) |code| try writer.print(", code={s}", .{code});
        if (self.detail.message) |message| try writer.print(", message={s}", .{message});
        if (self.transport_error) |cause| try writer.print(", cause={s}", .{@errorName(cause)});
        try writer.writeAll(")");
    }
};

/// Kusto-specific result that keeps service failures separate from local Zig
/// errors and retains decoded tables when a response completed partially.
pub fn KustoResult(comptime T: type) type {
    return union(enum) {
        ok: T,
        partial: struct { value: T, failure: KustoError },
        err: KustoError,

        const Self = @This();

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            switch (self.*) {
                .ok => |*value| deinitValue(T, value, allocator),
                .partial => |*partial| {
                    deinitValue(T, &partial.value, allocator);
                    partial.failure.deinit();
                },
                .err => |*failure| failure.deinit(),
            }
        }
    };
}

fn deinitValue(comptime T: type, value: *T, allocator: std.mem.Allocator) void {
    switch (@typeInfo(T)) {
        .@"struct" => {
            if (comptime @hasDecl(T, "deinit"))
                value.deinit(allocator);
        },
        .pointer => |pointer| {
            if (comptime pointer.size == .one and @hasDecl(pointer.child, "deinit")) {
                const deinit_info = @typeInfo(@TypeOf(pointer.child.deinit)).@"fn";
                if (comptime deinit_info.params.len == 1) {
                    value.*.deinit();
                } else if (comptime deinit_info.params.len == 2) {
                    value.*.deinit(allocator);
                } else {
                    @compileError("KustoResult pointer payload deinit must accept self and optionally an allocator");
                }
            }
        },
        else => {},
    }
}

/// Wire types are public so data-frame decoding can use the same serde shape.
pub const OneApiContext = struct {
    clientRequestId: ?[]const u8 = null,
    activityId: ?[]const u8 = null,
};

pub const OneApiErrorBody = struct {
    code: ?[]const u8 = null,
    message: ?[]const u8 = null,
    @"@type": ?[]const u8 = null,
    @"@message": ?[]const u8 = null,
    @"@context": ?OneApiContext = null,
    @"@permanent": ?bool = null,
    innererror: ?*OneApiErrorBody = null,
};

pub const OneApiEnvelope = struct {
    @"error": ?OneApiErrorBody = null,
};

/// Parses a OneAPI envelope. Invalid JSON intentionally still yields a
/// structured HTTP failure; malformed service bodies are not local failures.
pub fn fromHttpResponse(
    allocator: std.mem.Allocator,
    operation: KustoOperation,
    response: *const http.Response,
    outcome: KustoOperationOutcome,
) !KustoError {
    var result = init(allocator, operation, .http, outcome, response.status_code);
    errdefer result.deinit();
    result.retry_after_ms = retryAfterMs(response);
    try setIds(
        &result,
        response.getHeader("x-ms-client-request-id"),
        response.getHeader("x-ms-activity-id"),
        null,
    );

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const envelope = serde.json.fromSlice(OneApiEnvelope, arena.allocator(), response.body) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        result.retryable = isRetryable(result);
        return result;
    };
    if (envelope.@"error") |body| {
        try populate(&result, body);
        if (result.client_request_id == null and result.activity_id == null) {
            try setIds(&result, null, null, body.@"@context");
        } else if (body.@"@context") |context| {
            if (result.client_request_id == null and context.clientRequestId != null)
                result.client_request_id = try allocator.dupe(u8, context.clientRequestId.?);
            if (result.activity_id == null and context.activityId != null)
                result.activity_id = try allocator.dupe(u8, context.activityId.?);
        }
    }
    result.retryable = isRetryable(result);
    return result;
}

fn retryAfterMs(response: *const http.Response) ?u64 {
    const value = response.getHeader("Retry-After") orelse return null;
    const seconds = std.fmt.parseInt(u64, value, 10) catch return null;
    return std.math.mul(u64, seconds, 1000) catch std.math.maxInt(u64);
}

/// Converts the first OneAPI envelope from an in-band completion frame.
pub fn fromOneApiEnvelope(
    allocator: std.mem.Allocator,
    operation: KustoOperation,
    source: KustoErrorSource,
    envelope: OneApiEnvelope,
    cancelled: bool,
) !KustoError {
    var result = init(allocator, operation, source, .partial, null);
    errdefer result.deinit();
    if (envelope.@"error") |body| {
        try populate(&result, body);
        try setIds(&result, null, null, body.@"@context");
    }
    result.cancelled = cancelled;
    result.retryable = isRetryable(result);
    return result;
}

pub fn inBandFailure(
    allocator: std.mem.Allocator,
    operation: KustoOperation,
    source: KustoErrorSource,
    cancelled: bool,
) KustoError {
    var result = init(allocator, operation, source, .partial, null);
    result.cancelled = cancelled;
    result.retryable = false;
    return result;
}

pub fn transportUnknown(
    allocator: std.mem.Allocator,
    transport_error: anyerror,
    client_request_id: ?[]const u8,
) !KustoError {
    var result = init(allocator, .streaming_ingest, .transport, .unknown, null);
    errdefer result.deinit();
    result.transport_error = transport_error;
    if (client_request_id) |value|
        result.client_request_id = try allocator.dupe(u8, value);
    return result;
}

/// Prefer correlation IDs carried by the HTTP response over values embedded in
/// a OneAPI context. Completion-frame errors call this after classification.
pub fn applyResponseCorrelation(
    result: *KustoError,
    response: *const http.Response,
    fallback_request_id: ?[]const u8,
) !void {
    return applyCorrelation(
        result,
        response.getHeader("x-ms-client-request-id"),
        response.getHeader("x-ms-activity-id"),
        fallback_request_id,
    );
}

/// Prefer correlation IDs carried by a streaming HTTP operation over values
/// embedded in a OneAPI context.
pub fn applyCorrelation(
    result: *KustoError,
    response_request_id: ?[]const u8,
    response_activity_id: ?[]const u8,
    fallback_request_id: ?[]const u8,
) !void {
    if (response_request_id) |value| {
        const owned = try result.allocator.dupe(u8, value);
        if (result.client_request_id) |old| result.allocator.free(old);
        result.client_request_id = owned;
    } else if (result.client_request_id == null) {
        if (fallback_request_id) |value|
            result.client_request_id = try result.allocator.dupe(u8, value);
    }
    if (response_activity_id) |value| {
        const owned = try result.allocator.dupe(u8, value);
        if (result.activity_id) |old| result.allocator.free(old);
        result.activity_id = owned;
    }
}

fn init(
    allocator: std.mem.Allocator,
    operation: KustoOperation,
    source: KustoErrorSource,
    outcome: KustoOperationOutcome,
    status: ?u16,
) KustoError {
    return .{
        .allocator = allocator,
        .operation = operation,
        .source = source,
        .outcome = outcome,
        .http_status = status,
    };
}

fn populate(result: *KustoError, body: OneApiErrorBody) !void {
    result.detail = try makeDetail(result.allocator, body);
    result.permanent = body.@"@permanent";
}

fn makeDetail(allocator: std.mem.Allocator, body: OneApiErrorBody) !KustoErrorDetail {
    var detail = KustoErrorDetail{};
    errdefer detail.deinit(allocator);
    if (body.code) |value| detail.code = try allocator.dupe(u8, value);
    if (body.message) |value| detail.message = try allocator.dupe(u8, value);
    if (body.@"@type") |value| detail.error_type = try allocator.dupe(u8, value);
    if (body.@"@message") |value| detail.description = try allocator.dupe(u8, value);
    detail.permanent = body.@"@permanent";
    if (body.innererror) |inner| {
        const owned_inner = try allocator.create(KustoErrorDetail);
        errdefer allocator.destroy(owned_inner);
        owned_inner.* = try makeDetail(allocator, inner.*);
        detail.inner_error = owned_inner;
    }
    return detail;
}

fn setIds(
    result: *KustoError,
    header_request_id: ?[]const u8,
    header_activity_id: ?[]const u8,
    context: ?OneApiContext,
) !void {
    const request_id = header_request_id orelse if (context) |value| value.clientRequestId else null;
    const activity_id = header_activity_id orelse if (context) |value| value.activityId else null;
    if (request_id) |value| result.client_request_id = try result.allocator.dupe(u8, value);
    errdefer if (result.client_request_id) |value| {
        result.allocator.free(value);
        result.client_request_id = null;
    };
    if (activity_id) |value| result.activity_id = try result.allocator.dupe(u8, value);
}

fn isRetryable(result: KustoError) bool {
    if (result.permanent == true or result.cancelled or result.outcome == .partial or result.outcome == .unknown) return false;
    if (result.source != .http) return false;
    return switch (result.http_status orelse return false) {
        408, 429, 500, 502, 503, 504, 520 => true,
        else => false,
    };
}

test "OneAPI HTTP errors preserve details and correlation IDs" {
    const allocator = std.testing.allocator;
    var response = http.Response{
        .status_code = 400,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(u8,
            \\{"error":{"code":"BadRequest","message":"bad","@type":"Kusto.Data.Exceptions","@message":"description","@permanent":true,"@context":{"clientRequestId":"context-request","activityId":"context-activity"},"innererror":{"code":"Inner","message":"inner"}}}
        ),
        .allocator = allocator,
    };
    defer response.deinit();
    try response.headers.put(try allocator.dupe(u8, "x-ms-client-request-id"), try allocator.dupe(u8, "header-request"));
    try response.headers.put(try allocator.dupe(u8, "x-ms-activity-id"), try allocator.dupe(u8, "header-activity"));
    var failure = try fromHttpResponse(allocator, .query, &response, .known_not_accepted);
    defer failure.deinit();
    try std.testing.expectEqual(@as(?u16, 400), failure.http_status);
    try std.testing.expectEqualStrings("BadRequest", failure.detail.code.?);
    try std.testing.expectEqualStrings("Kusto.Data.Exceptions", failure.detail.error_type.?);
    try std.testing.expectEqualStrings("description", failure.detail.description.?);
    try std.testing.expectEqual(@as(?bool, true), failure.permanent);
    try std.testing.expect(!failure.retryable);
    try std.testing.expectEqualStrings("Inner", failure.detail.inner_error.?.code.?);
    try std.testing.expectEqualStrings("header-request", failure.client_request_id.?);
    try std.testing.expectEqualStrings("header-activity", failure.activity_id.?);
}

test "HTTP retryability is conservative" {
    const allocator = std.testing.allocator;
    var response = http.Response{
        .status_code = 503,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(u8, "{\"error\":{\"@permanent\":false}}"),
        .allocator = allocator,
    };
    defer response.deinit();
    var transient = try fromHttpResponse(allocator, .query, &response, .known_not_accepted);
    defer transient.deinit();
    try std.testing.expect(transient.retryable);
    response.status_code = 500;
    response.allocator.free(response.body);
    response.body = try allocator.dupe(u8, "{\"error\":{\"@permanent\":true}}");
    var permanent = try fromHttpResponse(allocator, .query, &response, .known_not_accepted);
    defer permanent.deinit();
    try std.testing.expect(!permanent.retryable);
    try std.testing.expectEqual(@as(?bool, true), permanent.permanent);
}

test "OneAPI context supplies correlation IDs without response headers" {
    const allocator = std.testing.allocator;
    var response = http.Response{
        .status_code = 400,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(u8,
            \\{"error":{"@context":{"clientRequestId":"context-request","activityId":"context-activity"}}}
        ),
        .allocator = allocator,
    };
    defer response.deinit();
    var failure = try fromHttpResponse(allocator, .query, &response, .known_not_accepted);
    defer failure.deinit();
    try std.testing.expectEqualStrings("context-request", failure.client_request_id.?);
    try std.testing.expectEqualStrings("context-activity", failure.activity_id.?);
}

test "malformed OneAPI bodies retain HTTP correlation" {
    const allocator = std.testing.allocator;
    var response = http.Response{
        .status_code = 502,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(u8, "gateway said no"),
        .allocator = allocator,
    };
    defer response.deinit();
    try response.headers.put(try allocator.dupe(u8, "x-ms-client-request-id"), try allocator.dupe(u8, "request"));
    try response.headers.put(try allocator.dupe(u8, "x-ms-activity-id"), try allocator.dupe(u8, "activity"));
    var failure = try fromHttpResponse(allocator, .query, &response, .known_not_accepted);
    defer failure.deinit();
    try std.testing.expectEqualStrings("request", failure.client_request_id.?);
    try std.testing.expectEqualStrings("activity", failure.activity_id.?);
    try std.testing.expectEqual(@as(?bool, null), failure.permanent);
    try std.testing.expect(failure.retryable);
}

fn parseFailureAllocationFixture(allocator: std.mem.Allocator) !void {
    var response = http.Response{
        .status_code = 429,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(u8,
            \\{"error":{"code":"Throttled","message":"slow down","@type":"Kusto.Error","@message":"retry later","@context":{"clientRequestId":"request","activityId":"activity"},"innererror":{"code":"Cause","message":"nested"}}}
        ),
        .allocator = allocator,
    };
    defer response.deinit();
    var failure = try fromHttpResponse(allocator, .query, &response, .known_not_accepted);
    defer failure.deinit();
    try std.testing.expect(failure.retryable);
    try std.testing.expectEqualStrings("Cause", failure.detail.inner_error.?.code.?);
}

test "Kusto errors release every allocation failure path" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        parseFailureAllocationFixture,
        .{},
    );
}
