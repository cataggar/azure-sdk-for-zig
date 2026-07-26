//! Typed SDK responses and their ownership rules.
//!
//! Allocating responses will own an arena and expose one `deinit` operation.
//! Response slices remain valid until that operation. HTTP failures are values
//! in `*Result` variants; Zig errors are reserved for local failures.

const std = @import("std");
const core = @import("azure_sdk_core");
const errors = @import("errors.zig");

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

/// Allocator-owned raw headers, including duplicate values in wire order.
pub const RawHeaders = struct {
    entries: std.ArrayList(Header) = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RawHeaders {
        return .{ .allocator = allocator };
    }

    pub fn fromResponse(allocator: std.mem.Allocator, response: *const core.http.Response) !RawHeaders {
        var result = init(allocator);
        errdefer result.deinit();
        if (response.response_headers.entries.items.len > 0) {
            for (response.response_headers.entries.items) |header| {
                try result.append(header.name, header.value);
            }
        } else {
            var iterator = response.headers.iterator();
            while (iterator.next()) |header| {
                try result.append(header.key_ptr.*, header.value_ptr.*);
            }
        }
        return result;
    }

    pub fn append(self: *RawHeaders, name: []const u8, value: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        try self.entries.append(self.allocator, .{ .name = owned_name, .value = owned_value });
    }

    pub fn getFirst(self: *const RawHeaders, name: []const u8) ?[]const u8 {
        for (self.entries.items) |header| {
            if (std.ascii.eqlIgnoreCase(name, header.name)) return header.value;
        }
        return null;
    }

    pub fn deinit(self: *RawHeaders) void {
        for (self.entries.items) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.entries.deinit(self.allocator);
    }
};

pub const ResponseMetadata = struct {
    status: u16,
    headers: RawHeaders,
    body: ?[]const u8 = null,

    pub fn fromResponse(allocator: std.mem.Allocator, response: *const core.http.Response) !ResponseMetadata {
        return .{
            .status = response.status_code,
            .headers = try RawHeaders.fromResponse(allocator, response),
        };
    }

    pub fn deinit(self: *ResponseMetadata) void {
        self.headers.deinit();
        if (self.body) |body| self.headers.allocator.free(body);
    }
};

/// Owns generated response allocations and raw headers in one arena.
pub fn SdkResponse(comptime T: type) type {
    return struct {
        value: T,
        status: u16,
        headers: RawHeaders,
        body: ?[]const u8 = null,
        arena: *std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.allocator.destroy(self.arena);
            self.* = undefined;
        }
    };
}

/// Frequently used Tables response headers. Slices are owned by the enclosing
/// response and remain valid until its `deinit`.
pub const EntityHeaders = struct {
    request_id: ?[]const u8 = null,
    client_request_id: ?[]const u8 = null,
    date: ?[]const u8 = null,
    api_version: ?[]const u8 = null,
    content_type: ?[]const u8 = null,
    preference_applied: ?[]const u8 = null,
};

/// OData entity annotations emitted by full and minimal metadata responses.
/// No-metadata responses leave every field null.
pub const EntityMetadata = struct {
    metadata: ?[]const u8 = null,
    type_name: ?[]const u8 = null,
    id: ?[]const u8 = null,
    etag: ?[]const u8 = null,
    edit_link: ?[]const u8 = null,
};

/// An arena-owned decoded entity response.
pub fn EntityResponse(comptime T: type) type {
    return struct {
        value: T,
        etag: []const u8,
        status: u16,
        headers: EntityHeaders,
        metadata: EntityMetadata,
        raw_headers: RawHeaders,
        arena: *std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.allocator.destroy(self.arena);
            self.* = undefined;
        }
    };
}

/// Arena-owned response from an entity deletion.
pub const DeleteEntityResponse = struct {
    status: u16,
    headers: EntityHeaders,
    raw_headers: RawHeaders,
    arena: *std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *DeleteEntityResponse) void {
        self.arena.deinit();
        self.allocator.destroy(self.arena);
        self.* = undefined;
    }
};

/// Arena-owned response from an entity update or upsert.
pub const MutationEntityResponse = struct {
    etag: []const u8,
    status: u16,
    headers: EntityHeaders,
    raw_headers: RawHeaders,
    arena: *std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *MutationEntityResponse) void {
        self.arena.deinit();
        self.allocator.destroy(self.arena);
        self.* = undefined;
    }
};

/// A typed operation outcome. Local failures remain in the outer Zig error
/// union; non-successful HTTP responses are `failure` values.
pub fn TableResult(comptime T: type) type {
    return union(enum) {
        success: T,
        failure: errors.TableError,

        const Self = @This();

        /// Releases the active branch, including a payload's `deinit` method
        /// when one is declared at comptime.
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            switch (self.*) {
                .success => |*value| deinitPayload(T, allocator, value),
                .failure => |*table_error| table_error.deinit(),
            }
            self.* = undefined;
        }

        /// Consumes a result for simple methods which intentionally do not
        /// retain structured service errors. `failure` never becomes a
        /// success-shaped fallback value.
        pub fn unwrap(self: Self) error{TableServiceError}!T {
            return switch (self) {
                .success => |value| value,
                .failure => |table_error| {
                    var owned_error = table_error;
                    owned_error.deinit();
                    return error.TableServiceError;
                },
            };
        }

        /// Builds a failure branch from a non-2xx response. This boundary
        /// prevents an HTTP failure from being represented as `success`.
        pub fn fromHttpFailure(
            allocator: std.mem.Allocator,
            status: u16,
            content_type: ?[]const u8,
            request_id: ?[]const u8,
            operation_index: ?usize,
            body: []const u8,
        ) !Self {
            return .{
                .failure = try errors.TableError.fromResponse(
                    allocator,
                    status,
                    content_type,
                    request_id,
                    operation_index,
                    body,
                ),
            };
        }
    };
}

