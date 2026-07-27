const std = @import("std");

const sas = @import("sas.zig");

// ─────────────────────────── SAS client ───────────────────────
// Hand-written Shared Access Signature (SAS) upload client. This is not part
// of the generated TypeSpec surface; it is preserved as a first-class feature.
pub const SasBlobClient = sas.SasBlobClient;
pub const CompleteSasBlobClient = sas.CompleteSasBlobClient;
pub const BlobUploadSource = sas.BlobUploadSource;
pub const BlobUploadSourceKind = sas.BlobUploadSourceKind;
pub const BorrowedReaderSource = sas.BorrowedReaderSource;
pub const BlobUploadOptions = sas.BlobUploadOptions;
pub const BlobUploadOutcome = sas.BlobUploadOutcome;
pub const BlobUploadPhase = sas.BlobUploadPhase;
pub const default_single_upload_max_bytes = sas.default_single_upload_max_bytes;
pub const max_single_upload_bytes = sas.max_single_upload_bytes;
pub const default_block_size = sas.default_block_size;
pub const max_block_size = sas.max_block_size;
pub const max_block_count = sas.max_block_count;
pub const max_upload_bytes = sas.max_upload_bytes;

// ─────────────────────── Generated client ─────────────────────
// Generated from the Microsoft.BlobStorage TypeSpec. `BlobClient` is the entry
// point; obtain operation sub-clients through `.service()`, `.container()`,
// `.blob()`, `.appendBlob()`, `.blockBlob()`, and `.pageBlob()`.
const clients = @import("src/clients.zig");

pub const models = @import("src/models.zig");
pub const enums = @import("src/enums.zig");

pub const BlobClient = clients.BlobClient;
pub const Service = clients.Service;
pub const Container = clients.Container;
pub const Blob = clients.Blob;
pub const AppendBlob = clients.AppendBlob;
pub const BlockBlob = clients.BlockBlob;
pub const PageBlob = clients.PageBlob;

// ─────────────────────── Convenience helpers ──────────────────
// Hand-written high-level helpers layered on the generated clients (existence
// checks, auto-chunking block-blob upload, and a download-to-writer sink).
// Kept in a separate module because `src/clients.zig` is emitter-owned.
pub const convenience = @import("convenience.zig");
pub const blobExists = convenience.blobExists;
pub const containerExists = convenience.containerExists;
pub const uploadBlockBlob = convenience.uploadBlockBlob;
pub const downloadInto = convenience.downloadInto;
pub const download = convenience.download;
pub const DownloadResult = convenience.DownloadResult;
pub const DownloadOptions = convenience.DownloadOptions;

// ────────────────── Container and blob convenience ────────────
// Hand-written container-scoped clients. The generated client models Azure
// blob metadata as a single `x-ms-meta` header, which is not the wire format;
// these clients emit one `x-ms-meta-{name}` header per entry and read them
// back, which is what the Event Hubs checkpoint store needs.
pub const container_client = @import("container_client.zig");
pub const BlobContainerClient = container_client.BlobContainerClient;
pub const auth_scopes = container_client.auth_scopes;
pub const ListBlobsOptions = container_client.ListBlobsOptions;
pub const ContainerBlobClient = container_client.BlobClient;
pub const BlobProperties = container_client.BlobProperties;
pub const BlobItem = container_client.BlobItem;
pub const freeBlobItems = container_client.freeBlobItems;
pub const Metadata = container_client.Metadata;
pub const MetadataEntry = container_client.MetadataEntry;
pub const isValidMetadataName = container_client.isValidMetadataName;
pub const metadata_header_prefix = container_client.metadata_header_prefix;
pub const UploadBlobOptions = container_client.UploadBlobOptions;
pub const UploadBlobResult = container_client.UploadBlobResult;
pub const SetMetadataOptions = container_client.SetMetadataOptions;
pub const SetMetadataResult = container_client.SetMetadataResult;
pub const DownloadBlobResult = container_client.DownloadBlobResult;

test {
    std.testing.refAllDecls(sas);
    _ = @import("convenience.zig");
    _ = @import("container_client.zig");
    inline for (.{
        clients.BlobClient,
        clients.Service,
        clients.Container,
        clients.Blob,
        clients.AppendBlob,
        clients.BlockBlob,
        clients.PageBlob,
    }) |T| {
        std.testing.refAllDecls(T);
    }
    std.testing.refAllDecls(models);
    std.testing.refAllDecls(enums);
    _ = @import("src/clients_test.zig");
}
