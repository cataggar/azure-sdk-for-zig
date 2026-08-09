//! List a project's most recent builds.
//!
//! ```sh
//! AZURE_DEVOPS_ORGANIZATION=contoso \
//! AZURE_DEVOPS_PROJECT=my-project \
//! AZURE_DEVOPS_PAT=… \
//! zig build examples && ./zig-out/bin/devops-list-builds
//! ```
//!
//! `Builds.list` reports its continuation token in the
//! `x-ms-continuationtoken` response header, which the Azure DevOps
//! Swagger does not declare and the generated operation therefore does
//! not return. Until it does, this asks for one bounded page via `$top`.
//! See `page_audit_log.zig` for paging an operation whose token *is* in
//! the response body.

const std = @import("std");
const core = @import("azure_sdk_core");
const support = @import("devops_example_support");

const page_size: i32 = 25;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    var transport = core.http.StdHttpTransport.init(allocator, init.io);
    defer transport.deinit();

    const settings = try support.loadSettings(init.environ_map);
    const project = try support.requireProject(settings);

    var client = try support.client(allocator, settings, transport.asTransport());
    defer client.deinit();

    var build_client = client.build();
    var builds = build_client.builds();
    const list = try builds.list(
        allocator,
        settings.organization,
        project,
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
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
    );
    defer allocator.free(list);

    std.debug.print("{d} most recent builds in {s}\n", .{ list.len, project });
    for (list) |build| {
        std.debug.print(
            "  #{s}  {s}\n",
            .{
                build.build_number orelse "<none>",
                if (build.status) |status| @tagName(status) else "unknown",
            },
        );
    }
}
