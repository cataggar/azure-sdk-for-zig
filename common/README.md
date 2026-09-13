# Kusto Common namespace

Shared Kusto connection, endpoint discovery, trust validation, error, cloud,
and result types.

Import it from the consolidated package:

```zig
const common = @import("azure_sdk_kusto").common;
```

See the [Kusto overview](../README.md) for connection, authentication, and
development guidance.

`KustoConnectionOptions.instrumentation` optionally configures Core tracing for
both unauthenticated cloud discovery and the authenticated connection pipeline.
It preserves the caller's complete scope/version/namespace/default-parent
configuration. It defaults to `null`; provider and metadata lifetimes follow the
[tracing ownership contract](../README.md#ownership-and-status-handles).
