# azure_sdk_core_amqp

AMQP 1.0 integration for Azure SDK clients, backed by the pure Zig
[`azure-uamqp-zig`](https://github.com/cataggar/azure-uamqp-zig) package.

- Source: `sdk/core/amqp`
- Release branch: `sdk/core_amqp`
- Initial version: `0.1.0`
- External dependency: `uamqp`

Run its independent tests from this directory:

```bash
zig build test --summary all
```
