//! Hand-written container and blob convenience clients.
//!
//! The generated client in `src/clients.zig` models Azure Blob metadata as a
//! single `x-ms-meta` header. That is not the Azure wire format: metadata
//! travels as one `x-ms-meta-{name}` header per entry, and a literal
//! `x-ms-meta` header sets nothing. These clients implement the real format so
//! callers such as the Event Hubs checkpoint store can round-trip metadata.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const default_api_version = "2024-11-04";

/// Prefix Azure uses for user-defined blob and container metadata headers.
pub const metadata_header_prefix = "x-ms-meta-";

// ─────────────────────────── Metadata ─────────────────────────

pub const MetadataEntry = struct {
    name: []const u8,
    value: []const u8,
};

/// Allocator-owned metadata read back from a response.
///
/// Entries preserve the order the service returned them.
pub const Metadata = struct {
    entries: []MetadataEntry = &.{},

    /// Look up a value by name. Azure metadata names are case-insensitive.
    pub fn get(self: Metadata, name: []const u8) ?[]const u8 {
        for (self.entries) |entry| {
            if (std.ascii.eqlIgnoreCase(entry.name, name)) return entry.value;
        }
        return null;
    }

    pub fn deinit(self: Metadata, allocator: std.mem.Allocator) void {
        for (self.entries) |entry| {
            allocator.free(entry.name);
            allocator.free(entry.value);
        }
        allocator.free(self.entries);
    }
};

/// Azure requires metadata names to be valid C# identifiers, so a name must
/// start with a letter or underscore and otherwise contain only ASCII
/// alphanumerics and underscores.
pub fn isValidMetadataName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!std.ascii.isAlphabetic(name[0]) and name[0] != '_') return false;
    for (name[1..]) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '_') return false;
    }
    return true;
}

fn applyMetadata(
    allocator: std.mem.Allocator,
    request: *core.http.Request,
    metadata: []const MetadataEntry,
) !void {
    for (metadata) |entry| {
        if (!isValidMetadataName(entry.name)) return error.InvalidMetadataName;
        const header = try std.fmt.allocPrint(
            allocator,
            metadata_header_prefix ++ "{s}",
            .{entry.name},
        );
        defer allocator.free(header);
        try request.setHeader(header, entry.value);
    }
}

fn metadataNameOf(header_name: []const u8) ?[]const u8 {
    if (header_name.len <= metadata_header_prefix.len) return null;
    if (!std.ascii.startsWithIgnoreCase(header_name, metadata_header_prefix)) return null;
    return header_name[metadata_header_prefix.len..];
}

fn appendMetadataEntry(
    allocator: std.mem.Allocator,
    list: *std.ArrayList(MetadataEntry),
    name: []const u8,
    value: []const u8,
) !void {
    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    const owned_value = try allocator.dupe(u8, value);
    errdefer allocator.free(owned_value);
    try list.append(allocator, .{ .name = owned_name, .value = owned_value });
}

fn lessThanByName(_: void, lhs: MetadataEntry, rhs: MetadataEntry) bool {
    return std.mem.lessThan(u8, lhs.name, rhs.name);
}

fn collectMetadata(
    allocator: std.mem.Allocator,
    response: *const core.http.Response,
) !Metadata {
    var list: std.ArrayList(MetadataEntry) = .empty;
    errdefer {
        for (list.items) |entry| {
            allocator.free(entry.name);
            allocator.free(entry.value);
        }
        list.deinit(allocator);
    }

    // Preferred path: ordered headers preserve the order the service sent.
    for (response.response_headers.entries.items) |header| {
        const name = metadataNameOf(header.name) orelse continue;
        try appendMetadataEntry(allocator, &list, name, header.value);
    }

    if (list.items.len == 0) {
        // Fallback for transports that only populate the deduplicated map.
        // Hash map order is unspecified, so sort for a stable result.
        var iterator = response.headers.iterator();
        while (iterator.next()) |entry| {
            const name = metadataNameOf(entry.key_ptr.*) orelse continue;
            try appendMetadataEntry(allocator, &list, name, entry.value_ptr.*);
        }
        std.mem.sort(MetadataEntry, list.items, {}, lessThanByName);
    }

    return .{ .entries = try list.toOwnedSlice(allocator) };
}

// ─────────────────────────── Models ───────────────────────────

pub const BlobProperties = struct {
    content_type: ?[]const u8 = null,
    content_length: ?u64 = null,
    etag: ?[]const u8 = null,
    last_modified: ?[]const u8 = null,
    metadata: Metadata = .{},

    pub fn deinit(self: BlobProperties, allocator: std.mem.Allocator) void {
        if (self.content_type) |value| allocator.free(value);
        if (self.etag) |value| allocator.free(value);
        if (self.last_modified) |value| allocator.free(value);
        self.metadata.deinit(allocator);
    }
};

pub const BlobItem = struct {
    name: []const u8,
    properties: BlobProperties = .{},

    pub fn deinit(self: BlobItem, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.properties.deinit(allocator);
    }
};

/// Free a slice returned by `BlobContainerClient.listBlobs`.
pub fn freeBlobItems(allocator: std.mem.Allocator, items: []const BlobItem) void {
    for (items) |item| item.deinit(allocator);
    allocator.free(items);
}

// ─────────────────────── BlobContainerClient ──────────────────

/// Scope the service expects for AAD-authenticated Blob Storage requests.
pub const auth_scopes: []const []const u8 = &.{"https://storage.azure.com/.default"};

pub const ListBlobsOptions = struct {
    prefix: ?[]const u8 = null,
    /// Request `x-ms-meta-*` values for each blob in the listing.
    include_metadata: bool = false,
    /// `maxresults` page size. The service caps a page at 5000 regardless;
    /// listing follows continuation markers until the container is exhausted.
    page_size: ?u32 = null,
};

