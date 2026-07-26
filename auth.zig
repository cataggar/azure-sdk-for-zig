//! Azure Storage Tables authentication selection and SharedKeyLite signing.
//!
//! This module is intentionally scoped to Storage Tables. Cosmos audiences and
//! request transforms belong to a separate Cosmos SDK.

/// Microsoft Entra scope for Azure Storage data-plane requests.
pub const storage_scope = "https://storage.azure.com/.default";
