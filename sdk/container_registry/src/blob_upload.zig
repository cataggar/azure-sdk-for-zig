const std = @import("std");
const core = @import("azure_core");
const digest_mod = @import("digest.zig");
const service_error = @import("service_error.zig");

pub const default_chunk_size: usize = 4 * 1024 * 1024;
pub const max_chunk_size: usize = 100 * 1024 * 1024;
const max_location_length: usize = 8 * 1024;
const max_upload_uuid_length: usize = 1024;
const max_error_body_length: usize = 64 * 1024;

pub const BlobUploadOptions = struct {
    /// Maximum bytes buffered and sent in one PATCH request. Valid values are
    /// `1..max_chunk_size`.
    chunk_size: usize = default_chunk_size,
    /// Retries after an initial retryable failure.
    max_retries: u32 = 3,
    cancellation: ?*const core.http.CancellationToken = null,
};

pub const BlobUploadResult = struct {
    allocator: std.mem.Allocator,
    digest: []u8,
    location: []u8,
    size: u64,

    pub fn deinit(self: *BlobUploadResult) void {
        self.allocator.free(self.digest);
        self.allocator.free(self.location);
        self.* = undefined;
    }
};

pub const BlobUploadResponse = service_error.Result(BlobUploadResult);

pub const UploadContext = struct {
    allocator: std.mem.Allocator,
    pipeline: *core.pipeline.HttpPipeline,
    endpoint: []const u8,
    api_version: []const u8,
    repository_name: []const u8,
};

pub fn upload(
    context: UploadContext,
    reader: *std.Io.Reader,
    options: BlobUploadOptions,
) !BlobUploadResponse {
    try validateOptions(options);
    try checkCancelled(options.cancellation);

    const buffer = try context.allocator.alloc(u8, options.chunk_size);
    defer context.allocator.free(buffer);

    var start_result = try startUpload(context, options);
    switch (start_result) {
        .err => |failure| return .{ .err = failure },
        .ok => |*session_value| {
            var session = session_value.*;
            start_result = undefined;
            defer session.deinit();

            var digest = digest_mod.Sha256Digest{};
            var total: u64 = 0;
            while (true) {
                checkCancelled(options.cancellation) catch |err| {
                    return failAfterCleanup(context, &session, err);
                };
                const count = readChunk(
                    reader,
                    buffer,
                    options.cancellation,
                ) catch |err| {
                    return failAfterCleanup(context, &session, err);
                };
                if (count == 0) break;
                if (count > std.math.maxInt(u64) - total)
                    return failAfterCleanup(
                        context,
                        &session,
                        error.BlobUploadTooLarge,
                    );

                const chunk_result = uploadChunk(
                    context,
                    &session,
                    buffer[0..count],
                    total,
                    &digest,
                    options,
                ) catch |err| {
                    return failAfterCleanup(context, &session, err);
                };
                switch (chunk_result) {
                    .ok => {},
                    .err => |failure| {
                        return serviceFailureAfterCleanup(
                            context,
                            &session,
                            failure,
                        );
                    },
                }
                total += count;
            }

            const computed_digest = digest.final();
            const completion_result = completeUpload(
                context,
                &session,
                &computed_digest,
                total,
                options,
            ) catch |err| {
                return failAfterCleanup(context, &session, err);
            };
            switch (completion_result) {
                .err => |failure| {
                    return serviceFailureAfterCleanup(
                        context,
                        &session,
                        failure,
                    );
                },
                .ok => |completion| {
                    errdefer context.allocator.free(completion.location);
                    const owned_digest = try context.allocator.dupe(
                        u8,
                        &computed_digest,
                    );
                    errdefer context.allocator.free(owned_digest);
                    return .{ .ok = .{
                        .allocator = context.allocator,
                        .digest = owned_digest,
                        .location = completion.location,
                        .size = total,
                    } };
                },
            }
        },
    }
}

