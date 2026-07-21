//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const JsonValue = union(enum) {
    null_value: void,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    array: []JsonValue,
    object: std.StringArrayHashMapUnmanaged(JsonValue),

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        const saved = deserializer.*;
        if (deserializer.deserializeVoid()) |_| {
            return .{ .null_value = {} };
        } else |_| deserializer.* = saved;
        if (deserializer.deserializeBool()) |value| {
            return .{ .boolean = value };
        } else |_| deserializer.* = saved;
        if (deserializer.deserializeInt(i64)) |value| {
            return .{ .integer = value };
        } else |_| deserializer.* = saved;
        if (deserializer.deserializeFloat(f64)) |value| {
            return .{ .float = value };
        } else |_| deserializer.* = saved;
        if (deserializer.deserializeString(allocator)) |value| {
            return .{ .string = value };
        } else |_| deserializer.* = saved;

        if (deserializer.deserializeSeqAccess()) |sequence_value| {
            var sequence = sequence_value;
            var values: std.ArrayList(JsonValue) = .empty;
            errdefer values.deinit(allocator);
            while (try sequence.nextElement(JsonValue, allocator)) |value| {
                values.append(allocator, value) catch
                    return deserializer.raiseError(error.OutOfMemory);
            }
            return .{ .array = values.toOwnedSlice(allocator) catch
                return deserializer.raiseError(error.OutOfMemory) };
        } else |_| deserializer.* = saved;

        var map = deserializer.deserializeStruct(T) catch
            return deserializer.raiseError(error.UnexpectedToken);
        var values: std.StringArrayHashMapUnmanaged(JsonValue) = .empty;
        errdefer values.deinit(allocator);
        while (try map.nextKey(allocator)) |key| {
            const owned_key = allocator.dupe(u8, key) catch
                return deserializer.raiseError(error.OutOfMemory);
            const value = map.nextValue(JsonValue, allocator) catch |err| {
                allocator.free(owned_key);
                return err;
            };
            values.put(allocator, owned_key, value) catch {
                allocator.free(owned_key);
                return deserializer.raiseError(error.OutOfMemory);
            };
        }
        return .{ .object = values };
    }

    pub fn zerdeSerialize(self: JsonValue, serializer: anytype) @TypeOf(serializer.*).Error!void {
        switch (self) {
            .null_value => return serializer.serializeNull(),
            .boolean => |value| return serializer.serializeBool(value),
            .integer => |value| return serializer.serializeInt(value),
            .float => |value| return serializer.serializeFloat(value),
            .string => |value| return serializer.serializeString(value),
            .array => |values| {
                var array = try serializer.beginArray();
                for (values) |value| try value.zerdeSerialize(&array);
                return array.end();
            },
            .object => |values| {
                var object = try serializer.beginStruct();
                var iterator = values.iterator();
                while (iterator.next()) |entry| {
                    try object.serializeEntry(entry.key_ptr.*, entry.value_ptr.*);
                }
                return object.end();
            },
        }
    }
};

