# azure_sdk_messaging_common

Shared messaging types used by Event Hubs and Service Bus.

## Connection strings

`ConnectionStringProperties.parse` accepts the two shapes the portal and the
other Azure SDKs produce: an embedded `SharedAccessKeyName`/`SharedAccessKey`
pair, or a pre-formed `SharedAccessSignature`. Keys are matched
case-insensitively and a value may contain `=`, as base64 keys and SAS tokens
do. A string with neither a key nor a signature is rejected at parse time
rather than failing later as an opaque broker 401.

`UseDevelopmentEmulator=true` sets `emulator`, which switches `scheme()` from
`amqps` to `amqp` and makes `useTls()` false. The emulator is only addressable
as `sb://host` or `sb://host:port`, and any other endpoint is rejected.

Every slice borrows from the connection string, which must outlive the result.

## Shared Access Signatures

`sas.sign` produces the token format the brokers accept:

```text
SharedAccessSignature sr={encoded resource}&sig={encoded HMAC}&se={expiry}&skn={key name}
```

The string-to-sign is `encoded_resource + "\n" + expiry`. HMAC-SHA256 uses the
exact UTF-8 bytes of `SharedAccessKey`; the value is not Base64-decoded. Raw
and Base64-encoded temporary MAC material is wiped on every success and failure
path. Signing uses an explicit `azure_sdk_core.crypto.CryptoProvider`; there is
no fallback to the standard provider. Encoding follows Go's
`url.QueryEscape`: everything outside `A-Za-z0-9-_.~` is escaped and a space
becomes `+`. The resource is lowercased after encoding, so its escapes read
`%3a`/`%2f`; the signature is not lowercased, so its escapes read `%2B`/`%3D`.
That asymmetry is deliberate and is pinned by a reference vector cross-checked
against the Go and Rust SDKs.

`SasCredential` implements `azure_sdk_core`'s `TokenCredential`, so downstream
clients only ever see a credential. It either signs a fresh token per request
from a shared key, defaulting to one hour of validity, or hands back a
pre-formed signature and reports that signature's own `se` expiry. A pre-formed
signature cannot be re-signed, so `isRefreshable` is false and a request made
after it expires fails with `error.SignatureExpired` instead of handing back a
token the broker will reject.

A shared-key credential signs with the provider in the `HttpRuntime` supplied
to each `TokenCredential.getToken` call, so provider selection follows the
client runtime and no provider is retained by the credential. A pre-formed
token remains independent of the runtime provider.

The `azure_sdk_core` dependency is provisionally pinned to the merged provider
API commit. It must be repinned to the final `azure_sdk_core/v0.3.0` release
commit and package hash before this package change is merged.

Use `sas.audienceFor` to build the `amqps://{namespace}/{entity}` resource. An
entity-scoped token authorizes every partition and consumer group beneath it,
so one token covers all of a client's links.

The CBS token type constants are `cbs_token_type_sas`
(`servicebus.windows.net:sastoken`) and `cbs_token_type_jwt` (`jwt`).

Release branch: `sdk/messaging_common`. The package depends on
`azure_sdk_core` and starts at `0.1.0`.

## Development

```bash
zig build test --summary all
```
