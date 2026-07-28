//! Shared Access Signature generation for Azure messaging services.
//!
//! Event Hubs and Service Bus both authenticate connection strings by signing a
//! resource URI with a shared access key, so this lives in the common package.
//! The token format and signing algorithm match Go's `internal/sas/sas.go` and
//! Rust's `common/sas_credential.rs`:
//!
//! ```text
//! SharedAccessSignature sr={encoded resource}&sig={encoded HMAC}&se={expiry}&skn={key name}
//! ```
//!
//! The string-to-sign is `encoded_resource + "\n" + expiry`, and the HMAC-SHA256
//! is taken over the **raw** key bytes; the `SharedAccessKey` is not
//! base64-decoded first even though it looks like base64.

const std = @import("std");
const core = @import("azure_sdk_core");
const connection_string = @import("root.zig");

/// CBS token type for a Shared Access Signature.
pub const cbs_token_type_sas = "servicebus.windows.net:sastoken";

/// CBS token type for an Entra ID (AAD) bearer token.
pub const cbs_token_type_jwt = "jwt";

/// How long a generated token stays valid.
///
/// Rust uses one hour and Go two. The shorter window is the safer default: the
/// connection re-authorizes well before it elapses, and a leaked token is
/// useful for less time.
pub const default_validity_secs: i64 = 60 * 60;

pub const SasError = error{
    /// The token does not start with `SharedAccessSignature `.
    MalformedSignature,
    /// The token has no `se` field.
    MissingExpiry,
    /// The token's `se` field is not a Unix timestamp.
    InvalidExpiry,
    /// A pre-formed token is past its `se` and cannot be re-signed.
    SignatureExpired,
};

const signature_prefix = "SharedAccessSignature ";

/// Percent-encode `input` the way Go's `url.QueryEscape` does, since the broker
/// recomputes the HMAC over the `sr` field exactly as it was sent.
///
/// Everything outside `A-Za-z0-9-_.~` is escaped, and a space becomes `+`
/// rather than `%20`.
///
/// Caller owns the result.
pub fn percentEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, input.len);

    for (input) |byte| {
        switch (byte) {
            'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => try out.append(allocator, byte),
            ' ' => try out.append(allocator, '+'),
            else => try out.print(allocator, "%{X:0>2}", .{byte}),
        }
    }

    return out.toOwnedSlice(allocator);
}

/// Build the audience URI a token is scoped to, `amqps://{namespace}/{entity}`.
///
/// An entity-scoped token authorizes every partition and consumer group
/// beneath it, so one token covers all of a client's links. Pass a null or
/// empty `entity` for a namespace-scoped token.
///
/// Caller owns the result.
pub fn audienceFor(
    allocator: std.mem.Allocator,
    fully_qualified_namespace: []const u8,
    entity: ?[]const u8,
) ![]u8 {
    if (entity) |path| {
        if (path.len > 0) {
            return std.fmt.allocPrint(allocator, "amqps://{s}/{s}", .{ fully_qualified_namespace, path });
        }
    }
    return std.fmt.allocPrint(allocator, "amqps://{s}/", .{fully_qualified_namespace});
}

/// Sign `audience` with `key`, producing a token valid until `expiry_secs`.
///
/// `expiry_secs` is a Unix timestamp in seconds. Caller owns the result.
pub fn sign(
    allocator: std.mem.Allocator,
    audience: []const u8,
    key_name: []const u8,
    key: []const u8,
    expiry_secs: i64,
) ![]u8 {
    // The resource is lowercased after encoding, so the escape hex digits come
    // out lowercase too (`%3a`, not `%3A`). Go does the same via
    // `strings.ToLower(url.QueryEscape(uri))`; the signature below is not
    // lowercased.
    const resource = try percentEncode(allocator, audience);
    defer allocator.free(resource);
    for (resource) |*byte| byte.* = std.ascii.toLower(byte.*);

    const string_to_sign = try std.fmt.allocPrint(allocator, "{s}\n{d}", .{ resource, expiry_secs });
    defer allocator.free(string_to_sign);

    const Hmac = std.crypto.auth.hmac.sha2.HmacSha256;
    var mac: [Hmac.mac_length]u8 = undefined;
    Hmac.create(&mac, string_to_sign, key);

    const Base64 = std.base64.standard.Encoder;
    var encoded_mac: [Base64.calcSize(Hmac.mac_length)]u8 = undefined;
    const base64_mac = Base64.encode(&encoded_mac, &mac);

    const signature = try percentEncode(allocator, base64_mac);
    defer allocator.free(signature);

    return std.fmt.allocPrint(
        allocator,
        signature_prefix ++ "sr={s}&sig={s}&se={d}&skn={s}",
        .{ resource, signature, expiry_secs, key_name },
    );
}

