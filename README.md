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

`RecordingTransport.toJson` emits version 2 recordings. Accepted request and
response bodies are represented losslessly as base64 with an explicit encoding
field. Every non-empty body is rejected by default and requires an explicit
caller body-policy decision. Approved textual and binary bodies, including NUL
and non-UTF-8 data, then round-trip exactly through `parseJson`. Parsed
recordings can be passed directly to playback:

```zig
var parsed = try testing.parseJson(allocator, json);
defer parsed.deinit();
var playback = testing.PlaybackTransport.init(allocator, parsed.asSlice());
```

Recording stages a complete redirect/retry chain before publishing any of its
exchanges. Buffered chains commit only when their final nonretry response is
returned; a retryable final response remains tentative until it is accepted or
the original request restarts. Streaming chains commit only after the final
operation finishes. Intermediate redirect aborts remain tentative, while
redirect allocation failure, retry restart from the original request,
operation failure, abort, or cancellation discards the whole tentative chain.

Recording JSON replaces recognized authorization, token, secret, key, cookie,
and SAS-bearing header values with `REDACTED`. Credential URL headers such as
`x-ms-copy-source`, `x-ms-rename-source`, and
`x-ms-file-rename-source` are fully redacted; recognized credential-specific
query parameters in request URLs and location-style headers are value-redacted.
Each redacted header carries a structured `redacted` flag, so playback
wildcards only values that recording explicitly classified as credentials.
Those structured redactions match a caller-supplied live credential, while
nonsensitive query fields such as App Configuration's `key` filter and all
other nonsensitive URL components, headers, and bodies remain exact-match
requirements.

`Location`, `Content-Location`, `Operation-Location`, and
`Azure-AsyncOperation` retain their origin/path and nonsensitive query fields;
only recognized credential query values are replaced. This keeps redirect and
LRO URLs replayable. Malformed or unsafe location values are fully redacted.
Credential source URL headers such as `x-ms-copy-source` remain fully redacted.
URL sanitization parses the URI reference from its start, percent-decodes path
and query components through a bounded recursive decoder, recursively inspects
URI-valued parameters, redacts recognized credential names and
credential-shaped values, and rejects credential-bearing paths or fragments.
Safe fragments are preserved in recorded URL headers; Core strips them when
constructing the redirected HTTP request. Unsafe or malformed location
fragments cause full header redaction. Relative redirects such as
`/callback?return=https://...` remain replayable when their decoded values are
safe. Safe network-path references such as `//example.test/final` and pathless
absolute references such as `https://example.test?mode=one` are preserved;
userinfo and credential-bearing authorities are rejected. Decode depth and
size are bounded, and malformed or over-depth encodings fail closed.

Header names are checked case-insensitively. The default preserves only a
known-safe standard/Azure header allowlist, after inspecting every value for
signed URLs, JWTs, connection strings, and other recognized credentials.
Unknown application and metadata headers are redacted. Credential-shaped names,
including metadata suffixes such as `password`, `pwd`, `private-key`, and
`connection-string`, are also redacted. Applications can add redactions or
explicitly preserve a known-safe false positive with an exchange-aware header
policy:

Volatile request headers—including request/correlation IDs, `date`,
`x-ms-date`, `traceparent`, and `tracestate`—are structurally redacted by
default so freshly generated Core pipeline values wildcard during playback.
Returning `preserve` from the header policy makes a selected value exact.

```zig
fn headerPolicy(
    context: ?*anyopaque,
    header: testing.HeaderSafetyContext,
) testing.HeaderPolicyDecision {
    _ = context;
    if (isApplicationCredential(header.name)) return .redact;
    if (isKnownSafeMetadataLabel(header.name)) return .preserve;
    return .inspect;
}
```

`preserve` bypasses a conservative built-in classification and therefore
asserts that the persisted value is not a credential. Policy contexts are
borrowed through `toJson`.

