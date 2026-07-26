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

After the generated package is published, this SDK will pin it by immutable Git
commit and Zig package hash and re-export its public root as `protocol`.
`protocol` is reserved now so application imports do not change. Generated
declarations must not absorb SDK policy, convenience, or ownership behavior.

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
| [x] | `GetEntity` | generic `TableClient.getEntity` / `getEntityResult` |
| [x] | `DeleteEntity` with `IfMatch` | `TableClient.deleteEntity` / `deleteEntityResult` |
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
