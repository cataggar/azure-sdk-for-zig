///! Blob-based checkpoint store for Azure Event Hubs.
///!
///! Persists consumer progress and partition ownership in Azure Blob Storage,
///! enabling distributed event processing with load balancing.
const std = @import("std");
const core = @import("azure_core");
const blobs = @import("azure_storage_blobs");
const eventhubs = @import("azure_messaging_eventhubs");

/// Checkpoint store backed by Azure Blob Storage.
///
/// Stores checkpoints and ownership as JSON blobs:
/// - Checkpoints: `{namespace}/{hubName}/{consumerGroup}/checkpoint/{partitionId}`
/// - Ownership:   `{namespace}/{hubName}/{consumerGroup}/ownership/{partitionId}`
pub const BlobCheckpointStore = struct {
    container_client: *blobs.BlobContainerClient,
    store: eventhubs.CheckpointStore,

    pub fn init(container_client: *blobs.BlobContainerClient) BlobCheckpointStore {
        return .{
            .container_client = container_client,
            .store = .{
                .claimOwnershipFn = &claimOwnershipImpl,
                .listOwnershipFn = &listOwnershipImpl,
                .updateCheckpointFn = &updateCheckpointImpl,
                .listCheckpointsFn = &listCheckpointsImpl,
            },
        };
    }

    pub fn asCheckpointStore(self: *BlobCheckpointStore) *eventhubs.CheckpointStore {
        return &self.store;
    }

    fn claimOwnershipImpl(store: *eventhubs.CheckpointStore, allocator: std.mem.Allocator, ownership: []const eventhubs.PartitionOwnership) anyerror![]eventhubs.PartitionOwnership {
        const self: *BlobCheckpointStore = @fieldParentPtr("store", store);
        var claimed = std.ArrayList(eventhubs.PartitionOwnership).empty;
        errdefer claimed.deinit(allocator);

        for (ownership) |own| {
            const blob_path = try buildOwnershipPath(allocator, own);
            defer allocator.free(blob_path);

            var blob_client = self.container_client.getBlobClient(blob_path);
            const body = try serializeOwnership(allocator, own);
            defer allocator.free(body);

            const result = blob_client.uploadConditional(allocator, body, .{
                .content_type = "application/json",
                .if_match = own.etag,
                .if_none_match = if (own.etag == null) @as(?[]const u8, "*") else null,
            }) catch {
                continue; // Another processor won the claim
            };

            try claimed.append(allocator, .{
                .fully_qualified_namespace = own.fully_qualified_namespace,
                .event_hub_name = own.event_hub_name,
                .consumer_group = own.consumer_group,
                .partition_id = own.partition_id,
                .owner_id = own.owner_id,
                .etag = result.etag,
            });
        }

        return claimed.toOwnedSlice(allocator);
    }

    fn listOwnershipImpl(store: *eventhubs.CheckpointStore, allocator: std.mem.Allocator, fqns: []const u8, hub_name: []const u8, consumer_group: []const u8) anyerror![]eventhubs.PartitionOwnership {
        const self: *BlobCheckpointStore = @fieldParentPtr("store", store);
        const prefix = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}/ownership/", .{ fqns, hub_name, consumer_group });
        defer allocator.free(prefix);

        const blob_list = try self.container_client.listBlobs(allocator);
        defer {
            for (blob_list) |b| {
                if (b.name.len > 0) allocator.free(b.name);
                if (b.properties.content_type) |ct| allocator.free(ct);
            }
            allocator.free(blob_list);
        }

        var result = std.ArrayList(eventhubs.PartitionOwnership).empty;
        errdefer result.deinit(allocator);

        for (blob_list) |blob| {
            if (!std.mem.startsWith(u8, blob.name, prefix)) continue;

            const partition_id = blob.name[prefix.len..];
            var blob_client = self.container_client.getBlobClient(blob.name);
            const body = blob_client.download(allocator) catch continue;
            defer allocator.free(body);

            const owner_id = parseOwnerField(body) orelse continue;

            try result.append(allocator, .{
                .fully_qualified_namespace = fqns,
                .event_hub_name = hub_name,
                .consumer_group = consumer_group,
                .partition_id = partition_id,
                .owner_id = owner_id,
            });
        }

        return result.toOwnedSlice(allocator);
    }

    fn updateCheckpointImpl(store: *eventhubs.CheckpointStore, allocator: std.mem.Allocator, checkpoint: eventhubs.Checkpoint) anyerror!void {
        const self: *BlobCheckpointStore = @fieldParentPtr("store", store);
        const blob_path = try buildCheckpointPath(allocator, checkpoint);
        defer allocator.free(blob_path);

        var blob_client = self.container_client.getBlobClient(blob_path);
        const body = try serializeCheckpoint(allocator, checkpoint);
        defer allocator.free(body);

        try blob_client.upload(allocator, body, "application/json");
    }

    fn listCheckpointsImpl(store: *eventhubs.CheckpointStore, allocator: std.mem.Allocator, fqns: []const u8, hub_name: []const u8, consumer_group: []const u8) anyerror![]eventhubs.Checkpoint {
        const self: *BlobCheckpointStore = @fieldParentPtr("store", store);
        const prefix = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}/checkpoint/", .{ fqns, hub_name, consumer_group });
        defer allocator.free(prefix);

        const blob_list = try self.container_client.listBlobs(allocator);
        defer {
            for (blob_list) |b| {
                if (b.name.len > 0) allocator.free(b.name);
                if (b.properties.content_type) |ct| allocator.free(ct);
            }
            allocator.free(blob_list);
        }

        var result = std.ArrayList(eventhubs.Checkpoint).empty;
        errdefer result.deinit(allocator);

        for (blob_list) |blob| {
            if (!std.mem.startsWith(u8, blob.name, prefix)) continue;

            const partition_id = blob.name[prefix.len..];
            var blob_client = self.container_client.getBlobClient(blob.name);
            const body = blob_client.download(allocator) catch continue;
            defer allocator.free(body);

            var cp = eventhubs.Checkpoint{
                .fully_qualified_namespace = fqns,
                .event_hub_name = hub_name,
                .consumer_group = consumer_group,
                .partition_id = partition_id,
            };
            parseCheckpointFields(body, &cp);
            try result.append(allocator, cp);
        }

        return result.toOwnedSlice(allocator);
    }
};

