const std = @import("std");
const http = @import("http/transport.zig");
const pipeline_mod = @import("http/pipeline.zig");

/// Generic response wrapper — parsed value `T` + raw HTTP response metadata.
pub fn AzureResponse(comptime T: type) type {
    return struct {
        value: T,
        status_code: u16,
        raw_body: []const u8,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.raw_body);
        }
    };
}

/// Paged response that lazily fetches continuation pages.
///
/// Superseded by `pager.PipelinePager` which provides a proper iterator
/// interface. Kept for backward compatibility.
pub fn PagedResponse(comptime T: type) type {
    return struct {
        items: []T,
        next_link: ?[]const u8 = null,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn hasMore(self: Self) bool {
            return self.next_link != null;
        }

        /// Fetch the next page using the stored next_link URL.
        ///
        /// `parseFn` receives the allocator and response body, and must return
        /// a new `Self` (items + optional next_link for further pages).
        pub fn fetchNextPage(
            self: *Self,
            pipeline: *pipeline_mod.HttpPipeline,
            parseFn: *const fn (std.mem.Allocator, []const u8) anyerror!Self,
        ) !Self {
            const link = self.next_link orelse return error.NoMorePages;
            const allocator = self.allocator;

            var req = http.Request.init(allocator, .GET, link);
            defer req.deinit();
            try req.setHeader("Accept", "application/json");

            var resp = try pipeline.send(&req);
            defer resp.deinit();

            if (!resp.isSuccess()) {
                @import("pager.zig").logHttpError("PagedResponse.fetchNextPage", resp.status_code, resp.body);
                return error.PageFetchFailed;
            }

            return parseFn(allocator, resp.body);
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }
    };
}

test "AzureResponse basic" {
    const Resp = AzureResponse(u32);
    var r = Resp{
        .value = 42,
        .status_code = 200,
        .raw_body = try std.testing.allocator.dupe(u8, "body"),
        .allocator = std.testing.allocator,
    };
    defer r.deinit();
    try std.testing.expectEqual(@as(u32, 42), r.value);
}

test "PagedResponse hasMore" {
    const Page = PagedResponse(u8);
    const items = try std.testing.allocator.alloc(u8, 0);
    var p = Page{ .items = items, .next_link = null, .allocator = std.testing.allocator };
    defer p.deinit();
    try std.testing.expect(!p.hasMore());

    var p2 = Page{
        .items = try std.testing.allocator.alloc(u8, 0),
        .next_link = "https://next",
        .allocator = std.testing.allocator,
    };
    defer p2.deinit();
    try std.testing.expect(p2.hasMore());
}
