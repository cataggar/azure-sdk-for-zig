//! Shared utilities for Azure messaging services (Event Hubs, Service Bus).
const std = @import("std");

pub const sas = @import("sas.zig");

pub const SasCredential = sas.SasCredential;
pub const SasError = sas.SasError;
pub const audienceFor = sas.audienceFor;
pub const cbs_token_type_sas = sas.cbs_token_type_sas;
pub const cbs_token_type_jwt = sas.cbs_token_type_jwt;

/// Parsed connection string properties for Azure messaging services.
///
/// Two shapes are accepted, matching Go's `ParseConnectionString`:
///
/// 1. An embedded key and key name, from which a SAS token is generated:
///    `Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=...;SharedAccessKey=...;EntityPath=...`
/// 2. A pre-formed signature the caller generated elsewhere:
///    `Endpoint=sb://ns.servicebus.windows.net/;SharedAccessSignature=SharedAccessSignature sr=...&sig=...&se=...&skn=...`
///
/// Every slice borrows from the connection string, which must outlive the
/// result.
pub const ConnectionStringProperties = struct {
    endpoint: []const u8,
    fully_qualified_namespace: []const u8,
    shared_access_key_name: ?[]const u8 = null,
    shared_access_key: ?[]const u8 = null,
    /// A pre-formed `SharedAccessSignature`, used instead of signing with a key.
    shared_access_signature: ?[]const u8 = null,
    entity_path: ?[]const u8 = null,
    /// Set by `UseDevelopmentEmulator=true`. The emulator serves plaintext AMQP
    /// on a local port and has no certificate to validate.
    emulator: bool = false,

    /// The AMQP URI scheme this endpoint should be reached over.
    pub fn scheme(self: ConnectionStringProperties) []const u8 {
        return if (self.emulator) "amqp" else "amqps";
    }

    /// Whether the connection should be wrapped in TLS.
    pub fn useTls(self: ConnectionStringProperties) bool {
        return !self.emulator;
    }

    pub fn parse(connection_string: []const u8) !ConnectionStringProperties {
        var endpoint: ?[]const u8 = null;
        var key_name: ?[]const u8 = null;
        var key: ?[]const u8 = null;
        var signature: ?[]const u8 = null;
        var entity: ?[]const u8 = null;
        var emulator = false;

        var parts = std.mem.splitScalar(u8, connection_string, ';');
        while (parts.next()) |part| {
            const trimmed = std.mem.trim(u8, part, " ");
            if (trimmed.len == 0) continue;

            const eq_pos = std.mem.findScalar(u8, trimmed, '=') orelse
                return error.MalformedConnectionString;
            const k = trimmed[0..eq_pos];
            // A value may itself contain '=', as base64 keys and SAS tokens do.
            const v = trimmed[eq_pos + 1 ..];

            // Keys are compared case-insensitively, as the portal and the
            // other SDKs both do.
            if (std.ascii.eqlIgnoreCase(k, "Endpoint")) {
                endpoint = v;
            } else if (std.ascii.eqlIgnoreCase(k, "SharedAccessKeyName")) {
                key_name = v;
            } else if (std.ascii.eqlIgnoreCase(k, "SharedAccessKey")) {
                key = v;
            } else if (std.ascii.eqlIgnoreCase(k, "SharedAccessSignature")) {
                signature = v;
            } else if (std.ascii.eqlIgnoreCase(k, "EntityPath")) {
                entity = v;
            } else if (std.ascii.eqlIgnoreCase(k, "UseDevelopmentEmulator")) {
                emulator = if (std.ascii.eqlIgnoreCase(v, "true"))
                    true
                else if (std.ascii.eqlIgnoreCase(v, "false"))
                    false
                else
                    return error.InvalidEmulatorFlag;
            }
        }

        const ep = endpoint orelse return error.MissingEndpoint;
        const host = extractHost(ep) orelse return error.InvalidEndpoint;

        // The emulator is only ever addressed as sb://host or sb://host:port,
        // so anything else is a copy-paste mistake rather than a real endpoint.
        if (emulator and !std.mem.startsWith(u8, ep, "sb://")) return error.InvalidEmulatorEndpoint;

        // Without one of these there is nothing to authenticate with, and the
        // failure would otherwise surface as an opaque broker 401.
        if (signature == null) {
            if (key_name == null) return error.MissingSharedAccessKeyName;
            if (key == null) return error.MissingSharedAccessKey;
        }

        return .{
            .endpoint = ep,
            .fully_qualified_namespace = host,
            .shared_access_key_name = key_name,
            .shared_access_key = key,
            .shared_access_signature = signature,
            .entity_path = entity,
            .emulator = emulator,
        };
    }

    fn extractHost(endpoint: []const u8) ?[]const u8 {
        const after_scheme = if (std.mem.find(u8, endpoint, "://")) |pos|
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
    const cs = "Endpoint=sb://ns.servicebus.windows.net;SharedAccessKeyName=k;SharedAccessKey=s";
    const props = try ConnectionStringProperties.parse(cs);
    try std.testing.expectEqualStrings("ns.servicebus.windows.net", props.fully_qualified_namespace);
    try std.testing.expect(props.entity_path == null);
    try std.testing.expect(props.shared_access_signature == null);
    try std.testing.expect(!props.emulator);
}

test "ConnectionStringProperties parse missing endpoint" {
    const cs = "SharedAccessKeyName=mykey;SharedAccessKey=abc123";
    const result = ConnectionStringProperties.parse(cs);
    try std.testing.expectError(error.MissingEndpoint, result);
}

test "ConnectionStringProperties rejects a string with no credential" {
    try std.testing.expectError(
        error.MissingSharedAccessKeyName,
        ConnectionStringProperties.parse("Endpoint=sb://ns.servicebus.windows.net"),
    );
    try std.testing.expectError(
        error.MissingSharedAccessKey,
        ConnectionStringProperties.parse("Endpoint=sb://ns.servicebus.windows.net;SharedAccessKeyName=k"),
    );
}

test "ConnectionStringProperties parses a pre-formed signature" {
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;" ++
        "SharedAccessSignature=SharedAccessSignature sr=amqps%3a%2f%2fns&sig=abc%3D&se=1700003600&skn=policy";
    const props = try ConnectionStringProperties.parse(cs);

    // The value keeps its own '=' characters, and no key is required alongside.
    try std.testing.expectEqualStrings(
        "SharedAccessSignature sr=amqps%3a%2f%2fns&sig=abc%3D&se=1700003600&skn=policy",
        props.shared_access_signature.?,
    );
    try std.testing.expect(props.shared_access_key == null);
}

test "UseDevelopmentEmulator selects the insecure scheme" {
    const cs = "Endpoint=sb://localhost:6765;SharedAccessKeyName=k;SharedAccessKey=s;UseDevelopmentEmulator=true";
    const props = try ConnectionStringProperties.parse(cs);

    try std.testing.expect(props.emulator);
    try std.testing.expectEqualStrings("amqp", props.scheme());
    try std.testing.expect(!props.useTls());
    try std.testing.expectEqualStrings("localhost:6765", props.fully_qualified_namespace);
}

test "a non-emulator connection string keeps TLS" {
    const cs = "Endpoint=sb://ns.servicebus.windows.net/;SharedAccessKeyName=k;SharedAccessKey=s";
    const props = try ConnectionStringProperties.parse(cs);

    try std.testing.expect(!props.emulator);
    try std.testing.expectEqualStrings("amqps", props.scheme());
    try std.testing.expect(props.useTls());
}

test "UseDevelopmentEmulator=false is accepted and anything else is not" {
    const props = try ConnectionStringProperties.parse(
        "Endpoint=sb://ns.servicebus.windows.net;SharedAccessKeyName=k;SharedAccessKey=s;UseDevelopmentEmulator=false",
    );
    try std.testing.expect(!props.emulator);

    try std.testing.expectError(error.InvalidEmulatorFlag, ConnectionStringProperties.parse(
        "Endpoint=sb://ns.servicebus.windows.net;SharedAccessKeyName=k;SharedAccessKey=s;UseDevelopmentEmulator=yes",
    ));
}

test "the emulator flag requires an sb:// endpoint" {
    try std.testing.expectError(error.InvalidEmulatorEndpoint, ConnectionStringProperties.parse(
        "Endpoint=https://localhost:6765;SharedAccessKeyName=k;SharedAccessKey=s;UseDevelopmentEmulator=true",
    ));
}

test "connection string keys are case insensitive" {
    const cs = "endpoint=sb://ns.servicebus.windows.net/;sharedaccesskeyname=k;SHAREDACCESSKEY=s;EntityPath=hub";
    const props = try ConnectionStringProperties.parse(cs);

    try std.testing.expectEqualStrings("k", props.shared_access_key_name.?);
    try std.testing.expectEqualStrings("s", props.shared_access_key.?);
    try std.testing.expectEqualStrings("hub", props.entity_path.?);
}

test "a segment with no separator is rejected" {
    try std.testing.expectError(error.MalformedConnectionString, ConnectionStringProperties.parse(
        "Endpoint=sb://ns.servicebus.windows.net;SharedAccessKeyName",
    ));
}

test {
    // Only re-exported, so without this reference Zig never analyses it and
    // its tests never run.
    _ = sas;
}
