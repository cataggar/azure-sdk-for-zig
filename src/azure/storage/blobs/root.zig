///! Azure Blob Storage client module (stub — Phase 3b).

const core = @import("azure_core");
const identity = @import("azure_identity");

// Will be populated in Phase 3b:
// pub const BlobServiceClient = @import("blob_service_client.zig").BlobServiceClient;
// pub const BlobContainerClient = @import("blob_container_client.zig").BlobContainerClient;
// pub const BlobClient = @import("blob_client.zig").BlobClient;

test {
    @import("std").testing.refAllDecls(@This());
}
