const std = @import("std");
const acr = @import("azure_sdk_container_registry");
const support = @import("acr_example_support");

pub fn main(init: std.process.Init) !void {
    try support.requireOptIn(
        init.environ_map,
        "AZURE_CONTAINER_REGISTRY_ALLOW_DELETE",
    );
    const endpoint = try support.required(
        init.environ_map,
        support.endpoint_environment,
    );
    const repository = try support.required(
        init.environ_map,
        support.repository_environment,
    );
    const confirmation = try support.required(
        init.environ_map,
        "AZURE_CONTAINER_REGISTRY_CONFIRM_DELETE_REPOSITORY",
    );
    if (!std.mem.eql(u8, repository, confirmation))
        return error.ContainerRegistryDeleteConfirmationMismatch;
    const tag = init.environ_map.get("AZURE_CONTAINER_REGISTRY_DELETE_TAG");
    const digest = init.environ_map.get("AZURE_CONTAINER_REGISTRY_DELETE_DIGEST");
    const delete_repository = std.mem.eql(
        u8,
        init.environ_map.get("AZURE_CONTAINER_REGISTRY_DELETE_WHOLE_REPOSITORY") orelse "",
        "1",
    );
    if (tag == null and digest == null and !delete_repository)
        return error.ContainerRegistryDeleteTargetRequired;

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

    if (tag) |value| {
        var result = try client.deleteTag(init.gpa, repository, value);
        defer result.deinit();
        _ = try support.expectDelete(&result);
    }
    if (digest) |value| {
        var content = try acr.ContainerRegistryContentClient.init(
            init.gpa,
            endpoint,
            repository,
            session.clientOptions(),
        );
        defer content.deinit();
        _ = try content.deleteManifest(value);
    }
    if (delete_repository) {
        var result = try client.deleteRepository(init.gpa, repository);
        defer result.deinit();
        _ = try support.expectDelete(&result);
    }
}
