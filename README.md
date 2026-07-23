# Azure Container Registry for Zig

`azure_sdk_container_registry` adds secure ACR challenge authentication,
token caching, metadata operations, Link-header paging, structured service
errors, exact-byte manifest operations, bounded-memory resumable blob uploads,
and bounded blob downloads to the generated
`azure_rest_container_registry` protocol package.

The stable public data-plane version is **2021-07-01**. Both high-level
clients default to that version; override `api_version` only when intentionally
using a compatible service contract. `acr.protocol` re-exports
`azure_rest_container_registry` as the protocol escape hatch for raw generated
operations, status unions, and custom-pipeline scenarios.

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
Anonymous mode never acquires an Azure credential or attaches an
`Authorization` header. It succeeds only when the target repository permits
the requested public pull/catalog operation. Authenticated mode uses the
supplied `TokenCredential`, performs the AAD-to-ACR challenge exchange, and
caches bounded refresh/access tokens. Authentication, repository visibility,
and write/delete authorization remain registry configuration concerns.
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

Uploads directly support these manifest `Content-Type` values:

- `application/vnd.oci.image.manifest.v1+json`
- `application/vnd.docker.distribution.manifest.v2+json`

Downloads advertise and preserve OCI image manifests/indexes, Docker schema-2
manifests/lists/config, ORAS artifact manifests, wildcard-compatible
manifests, and the exact returned media type. Blob and layer bodies use
`application/octet-stream`; callers define the layer/config descriptors in
their manifest bytes.

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

Use `BlobDownloadClient` for digest-safe blob downloads:

```zig
var blobs = try acr.BlobDownloadClient.init(
    allocator,
    registry_endpoint,
    "team/app",
    .{
        .transport = transport,
        .authentication = .{ .credential = credential },
    },
);
defer blobs.deinit();

// Buffered downloads are capped at 16 MiB by default.
var small = try blobs.downloadBlob(digest, .{ .max_size = 2 * 1024 * 1024 });
defer small.deinit();

// Streaming callers own one active HTTP operation.
var stream = try blobs.downloadBlobStreaming(digest, .{});
defer stream.deinit();
const reader = try stream.reader();
// Read from reader, then finish to drain and validate length and SHA-256.
_ = reader;
try stream.finish();

// Large downloads use sequential 4 MiB ranges and bounded copy memory.
var downloaded = try blobs.downloadBlobToWriter(digest, writer, .{});
defer downloaded.deinit();
```

Streaming downloads require `finish`, `abort`, or `cancel`, followed by
`deinit`; active operations are aborted by `deinit`. Buffered downloads enforce
the configured decoded-byte bound. Writer downloads request sequential ranges
and retry only classified HTTP/read/transport failures from the last
successfully written offset, so retries never replay confirmed bytes. A server
may return a full `200`, ranged `206`, or terminal `416`; every length, range,
total, requested digest, and returned service digest is checked. Blob responses
may omit `Docker-Content-Digest`; full decoded bytes are always verified against
the requested digest, and any service digest that is present is also validated.

Core redirect handling follows ACR `307` responses over HTTPS, removes
`Authorization`, cookies, proxy authorization, and `Host` on cross-origin
requests, and rejects insecure targets. Ranged retries always restart from the
registry URL rather than retaining a storage redirect.

Long-lived clients use bounded LRU caches: 128 routes, 128 scoped access
tokens, and 32 refresh tokens. Tokens that reach the configured expiry skew
are pruned before lookup or insertion.

Local development uses relative package dependencies. The canonical package
split changes the common dependency to `azure_sdk_core`. Release branches
replace local paths with immutable Core and
`azure_rest_container_registry` Git commit/hash pins as described in the
[package branch model](../../doc/package-branch-model.md).

## Ownership and lifetime rules

- Clients own their copied endpoint/repository/auth-policy state and must be
  deinitialized before their borrowed transport and credential.
- Pagers borrow the originating client pipeline. Keep the client alive until
  `pager.deinit()`, and deinitialize every page result before requesting or
  discarding more pages.
- Metadata and service-error results own allocator-backed strings and arrays;
  call their `deinit()` exactly once.
- Manifest results use the allocator passed to the client and require
  `deinit(allocator)`. Blob results remember their allocator and use
  parameterless `deinit()`.
- A streaming blob operation exclusively owns one HTTP operation. Call
  `finish`, `abort`, or `cancel`, then `deinit`; `deinit` aborts an operation
  that is still active.
