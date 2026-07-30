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
// The entity path the string named, if it named one.
const entity = try transport.initFromConnectionString(allocator, io, connection_string, .{});
defer transport.deinit();

var client = sb.ServiceBusSenderClient.init(
    transport.fully_qualified_namespace,
    entity orelse "orders",
    transport.asTransport(),
);
```

The connection string is parsed once, here, and the transport borrows from it
— so it has to outlive the transport.

Authentication is the transport's, not the client's: a client carries no
credential, because the claim that authorises a link is put by `$cbs` and
cached per audience. Every operation re-checks it, so a claim that expires
under an attached link is renewed rather than left to be detached by the
broker.

Sending keeps up to `max_in_flight` messages (default 20) on the wire at once,
so a batch is bounded by one round trip rather than by one per message. A send
that fails partway abandons whatever it left unsettled: those messages may
still arrive, so delivery is at-least-once, but the link stays usable.

Encoding allocates nothing per message. The encode buffer is rewound rather
than reallocated, and the message scratch keeps the property array it has
already grown, so a loop of similar messages allocates on the first one and
never again. A test pins this by asserting the *marginal* allocation cost of a
message — the difference between a batch of 4 and a batch of 36, divided by
32 — which is exactly what `azure_sdk_amqp`'s sender spends per delivery and
nothing more.

A cached link is checked before it is reused. The broker detaches a sender
whose claim lapsed or whose entity went away, and §2.6.1 unbinds the handle
when it does; a transfer written on an unbound handle ends the whole session.
A detached link is therefore replaced rather than written to.

Two clocks, deliberately. Operation deadlines come from the driver's clock,
which is what session and link code compare against. Whether a cached CBS token
has expired is a question about the wall clock, since a token's expiry is a
Unix timestamp; judging it on a monotonic clock would make every token look
fresh forever.

`scheduleMessage` and `cancelScheduled` return `error.NotImplemented` until the
management path lands.

## Receiving and settling

`receiveMessages` returns a `ReceivedMessages` batch, not a slice, because the
batch owns the memory every message in it points into:

```zig
var batch = try client.receiveMessages(allocator, 10, .peek_lock);
defer batch.deinit();

for (batch.messages) |msg| {
    try process(msg.body);
}
try client.settleMessages(allocator, batch.messages, .complete, .{});
```

One arena backs the whole batch, so a message costs the two copies
`azure_sdk_amqp` makes of the delivery it came from and nothing else — the
decode borrows nothing from the payload, which matters because a delivery is
valid only until the next one is read. The batch owns its arena rather than
sharing one held by the transport, since settlement happens after processing
and a caller may legitimately hold batch N while receiving batch N+1. An empty
poll allocates nothing at all, which is the steady state of a consumer on a
quiet queue.

Credit is a window, never one at a time: the link is attached with a prefetch
of 300 by default and refills at half. Setting `prefetch` to 0 turns the window
off, and each receive then asks for exactly what it wants.

A receive that runs out of time with messages already in hand returns them
rather than raising; so does one that fails partway. Only an empty batch can
carry an error, and a timed-out empty batch is not an error either — there was
simply nothing there.

Settlement works on delivery *ids*, so a run of messages collapses into one
disposition frame instead of one per message. The run breaks where it must:
between entities, because an id is meaningful only on the link that issued it,
and across gaps, because settling through a gap would settle another link's
delivery. `completeMessage` and friends are the one-message spelling of the
same call.

| action | AMQP outcome |
| --- | --- |
| complete | `accepted` |
| abandon | `modified`, neither flag set |
| defer | `modified` with `undeliverable-here` |
| dead-letter | `rejected`, condition `com.microsoft:dead-letter`, reason and description in `info` |

`receive_and_delete` is emulated rather than negotiated. The AMQP form is
`snd-settle-mode: settled` on the attach, which `azure_sdk_amqp` does not
expose yet, so the transport accepts each delivery as it reads it — batched
into one disposition — and settling such a message afterwards is a no-op. That
makes it at-least-once where the broker's own mode is at-most-once: a
disposition lost in flight means redelivery, not a dropped message.

## Development

```bash
zig build test --summary all
```
