# Azure Messaging packages

| Package | Purpose |
| --- | --- |
| [`azure_sdk_messaging_common`](common/README.md) | Shared messaging types |
| [`azure_sdk_eventhubs`](eventhubs/README.md) | Event Hubs clients and Blob checkpoint-store namespace |
| [`azure_sdk_servicebus`](servicebus/README.md) | Service Bus sender, receiver, and administration clients |

Messaging packages start at `0.1.0` and are released in dependency order.
Event Hubs and Service Bus use the pure Zig `uamqp` package.

## Development

Each Messaging package builds independently from its package directory:

```bash
cd sdk/messaging/common && zig build test --summary all
cd ../eventhubs && zig build test --summary all
cd ../servicebus && zig build test --summary all
```