pub const BlobContainerClient = struct {
    endpoint: []const u8,
    container_name: []const u8,
    api_version: []const u8,
    pipeline: core.http.HttpPipeline,

    pub const InitOptions = struct {
        endpoint: []const u8,
        container_name: []const u8,
        api_version: []const u8 = default_api_version,
    };

    /// Build a client over a caller-owned pipeline.
    ///
    /// The pipeline and its runtime descriptors are copied by value. Their
    /// borrowed transport, crypto, policy, and credential contexts must
    /// outlive this client and every blob client derived from it.
    pub fn init(
        pipeline: core.http.HttpPipeline,
        options: InitOptions,
    ) BlobContainerClient {
        return .{
            .endpoint = options.endpoint,
            .container_name = options.container_name,
            .api_version = options.api_version,
            .pipeline = pipeline,
        };
    }

    /// PUT /container?restype=container
    pub fn create(self: *BlobContainerClient, allocator: std.mem.Allocator) !void {
        var result = try self.createResult(allocator);
        try result.unwrap(error.CreateContainerFailed);
    }

    pub fn createResult(
        self: *BlobContainerClient,
        allocator: std.mem.Allocator,
    ) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?restype=container",
            .{ self.endpoint, self.container_name },
        );
        defer allocator.free(url);

        var request = core.http.Request.init(allocator, .PUT, url);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);

        var response = try self.pipeline.send(&request);
        defer response.deinit();

        if (response.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, response)) |azure_error| {
            return .{ .err = azure_error };
        }
        return error.AzureRequestFailed;
    }

    /// DELETE /container?restype=container
    pub fn deleteContainer(self: *BlobContainerClient, allocator: std.mem.Allocator) !void {
        var result = try self.deleteContainerResult(allocator);
        try result.unwrap(error.DeleteContainerFailed);
    }

    pub fn deleteContainerResult(
        self: *BlobContainerClient,
        allocator: std.mem.Allocator,
    ) !core.errors.Result(void) {
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}?restype=container",
            .{ self.endpoint, self.container_name },
        );
        defer allocator.free(url);

        var request = core.http.Request.init(allocator, .DELETE, url);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);

        var response = try self.pipeline.send(&request);
        defer response.deinit();

        if (response.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, response)) |azure_error| {
            return .{ .err = azure_error };
        }
        return error.AzureRequestFailed;
    }

    /// GET /container?restype=container&comp=list
    ///
    /// Free the result with `freeBlobItems`.
    pub fn listBlobs(self: *BlobContainerClient, allocator: std.mem.Allocator) ![]BlobItem {
        return self.listBlobsWithOptions(allocator, .{});
    }

    /// Lists every blob in the container, following the service's continuation
    /// markers. A single response is capped at 5000 blobs, so a one-shot
    /// request would silently truncate larger containers.
    pub fn listBlobsWithOptions(
        self: *BlobContainerClient,
        allocator: std.mem.Allocator,
        options: ListBlobsOptions,
    ) ![]BlobItem {
        var items: std.ArrayList(BlobItem) = .empty;
        errdefer {
            for (items.items) |item| item.deinit(allocator);
            items.deinit(allocator);
        }

        var marker: ?[]u8 = null;
        defer if (marker) |value| allocator.free(value);

        while (true) {
            const page = try self.listBlobsPage(allocator, options, marker);
            defer allocator.free(page.items);
            errdefer {
                for (page.items) |item| item.deinit(allocator);
                if (page.next_marker) |value| allocator.free(value);
            }

            try items.appendSlice(allocator, page.items);

            const next = page.next_marker orelse break;
            // A service that echoed the same marker back would loop forever.
            if (marker) |previous| {
                if (std.mem.eql(u8, previous, next)) {
                    allocator.free(next);
                    break;
                }
                allocator.free(previous);
            }
            marker = next;
        }

        return items.toOwnedSlice(allocator);
    }

    const BlobPage = struct {
        items: []BlobItem,
        next_marker: ?[]u8,
    };

    fn listBlobsPage(
        self: *BlobContainerClient,
        allocator: std.mem.Allocator,
        options: ListBlobsOptions,
        marker: ?[]const u8,
    ) !BlobPage {
        var url_buffer: std.ArrayList(u8) = .empty;
        defer url_buffer.deinit(allocator);
        try url_buffer.print(allocator, "{s}/{s}?restype=container&comp=list", .{
            self.endpoint,
            self.container_name,
        });
        if (options.prefix) |prefix| {
            const encoded = try core.url.percentEncode(allocator, prefix);
            defer allocator.free(encoded);
            try url_buffer.print(allocator, "&prefix={s}", .{encoded});
        }
        if (options.include_metadata) try url_buffer.appendSlice(allocator, "&include=metadata");
        if (options.page_size) |page_size| {
            try url_buffer.print(allocator, "&maxresults={d}", .{page_size});
        }
        if (marker) |value| {
            const encoded = try core.url.percentEncode(allocator, value);
            defer allocator.free(encoded);
            try url_buffer.print(allocator, "&marker={s}", .{encoded});
        }

        var request = core.http.Request.init(allocator, .GET, url_buffer.items);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);

        var response = try self.pipeline.send(&request);
        defer response.deinit();

        if (!response.isSuccess()) {
            core.errors.logErrorResponse(response);
            return error.ListBlobsFailed;
        }

        const items = try parseBlobList(allocator, response.body);
        errdefer freeBlobItems(allocator, items);

        return .{
            .items = items,
            .next_marker = try parseNextMarker(allocator, response.body),
        };
    }

    pub fn getBlobClient(self: *BlobContainerClient, blob_name: []const u8) BlobClient {
        return .{
            .endpoint = self.endpoint,
            .container_name = self.container_name,
            .blob_name = blob_name,
            .api_version = self.api_version,
            .pipeline = self.pipeline,
        };
    }
};

// ─────────────────────────── BlobClient ───────────────────────

pub const UploadBlobOptions = struct {
    content_type: []const u8 = "application/octet-stream",
    metadata: []const MetadataEntry = &.{},
    if_match: ?[]const u8 = null,
    if_none_match: ?[]const u8 = null,
};

pub const UploadBlobResult = struct {
    etag: ?[]const u8 = null,
    last_modified: ?[]const u8 = null,

    pub fn deinit(self: UploadBlobResult, allocator: std.mem.Allocator) void {
        if (self.etag) |value| allocator.free(value);
        if (self.last_modified) |value| allocator.free(value);
    }
};