const Session = struct {
    allocator: std.mem.Allocator,
    location: []u8,
    upload_uuid: []u8,
    confirmed_offset: u64 = 0,

    fn deinit(self: *Session) void {
        self.allocator.free(self.location);
        self.allocator.free(self.upload_uuid);
        self.* = undefined;
    }

    fn replaceLocation(self: *Session, location: []u8) void {
        self.allocator.free(self.location);
        self.location = location;
    }
};

const Completion = struct {
    location: []u8,
};

fn Step(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: service_error.ServiceError,
    };
}

fn validateOptions(options: BlobUploadOptions) !void {
    if (options.chunk_size == 0) return error.InvalidBlobUploadChunkSize;
    if (options.chunk_size > max_chunk_size)
        return error.InvalidBlobUploadChunkSize;
}

fn checkCancelled(cancellation: ?*const core.http.CancellationToken) !void {
    if (cancellation) |token| {
        if (token.isCancelled()) return error.OperationCancelled;
    }
}

fn readChunk(
    reader: *std.Io.Reader,
    buffer: []u8,
    cancellation: ?*const core.http.CancellationToken,
) !usize {
    var total: usize = 0;
    while (total < buffer.len) {
        try checkCancelled(cancellation);
        const count = try reader.readSliceShort(buffer[total..]);
        try checkCancelled(cancellation);
        if (count == 0) break;
        total += count;
    }
    return total;
}

fn startUpload(
    context: UploadContext,
    options: BlobUploadOptions,
) !Step(Session) {
    const url = try buildStartUrl(context);
    defer context.allocator.free(url);
    var request = core.http.Request.init(context.allocator, .POST, url);
    defer request.deinit();
    request.retryable = false;
    request.redirect_policy = .not_allowed;
    try request.setHeader("Content-Length", "0");

    var operation = context.pipeline.open(
        &request,
        .{ .cancellation = options.cancellation },
    ) catch |err| {
        if (request.transport_started) return error.UploadStartOutcomeUnknown;
        return err;
    };
    defer operation.deinit();
    if (operation.status_code != 202) {
        if (operation.isSuccess()) return error.UnexpectedResponseStatus;
        return .{ .err = try serviceErrorFromOperation(context, operation) };
    }

    const raw_location = try requiredHeader(
        context.allocator,
        operation,
        "Location",
        error.MissingUploadLocation,
    );
    const range = try requiredHeader(
        context.allocator,
        operation,
        "Range",
        error.MissingUploadRange,
    );
    const upload_uuid = try requiredHeader(
        context.allocator,
        operation,
        "Docker-Upload-UUID",
        error.MissingUploadUuid,
    );
    if (upload_uuid.len > max_upload_uuid_length)
        return error.UploadUuidTooLong;
    try validateInitialRange(range);
    const location = try resolveUploadLocation(
        context.allocator,
        context.endpoint,
        url,
        raw_location,
    );
    errdefer context.allocator.free(location);
    const owned_uuid = try context.allocator.dupe(u8, upload_uuid);
    errdefer context.allocator.free(owned_uuid);
    try operation.finish();
    return .{ .ok = .{
        .allocator = context.allocator,
        .location = location,
        .upload_uuid = owned_uuid,
    } };
}