/// Acr error response describing why the operation failed
pub const AcrErrors = struct {
    /// Array of detailed error
    errors: ?[]const AcrErrorInfo = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Error information
pub const AcrErrorInfo = struct {
    /// Error code
    code: ?[]const u8 = null,
    /// Error message
    message: ?[]const u8 = null,
    /// Error details
    detail: ?AcrErrorInfoDetail = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AcrErrorInfoDetail = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Returns the requested manifest file
pub const ManifestWrapper = struct {
    /// Schema version
    schema_version: ?i32 = null,
    /// Media type for this Manifest
    media_type: ?[]const u8 = null,
    /// (ManifestList, OCIIndex) List of V2 image layer information
    manifests: ?[]const ManifestListAttributes = null,
    /// (V2, OCI) Image config descriptor
    config: ?Descriptor = null,
    /// (V2, OCI) List of V2 image layer information
    layers: ?[]const Descriptor = null,
    /// (OCI, OCIIndex) Additional metadata
    annotations: ?Annotations = null,
    /// (V1) CPU architecture
    architecture: ?[]const u8 = null,
    /// (V1) Image name
    name: ?[]const u8 = null,
    /// (V1) Image tag
    tag: ?[]const u8 = null,
    /// (V1) List of layer information
    fs_layers: ?[]const FsLayer = null,
    /// (V1) Image history
    history: ?[]const History = null,
    /// (V1) Image signature
    signatures: ?[]const ImageSignature = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Attributes of a manifest in a manifest list.
pub const ManifestListAttributes = struct {
    /// The MIME type of the referenced object. This will generally be
    /// application/vnd.docker.image.manifest.v2+json, but it could also be
    /// application/vnd.docker.image.manifest.v1+json
    media_type: ?[]const u8 = null,
    /// The size in bytes of the object
    size: ?i64 = null,
    /// The digest of the content, as defined by the Registry V2 HTTP API Specification
    digest: ?[]const u8 = null,
    /// The platform object describes the platform which the image in the manifest runs
    /// on. A full list of valid operating system and architecture values are listed in
    /// the Go language documentation for $GOOS and $GOARCH
    platform: ?Platform = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The platform object describes the platform which the image in the manifest runs
/// on. A full list of valid operating system and architecture values are listed in
/// the Go language documentation for $GOOS and $GOARCH
pub const Platform = struct {
    /// Specifies the CPU architecture, for example amd64 or ppc64le.
    architecture: ?[]const u8 = null,
    /// The os field specifies the operating system, for example linux or windows.
    os: ?[]const u8 = null,
    /// The optional os.version field specifies the operating system version, for
    /// example 10.0.10586.
    os_version: ?[]const u8 = null,
    /// The optional os.features field specifies an array of strings, each listing a
    /// required OS feature (for example on Windows win32k
    os_features: ?[]const []const u8 = null,
    /// The optional variant field specifies a variant of the CPU, for example armv6l
    /// to specify a particular CPU variant of the ARM CPU.
    variant: ?[]const u8 = null,
    /// The optional features field specifies an array of strings, each listing a
    /// required CPU feature (for example sse4 or aes
    features: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .os_version = "os.version",
            .os_features = "os.features",
        },
    };
};

/// Docker V2 image layer descriptor including config and layers
pub const Descriptor = struct {
    /// Layer media type
    media_type: ?[]const u8 = null,
    /// Layer size
    size: ?i64 = null,
    /// Layer digest
    digest: ?[]const u8 = null,
    /// Specifies a list of URIs from which this object may be downloaded.
    urls: ?[]const []const u8 = null,
    /// Additional information provided through arbitrary metadata.
    annotations: ?Annotations = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Additional information provided through arbitrary metadata.
pub const Annotations = struct {
    /// Date and time on which the image was built (string, date-time as defined by
    /// https://tools.ietf.org/html/rfc3339#section-5.6)
    created: ?[]const u8 = null,
    /// Contact details of the people or organization responsible for the image.
    authors: ?[]const u8 = null,
    /// URL to find more information on the image.
    url: ?[]const u8 = null,
    /// URL to get documentation on the image.
    documentation: ?[]const u8 = null,
    /// URL to get source code for building the image.
    source: ?[]const u8 = null,
    /// Version of the packaged software. The version MAY match a label or tag in the
    /// source code repository, may also be Semantic versioning-compatible
    version: ?[]const u8 = null,
    /// Source control revision identifier for the packaged software.
    revision: ?[]const u8 = null,
    /// Name of the distributing entity, organization or individual.
    vendor: ?[]const u8 = null,
    /// License(s) under which contained software is distributed as an SPDX License
    /// Expression.
    licenses: ?[]const u8 = null,
    /// Name of the reference for a target.
    name: ?[]const u8 = null,
    /// Human-readable title of the image
    title: ?[]const u8 = null,
    /// Human-readable description of the software packaged in the image
    description: ?[]const u8 = null,
    additional_properties: std.StringArrayHashMapUnmanaged(JsonValue) = .empty,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .created = "org.opencontainers.image.created",
            .authors = "org.opencontainers.image.authors",
            .url = "org.opencontainers.image.url",
            .documentation = "org.opencontainers.image.documentation",
            .source = "org.opencontainers.image.source",
            .version = "org.opencontainers.image.version",
            .revision = "org.opencontainers.image.revision",
            .vendor = "org.opencontainers.image.vendor",
            .licenses = "org.opencontainers.image.licenses",
            .name = "org.opencontainers.image.ref.name",
            .title = "org.opencontainers.image.title",
            .description = "org.opencontainers.image.description",
        },
        .skip = .{ .additional_properties = .always },
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        var result: T = .{};
        var map = try deserializer.deserializeStruct(T);
        while (try map.nextKey(allocator)) |key| {
            if (std.mem.eql(u8, key, "org.opencontainers.image.created")) {
                result.created = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.authors")) {
                result.authors = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.url")) {
                result.url = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.documentation")) {
                result.documentation = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.source")) {
                result.source = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.version")) {
                result.version = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.revision")) {
                result.revision = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.vendor")) {
                result.vendor = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.licenses")) {
                result.licenses = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.ref.name")) {
                result.name = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.title")) {
                result.title = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            if (std.mem.eql(u8, key, "org.opencontainers.image.description")) {
                result.description = try map.nextValue(?[]const u8, allocator);
                continue;
            }
            const owned_key = allocator.dupe(u8, key) catch
                return deserializer.raiseError(error.OutOfMemory);
            const value = map.nextValue(JsonValue, allocator) catch |err| {
                allocator.free(owned_key);
                return err;
            };
            result.additional_properties.put(allocator, owned_key, value) catch {
                allocator.free(owned_key);
                return deserializer.raiseError(error.OutOfMemory);
            };
        }
        return result;
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) @TypeOf(serializer.*).Error!void {
        var object = try serializer.beginStruct();
        if (self.created) |value| try object.serializeField("org.opencontainers.image.created", value);
        if (self.authors) |value| try object.serializeField("org.opencontainers.image.authors", value);
        if (self.url) |value| try object.serializeField("org.opencontainers.image.url", value);
        if (self.documentation) |value| try object.serializeField("org.opencontainers.image.documentation", value);
        if (self.source) |value| try object.serializeField("org.opencontainers.image.source", value);
        if (self.version) |value| try object.serializeField("org.opencontainers.image.version", value);
        if (self.revision) |value| try object.serializeField("org.opencontainers.image.revision", value);
        if (self.vendor) |value| try object.serializeField("org.opencontainers.image.vendor", value);
        if (self.licenses) |value| try object.serializeField("org.opencontainers.image.licenses", value);
        if (self.name) |value| try object.serializeField("org.opencontainers.image.ref.name", value);
        if (self.title) |value| try object.serializeField("org.opencontainers.image.title", value);
        if (self.description) |value| try object.serializeField("org.opencontainers.image.description", value);
        var iterator = self.additional_properties.iterator();
        while (iterator.next()) |entry| {
            try object.serializeEntry(entry.key_ptr.*, entry.value_ptr.*);
        }
        return object.end();
    }
};

/// Image layer information
pub const FsLayer = struct {
    /// SHA of an image layer
    blob_sum: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A list of unstructured historical data for v1 compatibility
pub const History = struct {
    /// The raw v1 compatibility information
    v1_compatibility: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Signature of a signed manifest
pub const ImageSignature = struct {
    /// A JSON web signature
    header: ?JWK = null,
    /// A signature for the image manifest, signed by a libtrust private key
    signature: ?[]const u8 = null,
    /// The signed protected header
    protected: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A JSON web signature
pub const JWK = struct {
    /// JSON web key parameter
    jwk: ?JWKHeader = null,
    /// The algorithm used to sign or encrypt the JWT
    alg: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// JSON web key parameter
pub const JWKHeader = struct {
    /// crv value
    crv: ?[]const u8 = null,
    /// kid value
    kid: ?[]const u8 = null,
    /// kty value
    kty: ?[]const u8 = null,
    /// x value
    x: ?[]const u8 = null,
    /// y value
    y: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Returns the requested manifest file
pub const Manifest = struct {
    /// Schema version
    schema_version: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// List of repositories
pub const Repositories = struct {
    /// Repository names
    repositories: ?[]const []const u8 = null,
    /// Link to the next page of results
    link: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Properties of this repository.
pub const ContainerRepositoryProperties = struct {
    /// Registry login server name. This is likely to be similar to
    /// {registry-name}.azurecr.io.
    registry_login_server: []const u8,
    /// Image name
    name: []const u8,
    /// Image created time
    created_on: []const u8,
    /// Image last update time
    last_updated_on: []const u8,
    /// Number of the manifests
    manifest_count: i32,
    /// Number of the tags
    tag_count: i32,
    /// Writeable properties of the resource
    changeable_attributes: RepositoryChangeableAttributes,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .registry_login_server = "registry",
            .name = "imageName",
            .created_on = "createdTime",
            .last_updated_on = "lastUpdateTime",
        },
    };
};

/// Changeable attributes for Repository
pub const RepositoryChangeableAttributes = struct {
    /// Delete enabled
    can_delete: ?bool = null,
    /// Write enabled
    can_write: ?bool = null,
    /// List enabled
    can_list: ?bool = null,
    /// Read enabled
    can_read: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .can_delete = "deleteEnabled",
            .can_write = "writeEnabled",
            .can_list = "listEnabled",
            .can_read = "readEnabled",
        },
    };
};

/// List of tag details
pub const TagList = struct {
    /// Registry login server name. This is likely to be similar to
    /// {registry-name}.azurecr.io.
    registry_login_server: []const u8,
    /// Image name
    repository: []const u8,
    /// List of tag attribute details
    tag_attribute_bases: []const TagAttributesBase,
    /// Link to the next page of results
    link: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .registry_login_server = "registry",
            .repository = "imageName",
            .tag_attribute_bases = "tags",
        },
    };
};

/// Tag attribute details
pub const TagAttributesBase = struct {
    /// Tag name
    name: []const u8,
    /// Tag digest
    digest: []const u8,
    /// Tag created time
    created_on: []const u8,
    /// Tag last update time
    last_updated_on: []const u8,
    /// Is signed
    signed: ?bool = null,
    /// Writeable properties of the resource
    changeable_attributes: TagChangeableAttributes,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .created_on = "createdTime",
            .last_updated_on = "lastUpdateTime",
        },
    };
};

/// Changeable attributes
pub const TagChangeableAttributes = struct {
    /// Delete enabled
    can_delete: ?bool = null,
    /// Write enabled
    can_write: ?bool = null,
    /// List enabled
    can_list: ?bool = null,
    /// Read enabled
    can_read: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .can_delete = "deleteEnabled",
            .can_write = "writeEnabled",
            .can_list = "listEnabled",
            .can_read = "readEnabled",
        },
    };
};

