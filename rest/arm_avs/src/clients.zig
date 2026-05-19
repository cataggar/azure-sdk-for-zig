//! Service clients for Azure VMware Solution (Microsoft.AVS).
//!
//! NOTE: hand-written shim. The TypeSpec → Zig emitter does not yet emit
//! ARM sub-clients, operation bodies, ARM auth scope, or `subscription_id`
//! as a required init argument. This file represents the *shape* the
//! emitter is expected to produce. Until that lands, regenerating the
//! arm_avs package will overwrite it.
//!
//! What's missing vs. a fully generated client tree:
//!   • Only `AVSClient.privateClouds().listInSubscription(...)` is wired.
//!   • All other ARM resource collections (Clusters, Datastores, …) are
//!     omitted — add them when the emitter learns sub-client recursion.
//!   • We use a local `PrivateCloudSummary` instead of `models.PrivateCloud`
//!     because the emitter currently produces snake_case field names while
//!     ARM emits camelCase. Every generated struct needs
//!     `pub const serde = .{ .rename_all = .camel_case };` (see the
//!     `PrivateCloudSummary.Properties` block below for the pattern).

const std = @import("std");
const core = @import("azure_core");
const models = @import("models.zig");

const default_endpoint = "https://management.azure.com";
const default_api_version = "2025-09-01";
const arm_scopes: []const []const u8 = &.{"https://management.azure.com/.default"};

/// Minimal view of a Private Cloud sufficient for `listInSubscription`.
///
/// Hand-written wire-format type with `pub const serde = .{ .rename_all =
/// .camel_case }` so ARM's camelCase JSON keys map to snake_case Zig
/// fields. This is the convention the emitter is expected to apply to
/// every generated struct.
pub const PrivateCloudSummary = struct {
    id: ?[]const u8 = null,
    name: []const u8,
    location: ?[]const u8 = null,
    properties: ?Properties = null,

    pub const Properties = struct {
        provisioning_state: ?[]const u8 = null,

        pub const serde = .{ .rename_all = .camel_case };
    };
};

/// Pager type returned by `PrivateCloudsClient.listInSubscription`.
pub const PrivateCloudPager = core.pager.PipelinePager(PrivateCloudSummary);

/// Top-level Azure VMware Solution client.
///
/// Owns the bearer-token policy + pipeline; sub-clients borrow the
/// pipeline by value.
pub const AVSClient = struct {
    allocator: std.mem.Allocator,
    subscription_id: []const u8,
    endpoint: []const u8,
    api_version: []const u8,

    auth_policy: *core.pipeline.BearerTokenAuthPolicy,
    policy_ptrs: []*core.pipeline.HttpPolicy,
    pipeline: core.pipeline.HttpPipeline,

    pub const InitOptions = struct {
        subscription_id: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
        endpoint: []const u8 = default_endpoint,
        api_version: []const u8 = default_api_version,
    };

    pub fn init(allocator: std.mem.Allocator, options: InitOptions) !AVSClient {
        const auth_policy = try allocator.create(core.pipeline.BearerTokenAuthPolicy);
        errdefer allocator.destroy(auth_policy);
        auth_policy.* = core.pipeline.BearerTokenAuthPolicy.init(
            allocator,
            options.credential,
            arm_scopes,
        );

        const policy_ptrs = try allocator.alloc(*core.pipeline.HttpPolicy, 1);
        errdefer allocator.free(policy_ptrs);
        policy_ptrs[0] = auth_policy.asPolicy();

        return .{
            .allocator = allocator,
            .subscription_id = options.subscription_id,
            .endpoint = options.endpoint,
            .api_version = options.api_version,
            .auth_policy = auth_policy,
            .policy_ptrs = policy_ptrs,
            .pipeline = .{
                .policies = policy_ptrs,
                .transport_impl = options.transport,
            },
        };
    }

    pub fn deinit(self: *AVSClient) void {
        self.auth_policy.deinit();
        self.allocator.destroy(self.auth_policy);
        self.allocator.free(self.policy_ptrs);
    }

    /// Sub-client for `Microsoft.AVS/privateClouds` resources.
    pub fn privateClouds(self: *AVSClient) PrivateCloudsClient {
        return .{
            .subscription_id = self.subscription_id,
            .endpoint = self.endpoint,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

/// Sub-client for the `Microsoft.AVS/privateClouds` resource collection.
pub const PrivateCloudsClient = struct {
    subscription_id: []const u8,
    endpoint: []const u8,
    api_version: []const u8,
    pipeline: core.pipeline.HttpPipeline,

    /// `GET /subscriptions/{sub}/providers/Microsoft.AVS/privateClouds?api-version=…`
    ///
    /// Caller owns the returned pager and the items it yields. The
    /// returned pager and per-page items are allocated from `alloc`;
    /// using an arena allocator avoids per-field cleanup.
    pub fn listInSubscription(
        self: *PrivateCloudsClient,
        alloc: std.mem.Allocator,
    ) !PrivateCloudPager {
        const url = try std.fmt.allocPrint(
            alloc,
            "{s}/subscriptions/{s}/providers/Microsoft.AVS/privateClouds?api-version={s}",
            .{ self.endpoint, self.subscription_id, self.api_version },
        );
        defer alloc.free(url);

        return PrivateCloudPager.init(
            self.pipeline,
            url,
            alloc,
            core.pager.listPageParser(PrivateCloudSummary),
            "application/json",
        );
    }
};

// ─────────────────────────── Tests ───────────────────────────

const testing = std.testing;

test "AVSClient.privateClouds().listInSubscription pages mock results" {
    const allocator = testing.allocator;

    const body =
        \\{"value":[{"name":"cloud-a","sku":{"name":"av36"}},{"name":"cloud-b","sku":{"name":"av36p"}}]}
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    const Stub = struct {
        fn getTokenFn(
            _: *core.credentials.TokenCredential,
            _: core.credentials.TokenRequestContext,
            _: core.context.Context,
        ) anyerror!core.credentials.AccessToken {
            const tok = try testing.allocator.dupe(u8, "stub-token");
            return .{ .token = tok, .expires_on = std.math.maxInt(i64) };
        }
    };
    var credential = core.credentials.TokenCredential{ .getTokenFn = &Stub.getTokenFn };

    var client = try AVSClient.init(allocator, .{
        .subscription_id = "00000000-0000-0000-0000-000000000000",
        .credential = &credential,
        .transport = mock.asTransport(),
    });
    defer client.deinit();

    var pcs = client.privateClouds();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var pager = try pcs.listInSubscription(arena.allocator());

    const page = (try pager.next()) orelse return error.ExpectedPage;
    try testing.expectEqual(@as(usize, 2), page.len);
    try testing.expectEqualStrings("cloud-a", page[0].name);
    try testing.expectEqualStrings("cloud-b", page[1].name);

    try testing.expect(try pager.next() == null);
}
