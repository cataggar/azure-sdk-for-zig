//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// Describes upstreaming behavior for a given feed/protocol/package
pub const UpstreamingBehavior = struct {
    /// Indicates whether external upstream versions should be considered for this package
    versions_from_external_upstreams: ?enums.UpstreamingBehaviorVersionsFromExternalUpstreams = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Package version metadata for a Cargo package To be returned by our web APIs
pub const Package = struct {
    links: ?ReferenceLinks = null,
    /// If and when the package was deleted.
    deleted_date: ?[]const u8 = null,
    /// Package Id.
    id: ?[]const u8 = null,
    /// The display name of the package.
    name: ?[]const u8 = null,
    /// If and when the package was permanently deleted.
    permanently_deleted_date: ?[]const u8 = null,
    /// The history of upstream sources for this package. The first source in the list is the immediate source from which this package was saved.
    source_chain: ?[]const UpstreamSourceInfo = null,
    /// The version of the package.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The class to represent a collection of REST reference links.
pub const ReferenceLinks = struct {
    /// The readonly view of the links. Because Reference links are readonly, we only want to expose them as read only.
    links: ?std.json.ArrayHashMap(ReferenceLinksLink) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReferenceLinksLink = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Upstream source definition, including its Identity, package type, and other associated information.
pub const UpstreamSourceInfo = struct {
    /// Locator for connecting to the upstream source in a user friendly format, that may potentially change over time
    display_location: ?[]const u8 = null,
    /// Identity of the upstream source.
    id: ?[]const u8 = null,
    /// Locator for connecting to the upstream source
    location: ?[]const u8 = null,
    /// Display name.
    name: ?[]const u8 = null,
    /// Source type, such as Public or Internal.
    source_type: ?enums.UpstreamSourceInfoSourceType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PackageVersionDetails = struct {
    views: ?JsonPatchOperation = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The JSON model for a JSON Patch operation
pub const JsonPatchOperation = struct {
    /// The path to copy from for the Move/Copy operation.
    from: ?[]const u8 = null,
    /// The patch operation
    op: ?enums.JsonPatchOperationOp = null,
    /// The path for the operation. In the case of an array, a zero based index can be used to specify the position in the array (e.g. /biscuits/0/name). The '-' character can be used instead of an index to insert at the end of the array (e.g. /biscuits/-).
    path: ?[]const u8 = null,
    /// The value for the operation. This is either a primitive or a JToken.
    value: ?JsonPatchOperationValue = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const JsonPatchOperationValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deletion state of a Cargo package.
pub const CargoPackageVersionDeletionState = struct {
    /// UTC date the package was deleted.
    deleted_date: ?[]const u8 = null,
    /// Name of the package.
    name: ?[]const u8 = null,
    /// Version of the package.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CargoRecycleBinPackageVersionDetails = struct {
    deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A batch of operations to apply to package versions.
pub const CargoPackagesBatchRequest = struct {
    data: ?BatchOperationData = null,
    /// Type of operation that needs to be performed on packages.
    operation: ?enums.CargoPackagesBatchRequestOperation = null,
    /// The packages onto which the operation will be performed.
    packages: ?[]const MinimalPackageDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Do not attempt to use this type to create a new BatchOperationData. This type does not contain sufficient fields to create a new batch operation data.
pub const BatchOperationData = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Minimal package details required to identify a package within a protocol.
pub const MinimalPackageDetails = struct {
    /// Package name.
    id: ?[]const u8 = null,
    /// Package version.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deletion state of a maven package.
pub const MavenPackageVersionDeletionState = struct {
    /// Artifact Id of the package.
    artifact_id: ?[]const u8 = null,
    /// UTC date the package was deleted.
    deleted_date: ?[]const u8 = null,
    /// Group Id of the package.
    group_id: ?[]const u8 = null,
    /// Version of the package.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const MavenRecycleBinPackageVersionDetails = struct {
    /// Setting to false will undo earlier deletion and restore the package to feed.
    deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A batch of operations to apply to package versions.
pub const MavenPackagesBatchRequest = struct {
    data: ?BatchOperationData = null,
    /// Type of operation that needs to be performed on packages.
    operation: ?enums.MavenPackagesBatchRequestOperation = null,
    /// The packages onto which the operation will be performed.
    packages: ?[]const MavenMinimalPackageDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Identifies a particular Maven package version
pub const MavenMinimalPackageDetails = struct {
    /// Package artifact ID
    artifact: ?[]const u8 = null,
    /// Package group ID
    group: ?[]const u8 = null,
    /// Package version
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ValidateCustomPublicUpstreamSourceRequest = struct {
    package_name: ?[]const u8 = null,
    upstream_location: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ValidateCustomPublicUpstreamSourceResponse = struct {
    message: ?[]const u8 = null,
    validated_successfully: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A batch of operations to apply to package versions.
pub const NpmPackagesBatchRequest = struct {
    data: ?BatchOperationData = null,
    /// Type of operation that needs to be performed on packages.
    operation: ?enums.NpmPackagesBatchRequestOperation = null,
    /// The packages onto which the operation will be performed.
    packages: ?[]const MinimalPackageDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deletion state of an npm package.
pub const NpmPackageVersionDeletionState = struct {
    /// Name of the package.
    name: ?[]const u8 = null,
    /// UTC date the package was unpublished.
    unpublished_date: ?[]const u8 = null,
    /// Version of the package.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const NpmRecycleBinPackageVersionDetails = struct {
    /// Setting to false will undo earlier deletion and restore the package to feed.
    deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A batch of operations to apply to package versions.
pub const NuGetPackagesBatchRequest = struct {
    data: ?BatchOperationData = null,
    /// Type of operation that needs to be performed on packages.
    operation: ?enums.NuGetPackagesBatchRequestOperation = null,
    /// The packages onto which the operation will be performed.
    packages: ?[]const MinimalPackageDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deletion state of a NuGet package.
pub const NuGetPackageVersionDeletionState = struct {
    /// Utc date the package was deleted.
    deleted_date: ?[]const u8 = null,
    /// Name of the package.
    name: ?[]const u8 = null,
    /// Version of the package.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const NuGetRecycleBinPackageVersionDetails = struct {
    /// Setting to false will undo earlier deletion and restore the package to feed.
    deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A batch of operations to apply to package versions.
pub const PyPiPackagesBatchRequest = struct {
    data: ?BatchOperationData = null,
    /// Type of operation that needs to be performed on packages.
    operation: ?enums.PyPiPackagesBatchRequestOperation = null,
    /// The packages onto which the operation will be performed.
    packages: ?[]const MinimalPackageDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deletion state of a Python package.
pub const PyPiPackageVersionDeletionState = struct {
    /// UTC date the package was deleted.
    deleted_date: ?[]const u8 = null,
    /// Name of the package.
    name: ?[]const u8 = null,
    /// Version of the package.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PyPiRecycleBinPackageVersionDetails = struct {
    /// Setting to false will undo earlier deletion and restore the package to feed.
    deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A batch of operations to apply to package versions.
pub const UPackPackagesBatchRequest = struct {
    data: ?BatchOperationData = null,
    /// Type of operation that needs to be performed on packages.
    operation: ?enums.UPackPackagesBatchRequestOperation = null,
    /// The packages onto which the operation will be performed.
    packages: ?[]const MinimalPackageDetails = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Deletion state of a Universal package.
pub const UPackPackageVersionDeletionState = struct {
    /// UTC date the package was deleted.
    deleted_date: ?[]const u8 = null,
    /// Name of the package.
    name: ?[]const u8 = null,
    /// Version of the package.
    version: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UPackRecycleBinPackageVersionDetails = struct {
    /// Setting to false will undo earlier deletion and restore the package to feed.
    deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