// ─────────────────────── Helpers ───────────────────────

pub fn buildCheckpointPath(allocator: std.mem.Allocator, cp: eventhubs.Checkpoint) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}/checkpoint/{s}", .{
        cp.fully_qualified_namespace,
        cp.event_hub_name,
        cp.consumer_group,
        cp.partition_id,
    });
}

pub fn buildOwnershipPath(allocator: std.mem.Allocator, own: eventhubs.PartitionOwnership) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}/ownership/{s}", .{
        own.fully_qualified_namespace,
        own.event_hub_name,
        own.consumer_group,
        own.partition_id,
    });
}

pub fn serializeCheckpoint(allocator: std.mem.Allocator, cp: eventhubs.Checkpoint) ![]u8 {
    if (cp.offset != null and cp.sequence_number != null) {
        return std.fmt.allocPrint(allocator, "{{\"offset\":{d},\"sequenceNumber\":{d}}}", .{ cp.offset.?, cp.sequence_number.? });
    } else if (cp.offset) |offset| {
        return std.fmt.allocPrint(allocator, "{{\"offset\":{d}}}", .{offset});
    } else if (cp.sequence_number) |seq| {
        return std.fmt.allocPrint(allocator, "{{\"sequenceNumber\":{d}}}", .{seq});
    }
    return allocator.dupe(u8, "{}");
}

pub fn serializeOwnership(allocator: std.mem.Allocator, own: eventhubs.PartitionOwnership) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"ownerId\":\"{s}\"}}", .{own.owner_id});
}

