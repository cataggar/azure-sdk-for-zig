# azure_sdk_kusto_common

Shared Kusto connection, endpoint discovery, trust validation, error, cloud,
and result types.

- Release branch: `sdk/kusto_common`
- Initial version: `0.1.0`
- Internal dependency: `azure_sdk_core`
- External dependency: `serde`

The current file-rooted module moves from `sdk/kusto/common.zig` to this
directory when the package is extracted. See the
[Kusto overview](../README.md) for connection and authentication behavior.