fn uploadChunk(
    context: UploadContext,
    session: *Session,
    chunk: []const u8,
    chunk_start: u64,
    digest: *digest_mod.Sha256Digest,
    options: BlobUploadOptions,
) !Step(void) {
    if (session.confirmed_offset != chunk_start)
        return error.ServerUploadOffsetDiverged;
    const chunk_length: u64 = @intCast(chunk.len);
    const chunk_end = std.math.add(u64, chunk_start, chunk_length) catch
        return error.BlobUploadTooLarge;
    var cursor: usize = 0;
    var retry_count: u32 = 0;

    while (cursor < chunk.len) {
        try checkCancelled(options.cancellation);
        const attempt_start = session.confirmed_offset;
        const attempt = chunk[cursor..];
        const attempt_end = std.math.add(
            u64,
            attempt_start,
            @as(u64, @intCast(attempt.len)),
        ) catch return error.BlobUploadTooLarge;
        const digest_snapshot = digest.*;
        const cursor_snapshot = cursor;
        digest.update(attempt);

        const request_url = try buildContinuationUrl(
            context,
            session.location,
            null,
        );
        defer context.allocator.free(request_url);
        var request = core.http.Request.init(
            context.allocator,
            .PATCH,
            request_url,
        );
        defer request.deinit();
        request.retryable = false;
        request.redirect_policy = .not_allowed;
        try request.setHeader("Content-Type", "application/octet-stream");
        var content_length_buffer: [32]u8 = undefined;
        const content_length = try std.fmt.bufPrint(
            &content_length_buffer,
            "{d}",
            .{attempt.len},
        );
        try request.setHeader("Content-Length", content_length);
        var content_range_buffer: [64]u8 = undefined;
        const content_range = try std.fmt.bufPrint(
            &content_range_buffer,
            "{d}-{d}",
            .{ attempt_start, attempt_end - 1 },
        );
        try request.setHeader("Content-Range", content_range);
        var replayable = core.http.ReplayableBytes.init(attempt);

        var operation = context.pipeline.open(
            &request,
            .{
                .body = replayable.body(),
                .cancellation = options.cancellation,
            },
        ) catch |err| {
            digest.* = digest_snapshot;
            cursor = cursor_snapshot;
            if (err == error.OperationCancelled) return err;
            if (!request.transport_started) {
                if (!isRetryablePreTransportError(err) or
                    retry_count >= options.max_retries)
                {
                    return err;
                }
                retry_count += 1;
                continue;
            }

            const recovery = try recoverUploadStatus(
                context,
                session,
                attempt_end,
                false,
                options,
            );
            switch (recovery) {
                .err => |failure| return .{ .err = failure },
                .lost => return error.UploadSessionLost,
                .offset => |offset| {
                    const progressed = try applyRecoveredOffset(
                        session,
                        chunk,
                        chunk_start,
                        &cursor,
                        digest,
                        offset,
                    );
                    if (session.confirmed_offset == chunk_end)
                        return .{ .ok = {} };
                    if (progressed) {
                        retry_count = 0;
                    } else {
                        if (retry_count >= options.max_retries)
                            return error.BlobUploadRetryExhausted;
                        retry_count += 1;
                    }
                    continue;
                },
            }
        };
        defer operation.deinit();

        if (operation.status_code == 202) {
            const response_offset = try responseUploadOffset(
                context.allocator,
                operation,
                false,
            );
            if (response_offset != attempt_end)
                return error.ServerUploadOffsetDiverged;
            try validateUploadUuid(
                context.allocator,
                operation,
                session.upload_uuid,
            );
            const next_location = try responseUploadLocation(
                context,
                operation,
                request_url,
            );
            errdefer context.allocator.free(next_location);
            try operation.finish();
            session.replaceLocation(next_location);
            session.confirmed_offset = response_offset;
            cursor = chunk.len;
            return .{ .ok = {} };
        }

        digest.* = digest_snapshot;
        cursor = cursor_snapshot;
        if (operation.status_code == 416) {
            const range = try requiredHeader(
                context.allocator,
                operation,
                "Range",
                error.MissingUploadRange,
            );
            const response_offset = try parseStatusRange(
                range,
                session.confirmed_offset,
                attempt_end,
                false,
            );
            try validateUploadUuid(
                context.allocator,
                operation,
                session.upload_uuid,
            );
            const next_location = try responseUploadLocation(
                context,
                operation,
                request_url,
            );
            errdefer context.allocator.free(next_location);
            try operation.finish();
            session.replaceLocation(next_location);
            const progressed = try applyRecoveredOffset(
                session,
                chunk,
                chunk_start,
                &cursor,
                digest,
                response_offset,
            );
            if (session.confirmed_offset == chunk_end)
                return .{ .ok = {} };
            if (progressed) {
                retry_count = 0;
            } else {
                if (retry_count >= options.max_retries)
                    return error.BlobUploadRetryExhausted;
                retry_count += 1;
            }
            continue;
        }
        if (isRetryableStatus(operation.status_code)) {
            operation.abort();
            const recovery = try recoverUploadStatus(
                context,
                session,
                attempt_end,
                false,
                options,
            );
            switch (recovery) {
                .err => |failure| return .{ .err = failure },
                .lost => return error.UploadSessionLost,
                .offset => |offset| {
                    const progressed = try applyRecoveredOffset(
                        session,
                        chunk,
                        chunk_start,
                        &cursor,
                        digest,
                        offset,
                    );
                    if (session.confirmed_offset == chunk_end)
                        return .{ .ok = {} };
                    if (progressed) {
                        retry_count = 0;
                    } else {
                        if (retry_count >= options.max_retries)
                            return error.BlobUploadRetryExhausted;
                        retry_count += 1;
                    }
                    continue;
                },
            }
        }
        if (operation.isSuccess()) return error.UnexpectedResponseStatus;
        return .{ .err = try serviceErrorFromOperation(context, operation) };
    }
    return .{ .ok = {} };
}