/// Extract "ownerId" value from a JSON body like {"ownerId":"xyz"}.
fn parseOwnerField(body: []const u8) ?[]const u8 {
    const key = "\"ownerId\":\"";
    const start = (std.mem.indexOf(u8, body, key) orelse return null) + key.len;
    const end = std.mem.indexOfScalarPos(u8, body, start, '"') orelse return null;
    return body[start..end];
}

/// Parse offset and sequenceNumber from checkpoint JSON into the struct.
fn parseCheckpointFields(body: []const u8, cp: *eventhubs.Checkpoint) void {
    cp.offset = parseJsonInt(body, "\"offset\":");
    cp.sequence_number = parseJsonInt(body, "\"sequenceNumber\":");
}

fn parseJsonInt(body: []const u8, key: []const u8) ?i64 {
    const start = (std.mem.indexOf(u8, body, key) orelse return null) + key.len;
    var end = start;
    while (end < body.len and (body[end] == '-' or (body[end] >= '0' and body[end] <= '9'))) : (end += 1) {}
    if (start == end) return null;
    return std.fmt.parseInt(i64, body[start..end], 10) catch null;
}

// ─────────────────────── Tests ───────────────────────

test "buildCheckpointPath" {
    const allocator = std.testing.allocator;
    const path = try buildCheckpointPath(allocator, .{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
    });
    defer allocator.free(path);
    try std.testing.expectEqualStrings("ns.servicebus.windows.net/hub/$Default/checkpoint/0", path);
}

test "buildOwnershipPath" {
    const allocator = std.testing.allocator;
    const path = try buildOwnershipPath(allocator, .{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "1",
        .owner_id = "proc-1",
    });
    defer allocator.free(path);
    try std.testing.expectEqualStrings("ns.servicebus.windows.net/hub/$Default/ownership/1", path);
}

test "serializeCheckpoint both fields" {
    const allocator = std.testing.allocator;
    const json = try serializeCheckpoint(allocator, .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "cg",
        .partition_id = "0",
        .offset = 100,
        .sequence_number = 42,
    });
    defer allocator.free(json);
    try std.testing.expectEqualStrings("{\"offset\":100,\"sequenceNumber\":42}", json);
}

test "serializeOwnership" {
    const allocator = std.testing.allocator;
    const json = try serializeOwnership(allocator, .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "cg",
        .partition_id = "0",
        .owner_id = "processor-1",
    });
    defer allocator.free(json);
    try std.testing.expectEqualStrings("{\"ownerId\":\"processor-1\"}", json);
}

test "parseOwnerField" {
    const owner = parseOwnerField("{\"ownerId\":\"proc-1\"}");
    try std.testing.expectEqualStrings("proc-1", owner.?);
}

test "parseCheckpointFields" {
    var cp = eventhubs.Checkpoint{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "cg",
        .partition_id = "0",
    };
    parseCheckpointFields("{\"offset\":100,\"sequenceNumber\":42}", &cp);
    try std.testing.expectEqual(@as(i64, 100), cp.offset.?);
    try std.testing.expectEqual(@as(i64, 42), cp.sequence_number.?);
}

test "BlobCheckpointStore updateCheckpoint" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();

    const identity = @import("azure_identity");
    var cred_mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"t","expires_in":3600}
    );
    defer cred_mock.deinit();
    var cred = identity.ClientSecretCredential.init(allocator, cred_mock.asTransport(), "t", "c", "s");

    var container = blobs.BlobContainerClient.init(
        "https://myaccount.blob.core.windows.net",
        "checkpoints",
        cred.asCredential(),
        mock.asTransport(),
        .{},
    );

    var store = BlobCheckpointStore.init(&container);
    try store.asCheckpointStore().updateCheckpoint(allocator, .{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .offset = 100,
        .sequence_number = 42,
    });

    // Verify the upload went to the correct path.
    try std.testing.expect(std.mem.indexOf(u8, mock.last_url.?, "ns.servicebus.windows.net/hub/$Default/checkpoint/0") != null);
}
