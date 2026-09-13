//! Azure Data Explorer (Kusto) clients.

pub const common = @import("kusto_common_internal");
pub const data = @import("kusto_data_internal");
pub const ingest = @import("kusto_ingest_internal");
pub const version = common.version;
pub const user_agent_prefix = common.user_agent_prefix;

test "facade exposes Kusto namespaces" {
    _ = common.KustoConnection;
    _ = data.KustoClient;
    _ = ingest.ManagedIngestClient;
}
