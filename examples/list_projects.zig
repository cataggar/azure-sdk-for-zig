//! List the projects in an organization.
//!
//! ```sh
//! AZURE_DEVOPS_ORGANIZATION=contoso \
//! AZURE_DEVOPS_PAT=… \
//! zig build examples && ./zig-out/bin/devops-list-projects
//! ```

const std = @import("std");
const core = @import("azure_sdk_core");
const support = @import("devops_example_support");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();

    const settings = try support.loadSettings(init.environ_map);

    var client = try support.client(allocator, settings, transport.asTransport());
    defer client.deinit();

    // `core` is an Azure DevOps API area as well as the name of the Zig
    // Core package, so the accessor is `core_area`.
    var core_area = client.core_area();
    var projects = core_area.projects();
    const list = try projects.list(
        allocator,
        settings.organization,
        null,
        null,
        null,
        null,
        null,
    );
    defer allocator.free(list);

    std.debug.print("{d} projects in {s}\n", .{ list.len, settings.organization });
    for (list) |project| {
        std.debug.print(
            "  {s}  {s}\n",
            .{ project.name orelse "<unnamed>", project.id orelse "" },
        );
    }
}
