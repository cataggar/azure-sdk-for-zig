const std = @import("std");
const serde = @import("serde");
const pipeline_mod = @import("http/pipeline.zig");
const transport = @import("http/transport.zig");
const url_mod = @import("url.zig");

/// Log a non-2xx HTTP response body so the developer sees the ARM/data-plane
/// error message before the generic `PageFetchFailed` propagates upward.
///
/// Output is truncated to 1024 bytes to keep tracebacks readable; the full
/// body is still in `resp.body` if a caller wants to inspect it. Logging is
/// suppressed during `zig test` (the test runner treats `.err` logs as
/// failures, but we still want the logging in real runs).
pub fn logHttpError(context: []const u8, status_code: u16, body: []const u8) void {
    if (@import("builtin").is_test) return;
    const max_len: usize = 1024;
    const snippet = if (body.len > max_len) body[0..max_len] else body;
    const elision: []const u8 = if (body.len > max_len) "..." else "";
    std.log.err("{s}: HTTP {d}: {s}{s}", .{ context, status_code, snippet, elision });
}

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
            const self: *Self = @alignCast(@fieldParentPtr("pager", pager_ptr));
            const url = self.next_url orelse return null;

            var req = transport.Request.init(self.allocator, .GET, url);
            defer req.deinit();
            try req.setHeader("Accept", self.accept_header);

            var resp = try self.pipeline.send(&req);
            defer resp.deinit();

            // Free the URL we just consumed before potentially setting a new one.
            self.allocator.free(url);
            self.next_url = null;

            if (!resp.isSuccess()) {
                logHttpError("Pager.next", resp.status_code, resp.body);
                return error.PageFetchFailed;
            }

            const result = self.parseFn(self.allocator, resp.body) catch |err| {
                logHttpError("Pager.next parse failed", resp.status_code, resp.body);
                return err;
            };
            self.next_url = result.next_link;
            return result.items;
        }

        fn deinitImpl(pager_ptr: *Pager(T)) void {
            const self: *Self = @alignCast(@fieldParentPtr("pager", pager_ptr));
            self.deinit();
        }
    };
}

// ─────────────────────────── XML marker pager ──────────────────────────────