pub const SetMetadataOptions = struct {
    if_match: ?[]const u8 = null,
    if_none_match: ?[]const u8 = null,
};

pub const SetMetadataResult = UploadBlobResult;

/// Blob content together with the properties and metadata returned on the same
/// download response.
pub const DownloadBlobResult = struct {
    data: []const u8 = &.{},
    properties: BlobProperties = .{},

    pub fn deinit(self: DownloadBlobResult, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
        self.properties.deinit(allocator);
    }
};

pub const BlobClient = struct {
    endpoint: []const u8,
    container_name: []const u8,
    blob_name: []const u8,
    api_version: []const u8 = default_api_version,
    pipeline: core.http.HttpPipeline,

    /// GET /container/blob
    pub fn download(self: *BlobClient, allocator: std.mem.Allocator) ![]const u8 {
        var result = try self.downloadResult(allocator);
        return result.unwrap(error.DownloadFailed);
    }

    pub fn downloadResult(
        self: *BlobClient,
        allocator: std.mem.Allocator,
    ) !core.errors.Result([]const u8) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var request = core.http.Request.init(allocator, .GET, url);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);

        var response = try self.pipeline.send(&request);
        defer response.deinit();

        if (!response.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, response)) |azure_error| {
                return .{ .err = azure_error };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try allocator.dupe(u8, response.body) };
    }

    /// GET /container/blob, returning the content alongside the properties and
    /// metadata that came back on the same response.
    pub fn downloadWithProperties(
        self: *BlobClient,
        allocator: std.mem.Allocator,
    ) !DownloadBlobResult {
        var result = try self.downloadWithPropertiesResult(allocator);
        return result.unwrap(error.DownloadFailed);
    }

    pub fn downloadWithPropertiesResult(
        self: *BlobClient,
        allocator: std.mem.Allocator,
    ) !core.errors.Result(DownloadBlobResult) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var request = core.http.Request.init(allocator, .GET, url);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);

        var response = try self.pipeline.send(&request);
        defer response.deinit();

        if (!response.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, response)) |azure_error| {
                return .{ .err = azure_error };
            }
            return error.AzureRequestFailed;
        }

        var result = DownloadBlobResult{ .data = try allocator.dupe(u8, response.body) };
        errdefer result.deinit(allocator);
        result.properties = try readProperties(allocator, &response);
        return .{ .ok = result };
    }

    /// PUT /container/blob
    pub fn upload(
        self: *BlobClient,
        allocator: std.mem.Allocator,
        data: []const u8,
        content_type: []const u8,
    ) !void {
        var result = try self.uploadConditionalResult(allocator, data, .{ .content_type = content_type });
        var value = try result.unwrap(error.UploadFailed);
        value.deinit(allocator);
    }

    /// PUT /container/blob with metadata, conditional headers, and an ETag.
    pub fn uploadConditional(
        self: *BlobClient,
        allocator: std.mem.Allocator,
        data: []const u8,
        options: UploadBlobOptions,
    ) !UploadBlobResult {
        var result = try self.uploadConditionalResult(allocator, data, options);
        return result.unwrap(error.UploadFailed);
    }

    pub fn uploadConditionalResult(
        self: *BlobClient,
        allocator: std.mem.Allocator,
        data: []const u8,
        options: UploadBlobOptions,
    ) !core.errors.Result(UploadBlobResult) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var request = core.http.Request.init(allocator, .PUT, url);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);
        try request.setHeader("Content-Type", options.content_type);
        try request.setHeader("x-ms-blob-type", "BlockBlob");
        if (options.if_match) |etag| try request.setHeader("If-Match", etag);
        if (options.if_none_match) |etag| try request.setHeader("If-None-Match", etag);
        try applyMetadata(allocator, &request, options.metadata);
        request.body = data;

        return self.sendForWriteResult(allocator, &request);
    }

    /// PUT /container/blob?comp=metadata
    ///
    /// Replaces every metadata entry on an existing blob without rewriting its
    /// content, which is how the Go and Rust Event Hubs checkpoint stores
    /// update a checkpoint.
    pub fn setMetadata(
        self: *BlobClient,
        allocator: std.mem.Allocator,
        metadata: []const MetadataEntry,
        options: SetMetadataOptions,
    ) !SetMetadataResult {
        var result = try self.setMetadataResult(allocator, metadata, options);
        return result.unwrap(error.SetMetadataFailed);
    }

    pub fn setMetadataResult(
        self: *BlobClient,
        allocator: std.mem.Allocator,
        metadata: []const MetadataEntry,
        options: SetMetadataOptions,
    ) !core.errors.Result(SetMetadataResult) {
        const blob_url = try self.buildBlobUrl(allocator);
        defer allocator.free(blob_url);
        const url = try std.fmt.allocPrint(allocator, "{s}?comp=metadata", .{blob_url});
        defer allocator.free(url);

        var request = core.http.Request.init(allocator, .PUT, url);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);
        if (options.if_match) |etag| try request.setHeader("If-Match", etag);
        if (options.if_none_match) |etag| try request.setHeader("If-None-Match", etag);
        try applyMetadata(allocator, &request, metadata);

        return self.sendForWriteResult(allocator, &request);
    }

    /// DELETE /container/blob
    pub fn deleteBlob(self: *BlobClient, allocator: std.mem.Allocator) !void {
        var result = try self.deleteBlobResult(allocator);
        try result.unwrap(error.DeleteBlobFailed);
    }

    pub fn deleteBlobResult(
        self: *BlobClient,
        allocator: std.mem.Allocator,
    ) !core.errors.Result(void) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var request = core.http.Request.init(allocator, .DELETE, url);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);

        var response = try self.pipeline.send(&request);
        defer response.deinit();

        if (response.isSuccess()) return .{ .ok = {} };
        if (core.errors.errorFromResponse(allocator, response)) |azure_error| {
            return .{ .err = azure_error };
        }
        return error.AzureRequestFailed;
    }

    /// HEAD /container/blob
    pub fn getProperties(self: *BlobClient, allocator: std.mem.Allocator) !BlobProperties {
        var result = try self.getPropertiesResult(allocator);
        return result.unwrap(error.GetPropertiesFailed);
    }

    pub fn getPropertiesResult(
        self: *BlobClient,
        allocator: std.mem.Allocator,
    ) !core.errors.Result(BlobProperties) {
        const url = try self.buildBlobUrl(allocator);
        defer allocator.free(url);

        var request = core.http.Request.init(allocator, .HEAD, url);
        defer request.deinit();
        try request.setHeader("x-ms-version", self.api_version);

        var response = try self.pipeline.send(&request);
        defer response.deinit();

        if (!response.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, response)) |azure_error| {
                return .{ .err = azure_error };
            }
            return error.AzureRequestFailed;
        }

        return .{ .ok = try readProperties(allocator, &response) };
    }

    fn readProperties(
        allocator: std.mem.Allocator,
        response: *const core.http.Response,
    ) !BlobProperties {
        var properties = BlobProperties{};
        errdefer properties.deinit(allocator);

        properties.metadata = try collectMetadata(allocator, response);
        if (response.getHeader("Content-Type")) |value| {
            properties.content_type = try allocator.dupe(u8, value);
        }
        if (response.getHeader("ETag")) |value| {
            properties.etag = try allocator.dupe(u8, value);
        }
        if (response.getHeader("Last-Modified")) |value| {
            properties.last_modified = try allocator.dupe(u8, value);
        }
        if (response.getHeader("Content-Length")) |value| {
            properties.content_length = std.fmt.parseInt(u64, value, 10) catch null;
        }
        return properties;
    }

    fn sendForWriteResult(
        self: *BlobClient,
        allocator: std.mem.Allocator,
        request: *core.http.Request,
    ) !core.errors.Result(UploadBlobResult) {
        var response = try self.pipeline.send(request);
        defer response.deinit();

        if (!response.isSuccess()) {
            if (core.errors.errorFromResponse(allocator, response)) |azure_error| {
                return .{ .err = azure_error };
            }
            return error.AzureRequestFailed;
        }

        var result = UploadBlobResult{};
        errdefer result.deinit(allocator);
        if (response.getHeader("ETag")) |value| {
            result.etag = try allocator.dupe(u8, value);
        }
        if (response.getHeader("Last-Modified")) |value| {
            result.last_modified = try allocator.dupe(u8, value);
        }
        return .{ .ok = result };
    }

    /// Percent-encodes the blob name while preserving `/` separators, so names
    /// containing characters such as `$` or `#` reach the service intact.
    fn buildBlobUrl(self: *BlobClient, allocator: std.mem.Allocator) ![]u8 {
        const encoded_name = try core.url.encodeRepositoryName(allocator, self.blob_name);
        defer allocator.free(encoded_name);
        return std.fmt.allocPrint(allocator, "{s}/{s}/{s}", .{
            self.endpoint,
            self.container_name,
            encoded_name,
        });
    }
};

