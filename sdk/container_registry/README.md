# Azure Container Registry for Zig

`azure_sdk_container_registry` adds secure ACR challenge authentication,
metadata operations, Link-header paging, and structured service errors to the
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

Long-lived clients use bounded LRU caches: 128 routes, 128 scoped access
tokens, and 32 refresh tokens. Tokens that reach the configured expiry skew
are pruned before lookup or insertion.

Local development uses relative package dependencies. Release branches replace
them with immutable `azure_sdk` and `azure_rest_container_registry` Git
commit/hash pins as described in `doc/package-branch-model.md`.
