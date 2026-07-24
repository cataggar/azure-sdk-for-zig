//! Azure Data Explorer (Kusto) clients.

pub const common = @import("kusto_common_internal");
pub const data = @import("kusto_data_internal");
pub const ingest = @import("kusto_ingest_internal");

test "facade exposes Kusto namespaces" {
    _ = common.KustoConnection;
    _ = data.KustoClient;
    _ = ingest.ManagedIngestClient;
}
