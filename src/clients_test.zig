const std = @import("std");
const clients = @import("clients.zig");
const models = @import("models.zig");

test "all fourteen stable Tables operations are directly accessible" {
    try expectPublicMethods(clients.TablesClient, &.{ "table", "service" });
    try expectPublicMethods(clients.Table, &.{
        "query",
        "create",
        "delete",
        "queryEntities",
        "queryEntityWithPartitionAndRowKey",
        "updateEntity",
        "mergeEntity",
        "deleteEntity",
        "insertEntity",
        "getAccessPolicy",
        "setAccessPolicy",
    });
    try expectPublicMethods(clients.Service, &.{
        "setProperties",
        "getProperties",
        "getStatistics",
    });
    try std.testing.expect(@hasDecl(models, "TableServiceProperties"));
    try std.testing.expect(@hasDecl(models, "TableServiceStats"));
}

fn expectPublicMethods(comptime Client: type, comptime methods: []const []const u8) !void {
    inline for (methods) |method| {
        try std.testing.expect(@hasDecl(Client, method));
    }
}