/// Pager for Azure XML data-plane list endpoints (Blob, Queue, …).
///
/// Unlike ARM's `{ value, nextLink }` JSON envelope, these APIs return an
/// XML body whose `<NextMarker>` element carries the continuation token, and
/// the next page is fetched by setting `?marker=<token>` on the *same* URL
/// (not by following an absolute `nextLink`). Every request also needs the
/// `x-ms-version` header. `T` is the whole per-page envelope model (e.g.
/// `ListContainersResponse`), mirroring azure-sdk-for-rust's
/// `Pager<ListContainersResponse, XmlFormat>`.
///
/// `T` must expose an optional `next_marker: ?[]const u8` field; when it is
/// absent or empty the pager stops.
///
/// Each `next()` returns the deserialized envelope for one page, allocated
/// from an internal arena that is reset on the following `next()` call — so a
/// page is only valid until the next call or `deinit()`. Copy anything you
/// need to retain.
///
/// Usage:
/// ```
/// var pager = try XmlPager(ListContainersResponse).init(
///     pipeline, url, api_version, initial_marker, client_request_id, allocator);
/// defer pager.deinit();
/// while (try pager.next()) |page| {
///     for (page.container_items.items) |container| { ... }
/// }
/// ```
pub fn XmlPager(comptime T: type) type {
    if (!@hasField(T, "next_marker"))
        @compileError("XmlPager(" ++ @typeName(T) ++ ") requires a `next_marker` field");
    return struct {
        pipeline: pipeline_mod.HttpPipeline,
        allocator: std.mem.Allocator,
        arena: std.heap.ArenaAllocator,
        /// Request URL without any `marker` query pair; the pager appends it.
        base_url: []u8,
        api_version: []const u8,
        /// Optional `x-ms-client-request-id` correlation header, owned by
        /// `allocator`, set on every page request when present.
        client_request_id: ?[]u8,
        /// Continuation (or initial) marker, owned by `allocator`. Null means
        /// "no marker on the next request".
        marker: ?[]u8,
        /// False until the first page has been fetched, so that a null marker
        /// on the first call means "start" rather than "done".
        started: bool,

        const Self = @This();

        pub fn init(
            pipeline: pipeline_mod.HttpPipeline,
            initial_url: []const u8,
            api_version: []const u8,
            initial_marker: ?[]const u8,
            client_request_id: ?[]const u8,
            allocator: std.mem.Allocator,
        ) !Self {
            const base = try allocator.dupe(u8, initial_url);
            errdefer allocator.free(base);
            const marker: ?[]u8 = if (initial_marker) |m|
                try allocator.dupe(u8, m)
            else
                null;
            errdefer if (marker) |mk| allocator.free(mk);
            const crid: ?[]u8 = if (client_request_id) |c|
                try allocator.dupe(u8, c)
            else
                null;
            return .{
                .pipeline = pipeline,
                .allocator = allocator,
                .arena = std.heap.ArenaAllocator.init(allocator),
                .base_url = base,
                .api_version = api_version,
                .client_request_id = crid,
                .marker = marker,
                .started = false,
            };
        }

        /// Fetch the next page, or null when the listing is exhausted. The
        /// returned value is valid until the next `next()` or `deinit()`.
        pub fn next(self: *Self) !?T {
            if (self.started and self.marker == null) return null;

            const url = try self.buildUrl();
            defer self.allocator.free(url);

            var req = transport.Request.init(self.allocator, .GET, url);
            defer req.deinit();
            try req.setHeader("x-ms-version", self.api_version);
            try req.setHeader("Accept", "application/xml");
            if (self.client_request_id) |crid| try req.setHeader("x-ms-client-request-id", crid);

            var resp = try self.pipeline.send(&req);
            defer resp.deinit();
            if (!resp.isSuccess()) {
                logHttpError("XmlPager.next", resp.status_code, resp.body);
                return error.PageFetchFailed;
            }

            _ = self.arena.reset(.retain_capacity);
            const page = serde.xml.fromSlice(T, self.arena.allocator(), resp.body) catch |err| {
                logHttpError("XmlPager.next parse failed", resp.status_code, resp.body);
                return err;
            };

            // Advance the continuation marker. A missing/empty NextMarker
            // ends the listing.
            if (self.marker) |old| self.allocator.free(old);
            self.marker = null;
            if (page.next_marker) |nm| {
                if (nm.len > 0) self.marker = try self.allocator.dupe(u8, nm);
            }
            self.started = true;
            return page;
        }

        /// Free pager-owned state (URL, marker, and the page arena).
        pub fn deinit(self: *Self) void {
            self.arena.deinit();
            self.allocator.free(self.base_url);
            if (self.marker) |m| self.allocator.free(m);
            self.marker = null;
            if (self.client_request_id) |c| self.allocator.free(c);
            self.client_request_id = null;
        }

        fn buildUrl(self: *Self) ![]u8 {
            const marker = self.marker orelse return self.allocator.dupe(u8, self.base_url);
            const enc = try url_mod.percentEncode(self.allocator, marker);
            defer self.allocator.free(enc);
            const sep: []const u8 = if (std.mem.indexOfScalar(u8, self.base_url, '?') != null) "&" else "?";
            return std.fmt.allocPrint(self.allocator, "{s}{s}marker={s}", .{ self.base_url, sep, enc });
        }
    };
}

// ─────────────────────────── Generic page parser ───────────────────────────

/// Page parser for the standard `{ "value": [T, ...], "nextLink": "..." }`
/// envelope used by every Azure ARM list endpoint and most data-plane list
/// endpoints (Key Vault, Storage Tables, App Configuration, ...).
///
/// Returns a function pointer compatible with `PipelinePager(T).init`:
/// ```zig
/// var pager = try PipelinePager(PrivateCloud).init(
///     pipeline, url, alloc,
///     core.pager.listPageParser(PrivateCloud),
///     "application/json",
/// );
/// ```
///
/// Per-`T` cost is zero — the comptime closure stamps out one function per
/// `T` and `serde.json.fromSlice` does the rest. `T` must round-trip through
/// `serde.json`; any owned strings inside each `T` are allocated from the
/// caller's allocator and should be freed by the caller (typically via a
/// `T.deinit(allocator)` method emitted by the codegen).
pub fn listPageParser(comptime T: type) *const fn (std.mem.Allocator, []const u8) anyerror!PageResult(T) {
    return &struct {
        fn parse(allocator: std.mem.Allocator, body: []const u8) anyerror!PageResult(T) {
            const PageSchema = struct {
                value: ?[]T = null,
                nextLink: ?[]const u8 = null,
            };

            const parsed = try serde.json.fromSlice(PageSchema, allocator, body);

            var next_link: ?[]u8 = null;
            if (parsed.nextLink) |nl| {
                defer allocator.free(nl);
                if (nl.len > 0) next_link = try allocator.dupe(u8, nl);
            }
            errdefer if (next_link) |nl_dup| allocator.free(nl_dup);

            const items = parsed.value orelse try allocator.alloc(T, 0);
            return .{ .items = items, .next_link = next_link };
        }
    }.parse;
}

