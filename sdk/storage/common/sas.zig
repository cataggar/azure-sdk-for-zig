//! Credential-isolated helpers for operations on complete, service-issued
//! Azure Storage SAS URLs.
const std = @import("std");
const core = @import("azure_core");

/// An owned complete HTTPS SAS URL.
///
/// The URL's existing query is deliberately opaque: it is copied exactly as
/// supplied and is never parsed, decoded, reordered, or rendered by
/// `format`. Protocol parameters added by an operation are appended only
/// after the original query.
pub const CompleteSasUri = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    query_start: usize,

    pub fn init(allocator: std.mem.Allocator, value: []const u8) !CompleteSasUri {
        try validate(value);
        return .{
            .allocator = allocator,
            .bytes = try allocator.dupe(u8, value),
            .query_start = std.mem.indexOfScalar(u8, value, '?').?,
        };
    }

    pub fn deinit(self: *CompleteSasUri) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }

    /// Renders the public origin and path only. The SAS query is never
    /// included in diagnostic output.
    pub fn format(self: CompleteSasUri, writer: anytype) !void {
        try writer.print("CompleteSasUri({s}?***)", .{self.bytes[0..self.query_start]});
    }

    /// Returns whether this URI targets a recognized Azure Storage service
    /// hostname for `service` (`"blob"` or `"queue"`). This intentionally
    /// accepts public, US Government, China, and Private Link service names,
    /// but not an arbitrary host that could receive a SAS token.
    pub fn hasAzureStorageServiceHost(
        self: *const CompleteSasUri,
        service: []const u8,
    ) bool {
        const scheme_end = std.mem.indexOfScalar(u8, self.bytes, ':') orelse return false;
        const authority_start = scheme_end + 3;
        const authority_end = authority_start + (std.mem.indexOfAny(
            u8,
            self.bytes[authority_start..],
            "/?",
        ) orelse self.bytes.len - authority_start);
        const authority = self.bytes[authority_start..authority_end];
        const host = if (std.mem.lastIndexOfScalar(u8, authority, ':')) |port_start|
            authority[0..port_start]
        else
            authority;

        const suffixes = [_][]const u8{
            ".core.windows.net",
            ".core.usgovcloudapi.net",
            ".core.chinacloudapi.cn",
            ".core.cloudapi.de",
        };
        for (suffixes) |suffix| {
            var service_suffix_buffer: [64]u8 = undefined;
            const service_suffix = std.fmt.bufPrint(
                &service_suffix_buffer,
                ".{s}{s}",
                .{ service, suffix },
            ) catch return false;
            if (endsWithIgnoreCase(host, service_suffix)) return true;
        }
        return false;
    }

    /// Returns an owned URL with protocol parameters appended after the
    /// original opaque query. Only `QueryParameter.value` is percent encoded.
    pub fn appendProtocolQuery(
        self: *const CompleteSasUri,
        allocator: std.mem.Allocator,
        parameters: []const QueryParameter,
    ) ![]u8 {
        var result = std.ArrayList(u8).empty;
        errdefer result.deinit(allocator);
        try result.appendSlice(allocator, self.bytes);
        for (parameters) |parameter| {
            if (!isProtocolParameterName(parameter.name))
                return error.InvalidSasProtocolParameter;
            try result.append(allocator, '&');
            try result.appendSlice(allocator, parameter.name);
            try result.append(allocator, '=');
            try appendPercentEncoded(&result, allocator, parameter.value);
        }
        return result.toOwnedSlice(allocator);
    }

    /// Returns an owned URL with a path segment inserted before the original
    /// opaque query. Queue SAS URLs use this to address `/messages`.
    pub fn appendPathSegment(
        self: *const CompleteSasUri,
        allocator: std.mem.Allocator,
        segment: []const u8,
    ) ![]u8 {
        if (segment.len == 0 or
            std.mem.indexOfAny(u8, segment, "/?#") != null)
            return error.InvalidSasPathSegment;

        var result = std.ArrayList(u8).empty;
        errdefer result.deinit(allocator);
        const path_end = self.query_start;
        try result.appendSlice(allocator, self.bytes[0..path_end]);
        if (path_end == 0 or self.bytes[path_end - 1] != '/')
            try result.append(allocator, '/');
        try result.appendSlice(allocator, segment);
        try result.appendSlice(allocator, self.bytes[path_end..]);
        return result.toOwnedSlice(allocator);
    }

    fn validate(value: []const u8) !void {
        for (value) |byte| {
            if (byte <= 0x20 or byte >= 0x7f)
                return error.InvalidSasUri;
        }
        // Parse solely to reject malformed URLs. Rendering and query handling
        // below always use the original byte slice, not parsed components.
        _ = std.Uri.parse(value) catch return error.InvalidSasUri;

        const scheme_end = std.mem.indexOfScalar(u8, value, ':') orelse
            return error.InvalidSasUri;
        if (!std.ascii.eqlIgnoreCase(value[0..scheme_end], "https"))
            return error.SasUriMustUseHttps;
        if (value.len < scheme_end + 3 or
            !std.mem.eql(u8, value[scheme_end..][0..3], "://"))
            return error.InvalidSasUri;
        if (std.mem.indexOfScalar(u8, value, '#') != null)
            return error.SasUriFragmentNotAllowed;

        const authority_start = scheme_end + 3;
        const authority_end = authority_start + (std.mem.indexOfAny(
            u8,
            value[authority_start..],
            "/?",
        ) orelse value.len - authority_start);
        if (authority_start == authority_end)
            return error.InvalidSasUri;
        if (std.mem.indexOfScalar(u8, value[authority_start..authority_end], '@') != null)
            return error.SasUriUserInfoNotAllowed;

        const query_start = std.mem.indexOfScalar(u8, value, '?') orelse
            return error.SasQueryRequired;
        if (query_start + 1 == value.len)
            return error.SasQueryRequired;
    }
};

