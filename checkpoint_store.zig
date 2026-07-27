//! Blob-based checkpoint store for Azure Event Hubs.
//!
//! State lives in blob **metadata**, not in the blob body, matching the Go and
//! Rust Event Hubs SDKs so processors written in different languages can share
//! one container:
//!
//! - Checkpoints: `{namespace}/{hub}/{group}/checkpoint/{partition}` with
//!   `sequencenumber` and `offset` metadata.
//! - Ownership: `{namespace}/{hub}/{group}/ownership/{partition}` with
//!   `ownerid` metadata, plus the blob's own ETag and Last-Modified.
//!
//! Blob bodies are always empty.

const std = @import("std");
const core = @import("azure_sdk_core");
const blobs = @import("azure_sdk_storage_blobs");
const eventhubs = @import("checkpoint.zig");

/// Metadata key holding the checkpoint sequence number.
pub const sequence_number_key = "sequencenumber";
/// Metadata key holding the opaque checkpoint offset.
pub const offset_key = "offset";
/// Metadata key holding the owning processor's identifier.
pub const owner_id_key = "ownerid";

/// Checkpoint store backed by Azure Blob Storage.
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

    /// Claims each partition with a compare-and-swap on the ownership blob.
    ///
    /// A processor holding an ETag renews with `If-Match`; a processor claiming
    /// an unowned partition creates the blob with `If-None-Match: *`. Losing
    /// the race is normal, so those partitions are dropped from the result
    /// instead of failing the batch.
    fn claimOwnershipImpl(
        store: *eventhubs.CheckpointStore,
        allocator: std.mem.Allocator,
        ownership: []const eventhubs.PartitionOwnership,
    ) anyerror![]eventhubs.PartitionOwnership {
        const self: *BlobCheckpointStore = @fieldParentPtr("store", store);

        var claimed: std.ArrayList(eventhubs.PartitionOwnership) = .empty;
        errdefer {
            for (claimed.items) |item| item.deinit(allocator);
            claimed.deinit(allocator);
        }

        for (ownership) |own| {
            const blob_path = try buildOwnershipPath(allocator, own);
            defer allocator.free(blob_path);

            var blob_client = self.container_client.getBlobClient(blob_path);
            const metadata = [_]blobs.MetadataEntry{
                .{ .name = owner_id_key, .value = own.owner_id },
            };

            var result = if (own.etag) |etag|
                try blob_client.setMetadataResult(allocator, &metadata, .{ .if_match = etag })
            else
                try blob_client.uploadConditionalResult(allocator, "", .{
                    .metadata = &metadata,
                    .if_none_match = "*",
                });
            defer result.deinit(allocator);

            const written = switch (result) {
                .ok => |value| value,
                .err => |azure_error| {
                    if (isClaimConflict(azure_error.status_code)) continue;
                    return error.ClaimOwnershipFailed;
                },
            };

            var entry = try cloneOwnership(allocator, own);
            errdefer entry.deinit(allocator);
            if (written.etag) |etag| entry.etag = try allocator.dupe(u8, etag);
            entry.last_modified_time = if (written.last_modified) |value|
                parseRfc1123(value)
            else
                null;

            try claimed.append(allocator, entry);
        }

        return claimed.toOwnedSlice(allocator);
    }

    fn listOwnershipImpl(
        store: *eventhubs.CheckpointStore,
        allocator: std.mem.Allocator,
        fqns: []const u8,
        hub_name: []const u8,
        consumer_group: []const u8,
    ) anyerror![]eventhubs.PartitionOwnership {
        const self: *BlobCheckpointStore = @fieldParentPtr("store", store);

        const prefix = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}/ownership/",
            .{ fqns, hub_name, consumer_group },
        );
        defer allocator.free(prefix);

        const blob_list = try self.container_client.listBlobsWithOptions(allocator, .{
            .prefix = prefix,
            .include_metadata = true,
        });
        defer blobs.freeBlobItems(allocator, blob_list);

        var result: std.ArrayList(eventhubs.PartitionOwnership) = .empty;
        errdefer {
            for (result.items) |item| item.deinit(allocator);
            result.deinit(allocator);
        }

        for (blob_list) |blob| {
            const partition_id = partitionIdOf(blob.name) orelse continue;

            var entry = eventhubs.PartitionOwnership{
                .fully_qualified_namespace = try allocator.dupe(u8, fqns),
                .event_hub_name = undefined,
                .consumer_group = undefined,
                .partition_id = undefined,
                // A missing `ownerid` means the partition was relinquished;
                // the service omits metadata keys whose value is empty.
                .owner_id = undefined,
            };
            errdefer entry.deinit(allocator);
            entry.event_hub_name = try allocator.dupe(u8, hub_name);
            entry.consumer_group = try allocator.dupe(u8, consumer_group);
            entry.partition_id = try allocator.dupe(u8, partition_id);
            entry.owner_id = try allocator.dupe(u8, blob.properties.metadata.get(owner_id_key) orelse "");

            if (blob.properties.etag) |etag| entry.etag = try allocator.dupe(u8, etag);
            if (blob.properties.last_modified) |value| {
                entry.last_modified_time = parseRfc1123(value);
            }

            try result.append(allocator, entry);
        }

        return result.toOwnedSlice(allocator);
    }

    /// Writes the checkpoint into blob metadata, creating the blob if it does
    /// not exist yet. Ownership is assumed, so no precondition is applied.
    fn updateCheckpointImpl(
        store: *eventhubs.CheckpointStore,
        allocator: std.mem.Allocator,
        checkpoint: eventhubs.Checkpoint,
    ) anyerror!void {
        const self: *BlobCheckpointStore = @fieldParentPtr("store", store);

        const blob_path = try buildCheckpointPath(allocator, checkpoint);
        defer allocator.free(blob_path);

        var sequence_buffer: [24]u8 = undefined;
        var metadata: [2]blobs.MetadataEntry = undefined;
        var count: usize = 0;
        if (checkpoint.sequence_number) |sequence_number| {
            metadata[count] = .{
                .name = sequence_number_key,
                .value = try std.fmt.bufPrint(&sequence_buffer, "{d}", .{sequence_number}),
            };
            count += 1;
        }
        if (checkpoint.offset) |offset| {
            metadata[count] = .{ .name = offset_key, .value = offset };
            count += 1;
        }

        var blob_client = self.container_client.getBlobClient(blob_path);

        var set_result = try blob_client.setMetadataResult(allocator, metadata[0..count], .{});
        defer set_result.deinit(allocator);
        switch (set_result) {
            .ok => return,
            .err => |azure_error| {
                if (azure_error.status_code != 404) return error.UpdateCheckpointFailed;
            },
        }

        var upload_result = try blob_client.uploadConditionalResult(allocator, "", .{
            .metadata = metadata[0..count],
        });
        defer upload_result.deinit(allocator);
        if (upload_result == .err) return error.UpdateCheckpointFailed;
    }

    fn listCheckpointsImpl(
        store: *eventhubs.CheckpointStore,
        allocator: std.mem.Allocator,
        fqns: []const u8,
        hub_name: []const u8,
        consumer_group: []const u8,
    ) anyerror![]eventhubs.Checkpoint {
        const self: *BlobCheckpointStore = @fieldParentPtr("store", store);

        const prefix = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/{s}/checkpoint/",
            .{ fqns, hub_name, consumer_group },
        );
        defer allocator.free(prefix);

        const blob_list = try self.container_client.listBlobsWithOptions(allocator, .{
            .prefix = prefix,
            .include_metadata = true,
        });
        defer blobs.freeBlobItems(allocator, blob_list);

        var result: std.ArrayList(eventhubs.Checkpoint) = .empty;
        errdefer {
            for (result.items) |item| item.deinit(allocator);
            result.deinit(allocator);
        }

        for (blob_list) |blob| {
            const partition_id = partitionIdOf(blob.name) orelse continue;

            var entry = eventhubs.Checkpoint{
                .fully_qualified_namespace = try allocator.dupe(u8, fqns),
                .event_hub_name = undefined,
                .consumer_group = undefined,
                .partition_id = undefined,
            };
            errdefer entry.deinit(allocator);
            entry.event_hub_name = try allocator.dupe(u8, hub_name);
            entry.consumer_group = try allocator.dupe(u8, consumer_group);
            entry.partition_id = try allocator.dupe(u8, partition_id);

            if (blob.properties.metadata.get(offset_key)) |offset| {
                entry.offset = try allocator.dupe(u8, offset);
            }
            if (blob.properties.metadata.get(sequence_number_key)) |value| {
                entry.sequence_number = std.fmt.parseInt(i64, value, 10) catch null;
            }

            try result.append(allocator, entry);
        }

        return result.toOwnedSlice(allocator);
    }
};