fn applyRecoveredOffset(
    session: *Session,
    chunk: []const u8,
    chunk_start: u64,
    cursor: *usize,
    digest: *digest_mod.Sha256Digest,
    recovered_offset: u64,
) !bool {
    const current_offset = std.math.add(
        u64,
        chunk_start,
        @as(u64, @intCast(cursor.*)),
    ) catch return error.BlobUploadTooLarge;
    const chunk_end = std.math.add(
        u64,
        chunk_start,
        @as(u64, @intCast(chunk.len)),
    ) catch return error.BlobUploadTooLarge;
    if (recovered_offset < current_offset or recovered_offset > chunk_end)
        return error.ServerUploadOffsetDiverged;
    const delta: usize = @intCast(recovered_offset - current_offset);
    if (delta > 0) {
        digest.update(chunk[cursor.* .. cursor.* + delta]);
        cursor.* += delta;
    }
    session.confirmed_offset = recovered_offset;
    return delta > 0;
}

const Recovery = union(enum) {
    offset: u64,
    lost,
    err: service_error.ServiceError,
};

fn recoverUploadStatus(
    context: UploadContext,
    session: *Session,
    attempted_end: u64,
    completion: bool,
    options: BlobUploadOptions,
) !Recovery {
    var retry_count: u32 = 0;
    while (true) {
        try checkCancelled(options.cancellation);
        const request_url = try buildContinuationUrl(
            context,
            session.location,
            null,
        );
        defer context.allocator.free(request_url);
        var request = core.http.Request.init(context.allocator, .GET, request_url);
        defer request.deinit();
        request.redirect_policy = .not_allowed;

        var operation = context.pipeline.open(
            &request,
            .{ .cancellation = options.cancellation },
        ) catch |err| {
            if (err == error.OperationCancelled) return err;
            if (retry_count >= options.max_retries) return err;
            retry_count += 1;
            continue;
        };
        defer operation.deinit();
        if (operation.status_code == 204) {
            try validateUploadUuid(
                context.allocator,
                operation,
                session.upload_uuid,
            );
            const range = try requiredHeader(
                context.allocator,
                operation,
                "Range",
                error.MissingUploadRange,
            );
            const offset = try parseStatusRange(
                range,
                session.confirmed_offset,
                attempted_end,
                completion,
            );
            if (offset < session.confirmed_offset or offset > attempted_end)
                return error.ServerUploadOffsetDiverged;
            if (try optionalHeader(
                context.allocator,
                operation,
                "Location",
            )) |raw_location| {
                const next_location = try resolveUploadLocation(
                    context.allocator,
                    context.endpoint,
                    request_url,
                    raw_location,
                );
                errdefer context.allocator.free(next_location);
                try operation.finish();
                session.replaceLocation(next_location);
            } else {
                try operation.finish();
            }
            return .{ .offset = offset };
        }
        if (operation.status_code == 404) {
            try operation.finish();
            return .lost;
        }
        if (isRetryableStatus(operation.status_code) and
            retry_count < options.max_retries)
        {
            retry_count += 1;
            continue;
        }
        if (operation.isSuccess()) return error.UnexpectedResponseStatus;
        return .{ .err = try serviceErrorFromOperation(context, operation) };
    }
}

