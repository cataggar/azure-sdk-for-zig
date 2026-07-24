# Kusto Ingest examples

Configure the target cluster, database, table, and named JSON mapping:

```bash
export KUSTO_CLUSTER_URL='https://<cluster>.<region>.kusto.windows.net'
export KUSTO_DATABASE='<database>'
export KUSTO_TARGET_TABLE='<table>'
export KUSTO_TARGET_MAPPING='<json-ingestion-mapping>'
```

Run ingestion and status scenarios from `example/kusto`:

```bash
zig build run-example -- ingest streaming
zig build run-example -- ingest queued
zig build run-example -- ingest managed
zig build run-example -- ingest status
zig build run-example -- ingest all
```

`KUSTO_INGEST_DATA` overrides the default NDJSON payload.
`KUSTO_STATUS_TIMEOUT_MS` changes the two-minute polling budget. The managed
example uses a queued-only extent tag for deterministic routing.

`zig build live-test` runs the same functions serially and skips successfully
when the environment is not configured.
