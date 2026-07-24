# azure_sdk_storage_queues

Azure Queue Storage clients, including `QueueClient`, `QueueServiceClient`, and
the complete-SAS `SasQueueClient`.

Release branch: `sdk/storage_queues`. The package depends on
`azure_sdk_core`, `azure_sdk_storage_common`, and `serde` and starts at
`0.1.0`.

See the
[Storage overview](https://github.com/cataggar/azure-sdk-for-zig/blob/main/sdk/storage/README.md)
for complete-SAS message behavior.

```bash
zig build test --summary all
zig build examples
zig build complete-sas-message -- <queue-sas-url> <message>
```
