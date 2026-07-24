# Kusto Data examples

Configure the target cluster and database:

```bash
export KUSTO_CLUSTER_URL='https://<cluster>.<region>.kusto.windows.net'
export KUSTO_DATABASE='<database>'
```

Run query, management, and progressive scenarios from `example/kusto`:

```bash
zig build run-example -- data default-query
zig build run-example -- data typed-query
zig build run-example -- data management
zig build run-example -- data progressive
zig build run-example -- data all
```

`zig build live-test` runs the same functions serially and skips successfully
when the environment is not configured.