/// Tag attributes
pub const ArtifactTagProperties = struct {
    /// Registry login server name. This is likely to be similar to
    /// {registry-name}.azurecr.io.
    registry_login_server: []const u8,
    /// Image name
    repository_name: []const u8,
    /// List of tag attribute details
    tag: TagAttributesBase,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .registry_login_server = "registry",
            .repository_name = "imageName",
        },
    };
};

/// Manifest attributes
pub const AcrManifests = struct {
    /// Registry login server name. This is likely to be similar to
    /// {registry-name}.azurecr.io.
    registry_login_server: ?[]const u8 = null,
    /// Image name
    repository: ?[]const u8 = null,
    /// List of manifests
    manifests: ?[]const ManifestAttributesBase = null,
    /// Link to the next page of results
    link: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .registry_login_server = "registry",
            .repository = "imageName",
        },
    };
};

/// Manifest details
pub const ManifestAttributesBase = struct {
    /// Manifest
    digest: []const u8,
    /// Image size
    size: ?i64 = null,
    /// Created time
    created_on: []const u8,
    /// Last update time
    last_updated_on: []const u8,
    /// CPU architecture
    architecture: ?enums.ArtifactArchitecture = null,
    /// Operating system
    operating_system: ?enums.ArtifactOperatingSystem = null,
    /// List of artifacts that are referenced by this manifest list, with information
    /// about the platform each supports.  This list will be empty if this is a leaf
    /// manifest and not a manifest list.
    related_artifacts: ?[]const ArtifactManifestPlatform = null,
    /// Config blob media type
    config_media_type: ?[]const u8 = null,
    /// List of tags
    tags: ?[]const []const u8 = null,
    /// Writeable properties of the resource
    changeable_attributes: ?ManifestChangeableAttributes = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .size = "imageSize",
            .created_on = "createdTime",
            .last_updated_on = "lastUpdateTime",
            .operating_system = "os",
            .related_artifacts = "references",
        },
    };
};

