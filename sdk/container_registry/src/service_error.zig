const std = @import("std");
const core = @import("azure_sdk_core");

pub const ServiceErrorInfo = struct {
    allocator: std.mem.Allocator,
    code: ?[]u8,
    message: ?[]u8,
    detail: ?[]u8,

    pub fn deinit(self: *ServiceErrorInfo) void {
        if (self.code) |value| self.allocator.free(value);
        if (self.message) |value| self.allocator.free(value);
        if (self.detail) |value| self.allocator.free(value);
        self.* = undefined;
    }
};

pub const ServiceError = struct {
    allocator: std.mem.Allocator,
    status_code: u16,
    code: ?[]u8,
    message: ?[]u8,
    detail: ?[]u8,
    errors: []ServiceErrorInfo,
    malformed: bool,
    raw_body: ?[]u8,

    pub fn fromResponse(
        allocator: std.mem.Allocator,
        response: *const core.http.Response,
    ) !ServiceError {
        const parsed = std.json.parseFromSlice(
            std.json.Value,
            allocator,
            response.body,
            .{},
        ) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return malformedError(
                allocator,
                response.status_code,
                response.body,
            ),
        };
        defer parsed.deinit();
        if (parsed.value != .object) {
            return malformedError(allocator, response.status_code, response.body);
        }
        const error_values = parsed.value.object.get("errors") orelse
            return malformedError(allocator, response.status_code, response.body);
        if (error_values != .array) {
            return malformedError(allocator, response.status_code, response.body);
        }

        var errors: std.ArrayList(ServiceErrorInfo) = .empty;
        errdefer {
            for (errors.items) |*item| item.deinit();
            errors.deinit(allocator);
        }
        for (error_values.array.items) |value| {
            var item = parseErrorInfo(allocator, value) catch |err| switch (err) {
                error.OutOfMemory => return err,
                error.InvalidContainerRegistryError => {
                    const malformed = try malformedError(
                        allocator,
                        response.status_code,
                        response.body,
                    );
                    for (errors.items) |*existing| existing.deinit();
                    errors.deinit(allocator);
                    return malformed;
                },
            };
            errdefer item.deinit();
            try errors.append(allocator, item);
        }
        const owned_errors = try errors.toOwnedSlice(allocator);
        errdefer {
            for (owned_errors) |*item| item.deinit();
            allocator.free(owned_errors);
        }
        const first = if (owned_errors.len > 0) &owned_errors[0] else null;
        const code = if (first) |item| if (item.code) |value|
            try allocator.dupe(u8, value)
        else
            null else null;
        errdefer if (code) |value| allocator.free(value);
        const message = if (first) |item| if (item.message) |value|
            try allocator.dupe(u8, value)
        else
            null else null;
        errdefer if (message) |value| allocator.free(value);
        const detail = if (first) |item| if (item.detail) |value|
            try allocator.dupe(u8, value)
        else
            null else null;
        return .{
            .allocator = allocator,
            .status_code = response.status_code,
            .code = code,
            .message = message,
            .detail = detail,
            .errors = owned_errors,
            .malformed = false,
            .raw_body = null,
        };
    }

    pub fn deinit(self: *ServiceError) void {
        if (self.code) |value| self.allocator.free(value);
        if (self.message) |value| self.allocator.free(value);
        if (self.detail) |value| self.allocator.free(value);
        for (self.errors) |*item| item.deinit();
        self.allocator.free(self.errors);
        if (self.raw_body) |body| self.allocator.free(body);
        self.* = undefined;
    }

    pub fn isNotFound(self: ServiceError) bool {
        return self.status_code == 404;
    }

    pub fn isCode(self: ServiceError, code: []const u8) bool {
        for (self.errors) |item| {
            if (item.code) |value| {
                if (std.ascii.eqlIgnoreCase(value, code)) return true;
            }
        }
        return false;
    }

    pub fn format(self: ServiceError, writer: anytype) !void {
        try writer.print("ContainerRegistryServiceError(status={d}", .{self.status_code});
        if (self.code) |value| try writer.print(", code={s}", .{value});
        if (self.message) |value| try writer.print(", message={s}", .{value});
        if (self.malformed) try writer.writeAll(", malformed=true");
        try writer.writeAll(")");
    }
};

pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: ServiceError,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            switch (self.*) {
                .ok => |*value| {
                    if (comptime hasDeinit(T)) value.deinit();
                },
                .err => |*service_error| service_error.deinit(),
            }
            self.* = undefined;
        }

        pub fn isOk(self: Self) bool {
            return self == .ok;
        }
    };
}

fn parseErrorInfo(
    allocator: std.mem.Allocator,
    value: std.json.Value,
) (error{ OutOfMemory, InvalidContainerRegistryError })!ServiceErrorInfo {
    if (value != .object) return error.InvalidContainerRegistryError;
    const code = try optionalOwnedString(allocator, value.object, "code");
    errdefer if (code) |field| allocator.free(field);
    const message = try optionalOwnedString(allocator, value.object, "message");
    errdefer if (message) |field| allocator.free(field);
    const detail = if (value.object.get("detail")) |field|
        try stringifyDetail(allocator, field)
    else
        null;
    return .{
        .allocator = allocator,
        .code = code,
        .message = message,
        .detail = detail,
    };
}

fn optionalOwnedString(
    allocator: std.mem.Allocator,
    object: std.json.ObjectMap,
    field: []const u8,
) (error{ OutOfMemory, InvalidContainerRegistryError })!?[]u8 {
    const value = object.get(field) orelse return null;
    return switch (value) {
        .null => null,
        .string => |string| try allocator.dupe(u8, string),
        else => error.InvalidContainerRegistryError,
    };
}

fn stringifyDetail(
    allocator: std.mem.Allocator,
    value: std.json.Value,
) (error{OutOfMemory})!?[]u8 {
    if (value == .null) return null;
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    var stringify = std.json.Stringify{ .writer = &output.writer };
    stringify.write(value) catch return error.OutOfMemory;
    return @as(?[]u8, try output.toOwnedSlice());
}

fn malformedError(
    allocator: std.mem.Allocator,
    status_code: u16,
    body: []const u8,
) !ServiceError {
    const raw_body = try allocator.dupe(u8, body);
    errdefer allocator.free(raw_body);
    return .{
        .allocator = allocator,
        .status_code = status_code,
        .code = null,
        .message = null,
        .detail = null,
        .errors = try allocator.alloc(ServiceErrorInfo, 0),
        .malformed = true,
        .raw_body = raw_body,
    };
}

fn hasDeinit(comptime T: type) bool {
    if (@typeInfo(T) != .@"struct") return false;
    if (!@hasDecl(T, "deinit")) return false;
    const info = @typeInfo(@TypeOf(T.deinit));
    return info == .@"fn" and info.@"fn".params.len == 1;
}
