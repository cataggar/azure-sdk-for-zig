const std = @import("std");
const core = @import("../root.zig");
const serde = @import("serde");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Callback type that returns a JWT assertion string.
/// The caller owns the returned memory and must free it.
pub const AssertionCallback = *const fn (allocator: std.mem.Allocator) anyerror![]u8;

/// Authenticates with a client assertion (JWT bearer token).
///
/// Uses OAuth 2.0 client_credentials grant with:
///   grant_type=client_credentials
///   client_id=...
///   client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
///   client_assertion=<from callback>
///   scope=...
///
/// This is the foundation for federated identity scenarios
/// (WorkloadIdentity, AzurePipelines, etc.).
pub const ClientAssertionCredential = struct {
    tenant_id: []const u8,
    client_id: []const u8,
    authority_host: []const u8 = "https://login.microsoftonline.com",
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
    credential: TokenCredential,
    get_assertion: AssertionCallback,

    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
        tenant_id: []const u8,
        client_id: []const u8,
        get_assertion: AssertionCallback,
    ) ClientAssertionCredential {
        return .{
            .tenant_id = tenant_id,
            .client_id = client_id,
            .allocator = allocator,
            .transport = transport,
            .credential = .{ .getTokenFn = &getTokenImpl },
            .get_assertion = get_assertion,
        };
    }

    pub fn asCredential(self: *ClientAssertionCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        _: Context,
    ) anyerror!AccessToken {
        const self: *ClientAssertionCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        const scope = if (request_context.scopes.len > 0)
            request_context.scopes[0]
        else
            return error.NoScopesProvided;

        // Get the assertion from the callback.
        const assertion = try self.get_assertion(allocator);
        defer allocator.free(assertion);

        // Build the token request URL.
        const url = try std.fmt.allocPrint(
            allocator,
            "{s}/{s}/oauth2/v2.0/token",
            .{ self.authority_host, self.tenant_id },
        );
        defer allocator.free(url);

        const encoded_client_id = try core.url.percentEncode(allocator, self.client_id);
        defer allocator.free(encoded_client_id);
        const encoded_assertion = try core.url.percentEncode(allocator, assertion);
        defer allocator.free(encoded_assertion);
        const encoded_scope = try core.url.percentEncode(allocator, scope);
        defer allocator.free(encoded_scope);

        // Build form body.
        const body = try std.fmt.allocPrint(
            allocator,
            "grant_type=client_credentials&client_id={s}&client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer&client_assertion={s}&scope={s}",
            .{ encoded_client_id, encoded_assertion, encoded_scope },
        );
        defer allocator.free(body);

        var req = core.http.Request.init(allocator, .POST, url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/x-www-form-urlencoded");
        req.body = body;

        var resp = try self.transport.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) return error.AuthenticationFailed;

        return parseTokenResponse(allocator, resp.body);
    }
};

fn parseTokenResponse(allocator: std.mem.Allocator, body: []const u8) !AccessToken {
    const TokenResponseSchema = struct {
        access_token: []const u8,
        expires_in: i64 = 3600,
    };

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const parsed = serde.json.fromSlice(TokenResponseSchema, arena.allocator(), body) catch
        return error.InvalidTokenResponse;

    const token = try allocator.dupe(u8, parsed.access_token);
    return .{
        .token = token,
        .expires_on = currentTimestamp() + parsed.expires_in,
        .allocator = allocator,
    };
}

fn currentTimestamp() i64 {
    var threaded: std.Io.Threaded = .init_single_threaded;
    return std.Io.Timestamp.now(threaded.io(), .real).toSeconds();
}

test "ClientAssertionCredential getToken" {
    const allocator = std.testing.allocator;

    var mock = core.http.MockTransport.init(allocator, 200,
        \\{"access_token":"assertion-token","expires_in":3600}
    );
    defer mock.deinit();

    const getAssertion = struct {
        fn call(alloc: std.mem.Allocator) anyerror![]u8 {
            return alloc.dupe(u8, "my-jwt-assertion");
        }
    }.call;

    var cred = ClientAssertionCredential.init(
        allocator,
        mock.asTransport(),
        "tenant-1",
        "client-1",
        &getAssertion,
    );

    const token = try cred.asCredential().getToken(
        .{ .scopes = &.{"https://vault.azure.net/.default"} },
        core.context.Context.none,
    );
    defer allocator.free(token.token);

    try std.testing.expectEqualStrings("assertion-token", token.token);
    // Verify the request was sent to the correct token endpoint.
    try std.testing.expect(std.mem.find(u8, mock.last_url.?, "tenant-1/oauth2/v2.0/token") != null);
    try std.testing.expectEqual(core.http.Method.POST, mock.last_method.?);
}
