# azure_sdk_eventhubs

Azure Event Hubs clients:

- `ProducerClient`
- `ConsumerClient`
- [`checkpoint_store_blob`](checkpoint_store_blob/README.md)

## Event models

`EventData` holds only what a producer sends: `body`, `properties`,
`content_type`, `correlation_id`, and `message_id`. `ReceivedEventData` wraps
it and adds the fields Event Hubs populates on the service side —
`sequence_number`, `offset`, `enqueued_time`, `partition_key`,
`system_properties`, and the raw AMQP message. This is the same split the Go
and Rust SDKs use.

Application property values are `uamqp.AmqpValue`, so any AMQP simple type
round-trips. `setStringProperty` is a shortcut for the common case:

```zig
var event = EventData.init("payload");
defer event.deinit(allocator);
event.content_type = "application/json";
event.message_id = .{ .string = "msg-1" };
try event.setStringProperty(allocator, "tenant", "contoso");
try event.setProperty(allocator, "retries", .{ .long = 7 });
```

`EventData` borrows every slice it is given and only `properties` allocates, so
`deinit` frees just that map. Values decoded from the wire own everything and
are freed with `ReceivedEventData.deinit` or `freeReceivedEvents`.

Release branch: `sdk/eventhubs`. The package depends on `azure_sdk_core`,
`azure_sdk_messaging_common`, `azure_sdk_storage_blobs`, `uamqp`, and `serde`
and starts at `0.1.0`.

## Development

```bash
zig build test --summary all
```
