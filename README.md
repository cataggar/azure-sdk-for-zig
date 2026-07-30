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
| `management.zig` | the `$management` request and reply wire format |
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
var batch = try client.receiveMessages(allocator, 10);
defer batch.deinit();

for (batch.messages) |msg| {
    try process(msg.body);
}
try client.settleMessages(allocator, batch.messages, .complete, .{});
```

Nothing is allocated until a message actually arrives, so an empty poll — the
steady state of a consumer on a quiet queue — costs no page. Once one does,
one arena backs the whole batch, so a message costs the two copies
`azure_sdk_amqp` makes of the delivery it came from and nothing else — the
decode borrows nothing from the payload, which matters because a delivery is
valid only until the next one is read. The batch owns its arena rather than
sharing one held by the transport, since settlement happens after processing
and a caller may legitimately hold batch N while receiving batch N+1.

`max_count` is capped at 5000, the same ceiling Event Hubs puts on a receive:
it sizes both a credit grant and a precise reservation, so it has to be the
caller's intent rather than whatever number happened to arrive.

Credit is a window, never one at a time: the link is attached with a prefetch
of 300 by default and refills at half. Setting `prefetch` to 0 turns the window
off, and each receive then asks for exactly what it wants.

A receive that runs out of time with messages already in hand returns them
rather than raising; so does one that fails partway, including on a message
that will not decode. Only an empty batch can carry an error, and a timed-out
empty batch is not an error either — there was simply nothing there. The one
case with no good answer is an undecodable message at the *head* of a batch:
it surfaces as an error, and since the caller never gets a handle to it, it
cannot be dead-lettered either. Under peek-lock that recurs rather than
happening once — the message is left unsettled, so it comes back when the lock
lapses and stops the batch at the same place again.

Settlement works on delivery *ids*, so a run of messages collapses into one
disposition frame instead of one per message. Ids are allocated by the session
rather than the link, and a `disposition` carries no handle, so a range is not
confined to the link it is sent through — which is why the run has to break in
two places. Across **gaps**, because a gap means another link on the session
took an id in between and settling through it would decide that link's
delivery. And between **entities**, because whether the ids should be settled
at all is a property of the link: a `receive_and_delete` entity's messages were
settled as they were read, and folding them into a neighbouring `peek_lock`
range would settle them twice. `completeMessage` and friends are the
one-message spelling of the same call.

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

## Management operations

Scheduling, cancelling, lock renewal and peeking are not link operations. They
are requests to the entity's `$management` node, carried over a request/reply
link pair with the operation named in `application-properties` and its
arguments in the body. `azure_sdk_amqp`'s `RpcLink` provides the pair and the
correlation; `management.zig` provides the wire format, as pure functions over
values so it is testable without a broker.

```zig
// Enqueue at a time in the future; the number comes back so it can be cancelled.
const seq = try sender.scheduleMessage(allocator, msg, when_ms);
try sender.cancelScheduledMessage(allocator, seq);

// Extend a lock that is about to lapse, and read what the broker granted.
const expires_at_ms = try receiver.renewMessageLock(allocator, batch.messages[0]);