// ─────────────────────── Helpers ───────────────────────

/// A claim lost to another processor. 412 is a failed precondition on renewal,
/// 409 is another processor having created the blob first.
fn isClaimConflict(status_code: u16) bool {
    return status_code == 412 or status_code == 409;
}

fn cloneOwnership(
    allocator: std.mem.Allocator,
    own: eventhubs.PartitionOwnership,
) !eventhubs.PartitionOwnership {
    var entry = eventhubs.PartitionOwnership{
        .fully_qualified_namespace = try allocator.dupe(u8, own.fully_qualified_namespace),
        .event_hub_name = undefined,
        .consumer_group = undefined,
        .partition_id = undefined,
        .owner_id = undefined,
    };
    errdefer entry.deinit(allocator);
    entry.event_hub_name = try allocator.dupe(u8, own.event_hub_name);
    entry.consumer_group = try allocator.dupe(u8, own.consumer_group);
    entry.partition_id = try allocator.dupe(u8, own.partition_id);
    entry.owner_id = try allocator.dupe(u8, own.owner_id);
    return entry;
}

/// The partition id is the final path segment of a checkpoint or ownership
/// blob name, matching Go's `[^/]+?$`.
fn partitionIdOf(blob_name: []const u8) ?[]const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, blob_name, '/') orelse return null;
    const partition_id = blob_name[slash + 1 ..];
    return if (partition_id.len == 0) null else partition_id;
}

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

