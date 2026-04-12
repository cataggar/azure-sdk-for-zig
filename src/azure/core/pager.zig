const std = @import("std");
const pipeline_mod = @import("http/pipeline.zig");
const transport = @import("http/transport.zig");

/// Generic iterator over pages of Azure API results.
///
/// Concrete implementations embed this struct and use `@fieldParentPtr`
/// to recover their state, following the same pattern as `HttpTransport`
/// and `TokenCredential`.
pub fn Pager(comptime T: type) type {
    return struct {
        nextFn: *const fn (self: *@This()) anyerror!?[]T,
        deinitFn: *const fn (self: *@This()) void,

        const Self = @This();

        /// Fetch the next page of items, or null when all pages are consumed.
        pub fn next(self: *Self) !?[]T {
            return self.nextFn(self);
        }

        /// Release pager-owned resources (e.g., continuation URL).
        pub fn deinit(self: *Self) void {
            self.deinitFn(self);
        }
    };
}

/// Result of parsing a single page from an API response body.
pub fn PageResult(comptime T: type) type {
    return struct {
        items: []T,
        /// Heap-allocated URL for the next page, or null if this is the last page.
        next_link: ?[]u8 = null,
    };
}

/// Concrete pager that fetches pages via an `HttpPipeline`.
///
/// Handles the common Azure pattern: send GET to a URL, parse the response
/// body into items + an optional continuation URL, repeat.
///
/// Usage:
/// ```
/// var pager = try PipelinePager(Secret).init(pipeline, url, alloc, parseFn, "application/json");
/// defer pager.deinit();
/// while (try pager.next()) |items| {
///     defer allocator.free(items);
///     for (items) |item| { ... }
/// }
/// ```
pub fn PipelinePager(comptime T: type) type {
    return struct {
        pipeline: pipeline_mod.HttpPipeline,
        next_url: ?[]u8,
        allocator: std.mem.Allocator,
        accept_header: []const u8,
        pager: Pager(T),
        parseFn: *const fn (allocator: std.mem.Allocator, body: []const u8) anyerror!PageResult(T),

        const Self = @This();

        pub fn init(
            pipeline: pipeline_mod.HttpPipeline,
            initial_url: []const u8,
            allocator: std.mem.Allocator,
            parseFn: *const fn (std.mem.Allocator, []const u8) anyerror!PageResult(T),
            accept_header: []const u8,
        ) !Self {
            return .{
                .pipeline = pipeline,
                .next_url = try allocator.dupe(u8, initial_url),
                .allocator = allocator,
                .accept_header = accept_header,
                .pager = .{ .nextFn = &nextImpl, .deinitFn = &deinitImpl },
                .parseFn = parseFn,
            };
        }

        /// Return a pointer to the embedded Pager interface.
        pub fn asPager(self: *Self) *Pager(T) {
            return &self.pager;
        }

        /// Fetch the next page directly (without going through the interface).
        pub fn next(self: *Self) !?[]T {
            return self.asPager().next();
        }

        /// Free pager-owned state.
        pub fn deinit(self: *Self) void {
            if (self.next_url) |url| self.allocator.free(url);
            self.next_url = null;
        }

        fn nextImpl(pager_ptr: *Pager(T)) anyerror!?[]T {
            const self: *Self = @fieldParentPtr("pager", pager_ptr);
            const url = self.next_url orelse return null;

            var req = transport.Request.init(self.allocator, .GET, url);
            defer req.deinit();
            try req.setHeader("Accept", self.accept_header);

            var resp = try self.pipeline.send(&req);
            defer resp.deinit();

            // Free the URL we just consumed before potentially setting a new one.
            self.allocator.free(url);
            self.next_url = null;

            if (!resp.isSuccess()) return error.PageFetchFailed;

            const result = try self.parseFn(self.allocator, resp.body);
            self.next_url = result.next_link;
            return result.items;
        }

        fn deinitImpl(pager_ptr: *Pager(T)) void {
            const self: *Self = @fieldParentPtr("pager", pager_ptr);
            self.deinit();
        }
    };
}

// ─────────────────────────── Tests ───────────────────────────

