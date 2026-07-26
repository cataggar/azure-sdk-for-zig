const core = @import("azure_sdk_core");
const client = @import("client.zig");

/// Client for Azure Table Service operations (list/create/delete tables).
///
/// The compatibility constructor borrows its endpoint, credential, and
/// transport. A table client returned by `getTableClient` borrows the same
/// values, so they must outlive both clients.
pub const TableServiceClient = struct {
    endpoint: []const u8,
    credential: *core.credentials.TokenCredential,
    transport: *core.http.HttpTransport,

    pub fn init(
        endpoint: []const u8,
        credential: *core.credentials.TokenCredential,
        transport: *core.http.HttpTransport,
    ) TableServiceClient {
        return .{
            .endpoint = endpoint,
            .credential = credential,
            .transport = transport,
        };
    }

    pub fn getTableClient(self: *TableServiceClient, table_name: []const u8) client.TableClient {
        return client.TableClient.init(self.endpoint, table_name, self.credential, self.transport, .{});
    }
};
