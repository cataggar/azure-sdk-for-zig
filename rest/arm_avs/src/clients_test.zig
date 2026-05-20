//! Tests for the generated `clients.zig`.
//!
//! Kept in a separate file so the emitter can overwrite `clients.zig`
//! without losing test coverage. Wired into the package's test step via
//! `root.zig`.

const std = @import("std");
const testing = std.testing;
const core = @import("azure_core");
const clients = @import("clients.zig");
const models = @import("models.zig");

test "AVSClient.privateClouds().listInSubscription pages mock results" {
    const allocator = testing.allocator;

    const body =
        \\{"value":[{"name":"cloud-a","location":"eastus","sku":{"name":"av36"}},{"name":"cloud-b","location":"westus2","sku":{"name":"av36p"}}]}
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

    var client = try clients.AVSClient.init(allocator, .{
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
    // Generic ARM accessors from `core.arm` work because the generated
    // struct carries `pub const arm_resource_kind = .tracked` and the
    // required base fields.
    try testing.expectEqualStrings("eastus", core.arm.location(&page[0]).?);
    try testing.expectEqualStrings("westus2", core.arm.location(&page[1]).?);

    try testing.expect(try pager.next() == null);
}