fn parseTestPage(allocator: std.mem.Allocator, body: []const u8) !PageResult([]const u8) {
    const parsed = std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{}) catch
        return .{ .items = try allocator.alloc([]const u8, 0) };
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return .{ .items = try allocator.alloc([]const u8, 0) };

    var next_link: ?[]u8 = null;
    if (obj.get("nextLink")) |nl| {
        if (nl == .string and nl.string.len > 0)
            next_link = try allocator.dupe(u8, nl.string);
    }

    const values_arr = if (obj.get("value")) |v| (if (v == .array) v.array.items else null) else null;
    const values = values_arr orelse
        return .{ .items = try allocator.alloc([]const u8, 0), .next_link = next_link };

    var items = try allocator.alloc([]const u8, values.len);
    for (values, 0..) |item, i| {
        if (item == .string) {
            items[i] = try allocator.dupe(u8, item.string);
        } else {
            items[i] = try allocator.dupe(u8, "");
        }
    }
    return .{ .items = items, .next_link = next_link };
}

test "PipelinePager single page" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 200,
        \\{"value":["a","b","c"]}
    );
    defer mock.deinit();

    var pip = PipelinePager([]const u8).init(
        .{ .policies = &.{}, .transport_impl = mock.asTransport() },
        "https://example.com/items",
        allocator,
        &parseTestPage,
        "application/json",
    ) catch unreachable;
    defer pip.deinit();

    const items = (try pip.next()) orelse return error.ExpectedPage;
    defer {
        for (items) |item| allocator.free(item);
        allocator.free(items);
    }
    try std.testing.expectEqual(@as(usize, 3), items.len);
    try std.testing.expectEqualStrings("a", items[0]);
    try std.testing.expectEqualStrings("b", items[1]);
    try std.testing.expectEqualStrings("c", items[2]);

    // No more pages.
    const none = try pip.next();
    try std.testing.expect(none == null);
}

test "PipelinePager multiple pages" {
    const allocator = std.testing.allocator;
    const responses = [_]transport.SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body = 
        \\{"value":["page1-a"],"nextLink":"https://example.com/items?page=2"}
        },
        .{ .status = 200, .body = 
        \\{"value":["page2-a","page2-b"]}
        },
    };
    var seq = transport.SequenceMockTransport.init(allocator, &responses);

    var pip = PipelinePager([]const u8).init(
        .{ .policies = &.{}, .transport_impl = seq.asTransport() },
        "https://example.com/items",
        allocator,
        &parseTestPage,
        "application/json",
    ) catch unreachable;
    defer pip.deinit();

    // Page 1
    const p1 = (try pip.next()) orelse return error.ExpectedPage;
    defer {
        for (p1) |item| allocator.free(item);
        allocator.free(p1);
    }
    try std.testing.expectEqual(@as(usize, 1), p1.len);
    try std.testing.expectEqualStrings("page1-a", p1[0]);

    // Page 2
    const p2 = (try pip.next()) orelse return error.ExpectedPage;
    defer {
        for (p2) |item| allocator.free(item);
        allocator.free(p2);
    }
    try std.testing.expectEqual(@as(usize, 2), p2.len);
    try std.testing.expectEqualStrings("page2-a", p2[0]);

    // Done
    try std.testing.expect(try pip.next() == null);
}

test "PipelinePager error propagation" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 500, "server error");
    defer mock.deinit();

    var pip = PipelinePager([]const u8).init(
        .{ .policies = &.{}, .transport_impl = mock.asTransport() },
        "https://example.com/items",
        allocator,
        &parseTestPage,
        "application/json",
    ) catch unreachable;
    defer pip.deinit();

    try std.testing.expectError(error.PageFetchFailed, pip.next());
}

test "Pager interface via asPager" {
    const allocator = std.testing.allocator;
    var mock = transport.MockTransport.init(allocator, 200,
        \\{"value":["x"]}
    );
    defer mock.deinit();

    var pip = PipelinePager([]const u8).init(
        .{ .policies = &.{}, .transport_impl = mock.asTransport() },
        "https://example.com/items",
        allocator,
        &parseTestPage,
        "application/json",
    ) catch unreachable;

    // Use through the Pager interface.
    var pager = pip.asPager();
    const items = (try pager.next()) orelse {
        pager.deinit();
        return error.ExpectedPage;
    };
    defer {
        for (items) |item| allocator.free(item);
        allocator.free(items);
    }
    pager.deinit();

    try std.testing.expectEqual(@as(usize, 1), items.len);
    try std.testing.expectEqualStrings("x", items[0]);
}
