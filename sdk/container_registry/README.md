# Azure Container Registry for Zig

`azure_sdk_container_registry` adds secure ACR challenge authentication and
token caching to the generated `azure_rest_container_registry` protocol
package.

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
