const std = @import("std");
const core = @import("azure_core");
const service_error = @import("service_error.zig");

pub fn LinkPager(comptime Page: type) type {
    return struct {
        allocator: std.mem.Allocator,
        pipeline: core.pipeline.HttpPipeline,
        trusted_origin: []u8,
        next_url: ?[]u8,
        parsePage: *const fn (std.mem.Allocator, []const u8) anyerror!Page,

        const Self = @This();
        pub const NextResult = service_error.Result(Page);

        pub fn init(
            allocator: std.mem.Allocator,
            pipeline: core.pipeline.HttpPipeline,
            trusted_origin: []const u8,
            initial_url: []const u8,
            parsePage: *const fn (std.mem.Allocator, []const u8) anyerror!Page,
        ) !Self {
            const owned_origin = try allocator.dupe(u8, trusted_origin);
            errdefer allocator.free(owned_origin);
            const owned_url = try allocator.dupe(u8, initial_url);
            return .{
                .allocator = allocator,
                .pipeline = pipeline,
                .trusted_origin = owned_origin,
                .next_url = owned_url,
                .parsePage = parsePage,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.trusted_origin);
            if (self.next_url) |url| self.allocator.free(url);
            self.* = undefined;
        }

        pub fn next(self: *Self) !?NextResult {
            const current_url = self.next_url orelse return null;
            self.next_url = null;
            defer self.allocator.free(current_url);

            var request = core.http.Request.init(self.allocator, .GET, current_url);
            defer request.deinit();
            try request.setHeader("Accept", "application/json");

            var response = try self.pipeline.send(&request);
            defer response.deinit();
            if (response.status_code != 200) {
                return .{ .err = try service_error.ServiceError.fromResponse(
                    self.allocator,
                    &response,
                ) };
            }

            const next_url = try continuationFromResponse(
                self.allocator,
                current_url,
                self.trusted_origin,
                &response,
            );
            errdefer if (next_url) |url| self.allocator.free(url);
            var page = try self.parsePage(self.allocator, response.body);
            errdefer page.deinit();
            self.next_url = next_url;
            return .{ .ok = page };
        }
    };
}

pub fn continuationFromResponse(
    allocator: std.mem.Allocator,
    current_url: []const u8,
    trusted_origin: []const u8,
    response: *const core.http.Response,
) !?[]u8 {
    const header_values = try response.getHeaderValues(allocator, "Link");
    defer allocator.free(header_values);

    var continuation: ?[]u8 = null;
    errdefer if (continuation) |url| allocator.free(url);
    for (header_values) |header| {
        if (std.mem.trim(u8, header, " \t").len == 0)
            return error.MalformedLinkHeader;
        var iterator = LinkIterator{ .value = header };
        while (try iterator.next()) |link| {
            if (!link.is_next) continue;
            if (continuation != null) return error.AmbiguousContinuationLink;
            continuation = try resolveTrustedContinuation(
                allocator,
                current_url,
                trusted_origin,
                link.target,
            );
        }
    }
    return continuation;
}

const ParsedLink = struct {
    target: []const u8,
    is_next: bool,
};

const LinkIterator = struct {
    value: []const u8,
    index: usize = 0,

    fn next(self: *LinkIterator) !?ParsedLink {
        skipOws(self.value, &self.index);
        if (self.index == self.value.len) return null;
        if (self.value[self.index] != '<') return error.MalformedLinkHeader;
        self.index += 1;
        const target_start = self.index;
        while (self.index < self.value.len and self.value[self.index] != '>') {
            if (!isUriReferenceByte(self.value[self.index]))
                return error.MalformedLinkHeader;
            if (self.value[self.index] == '%') {
                if (self.index + 2 >= self.value.len or
                    !std.ascii.isHex(self.value[self.index + 1]) or
                    !std.ascii.isHex(self.value[self.index + 2]))
                {
                    return error.MalformedLinkHeader;
                }
                self.index += 3;
                continue;
            }
            self.index += 1;
        }
        if (self.index == self.value.len or self.index == target_start)
            return error.MalformedLinkHeader;
        const target = self.value[target_start..self.index];
        self.index += 1;

        var is_next = false;
        var rel_seen = false;
        var has_anchor = false;
        while (true) {
            skipOws(self.value, &self.index);
            if (self.index == self.value.len) break;
            if (self.value[self.index] == ',') {
                self.index += 1;
                break;
            }
            if (self.value[self.index] != ';') return error.MalformedLinkHeader;
            self.index += 1;
            skipOws(self.value, &self.index);
            const name_start = self.index;
            while (self.index < self.value.len and isParameterNameByte(self.value[self.index]))
                self.index += 1;
            if (self.index == name_start) return error.MalformedLinkHeader;
            const name = self.value[name_start..self.index];
            const is_rel = std.ascii.eqlIgnoreCase(name, "rel");
            const is_anchor = std.ascii.eqlIgnoreCase(name, "anchor");
            skipOws(self.value, &self.index);
            if (self.index == self.value.len or self.value[self.index] != '=') {
                if (is_rel and !rel_seen) rel_seen = true;
                if (is_anchor) has_anchor = true;
                continue;
            }
            self.index += 1;
            skipOws(self.value, &self.index);
            const parameter = try parseParameterValue(self.value, &self.index);
            if (is_rel and !rel_seen) {
                rel_seen = true;
                is_next = containsNextRelation(parameter);
            }
            if (is_anchor) has_anchor = true;
        }
        return .{ .target = target, .is_next = is_next and !has_anchor };
    }
};

const ParameterValue = struct {
    bytes: []const u8,
    quoted: bool,
};