/// Read the `se` expiry out of a pre-formed token, validating its shape.
///
/// A token that does not look like this signer's output is rejected here, so a
/// truncated or mistyped connection string fails at open time rather than as an
/// opaque broker 401 later.
pub fn parseExpiry(token: []const u8) SasError!i64 {
    if (!std.mem.startsWith(u8, token, signature_prefix)) return error.MalformedSignature;

    var fields = std.mem.splitScalar(u8, token[signature_prefix.len..], '&');
    while (fields.next()) |field| {
        if (std.mem.startsWith(u8, field, "se=")) {
            return std.fmt.parseInt(i64, field[3..], 10) catch error.InvalidExpiry;
        }
    }
    return error.MissingExpiry;
}

/// Current Unix time in seconds.
pub fn currentTimestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    return std.Io.Timestamp.now(threaded.io(), .real).toSeconds();
}

/// A `TokenCredential` that produces SAS tokens, so downstream clients only
/// ever see a credential regardless of how the caller authenticated.
///
/// Every slice is borrowed and must outlive the credential.
pub const SasCredential = struct {
    allocator: std.mem.Allocator,
    kind: Kind,
    credential: core.credentials.TokenCredential,
    /// Injected so tests can pin the expiry. Defaults to the system clock.
    now_fn: *const fn () i64 = currentTimestamp,

    pub const Kind = union(enum) {
        /// Sign a fresh token on every request.
        shared_key: struct {
            audience: []const u8,
            key_name: []const u8,
            key: []const u8,
            validity_secs: i64 = default_validity_secs,
        },
        /// Hand back a signature the caller supplied. It cannot be re-signed,
        /// so it expires for good.
        preformed: struct {
            token: []const u8,
            expires_on: i64,
        },
    };

    pub fn initSharedKey(
        allocator: std.mem.Allocator,
        audience: []const u8,
        key_name: []const u8,
        key: []const u8,
    ) SasCredential {
        return .{
            .allocator = allocator,
            .kind = .{ .shared_key = .{ .audience = audience, .key_name = key_name, .key = key } },
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    /// Wrap a pre-formed `SharedAccessSignature`, validating its shape and
    /// reading its real expiry up front.
    pub fn initPreformed(allocator: std.mem.Allocator, token: []const u8) SasError!SasCredential {
        return .{
            .allocator = allocator,
            .kind = .{ .preformed = .{ .token = token, .expires_on = try parseExpiry(token) } },
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    /// Build the right credential for a parsed connection string.
    ///
    /// `audience` is borrowed; see `audienceFor`.
    pub fn initFromConnectionString(
        allocator: std.mem.Allocator,
        properties: connection_string.ConnectionStringProperties,
        audience: []const u8,
    ) SasError!SasCredential {
        if (properties.shared_access_signature) |signature| {
            return initPreformed(allocator, signature);
        }
        // `ConnectionStringProperties.parse` rejects a string with neither a
        // signature nor a key, so both are present here.
        return initSharedKey(
            allocator,
            audience,
            properties.shared_access_key_name.?,
            properties.shared_access_key.?,
        );
    }

    pub fn asCredential(self: *SasCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    /// Whether this credential can produce a new token once the current one
    /// expires. A pre-formed signature cannot.
    pub fn isRefreshable(self: SasCredential) bool {
        return self.kind == .shared_key;
    }

    fn getTokenImpl(
        credential: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        ctx: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        _ = request_context;
        _ = ctx;
        const self: *SasCredential = @alignCast(@fieldParentPtr("credential", credential));

        switch (self.kind) {
            .shared_key => |shared_key| {
                const expires_on = self.now_fn() + shared_key.validity_secs;
                const token = try sign(
                    self.allocator,
                    shared_key.audience,
                    shared_key.key_name,
                    shared_key.key,
                    expires_on,
                );
                return .{ .token = token, .expires_on = expires_on, .allocator = self.allocator };
            },
            .preformed => |preformed| {
                // Re-presenting an expired signature just gets the link dropped
                // by the broker, so fail with something the caller can act on.
                if (self.now_fn() >= preformed.expires_on) return error.SignatureExpired;
                return .{ .token = preformed.token, .expires_on = preformed.expires_on };
            },
        }
    }
};

// ─────────────────────── Tests ───────────────────────

test "percentEncode matches Go's url.QueryEscape" {
    const allocator = std.testing.allocator;

    const encoded = try percentEncode(allocator, "amqps://example.servicebus.windows.net/myhub");
    defer allocator.free(encoded);
    try std.testing.expectEqualStrings(
        "amqps%3A%2F%2Fexample.servicebus.windows.net%2Fmyhub",
        encoded,
    );

    const unreserved = try percentEncode(allocator, "abcXYZ012-_.~");
    defer allocator.free(unreserved);
    try std.testing.expectEqualStrings("abcXYZ012-_.~", unreserved);

    // A space is `+`, not `%20`, which is what makes this query escaping.
    const spaced = try percentEncode(allocator, "a b");
    defer allocator.free(spaced);
    try std.testing.expectEqualStrings("a+b", spaced);

    const base64_chars = try percentEncode(allocator, "aB+/9=");
    defer allocator.free(base64_chars);
    try std.testing.expectEqualStrings("aB%2B%2F9%3D", base64_chars);
}

test "sign matches the cross-SDK reference vector" {
    const allocator = std.testing.allocator;

    // Generated independently and cross-checked against the vector checked into
    // azure-sdk-for-rust. Pins the raw-key HMAC, the encoding, the field order,
    // and the casing asymmetry between `sr` and `sig`.
    const token = try sign(
        allocator,
        "amqps://example.servicebus.windows.net/myhub",
        "RootManageSharedAccessKey",
        "mykey",
        1_700_000_000,
    );
    defer allocator.free(token);

    try std.testing.expectEqualStrings(
        "SharedAccessSignature " ++
            "sr=amqps%3a%2f%2fexample.servicebus.windows.net%2fmyhub" ++
            "&sig=SgJoMn7K6nWDCF6e1%2BfsxrmJLsorqPeZ3B8N1uQ31dc%3D" ++
            "&se=1700000000" ++
            "&skn=RootManageSharedAccessKey",
        token,
    );
}

test "sign uses the key as raw bytes" {
    const allocator = std.testing.allocator;

    // "bXlrZXk=" is the base64 of "mykey". Signing with one must not equal
    // signing with the other, or the key is being decoded when it should not be.
    const raw = try sign(allocator, "amqps://ns/hub", "policy", "mykey", 100);
    defer allocator.free(raw);
    const encoded = try sign(allocator, "amqps://ns/hub", "policy", "bXlrZXk=", 100);
    defer allocator.free(encoded);

    try std.testing.expect(!std.mem.eql(u8, raw, encoded));
}

test "audienceFor scopes to an entity or a namespace" {
    const allocator = std.testing.allocator;

    const entity = try audienceFor(allocator, "ns.servicebus.windows.net", "myhub");
    defer allocator.free(entity);
    try std.testing.expectEqualStrings("amqps://ns.servicebus.windows.net/myhub", entity);

    const namespace = try audienceFor(allocator, "ns.servicebus.windows.net", null);
    defer allocator.free(namespace);
    try std.testing.expectEqualStrings("amqps://ns.servicebus.windows.net/", namespace);

    const empty = try audienceFor(allocator, "ns.servicebus.windows.net", "");
    defer allocator.free(empty);
    try std.testing.expectEqualStrings("amqps://ns.servicebus.windows.net/", empty);
}

test "parseExpiry reads se and rejects malformed tokens" {
    try std.testing.expectEqual(@as(i64, 1700000000), try parseExpiry(
        "SharedAccessSignature sr=amqps%3a%2f%2fns&sig=abc%3D&se=1700000000&skn=policy",
    ));

    // `se` is found wherever it appears, not just last.
    try std.testing.expectEqual(@as(i64, 42), try parseExpiry(
        "SharedAccessSignature se=42&sr=x&sig=y&skn=z",
    ));

    try std.testing.expectError(error.MalformedSignature, parseExpiry("sr=x&se=1&skn=z"));
    try std.testing.expectError(error.MissingExpiry, parseExpiry(
        "SharedAccessSignature sr=x&sig=y&skn=z",
    ));
    try std.testing.expectError(error.InvalidExpiry, parseExpiry(
        "SharedAccessSignature sr=x&se=soon&skn=z",
    ));
    // A field merely containing "se=" must not be mistaken for the expiry.
    try std.testing.expectError(error.MissingExpiry, parseExpiry(
        "SharedAccessSignature sr=x&use=1&skn=z",
    ));
}

const fixed_now: i64 = 1_700_000_000;

fn fixedNow() i64 {
    return fixed_now;
}

test "a shared key credential signs a fresh token per request" {
    const allocator = std.testing.allocator;

    var credential = SasCredential.initSharedKey(
        allocator,
        "amqps://example.servicebus.windows.net/myhub",
        "RootManageSharedAccessKey",
        "mykey",
    );
    credential.now_fn = fixedNow;
    try std.testing.expect(credential.isRefreshable());

    var token = try credential.asCredential().getToken(.{ .scopes = &.{} }, .none);
    defer token.deinit();

    try std.testing.expectEqual(fixed_now + default_validity_secs, token.expires_on);
    try std.testing.expect(std.mem.startsWith(u8, token.token, "SharedAccessSignature sr="));
    try std.testing.expectEqual(token.expires_on, try parseExpiry(token.token));
    // The token owns its memory, unlike a pre-formed one.
    try std.testing.expect(token.allocator != null);
}

test "validity defaults to one hour" {
    try std.testing.expectEqual(@as(i64, 3600), default_validity_secs);

    const credential = SasCredential.initSharedKey(std.testing.allocator, "amqps://ns/hub", "policy", "key");
    try std.testing.expectEqual(default_validity_secs, credential.kind.shared_key.validity_secs);
}

test "a pre-formed signature passes through unmodified and reports its own expiry" {
    const allocator = std.testing.allocator;
    const supplied = "SharedAccessSignature sr=amqps%3a%2f%2fns&sig=abc%3D&se=1700003600&skn=policy";

    var credential = try SasCredential.initPreformed(allocator, supplied);
    credential.now_fn = fixedNow;
    try std.testing.expect(!credential.isRefreshable());

    var token = try credential.asCredential().getToken(.{ .scopes = &.{} }, .none);
    defer token.deinit();

    try std.testing.expectEqualStrings(supplied, token.token);
    try std.testing.expectEqual(@as(i64, 1700003600), token.expires_on);
    // Borrowed, so there is nothing for the caller to free.
    try std.testing.expect(token.allocator == null);
}

test "an expired pre-formed signature is refused rather than re-presented" {
    const allocator = std.testing.allocator;

    var credential = try SasCredential.initPreformed(
        allocator,
        "SharedAccessSignature sr=amqps%3a%2f%2fns&sig=abc%3D&se=1699999999&skn=policy",
    );
    credential.now_fn = fixedNow;

    try std.testing.expectError(
        error.SignatureExpired,
        credential.asCredential().getToken(.{ .scopes = &.{} }, .none),
    );
}

test "a malformed pre-formed signature is rejected at construction" {
    try std.testing.expectError(
        error.MalformedSignature,
        SasCredential.initPreformed(std.testing.allocator, "sr=x&se=1&skn=z"),
    );
}

test "a connection string credential prefers a supplied signature" {
    const allocator = std.testing.allocator;
    const properties = try connection_string.ConnectionStringProperties.parse(
        "Endpoint=sb://ns.servicebus.windows.net/;" ++
            "SharedAccessSignature=SharedAccessSignature sr=amqps%3a%2f%2fns&sig=abc%3D&se=1700003600&skn=policy",
    );

    var credential = try SasCredential.initFromConnectionString(allocator, properties, "unused");
    credential.now_fn = fixedNow;
    try std.testing.expect(!credential.isRefreshable());

    var token = try credential.asCredential().getToken(.{ .scopes = &.{} }, .none);
    defer token.deinit();
    try std.testing.expectEqual(@as(i64, 1700003600), token.expires_on);
}

test "a connection string credential falls back to the shared key" {
    const allocator = std.testing.allocator;
    const properties = try connection_string.ConnectionStringProperties.parse(
        "Endpoint=sb://example.servicebus.windows.net/;" ++
            "SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=mykey;EntityPath=myhub",
    );

    const audience = try audienceFor(
        allocator,
        properties.fully_qualified_namespace,
        properties.entity_path,
    );
    defer allocator.free(audience);

    var credential = try SasCredential.initFromConnectionString(allocator, properties, audience);
    credential.now_fn = fixedNow;
    try std.testing.expect(credential.isRefreshable());

    var token = try credential.asCredential().getToken(.{ .scopes = &.{} }, .none);
    defer token.deinit();

    const expected = try sign(
        allocator,
        "amqps://example.servicebus.windows.net/myhub",
        "RootManageSharedAccessKey",
        "mykey",
        fixed_now + default_validity_secs,
    );
    defer allocator.free(expected);
    try std.testing.expectEqualStrings(expected, token.token);
}

test "signing is failure atomic" {
    const Case = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const token = try sign(allocator, "amqps://ns.example.com/hub", "policy", "key", 1);
            defer allocator.free(token);
            try std.testing.expect(std.mem.startsWith(u8, token, "SharedAccessSignature "));
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Case.run, .{});
}

test "the CBS token types match the other SDKs" {
    try std.testing.expectEqualStrings("servicebus.windows.net:sastoken", cbs_token_type_sas);
    try std.testing.expectEqualStrings("jwt", cbs_token_type_jwt);
}
