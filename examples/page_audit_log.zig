//! Page through the organization audit log with `ContinuationPager`.
//!
//! `AuditLog.query` is one of the Azure DevOps operations that returns
//! its continuation token in the response *body*, so the pager can drive
//! it to exhaustion without any header plumbing.
//!
//! Requires a PAT with the **Auditing (Read)** scope and organization
//! Project Collection Administrator rights.
//!
//! ```sh
//! AZURE_DEVOPS_ORGANIZATION=contoso \
//! AZURE_DEVOPS_PAT=… \
//! zig build examples && ./zig-out/bin/devops-page-audit-log
//! ```

const std = @import("std");
const core = @import("azure_sdk_core");
const devops = @import("azure_sdk_devops");
const support = @import("devops_example_support");

const models = devops.protocol.audit.models;
const Entry = models.DecoratedAuditLogEntry;

const batch_size: i32 = 100;

/// Captures the sub-client and the operation's fixed parameters so the
/// pager only has to supply the continuation token.
const AuditFetcher = struct {
    audit_log: devops.protocol.audit.AuditLog,
    organization: []const u8,
    /// One page's worth of parsed response. Reset before each fetch, so
    /// memory stays bounded no matter how long the listing runs. Safe
    /// because the caller is done with a page before asking for the next.
    page_arena: std.heap.ArenaAllocator,
    /// The service's token is owned by the parsed body, which is
    /// discarded with the arena, so it is copied here to outlive it.
    token_buffer: ?[]u8 = null,
    allocator: std.mem.Allocator,

    pub fn fetch(
        self: *AuditFetcher,
        allocator: std.mem.Allocator,
        token: ?[]const u8,
    ) !devops.Page(Entry) {
        _ = self.page_arena.reset(.retain_capacity);
        const result = try self.audit_log.query(
            self.page_arena.allocator(),
            self.organization,
            null,
            null,
            batch_size,
            token,
            null,
        );

        const entries = result.decorated_audit_log_entries orelse &.{};
        const items = try allocator.dupe(Entry, entries);
        errdefer allocator.free(items);

        if (self.token_buffer) |buffer| self.allocator.free(buffer);
        self.token_buffer = null;
        // `hasMore` is what tells the caller to keep going; the token
        // is repeated on the last page as well.
        if (result.has_more orelse false) {
            if (result.continuation_token) |next| {
                self.token_buffer = try self.allocator.dupe(u8, next);
            }
        }

        return .{ .items = items, .continuation_token = self.token_buffer };
    }

    fn deinit(self: *AuditFetcher) void {
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

    var client = try support.client(allocator, settings, runtime);
    defer client.deinit();

    var audit = client.audit();
    var fetcher: AuditFetcher = .{
        .audit_log = audit.auditLog(),
        .organization = settings.organization,
        .page_arena = .init(allocator),
        .allocator = allocator,
    };
    defer fetcher.deinit();

    var pages = devops.ContinuationPager(Entry, AuditFetcher).init(&fetcher);

    var total: usize = 0;
    while (try pages.next(allocator)) |page| {
        defer allocator.free(page);
        for (page) |entry| {
            total += 1;
            std.debug.print(
                "  {s}  {s}  {s}\n",
                .{
                    entry.timestamp orelse "<no timestamp>",
                    entry.action_id orelse "<no action>",
                    entry.actor_display_name orelse "",
                },
            );
        }
    }
    std.debug.print("{d} audit entries in {s}\n", .{ total, settings.organization });
}
