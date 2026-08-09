//! Continuation-token paging.
//!
//! Azure DevOps pages with an opaque continuation token rather than a
//! `nextLink` URL: a listing operation takes an optional
//! `continuation_token` parameter and reports the next one either in the
//! `x-ms-continuationtoken` response header or in a `continuationToken`
//! field on the response body. There is no absolute URL to follow, so
//! Core's `PipelinePager` — which re-sends a server-supplied link — does
//! not apply; the caller has to re-invoke the same operation with the new
//! token.
//!
//! Only the body-field form is reachable through the generated clients
//! today: the Azure DevOps Swagger does not declare the
//! `x-ms-continuationtoken` response header, so the generated operations
//! do not return it.
//!
//! `ContinuationPager` owns that loop so callers write a `while` instead
//! of hand-rolling token plumbing:
//!
//! ```zig
//! var pages = ContinuationPager(models.WorkItem, Fetcher).init(&fetcher);
//! while (try pages.next(allocator)) |page| {
//!     defer allocator.free(page);
//!     for (page) |work_item| { … }
//! }
//! ```

const std = @import("std");

/// One page of results plus the token that reaches the next one.
pub fn Page(comptime T: type) type {
    return struct {
        items: []T,
        /// Token for the following page, or null on the last page.
        /// Owned by the fetcher, which must keep it alive until the next
        /// `next` call.
        continuation_token: ?[]const u8 = null,
    };
}

/// Drives a paged Azure DevOps listing operation to exhaustion.
///
/// `Fetcher` is any type with:
///
/// ```zig
/// pub fn fetch(self: *Fetcher, allocator: std.mem.Allocator, token: ?[]const u8) !Page(T)
/// ```
///
/// which is normally a small struct capturing the area sub-client and
/// the operation's fixed parameters.
pub fn ContinuationPager(comptime T: type, comptime Fetcher: type) type {
    return struct {
        fetcher: *Fetcher,
        token: ?[]const u8 = null,
        /// False until the first fetch, so a listing whose very first
        /// page is empty still performs one request.
        started: bool = false,
        exhausted: bool = false,

        const Self = @This();

        pub fn init(fetcher: *Fetcher) Self {
            return .{ .fetcher = fetcher };
        }

        /// Fetch the next page, or null once the service stops returning
        /// a continuation token. The caller owns the returned slice.
        pub fn next(self: *Self, allocator: std.mem.Allocator) !?[]T {
            if (self.exhausted) return null;
            const page = try self.fetcher.fetch(allocator, self.token);
            self.started = true;
            self.token = page.continuation_token;
            if (page.continuation_token == null) self.exhausted = true;
            return page.items;
        }

        /// Collect every remaining page into one slice. Convenient for
        /// small listings; prefer `next` when a listing may be large.
        /// The caller owns the returned slice.
        pub fn collect(self: *Self, allocator: std.mem.Allocator) ![]T {
            var all: std.ArrayList(T) = .empty;
            errdefer all.deinit(allocator);
            while (try self.next(allocator)) |page| {
                defer allocator.free(page);
                try all.appendSlice(allocator, page);
            }
            return all.toOwnedSlice(allocator);
        }
    };
}

const TestFetcher = struct {
    pages: []const []const u32,
    tokens: []const ?[]const u8,
    index: usize = 0,
    seen_tokens: [4]?[]const u8 = @splat(null),

    fn fetch(self: *TestFetcher, allocator: std.mem.Allocator, token: ?[]const u8) !Page(u32) {
        self.seen_tokens[self.index] = token;
        const items = try allocator.dupe(u32, self.pages[self.index]);
        const next_token = self.tokens[self.index];
        self.index += 1;
        return .{ .items = items, .continuation_token = next_token };
    }
};

test "paging stops when the service returns no continuation token" {
    const pages = [_][]const u32{ &.{ 1, 2 }, &.{3} };
    const tokens = [_]?[]const u8{ "page-2", null };
    var fetcher: TestFetcher = .{ .pages = &pages, .tokens = &tokens };
    var pager = ContinuationPager(u32, TestFetcher).init(&fetcher);

    const collected = try pager.collect(std.testing.allocator);
    defer std.testing.allocator.free(collected);
    try std.testing.expectEqualSlices(u32, &.{ 1, 2, 3 }, collected);
    try std.testing.expectEqual(@as(usize, 2), fetcher.index);
}

test "each request carries the token from the previous response" {
    const pages = [_][]const u32{ &.{1}, &.{2} };
    const tokens = [_]?[]const u8{ "page-2", null };
    var fetcher: TestFetcher = .{ .pages = &pages, .tokens = &tokens };
    var pager = ContinuationPager(u32, TestFetcher).init(&fetcher);

    const collected = try pager.collect(std.testing.allocator);
    defer std.testing.allocator.free(collected);
    try std.testing.expect(fetcher.seen_tokens[0] == null);
    try std.testing.expectEqualStrings("page-2", fetcher.seen_tokens[1].?);
}

test "an empty first page still performs one request" {
    const pages = [_][]const u32{&.{}};
    const tokens = [_]?[]const u8{null};
    var fetcher: TestFetcher = .{ .pages = &pages, .tokens = &tokens };
    var pager = ContinuationPager(u32, TestFetcher).init(&fetcher);

    const first = (try pager.next(std.testing.allocator)).?;
    defer std.testing.allocator.free(first);
    try std.testing.expectEqual(@as(usize, 0), first.len);
    try std.testing.expect((try pager.next(std.testing.allocator)) == null);
    try std.testing.expectEqual(@as(usize, 1), fetcher.index);
}
