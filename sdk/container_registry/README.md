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
By default only the endpoint host is trusted. Add explicit
`authentication_options.expected_hosts` entries for known ACR data endpoints;
requests and challenge realms on every other host are rejected before tokens
are sent.

Local development uses relative package dependencies. Release branches replace
them with immutable `azure_sdk` and `azure_rest_container_registry` Git
commit/hash pins as described in `doc/package-branch-model.md`.
