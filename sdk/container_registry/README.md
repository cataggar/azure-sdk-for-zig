# Azure Container Registry for Zig

`azure_sdk_container_registry` adds secure ACR challenge authentication,
token caching, metadata operations, Link-header paging, structured service
errors, exact-byte manifests, and bounded-memory resumable blob uploads to the
generated `azure_rest_container_registry` protocol package.

```zig
const acr = @import("azure_sdk_container_registry");

var client = try acr.ContainerRegistryClient.init(allocator, registry_endpoint, .{
    .transport = transport,
    .authentication = .{ .credential = credential },
});
defer client.deinit();

var service = client.protocolClient().containerRegistry();
try service.checkDockerV2Support(allocator);
```

The high-level client lists repositories, manifests, and tags and supports
get, update, and delete operations for their properties:

```zig
var pager = try client.listRepositories(allocator, .{ .max_results = 100 });
defer pager.deinit();

while (try pager.next()) |page_result| {
    var result = page_result;
    defer result.deinit();
    switch (result) {
        .ok => |page| {
            for (page.names) |name| {
                // use name
            }
        },
        .err => |service_error| {
            // status_code, code, message, detail, and all ACR errors are kept.
            _ = service_error;
        },
    }
}

var update = try client.updateRepositoryProperties(
    allocator,
    "team/image",
    .{ .can_write = false, .can_delete = true },
);
defer update.deinit();

var deletion = try client.deleteRepository(allocator, "team/image");
defer deletion.deinit();
// Both 202 Accepted and 404 Not Found are successful, idempotent outcomes.
```

Pages, property values, and service errors own their allocations. Keep the
client alive until its pagers are deinitialized, and call `deinit()` on every
pager result and unary result. Local failures such as transport, allocation,
invalid response, or unsafe continuation errors remain in the outer Zig error
union; HTTP service failures use the `.err` result variant.

ACR `Link` continuations may be relative or absolute. The SDK resolves them
against the current page, requires HTTPS, and only follows the original
registry origin (case-insensitive scheme/host plus effective port). It rejects
userinfo, fragments, malformed links, alternate ports, and untrusted hosts
before the authentication policy can attach credentials.

Use `.authentication = .anonymous` only for intentional anonymous access.
The generated dependency is available as `acr.protocol`.
By default only the endpoint HTTPS origin is trusted. Hostname-only
`authentication_options.expected_hosts` entries imply port 443; use an
explicit origin such as `https://registry.example:8443` to trust another port.
Requests and challenge realms on every other origin are rejected before tokens
are sent.

Use `ContainerRegistryContentClient` for OCI and Docker manifests:

```zig
var content = try acr.ContainerRegistryContentClient.init(
    allocator,
    registry_endpoint,
    "team/app",
    .{
        .transport = transport,
        .authentication = .{ .credential = credential },
    },
);
defer content.deinit();

var uploaded = try content.uploadManifest(manifest_bytes, .{
    .reference = "v1",
    // Defaults to .oci_image_manifest.
    .media_type = .docker_v2_manifest,
});
defer uploaded.deinit(allocator);

var downloaded = try content.downloadManifest(uploaded.digest);
defer downloaded.deinit(allocator);

const delete_outcome = try content.deleteManifest(uploaded.digest);
// Both .accepted and .not_found are successful, idempotent outcomes.
_ = delete_outcome;

var blob_reader = std.Io.Reader.fixed(blob_bytes);
var blob = try content.uploadBlob(&blob_reader, .{
    // Defaults to 4 MiB and is the maximum upload buffer allocation.
    .chunk_size = 8 * 1024 * 1024,
    .cancellation = cancellation,
});
defer blob.deinit();
// blob.digest, blob.location, and blob.size are owned result values.
```

Manifest bytes are never parsed or reserialized. Upload and download validate
the exact-byte SHA-256 digest, downloads send the mature SDK Accept list, and
both directions enforce the 4 MiB manifest limit. Omitting the upload
reference uses the computed digest; deletes require a digest. Download limits
apply to decoded bytes; `Content-Length` is exact only for identity responses.
The `*Result` variants preserve structured ACR service errors.

Blob uploads start a resumable session, send sequential inclusive
`Content-Range` chunks with exact `Content-Length`, then complete using the
incrementally computed SHA-256 digest. Seekable and non-seekable readers are
supported without buffering more than one configured chunk. Retryable
pre-transport failures replay the buffered chunk; uncertain transport outcomes
first query upload status and resume only from the strictly validated confirmed
offset. Every continuation `Location` must remain HTTPS on the original
registry origin, including its effective port. Upload failures cancel the
session, final service digests are validated, and cancellation remains an outer
`error.OperationCancelled`.

Use `uploadBlobResult` when structured service errors are required. Generated
mount, upload-status, and cancel operations remain available through
`client.protocolClient().containerRegistryBlob()` and `acr.protocol`.

Long-lived clients use bounded LRU caches: 128 routes, 128 scoped access
tokens, and 32 refresh tokens. Tokens that reach the configured expiry skew
are pruned before lookup or insertion.

Local development uses relative package dependencies. Release branches replace
them with immutable `azure_sdk` and `azure_rest_container_registry` Git
commit/hash pins as described in `doc/package-branch-model.md`.
