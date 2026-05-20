///! Cloud environment configuration for Azure sovereign clouds.
///!
///! Azure operates in multiple cloud environments (public, government, China,
///! etc.), each with different endpoint suffixes and authority hosts. This
///! module provides well-known configurations and a struct for custom clouds.
const std = @import("std");

/// Configuration for an Azure cloud environment.
pub const Cloud = struct {
    /// Display name for this cloud (e.g., "Azure Public").
    name: []const u8,
    /// Azure Active Directory / Entra ID authority host
    /// (e.g., "https://login.microsoftonline.com").
    authority_host: []const u8,
    /// Suffix for Azure Resource Manager endpoints.
    resource_manager_endpoint: []const u8,
    /// Suffix for Azure Storage endpoints.
    storage_endpoint_suffix: []const u8,
    /// Suffix for Azure Key Vault endpoints.
    keyvault_endpoint_suffix: []const u8,
    /// Default scope for Azure Resource Manager tokens.
    default_scope: []const u8,
};

/// Azure Public Cloud (global, default).
pub const azure_public = Cloud{
    .name = "Azure Public",
    .authority_host = "https://login.microsoftonline.com",
    .resource_manager_endpoint = "https://management.azure.com",
    .storage_endpoint_suffix = "core.windows.net",
    .keyvault_endpoint_suffix = "vault.azure.net",
    .default_scope = "https://management.azure.com/.default",
};

/// Azure US Government Cloud.
pub const azure_government = Cloud{
    .name = "Azure Government",
    .authority_host = "https://login.microsoftonline.us",
    .resource_manager_endpoint = "https://management.usgovcloudapi.net",
    .storage_endpoint_suffix = "core.usgovcloudapi.net",
    .keyvault_endpoint_suffix = "vault.usgovcloudapi.net",
    .default_scope = "https://management.usgovcloudapi.net/.default",
};

/// Azure China Cloud (operated by 21Vianet).
pub const azure_china = Cloud{
    .name = "Azure China",
    .authority_host = "https://login.chinacloudapi.cn",
    .resource_manager_endpoint = "https://management.chinacloudapi.cn",
    .storage_endpoint_suffix = "core.chinacloudapi.cn",
    .keyvault_endpoint_suffix = "vault.azure.cn",
    .default_scope = "https://management.chinacloudapi.cn/.default",
};

// ─────────────────────── Tests ───────────────────────

test "public cloud defaults" {
    try std.testing.expectEqualStrings("https://login.microsoftonline.com", azure_public.authority_host);
    try std.testing.expectEqualStrings("vault.azure.net", azure_public.keyvault_endpoint_suffix);
    try std.testing.expectEqualStrings("core.windows.net", azure_public.storage_endpoint_suffix);
}

test "government cloud" {
    try std.testing.expectEqualStrings("https://login.microsoftonline.us", azure_government.authority_host);
    try std.testing.expectEqualStrings("vault.usgovcloudapi.net", azure_government.keyvault_endpoint_suffix);
}

test "china cloud" {
    try std.testing.expectEqualStrings("https://login.chinacloudapi.cn", azure_china.authority_host);
    try std.testing.expectEqualStrings("vault.azure.cn", azure_china.keyvault_endpoint_suffix);
}

test "custom cloud" {
    const custom = Cloud{
        .name = "My Private Cloud",
        .authority_host = "https://login.private.example.com",
        .resource_manager_endpoint = "https://management.private.example.com",
        .storage_endpoint_suffix = "storage.private.example.com",
        .keyvault_endpoint_suffix = "vault.private.example.com",
        .default_scope = "https://management.private.example.com/.default",
    };
    try std.testing.expectEqualStrings("My Private Cloud", custom.name);
    try std.testing.expectEqualStrings("vault.private.example.com", custom.keyvault_endpoint_suffix);
}
