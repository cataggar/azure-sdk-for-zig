# azure_sdk_attestation

Azure Attestation client exposing `AttestationClient`.

Release branch: `sdk/attestation`. The package depends on
`azure_sdk_core` and `serde`. The current breaking runtime release is `0.2.0`.

Construct clients with Core's canonical HTTP runtime:

```zig
var transport = core.http.StdHttpTransport.init(allocator, io);
defer transport.deinit();
var crypto = core.crypto.StdCryptoProvider.init(io);
const runtime = core.http.HttpRuntime.init(
    transport.asTransport(),
    crypto.asProvider(),
);
var client = try attestation.AttestationClient.init(
    allocator,
    endpoint,
    credential,
    .{ .runtime = runtime },
);
defer client.deinit();
```

The client copies the runtime, transport, and crypto descriptors by value.
Their backend contexts and the credential are borrowed and must outlive the
client and every operation on it. Transport and crypto providers remain
independently selectable. Attestation request IDs use `runtime.crypto`;
provider failures propagate without falling back to `std.crypto` or sending a
request.

Core is pinned to commit
`bc77bcacbb64af935ca53d60bf8a351c9592bc41` with package hash
`azure_sdk_core-0.3.0-eFY0Ev0-CACjsFaYPL6jS7CpeVNvsqYqTrXRfgQKiRFV`.

## Development

```bash
zig build
zig build test --summary all
```
