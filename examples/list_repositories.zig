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
    // The parsed response owns a string per field; an arena frees the
    // whole graph at once rather than walking it.
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();

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

    var git = client.git();
    var repositories = git.repositories();
    const result = try repositories.list(
        allocator,
        settings.organization,
        project,
        null,
        null,
        null,
    );
    const list = result.value orelse &.{};

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
