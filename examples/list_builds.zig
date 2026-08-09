//! Page through a project's builds with `ContinuationPager`.
//!
//! `Builds.list` is one of the Azure DevOps operations that returns its
//! continuation token in the `x-ms-continuationtoken` response header.
//! The generated operation surfaces it on `status_200.headers`, so the
//! pager can drive the listing to exhaustion.
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

/// Captures the sub-client and the operation's fixed parameters so the
/// pager only has to supply the continuation token.
const BuildFetcher = struct {
    builds: devops.protocol.build.Builds,
    organization: []const u8,
    project: []const u8,
    /// The header value is owned by the response, which is freed once
    /// the page is handed back, so it is copied here to outlive it.
    token_buffer: ?[]u8 = null,
    allocator: std.mem.Allocator,

    pub fn fetch(
        self: *BuildFetcher,
        allocator: std.mem.Allocator,
        token: ?[]const u8,
    ) !devops.Page(Build) {
        const result = try self.builds.list(
            allocator,
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
            null,
            null,
            null,
            null,
            null,
        );

        switch (result) {
            .status_200 => |ok| {
                defer allocator.free(ok.body);
                const items = try allocator.dupe(Build, ok.body);
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
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();

    const settings = try support.loadSettings(init.environ_map);
    const project = try support.requireProject(settings);

    var client = try support.client(allocator, settings, transport.asTransport());
    defer client.deinit();

    var build_client = client.build();
    var fetcher: BuildFetcher = .{
        .builds = build_client.builds(),
        .organization = settings.organization,
        .project = project,
        .allocator = allocator,
    };
    defer fetcher.deinit();

    var pages = devops.ContinuationPager(Build, BuildFetcher).init(&fetcher);

    var total: usize = 0;
    while (try pages.next(allocator)) |page| {
        defer allocator.free(page);
        for (page) |build| {
            total += 1;
            std.debug.print(
                "  #{s}  {s}\n",
                .{
                    build.build_number orelse "<none>",
                    if (build.status) |status| @tagName(status) else "unknown",
                },
            );
        }
    }
    std.debug.print("{d} builds in {s}\n", .{ total, project });
}
