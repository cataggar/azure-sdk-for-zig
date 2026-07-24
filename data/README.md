# Kusto Data namespace

Kusto query and management APIs, progressive result streaming, typed KQL
parameters, and typed result rows.

Import it from the consolidated package:

```zig
const data = @import("azure_sdk_kusto").data;
```

## Request properties and timeouts

`ClientRequestProperties` emits object-valued `Options` and `Parameters`
through structured serde values. Dynamic setters own their keys and values;
borrowed header strings must outlive the request.

- Typed helpers cover timeout, truncation, progressive results, cache,
  consistency, resources, and security.
- Unknown options preserve JSON types; raw JSON fragments are not accepted.
- Query parameters must be strings or Kusto `long` values. Encode other
  scalars as KQL literal strings such as `datetime(...)` or `dynamic(...)`.
- Query server timeout defaults to four minutes; management defaults to ten
  minutes. Explicit timeouts range from one second through one hour.
- Client budgets default to server timeout plus 30 seconds.
- Buffered timeouts bound retries/backoff but cannot interrupt a blocking HTTP
  call.

Explicit application, user, version, and request-ID headers override defaults.
Results expose owned client request and activity IDs.

## Buffered results

Rows must match declared column width by default. The varying-width option
preserves missing cells as absent and extra cells as unknown raw JSON.

V2 decoding requires `DataSetHeader` first and `DataSetCompletion` last. It
reconstructs progressive/fragmented `DataAppend` and `DataReplace` frames by
table ID, retains unknown frames, and exposes table/row iterators plus table
metadata and completion status.

`*Result` APIs return `KustoResult(T)`:

- `.ok`
- `.partial`, with decoded data plus an owned `KustoError`
- `.err`

Call `deinit`. Permanent and partial failures are never retryable.

## Progressive query

`executeProgressiveQuery` forces V2 progressive result options and reads one
complete object from the top-level JSON array at a time. It enforces
`max_frame_bytes` and `max_table_count`.

Frame, table, and row adapters are exclusive. The row adapter emits a reset
before each replacement batch and preserves completion events so partial
failures and cancellation remain visible. Adapter payloads are borrowed until
the next call.

```zig
var opened = try client.executeProgressiveQuery(
    allocator,
    "db",
    "StormEvents | take 100",
    null,
    .{ .max_frame_bytes = 1024 * 1024, .deadline_ms = 30_000 },
);
const stream = switch (opened) {
    .ok => |value| value,
    .err => |*failure| {
        defer failure.deinit();
        return error.KustoQueryFailed;
    },
    .partial => unreachable,
};
defer stream.deinit();

while (try stream.next()) |frame| {
    var owned = frame;
    defer owned.deinit(allocator);
    // Process the explicit frame payload.
}
try stream.finish();
```

Call `finish` to drain and validate the full response. Calling `deinit`
without `finish` aborts. `cancel` first cancels locally, then sends a
non-retryable `.cancel query` management command for the original request ID.

## Typed KQL

`kql.QueryParameters` declares parameter types once. Its generated `Name` enum
is the only runtime parameter name accepted by `kql.Builder.parameter`.
Bindings copy values into `ClientRequestProperties.Parameters`; values are
never interpolated into KQL.

```zig
const data = @import("azure_sdk_kusto").data;
const Params = struct { account: []const u8, minimum: i64 };
const Binding = data.kql.QueryParameters(Params);

var properties = try Binding.bind(
    allocator,
    .{ .account = user_input, .minimum = 10 },
);
defer properties.deinit(allocator);

var query = try data.kql.Builder(Binding).init(allocator);
defer query.deinit();
try query.literal("StormEvents | where ");
try query.identifier("Account");
try query.literal(" == ");
try query.parameter(.account);
```

`literal` is comptime-trusted KQL. Runtime identifiers and strings are
validated and escaped. `unsafeRaw` is the explicit unescaped runtime path.
Typed helpers cover datetime, timespan, decimal, GUID, and dynamic values.

## Typed rows

Typed decoders scan a table schema once and allocate values independently of
the dataset. Call `deinitRow` for every successful row.

```zig
const Row = struct { Account: []u8, Count: i64 };
const table = dataset.primaryTable().?;
const Decoder = data.KustoRowDecoder(Row);
const decoder = try table.rowDecoder(Row);
var row = try decoder.rowAs(&table.rows[0], allocator);
defer Decoder.deinitRow(&row, allocator);
```

## Examples and development

See the
[Data examples](https://github.com/cataggar/azure-sdk-for-zig/tree/example/kusto/data)
for query, management, and progressive-query scenarios.

```bash
zig build test --summary all
```