const month_names = [_][]const u8{
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
};

/// Parse an HTTP-date such as `Mon, 27 Jul 2026 12:34:56 GMT` into Unix
/// seconds. Blob `Last-Modified` always uses this format, and load balancing
/// needs it as a number to expire stale ownership.
pub fn parseRfc1123(value: []const u8) ?i64 {
    const comma = std.mem.indexOfScalar(u8, value, ',') orelse return null;
    const rest = std.mem.trim(u8, value[comma + 1 ..], " ");
    if (rest.len < 20) return null;

    var fields = std.mem.tokenizeScalar(u8, rest, ' ');
    const day = std.fmt.parseInt(u8, fields.next() orelse return null, 10) catch return null;
    const month_name = fields.next() orelse return null;
    const year = std.fmt.parseInt(u16, fields.next() orelse return null, 10) catch return null;
    const time = fields.next() orelse return null;

    var month: u8 = 0;
    for (month_names, 0..) |name, index| {
        if (std.mem.eql(u8, name, month_name)) {
            month = @intCast(index + 1);
            break;
        }
    }
    if (month == 0) return null;
    if (day < 1 or day > 31) return null;

    var time_fields = std.mem.splitScalar(u8, time, ':');
    const hour = std.fmt.parseInt(u8, time_fields.next() orelse return null, 10) catch return null;
    const minute = std.fmt.parseInt(u8, time_fields.next() orelse return null, 10) catch return null;
    const second = std.fmt.parseInt(u8, time_fields.next() orelse return null, 10) catch return null;
    if (hour > 23 or minute > 59 or second > 60) return null;

    const days = daysFromCivil(year, month, day);
    return days * std.time.s_per_day +
        @as(i64, hour) * 3600 + @as(i64, minute) * 60 + @as(i64, second);
}

/// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's
/// `days_from_civil`).
fn daysFromCivil(year: u16, month: u8, day: u8) i64 {
    var y: i64 = year;
    const m: i64 = month;
    const d: i64 = day;
    y -= if (m <= 2) 1 else 0;
    const era = @divFloor(y, 400);
    const yoe = y - era * 400;
    const doy = @divFloor(153 * (m + (if (m > 2) @as(i64, -3) else 9)) + 2, 5) + d - 1;
    const doe = yoe * 365 + @divFloor(yoe, 4) - @divFloor(yoe, 100) + doy;
    return era * 146097 + doe - 719468;
}

// ─────────────────────── Tests ───────────────────────

const testing = std.testing;

test {
    _ = @import("checkpoint.zig");
}

fn testContainer(transport: *core.http.HttpTransport) blobs.BlobContainerClient {
    return blobs.BlobContainerClient.initWithPipeline(
        .{ .policies = &.{}, .transport_impl = transport },
        .{
            .endpoint = "https://myaccount.blob.core.windows.net",
            .container_name = "checkpoints",
        },
    );
}

test "buildCheckpointPath" {
    const allocator = testing.allocator;
    const path = try buildCheckpointPath(allocator, .{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
    });
    defer allocator.free(path);
    try testing.expectEqualStrings("ns.servicebus.windows.net/hub/$Default/checkpoint/0", path);
}

test "buildOwnershipPath" {
    const allocator = testing.allocator;
    const path = try buildOwnershipPath(allocator, .{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "1",
        .owner_id = "proc-1",
    });
    defer allocator.free(path);
    try testing.expectEqualStrings("ns.servicebus.windows.net/hub/$Default/ownership/1", path);
}

test "partitionIdOf takes the final path segment" {
    try testing.expectEqualStrings("0", partitionIdOf("ns/hub/$Default/checkpoint/0").?);
    try testing.expectEqualStrings("12", partitionIdOf("ns/hub/cg/ownership/12").?);
    try testing.expect(partitionIdOf("ns/hub/cg/ownership/") == null);
    try testing.expect(partitionIdOf("nopath") == null);
}

test "parseRfc1123 converts an HTTP-date to Unix seconds" {
    try testing.expectEqual(@as(i64, 0), parseRfc1123("Thu, 01 Jan 1970 00:00:00 GMT").?);
    try testing.expectEqual(@as(i64, 1000000000), parseRfc1123("Sun, 09 Sep 2001 01:46:40 GMT").?);
    // A leap day, to exercise the civil-date conversion.
    try testing.expectEqual(@as(i64, 1582934400), parseRfc1123("Sat, 29 Feb 2020 00:00:00 GMT").?);
    try testing.expect(parseRfc1123("not a date") == null);
    try testing.expect(parseRfc1123("Mon, 27 Xxx 2026 00:00:00 GMT") == null);
}

test "updateCheckpoint writes sequencenumber and offset metadata" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    try store.asCheckpointStore().updateCheckpoint(allocator, .{
        .fully_qualified_namespace = "ns.servicebus.windows.net",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .offset = "100",
        .sequence_number = 42,
    });

    try testing.expectEqualStrings("42", mock.last_headers.get("x-ms-meta-sequencenumber").?);
    try testing.expectEqualStrings("100", mock.last_headers.get("x-ms-meta-offset").?);
    try testing.expect(std.mem.endsWith(
        u8,
        mock.last_url.?,
        "/ns.servicebus.windows.net/hub/%24Default/checkpoint/0?comp=metadata",
    ));
    // The body stays empty; state lives entirely in metadata.
    try testing.expect(mock.last_body == null or mock.last_body.?.len == 0);
}