fn completeUpload(
    context: UploadContext,
    session: *Session,
    digest: []const u8,
    total: u64,
    options: BlobUploadOptions,
) !Step(Completion) {
    if (session.confirmed_offset != total)
        return error.ServerUploadOffsetDiverged;
    var retry_count: u32 = 0;
    while (true) {
        try checkCancelled(options.cancellation);
        const request_url = try buildContinuationUrl(
            context,
            session.location,
            digest,
        );
        defer context.allocator.free(request_url);
        var request = core.http.Request.init(context.allocator, .PUT, request_url);
        defer request.deinit();
        request.retryable = false;
        request.redirect_policy = .not_allowed;
        try request.setHeader("Content-Length", "0");

        var operation = context.pipeline.open(
            &request,
            .{ .cancellation = options.cancellation },
        ) catch |err| {
            if (err == error.OperationCancelled) return err;
            if (!request.transport_started) {
                if (!isRetryablePreTransportError(err) or
                    retry_count >= options.max_retries)
                {
                    return err;
                }
                retry_count += 1;
                continue;
            }
            const recovery = try recoverUploadStatus(
                context,
                session,
                total,
                true,
                options,
            );
            switch (recovery) {
                .err => |failure| return .{ .err = failure },
                .offset => |offset| {
                    if (offset != total)
                        return error.ServerUploadOffsetDiverged;
                    if (retry_count >= options.max_retries)
                        return error.BlobUploadRetryExhausted;
                    retry_count += 1;
                    continue;
                },
                .lost => return verifyCompletedBlob(
                    context,
                    digest,
                    total,
                    options,
                ),
            }
        };
        defer operation.deinit();
        if (operation.status_code == 201) {
            const returned_digest = try requiredHeader(
                context.allocator,
                operation,
                "Docker-Content-Digest",
                error.MissingDockerContentDigest,
            );
            try digest_mod.validateSha256Digest(returned_digest);
            if (!(try digest_mod.sha256DigestsEqual(digest, returned_digest)))
                return error.DigestMismatch;
            const range = try requiredHeader(
                context.allocator,
                operation,
                "Range",
                error.MissingUploadRange,
            );
            try validateCompletionRange(range, total);
            const final_location = try responseUploadLocation(
                context,
                operation,
                request_url,
            );
            errdefer context.allocator.free(final_location);
            try operation.finish();
            return .{ .ok = .{
                .location = final_location,
            } };
        }
        if (isRetryableStatus(operation.status_code)) {
            operation.abort();
            const recovery = try recoverUploadStatus(
                context,
                session,
                total,
                true,
                options,
            );
            switch (recovery) {
                .err => |failure| return .{ .err = failure },
                .offset => |offset| {
                    if (offset != total)
                        return error.ServerUploadOffsetDiverged;
                    if (retry_count >= options.max_retries)
                        return error.BlobUploadRetryExhausted;
                    retry_count += 1;
                    continue;
                },
                .lost => return verifyCompletedBlob(
                    context,
                    digest,
                    total,
                    options,
                ),
            }
        }
        if (operation.isSuccess()) return error.UnexpectedResponseStatus;
        return .{ .err = try serviceErrorFromOperation(context, operation) };
    }
}

