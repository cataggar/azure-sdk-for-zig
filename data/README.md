# Kusto Data examples

Configure the target cluster and database:

```bash
export KUSTO_CLUSTER_URL='https://<cluster>.<region>.kusto.windows.net'
export KUSTO_DATABASE='<database>'
```

Run query, management, and progressive scenarios from `sdk/kusto/data`:

```bash
zig build run-example -- default-query
zig build run-example -- typed-query
zig build run-example -- management
zig build run-example -- progressive
zig build run-example -- all
```

`zig build live-test` runs the same functions serially and skips successfully
when the environment is not configured.