test "updateCheckpoint keeps a non-numeric offset intact" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    try store.asCheckpointStore().updateCheckpoint(allocator, .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .offset = "3298423984:2:9",
        .sequence_number = 1,
    });

    try testing.expectEqualStrings("3298423984:2:9", mock.last_headers.get("x-ms-meta-offset").?);
}

test "updateCheckpoint creates the blob when setMetadata reports it is missing" {
    const allocator = testing.allocator;
    var scripted = ScriptedTransport.init(allocator, &.{
        .{ .status = 404, .body = "" },
        .{ .status = 201, .body = "" },
    });
    defer scripted.deinit();

    var container = testContainer(scripted.asTransport());
    var store = BlobCheckpointStore.init(&container);

    try store.asCheckpointStore().updateCheckpoint(allocator, .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .offset = "100",
        .sequence_number = 42,
    });

    try testing.expectEqual(@as(usize, 2), scripted.requests.items.len);
    try testing.expect(std.mem.endsWith(u8, scripted.requests.items[0].url, "?comp=metadata"));
    // The fallback is a plain PUT of an empty block blob carrying the metadata.
    try testing.expect(!std.mem.endsWith(u8, scripted.requests.items[1].url, "?comp=metadata"));
    try testing.expectEqualStrings("BlockBlob", scripted.requests.items[1].headers.get("x-ms-blob-type").?);
    try testing.expectEqualStrings("42", scripted.requests.items[1].headers.get("x-ms-meta-sequencenumber").?);
}

test "updateCheckpoint surfaces a non-404 failure" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 403, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    try testing.expectError(error.UpdateCheckpointFailed, store.asCheckpointStore().updateCheckpoint(allocator, .{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .sequence_number = 1,
    }));
}

test "listCheckpoints reads state from metadata" {
    const allocator = testing.allocator;
    const body =
        \\<EnumerationResults><Blobs>
        \\<Blob><Name>ns/hub/$Default/checkpoint/0</Name><Metadata><sequencenumber>42</sequencenumber><offset>100</offset></Metadata></Blob>
        \\<Blob><Name>ns/hub/$Default/checkpoint/1</Name><Metadata><sequencenumber>7</sequencenumber><offset>3298423984:2:9</offset></Metadata></Blob>
        \\</Blobs></EnumerationResults>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    const checkpoints = try store.asCheckpointStore().listCheckpoints(
        allocator,
        "ns",
        "hub",
        "$Default",
    );
    defer eventhubs.freeCheckpoints(allocator, checkpoints);

    try testing.expect(std.mem.indexOf(u8, mock.last_url.?, "include=metadata") != null);

    try testing.expectEqual(@as(usize, 2), checkpoints.len);
    try testing.expectEqualStrings("0", checkpoints[0].partition_id);
    try testing.expectEqualStrings("100", checkpoints[0].offset.?);
    try testing.expectEqual(@as(i64, 42), checkpoints[0].sequence_number.?);
    try testing.expectEqualStrings("1", checkpoints[1].partition_id);
    try testing.expectEqualStrings("3298423984:2:9", checkpoints[1].offset.?);
    try testing.expectEqual(@as(i64, 7), checkpoints[1].sequence_number.?);
    try testing.expectEqualStrings("ns", checkpoints[0].fully_qualified_namespace);
    try testing.expectEqualStrings("hub", checkpoints[0].event_hub_name);
    try testing.expectEqualStrings("$Default", checkpoints[0].consumer_group);
}