fn verifyCompletedBlob(
    context: UploadContext,
    digest: []const u8,
    total: u64,
    options: BlobUploadOptions,
) !Step(Completion) {
    const url = try buildBlobUrl(context, digest);
    var owns_url = true;
    defer if (owns_url) context.allocator.free(url);
    var request = core.http.Request.init(context.allocator, .HEAD, url);
    defer request.deinit();
    request.redirect_policy = .not_allowed;

    var operation = try context.pipeline.open(
        &request,
        .{ .cancellation = options.cancellation },
    );
    defer operation.deinit();
    if (operation.status_code == 200) {
        const returned_digest = try requiredHeader(
            context.allocator,
            operation,
            "Docker-Content-Digest",
            error.MissingDockerContentDigest,
        );
        try digest_mod.validateSha256Digest(returned_digest);
        if (!(try digest_mod.sha256DigestsEqual(digest, returned_digest)))
            return error.DigestMismatch;
        const content_length = try requiredHeader(
            context.allocator,
            operation,
            "Content-Length",
            error.MissingContentLength,
        );
        const returned_size = std.fmt.parseInt(u64, content_length, 10) catch
            return error.InvalidContentLength;
        if (returned_size != total) return error.ContentLengthMismatch;
        try operation.finish();
        owns_url = false;
        return .{ .ok = .{
            .location = url,
        } };
    }
    if (operation.status_code == 404)
        return error.CompletionOutcomeUnknown;
    if (operation.isSuccess()) return error.UnexpectedResponseStatus;
    return .{ .err = try serviceErrorFromOperation(context, operation) };
}

fn cleanupUpload(context: UploadContext, session: *Session) !void {
    const request_url = try buildContinuationUrl(
        context,
        session.location,
        null,
    );
    defer context.allocator.free(request_url);
    var request = core.http.Request.init(context.allocator, .DELETE, request_url);
    defer request.deinit();
    request.redirect_policy = .not_allowed;
    try request.setHeader("Content-Length", "0");

    var operation = try context.pipeline.open(&request, .{});
    defer operation.deinit();
    if (operation.status_code != 204 and operation.status_code != 404)
        return error.UploadCleanupFailed;
    try operation.finish();
}

fn failAfterCleanup(
    context: UploadContext,
    session: *Session,
    failure: anyerror,
) anyerror!BlobUploadResponse {
    cleanupUpload(context, session) catch |cleanup_error| return cleanup_error;
    return failure;
}

fn serviceFailureAfterCleanup(
    context: UploadContext,
    session: *Session,
    failure_value: service_error.ServiceError,
) !BlobUploadResponse {
    var failure = failure_value;
    cleanupUpload(context, session) catch |cleanup_error| {
        failure.deinit();
        return cleanup_error;
    };
    return .{ .err = failure };
}

fn buildStartUrl(context: UploadContext) ![]u8 {
    const repository = try core.url.encodeRepositoryName(
        context.allocator,
        context.repository_name,
    );
    defer context.allocator.free(repository);
    const api_version = try core.url.percentEncode(
        context.allocator,
        context.api_version,
    );
    defer context.allocator.free(api_version);
    return std.fmt.allocPrint(
        context.allocator,
        "{s}/v2/{s}/blobs/uploads/?api-version={s}",
        .{ context.endpoint, repository, api_version },
    );
}

fn buildBlobUrl(context: UploadContext, digest: []const u8) ![]u8 {
    const repository = try core.url.encodeRepositoryName(
        context.allocator,
        context.repository_name,
    );
    defer context.allocator.free(repository);
    const encoded_digest = try core.url.encodePathSegment(
        context.allocator,
        digest,
    );
    defer context.allocator.free(encoded_digest);
    const api_version = try core.url.percentEncode(
        context.allocator,
        context.api_version,
    );
    defer context.allocator.free(api_version);
    return std.fmt.allocPrint(
        context.allocator,
        "{s}/v2/{s}/blobs/{s}?api-version={s}",
        .{
            context.endpoint,
            repository,
            encoded_digest,
            api_version,
        },
    );
}