- Writers/readers and request byte slices are borrowed only for the documented
  call duration. Returned owned bytes remain valid until result deinit.

## Transfer bounds and replay semantics

- Manifests are limited to 4 MiB in both directions.
- Buffered blob downloads default to 16 MiB and fail before exceeding
  `max_size`.
- Blob uploads allocate one configured chunk (4 MiB default, 100 MiB maximum)
  and support seekable or non-seekable readers. A buffered chunk can be
  replayed after a definitely pre-transport failure. After an uncertain
  outcome the client queries and strictly validates the server offset before
  resuming; it never blindly replays bytes.
- Writer downloads use 4 MiB sequential ranges by default plus a 64 KiB copy
  buffer. Only bytes accepted by the writer advance the digest and confirmed
  offset, so retryable transport/read failures resume without duplicating
  output. Redirected range retries restart at the registry URL.
- Request bodies that must survive core HTTP redirects/retries are replayable
  only when the body supplies rewind state. Non-replayable streaming request
  bodies are not automatically resent.

## Examples

Compile all examples with:

```bash
zig build examples
```

The examples are deliberately environment-driven and never embed credentials
or registry names:

| Example | Required environment |
| --- | --- |
| `list_repositories_tags.zig` | `AZURE_CONTAINER_REGISTRY_ENDPOINT`; optional `AZURE_CONTAINER_REGISTRY_REPOSITORY` |
| `anonymous_read.zig` | endpoint, repository, `AZURE_CONTAINER_REGISTRY_MANIFEST_REFERENCE`; always anonymous |
| `oci_push_pull.zig` | endpoint, repository, `AZURE_CONTAINER_REGISTRY_ALLOW_WRITES=1`; optional `AZURE_CONTAINER_REGISTRY_TAG` |
| `delete_artifact.zig` | endpoint, repository, `AZURE_CONTAINER_REGISTRY_ALLOW_DELETE=1`, and `AZURE_CONTAINER_REGISTRY_CONFIRM_DELETE_REPOSITORY` exactly equal to the repository; one or more delete target variables |

Authenticated examples use `DefaultAzureCredential`. The delete example accepts
`AZURE_CONTAINER_REGISTRY_DELETE_TAG`,
`AZURE_CONTAINER_REGISTRY_DELETE_DIGEST`, and the additional explicit
`AZURE_CONTAINER_REGISTRY_DELETE_WHOLE_REPOSITORY=1` gate.

## Destructive live tests

`zig build live-test` skips cleanly unless
`AZURE_CONTAINER_REGISTRY_LIVE_TESTS=1`. A configured run also requires:

- `AZURE_CONTAINER_REGISTRY_ENDPOINT` — exact HTTPS registry origin without a
  trailing slash.
- `AZURE_CONTAINER_REGISTRY_LIVE_TEST_RUN_ID` — a unique lowercase
  alphanumeric/hyphen identifier (maximum 40 bytes) for this run.
- Optional `AZURE_CONTAINER_REGISTRY_LIVE_TEST_REPOSITORY_PREFIX` — defaults
  to `azure-sdk-for-zig-live`.

The suite creates only
`<prefix>/azure-sdk-for-zig-live-issue-89-<run-id>`, exercises metadata properties, OCI
manifest/blob transfer, a non-seekable upload, injected live ranged-resume
recovery, real ACR HTTPS redirects, and idempotent deletion. A deferred cleanup
deletes that exact unique repository on every exit; no prefix-wide/list-based
deletion is performed.

The principal needs data-plane catalog, pull, push, metadata-update, and delete
permissions. For a non-ABAC registry, `AcrPush` plus repository catalog-list
permission is sufficient. For an ABAC-enabled registry, assign
`Container Registry Repository Contributor` and
`Container Registry Repository Catalog Lister` scoped as narrowly as
practical. `DefaultAzureCredential` may use the standard `AZURE_TENANT_ID`,
`AZURE_CLIENT_ID`, and `AZURE_CLIENT_SECRET`, workload identity, managed
identity, or Azure CLI login; the tests never print or persist credential
values.

## Independent release preparation

The checked-in package keeps local path dependencies for monorepo development.
Run `scripts/package-release.sh verify azure_sdk_container_registry` for
deterministic local release validation. Publish the generated REST package
first, then prepare the SDK package so the generic engine resolves and applies
the immutable REST and Core package commits and hashes. Exact commands are
documented in
[Container Registry release staging](../../eng/container_registry_release/README.md).
