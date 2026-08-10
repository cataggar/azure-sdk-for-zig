//! Run a WIQL query and print the matching work items.
//!
//! ```sh
//! AZURE_DEVOPS_ORGANIZATION=contoso \
//! AZURE_DEVOPS_PROJECT=my-project \
//! AZURE_DEVOPS_PAT=… \
//! zig build examples && ./zig-out/bin/devops-query-work-items
//! ```

const std = @import("std");
const core = @import("azure_sdk_core");
const devops = @import("azure_sdk_devops");
const support = @import("devops_example_support");

const wiql_query =
    \\SELECT [System.Id], [System.Title], [System.State]
    \\FROM WorkItems
    \\WHERE [System.WorkItemType] = 'Bug'
    \\ORDER BY [System.ChangedDate] DESC
;

pub fn main(init: std.process.Init) !void {
    // The parsed response owns a string per field; an arena frees the
    // whole graph at once rather than walking it.
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();

    const settings = try support.loadSettings(init.environ_map);
    const project = try support.requireProject(settings);

    var client = try support.client(allocator, settings, transport.asTransport());
    defer client.deinit();

    var wit = client.workItemTracking();
    var wiql = wit.wiqlOperations();
    const result = try wiql.queryByWiql(
        allocator,
        settings.organization,
        project,
        "",
        null,
        20,
        .{ .query = wiql_query },
    );

    const references = result.work_items orelse &.{};
    std.debug.print("{d} matching work items\n", .{references.len});
    for (references) |reference| {
        std.debug.print("  #{?d}  {s}\n", .{ reference.id, reference.url orelse "" });
    }
}
