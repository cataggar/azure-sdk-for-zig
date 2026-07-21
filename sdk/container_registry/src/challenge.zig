const std = @import("std");

pub const BearerChallenge = struct {
    allocator: std.mem.Allocator,
    realm: []u8,
    service: []u8,
    scope: []u8,
    tenant: ?[]u8 = null,

    pub fn clone(self: BearerChallenge, allocator: std.mem.Allocator) !BearerChallenge {
        const realm = try allocator.dupe(u8, self.realm);
        errdefer allocator.free(realm);
        const service = try allocator.dupe(u8, self.service);
        errdefer allocator.free(service);
        const scope = try allocator.dupe(u8, self.scope);
        errdefer allocator.free(scope);
        const tenant = if (self.tenant) |value|
            try allocator.dupe(u8, value)
        else
            null;
        return .{
            .allocator = allocator,
            .realm = realm,
            .service = service,
            .scope = scope,
            .tenant = tenant,
        };
    }

    pub fn deinit(self: *BearerChallenge) void {
        self.allocator.free(self.realm);
        self.allocator.free(self.service);
        self.allocator.free(self.scope);
        if (self.tenant) |tenant| self.allocator.free(tenant);
        self.* = undefined;
    }
};

const ParsedValue = struct {
    bytes: []const u8,
    next: usize,
};

const TemporaryChallenge = struct {
    realm: ?[]const u8 = null,
    service: ?[]const u8 = null,
    scope: ?[]const u8 = null,
    tenant: ?[]const u8 = null,
};

/// Parses exactly one Bearer challenge from one or more WWW-Authenticate
/// header values. Returned fields are allocator-owned.
pub fn parseBearerChallenge(
    allocator: std.mem.Allocator,
    header_values: []const []const u8,
) !BearerChallenge {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var found: ?TemporaryChallenge = null;
    for (header_values) |header| {
        try parseHeaderValue(arena.allocator(), header, &found);
    }

    const parsed = found orelse return error.BearerChallengeMissing;
    const realm_value = parsed.realm orelse return error.BearerChallengeRealmMissing;
    const service_value = parsed.service orelse return error.BearerChallengeServiceMissing;
    const scope_value = parsed.scope orelse return error.BearerChallengeScopeMissing;
    if (realm_value.len == 0) return error.BearerChallengeRealmMissing;
    if (service_value.len == 0) return error.BearerChallengeServiceMissing;
    if (scope_value.len == 0) return error.BearerChallengeScopeMissing;

    const realm = try allocator.dupe(u8, realm_value);
    errdefer allocator.free(realm);
    const service = try allocator.dupe(u8, service_value);
    errdefer allocator.free(service);
    const scope = try allocator.dupe(u8, scope_value);
    errdefer allocator.free(scope);
    const tenant = if (parsed.tenant) |value|
        try allocator.dupe(u8, value)
    else
        null;

    return .{
        .allocator = allocator,
        .realm = realm,
        .service = service,
        .scope = scope,
        .tenant = tenant,
    };
}

fn parseHeaderValue(
    allocator: std.mem.Allocator,
    header: []const u8,
    found: *?TemporaryChallenge,
) !void {
    var index: usize = 0;
    while (true) {
        skipSeparators(header, &index);
        if (index == header.len) return;

        const scheme_start = index;
        try parseToken(header, &index);
        const scheme = header[scheme_start..index];
        if (index == header.len) {
            if (std.ascii.eqlIgnoreCase(scheme, "Bearer"))
                return error.MalformedBearerChallenge;
            return;
        }
        if (!isWhitespace(header[index])) return error.MalformedAuthenticationChallenge;
        skipWhitespace(header, &index);

        var bearer = TemporaryChallenge{};
        const is_bearer = std.ascii.eqlIgnoreCase(scheme, "Bearer");
        var saw_parameter = false;

        while (index < header.len) {
            const key_start = index;
            try parseToken(header, &index);
            const key = header[key_start..index];
            var after_key = index;
            skipWhitespace(header, &after_key);

            if (after_key >= header.len or header[after_key] != '=') {
                if (saw_parameter) {
                    index = key_start;
                    break;
                }
                while (index < header.len and header[index] != ',') {
                    if (isWhitespace(header[index])) return error.MalformedAuthenticationChallenge;
                    index += 1;
                }
                if (is_bearer) return error.UnsupportedBearerChallenge;
                break;
            }

            index = after_key + 1;
            skipWhitespace(header, &index);
            const value = try parseParameterValue(allocator, header, index);
            index = value.next;
            saw_parameter = true;

            if (is_bearer) try assignBearerParameter(&bearer, key, value.bytes);

            skipWhitespace(header, &index);
            if (index == header.len) break;
            if (header[index] != ',') return error.MalformedAuthenticationChallenge;
            index += 1;
            skipWhitespace(header, &index);
            if (index == header.len) return error.MalformedAuthenticationChallenge;

            var lookahead = index;
            try parseToken(header, &lookahead);
            skipWhitespace(header, &lookahead);
            if (lookahead >= header.len or header[lookahead] != '=') break;
        }

        if (is_bearer) {
            if (!saw_parameter) return error.MalformedBearerChallenge;
            if (found.* != null) return error.AmbiguousBearerChallenge;
            found.* = bearer;
        }
    }
}