// ─────────────────────────── Parsing ──────────────────────────

/// A located XML element within a slice.
const Element = struct {
    attributes: []const u8,
    inner: []const u8,
    /// Index in the searched slice just past this element's closing tag.
    end: usize,
};

/// Find the next `<name ...>...</name>` element at or after `start`.
///
/// This is a deliberately small scanner rather than a general XML parser: the
/// List Blobs schema is flat, but `<Metadata>` children carry arbitrary names
/// that no struct can model, so serde cannot deserialize the response.
fn findElement(xml: []const u8, start: usize, name: []const u8) ?Element {
    var cursor = start;
    while (std.mem.indexOfScalarPos(u8, xml, cursor, '<')) |lt| {
        const after = lt + 1 + name.len;
        if (after >= xml.len) return null;
        cursor = lt + 1;
        if (!std.mem.startsWith(u8, xml[lt + 1 ..], name)) continue;
        // Reject prefix matches such as `<BlobPrefix>` when looking for `Blob`.
        switch (xml[after]) {
            '>', '/', ' ', '\t', '\r', '\n' => {},
            else => continue,
        }

        const gt = std.mem.indexOfScalarPos(u8, xml, after, '>') orelse return null;
        const attributes = xml[after..gt];
        if (gt > after and xml[gt - 1] == '/') {
            return .{
                .attributes = attributes[0 .. attributes.len - 1],
                .inner = xml[gt..gt],
                .end = gt + 1,
            };
        }

        var close_buffer: [64]u8 = undefined;
        if (name.len + 3 > close_buffer.len) return null;
        const close_tag = std.fmt.bufPrint(&close_buffer, "</{s}>", .{name}) catch return null;
        const close = std.mem.indexOfPos(u8, xml, gt + 1, close_tag) orelse return null;
        return .{
            .attributes = attributes,
            .inner = xml[gt + 1 .. close],
            .end = close + close_tag.len,
        };
    }
    return null;
}

/// Decoded text of a direct child element, or null when it is absent.
fn childText(allocator: std.mem.Allocator, element: []const u8, name: []const u8) !?[]u8 {
    const child = findElement(element, 0, name) orelse return null;
    return try decodeXmlText(allocator, child.inner);
}

fn hasEncodedAttribute(attributes: []const u8) bool {
    const marker = std.mem.indexOf(u8, attributes, "Encoded") orelse return false;
    const rest = attributes[marker + "Encoded".len ..];
    const equals = std.mem.indexOfScalar(u8, rest, '=') orelse return false;
    return std.mem.indexOf(u8, rest[equals..], "true") != null;
}

/// Read `<Name>`, honouring `Encoded="true"`, which the service uses when a
/// blob name contains characters that are not legal in XML.
fn parseBlobName(allocator: std.mem.Allocator, element: []const u8) !?[]u8 {
    const child = findElement(element, 0, "Name") orelse return null;
    const text = try decodeXmlText(allocator, child.inner);
    if (!hasEncodedAttribute(child.attributes)) return text;
    defer allocator.free(text);
    return try core.url.percentDecode(allocator, text);
}