pub const QueryParameter = struct {
    name: []const u8,
    value: []const u8,
};

/// The outcome of a request sent through a credential-free SAS pipeline.
///
/// A received non-2xx status is known not accepted. A failure while opening
/// after transport entry is unknown because no response status was received.
/// Once a 2xx response head is received, the request is accepted even if
/// draining the response body fails.
pub const RequestOutcome = union(enum) {
    accepted: struct { status_code: u16 },
    rejected: struct { status_code: u16 },
    unknown: struct { cause: anyerror },

    pub fn isAccepted(self: RequestOutcome) bool {
        return self == .accepted;
    }

    pub fn format(self: RequestOutcome, writer: anytype) !void {
        switch (self) {
            .accepted => |value| try writer.print(
                "SasRequestOutcome(accepted, status={d})",
                .{value.status_code},
            ),
            .rejected => |value| try writer.print(
                "SasRequestOutcome(rejected, status={d})",
                .{value.status_code},
            ),
            .unknown => |value| try writer.print(
                "SasRequestOutcome(unknown, cause={s})",
                .{@errorName(value.cause)},
            ),
        }
    }
};

/// Opens one non-retrying, no-redirect request through an empty-policy
/// pipeline. No caller-supplied pipeline is accepted, so a bearer policy
/// cannot be attached to this request class.
pub fn send(
    transport: *core.http.HttpTransport,
    request: *core.http.Request,
    body: ?core.http.StreamingRequestBody,
) !RequestOutcome {
    request.retryable = false;
    request.redirect_policy = .not_allowed;
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &.{},
        .transport_impl = transport,
    };
    const operation = pipeline.open(request, .{ .body = body }) catch |err| {
        if (request.transport_started)
            return .{ .unknown = .{ .cause = err } };
        return err;
    };
    defer operation.deinit();

    const status_code = operation.status_code;
    if (!operation.isSuccess()) {
        // The response head establishes a known rejection. A body-drain
        // failure cannot turn that status into an accepted operation.
        _ = operation.finish() catch {};
        return .{ .rejected = .{ .status_code = status_code } };
    }

    _ = operation.finish() catch {};
    return .{ .accepted = .{ .status_code = status_code } };
}

fn isProtocolParameterName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |byte| {
        if (!((byte >= 'a' and byte <= 'z') or
            (byte >= 'A' and byte <= 'Z') or
            (byte >= '0' and byte <= '9') or
            byte == '-' or byte == '_' or byte == '.'))
            return false;
    }
    return true;
}

fn appendPercentEncoded(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    value: []const u8,
) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (isUnreserved(byte)) {
            try output.append(allocator, byte);
        } else {
            try output.append(allocator, '%');
            try output.append(allocator, hex[byte >> 4]);
            try output.append(allocator, hex[byte & 0x0f]);
        }
    }
}

fn isUnreserved(byte: u8) bool {
    return (byte >= 'a' and byte <= 'z') or
        (byte >= 'A' and byte <= 'Z') or
        (byte >= '0' and byte <= '9') or
        byte == '-' or byte == '.' or byte == '_' or byte == '~';
}

