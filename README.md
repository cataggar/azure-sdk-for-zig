# Azure DevOps for Zig

`azure_sdk_devops` puts one authenticated client in front of the 44
generated Azure DevOps API areas. It adds Personal Access Token and
Entra ID authentication, a shared retry/telemetry pipeline,
continuation-token paging, and Azure DevOps' idiosyncratic error
reporting to the `azure_rest_devops` protocol package.

Only API version **7.2** is supported, matching
[`azure-devops-rust-api`](https://github.com/microsoft/azure-devops-rust-api).

## Getting started

```zig
const std = @import("std");
const core = @import("azure_sdk_core");
const devops = @import("azure_sdk_devops");

pub fn main(init: std.process.Init) !void {
    var transport = core.http.StdHttpTransport.init(init.gpa, init.io);
    defer transport.deinit();
    var crypto = core.crypto.StdCryptoProvider.init(init.io);
    const runtime = core.http.HttpRuntime.init(
        transport.asTransport(),
        crypto.asProvider(),
    );

    var client = try devops.DevOpsClient.init(init.gpa, .{
        .organization = "contoso",
        .credential = .fromPat(pat),
        .runtime = runtime,
    });
    defer client.deinit();

    var git = client.git();
    var repositories = git.repositories();
    const result = try repositories.list(
        init.gpa,
        "contoso",
        "my-project",
        null,
        null,
        null,
    );

    // Azure DevOps wraps every collection in a `{count, value}` envelope,
    // so list operations return that rather than a bare slice.
    for (result.value orelse &.{}) |repository| {
        std.debug.print("{s}\n", .{repository.name orelse "<unnamed>"});
    }
}
```

`organization` is both stored on the client and passed to each operation.
The generated operations take it as a path parameter, so the field exists
so callers can write `client.organization` instead of threading the name
through every call site.

Azure DevOps never returns a bare JSON array: every collection comes back
wrapped in an object carrying a `value` array and, on most endpoints, a
`count`. List operations therefore return a generated `<Item>List`
envelope, and callers read `.value`. `count` is optional because some
endpoints omit it.

## The 44 areas

Each area has an accessor on `DevOpsClient` returning that area's
generated root client:

```zig
var git = client.git();                   // GitClient
var build = client.build();               // BuildClient
var wit = client.workItemTracking();      // work item tracking
var graph = client.graph();               // identities and groups
var core_area = client.core_area();       // projects and teams
```

Azure DevOps has an API area literally named `core`, which collides with
the Zig Core package, so its accessor is `core_area`.

Areas do not share a host. `git` lives on `dev.azure.com`, `graph` on
`vssps.dev.azure.com`, package feeds on `pkgs.dev.azure.com`, and so on —
14 hosts in total. Every generated area client carries its own default
endpoint, so an accessor only overrides the endpoint when you supplied
one. Set `endpoint` for Azure DevOps Server, which serves every area from
a single collection URL:

```zig
var client = try devops.DevOpsClient.init(allocator, .{
    .organization = "DefaultCollection",
    .endpoint = "https://tfs.contoso.com/tfs",
    .credential = .fromPat(pat),
    .runtime = runtime,
});
```

## Authentication

Three credential kinds:

```zig
.credential = .fromPat(pat)                    // Personal Access Token
.credential = .fromTokenCredential(credential) // Entra ID
.credential = .unauthenticated                 // public projects only
```

A PAT is sent as HTTP Basic with an empty user name, which is what Azure
DevOps expects. A `TokenCredential` is asked for a token against the
Azure DevOps first-party resource
(`499b84ac-1321-427f-aa17-267ca6975798/.default`) and the result is
cached until five minutes before it expires.

Azure DevOps answers a missing or invalid credential with
`203 Non-Authoritative Information` and an HTML sign-in page at least as
often as with `401`, so a naive status check reports success on an
unauthenticated request. `devops.isSignInPage` recognises that
response, and `devops.parseServiceError` turns an Azure DevOps error
body into a structured `ServiceError`.

## Paging

Azure DevOps pages with an opaque continuation token rather than a
`nextLink` URL, so Core's `PipelinePager` — which re-sends a
server-supplied link — does not apply. `ContinuationPager` drives a
listing operation to exhaustion instead:

```zig
var pages = devops.ContinuationPager(Entry, Fetcher).init(&fetcher);
while (try pages.next(allocator)) |page| {
    defer allocator.free(page);
    for (page) |entry| { … }
}
```

`Fetcher` is a small struct capturing the sub-client and the operation's
fixed parameters, with one method:

```zig
pub fn fetch(self: *Fetcher, allocator: std.mem.Allocator, token: ?[]const u8) !devops.Page(T)
```

Some Azure DevOps operations report the next token in the response body
and some in the `x-ms-continuationtoken` response header. Both are
reachable: header-paged operations return a result union whose
`status_200.headers` carries `x_ms_continuationtoken` and whose
`status_200.body` is the collection envelope, so the fetcher reads
`body.value`. An absent header is the end-of-collection signal. See
`examples/list_builds.zig` for a header-token pager and
`examples/page_audit_log.zig` for a body-token one.

## Raw operations

`devops.protocol` re-exports `azure_rest_devops`, so generated models,
enums and clients are reachable without a second dependency:

```zig
const models = devops.protocol.git.models;
const Repository = models.GitRepository;
```

`DevOpsClient.areaClient` builds any generated root client on the shared
pipeline, so an area without a named accessor is still one call away.

## Runtime and ownership

`DevOpsClient` has one canonical dependency path: callers supply a
`core.http.HttpRuntime`, and the client builds its telemetry, retry, and
credential policies around that runtime. Runtime, transport, and crypto
provider descriptors are copied by value. Their backend contexts are borrowed
and must outlive the client, every derived area/sub-client or pager fetcher,
every token-credential call, and every open operation.

The selected HTTP transport and SDK crypto provider remain independent and are
preserved through all generated derived clients. Entra ID token credentials
receive that same runtime for each token acquisition. This package performs no
MD5, SHA-256, HMAC-SHA256, or random-byte operation itself; it has no direct
`std.crypto` use or standard-provider fallback. PAT Base64 is wire encoding,
not hashing or signing.

The client borrows `organization`, `endpoint`, `scope`, credential, and runtime
backend contexts. Deinitialize the client before releasing them. A
`ContinuationPager` borrows its fetcher; fetchers normally contain a generated
sub-client whose copied pipeline still borrows the original runtime contexts.

## Examples

```sh
export AZURE_DEVOPS_ORGANIZATION=contoso
export AZURE_DEVOPS_PAT=…
export AZURE_DEVOPS_PROJECT=my-project

zig build examples
./zig-out/bin/devops-list-projects
./zig-out/bin/devops-list-repositories
./zig-out/bin/devops-list-builds
./zig-out/bin/devops-query-work-items
./zig-out/bin/devops-page-audit-log
```

## Live tests

`zig build live-test` runs read-only tests against a real organization.
They skip themselves unless `AZURE_DEVOPS_ORGANIZATION` and
`AZURE_DEVOPS_PAT` are set.

## License

MIT. See `LICENSE.txt`.