fn parseBlobList(allocator: std.mem.Allocator, body: []const u8) ![]BlobItem {
    var result: std.ArrayList(BlobItem) = .empty;
    errdefer {
        for (result.items) |item| item.deinit(allocator);
        result.deinit(allocator);
    }

    const results = findElement(body, 0, "EnumerationResults") orelse
        return error.InvalidListBlobsResponse;
    // An empty container omits `<Blobs>` entirely on some API versions.
    const blobs = findElement(results.inner, 0, "Blobs") orelse
        return result.toOwnedSlice(allocator);

    var cursor: usize = 0;
    while (findElement(blobs.inner, cursor, "Blob")) |blob| {
        cursor = blob.end;

        const name = try parseBlobName(allocator, blob.inner) orelse
            return error.InvalidListBlobsResponse;
        var item = BlobItem{ .name = name };
        errdefer item.deinit(allocator);

        if (findElement(blob.inner, 0, "Properties")) |properties| {
            item.properties.content_type = try childText(allocator, properties.inner, "Content-Type");
            item.properties.last_modified = try childText(allocator, properties.inner, "Last-Modified");
            // The list schema spells it `Etag`; headers spell it `ETag`.
            item.properties.etag = try childText(allocator, properties.inner, "Etag") orelse
                try childText(allocator, properties.inner, "ETag");
            if (try childText(allocator, properties.inner, "Content-Length")) |value| {
                defer allocator.free(value);
                item.properties.content_length = std.fmt.parseInt(u64, value, 10) catch null;
            }
        }

        item.properties.metadata = try parseMetadataElement(allocator, blob.inner);
        try result.append(allocator, item);
    }

    return result.toOwnedSlice(allocator);
}

/// Read `<NextMarker>` from a List Blobs response. An empty element means the
/// listing is complete.
fn parseNextMarker(allocator: std.mem.Allocator, body: []const u8) !?[]u8 {
    const marker = try childText(allocator, body, "NextMarker") orelse return null;
    if (marker.len == 0) {
        allocator.free(marker);
        return null;
    }
    return marker;
}

/// Parse `<Metadata><name>value</name>...</Metadata>` out of a `<Blob>` element.
/// Names are validated the same way outgoing metadata is, so a malformed server
/// response cannot smuggle an unusable name into the map.
fn parseMetadataElement(allocator: std.mem.Allocator, element: []const u8) !Metadata {
    var entries: std.ArrayList(MetadataEntry) = .empty;
    errdefer {
        for (entries.items) |entry| {
            allocator.free(entry.name);
            allocator.free(entry.value);
        }
        entries.deinit(allocator);
    }

    const metadata = findElement(element, 0, "Metadata") orelse
        return .{ .entries = try entries.toOwnedSlice(allocator) };
    const inner = metadata.inner;

    var cursor: usize = 0;
    while (std.mem.indexOfScalarPos(u8, inner, cursor, '<')) |lt| {
        const gt = std.mem.indexOfScalarPos(u8, inner, lt + 1, '>') orelse break;
        var tag = inner[lt + 1 .. gt];
        cursor = gt + 1;
        if (tag.len == 0 or tag[0] == '/' or tag[0] == '?' or tag[0] == '!') continue;

        const self_closing = tag[tag.len - 1] == '/';
        if (self_closing) tag = tag[0 .. tag.len - 1];
        // Drop any attributes; metadata elements carry none that we need.
        if (std.mem.indexOfAny(u8, tag, " \t\r\n")) |space| tag = tag[0..space];
        if (!isValidMetadataName(tag)) continue;

        if (self_closing) {
            try appendMetadataEntry(allocator, &entries, tag, "");
            continue;
        }

        const end_tag = try std.fmt.allocPrint(allocator, "</{s}>", .{tag});
        defer allocator.free(end_tag);
        const value_end = std.mem.indexOfPos(u8, inner, cursor, end_tag) orelse continue;

        const decoded = try decodeXmlText(allocator, inner[cursor..value_end]);
        defer allocator.free(decoded);
        try appendMetadataEntry(allocator, &entries, tag, decoded);
        cursor = value_end + end_tag.len;
    }

    std.mem.sort(MetadataEntry, entries.items, {}, lessThanByName);
    return .{ .entries = try entries.toOwnedSlice(allocator) };
}

/// Expand the five predefined XML entities. Metadata values are ASCII by
/// Azure's rules, so numeric character references are not handled.
fn decodeXmlText(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    if (std.mem.indexOfScalar(u8, text, '&') == null) return allocator.dupe(u8, text);

    const entities = [_]struct { name: []const u8, char: u8 }{
        .{ .name = "&amp;", .char = '&' },
        .{ .name = "&lt;", .char = '<' },
        .{ .name = "&gt;", .char = '>' },
        .{ .name = "&quot;", .char = '"' },
        .{ .name = "&apos;", .char = '\'' },
    };

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var cursor: usize = 0;
    outer: while (cursor < text.len) {
        if (text[cursor] == '&') {
            inline for (entities) |entity| {
                if (std.mem.startsWith(u8, text[cursor..], entity.name)) {
                    try out.append(allocator, entity.char);
                    cursor += entity.name.len;
                    continue :outer;
                }
            }
        }
        try out.append(allocator, text[cursor]);
        cursor += 1;
    }

    return out.toOwnedSlice(allocator);
}

// ─────────────────────────── Tests ────────────────────────────

const testing = std.testing;
var testing_crypto_provider = core.crypto.StdCryptoProvider.init(std.testing.io);

fn testRuntime(transport: core.http.HttpTransport) core.http.HttpRuntime {
    return core.http.HttpRuntime.init(
        transport,
        testing_crypto_provider.asProvider(),
    );
}

fn testContainer(transport: core.http.HttpTransport) BlobContainerClient {
    return BlobContainerClient.init(
        core.http.HttpPipeline.init(testRuntime(transport), &.{}),
        .{
            .endpoint = "https://myaccount.blob.core.windows.net",
            .container_name = "checkpoints",
        },
    );
}

test "isValidMetadataName accepts C# identifiers and rejects the rest" {
    try testing.expect(isValidMetadataName("ownerid"));
    try testing.expect(isValidMetadataName("sequencenumber"));
    try testing.expect(isValidMetadataName("_private"));
    try testing.expect(isValidMetadataName("Offset2"));

    try testing.expect(!isValidMetadataName(""));
    try testing.expect(!isValidMetadataName("2fast"));
    try testing.expect(!isValidMetadataName("has-dash"));
    try testing.expect(!isValidMetadataName("has space"));
    try testing.expect(!isValidMetadataName("dot.name"));
}