test "listOwnership returns etag and last modified for expiry and CAS" {
    const allocator = testing.allocator;
    const body =
        \\<EnumerationResults><Blobs>
        \\<Blob><Name>ns/hub/$Default/ownership/0</Name><Properties><Etag>"0x1"</Etag><Last-Modified>Sun, 09 Sep 2001 01:46:40 GMT</Last-Modified></Properties><Metadata><ownerid>processor-1</ownerid></Metadata></Blob>
        \\<Blob><Name>ns/hub/$Default/ownership/1</Name><Properties><Etag>"0x2"</Etag><Last-Modified>Sun, 09 Sep 2001 01:46:40 GMT</Last-Modified></Properties><Metadata></Metadata></Blob>
        \\</Blobs></EnumerationResults>
    ;
    var mock = core.http.MockTransport.init(allocator, 200, body);
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    const ownerships = try store.asCheckpointStore().listOwnership(allocator, "ns", "hub", "$Default");
    defer eventhubs.freeOwnerships(allocator, ownerships);

    try testing.expectEqual(@as(usize, 2), ownerships.len);
    try testing.expectEqualStrings("processor-1", ownerships[0].owner_id);
    try testing.expectEqualStrings("\"0x1\"", ownerships[0].etag.?);
    try testing.expectEqual(@as(i64, 1000000000), ownerships[0].last_modified_time.?);
    try testing.expect(!ownerships[0].isRelinquished());

    // A blob with no `ownerid` was relinquished by its previous owner.
    try testing.expectEqualStrings("", ownerships[1].owner_id);
    try testing.expect(ownerships[1].isRelinquished());
    try testing.expectEqualStrings("\"0x2\"", ownerships[1].etag.?);
}

test "claimOwnership creates an unowned blob with If-None-Match" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 201, "");
    defer mock.deinit();
    mock.response_headers_list = &.{
        .{ .name = "ETag", .value = "\"0x1\"" },
        .{ .name = "Last-Modified", .value = "Sun, 09 Sep 2001 01:46:40 GMT" },
    };

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    const claimed = try store.asCheckpointStore().claimOwnership(allocator, &.{.{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .owner_id = "processor-1",
    }});
    defer eventhubs.freeOwnerships(allocator, claimed);

    try testing.expectEqualStrings("*", mock.last_headers.get("If-None-Match").?);
    try testing.expect(mock.last_headers.get("If-Match") == null);
    try testing.expectEqualStrings("processor-1", mock.last_headers.get("x-ms-meta-ownerid").?);

    try testing.expectEqual(@as(usize, 1), claimed.len);
    try testing.expectEqualStrings("\"0x1\"", claimed[0].etag.?);
    try testing.expectEqual(@as(i64, 1000000000), claimed[0].last_modified_time.?);
}

test "claimOwnership renews an existing claim with If-Match" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();
    mock.response_headers_list = &.{.{ .name = "ETag", .value = "\"0x2\"" }};

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    const claimed = try store.asCheckpointStore().claimOwnership(allocator, &.{.{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .owner_id = "processor-1",
        .etag = "\"0x1\"",
    }});
    defer eventhubs.freeOwnerships(allocator, claimed);

    try testing.expectEqualStrings("\"0x1\"", mock.last_headers.get("If-Match").?);
    try testing.expect(mock.last_headers.get("If-None-Match") == null);
    try testing.expect(std.mem.endsWith(u8, mock.last_url.?, "?comp=metadata"));
    try testing.expectEqualStrings("\"0x2\"", claimed[0].etag.?);
}

test "claimOwnership drops partitions lost to another processor" {
    const allocator = testing.allocator;
    var scripted = ScriptedTransport.init(allocator, &.{
        .{ .status = 412, .body = "" },
        .{ .status = 200, .body = "", .etag = "\"0x9\"" },
    });
    defer scripted.deinit();

    var container = testContainer(scripted.asTransport());
    var store = BlobCheckpointStore.init(&container);

    const claimed = try store.asCheckpointStore().claimOwnership(allocator, &.{
        .{
            .fully_qualified_namespace = "ns",
            .event_hub_name = "hub",
            .consumer_group = "$Default",
            .partition_id = "0",
            .owner_id = "processor-1",
            .etag = "\"stale\"",
        },
        .{
            .fully_qualified_namespace = "ns",
            .event_hub_name = "hub",
            .consumer_group = "$Default",
            .partition_id = "1",
            .owner_id = "processor-1",
            .etag = "\"fresh\"",
        },
    });
    defer eventhubs.freeOwnerships(allocator, claimed);

    // Losing a claim is expected, not an error.
    try testing.expectEqual(@as(usize, 1), claimed.len);
    try testing.expectEqualStrings("1", claimed[0].partition_id);
    try testing.expectEqualStrings("\"0x9\"", claimed[0].etag.?);
}

