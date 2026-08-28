//! container-registry — generated from TypeSpec.
//!
//! Do not edit by hand. Regenerate with `codegen`.

const clients = @import("clients.zig");
pub const models = @import("models.zig");
pub const enums = @import("enums.zig");
pub const ContainerRegistryClient = clients.ContainerRegistryClient;
pub const ContainerRegistry = clients.ContainerRegistry;
pub const ContainerRegistryBlob = clients.ContainerRegistryBlob;
pub const Authentication = clients.Authentication;

test {
    _ = @import("clients_test.zig");
}