/// The artifact's platform, consisting of operating system and architecture.
pub const ArtifactManifestPlatform = struct {
    /// Manifest digest
    digest: []const u8,
    /// CPU architecture
    architecture: ?enums.ArtifactArchitecture = null,
    /// Operating system
    operating_system: ?enums.ArtifactOperatingSystem = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .operating_system = "os",
        },
    };
};

/// Changeable attributes
pub const ManifestChangeableAttributes = struct {
    /// Delete enabled
    can_delete: ?bool = null,
    /// Write enabled
    can_write: ?bool = null,
    /// List enabled
    can_list: ?bool = null,
    /// Read enabled
    can_read: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .can_delete = "deleteEnabled",
            .can_write = "writeEnabled",
            .can_list = "listEnabled",
            .can_read = "readEnabled",
        },
    };
};

/// Manifest attributes details
pub const ArtifactManifestProperties = struct {
    /// Registry login server name. This is likely to be similar to
    /// {registry-name}.azurecr.io.
    registry_login_server: ?[]const u8 = null,
    /// Repository name
    repository_name: ?[]const u8 = null,
    /// Manifest attributes
    manifest: ManifestAttributesBase,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .registry_login_server = "registry",
            .repository_name = "imageName",
        },
    };
};

/// The multipart body parameter for AAD token exchange.
pub const MultipartBodyParameter = struct {
    /// Can take a value of access_token_refresh_token, or access_token, or
    /// refresh_token
    grant_type: enums.PostContentSchemaGrantType,
    /// Indicates the name of your Azure container registry.
    service: []const u8,
    /// AAD tenant associated to the AAD credentials.
    tenant: ?[]const u8 = null,
    /// AAD refresh token, mandatory when grant_type is access_token_refresh_token or
    /// refresh_token
    refresh_token: ?[]const u8 = null,
    /// AAD access token, mandatory when grant_type is access_token_refresh_token or
    /// access_token.
    access_token: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The ACR refresh token response containing the refresh token for authentication.
pub const AcrRefreshToken = struct {
    /// The refresh token to be used for generating access tokens
    refresh_token: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .refresh_token = "refresh_token",
        },
    };
};

/// The ACR access token response containing the access token for authentication.
pub const AcrAccessToken = struct {
    /// The access token for performing authenticated requests
    access_token: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .access_token = "access_token",
        },
    };
};