test "claimOwnership treats a lost creation race as a conflict" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 409, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    const claimed = try store.asCheckpointStore().claimOwnership(allocator, &.{.{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .owner_id = "processor-1",
    }});
    defer eventhubs.freeOwnerships(allocator, claimed);

    try testing.expectEqual(@as(usize, 0), claimed.len);
}

test "claimOwnership reports a genuine failure" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 403, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    try testing.expectError(error.ClaimOwnershipFailed, store.asCheckpointStore().claimOwnership(allocator, &.{.{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .owner_id = "processor-1",
    }}));
}

test "claimOwnership relinquishes a partition with an empty owner id" {
    const allocator = testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "");
    defer mock.deinit();

    var container = testContainer(mock.asTransport());
    var store = BlobCheckpointStore.init(&container);

    const claimed = try store.asCheckpointStore().claimOwnership(allocator, &.{.{
        .fully_qualified_namespace = "ns",
        .event_hub_name = "hub",
        .consumer_group = "$Default",
        .partition_id = "0",
        .owner_id = "",
        .etag = "\"0x1\"",
    }});
    defer eventhubs.freeOwnerships(allocator, claimed);

    try testing.expectEqualStrings("", mock.last_headers.get("x-ms-meta-ownerid").?);
    try testing.expect(claimed[0].isRelinquished());
}

/// Transport that replays a scripted sequence of responses and records each
/// request, so multi-request flows can be asserted on.
const ScriptedTransport = struct {
    const Reply = struct {
        status: u16,
        body: []const u8,
        etag: ?[]const u8 = null,
    };

    const Captured = struct {
        url: []u8,
        headers: std.StringHashMap([]const u8),

        fn deinit(self: *Captured, allocator: std.mem.Allocator) void {
            allocator.free(self.url);
            var iterator = self.headers.iterator();
            while (iterator.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
            self.headers.deinit();
        }
    };

    allocator: std.mem.Allocator,
    replies: []const Reply,
    index: usize = 0,
    requests: std.ArrayList(Captured) = .empty,
    transport: core.http.HttpTransport = .{ .sendFn = &sendImpl },

    fn init(allocator: std.mem.Allocator, replies: []const Reply) ScriptedTransport {
        return .{ .allocator = allocator, .replies = replies };
    }

    fn deinit(self: *ScriptedTransport) void {
        for (self.requests.items) |*captured| captured.deinit(self.allocator);
        self.requests.deinit(self.allocator);
    }

    fn asTransport(self: *ScriptedTransport) *core.http.HttpTransport {
        return &self.transport;
    }

    fn sendImpl(
        transport: *core.http.HttpTransport,
        request: *core.http.Request,
    ) anyerror!core.http.Response {
        const self: *ScriptedTransport = @alignCast(@fieldParentPtr("transport", transport));

        var captured = Captured{
            .url = try self.allocator.dupe(u8, request.url),
            .headers = std.StringHashMap([]const u8).init(self.allocator),
        };
        var iterator = request.headers.iterator();
        while (iterator.next()) |entry| {
            try captured.headers.put(
                try self.allocator.dupe(u8, entry.key_ptr.*),
                try self.allocator.dupe(u8, entry.value_ptr.*),
            );
        }
        try self.requests.append(self.allocator, captured);

        const reply = self.replies[@min(self.index, self.replies.len - 1)];
        self.index += 1;

        var headers = core.http.ResponseHeaders.init(self.allocator);
        if (reply.etag) |etag| try headers.append("ETag", etag);

        return .{
            .status_code = reply.status,
            .headers = std.StringHashMap([]const u8).init(self.allocator),
            .body = try self.allocator.dupe(u8, reply.body),
            .allocator = self.allocator,
            .response_headers = headers,
        };
    }
};
