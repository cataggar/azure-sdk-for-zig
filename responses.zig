//! Typed SDK responses and their ownership rules.
//!
//! Allocating responses will own an arena and expose one `deinit` operation.
//! Response slices remain valid until that operation. HTTP failures are values
//! in `*Result` variants; Zig errors are reserved for local failures.

const std = @import("std");
const core = @import("azure_sdk_core");

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

    pub fn fromResponse(allocator: std.mem.Allocator, response: *const core.http.Response) !ResponseMetadata {
        return .{
            .status = response.status_code,
            .headers = try RawHeaders.fromResponse(allocator, response),
        };
    }

    pub fn deinit(self: *ResponseMetadata) void {
        self.headers.deinit();
    }
};

/// Owns generated response allocations and raw headers in one arena.
pub fn SdkResponse(comptime T: type) type {
    return struct {
        value: T,
        status: u16,
        headers: RawHeaders,
        arena: *std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *@This()) void {
            self.arena.deinit();
            self.allocator.destroy(self.arena);
            self.* = undefined;
        }
    };
}
