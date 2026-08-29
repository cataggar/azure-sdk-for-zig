//! Page through a project's builds with `ContinuationPager`.
//!
//! `Builds.list` is one of the Azure DevOps operations that returns its
//! continuation token in the `x-ms-continuationtoken` response header.
//! The generated operation surfaces it on `status_200.headers`, so the
//! pager can drive the listing to exhaustion.
//!
//! A busy project holds tens of thousands of builds, so this stops after
//! `max_pages` rather than reading them all: `next` may be abandoned at
//! any point. Drop the check to walk the whole listing.
//!
//! See `page_audit_log.zig` for the other flavour, where the token
//! arrives on the response *body* instead.
//!
//! ```sh
//! AZURE_DEVOPS_ORGANIZATION=contoso \
//! AZURE_DEVOPS_PROJECT=my-project \
//! AZURE_DEVOPS_PAT=… \
//! zig build examples && ./zig-out/bin/devops-list-builds
//! ```

const std = @import("std");
const core = @import("azure_sdk_core");
const devops = @import("azure_sdk_devops");
const support = @import("devops_example_support");

const models = devops.protocol.build.models;
const Build = models.Build;

const page_size: i32 = 25;
const max_pages: usize = 4;

/// Captures the sub-client and the operation's fixed parameters so the
/// pager only has to supply the continuation token.
const BuildFetcher = struct {
    builds: devops.protocol.build.Builds,
    organization: []const u8,
    project: []const u8,
    /// One page's worth of parsed response. Reset before each fetch, so
    /// memory stays bounded no matter how long the listing runs. Safe
    /// because the caller is done with a page before asking for the next.
    page_arena: std.heap.ArenaAllocator,
    /// The header value is owned by the response, which is discarded with
    /// the arena, so it is copied here to outlive it.
    token_buffer: ?[]u8 = null,
    allocator: std.mem.Allocator,

    pub fn fetch(
        self: *BuildFetcher,
        allocator: std.mem.Allocator,
        token: ?[]const u8,
    ) !devops.Page(Build) {
        _ = self.page_arena.reset(.retain_capacity);
        const result = try self.builds.list(
            self.page_arena.allocator(),
            self.organization,
            self.project,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            page_size,
            token,
            null,
            null,
            // Azure DevOps only issues a continuation token for this
            // operation when an explicit order is requested; with the
            // default order it returns the first page and nothing else.
            .queue_time_descending,
            null,
            null,
            null,
            null,
        );

        switch (result) {
            .status_200 => |ok| {
                const items = try allocator.dupe(Build, ok.body.value orelse &.{});
                errdefer allocator.free(items);

                if (self.token_buffer) |buffer| self.allocator.free(buffer);
                self.token_buffer = null;
                // An absent header is the end-of-collection signal.
                if (ok.headers.x_ms_continuationtoken) |next| {
                    if (next.len != 0) self.token_buffer = try self.allocator.dupe(u8, next);
                }

                return .{ .items = items, .continuation_token = self.token_buffer };
            },
        }
    }

    fn deinit(self: *BuildFetcher) void {
        if (self.token_buffer) |buffer| self.allocator.free(buffer);
        self.token_buffer = null;
        self.page_arena.deinit();
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(init.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    const settings = try support.loadSettings(init.environ_map);
    const project = try support.requireProject(settings);

    var client = try support.client(allocator, settings, runtime);
    defer client.deinit();

    var build_client = client.build();
    var fetcher: BuildFetcher = .{
        .builds = build_client.builds(),
        .organization = settings.organization,
        .project = project,
        .page_arena = .init(allocator),
        .allocator = allocator,
    };
    defer fetcher.deinit();

    var pages = devops.ContinuationPager(Build, BuildFetcher).init(&fetcher);

    var total: usize = 0;
    var page_count: usize = 0;
    while (try pages.next(allocator)) |page| {
        defer allocator.free(page);
        page_count += 1;
        for (page) |build| {
            total += 1;
            std.debug.print(
                "  #{s}  {s}\n",
                .{
                    build.build_number orelse "<none>",
                    // `toWire` gives the service's spelling, including
                    // for values this build of the SDK doesn't know.
                    if (build.status) |status| status.toWire() else "unknown",
                },
            );
        }
        if (page_count == max_pages) break;
    }
    std.debug.print(
        "{d} builds across {d} pages in {s}\n",
        .{ total, page_count, project },
    );
}
