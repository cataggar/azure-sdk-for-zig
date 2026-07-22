# Kusto examples and live tests

`examples/kusto/main.zig` covers default-credential query, typed parameters,
management, progressive results, direct streaming ingestion, queued
submission, managed routing, and status polling.

## Query examples

```bash
export KUSTO_CLUSTER_URL='https://<cluster>.<region>.kusto.windows.net'
export KUSTO_DATABASE='<database>'

zig build run-kusto-examples -- default-query
zig build run-kusto-examples -- typed-query
zig build run-kusto-examples -- management
zig build run-kusto-examples -- progressive
```

## Ingestion examples

Ingestion also requires a target table and named mapping. The default NDJSON
payload contains one `Message` string field; override it with
`KUSTO_INGEST_DATA` when the mapping expects another shape.

```bash
export KUSTO_TARGET_TABLE='<table>'
export KUSTO_TARGET_MAPPING='<json-ingestion-mapping>'

zig build run-kusto-examples -- streaming
zig build run-kusto-examples -- queued
zig build run-kusto-examples -- managed
zig build run-kusto-examples -- status
zig build run-kusto-examples -- all
```

`KUSTO_STATUS_TIMEOUT_MS` optionally changes the two-minute polling budget.
The managed example deterministically selects Queue using a queued-only extent
tag. The exact live direct-fallback branch remains covered by mock protocol
tests because safely forcing a real service retryable rejection is not
practical.

## Live tests

```bash
zig build kusto-live-test
```

The live test runs the same functions serially and returns successful Zig
skips when query or ingestion configuration is absent. It is not part of
deterministic `zig build test`.

`DefaultAzureCredential` requires one usable environment, workload identity,
managed identity, or Azure CLI source. Examples print counts and enum outcomes
only. They do not print credentials, authorization headers, ingestion
payloads, service-issued SAS URIs, or raw error bodies.