test "derived blob client preserves the container runtime" {
    var mock = core.http.MockTransport.init(testing.allocator, 200, "");
    defer mock.deinit();
    var container = testContainer(mock.asTransport());
    const blob = container.getBlobClient("blob");

    try testing.expectEqual(
        container.pipeline.runtime.transport.context,
        blob.pipeline.runtime.transport.context,
    );
    try testing.expectEqual(
        container.pipeline.runtime.crypto.context,
        blob.pipeline.runtime.crypto.context,
    );
}

test "uploadConditional emits one x-ms-meta header per entry" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "ETag", .value = "\"0x1\"" },
        .{ .name = "Last-Modified", .value = "Mon, 27 Jul 2026 00:00:00 GMT" },
    };

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("ns/hub/$Default/checkpoint/0");

    const result = try blob.uploadConditional(allocator, "", .{
        .content_type = "application/octet-stream",
        .metadata = &.{
            .{ .name = "sequencenumber", .value = "42" },
            .{ .name = "offset", .value = "100" },
        },
    });
    defer result.deinit(allocator);

    // Azure requires one header per entry, not a single `x-ms-meta` header.
    try testing.expectEqualStrings("42", mock.last_headers.get("x-ms-meta-sequencenumber").?);
    try testing.expectEqualStrings("100", mock.last_headers.get("x-ms-meta-offset").?);
    try testing.expect(mock.last_headers.get("x-ms-meta") == null);
    try testing.expectEqualStrings("BlockBlob", mock.last_headers.get("x-ms-blob-type").?);

    try testing.expectEqualStrings("\"0x1\"", result.etag.?);
    try testing.expectEqualStrings("Mon, 27 Jul 2026 00:00:00 GMT", result.last_modified.?);
}

test "uploadConditional rejects an invalid metadata name before sending" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("blob");

    try testing.expectError(error.InvalidMetadataName, blob.uploadConditional(allocator, "", .{
        .metadata = &.{.{ .name = "not-valid", .value = "x" }},
    }));
    try testing.expectEqual(@as(usize, 0), mock.call_count);
}

test "setMetadata targets comp=metadata and sends preconditions" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    mock.response_headers_list = &.{.{ .name = "ETag", .value = "\"0x2\"" }};

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("ns/hub/$Default/ownership/3");

    const result = try blob.setMetadata(
        allocator,
        &.{.{ .name = "ownerid", .value = "processor-1" }},
        .{ .if_match = "\"0x1\"" },
    );
    defer result.deinit(allocator);

    try testing.expect(std.mem.endsWith(
        u8,
        mock.last_url.?,
        "/checkpoints/ns/hub/%24Default/ownership/3?comp=metadata",
    ));
    try testing.expectEqualStrings("processor-1", mock.last_headers.get("x-ms-meta-ownerid").?);
    try testing.expectEqualStrings("\"0x1\"", mock.last_headers.get("If-Match").?);
    try testing.expectEqualStrings("\"0x2\"", result.etag.?);
}

test "setMetadata can claim an unowned blob with If-None-Match" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("blob");

    const result = try blob.setMetadata(
        allocator,
        &.{.{ .name = "ownerid", .value = "processor-2" }},
        .{ .if_none_match = "*" },
    );
    defer result.deinit(allocator);

    try testing.expectEqualStrings("*", mock.last_headers.get("If-None-Match").?);
    try testing.expect(mock.last_headers.get("If-Match") == null);
}

test "setMetadata surfaces a failed precondition as an Azure error" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 412, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("blob");

    var result = try blob.setMetadataResult(
        allocator,
        &.{.{ .name = "ownerid", .value = "loser" }},
        .{ .if_match = "\"stale\"" },
    );
    defer result.deinit(allocator);

    try testing.expect(!result.isOk());
}

test "getProperties reads x-ms-meta headers back into a metadata map" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "ETag", .value = "\"0x3\"" },
        .{ .name = "Last-Modified", .value = "Mon, 27 Jul 2026 12:00:00 GMT" },
        .{ .name = "Content-Type", .value = "application/octet-stream" },
        .{ .name = "Content-Length", .value = "0" },
        .{ .name = "x-ms-meta-sequencenumber", .value = "42" },
        .{ .name = "x-ms-meta-offset", .value = "100" },
    };

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("ns/hub/$Default/checkpoint/0");

    const properties = try blob.getProperties(allocator);
    defer properties.deinit(allocator);

    try testing.expectEqual(@as(usize, 2), properties.metadata.entries.len);
    try testing.expectEqualStrings("42", properties.metadata.get("sequencenumber").?);
    try testing.expectEqualStrings("100", properties.metadata.get("offset").?);
    // Azure lowercases metadata names on the wire, so lookup is case-insensitive.
    try testing.expectEqualStrings("42", properties.metadata.get("SequenceNumber").?);
    try testing.expect(properties.metadata.get("missing") == null);

    try testing.expectEqualStrings("\"0x3\"", properties.etag.?);
    try testing.expectEqualStrings("Mon, 27 Jul 2026 12:00:00 GMT", properties.last_modified.?);
    try testing.expectEqual(@as(u64, 0), properties.content_length.?);
}

