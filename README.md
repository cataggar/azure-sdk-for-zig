# azure_sdk_amqp

AMQP 1.0 integration for Azure SDK clients, backed by the pure Zig
[`azure-uamqp-zig`](https://github.com/cataggar/azure-uamqp-zig) package.

- Source: `sdk/core/amqp`
- Release branch: `sdk/core_amqp`
- Initial version: `0.1.0`
- External dependency: `uamqp`

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
SASL performatives as described lists. Encoding is written here rather than
delegated to `uamqp.encoder` because that encoder writes array elements of
variable-width types without their length prefix, which no peer accepts.

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

CBS authentication, the `$management` link, and message transfer are not here
yet.

Run its independent tests from this directory:

```bash
zig build test --summary all
```