fn buildContinuationUrl(
    context: UploadContext,
    location: []const u8,
    digest: ?[]const u8,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(context.allocator);
    try output.appendSlice(context.allocator, location);
    var separator: []const u8 = if (std.mem.indexOfScalar(u8, location, '?') == null)
        "?"
    else
        "&";
    if (!hasQueryParameter(location, "api-version")) {
        const encoded = try core.url.percentEncode(
            context.allocator,
            context.api_version,
        );
        defer context.allocator.free(encoded);
        try output.print(
            context.allocator,
            "{s}api-version={s}",
            .{ separator, encoded },
        );
        separator = "&";
    }
    if (digest) |value| {
        if (hasQueryParameter(location, "digest"))
            return error.AmbiguousUploadLocation;
        const encoded = try core.url.percentEncode(context.allocator, value);
        defer context.allocator.free(encoded);
        try output.print(
            context.allocator,
            "{s}digest={s}",
            .{ separator, encoded },
        );
    }
    return output.toOwnedSlice(context.allocator);
}

fn hasQueryParameter(url: []const u8, name: []const u8) bool {
    const query_start = std.mem.indexOfScalar(u8, url, '?') orelse return false;
    var parameters = std.mem.splitScalar(u8, url[query_start + 1 ..], '&');
    while (parameters.next()) |parameter| {
        const end = std.mem.indexOfScalar(u8, parameter, '=') orelse
            parameter.len;
        const key = parameter[0..end];
        if (std.ascii.eqlIgnoreCase(key, name)) return true;
        if (std.ascii.eqlIgnoreCase(name, "api-version") and
            std.ascii.eqlIgnoreCase(key, "api%2dversion"))
        {
            return true;
        }
    }
    return false;
}

fn resolveUploadLocation(
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    request_url: []const u8,
    location: []const u8,
) ![]u8 {
    if (location.len > max_location_length)
        return error.UploadLocationTooLong;
    const resolved = try core.url.resolveUrl(allocator, request_url, location);
    errdefer allocator.free(resolved);
    if (resolved.len > max_location_length)
        return error.UploadLocationTooLong;
    try core.url.validateHttpsUrl(resolved, &.{});
    if (!(try core.url.sameOrigin(endpoint, resolved)))
        return error.UntrustedUploadLocation;
    return resolved;
}

fn responseUploadLocation(
    context: UploadContext,
    operation: *const core.http.HttpOperation,
    request_url: []const u8,
) ![]u8 {
    const raw_location = try requiredHeader(
        context.allocator,
        operation,
        "Location",
        error.MissingUploadLocation,
    );
    return resolveUploadLocation(
        context.allocator,
        context.endpoint,
        request_url,
        raw_location,
    );
}

fn responseUploadOffset(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
    zero_is_empty: bool,
) !u64 {
    const range = try requiredHeader(
        allocator,
        operation,
        "Range",
        error.MissingUploadRange,
    );
    return parseRange(range, zero_is_empty);
}

fn validateUploadUuid(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
    expected: []const u8,
) !void {
    const actual = try requiredHeader(
        allocator,
        operation,
        "Docker-Upload-UUID",
        error.MissingUploadUuid,
    );
    if (actual.len > max_upload_uuid_length)
        return error.UploadUuidTooLong;
    if (!std.mem.eql(u8, expected, actual))
        return error.UploadUuidChanged;
}

fn validateInitialRange(value: []const u8) !void {
    if (try parseRange(value, true) != 0)
        return error.ServerUploadOffsetDiverged;
}

fn validateCompletionRange(value: []const u8, total: u64) !void {
    const offset = try parseRange(value, total == 0);
    if (offset != total) return error.ServerUploadOffsetDiverged;
}

