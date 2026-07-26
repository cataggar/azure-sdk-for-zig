# azure_sdk_data_tables

Hand-written, idiomatic Zig conveniences for **Azure Storage Tables**.

Release branch: `sdk/data_tables`. The package starts at `0.1.0` and currently
preserves its prototype `TableClient`, `TableServiceClient`, and `TableEntity`
exports while the parity roadmap in
[tracker #148](https://github.com/cataggar/azure-sdk-for-zig/issues/148) is
implemented.

## Package boundary and protocol provenance

Two independently released packages form the planned Tables stack:

| Package | Branch | Owns |
|---|---|---|
| `azure_rest_data_tables` | `rest/data_tables` | Generated HTTP clients, wire models, operation options, exact request/response serialization, status codes, headers, and regeneration metadata |
| `azure_sdk_data_tables` | `sdk/data_tables` | Authentication, stable pipelines, typed and dynamic entities, paging, transactions, SAS, connection strings, structured errors, and convenience APIs |

The generated package must come from
`Azure/azure-rest-api-specs/specification/cosmos-db/data-plane/Tables/tspconfig.yaml`.
The directory name is historical: this is the shared Azure Tables wire
contract. **Cosmos DB Table API runtime support is excluded.** Cosmos endpoint
audiences, request transforms, compatibility policies, and emulator behavior
belong in a separate Cosmos SDK.

The contract was checked on 2026-07-26 at upstream commit
`0744f52a86919d243ba2225e55bdb9c87bf521a5`; the Tables source was last changed
at `9bec2c0a197179ccddec40f18c245e0817c25d62`. `Data.Tables.Versions` and the
`stable/` directory contain only `2019-02-02`. Generation must nevertheless
re-read `Data.Tables.Versions`, choose the newest stable member, and record an
immutable upstream commit every time it is regenerated. A generic Storage
`x-ms-version` is not a substitute for a Tables contract version.

The SDK pins generated package commit
`67d001426e73385a944a1bacde8d482b81dbf5ae` and Zig package hash
`azure_rest_data_tables-0.1.0-CqXnR3B2AQBJhSOC2e17bpbGPj5hN9RjLcpQ01OfFGkf`,
and re-exports its public root as `protocol`. Its provenance records upstream
spec commit `0744f52a86919d243ba2225e55bdb9c87bf521a5`, generator commit
`f5dde2c7aa95e7a5ac496793b5527c9a212d642c`, and stable API version
`2019-02-02`.

`ProtocolClient` is the shared validated bridge to generated calls. It
normalizes endpoint paths while preserving SAS query bytes, maps metadata,
request ID, server timeout, client timeout, and per-call policy options, and
adapts generated values with allocator-owned raw response headers. Generated
models remain the only wire models.

## Microsoft Entra authentication

Create owning token-authenticated clients with
`TableServiceClient.initWithToken` or `TableClient.initWithToken`. Both copy
their endpoint, API version, telemetry application ID, default client request
ID, and policy pointer list. The credential, transport, and policy objects
remain borrowed and must outlive the client. The bearer policy requests
`https://storage.azure.com/.default`. Token-authenticated constructors require
HTTPS, including for custom and private endpoint hosts. HTTP remains available
to future explicit emulator Shared Key and no-token constructors.

`TableServiceClient.getTableClient` creates a table client that owns its table
name and protocol configuration while borrowing the service client's stable
pipeline state. Deinitialize every derived client before its service client.
Derived clients share the parent's bearer-token cache and transport.

## Shared Key, SAS, and connection strings

`SharedKeyCredential.init` validates and decodes an account key, and
`initWithSharedKey` uses the Table-only `SharedKeyLite` canonical form. The
signer runs after retry, so it applies a current `x-ms-date`, API version, and
signature to every attempt. Use `initWithSasUrl` only with a complete signed
URL; its query bytes are retained verbatim and the pipeline has no
`Authorization` policy. Client formatting omits all query strings.

`initFromConnectionString` accepts account-key and SAS strings with
`DefaultEndpointsProtocol`, `EndpointSuffix`, or `TableEndpoint`, plus
`UseDevelopmentStorage=true` for Azurite. It rejects duplicate, unknown, and
ambiguous fields before creating a pipeline. Token authentication is always
HTTPS; cleartext Shared Key/SAS endpoints are limited to local emulators.

`sas.AccountSignatureValues` generates Table-only account SAS values, and
`sas.TableSignatureValues` generates table service SAS values including stored
identifier and inclusive partition/row bounds. Its `accessPolicy` is a tagged
union: `.adHoc` requires permissions and expiry, while `.stored` accepts only
the identifier, so inline access fields cannot accidentally accompany a stored
policy. A partition bound may stand alone; a row bound requires its matching
partition. Permissions, services, and resource types are emitted in Azure's
required order; invalid time, permission, identifier, IP, and key-range
combinations fail before signing. SAS times use UTC whole-second precision and
the canonical Tables version `2019-02-02`.
`getAccountSasUrl` and `getTableSasUrl` are available only on Shared Key
clients. Their caller-owned URL results are secrets; SAS value/query formatting
is redacted. A full generated table URL can be passed directly to
`TableClient.initWithSasUrl`. It recognizes table scope from one unambiguous,
decoded `tn` parameter and retains the complete encoded query bytes verbatim;
account SAS URLs never infer scope from their path.

Client options configure retry count/delays, telemetry application ID, a
default client request ID, a default operation timeout, API version, and
caller policies. Per-operation request IDs and operation timeouts override
client defaults. The stable policy order is request ID, telemetry, retry,
bearer authentication, client policies, then per-operation policies. Thus
authentication and caller policies run on every retry.

Initialized clients may be moved because policy objects and their type-erased
pointers live in allocator-owned stable storage. Calls that share a pipeline
must nevertheless be serialized: the bearer-token cache and standard HTTP
transport are mutable and not thread-safe. Callers may provide external
synchronization when sharing a client or using multiple derived clients.

The canonical TypeSpec does not model `$batch`; the generated provenance and
operation inventory test prove that gap. This layer does not hand-write a
replacement: the later transaction issue owns its documented implementation.

## Entity CRUD

`TableClient.addEntity` accepts either a comptime-validated caller struct or a
`DynamicEntity`; `getEntityAs(T, ...)` decodes either form. The matching
`*Result` methods retain structured service failures, while simple methods map
them to operation errors. `EntityResponse(T)` owns its decoded value, ETag,
OData metadata, selected and raw headers in an arena; call `deinit`.

`DeleteEntityOptions.if_match` defaults to `"*"` and accepts an ETag for a
conditional delete through `deleteEntityWithOptions`. The original
`getEntity(allocator, pk, rk)`, `createEntity`, and
`deleteEntity(allocator, pk, rk)` raw-response calls retain exact source
compatibility; explicit `getEntityRaw` and `deleteEntityRaw` aliases are also
available.

## Checked feature-parity contract

`[x]` means the Go capability has been reviewed and assigned a Zig API owner;
it does **not** claim that a later roadmap phase is already implemented.

### Construction, authentication, and pipeline

| Checked | Go `sdk/data/aztables` capability | Planned Zig API |
|---|---|---|
| [x] | `NewServiceClient` / `NewClient` | `TableServiceClient.initWithToken` / `TableClient.initWithToken` |
| [x] | `NewServiceClientWithSharedKey` / `NewClientWithSharedKey` | `initWithSharedKey`; Tables-specific `SharedKeyCredential` and SharedKeyLite policy |
| [x] | `NewSharedKeyCredential`, account-name access, and key rotation | `auth.SharedKeyCredential.init`, `accountName`, and `updateKey` |
| [x] | `NewServiceClientWithNoCredential` / `NewClientWithNoCredential` | `initWithSasUrl` |
| [x] | `NewServiceClientFromConnectionString` | `TableServiceClient.initFromConnectionString` and matching direct table constructor |
| [x] | Service client `NewClient` | `TableServiceClient.getTableClient` |
| [x] | Core client options, retry, telemetry, request IDs, cloud token auth | `options`, `pipeline`, and `auth`; Storage bearer scope is `https://storage.azure.com/.default` |
| [x] | Storage and Azurite connection strings | `connection_string` |

### Tables, entities, administration, and transactions

| Checked | Go capability | Planned Zig API |
|---|---|---|
| [x] | Service `CreateTable` | `TableServiceClient.createTable` / `createTableResult` |
| [x] | Table client `CreateTable` convenience | `TableClient.createTable` / `createTableResult` |
| [x] | Service `DeleteTable` | `TableServiceClient.deleteTable` / `deleteTableResult` |
| [x] | Table client `Delete` convenience | `TableClient.deleteTable` / `deleteTableResult` |
| [x] | `NewListTablesPager` with filter, select, top, format, and continuation | `TableServiceClient.listTables` returning `TablePager` |
| [x] | `AddEntity` | generic `TableClient.addEntity` / `addEntityResult` |
| [x] | `GetEntity` | generic `TableClient.getEntityAs` / `getEntityResult`; raw-compatible `getEntity` |
| [x] | `DeleteEntity` with `IfMatch` | `TableClient.deleteEntityWithOptions` / `deleteEntityResult`; raw-compatible `deleteEntity` |
| [x] | `UpdateEntity` merge and replace with ETags | `TableClient.updateEntity` / `updateEntityResult` plus `UpdateMode` |
| [x] | `UpsertEntity` merge and replace | `TableClient.upsertEntity` / `upsertEntityResult` |
| [x] | `NewListEntitiesPager` with filter, select, top, format, and two continuation keys | generic `TableClient.listEntities` returning `EntityPager(T)` |
| [x] | `GetAccessPolicy` / `SetAccessPolicy` | `TableClient.getAccessPolicies` / `setAccessPolicies` and result variants |
| [x] | `SubmitTransaction` and all six action kinds | `TransactionBuilder` and `TableClient.submitTransactionResult` |
| [x] | `GetProperties` / `SetProperties` | `TableServiceClient.getProperties` / `setProperties` and result variants |
| [x] | `GetStatistics` | `TableServiceClient.getStatistics` / `getStatisticsResult` |

### SAS and model families

| Checked | Go capability or model family | Planned Zig API |
|---|---|---|
| [x] | `GetAccountSASURL`, account permissions, resource types | `sas.AccountSignatureValues`, `AccountPermissions`, `AccountResourceTypes` |
| [x] | `GetTableSASURL`, table permissions and key ranges | `sas.TableSignatureValues`, `TablePermissions` |
| [x] | SAS protocol, IP range, query parsing/encoding, time formatting | `sas.Protocol`, `IPRange`, and `QueryParameters` |
| [x] | `Entity`, `EDMEntity`, binary, DateTime, GUID, and Int64 | typed `EntityCodec(T)`, `DynamicEntity`, `EdmValue`, and `edm` wrappers |
| [x] | metadata format and operation option structs | `options` operation-specific types and `MetadataFormat` |
| [x] | operation response structs, ETags, raw entity/table values | generic types in `responses` with status, ETag, selected headers, and owned decoded values |
| [x] | CORS, logging, metrics, retention, table properties | `service_models` |
| [x] | signed identifiers and access policies | `service_models.SignedIdentifier` / `AccessPolicy` |
| [x] | geo-replication status and last-sync time | `service_models.GeoReplication` |
| [x] | `TableErrorCode` and HTTP response errors | `errors.TableError`, known code constants, and unknown-code preservation |
| [x] | paged table/entity responses | `TablePager`, `EntityPager(T)`, `ListTablesPage`, and `ListEntitiesPage(T)` |
| [x] | transactional action and per-operation responses | `TransactionBuilder`, action types, and indexed transaction results |

Typed Zig entities add compile-time schema checking while `DynamicEntity`
retains the runtime-schema escape hatch. `$batch` is absent from the canonical
TypeSpec, so transactions remain hand-written unless upstream adds it.

### Entity codecs

`EntityCodec(T)` validates entity shapes when it is instantiated. `T` needs
string `partition_key` and `row_key` fields; an optional `timestamp` is the
service `Timestamp`. Supported property types are `bool`, `i32`, `f64`,
strings, optionals, and the `EdmBinary`, `EdmDateTime`, `EdmGuid`, and
`EdmInt64` wrappers. Declare `pub const table = .{ .rename = .{ ... } };` to
rename application properties on the wire. `Codec.toJson` returns an
allocator-owned byte slice; values returned by `Codec.deserialize` own decoded
strings and binary data and must be released with `Codec.deinit`.

For runtime schemas, `DynamicEntity.init` and `put` copy keys and values.
Release it with `DynamicEntity.deinit`; use `dynamicToJson` and
`dynamicFromJson` for its OData JSON representation. The original
string-only `TableEntity` remains available as a compatibility export and
continues to borrow its keys and values.

## Public API conventions

- Public types and generic type families use `PascalCase`; functions, methods,
  and fields use `lowerCamelCase`. Operation settings end in `Options`.
- Authentication constructors are explicit: `initWithToken`,
  `initWithSharedKey`, `initWithSasUrl`, and `initFromConnectionString`.
  Invalid credential combinations must not be representable.
- Each network operation has a simple `operation` method and an
  `operationResult` variant. Zig error unions report local failures such as
  allocation, validation, transport, or decoding. The result variant preserves
  Azure HTTP failures as a typed branch containing status, service code,
  message, request ID, and selected headers. The simple method maps that branch
  to its documented service error.
- Any public operation that allocates accepts an allocator. An allocating
  response owns one arena and has one `deinit`; all decoded strings and binary
  values belong to it and remain valid until `deinit`.
- An owning client holds heap-allocated `PipelineState` at a stable address and
  releases it in `deinit`. A client created by
  `TableServiceClient.getTableClient` borrows that state and must not outlive
  the service client. Moving either client value does not move policy objects.
- Pager state owns a resettable arena. Page values remain valid until the next
  successful page request or pager `deinit`. Continuation inputs are copied
  when needed and never borrowed from a released page.
- Caller entity values passed for serialization are borrowed only for the
  duration of the call. `DynamicEntity` owns copied keys and values and has
  `deinit`.
- The compatibility `TableEntity` is the exception retained from `0.1.0`: its
  map bookkeeping is owned, but partition key, row key, property keys, and
  property values are borrowed. Call `deinit` to release the map.

## Table lifecycle

`TableServiceClient.createTable` and `deleteTable` operate on a supplied
validated name; `TableClient` provides the same methods for its bound name.
Their `*Result` variants retain non-2xx service failures as `TableError`.
`listTables` returns a `TablePager`; configure `$filter`, `$select`, `$top`,
metadata format, and an initial continuation through `ListTablesOptions`.
Each page exposes the generated table wire response plus status and raw
headers. Page values are borrowed from the pager until its next successful
request or `deinit`. A pager owns an immutable protocol configuration copy,
but borrows the service client's heap-stable pipeline state; deinitialize it
before its parent service client. `ListTablesOptions` strings and policy
pointer-list storage are copied at pager creation, but the policy objects
themselves are borrowed and must remain stable and outlive the pager.

The pipeline policy order is request ID, telemetry, retry, then authentication.
Putting authentication after retry ensures date-sensitive SharedKeyLite
requests are signed on every attempt.

## Module ownership

| Module | Responsibility |
|---|---|
| `root.zig` | Public exports, compatibility aliases, and compile coverage |
| `client.zig`, `service_client.zig` | Table- and account-scoped clients |
| `pipeline.zig`, `auth.zig`, `request.zig` | Stable policy state, authentication, and shared request plumbing |
| `connection_string.zig`, `sas.zig` | Connection strings and SAS |
| `entity.zig`, `entity_codec.zig`, `edm.zig` | Entity models, typed codec, and EDM values |
| `options.zig`, `responses.zig`, `errors.zig` | Operation contracts and structured results |
| `pager.zig`, `transaction.zig` | Continuation paging and multipart transactions |
| `service_models.zig` | ACL, metrics, logging, CORS, and geo-replication |

## Development

```bash
git ls-files -z -- '*.zig' 'build.zig.zon' | xargs -0 zig fmt --check
zig build test --summary all
```

## Errors and results

`*Result` APIs return `TableResult(T)`: local failures remain Zig errors while
HTTP failures retain a `TableError` with status, service code, message, request
ID, and optional batch operation index. Call `deinit` on a result that is not
consumed by a simple-method adapter. `TableError` formatting redacts
Authorization values and complete URL query strings, including SAS.
