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
duplicates are preserved.

`RecordingTransport.toJson` emits version 2 recordings. Request and response
bodies are always represented as base64 with an explicit encoding field, so
empty, NUL-containing, non-UTF-8, and normal UTF-8 bodies round-trip losslessly
through `parseJson`. Parsed recordings can be passed directly to playback:

```zig
var parsed = try testing.parseJson(allocator, json);
defer parsed.deinit();
var playback = testing.PlaybackTransport.init(allocator, parsed.asSlice());
```

Recording JSON replaces recognized authorization, token, secret, key, cookie,
and SAS-bearing header values with `REDACTED`. Credential URL headers such as
`x-ms-copy-source`, `x-ms-rename-source`, and
`x-ms-file-rename-source` are fully redacted; recognized credential-specific
query parameters in request URLs and location-style headers are value-redacted.
During playback, those structured redactions match a caller-supplied live
credential, while nonsensitive query fields such as App Configuration's
`key` filter and all other nonsensitive URL components, headers, and bodies
remain exact-match requirements.

Credential-bearing JSON fields are detected structurally and
case-insensitively, including nested list-keys results, connection strings,
API keys, tokens, passwords, SAS URIs, and common Azure key fields. Form,
connection-string, multipart field names, XML elements/attributes, and common
private-key envelopes receive conservative checks. Key Vault secret endpoints
treat root `value` fields as sensitive, while App Configuration key/value
documents remain recordable and exact.

The default threat model accepts structurally inspected safe JSON, form, and
plain-text bodies, but rejects opaque non-UTF-8 bodies, multipart bodies, XML
bodies, and malformed JSON-like bodies. This prevents DER/PKCS#12, UTF-16
secret documents, and unknown containers from being base64-obscured under a
false sanitization guarantee. A caller that knows a specific rejected
opaque/XML/multipart exchange is safe can opt in with an exchange-aware policy:

```zig
fn bodyPolicy(
    context: ?*anyopaque,
    body: testing.BodySafetyContext,
) testing.BodyPolicyDecision {
    _ = context;
    return if (isKnownSafeBinaryEndpoint(body.url)) .allow_opaque else .inspect;
}

var recording = testing.RecordingTransport.initWithOptions(
    allocator,
    transport,
    .{ .bodyPolicyFn = &bodyPolicy },
);
```

The callback may also return `reject_sensitive` for application-specific
schemas. Built-in recognized credential fields and private-key markers cannot
be bypassed by `allow_opaque`. Policy contexts are borrowed through `toJson`.

Run its independent tests from this directory:

```bash
zig build test --summary all
```
