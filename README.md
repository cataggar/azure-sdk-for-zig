# azure_sdk_servicebus

Azure Service Bus clients:

- `ServiceBusSenderClient`
- `ServiceBusReceiverClient`
- `ServiceBusAdministrationClient`

Release branch: `sdk/servicebus`. The package depends on `azure_sdk_core`,
`azure_sdk_messaging_common`, `azure_sdk_amqp`, and `serde`.

Messaging runs over [`azure_sdk_amqp`](../../tree/sdk/amqp), the same AMQP 1.0
stack Event Hubs uses, rather than over a second direct-`uamqp` transport. Both
packages therefore share one connection driver, link implementation, prefetch
credit window, and settlement path, and Service Bus inherits work done on
either.

Administration runs over the `azure_sdk_core` HTTP pipeline against the
management REST API and is unrelated to the AMQP path.

## Layout

| file | what |
| --- | --- |
| `root.zig` | models, clients, and the AMQP transport interface |
| `amqp_transport.zig` | the AMQP transport: dial, CBS, cached session and links |
| `message.zig` | Service Bus ↔ AMQP message translation |
| `admin.zig` | administration client and its Atom XML parsing |

## Messages on the wire

Service Bus keeps its broker metadata in ordinary AMQP places, so `message.zig`
is a mapping rather than a codec:

| Service Bus | AMQP |
| --- | --- |
| `message_id`, `correlation_id`, `content_type`, `subject`, `to`, `reply_to` | `properties` (§3.2.4) |
| `session_id` | `properties.group-id` |
| `time_to_live_ms` | `header.ttl` (§3.2.1) |
| `partition_key` | annotation `x-opt-partition-key` |
| `scheduled_enqueue_time` | annotation `x-opt-scheduled-enqueue-time` |
| `sequence_number`, `enqueued_time`, `locked_until`, `dead_letter_source` | `x-opt-*` annotations |
| `delivery_count` | `header.delivery-count` |
| `dead_letter_reason`, `dead_letter_description` | application properties |

Decoding **borrows**. Every slice on a `ServiceBusReceivedMessage` points into
the arena its AMQP message was decoded into, and dies with that arena. It does
*not* point into the delivery payload — the decoder dupes strings and binaries
out of it — so keeping the payload bytes alive does not keep a received message
valid. Copy anything that must outlive the arena.

`delivery_count` is the Service Bus count, 1 on a first delivery, not the raw
AMQP field that counts previous failures and is 0 there. It compares directly
against `MaxDeliveryCount`.

Application properties are handed back as AMQP fields rather than as a map: a
map would cost an allocation on every received message, and Service Bus allows
typed values a string map could not hold. Read them with
`applicationPropertyOf`.

## The transport

`AmqpTransport` implements the `ServiceBusAmqpTransport` interface over
`azure_sdk_amqp`. What it holds across calls is the point of it: one
connection, one session, one `$cbs` link pair, one sender link per entity, and
one encode buffer. Nothing dials until the first operation needs the wire.

```zig
var transport: sb.AmqpTransport = undefined;
const entity = try transport.initFromConnectionString(allocator, io, connection_string, .{});
defer transport.deinit();

var client = sb.ServiceBusSenderClient.init(
    transport.fully_qualified_namespace,
    entity,
    transport.asTransport(),
);
```

Authentication is the transport's, not the client's: a client carries no
credential, because the claim that authorises a link is put by `$cbs` and
cached per audience. Every operation re-checks it, so a claim that expires
under an attached link is renewed rather than left to be detached by the
broker.

Sending keeps up to `max_in_flight` messages (default 20) on the wire at once,
so a batch is bounded by one round trip rather than by one per message. A send
that fails partway abandons whatever it left unsettled: those messages may
still arrive, so delivery is at-least-once, but the link stays usable. Encoding
allocates nothing per message — the encode buffer and the message scratch are
both reused — which a test pins by asserting the *marginal* allocation cost of
a message.

Two clocks, deliberately. Operation deadlines come from the driver's clock,
which is what session and link code compare against. Whether a cached CBS token
has expired is a question about the wall clock, since a token's expiry is a
Unix timestamp; judging it on a monotonic clock would make every token look
fresh forever.

`receiveMessages`, `settleMessage`, `scheduleMessage` and `cancelScheduled`
return `error.NotImplemented` until the receive and management paths land.

## Development

```bash
zig build test --summary all
```