test "metadata round-trips from upload through getProperties" {
    const allocator = testing.allocator;
    const written = [_]MetadataEntry{
        .{ .name = "ownerid", .value = "processor-1" },
        .{ .name = "sequencenumber", .value = "7" },
    };

    var upload_mock = core.http.MockTransport.init(allocator, 201, "");
    defer upload_mock.deinit();
    var container = testContainer(upload_mock.asTransport());
    var blob = container.getBlobClient("blob");
    const upload_result = try blob.uploadConditional(allocator, "", .{ .metadata = &written });
    defer upload_result.deinit(allocator);

    // Echo whatever the upload sent back as response headers.
    var echoed: [written.len]core.http.MockTransport.HeaderPair = undefined;
    var names: [written.len][]u8 = undefined;
    for (written, 0..) |entry, i| {
        names[i] = try std.fmt.allocPrint(allocator, metadata_header_prefix ++ "{s}", .{entry.name});
        echoed[i] = .{
            .name = names[i],
            .value = upload_mock.last_headers.get(names[i]).?,
        };
    }
    defer for (names) |name| allocator.free(name);

    var read_mock = core.http.MockTransport.init(allocator, 200, "");
    defer read_mock.deinit();
    read_mock.response_headers_list = &echoed;
    blob.pipeline = core.http.HttpPipeline.init(testRuntime(read_mock.asTransport()), &.{});

    const properties = try blob.getProperties(allocator);
    defer properties.deinit(allocator);

    try testing.expectEqual(written.len, properties.metadata.entries.len);
    for (written) |entry| {
        try testing.expectEqualStrings(entry.value, properties.metadata.get(entry.name).?);
    }
}

test "getProperties returns empty metadata when the blob has none" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    mock.response_headers_list = &.{.{ .name = "ETag", .value = "\"0x4\"" }};

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("blob");

    const properties = try blob.getProperties(allocator);
    defer properties.deinit(allocator);

    try testing.expectEqual(@as(usize, 0), properties.metadata.entries.len);
    try testing.expect(properties.metadata.get("ownerid") == null);
}

test "listBlobs parses names, properties, and metadata" {
    const allocator = testing.allocator;
    const body =
        \\<EnumerationResults><Blobs>
        \\<Blob><Name>ns/hub/$Default/ownership/0</Name><Properties><Etag>"0x1"</Etag><Last-Modified>Mon, 27 Jul 2026 00:00:00 GMT</Last-Modified><Content-Length>0</Content-Length></Properties><Metadata><ownerid>processor-1</ownerid></Metadata></Blob>
        \\<Blob><Name>ns/hub/$Default/ownership/1</Name><Properties><Etag>"0x2"</Etag></Properties><Metadata><ownerid>processor-2</ownerid></Metadata></Blob>
        \\</Blobs></EnumerationResults>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    const items = try container.listBlobsWithOptions(allocator, .{
        .prefix = "ns/hub/$Default/ownership/",
        .include_metadata = true,
    });
    defer freeBlobItems(allocator, items);

    try testing.expect(std.mem.find(u8, mock.last_url.?, "include=metadata") != null);
    try testing.expect(std.mem.find(u8, mock.last_url.?, "prefix=") != null);
    try testing.expect(std.mem.find(u8, mock.last_url.?, "restype=container&comp=list") != null);

    try testing.expectEqual(@as(usize, 2), items.len);
    try testing.expectEqualStrings("ns/hub/$Default/ownership/0", items[0].name);
    try testing.expectEqualStrings("processor-1", items[0].properties.metadata.get("ownerid").?);
    try testing.expectEqualStrings("\"0x1\"", items[0].properties.etag.?);
    try testing.expectEqual(@as(u64, 0), items[0].properties.content_length.?);
    try testing.expectEqualStrings("processor-2", items[1].properties.metadata.get("ownerid").?);
}

test "listBlobs tolerates an empty listing" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "<EnumerationResults><Blobs></Blobs></EnumerationResults>");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    const items = try container.listBlobs(allocator);
    defer freeBlobItems(allocator, items);

    try testing.expectEqual(@as(usize, 0), items.len);
}

test "container create and delete target restype=container" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    try container.create(allocator);
    try testing.expect(std.mem.endsWith(u8, mock.last_url.?, "/checkpoints?restype=container"));
    try testing.expectEqual(core.http.Method.PUT, mock.last_method.?);

    var delete_mock = core.http.MockTransport.init(allocator, 202, "");
    defer delete_mock.deinit();
    container.pipeline = core.http.HttpPipeline.init(testRuntime(delete_mock.asTransport()), &.{});
    try container.deleteContainer(allocator);
    try testing.expectEqual(core.http.Method.DELETE, delete_mock.last_method.?);
}

test "download and upload round trip through the container client" {
    const allocator = testing.allocator;
    var upload_mock = core.http.MockTransport.init(allocator, 201, "");
    defer upload_mock.deinit();

    var container = testContainer(upload_mock.asTransport());
    var blob = container.getBlobClient("myblob.txt");
    try blob.upload(allocator, "hello", "text/plain");
    try testing.expectEqualStrings("text/plain", upload_mock.last_headers.get("Content-Type").?);
    try testing.expect(std.mem.endsWith(u8, upload_mock.last_url.?, "/checkpoints/myblob.txt"));

    var download_mock = core.http.MockTransport.init(allocator, 200, "hello");
    defer download_mock.deinit();
    blob.pipeline = core.http.HttpPipeline.init(testRuntime(download_mock.asTransport()), &.{});
    const data = try blob.download(allocator);
    defer allocator.free(data);
    try testing.expectEqualStrings("hello", data);
}

test "listBlobs decodes XML entities and self-closing metadata elements" {
    const allocator = testing.allocator;
    const body =
        \\<EnumerationResults><Blobs>
        \\<Blob><Name>a</Name><Metadata><ownerid>a&amp;b&lt;c&gt;d&quot;e&apos;f</ownerid><empty /><Bad-Name>x</Bad-Name></Metadata></Blob>
        \\</Blobs></EnumerationResults>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    const items = try container.listBlobs(allocator);
    defer freeBlobItems(allocator, items);

    try testing.expectEqual(@as(usize, 1), items.len);
    const metadata = items[0].properties.metadata;
    try testing.expectEqualStrings("a&b<c>d\"e'f", metadata.get("ownerid").?);
    try testing.expectEqualStrings("", metadata.get("empty").?);
    // Names Azure could never have accepted on write are dropped on read too.
    try testing.expect(metadata.get("Bad-Name") == null);
    try testing.expectEqual(@as(usize, 2), metadata.entries.len);
}

test "blob names are percent-encoded except for path separators" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "hello");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("ns/hub/$Default/checkpoint/0");
    const data = try blob.download(allocator);
    defer allocator.free(data);

    try testing.expectEqualStrings(
        "https://myaccount.blob.core.windows.net/checkpoints/ns/hub/%24Default/checkpoint/0",
        mock.last_url.?,
    );
}