Credential-bearing JSON fields are detected structurally and
case-insensitively, including nested list-keys results, connection strings,
API keys, tokens, passwords, SAS URIs, and common Azure key fields. Form,
connection-string, multipart field names, XML elements/attributes, and common
private-key envelopes receive conservative checks. String scalars are scanned
recursively for signed URLs/SAS parameters, connection strings, private-key
containers, and JWT-shaped identity tokens. Key Vault secret, certificate, and
JWK rules apply only to parsed trusted Azure vault hosts and matching resource
paths; Kusto rules likewise use trusted service host suffixes. ARM
list/regenerate credential schemas—including Batch, AI Search, Event Grid,
Cognitive Services, Cosmos DB, and Container Registry—apply only to the
explicit public, US Government, China, and German management hosts. Storage
User Delegation Key XML is recognized only on trusted sovereign Blob service
hosts and the matching action. Managed HSM host rules include every supported
sovereign suffix, including `managedhsm.microsoftazure.de`. Endpoint path
segments and query names/values are canonicalized with the same bounded
recursive decoder before schema classification; malformed or over-depth
endpoint encodings fail closed. Arbitrary URL text cannot activate these
schema rules, so App Configuration key/value documents and paths containing
words such as `vault/secrets` remain recordable and exact.

The default body contract is deny-by-default: every non-empty body is rejected
with `BodyPolicyRequired` unless `bodyPolicyFn` classifies that exact exchange.
Before default rejection, the recorder still detects known plaintext and
structured credentials and returns `SensitiveBodyRequiresSanitization`.
Returning `inspect` explicitly opts a recognized textual content type into
built-in structural checks. A declared JSON content type must parse
successfully. Only untyped UTF-8 text,
`text/*`, JSON, XML, form URL encoding, JavaScript/ECMAScript, and GraphQL are
recognized as textual; PDF, CBOR, PKCS7, protobuf, arbitrary vendor/container
types, Unicode BOMs, NUL-bearing data, UTF-16/32 charsets, non-identity content
encodings, and non-UTF-8 bodies are opaque. Returning `allow_opaque` is the
explicit trust boundary for a caller-verified opaque body:

```zig
fn bodyPolicy(
    context: ?*anyopaque,
    body: testing.BodySafetyContext,
) testing.BodyPolicyDecision {
    _ = context;
    if (isKnownSafeAppConfigurationExchange(body)) return .inspect;
    if (isKnownSafeBinaryEndpoint(body.url)) return .allow_opaque;
    return .reject_sensitive;
}

var recording = testing.RecordingTransport.initWithOptions(
    allocator,
    transport,
    .{
        .bodyPolicyFn = &bodyPolicy,
        .headerPolicyFn = &headerPolicy,
    },
);
```

`inspect` does not sanitize or rewrite bodies; it persists only bodies that pass
the built-in checks, and playback continues to match request bodies exactly.
`reject_sensitive` rejects application-specific schemas. Private-key markers
and detectable plaintext credentials cannot be bypassed by `allow_opaque`;
callers that approve otherwise opaque encodings take responsibility for their
decoded contents. Multipart bodies are also scanned before opaque allowance,
including form-data names, embedded HTTP authorization headers, signed URLs,
JWTs, and parseable structured part payloads. Declared multipart boundaries are
parsed from `Content-Type` and recognized only as exact MIME delimiter lines;
legal preambles, epilogues, and nested multipart parts are inspected, while
invalid close suffixes, missing closes, and malformed multipart structures fail
closed. Policy contexts are borrowed through `toJson`.

Playback matches without consuming an exchange. It advances the caller-
serialized index only after a nonredirect buffered response succeeds or a
final streaming operation finishes successfully. Redirect chains remain a
single tentative transaction until their final response/operation commits, so
allocation failure at any Core redirect-resolution/request-construction step
can retry the original request. Aborted, cancelled, or failed streaming
operations remain retryable.

Run its independent tests from this directory:

```bash
zig build test --summary all
```

The test target runs both Core raw-transport and pipeline conformance contracts,
plus Core allocation-failure fixtures.
