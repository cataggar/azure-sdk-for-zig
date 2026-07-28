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

## Receiving

A partition is read through one receiver link held open for the life of a
`PartitionClient`. The link carries the reader's position, so reattaching
without advancing it replays events that were already handed to the caller.

```zig
var pool = ReceiverPool.init(allocator, &session, .{
    .instance_id = "reader-1",
    .deadline_ms = deadline,
});
defer pool.deinit();

var transport = LinkTransport.init(management_client, .{
    .receivers = &pool,
    .deadline_ms = deadline,
});

var partition: PartitionClient = undefined;
try consumer.newPartitionClient(&partition, allocator, &session, "0", deadline, .{
    .start_position = EventPosition.earliest(),
    .owner_level = 1,
});
defer partition.deinit();

const events = try partition.receiveEvents(allocator, 100);
defer freeReceivedEvents(allocator, events);
```

The source is the entity path `{hub}/ConsumerGroups/{group}/Partitions/{id}`,
and the link's target is the instance id, which is what makes a stolen-link
error name the reader that took it. The start position becomes a selector
filter on the attach. After every successful receive the filter is rewritten to
`amqp.annotation.x-opt-sequence-number > '<last>'`, so a reattach resumes
without replay; `ReceiverPool` therefore applies the caller's filter only on the
first call for an address.

`owner_level` attaches as an exclusive consumer via `com.microsoft:epoch`. A
higher level detaches every lower one, which reports as `ownership_lost`.

`prefetch` defaults to 300 credits, as Go and Rust do. A negative value
disables prefetch and issues exactly the credit each receive needs, for a
caller that wants to bound its own memory use. Neither prefetch nor a single
receive may exceed 5000, the session's incoming window.

A receive that asks for more events than arrive returns the ones that did
rather than failing: a quiet partition is not an error.

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

## Connection options

Both clients carry a `connection: ConnectionOptions`, the knobs that decide
how the namespace is reached rather than what is said once there:

```zig
var producer = ProducerClient.init(.{
    .fully_qualified_namespace = "ns.servicebus.windows.net",
    .event_hub_name = "my-hub",
    .connection = .{
        .application_id = "my-app/2.1",
        .custom_endpoint = .{ .host = "proxy.contoso.com", .port = 443 },
        .retry_options = .{ .max_retries = 5 },
    },
}, credential, transport);
```

`application_id` leads the user agent sent in the `open` properties, ahead of
`azsdk-zig-eventhubs/<version> (<platform>)`, so the service can attribute
traffic to the calling application.

`custom_endpoint` changes the address dialled and nothing else. The namespace
stays the TLS server name and the CBS audience: a proxy fronting Event Hubs
presents the *namespace's* certificate, and tokens are issued for the
namespace regardless of which address carried the bytes. The AMQP `open` also
keeps naming the namespace as its virtual host, since that is what the service
routes on.

`tls.bundle` supplies the certificate bundle to validate against, which is
also how the emulator's self-signed root is trusted. Leaving it null rescans
the system trust store on every dial, so a long-lived client should hoist one
bundle out and share it. `use_tls = false` reaches the emulator over plaintext
AMQP.

`web_socket` reaches the service on port 443, for firewalls that block 5671.
The SDK ships no WebSocket implementation — that would be a second protocol
stack and a dependency. Instead the hook is handed
`wss://{namespace}/$servicebus/websocket` and returns a duplex stream, as
Go's `NewWebSocketConn` does. A custom endpoint does not reach the hook: the
URL names the namespace, and any proxying is the caller's business.

Every connection asks for the `com.microsoft:georeplication` capability, which
is what makes the service report `geo_replication_enabled` on the hub
properties.

`AmqpConnectionFactory` is the factory that honours all of this. Give it to a
`RecoverableConnection` and a rebuild re-reads the options and re-dials from
scratch, re-invoking the WebSocket hook, since the caller's stream died with
the connection it was carrying.

## Recovery

A long-lived producer or consumer outlives the links it runs on. Brokers
recycle links during upgrades and rebalances, and a connection can drop
outright. `RecoverableConnection` rebuilds whatever the failure says is
broken and `runWithRecovery` re-runs the operation on top of it:

- `link` — reattach that one link. The connection and every other link stay
  up. The first link failure of an operation takes one immediate retry
  before the normal backoff, since a reattach is cheap and usually enough.
- `connection` — rebuild the connection, its session, and every link.
- `fatal` — surface it. `amqp:link:stolen` lands here, so a displaced
  consumer stops rather than stealing its partition back.

The connection is opened lazily through a `ConnectionFactory`, so nothing
dials until the first operation runs. An `Authorizer` puts a CBS token on
each generation *before* any link attaches: a rebuilt connection carries no
claims, and a link attaching without one is refused with
`unauthorized-access`, which is fatal.

Recovery is idempotent across concurrent failures. `ensureOpen` returns the
generation the caller is working against, and `recoverConnection` ignores a
request naming a generation that is already gone — otherwise two operations
failing on the same dead connection would rebuild it twice and the second
rebuild would discard the first's healthy connection.

Reattached receivers resume where they left off. The pool remembers each
partition's selector when it drops a client, so a reattach continues past
the last sequence number handed to the caller instead of replaying from the
configured start position. For the same reason, a receive that fails partway
through a batch returns the events that did arrive rather than discarding
them; the next call finds the link dead and recovers it.

## Distributed consumption

A `Processor` spreads a hub's partitions across a fleet of consumers. Each
processor claims what it is entitled to, opens a reader for it, and hands
that reader to the caller; ownership lives in a `CheckpointStore`, so the
fleet coordinates through storage rather than through each other.

```zig
var processor = consumer.newProcessor(
    allocator,
    &store.store,
    opener.asOpener(),
    .{ .load_balancing_strategy = .greedy },
    &clock.clock,
    prng.random(),
);
defer processor.deinit();

while (running) {
    try processor.runOnce();
    while (processor.nextPartitionClient()) |partition| {
        // read from `partition`, then `partition.updateCheckpoint(...)`
    }
    std.Thread.sleep(@intCast(processor.nextIntervalMs() * std.time.ns_per_ms));
}
```

`runOnce` is one balancing cycle rather than a thread, so the caller owns
the loop and its shutdown. `nextIntervalMs` applies Go's 0.8–1.3 jitter to
the update interval, which keeps a fleet that started together from
rebalancing in lockstep.

Two strategies decide how fast a processor grows:

- `balanced` (the default, as in Go) takes at most one partition per cycle,
  so a fleet converges gradually and a restarting processor does not
  stampede.
- `greedy` takes its whole fair share at once, which is what Rust defaults
  to and what a small, stable fleet wants.

Both prefer a partition that is unowned, expired, or explicitly relinquished
before stealing from a processor holding more than its share. The fair share
is `partitions / owners`, plus one where the division is uneven. Selection
among equally good candidates is random on purpose: every processor runs the
same algorithm at the same instant, so list order would make them all race
for the same partition.

Ownership is a lease. It is renewed by re-claiming every cycle and expires
after `partition_expiration_ms` (60s, as in Go and Rust), so a processor that
dies is taken over rather than blocking its partitions forever. `deinit`
relinquishes by writing an empty owner id, which the balancer treats as
immediately available — a clean shutdown hands over in one cycle instead of
one expiry.

A reader starts where the checkpoint says, preferring offset over sequence
number; failing that, at the per-partition start position; failing that, at
the default. A checkpoint carrying neither offset nor sequence number is an
error rather than a silent restart. When a geo-replicated namespace rejects
a checkpointed offset — offsets there are per-replica and mean nothing after
a failover — the reader restarts at earliest, inclusive: duplicates rather
than a partition nobody can read.

`InMemoryCheckpointStore` is a `CheckpointStore` held in memory, for tests
and for running a fleet in one process. It is last-write-wins and does not
model the etag race a real store arbitrates; `BlobCheckpointStore` does.

Release branch: `sdk/eventhubs`. The package depends on `azure_sdk_core`,
`azure_sdk_messaging_common`, `azure_sdk_storage_blobs`, `uamqp`, and `serde`
and starts at `0.1.0`.

## Development

```bash
zig build test --summary all
```
