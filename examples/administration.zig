//! Stored access policies and service properties/statistics.
//!
//! `AZURE_DATA_TABLES_ALLOW_SERVICE_PROPERTIES_WRITE=1` is required before
//! this example changes account-wide service properties.

const std = @import("std");
const core = @import("azure_sdk_core");
const tables = @import("azure_sdk_data_tables");
const support = @import("tables_example_support");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const env = init.environ_map;
    const connection_string = try support.required(
        env,
        "AZURE_DATA_TABLES_CONNECTION_STRING",
    );
    const table_name = try support.required(env, "AZURE_DATA_TABLES_TABLE");

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();
    var service = try tables.TableServiceClient.initFromConnectionString(
        allocator,
        connection_string,
        transport.asTransport(),
        .{},
    );
    defer service.deinit();
    var table = try service.getTableClient(table_name);
    defer table.deinit();

    const identifiers = [_]tables.SignedIdentifier{.{
        .id = "example-read",
        .access_policy = .{
            .permissions = .{ .table = .{ .read = true } },
        },
    }};
    var set_acl = try table.setAccessPolicy(allocator, &identifiers, .{});
    defer set_acl.deinit();
    var acl = try table.getAccessPolicy(allocator, .{});
    defer acl.deinit();

    var properties = try service.getServiceProperties(allocator, .{});
    defer properties.deinit();
    var statistics = try service.getStatistics(allocator, .{});
    defer statistics.deinit();

    const update = tables.ServiceProperties{
        .minute_metrics = .{
            .version = "1.0",
            .enabled = false,
            .retention_policy = .{ .enabled = false },
        },
    };
    if (support.enabled(env, "AZURE_DATA_TABLES_ALLOW_SERVICE_PROPERTIES_WRITE")) {
        var changed = try service.setServiceProperties(allocator, update, .{});
        defer changed.deinit();
    }
}