// Look without taking.
var peeked = try receiver.peekMessages(allocator, from_sequence_number, 10);
defer peeked.deinit();
```

The batched forms — `scheduleMessages` and `cancelScheduledMessages` — put the
whole run in one request, so a hundred scheduled messages cost one round trip
rather than a hundred. `scheduleMessages` writes one sequence number per
message into a caller-supplied `out` and returns how many it wrote; the
singular form is that call with a one-element array.

The `$management` node is **per entity**, so each entity gets its own link
pair, cached and reused across operations exactly as its sender and receiver
are. The CBS claim is on the entity rather than on the management address; the
broker prefix-matches a token's resource against the link address, so the
entity's token covers the node beneath it. The reference clients do not agree
on this — Go claims both, .NET claims only the management address, Python only
the entity — which is itself the evidence that either is accepted. A pair the
broker has detached is replaced rather than written to again: §2.6.1 unbinds
the handle at detach, and a transfer on an unbound handle ends the session and
takes every other entity's link with it.

Every pair is opened with the transport's one link id, not one per entity:
`RpcLink` derives the link names and the private reply address from the
address, which already carries the entity. `com.microsoft:server-timeout` is
what remains of the call's deadline less a second, not the whole configured
budget — the broker's timer starts when the request lands, after whatever
dialling, claiming and attaching the call had to do first, and the second is
the return leg the reply still needs to get back in.

Each operation names the link it acts on behalf of in `associated-link-name`,
which is how the broker routes it to the same partition and session as the
message: the **sender** for scheduling and cancelling, the **receiver** for
lock renewal and peeking. When no such link is open there is nothing to
associate with and the property is omitted.

A **peeked message is not a delivery.** It holds no lock, carries no delivery
id or tag, and cannot be settled — to act on one, receive it. Its
`delivery_count` is the header's own value rather than the received path's
`+ 1`; that increment exists because a delivery in hand is one the header has
not counted yet, and a peek has no delivery. A peek that runs past the end of
the queue answers `204` with no body at all and comes back as an empty batch
holding no arena, not as an error. `max_count` is a request rather than a
guarantee, so the batch is capped at it whatever the broker returns.

Lock renewal identifies the message by its delivery tag, which the broker
sends as a .NET `Guid` — the first three fields little-endian — while the AMQP
`uuid` it must be sent back as is RFC 4122 big-endian. The transport swaps
them. Getting this wrong fails *silently*: the broker simply reports a lock it
does not recognise. A lock that has already lapsed comes back as `410`, which
is surfaced as `error.MessageLockLost` rather than as a generic failure,
because it is the one refusal a caller can act on — the message is back on the
queue and will be redelivered, so there is nothing to retry.

## Benchmarks

```bash
zig build bench -Doptimize=ReleaseFast
```

Offline benchmarks for the encode, decode and management paths — building an
AMQP message from a `ServiceBusMessage`, encoding it as a transfer payload,
converting a received one back, and building and reading the two management
bodies that carry a whole batch. Nothing touches the network, so a result is
attributable to a code change rather than to service latency.

The last two run the whole receive path against a scripted peer: frames off
the transport, deliveries reassembled, messages decoded, Service Bus messages
converted, the batch arena filled. That loop is where a consumer actually
spends its time, and none of it is visible one message at a time. The two
share a byte-identical handshake, CBS exchange and attach and differ only in
how many transfers follow, so subtracting them and dividing by 999 leaves the
cost of one received message.

Prefer `allocs/op` as the regression signal. It is stable across machines,
whereas timings move on shared or virtualised hosts — and the suite opens with
an empty `baseline` case precisely so the small timings can be read against
the harness floor rather than taken at face value. Two of the numbers carry a
claim worth defending:

- **`toAmqpMessage + properties` at 0 allocs/op.** The property array is the
  one thing `Scratch` allocates, and `sendMessages` keeps one `Scratch` across
  a whole batch, so it grows once and is reused. Rebuild it per call instead
  and this reads 1. (`toAmqpMessage` without properties reads 0 either way,
  which is why the property case is the one that means anything.)
- **Exactly 2 allocations per received message.** `azure_sdk_amqp` dupes the
  payload and the delivery tag; this package adds nothing that scales with the
  batch, since the arena, the message list and the entity copy are each paid
  once. The bound already has a test; the benchmark is what makes it a number.

`fromAmqpMessage`'s 0 is *not* in that list. It takes no allocator, so no other
answer is representable — the guard against a copy creeping in is its
signature, not its reading.

The benchmarks are built (but not run) by `zig build test`, so a signature
change cannot silently rot them.

## Development

```bash
zig build test --summary all
```
