# azure_sdk_amqp

AMQP 1.0 integration for Azure SDK clients, backed by the pure Zig
[`azure-uamqp-zig`](https://github.com/cataggar/azure-uamqp-zig) package.

- Package branch: [`sdk/amqp`](https://github.com/cataggar/azure-sdk-for-zig/tree/sdk/amqp)
- External dependency: `uamqp` ([`azure-uamqp-zig`](https://github.com/cataggar/azure-uamqp-zig)), re-exported as `azure_sdk_amqp.uamqp`
- Version: see `build.zig.zon`

`azure-uamqp-zig` supplies the AMQP type system and frame layout but owns no
sockets and encodes no performatives. This package adds both, so a client can
actually reach an Event Hubs namespace.

## Transports

`transport.zig` defines a small `Transport` interface — `read`, `write`,
`flush`, `close` — with three implementations:

| Transport         | Use                                                 |
| ----------------- | --------------------------------------------------- |
| `TlsTransport`    | `amqps` on port 5671, the normal path               |
| `TcpTransport`    | plaintext on port 5672, for the Event Hubs emulator |
| `MemoryTransport` | a scripted in-memory duplex, for tests              |

`Endpoint` separates where the driver dials from the identity it validates, so
a namespace can be fronted by a local proxy:

```zig
const endpoint = amqp.Endpoint
    .forNamespace("myns.servicebus.windows.net")
    .viaCustomEndpoint("proxy.internal", 8443);

const socket = try amqp.connect(allocator, io, endpoint, .{});
defer socket.deinit();
```

## Performative codec

`performative.zig` encodes and decodes `open`, `begin`, `end`, `close`, and the
SASL performatives as described lists.

Encoding was originally written here rather than delegated to `uamqp.encoder`
because that encoder wrote array elements of variable-width types without their
length prefix, which no peer accepts. **uamqp v0.3.0 fixed that** — it now
emits a shared element constructor and per-element lengths, and rejects arrays
it cannot describe (`MixedArrayElements`, `UnsupportedArrayElement`). The
duplication is therefore no longer necessary and this codec could be folded
into `uamqp.encoder`; that consolidation has not been done yet.

## Connection driver

`connection.zig` runs the handshake and the connection state machine:

- protocol header exchange, anonymous SASL, then the post-SASL header exchange
- `open` with the negotiated `max-frame-size`, `channel-max`, and
  `idle-time-out`
- the connection properties Azure records (product, version, platform,
  user-agent) and the `com.microsoft:georeplication` desired capability
- `begin` and `end` for sessions, and `close` for the connection
- empty-frame keep-alives at half the peer's advertised idle timeout
- per-channel frame routing through `registerChannel`

Anonymous SASL is used because Event Hubs carries the real credential over CBS,
matching the Go and Rust clients.

Every call that can wait takes a deadline in milliseconds, so a stalled peer
surfaces `error.Timeout` rather than hanging. `Clock` is a seam: production code
uses `IoClock`, and tests use `ManualClock` to drive idle-timeout behaviour
without sleeping.

```zig
var clock = amqp.IoClock.init(io);
var driver = try amqp.Driver.init(allocator, socket.transport(), clock.clock(), .{
    .container_id = container_id,
    .hostname = "myns.servicebus.windows.net",
    .desired_capabilities = &.{amqp.georeplication_capability},
    .properties = properties,
});
defer driver.deinit();

try driver.open(deadline_ms);
const remote_channel = try driver.beginSession(0, .{}, deadline_ms);
```

## Message codec

`message.zig` encodes and decodes the AMQP message sections — header, delivery
and message annotations, properties, application properties, body, and footer.
The body is a `data`, `sequence`, or `value` section.

```zig
const bytes = try amqp.encodeMessageAlloc(allocator, .{
    .properties = .{ .message_id = .{ .string = id } },
    .application_properties = props,
    .body = .{ .data = &.{payload} },
});
defer allocator.free(bytes);
```

## Sessions and links

`link.zig` builds sessions, senders, and receivers on top of the driver:

- attach and detach, matched to the peer's echoed attach by link name
- flow control, including credit rebasing onto our delivery count (§2.6.7) and
  draining, which waits for the sender to consume the outstanding credit
- multi-frame transfers, split to the negotiated `max-frame-size` on send and
  reassembled on receive. A delivery that arrives whole in one frame — nearly
  all of them — skips reassembly entirely, and `receive` hands out the buffer
  the delivery already owns rather than copying it into scratch storage, so a
  received body is copied once rather than three times
- settlement: accepted, rejected, and released outcomes, with a rejection
  surfacing the peer's error condition, one delivery at a time or a whole
  contiguous run in a single disposition
- pipelined sends: a configurable number of deliveries may be unsettled at
  once, so a link is not limited to one message per round trip
- session flow control: transfer ids advance per frame, and the peer's
  `incoming-window` is seeded from its `begin`, rebased on every flow, and
  waited on rather than overrun
- the Event Hubs link properties the Go and Rust clients send —
  `com.microsoft:receiver-name`, `com.microsoft:epoch`, and the
  `apache.org:selector-filter:string` filter used to pick a starting offset

```zig
var session = try amqp.Session.begin(allocator, &driver, 0, .{}, deadline_ms);
defer session.deinit();

const filters = [_]amqp.performative.Filter{
    .selector("amqp.annotation.x-opt-offset > '@latest'"),
};
const receiver = try amqp.openReceiver(&session, .{
    .name = link_name,
    .source_address = "myhub/ConsumerGroups/$Default/Partitions/0",
    .filters = &filters,
    .prefetch = 300,
}, deadline_ms);

const delivery = try receiver.receive(deadline_ms);
try receiver.accept(delivery);
```

`delivery` stays valid until the next `receive` returns, so copy anything you
need to keep. Prefetched deliveries queue up and are drained with a cursor
rather than by shifting the queue, which keeps a deep prefetch window linear.

Settling one delivery at a time costs a frame per message, which at a 300-deep
prefetch is 300 frames of bookkeeping. A disposition can name a `first`..`last`
range instead, and `SettleBatch` builds those runs safely — delivery ids belong
to the session rather than to the link, so anything else sharing the session
leaves gaps that a range must not span:

```zig
var settling = amqp.SettleBatch.init(receiver, .accepted);
var i: usize = 0;
while (i < 300) : (i += 1) {
    try settling.add(try receiver.receive(deadline_ms));
}
try settling.flush();
```

Nothing reaches the wire until `flush`, so abandoning a batch leaves its
deliveries unsettled and the peer redelivers them.

### Keeping deliveries in flight

`send` and `sendBytes` wait for the peer to settle each delivery, so a link
sends at most one message per round trip no matter how small the messages are.
Against a broker 30 ms away that caps a sender near 33 deliveries a second,
which is a network limit rather than a CPU one and so survives any amount of
encoding work.

`max_in_flight` lifts the cap. `sendBytesAsync` writes the transfer frames and
returns a `DeliveryToken` instead of waiting, and `awaitSettlement` retires the
oldest delivery and reports the peer's verdict against the token that names it:

```zig
const sender = try amqp.openSender(&session, .{
    .name = link_name,
    .target_address = "myhub",
    .max_in_flight = 8,
}, deadline_ms);

for (payloads) |payload| {
    _ = sender.sendBytesAsync(payload, .{}, deadline_ms) catch |err| switch (err) {
        error.InFlightWindowFull => {
            _ = try sender.awaitSettlement(deadline_ms);
            _ = try sender.sendBytesAsync(payload, .{}, deadline_ms);
        },
        else => return err,
    };
}
while (sender.inFlight() > 0) {
    const settlement = try sender.awaitSettlement(deadline_ms);
    if (settlement.outcome != .accepted) return error.SendFailed;
}
```

A full window is an error rather than a wait: only the caller can retire a
delivery, so blocking inside `sendBytesAsync` until one was retired would wait
on something only the blocked caller could do.

A refused delivery comes back as `Settlement.outcome`, not as an error, because
a pipelining caller needs to know *which* delivery the broker turned down —
`sendBytes` keeps mapping the outcome onto `error.SendRejected` for callers that
send one at a time. `Outcome` deliberately carries no payload: the peer's own
`DeliveryState` holds slices decoded into the frame's arena, which is released
before `pump` returns, so handing that union back would hand back freed memory.
The condition behind a rejection is copied into `Settlement.rejection`, owned by
the sender and valid until its next `awaitSettlement`.

The default `max_in_flight` is 1, so a sender behaves exactly as it always has
until it is asked for more. `sendBytes` waits for the oldest delivery, which is
only its own when nothing else is outstanding, so it reports
`error.DeliveriesInFlight` rather than mixing with `sendBytesAsync` and
attributing one delivery's verdict to another. A send that never reaches a
verdict retires its own entry, so a timed-out send leaves the sender as usable
as it was before.

Deliveries settle in the order they were sent, and the ring holding them is
allocated once at attach, so a silent peer costs a fixed amount of memory rather
than a growing one.

### Session flow control

Session ids count transfer *frames*, not deliveries (§2.5.6). Every frame of a
multi-frame delivery consumes one, even though only the first frame carries the
delivery id, so a message split across seventeen frames advances the session by
seventeen and the next delivery's id follows from there. Numbering by delivery
instead leaves every later id short of the peer's count, and the peer's
dispositions then name ids the sender never issued — its verdicts match nothing
and the send waits out its deadline.

The peer's `begin` and every `flow` state how many frames it can still absorb.
That capacity is rebased onto what has already gone out:

```
remote-incoming-window = next-incoming-id(flow) + incoming-window(flow) - next-outgoing-id
```

The subtraction is the point. `incoming-window` describes the peer's room as of
the id it names, so taking it at face value re-credits every frame sent since
and lets a sender run past the window. A flow may omit `next-incoming-id` until
the peer has seen a transfer, in which case the spec substitutes the session's
first outgoing id. The result is serial arithmetic, so a peer that shrinks its
window below what is already in flight yields a span in the top half of the id
space rather than a negative — read raw, that is a window of nearly four
billion.

A sender waits for the peer to reopen a closed window before writing the next
frame, including partway through a multi-frame delivery. Unlike a full in-flight
ring, this is something waiting can actually resolve: the peer alone reopens it,
and it does so with a flow the sender picks up while pumping.

A handle in an inbound frame is scoped to the peer that sent it, so links are
looked up by the handle the peer chose, never by our own. A session holding both
a CBS link and an events link would otherwise cross its deliveries.

## Request/response links

`rpc.zig` pairs a sender with a receiver attached to a private reply address,
correlating each reply to its request by message id. Both `$cbs` and
`$management` are built on it, as they are in the Go client.

A reply's status rides in application properties rather than in the delivery
outcome, so a refused request still arrives as an accepted transfer. Both
spellings brokers use — `status-code` and `statusCode` — are accepted, as is
any integral encoding of the code.

## CBS authentication

Event Hubs carries no credential in the SASL exchange, so every entity is
authorised separately by putting a token to `$cbs` before a link on that path
attaches. `cbs.zig` sends the `operation`, `type`, `name`, and `expiration`
application properties with the token as the message value, matching Go's
layout exactly, and maps a 401 to `error.Unauthorized` so callers do not retry
a refused credential.

```zig
const client = try amqp.Cbs.open(&session, .{ .link_id = id }, deadline_ms);
defer client.deinit();

try client.authorize(audience, credential.tokenProvider(), now_ms, deadline_ms);
```

Tokens are cached per audience and refreshed six minutes before expiry with up
to five seconds of jitter, backing off thirty seconds after a failure — the
same policy as the Rust client. A pre-formed SAS from a connection string is
marked non-refreshable and schedules nothing, since renewing it returns the
same expiry; the broker still enforces it, and `invalidateAll` re-authorises
every path after a connection is recovered.

Acquiring the token is the credential's job. `TokenProvider` is a
function-pointer struct, so this module does not depend on the credential type,
and it is only consulted when a round-trip is actually needed.

## Management

`management.zig` drives the `$management` endpoint. A request carries the
`operation` (`READ` for every metadata read), the entity `type`, the `name`,
and the caller's `security_token`, with caller-supplied properties merged after
them. The path has to be authorised over CBS before this link attaches.

```zig
const client = try amqp.Management.open(&session, .{ .link_id = id }, deadline_ms);
defer client.deinit();

var response = try client.call(.{
    .entity_type = "com.microsoft:eventhub",
    .name = hub_name,
    .security_token = token,
}, deadline_ms);
defer response.deinit();
```

A non-2xx reply fails the call. Zig errors carry no payload, so the broker's
status and description are recorded on `last_error`, the same way the
connection driver records a remote error. `callRaw` returns the reply whatever
its status, for callers that treat some codes as expected.

`begin` and `awaitReply` are separate so several requests can be in flight at
once; each is matched to its own reply however the broker orders them, and a
reply that arrives before its caller asks for it is held rather than dropped. A
detach fails everything outstanding instead of leaving a caller blocked until
its deadline.

## Tests

`test_peer.zig` drives the far end of a `MemoryTransport`, writing the frames a
broker would send and parsing back what the driver emitted. The link, RPC, and
CBS tests share it, since they all need the same open/begin/attach preamble
before the behaviour under test starts.

Run the package's independent tests from this directory:

```bash
zig build test --summary all
```
