# azure_sdk_kusto_common

Shared Kusto connection, endpoint discovery, trust validation, error, cloud,
and result types.

- Release branch: `sdk/kusto_common`
- Initial version: `0.1.0`
- Internal dependency: `azure_sdk_core`
- External dependency: `serde`

See the
[Kusto overview](https://github.com/cataggar/azure-sdk-for-zig/tree/main/sdk/kusto)
for connection and authentication behavior.

## Development

```bash
zig build test --summary all
```
