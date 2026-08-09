//! List the Git repositories in a project.
//!
//! ```sh
//! AZURE_DEVOPS_ORGANIZATION=contoso \
//! AZURE_DEVOPS_PROJECT=my-project \
//! AZURE_DEVOPS_PAT=… \
//! zig build examples && ./zig-out/bin/devops-list-repositories
//! ```

const std = @import("std");
const core = @import("azure_sdk_core");
const support = @import("devops_example_support");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();

    const settings = try support.loadSettings(init.environ_map);
    const project = try support.requireProject(settings);

    var client = try support.client(allocator, settings, transport.asTransport());
    defer client.deinit();

    var git = client.git();
    var repositories = git.repositories();
    const list = try repositories.list(
        allocator,
        settings.organization,
        project,
        null,
        null,
        null,
    );
    defer allocator.free(list);

    std.debug.print("{d} repositories in {s}\n", .{ list.len, project });
    for (list) |repository| {
        std.debug.print(
            "  {s}  default branch: {s}\n",
            .{
                repository.name orelse "<unnamed>",
                repository.default_branch orelse "<none>",
            },
        );
    }
}