fn parseStatusRange(
    value: []const u8,
    confirmed_offset: u64,
    attempted_end: u64,
    completion: bool,
) !u64 {
    const trimmed = std.mem.trim(u8, value, " \t");
    const raw = if (std.ascii.startsWithIgnoreCase(trimmed, "bytes="))
        trimmed["bytes=".len..]
    else
        trimmed;
    if (std.mem.eql(u8, raw, "0-0") and confirmed_offset == 0) {
        if (completion and attempted_end == 0) return 0;
        return error.AmbiguousUploadRange;
    }
    return parseRange(value, false);
}

fn parseRange(value: []const u8, zero_is_empty: bool) !u64 {
    const trimmed = std.mem.trim(u8, value, " \t");
    const raw = if (std.ascii.startsWithIgnoreCase(trimmed, "bytes="))
        trimmed["bytes=".len..]
    else
        trimmed;
    const separator = std.mem.indexOfScalar(u8, raw, '-') orelse
        return error.InvalidUploadRange;
    if (separator == 0 or separator == raw.len - 1 or
        std.mem.indexOfScalar(u8, raw[separator + 1 ..], '-') != null)
    {
        return error.InvalidUploadRange;
    }
    const start = std.fmt.parseInt(u64, raw[0..separator], 10) catch
        return error.InvalidUploadRange;
    const end = std.fmt.parseInt(u64, raw[separator + 1 ..], 10) catch
        return error.InvalidUploadRange;
    if (start != 0 or end < start) return error.InvalidUploadRange;
    if (zero_is_empty and end == 0) return 0;
    return std.math.add(u64, end, 1) catch error.InvalidUploadRange;
}

fn requiredHeader(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
    name: []const u8,
    missing_error: anyerror,
) ![]const u8 {
    const values = try operation.getHeaderValues(allocator, name);
    defer allocator.free(values);
    if (values.len == 0) return missing_error;
    if (values.len != 1) return error.AmbiguousResponseHeader;
    if (values[0].len == 0) return error.InvalidResponseHeader;
    return values[0];
}

fn optionalHeader(
    allocator: std.mem.Allocator,
    operation: *const core.http.HttpOperation,
    name: []const u8,
) !?[]const u8 {
    const values = try operation.getHeaderValues(allocator, name);
    defer allocator.free(values);
    if (values.len == 0) return null;
    if (values.len != 1) return error.AmbiguousResponseHeader;
    if (values[0].len == 0) return error.InvalidResponseHeader;
    return values[0];
}

fn serviceErrorFromOperation(
    context: UploadContext,
    operation: *core.http.HttpOperation,
) !service_error.ServiceError {
    const reader = try operation.reader();
    const body = reader.allocRemaining(
        context.allocator,
        .limited(max_error_body_length),
    ) catch |err| switch (err) {
        error.ReadFailed => return operation.bodyError() orelse error.ReadFailed,
        error.StreamTooLong => return error.ErrorResponseTooLarge,
        else => |other| return other,
    };
    var response = core.http.Response{
        .status_code = operation.status_code,
        .headers = std.StringHashMap([]const u8).init(context.allocator),
        .body = body,
        .allocator = context.allocator,
    };
    defer response.deinit();
    var failure = try service_error.ServiceError.fromResponse(
        context.allocator,
        &response,
    );
    errdefer failure.deinit();
    try operation.finish();
    return failure;
}

fn isRetryableStatus(status: u16) bool {
    return status == 408 or status == 429 or status == 500 or
        status == 502 or status == 503 or status == 504;
}

fn isRetryablePreTransportError(failure: anyerror) bool {
    return switch (failure) {
        error.OutOfMemory,
        error.OperationCancelled,
        error.StreamingRequestUnsupported,
        error.RequestBodyNotReplayable,
        error.InvalidHttpHeaderName,
        error.InvalidHttpHeaderValue,
        error.InvalidUrl,
        error.HttpsRequired,
        error.UnexpectedHost,
        error.UntrustedUploadLocation,
        => false,
        else => true,
    };
}
