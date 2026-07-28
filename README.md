# azure_sdk_eventhubs

Azure Event Hubs clients:

- `ProducerClient`
- `ConsumerClient`
- [`checkpoint_store_blob`](checkpoint_store_blob/README.md)

## Authentication

Both clients hold a `Credential`, which is either an AAD `TokenCredential` or
a shared access signature parsed out of a connection string:

```zig
// AAD. The credential must outlive the client.
var producer = ProducerClient.init(.{
    .fully_qualified_namespace = "ns.servicebus.windows.net",
    .event_hub_name = "hub",
}, cred.asCredential(), transport);
defer producer.close();

// Connection string. The string must outlive the client, because the
// namespace, hub name, and key are all borrowed from it.
var producer = try ProducerClient.fromConnectionString(allocator, cs, null, transport);
defer producer.close();
```

AAD tokens are requested for `https://eventhubs.azure.net/.default` and put to
CBS as `jwt`; connection-string tokens are put as `servicebus.windows.net:sastoken`.

A token authorises an audience rather than the whole namespace.
`entityAudience` returns `amqps://{namespace}/{hub}` for management operations
and sending; `ConsumerClient.partitionAudience` returns the consumer group
form, `amqps://{namespace}/{hub}/ConsumerGroups/{group}/Partitions/{id}`, which
is what a partition receiver needs. The scheme comes from the connection string
when there is one, so the emulator's plaintext `amqp://` endpoint works.

A connection string carrying a pre-formed `SharedAccessSignature` instead of a
key cannot be re-signed, so `credential.isRefreshable()` reports `false` and the
client cannot outlive that signature.

## Sending

A batch leaves as a single AMQP transfer whose `message-format` is
`0x80013700`. Its body is the first event's non-body sections reused as an
envelope, followed by one data section per event, each holding a fully encoded
AMQP message. The service splits it back apart. Go and Rust produce the same
shape.

```zig
var pool = SenderPool.init(allocator, &session, .{ .deadline_ms = deadline });
defer pool.deinit();

var transport = LinkTransport.init(management_client, .{
    .senders = &pool,
    .deadline_ms = deadline,
});

var batch = try producer.createBatch(allocator, .{ .partition_key = "orders" });
defer batch.deinit(allocator);
_ = try batch.tryAdd(allocator, EventData.init("hello"));
try producer.sendBatch(allocator, batch);
```

The link target is the entity path, not the namespace: `{hub}` lets the service
pick a partition, and `{hub}/Partitions/{id}` pins one. A batch created with a
`partition_id` routes itself. One link is attached per address and reused,
because credit and `max-message-size` are both per link.

`createBatch` asks the link for its negotiated `max-message-size` and sizes the
batch by it, so a batch that reports as fitting actually fits. An explicit
`max_bytes` above what the link allows is refused rather than truncated.

A partition key becomes an `x-opt-partition-key` message annotation on every
event and on the envelope, which is the copy the service routes by.

The senders belong to the session, which detaches and frees them; the pool only
owns the addresses it keys them by. When the broker refuses a delivery,
`lastSendError` carries the AMQP condition and description that the Zig error
cannot.

## Metadata

`getEventHubProperties` and `getPartitionProperties` are `READ` operations on
the `$management` link, distinguished by entity type — `com.microsoft:eventhub`
returns the hub's partition list, `com.microsoft:partition` returns one
partition's sequence number range.

`LinkTransport` performs them against an already-open
`azure_sdk_amqp.Management` client. It borrows the client rather than opening
one, because the connection, its CBS authorisation, and its session outlive any
single operation.

```zig
var transport = LinkTransport.init(management_client, .{
    .security_token = token.token,
    .deadline_ms = deadline,
    .retry = .{ .sleeper = &sleeper, .random = prng.random() },
});
var props = try producer.getEventHubProperties(allocator);
defer props.deinit();
```

Decoded properties own their strings through an arena; ones built by hand leave
it null and borrow instead, so `deinit` is always correct and is idempotent.

The wire names are not guessable and are taken from the Go SDK. In a partition
reply `name` is the *hub* and `partition` is the partition; the first sequence
number is `begin_sequence_number`; geo-replication is reported as a *factor*
that the client turns into a boolean, so a factor of one is not
geo-replication.

Failures carry the broker's status and description, which a Zig error cannot,
on `Management.last_error`. Both operations optionally run under the Event Hubs
retry schedule, which classifies a management status into the AMQP condition it
corresponds to — a 404 is fatal and is not retried, a 503 is not.

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

## Batching

`EventDataBatch` encodes each event as it is added and tracks the real byte
count, so a batch that reports as fitting actually fits. `tryAdd` returns
`false` when an event does not fit alongside what is already batched, and
`BatchError.EventDataTooLarge` when it would not fit an empty batch either.

```zig
var batch = try EventDataBatch.init(.{ .partition_key = "orders-42" });
defer batch.deinit(allocator);
if (!try batch.tryAdd(allocator, event)) {
    // send `batch`, then start a new one
}
```

A batch targets either a partition key or a partition id, never both. The size
limit defaults to `default_max_message_size` (1 MiB) and
`applyLinkMaxMessageSize` adopts what a sender link negotiates, keeping a
smaller explicit `max_bytes` and rejecting a larger one.

## Errors and retries

`EventHubsError` pairs a stable `ErrorCode` with the AMQP condition behind it.
The codes match the other Azure SDKs: `unauthorized_access`,
`connection_lost`, `ownership_lost`, and `send_rejected`. Use `ErrorCode`
for programmatic decisions; the condition and description are diagnostics and
may change.

`recoveryKindForCondition` buckets an AMQP condition into `none`, `link`,
`connection`, or `fatal`. A condition the SDK does not recognise is treated as
connection-recoverable, on the assumption that an unfamiliar failure has left
the connection in an unknown state. `amqp:link:stolen` is `fatal` and maps to
`ownership_lost`, since another consumer attached with an equal or higher owner
level and retrying would only steal the partition back.

`retry` runs an operation on Go's schedule: 3 retries, `((1 << n) - 1) * 4s`
delays jittered by a uniform multiplier in `[0.8, 1.3)`, capped at 120s. A
fatal condition returns immediately without consuming the budget, and an
exhausted budget reports `connection_lost`. The operation reports its AMQP
condition by setting `attempt.condition` before returning an error, and may
call `attempt.resetAttempts` to take one more immediate try after recovering a
link. Both the `Sleeper` and the jitter source are injected, so tests can
exercise the whole schedule without spending the time it describes.

Release branch: `sdk/eventhubs`. The package depends on `azure_sdk_core`,
`azure_sdk_messaging_common`, `azure_sdk_storage_blobs`, `uamqp`, and `serde`
and starts at `0.1.0`.

## Development

```bash
zig build test --summary all
```