fn assignBearerParameter(
    challenge: *TemporaryChallenge,
    key: []const u8,
    value: []const u8,
) !void {
    if (std.ascii.eqlIgnoreCase(key, "realm")) {
        if (challenge.realm != null) return error.AmbiguousBearerChallenge;
        challenge.realm = value;
    } else if (std.ascii.eqlIgnoreCase(key, "service")) {
        if (challenge.service != null) return error.AmbiguousBearerChallenge;
        challenge.service = value;
    } else if (std.ascii.eqlIgnoreCase(key, "scope")) {
        if (challenge.scope != null) return error.AmbiguousBearerChallenge;
        challenge.scope = value;
    } else if (std.ascii.eqlIgnoreCase(key, "tenant")) {
        if (challenge.tenant != null) return error.AmbiguousBearerChallenge;
        challenge.tenant = value;
    }
}

fn parseParameterValue(
    allocator: std.mem.Allocator,
    input: []const u8,
    start: usize,
) !ParsedValue {
    if (start >= input.len) return error.MalformedAuthenticationChallenge;
    if (input[start] != '"') {
        var index = start;
        try parseToken(input, &index);
        return .{ .bytes = input[start..index], .next = index };
    }

    var output: std.ArrayList(u8) = .empty;
    var index = start + 1;
    while (index < input.len) {
        const byte = input[index];
        switch (byte) {
            '"' => return .{
                .bytes = try output.toOwnedSlice(allocator),
                .next = index + 1,
            },
            '\\' => {
                index += 1;
                if (index == input.len) return error.MalformedAuthenticationChallenge;
                const escaped = input[index];
                if (escaped < 0x20 or escaped == 0x7f)
                    return error.MalformedAuthenticationChallenge;
                try output.append(allocator, escaped);
            },
            '\t' => try output.append(allocator, byte),
            else => {
                if (byte < 0x20 or byte == 0x7f)
                    return error.MalformedAuthenticationChallenge;
                try output.append(allocator, byte);
            },
        }
        index += 1;
    }
    return error.MalformedAuthenticationChallenge;
}

fn parseToken(input: []const u8, index: *usize) !void {
    const start = index.*;
    while (index.* < input.len and isTokenByte(input[index.*])) index.* += 1;
    if (index.* == start) return error.MalformedAuthenticationChallenge;
}

fn skipSeparators(input: []const u8, index: *usize) void {
    while (index.* < input.len) {
        if (input[index.*] == ',' or isWhitespace(input[index.*])) {
            index.* += 1;
        } else {
            break;
        }
    }
}

fn skipWhitespace(input: []const u8, index: *usize) void {
    while (index.* < input.len and isWhitespace(input[index.*])) index.* += 1;
}

fn isWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t';
}

fn isTokenByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or switch (byte) {
        '!', '#', '$', '%', '&', '\'', '*', '+', '-', '.', '^', '_', '`', '|', '~' => true,
        else => false,
    };
}

test "Bearer challenge parses quoted commas and escapes" {
    const allocator = std.testing.allocator;
    const values = [_][]const u8{
        "Basic realm=\"legacy\", Bearer realm=\"https://registry.example/oauth2/token\", service=\"registry.example\", scope=\"repository:team\\/image,one:pull\", error_description=\"expired, retry\"",
    };
    var challenge = try parseBearerChallenge(allocator, &values);
    defer challenge.deinit();

    try std.testing.expectEqualStrings(
        "https://registry.example/oauth2/token",
        challenge.realm,
    );
    try std.testing.expectEqualStrings("registry.example", challenge.service);
    try std.testing.expectEqualStrings(
        "repository:team/image,one:pull",
        challenge.scope,
    );
}

test "Bearer challenge accepts case-insensitive parameters across header values" {
    const allocator = std.testing.allocator;
    const values = [_][]const u8{
        "Basic realm=\"legacy\"",
        "bEaReR REALM=\"https://registry.example/oauth2/token\", SERVICE=\"registry.example\", SCOPE=\"registry:catalog:*\", TENANT=\"tenant-a\"",
    };
    var challenge = try parseBearerChallenge(allocator, &values);
    defer challenge.deinit();

    try std.testing.expectEqualStrings("tenant-a", challenge.tenant.?);
}

test "Bearer challenge rejects malformed quoted values" {
    const values = [_][]const u8{
        "Bearer realm=\"https://registry.example/oauth2/token, service=\"registry.example\", scope=\"registry:catalog:*\"",
    };
    try std.testing.expectError(
        error.MalformedAuthenticationChallenge,
        parseBearerChallenge(std.testing.allocator, &values),
    );
}

test "Bearer challenge rejects duplicate and multiple Bearer challenges" {
    const duplicate = [_][]const u8{
        "Bearer realm=\"https://registry.example/oauth2/token\", service=\"registry.example\", scope=\"one\", scope=\"two\"",
    };
    try std.testing.expectError(
        error.AmbiguousBearerChallenge,
        parseBearerChallenge(std.testing.allocator, &duplicate),
    );

    const multiple = [_][]const u8{
        "Bearer realm=\"https://registry.example/oauth2/token\", service=\"registry.example\", scope=\"one\"",
        "Bearer realm=\"https://registry.example/oauth2/token\", service=\"registry.example\", scope=\"two\"",
    };
    try std.testing.expectError(
        error.AmbiguousBearerChallenge,
        parseBearerChallenge(std.testing.allocator, &multiple),
    );
}

test "Bearer challenge requires realm service and scope" {
    const values = [_][]const u8{
        "Bearer realm=\"https://registry.example/oauth2/token\", service=\"registry.example\"",
    };
    try std.testing.expectError(
        error.BearerChallengeScopeMissing,
        parseBearerChallenge(std.testing.allocator, &values),
    );
}
