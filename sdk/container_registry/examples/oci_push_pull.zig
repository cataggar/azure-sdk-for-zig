const std = @import("std");
const acr = @import("azure_sdk_container_registry");
const support = @import("acr_example_support");

const config_bytes = "{}";
const artifact_type = "application/vnd.azure.sdk-for-zig.example.v1";
const layer_media_type =
    "application/vnd.azure.sdk-for-zig.example.layer.v1";
const layer_bytes = "azure-sdk-for-zig OCI artifact payload\n";

pub fn main(init: std.process.Init) !void {
    try support.requireOptIn(
        init.environ_map,
        "AZURE_CONTAINER_REGISTRY_ALLOW_WRITES",
    );
    const endpoint = try support.required(
        init.environ_map,
        support.endpoint_environment,
    );
    const repository = try support.required(
        init.environ_map,
        support.repository_environment,
    );
    const tag = init.environ_map.get("AZURE_CONTAINER_REGISTRY_TAG") orelse
        "azure-sdk-for-zig-example";

    const session = try support.AuthenticatedSession.create(
        init.gpa,
        init.io,
        init.environ_map,
    );
    defer session.deinit();
    var content = try acr.ContainerRegistryContentClient.init(
        init.gpa,
        endpoint,
        repository,
        session.clientOptions(),
    );
    defer content.deinit();

    var config = try content.uploadBlobBytes(config_bytes, .{});
    defer config.deinit();
    var layer = try content.uploadBlobBytes(layer_bytes, .{});
    defer layer.deinit();
    const expected_config_digest = acr.computeSha256Digest(config_bytes);
    const expected_layer_digest = acr.computeSha256Digest(layer_bytes);
    if (config.size != config_bytes.len or
        !try acr.sha256DigestsEqual(config.digest, &expected_config_digest))
    {
        return error.ContainerRegistryConfigDescriptorMismatch;
    }
    if (layer.size != layer_bytes.len or
        !try acr.sha256DigestsEqual(layer.digest, &expected_layer_digest))
    {
        return error.ContainerRegistryLayerDescriptorMismatch;
    }
    const manifest_bytes = try std.fmt.allocPrint(
        init.gpa,
        "{{\"schemaVersion\":2,\"mediaType\":\"application/vnd.oci.image.manifest.v1+json\"," ++
            "\"artifactType\":\"{s}\"," ++
            "\"config\":{{\"mediaType\":\"application/vnd.oci.empty.v1+json\"," ++
            "\"digest\":\"{s}\",\"size\":{d}}},\"layers\":[{{\"mediaType\":" ++
            "\"{s}\",\"digest\":\"{s}\"," ++
            "\"size\":{d}}}]}}",
        .{
            artifact_type,
            config.digest,
            config.size,
            layer_media_type,
            layer.digest,
            layer.size,
        },
    );
    defer init.gpa.free(manifest_bytes);

    var uploaded = try content.uploadManifest(manifest_bytes, .{
        .reference = tag,
        .media_type = .oci_image_manifest,
    });
    defer uploaded.deinit(init.gpa);
    var downloaded = try content.downloadManifest(uploaded.digest);
    defer downloaded.deinit(init.gpa);
    if (!std.mem.eql(u8, manifest_bytes, downloaded.bytes))
        return error.ContainerRegistryManifestRoundTripMismatch;
    const expected_manifest_digest = acr.computeSha256Digest(manifest_bytes);
    if (!try acr.sha256DigestsEqual(
        uploaded.digest,
        &expected_manifest_digest,
    )) return error.ContainerRegistryManifestDescriptorMismatch;

    var blobs = try acr.BlobDownloadClient.init(
        init.gpa,
        endpoint,
        repository,
        session.clientOptions(),
    );
    defer blobs.deinit();
    var pulled_config = try blobs.downloadBlob(config.digest, .{
        .max_size = 1024,
    });
    defer pulled_config.deinit();
    if (!std.mem.eql(u8, config_bytes, pulled_config.bytes))
        return error.ContainerRegistryConfigRoundTripMismatch;
    var pulled_layer = try blobs.downloadBlob(layer.digest, .{
        .max_size = 1024 * 1024,
    });
    defer pulled_layer.deinit();
    if (!std.mem.eql(u8, layer_bytes, pulled_layer.bytes))
        return error.ContainerRegistryBlobRoundTripMismatch;

    std.debug.print(
        "pushed and pulled {s}:{s} ({s})\n",
        .{ repository, tag, uploaded.digest },
    );
}
