///! Shared utilities for Azure messaging services (Event Hubs, Service Bus).
const std = @import("std");

/// Parsed connection string properties for Azure messaging services.
///
/// Format: `Endpoint=sb://namespace.servicebus.windows.net/;SharedAccessKeyName=...;SharedAccessKey=...;EntityPath=...`
pub const ConnectionStringProperties = struct {
    endpoint: []const u8,
    fully_qualified_namespace: []const u8,
    shared_access_key_name: ?[]const u8 = null,
    shared_access_key: ?[]const u8 = null,
    entity_path: ?[]const u8 = null,

    pub fn parse(connection_string: []const u8) !ConnectionStringProperties {
        var endpoint: ?[]const u8 = null;
        var key_name: ?[]const u8 = null;
        var key: ?[]const u8 = null;
        var entity: ?[]const u8 = null;

        var parts = std.mem.splitScalar(u8, connection_string, ';');
        while (parts.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");
            if (trimmed.len == 0) continue;

            if (std.mem.indexOfScalar(u8, trimmed, '=')) |eq_pos| {
                const k = trimmed[0..eq_pos];
                const v = trimmed[eq_pos + 1 ..];

                if (std.mem.eql(u8, k, "Endpoint")) {
                    endpoint = v;
                } else if (std.mem.eql(u8, k, "SharedAccessKeyName")) {
                    key_name = v;
                } else if (std.mem.eql(u8, k, "SharedAccessKey")) {
                    key = v;
                } else if (std.mem.eql(u8, k, "EntityPath")) {
                    entity = v;
                }
            }
        }

        const ep = endpoint orelse return error.MissingEndpoint;
        const host = extractHost(ep) orelse return error.InvalidEndpoint;

        return .{
            .endpoint = ep,
            .fully_qualified_namespace = host,
            .shared_access_key_name = key_name,
            .shared_access_key = key,
            .entity_path = entity,
        };
    }

    fn extractHost(endpoint: []const u8) ?[]const u8 {
        const after_scheme = if (std.mem.indexOf(u8, endpoint, "://")) |pos|
            endpoint[pos + 3 ..]
        else
            endpoint;
        const host = if (after_scheme.len > 0 and after_scheme[after_scheme.len - 1] == '/')
            after_scheme[0 .. after_scheme.len - 1]
        else
            after_scheme;
        return if (host.len > 0) host else null;
    }
};

// ─────────────────────── Tests ───────────────────────

test "ConnectionStringProperties parse" {
    const cs = "Endpoint=sb://mynamespace.servicebus.windows.net/;SharedAccessKeyName=mykey;SharedAccessKey=abc123=;EntityPath=myhub";
    const props = try ConnectionStringProperties.parse(cs);
    try std.testing.expectEqualStrings("sb://mynamespace.servicebus.windows.net/", props.endpoint);
    try std.testing.expectEqualStrings("mynamespace.servicebus.windows.net", props.fully_qualified_namespace);
    try std.testing.expectEqualStrings("mykey", props.shared_access_key_name.?);
    try std.testing.expectEqualStrings("abc123=", props.shared_access_key.?);
    try std.testing.expectEqualStrings("myhub", props.entity_path.?);
}

test "ConnectionStringProperties parse minimal" {
    const cs = "Endpoint=sb://ns.servicebus.windows.net";
    const props = try ConnectionStringProperties.parse(cs);
    try std.testing.expectEqualStrings("ns.servicebus.windows.net", props.fully_qualified_namespace);
    try std.testing.expect(props.shared_access_key_name == null);
    try std.testing.expect(props.entity_path == null);
}

test "ConnectionStringProperties parse missing endpoint" {
    const cs = "SharedAccessKeyName=mykey;SharedAccessKey=abc123";
    const result = ConnectionStringProperties.parse(cs);
    try std.testing.expectError(error.MissingEndpoint, result);
}
