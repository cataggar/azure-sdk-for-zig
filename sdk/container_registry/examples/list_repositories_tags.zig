const std = @import("std");
const acr = @import("azure_sdk_container_registry");
const support = @import("acr_example_support");

pub fn main(init: std.process.Init) !void {
    const endpoint = try support.required(
        init.environ_map,
        support.endpoint_environment,
    );
    const repository = init.environ_map.get(support.repository_environment);
    const session = try support.AuthenticatedSession.create(
        init.gpa,
        init.io,
        init.environ_map,
    );
    defer session.deinit();

    var client = try acr.ContainerRegistryClient.init(
        init.gpa,
        endpoint,
        session.clientOptions(),
    );
    defer client.deinit();

    var repositories = try client.listRepositories(init.gpa, .{});
    defer repositories.deinit();
    while (try repositories.next()) |page_value| {
        var page = page_value;
        defer page.deinit();
        switch (page) {
            .ok => |value| for (value.names) |name| {
                std.debug.print("repository: {s}\n", .{name});
            },
            .err => |failure| {
                std.log.err("{f}", .{failure});
                return error.ContainerRegistryListRepositoriesFailed;
            },
        }
    }

    if (repository) |name| {
        var tags = try client.listTagProperties(init.gpa, name, .{});
        defer tags.deinit();
        while (try tags.next()) |page_value| {
            var page = page_value;
            defer page.deinit();
            switch (page) {
                .ok => |value| for (value.items) |tag| {
                    std.debug.print(
                        "tag: {s}@{s}\n",
                        .{ tag.name, tag.digest },
                    );
                },
                .err => |failure| {
                    std.log.err("{f}", .{failure});
                    return error.ContainerRegistryListTagsFailed;
                },
            }
        }
    }
}