fn endsWithIgnoreCase(value: []const u8, suffix: []const u8) bool {
    if (value.len < suffix.len) return false;
    return std.ascii.eqlIgnoreCase(value[value.len - suffix.len ..], suffix);
}

test "complete SAS URI preserves opaque query when adding parameters" {
    const allocator = std.testing.allocator;
    var uri = try CompleteSasUri.init(
        allocator,
        "https://account.blob.core.windows.net/c/b?sp=rw&sig=a%2Bb%3D&empty=&x=1+2",
    );
    defer uri.deinit();
    const updated = try uri.appendProtocolQuery(allocator, &.{
        .{ .name = "comp", .value = "block" },
        .{ .name = "blockid", .value = "A+/=" },
    });
    defer allocator.free(updated);
    try std.testing.expectEqualStrings(
        "https://account.blob.core.windows.net/c/b?sp=rw&sig=a%2Bb%3D&empty=&x=1+2&comp=block&blockid=A%2B%2F%3D",
        updated,
    );
}

test "complete SAS URI inserts queue path before opaque query" {
    const allocator = std.testing.allocator;
    var uri = try CompleteSasUri.init(
        allocator,
        "https://account.queue.core.windows.net/q?sig=a%2Fb&sv=2024-11-04",
    );
    defer uri.deinit();
    const messages = try uri.appendPathSegment(allocator, "messages");
    defer allocator.free(messages);
    try std.testing.expectEqualStrings(
        "https://account.queue.core.windows.net/q/messages?sig=a%2Fb&sv=2024-11-04",
        messages,
    );
}

test "complete SAS URI rejects unsafe URL forms and redacts formatting" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.SasUriMustUseHttps,
        CompleteSasUri.init(allocator, "http://account.blob.core.windows.net/c?sig=x"),
    );
    try std.testing.expectError(
        error.SasUriUserInfoNotAllowed,
        CompleteSasUri.init(allocator, "https://user@account.blob.core.windows.net/c?sig=x"),
    );
    try std.testing.expectError(
        error.SasUriFragmentNotAllowed,
        CompleteSasUri.init(allocator, "https://account.blob.core.windows.net/c?sig=x#fragment"),
    );
    try std.testing.expectError(
        error.InvalidSasUri,
        CompleteSasUri.init(
            allocator,
            "https://account.blob.core.windows.net/c?sig=x\r\nX-Injected:%20yes",
        ),
    );
    try std.testing.expectError(
        error.InvalidSasUri,
        CompleteSasUri.init(allocator, "https://account.blob.core.windows.net/raw path?sig=x"),
    );
    try std.testing.expectError(
        error.SasQueryRequired,
        CompleteSasUri.init(allocator, "https://account.blob.core.windows.net/c"),
    );

    var uri = try CompleteSasUri.init(
        allocator,
        "https://account.blob.core.windows.net/c?sig=secret-value",
    );
    defer uri.deinit();
    var buffer: [256]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try writer.print("{f}", .{uri});
    try std.testing.expectEqualStrings(
        "CompleteSasUri(https://account.blob.core.windows.net/c?***)",
        buffer[0..writer.end],
    );
}

test "complete SAS URI recognizes only the intended Azure Storage service host" {
    const allocator = std.testing.allocator;
    var blob = try CompleteSasUri.init(
        allocator,
        "https://account.privatelink.blob.core.windows.net/c?sig=x",
    );
    defer blob.deinit();
    try std.testing.expect(blob.hasAzureStorageServiceHost("blob"));
    try std.testing.expect(!blob.hasAzureStorageServiceHost("queue"));

    var attacker = try CompleteSasUri.init(
        allocator,
        "https://account.blob.core.windows.net.attacker.example/c?sig=x",
    );
    defer attacker.deinit();
    try std.testing.expect(!attacker.hasAzureStorageServiceHost("blob"));
}

fn uriAllocationTest(allocator: std.mem.Allocator) !void {
    var uri = try CompleteSasUri.init(
        allocator,
        "https://account.blob.core.windows.net/c/b?sig=a%2Bb%3D&sp=rw",
    );
    defer uri.deinit();
    const block = try uri.appendProtocolQuery(allocator, &.{
        .{ .name = "comp", .value = "block" },
        .{ .name = "blockid", .value = "MDAwMDAwMDA=" },
    });
    defer allocator.free(block);
    const messages = try uri.appendPathSegment(allocator, "messages");
    defer allocator.free(messages);
}

test "complete SAS URI cleans up on every URL allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        uriAllocationTest,
        .{},
    );
}
