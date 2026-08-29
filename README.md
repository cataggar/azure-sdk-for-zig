# azure_sdk_testing

Testing helpers for Azure SDK packages, including full-contract recording and
playback HTTP transports.

- Source: repository root on the `sdk/testing` package branch
- Release branch: `sdk/testing`
- Version: `0.2.0`
- Internal dependency: `azure_sdk_core` 0.3.0 at
  `bc77bcacbb64af935ca53d60bf8a351c9592bc41`

Transport descriptors are copied by value while their contexts are borrowed.
Keep playback/recording transport values, wrapped transport contexts, crypto
provider contexts, and any open operations alive for the full lifetime stated
by their API documentation. These testing transports are caller-serialized.

Construct a runtime with independently selected dependencies:

```zig
const runtime = testing.initHttpRuntime(
    playback.asTransport(),
    crypto_provider,
);
```

Playback validates method, exact URL, body presence/content, and every
recorded request header. Additional live request headers are allowed so
volatile telemetry can be omitted from recordings. Response header order and
duplicates are preserved. Recording JSON redacts recognized sensitive headers
and URL query values, and refuses to serialize bodies containing recognized
credential fields rather than emitting them unsanitized.

Run its independent tests from this directory:

```bash
zig build test --summary all
```
