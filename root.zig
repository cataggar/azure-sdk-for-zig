pub const auth = @import("auth.zig");
pub const client = @import("client.zig");
pub const connection_string = @import("connection_string.zig");
pub const edm = @import("edm.zig");
pub const entity = @import("entity.zig");
pub const entity_codec = @import("entity_codec.zig");
pub const errors = @import("errors.zig");
pub const options = @import("options.zig");
pub const pager = @import("pager.zig");
pub const pipeline = @import("pipeline.zig");
pub const request = @import("request.zig");
pub const responses = @import("responses.zig");
pub const sas = @import("sas.zig");
pub const service_client = @import("service_client.zig");
pub const service_models = @import("service_models.zig");
pub const transaction = @import("transaction.zig");

/// Generated Azure Tables wire declarations will be re-exported here after
/// `azure_rest_data_tables` is generated and pinned.
pub const protocol = struct {};

// Compatibility exports for the original 0.1.0 package surface.
pub const TableEntity = entity.TableEntity;
pub const TableClient = client.TableClient;
pub const TableServiceClient = service_client.TableServiceClient;

test {
    _ = auth;
    _ = client;
    _ = connection_string;
    _ = edm;
    _ = entity;
    _ = entity_codec;
    _ = errors;
    _ = options;
    _ = pager;
    _ = pipeline;
    _ = request;
    _ = responses;
    _ = sas;
    _ = service_client;
    _ = service_models;
    _ = transaction;
    _ = protocol;
    _ = TableEntity;
    _ = TableClient;
    _ = TableServiceClient;
}