fn parseParameterValue(value: []const u8, index: *usize) !ParameterValue {
    if (index.* == value.len) return error.MalformedLinkHeader;
    if (value[index.*] != '"') {
        const start = index.*;
        while (index.* < value.len and isParameterNameByte(value[index.*]))
            index.* += 1;
        if (index.* == start) return error.MalformedLinkHeader;
        return .{ .bytes = value[start..index.*], .quoted = false };
    }

    index.* += 1;
    const start = index.*;
    while (index.* < value.len and value[index.*] != '"') {
        const byte = value[index.*];
        if (byte == '\\') {
            index.* += 1;
            if (index.* == value.len or !isQuotedPairByte(value[index.*]))
                return error.MalformedLinkHeader;
        } else if (!isQuotedTextByte(byte)) {
            return error.MalformedLinkHeader;
        }
        index.* += 1;
    }
    if (index.* == value.len) return error.MalformedLinkHeader;
    const result = ParameterValue{
        .bytes = value[start..index.*],
        .quoted = true,
    };
    index.* += 1;
    return result;
}

fn containsNextRelation(value: ParameterValue) bool {
    var index: usize = 0;
    var relation_length: usize = 0;
    var matches_next = true;
    while (nextDecodedByte(value, &index)) |byte| {
        if (byte == ' ' or byte == '\t') {
            if (relation_length == "next".len and matches_next) return true;
            relation_length = 0;
            matches_next = true;
            continue;
        }
        if (relation_length >= "next".len or
            std.ascii.toLower(byte) != "next"[relation_length])
        {
            matches_next = false;
        }
        relation_length += 1;
    }
    return relation_length == "next".len and matches_next;
}

fn nextDecodedByte(value: ParameterValue, index: *usize) ?u8 {
    if (index.* == value.bytes.len) return null;
    const byte = value.bytes[index.*];
    index.* += 1;
    if (value.quoted and byte == '\\') {
        const escaped = value.bytes[index.*];
        index.* += 1;
        return escaped;
    }
    return byte;
}

fn resolveTrustedContinuation(
    allocator: std.mem.Allocator,
    current_url: []const u8,
    trusted_origin: []const u8,
    reference: []const u8,
) ![]u8 {
    const resolved = core.url.resolveUrl(allocator, current_url, reference) catch
        return error.InvalidContinuationUrl;
    errdefer allocator.free(resolved);
    const uri = std.Uri.parse(resolved) catch return error.InvalidContinuationUrl;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "https"))
        return error.ContinuationHttpsRequired;
    if (uri.host == null or uri.user != null or uri.password != null or uri.fragment != null)
        return error.InvalidContinuationUrl;
    if (!(core.url.sameOrigin(trusted_origin, resolved) catch
        return error.InvalidContinuationUrl))
    {
        return error.UntrustedContinuation;
    }
    return resolved;
}

fn skipOws(value: []const u8, index: *usize) void {
    while (index.* < value.len and
        (value[index.*] == ' ' or value[index.*] == '\t'))
    {
        index.* += 1;
    }
}

fn isParameterNameByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or switch (byte) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        else => false,
    };
}

fn isQuotedTextByte(byte: u8) bool {
    return byte == '\t' or byte == ' ' or
        (byte >= 0x21 and byte <= 0x7e and byte != '"' and byte != '\\') or
        byte >= 0x80;
}

fn isQuotedPairByte(byte: u8) bool {
    return byte == '\t' or byte == ' ' or
        (byte >= 0x21 and byte <= 0x7e) or byte >= 0x80;
}

fn isUriReferenceByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or switch (byte) {
        '-', '.', '_', '~', ':', '/', '?', '#', '[', ']', '@', '!', '$', '&', '\'', '(', ')', '*', '+', ',', ';', '=', '%' => true,
        else => false,
    };
}

test "Link parser uses only the first rel parameter" {
    const cases = [_]struct {
        value: []const u8,
        expected_next: bool,
    }{
        .{
            .value = "</first>; rel=prev; rel=next",
            .expected_next = false,
        },
        .{
            .value = "</second>; rel=next; rel=prev",
            .expected_next = true,
        },
        .{
            .value = "</third>; rel; rel=next",
            .expected_next = false,
        },
    };

    for (cases) |case| {
        var iterator = LinkIterator{ .value = case.value };
        const link = (try iterator.next()).?;
        try std.testing.expectEqual(case.expected_next, link.is_next);
        try std.testing.expect((try iterator.next()) == null);
    }
}

test "Link parser ignores next links with anchor parameters" {
    const cases = [_][]const u8{
        "</before>; anchor=context; rel=next",
        "</after>; rel=next; anchor=context",
        "</quoted>; rel=next; anchor=\"https://registry.example/context\"",
    };

    for (cases) |value| {
        var iterator = LinkIterator{ .value = value };
        const link = (try iterator.next()).?;
        try std.testing.expect(!link.is_next);
        try std.testing.expect((try iterator.next()) == null);
    }
}

test "Link continuation selects valid next beside ignored anchored link" {
    const allocator = std.testing.allocator;
    var response = core.http.Response{
        .status_code = 200,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(u8, ""),
        .allocator = allocator,
        .response_headers = core.http.ResponseHeaders.init(allocator),
    };
    defer response.deinit();
    try response.response_headers.append(
        "Link",
        "<https://evil.example/anchored>; rel=next; anchor=\"/context\", </safe>; rel=next",
    );

    const continuation = (try continuationFromResponse(
        allocator,
        "https://registry.example/current",
        "https://registry.example",
        &response,
    )).?;
    defer allocator.free(continuation);
    try std.testing.expectEqualStrings(
        "https://registry.example/safe",
        continuation,
    );
}
