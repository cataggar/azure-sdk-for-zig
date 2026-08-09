//! Azure DevOps authentication.
//!
//! Azure DevOps accepts three kinds of credential, and unlike most Azure
//! services two of them are not bearer tokens, so this package cannot
//! reuse Core's `BearerTokenAuthPolicy` directly:
//!
//!   - a Personal Access Token, sent as HTTP Basic with an empty user
//!     name (`Authorization: Basic base64(":" ++ pat)`),
//!   - an Entra ID token from any Core `TokenCredential`, sent as
//!     `Authorization: Bearer …` and acquired for the fixed Azure DevOps
//!     resource,
//!   - no credential at all, for the handful of anonymous endpoints such
//!     as `status`.
//!
//! See <https://learn.microsoft.com/azure/devops/integrate/get-started/authentication/authentication-guidance>.

const std = @import("std");
const core = @import("azure_sdk_core");

const HttpPolicy = core.pipeline.HttpPolicy;
const Request = core.http.Request;
const Response = core.http.Response;
const HttpTransport = core.http.HttpTransport;

/// The first-party application ID Azure DevOps registers in Entra ID.
/// Every organization authenticates against this same resource, so the
/// scope is a constant rather than derived from the endpoint.
pub const devops_scope = "499b84ac-1321-427f-aa17-267ca6975798/.default";

/// Tokens at or within this many seconds of expiry are refreshed early so
/// a request cannot be sent with a token that expires in flight.
const expiry_skew_seconds: i64 = 300;

pub const Credential = union(enum) {
    /// Send no `Authorization` header. Only a few endpoints accept this.
    unauthenticated,
    /// A Personal Access Token, sent as HTTP Basic.
    pat: []const u8,
    /// Any Core credential; its token is sent as a bearer token.
    token_credential: *core.credentials.TokenCredential,

    pub fn fromPat(pat: []const u8) Credential {
        return .{ .pat = pat };
    }

    pub fn fromTokenCredential(credential: *core.credentials.TokenCredential) Credential {
        return .{ .token_credential = credential };
    }
};

/// Applies a `Credential` to every request travelling through a pipeline.
///
/// Bearer tokens are cached until they approach expiry; PAT headers are
/// encoded once at `init` because they never change.
pub const CredentialPolicy = struct {
    allocator: std.mem.Allocator,
    credential: Credential,
    scope: []const u8,
    policy: HttpPolicy,
    /// Pre-encoded `Basic …` value; only set for `.pat`.
    basic_value: ?[]u8 = null,
    /// Most recently acquired `Bearer …` value; only set for
    /// `.token_credential`.
    bearer_value: ?[]u8 = null,
    bearer_expires_on: i64 = 0,

    pub const Options = struct {
        /// Entra ID scope requested from a `TokenCredential`. Azure DevOps
        /// Server deployments federated to a different resource can
        /// override this.
        scope: []const u8 = devops_scope,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        credential: Credential,
        options: Options,
    ) !CredentialPolicy {
        var self: CredentialPolicy = .{
            .allocator = allocator,
            .credential = credential,
            .scope = options.scope,
            .policy = .{ .processFn = &processImpl, .prepareFn = &prepareImpl },
        };
        if (credential == .pat) {
            self.basic_value = try encodeBasic(allocator, credential.pat);
        }
        return self;
    }

    pub fn deinit(self: *CredentialPolicy) void {
        if (self.basic_value) |value| self.allocator.free(value);
        if (self.bearer_value) |value| self.allocator.free(value);
        self.basic_value = null;
        self.bearer_value = null;
    }

    pub fn asPolicy(self: *CredentialPolicy) *HttpPolicy {
        return &self.policy;
    }

    /// The `Authorization` value for the current credential, refreshing a
    /// bearer token when the cached one is missing or near expiry.
    /// Returns null when unauthenticated. The policy owns the slice.
    pub fn authorizationHeader(self: *CredentialPolicy) !?[]const u8 {
        return switch (self.credential) {
            .unauthenticated => null,
            .pat => self.basic_value,
            .token_credential => |credential| blk: {
                var threaded: std.Io.Threaded = .init_single_threaded;
                const now = std.Io.Timestamp.now(threaded.io(), .real).toSeconds();
                if (self.bearer_value) |value| {
                    if (self.bearer_expires_on - expiry_skew_seconds > now) break :blk value;
                    self.allocator.free(value);
                    self.bearer_value = null;
                }
                const scopes = [_][]const u8{self.scope};
                var token = try credential.getToken(
                    .{ .scopes = &scopes },
                    core.context.Context.none,
                );
                defer token.deinit();
                const value = try std.fmt.allocPrint(
                    self.allocator,
                    "Bearer {s}",
                    .{token.token},
                );
                self.bearer_value = value;
                self.bearer_expires_on = token.expires_on;
                break :blk value;
            },
        };
    }

    fn prepareImpl(policy: *HttpPolicy, request: *Request) !void {
        const self: *CredentialPolicy = @alignCast(@fieldParentPtr("policy", policy));
        if (try self.authorizationHeader()) |value| {
            try request.setHeader("Authorization", value);
        }
    }

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        try prepareImpl(policy, request);
        if (next.len == 0) return final_transport.send(request);
        return next[0].process(request, next[1..], final_transport);
    }
};

/// `Basic base64(":" ++ pat)`. Azure DevOps ignores the user name, so it
/// is deliberately empty. Caller owns the returned slice.
fn encodeBasic(allocator: std.mem.Allocator, pat: []const u8) ![]u8 {
    const raw = try std.fmt.allocPrint(allocator, ":{s}", .{pat});
    defer allocator.free(raw);
    const encoder = std.base64.standard.Encoder;
    const encoded = try allocator.alloc(u8, encoder.calcSize(raw.len));
    defer allocator.free(encoded);
    _ = encoder.encode(encoded, raw);
    return std.fmt.allocPrint(allocator, "Basic {s}", .{encoded});
}

test "PAT credentials are sent as Basic auth with an empty user name" {
    const allocator = std.testing.allocator;
    var policy = try CredentialPolicy.init(allocator, .fromPat("secret-pat"), .{});
    defer policy.deinit();

    const header = (try policy.authorizationHeader()).?;
    try std.testing.expectStringStartsWith(header, "Basic ");

    const encoded = header["Basic ".len..];
    const decoder = std.base64.standard.Decoder;
    const decoded = try allocator.alloc(u8, try decoder.calcSizeForSlice(encoded));
    defer allocator.free(decoded);
    try decoder.decode(decoded, encoded);
    try std.testing.expectEqualStrings(":secret-pat", decoded);
}

test "unauthenticated credentials send no Authorization header" {
    var policy = try CredentialPolicy.init(std.testing.allocator, .unauthenticated, .{});
    defer policy.deinit();
    try std.testing.expect((try policy.authorizationHeader()) == null);
}

test "the Azure DevOps scope is the first-party resource, not the endpoint" {
    var policy = try CredentialPolicy.init(std.testing.allocator, .unauthenticated, .{});
    defer policy.deinit();
    try std.testing.expectEqualStrings(devops_scope, policy.scope);
    try std.testing.expectEqualStrings(
        "499b84ac-1321-427f-aa17-267ca6975798/.default",
        devops_scope,
    );
}
