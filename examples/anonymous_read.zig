const std = @import("std");
const core = @import("azure_sdk_core");
const acr = @import("azure_sdk_container_registry");
const support = @import("acr_example_support");

pub fn main(init: std.process.Init) !void {
    const endpoint = try support.required(
        init.environ_map,
        support.endpoint_environment,
    );
    const repository = try support.required(
        init.environ_map,
        support.repository_environment,
    );
    const reference = try support.required(
        init.environ_map,
        "AZURE_CONTAINER_REGISTRY_MANIFEST_REFERENCE",
    );

    var transport = core.http.StdHttpTransport.init(init.gpa, init.io);
    defer transport.deinit();
    var content = try acr.ContainerRegistryContentClient.init(
        init.gpa,
        endpoint,
        repository,
        .{
            .transport = transport.asTransport(),
            .authentication = .anonymous,
        },
    );
    defer content.deinit();

    var manifest = try content.downloadManifest(reference);
    defer manifest.deinit(init.gpa);
    std.debug.print(
        "anonymous manifest: digest={s} media-type={s} bytes={d}\n",
        .{ manifest.digest, manifest.media_type, manifest.bytes.len },
    );
}