// ─────────────────────────── Tests ───────────────────────────

fn parseTestPage(allocator: std.mem.Allocator, body: []const u8) !PageResult([]const u8) {
    const PageSchema = struct {
        value: ?[]const []const u8 = null,
        nextLink: ?[]const u8 = null,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(PageSchema, arena.allocator(), body) catch
        return .{ .items = try allocator.alloc([]const u8, 0) };

    var next_link: ?[]u8 = null;
    if (parsed.nextLink) |nl| {
        if (nl.len > 0) next_link = try allocator.dupe(u8, nl);
    }

    const values = parsed.value orelse
        return .{ .items = try allocator.alloc([]const u8, 0), .next_link = next_link };

    var items = try allocator.alloc([]const u8, values.len);
    for (values, 0..) |s, i| {
        items[i] = try allocator.dupe(u8, s);
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

test "XmlPager paginates via NextMarker" {
    const allocator = std.testing.allocator;
    const Item = struct {
        name: []const u8,
        pub const serde = .{ .rename = .{ .name = "Name" } };
    };
    const Envelope = struct {
        containers: ContainersXml = .{},
        next_marker: ?[]const u8 = null,
        pub const ContainersXml = struct {
            items: []const Item = &.{},
            pub const serde = .{ .rename = .{ .items = "Container" } };
        };
        pub const serde = .{
            .xml_root = "EnumerationResults",
            .rename = .{ .containers = "Containers", .next_marker = "NextMarker" },
        };
    };
    const responses = [_]transport.SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body =
        \\<EnumerationResults><Containers><Container><Name>a</Name></Container></Containers><NextMarker>m2</NextMarker></EnumerationResults>
        },
        .{ .status = 200, .body =
        \\<EnumerationResults><Containers><Container><Name>b</Name></Container><Container><Name>c</Name></Container></Containers><NextMarker></NextMarker></EnumerationResults>
        },
    };
    var seq = transport.SequenceMockTransport.init(allocator, &responses);

    var pager = try XmlPager(Envelope).init(
        .{ .policies = &.{}, .transport_impl = seq.asTransport() },
        "https://example.com/?comp=list",
        "2026-06-06",
        null,
        null,
        allocator,
    );
    defer pager.deinit();

    const p1 = (try pager.next()) orelse return error.ExpectedPage;
    try std.testing.expectEqual(@as(usize, 1), p1.containers.items.len);
    try std.testing.expectEqualStrings("a", p1.containers.items[0].name);

    const p2 = (try pager.next()) orelse return error.ExpectedPage;
    try std.testing.expectEqual(@as(usize, 2), p2.containers.items.len);
    try std.testing.expectEqualStrings("b", p2.containers.items[0].name);
    try std.testing.expectEqualStrings("c", p2.containers.items[1].name);

    // Empty NextMarker ends the listing.
    try std.testing.expect(try pager.next() == null);
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

test "listPageParser handles standard envelope" {
    const allocator = std.testing.allocator;
    const Item = struct {
        name: []const u8,

        pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
            alloc.free(self.name);
        }
    };

    const body =
        \\{"value":[{"name":"alpha"},{"name":"beta"}],"nextLink":"https://example.com/next"}
    ;
    const result = try listPageParser(Item)(allocator, body);
    defer {
        for (result.items) |item| item.deinit(allocator);
        allocator.free(result.items);
        if (result.next_link) |nl| allocator.free(nl);
    }

    try std.testing.expectEqual(@as(usize, 2), result.items.len);
    try std.testing.expectEqualStrings("alpha", result.items[0].name);
    try std.testing.expectEqualStrings("beta", result.items[1].name);
    try std.testing.expect(result.next_link != null);
    try std.testing.expectEqualStrings("https://example.com/next", result.next_link.?);
}

test "listPageParser tolerates missing nextLink" {
    const allocator = std.testing.allocator;
    const Item = struct {
        id: i64,
    };
    const result = try listPageParser(Item)(allocator,
        \\{"value":[{"id":1},{"id":2},{"id":3}]}
    );
    defer allocator.free(result.items);

    try std.testing.expectEqual(@as(usize, 3), result.items.len);
    try std.testing.expectEqual(@as(i64, 2), result.items[1].id);
    try std.testing.expect(result.next_link == null);
}