/// Consumes a result for a future `getEntity` simple method.
pub fn unwrapGetEntity(comptime T: type, result: TableResult(T)) error{GetEntityFailed}!T {
    return switch (result) {
        .success => |value| value,
        .failure => |table_error| {
            var owned_error = table_error;
            owned_error.deinit();
            return error.GetEntityFailed;
        },
    };
}

/// Consumes a result for a future `createEntity` simple method.
pub fn unwrapCreateEntity(comptime T: type, result: TableResult(T)) error{CreateEntityFailed}!T {
    return switch (result) {
        .success => |value| value,
        .failure => |table_error| {
            var owned_error = table_error;
            owned_error.deinit();
            return error.CreateEntityFailed;
        },
    };
}

pub fn unwrapCreateTable(comptime T: type, result: TableResult(T)) error{CreateTableFailed}!T {
    return switch (result) {
        .success => |value| value,
        .failure => |table_error| {
            var owned_error = table_error;
            owned_error.deinit();
            return error.CreateTableFailed;
        },
    };
}

pub fn unwrapDeleteTable(comptime T: type, result: TableResult(T)) error{DeleteTableFailed}!T {
    return switch (result) {
        .success => |value| value,
        .failure => |table_error| {
            var owned_error = table_error;
            owned_error.deinit();
            return error.DeleteTableFailed;
        },
    };
}

pub fn unwrapGetAccessPolicy(comptime T: type, result: TableResult(T)) error{GetAccessPolicyFailed}!T {
    return switch (result) {
        .success => |value| value,
        .failure => |table_error| {
            var owned_error = table_error;
            owned_error.deinit();
            return error.GetAccessPolicyFailed;
        },
    };
}

pub fn unwrapSetAccessPolicy(comptime T: type, result: TableResult(T)) error{SetAccessPolicyFailed}!T {
    return switch (result) {
        .success => |value| value,
        .failure => |table_error| {
            var owned_error = table_error;
            owned_error.deinit();
            return error.SetAccessPolicyFailed;
        },
    };
}

pub fn unwrapListTables(comptime T: type, result: TableResult(T)) error{ListTablesFailed}!T {
    return switch (result) {
        .success => |value| value,
        .failure => |table_error| {
            var owned_error = table_error;
            owned_error.deinit();
            return error.ListTablesFailed;
        },
    };
}

pub fn unwrapQueryEntities(comptime T: type, result: TableResult(T)) error{QueryEntitiesFailed}!T {
    return switch (result) {
        .success => |value| value,
        .failure => |table_error| {
            var owned_error = table_error;
            owned_error.deinit();
            return error.QueryEntitiesFailed;
        },
    };
}

fn deinitPayload(comptime T: type, allocator: std.mem.Allocator, value: *T) void {
    switch (@typeInfo(T)) {
        .@"struct", .@"union", .@"enum", .@"opaque" => {},
        else => return,
    }
    if (!@hasDecl(T, "deinit")) return;

    const function_info = @typeInfo(@TypeOf(T.deinit)).@"fn";
    if (function_info.params.len == 1) {
        value.deinit();
    } else if (function_info.params.len == 2) {
        value.deinit(allocator);
    } else {
        @compileError("TableResult payload deinit must accept self or self and allocator");
    }
}

test "TableResult cleanup detects payload deinit at comptime" {
    const OwnedPayload = struct {
        bytes: []u8,

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.bytes);
        }
    };

    var result: TableResult(OwnedPayload) = .{
        .success = .{ .bytes = try std.testing.allocator.dupe(u8, "owned") },
    };
    result.deinit(std.testing.allocator);
}

test "TableResult cleanup frees error branch and unwrap never succeeds on failure" {
    var table_error = try errors.TableError.init(
        std.testing.allocator,
        404,
        errors.TableErrorCode.table_not_found,
        null,
        null,
        null,
    );
    var result: TableResult(u8) = .{ .failure = table_error };
    try std.testing.expectError(error.TableServiceError, result.unwrap());

    table_error = try errors.TableError.init(
        std.testing.allocator,
        404,
        errors.TableErrorCode.table_not_found,
        null,
        null,
        null,
    );
    result = .{ .failure = table_error };
    try std.testing.expectError(error.GetEntityFailed, unwrapGetEntity(u8, result));
}

test "non-2xx response result cannot become successful payload" {
    var result = try TableResult(u8).fromHttpFailure(std.testing.allocator, 404, "application/json", "request-id", null,
        \\{"code":"EntityNotFound","message":"missing"}
    );
    defer result.deinit(std.testing.allocator);

    switch (result) {
        .failure => |table_error| {
            try std.testing.expectEqual(@as(u16, 404), table_error.status);
            try std.testing.expectEqualStrings(errors.TableErrorCode.entity_not_found, table_error.code);
        },
        .success => return error.TestUnexpectedResult,
    }
}
