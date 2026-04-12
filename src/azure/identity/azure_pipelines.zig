const std = @import("std");
const core = @import("azure_core");
const client_assertion = @import("client_assertion.zig");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Authenticates an Azure Pipelines task using OIDC federation.
///
/// Uses the Azure Pipelines OIDC token endpoint to obtain a federated
/// token, then exchanges it via `ClientAssertionCredential`.
///
/// Required environment variables:
///   SYSTEM_OIDCREQUESTURI — OIDC request URI (set by Azure Pipelines)
///   SYSTEM_ACCESSTOKEN    — Pipeline access token
pub const AzurePipelinesCredential = struct {
    tenant_id: []const u8,
    client_id: []const u8,
    service_connection_id: []const u8,
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
    credential: TokenCredential,
    oidc_request_uri: ?[]const u8,
    system_access_token: ?[]const u8,

    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
        tenant_id: []const u8,
        client_id: []const u8,
        service_connection_id: []const u8,
    ) AzurePipelinesCredential {
        return .{
            .tenant_id = tenant_id,
            .client_id = client_id,
            .service_connection_id = service_connection_id,
            .allocator = allocator,
            .transport = transport,
            .credential = .{ .getTokenFn = &getTokenImpl },
            .oidc_request_uri = std.process.getEnvVarOwned(allocator, "SYSTEM_OIDCREQUESTURI") catch null,
            .system_access_token = std.process.getEnvVarOwned(allocator, "SYSTEM_ACCESSTOKEN") catch null,
        };
    }

    pub fn asCredential(self: *AzurePipelinesCredential) *TokenCredential {
        return &self.credential;
    }

    pub fn deinit(self: *AzurePipelinesCredential) void {
        if (self.oidc_request_uri) |u| self.allocator.free(u);
        if (self.system_access_token) |t| self.allocator.free(t);
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        ctx: Context,
    ) anyerror!AccessToken {
        const self: *AzurePipelinesCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        const oidc_uri = self.oidc_request_uri orelse return error.NotInAzurePipelines;
        const access_token = self.system_access_token orelse return error.NotInAzurePipelines;

        // Request OIDC token from Azure Pipelines.
        const oidc_url = try std.fmt.allocPrint(
            allocator,
            "{s}?api-version=7.1&serviceConnectionId={s}",
            .{ oidc_uri, self.service_connection_id },
        );
        defer allocator.free(oidc_url);

        const auth_header = try std.fmt.allocPrint(allocator, "Bearer {s}", .{access_token});
        defer allocator.free(auth_header);

        var req = core.http.Request.init(allocator, .POST, oidc_url);
        defer req.deinit();
        try req.setHeader("Content-Type", "application/json");
        try req.setHeader("Authorization", auth_header);
        req.body = "{}";

        var resp = try self.transport.send(&req);
        defer resp.deinit();

        if (!resp.isSuccess()) return error.OidcTokenRequestFailed;

        // Parse the OIDC token from the response.
        const oidc_token = try parseOidcToken(allocator, resp.body);
        defer allocator.free(oidc_token);

        // Use the OIDC token as a client assertion.
        const getAssertion = struct {
            var cached_token: []const u8 = undefined;
            var cached_allocator: std.mem.Allocator = undefined;

            fn call(alloc: std.mem.Allocator) anyerror![]u8 {
                return alloc.dupe(u8, cached_token);
            }
        };
        getAssertion.cached_token = oidc_token;
        getAssertion.cached_allocator = allocator;

        var assertion_cred = client_assertion.ClientAssertionCredential.init(
            allocator,
            self.transport,
            self.tenant_id,
            self.client_id,
            &getAssertion.call,
        );

        return assertion_cred.asCredential().getToken(request_context, ctx);
    }
};

fn parseOidcToken(allocator: std.mem.Allocator, body: []const u8) ![]u8 {
    const parsed = try std.json.parseFromSlice(std.json.Value, std.heap.page_allocator, body, .{});
    defer parsed.deinit();

    const obj = if (parsed.value == .object) parsed.value.object else return error.InvalidOidcResponse;

    if (obj.get("oidcToken")) |v| {
        if (v == .string) return allocator.dupe(u8, v.string);
    }

    return error.InvalidOidcResponse;
}

test "parseOidcToken" {
    const body =
        \\{"oidcToken":"eyJ0eXAi..."}
    ;
    const token = try parseOidcToken(std.testing.allocator, body);
    defer std.testing.allocator.free(token);
    try std.testing.expectEqualStrings("eyJ0eXAi...", token);
}
