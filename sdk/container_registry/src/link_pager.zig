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
            if (self.value[self.index] == '\r' or self.value[self.index] == '\n')
                return error.MalformedLinkHeader;
            self.index += 1;
        }
        if (self.index == self.value.len or self.index == target_start)
            return error.MalformedLinkHeader;
        const target = self.value[target_start..self.index];
        self.index += 1;

        var is_next = false;
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
            skipOws(self.value, &self.index);
            if (self.index == self.value.len or self.value[self.index] != '=')
                return error.MalformedLinkHeader;
            self.index += 1;
            skipOws(self.value, &self.index);
            const parameter = try parseParameterValue(self.value, &self.index);
            if (std.ascii.eqlIgnoreCase(name, "rel") and containsNextRelation(parameter))
                is_next = true;
        }
        return .{ .target = target, .is_next = is_next };
    }
};

fn parseParameterValue(value: []const u8, index: *usize) ![]const u8 {
    if (index.* == value.len) return error.MalformedLinkHeader;
    if (value[index.*] != '"') {
        const start = index.*;
        while (index.* < value.len and
            value[index.*] != ';' and value[index.*] != ',' and
            value[index.*] != ' ' and value[index.*] != '\t')
        {
            index.* += 1;
        }
        if (index.* == start) return error.MalformedLinkHeader;
        return value[start..index.*];
    }

    index.* += 1;
    const start = index.*;
    while (index.* < value.len and value[index.*] != '"') {
        const byte = value[index.*];
        if (byte == '\\' or byte == '\r' or byte == '\n')
            return error.MalformedLinkHeader;
        index.* += 1;
    }
    if (index.* == value.len) return error.MalformedLinkHeader;
    const result = value[start..index.*];
    index.* += 1;
    return result;
}

fn containsNextRelation(value: []const u8) bool {
    var iterator = std.mem.tokenizeAny(u8, value, " \t");
    while (iterator.next()) |relation| {
        if (std.ascii.eqlIgnoreCase(relation, "next")) return true;
    }
    return false;
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