test "downloadWithProperties returns content and metadata together" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "payload");
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "ETag", .value = "\"0x5\"" },
        .{ .name = "Content-Length", .value = "7" },
        .{ .name = "x-ms-meta-ownerid", .value = "processor-1" },
    };

    var container = testContainer(mock.asTransport());
    var blob = container.getBlobClient("blob");

    const result = try blob.downloadWithProperties(allocator);
    defer result.deinit(allocator);

    try testing.expectEqualStrings("payload", result.data);
    try testing.expectEqualStrings("processor-1", result.properties.metadata.get("ownerid").?);
    try testing.expectEqualStrings("\"0x5\"", result.properties.etag.?);
    try testing.expectEqual(@as(u64, 7), result.properties.content_length.?);
}

/// Transport that replays a fixed script of response bodies, so a paginated
/// listing can be exercised without a live service.
const ScriptedTransport = struct {
    allocator: std.mem.Allocator,
    bodies: []const []const u8,
    index: usize = 0,
    urls: std.ArrayList([]u8) = .empty,

    const vtable: core.http.HttpTransport.VTable = .{
        .send = &sendImpl,
    };

    fn init(allocator: std.mem.Allocator, bodies: []const []const u8) ScriptedTransport {
        return .{ .allocator = allocator, .bodies = bodies };
    }

    fn deinit(self: *ScriptedTransport) void {
        for (self.urls.items) |url| self.allocator.free(url);
        self.urls.deinit(self.allocator);
    }

    fn asTransport(self: *ScriptedTransport) core.http.HttpTransport {
        return .{ .context = self, .vtable = &vtable };
    }

    fn sendImpl(
        context: *anyopaque,
        request: *core.http.Request,
    ) anyerror!core.http.Response {
        const self: *ScriptedTransport = @ptrCast(@alignCast(context));
        try self.urls.append(self.allocator, try self.allocator.dupe(u8, request.url));
        const body = self.bodies[@min(self.index, self.bodies.len - 1)];
        self.index += 1;
        return .{
            .status_code = 200,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = try self.allocator.dupe(u8, body),
            .allocator = self.allocator,
        };
    }
};

test "listBlobs follows NextMarker across pages" {
    const allocator = testing.allocator;
    const bodies = [_][]const u8{
        \\<EnumerationResults><Blobs><Blob><Name>a</Name><Metadata><ownerid>one</ownerid></Metadata></Blob></Blobs><NextMarker>page2</NextMarker></EnumerationResults>
        ,
        \\<EnumerationResults><Blobs><Blob><Name>b</Name></Blob><Blob><Name>c</Name></Blob></Blobs><NextMarker></NextMarker></EnumerationResults>
        ,
    };
    var scripted = ScriptedTransport.init(allocator, &bodies);
    defer scripted.deinit();

    var container = testContainer(scripted.asTransport());
    const items = try container.listBlobsWithOptions(allocator, .{ .page_size = 1 });
    defer freeBlobItems(allocator, items);

    try testing.expectEqual(@as(usize, 3), items.len);
    try testing.expectEqualStrings("a", items[0].name);
    try testing.expectEqualStrings("one", items[0].properties.metadata.get("ownerid").?);
    try testing.expectEqualStrings("b", items[1].name);
    try testing.expectEqualStrings("c", items[2].name);

    try testing.expectEqual(@as(usize, 2), scripted.urls.items.len);
    try testing.expect(std.mem.indexOf(u8, scripted.urls.items[0], "maxresults=1") != null);
    try testing.expect(std.mem.indexOf(u8, scripted.urls.items[0], "marker=") == null);
    try testing.expect(std.mem.indexOf(u8, scripted.urls.items[1], "marker=page2") != null);
}

test "listBlobs stops if the service repeats a continuation marker" {
    const allocator = testing.allocator;
    const bodies = [_][]const u8{
        \\<EnumerationResults><Blobs><Blob><Name>a</Name></Blob></Blobs><NextMarker>stuck</NextMarker></EnumerationResults>
        ,
    };
    var scripted = ScriptedTransport.init(allocator, &bodies);
    defer scripted.deinit();

    var container = testContainer(scripted.asTransport());
    const items = try container.listBlobsWithOptions(allocator, .{});
    defer freeBlobItems(allocator, items);

    // Two requests, then the repeated marker breaks the loop instead of hanging.
    try testing.expectEqual(@as(usize, 2), scripted.urls.items.len);
    try testing.expectEqual(@as(usize, 2), items.len);
}

test "listBlobs percent-decodes names marked Encoded" {
    const allocator = testing.allocator;
    const body =
        \\<EnumerationResults><Blobs>
        \\<Blob><Name Encoded="true">ns%2Fhub%2F%24Default%2Fcheckpoint%2F0</Name></Blob>
        \\<Blob><Name>plain%20name</Name></Blob>
        \\</Blobs></EnumerationResults>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    const items = try container.listBlobs(allocator);
    defer freeBlobItems(allocator, items);

    try testing.expectEqual(@as(usize, 2), items.len);
    try testing.expectEqualStrings("ns/hub/$Default/checkpoint/0", items[0].name);
    // Without the attribute the name is taken literally.
    try testing.expectEqualStrings("plain%20name", items[1].name);
}

test "listBlobs reports a malformed response instead of an empty container" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "<html>proxy error</html>");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    try testing.expectError(
        error.InvalidListBlobsResponse,
        container.listBlobs(allocator),
    );
}

test "listBlobs ignores BlobPrefix entries" {
    const allocator = testing.allocator;
    const body =
        \\<EnumerationResults><Blobs>
        \\<BlobPrefix><Name>ns/</Name></BlobPrefix>
        \\<Blob><Name>ns/hub</Name></Blob>
        \\</Blobs></EnumerationResults>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    const items = try container.listBlobs(allocator);
    defer freeBlobItems(allocator, items);

    try testing.expectEqual(@as(usize, 1), items.len);
    try testing.expectEqualStrings("ns/hub", items[0].name);
}
