const std = @import("std");
const core = @import("azure_core");
const client_assertion = @import("client_assertion.zig");

const AccessToken = core.credentials.AccessToken;
const TokenCredential = core.credentials.TokenCredential;
const TokenRequestContext = core.credentials.TokenRequestContext;
const Context = core.context.Context;

/// Authenticates with an X.509 certificate.
///
/// Reads a PEM certificate file and uses it as a client assertion
/// via `ClientAssertionCredential`. The PEM file must contain both
/// the certificate and the private key.
///
/// Note: This implementation sends the raw PEM content as the assertion.
/// A production implementation would sign a JWT with the private key
/// and use the certificate thumbprint in the JWT header. This requires
/// RSA/EC signing which could be added via `std.crypto`.
pub const ClientCertificateCredential = struct {
    tenant_id: []const u8,
    client_id: []const u8,
    certificate_path: []const u8,
    authority_host: []const u8 = "https://login.microsoftonline.com",
    allocator: std.mem.Allocator,
    transport: *core.http.HttpTransport,
    credential: TokenCredential,

    pub fn init(
        allocator: std.mem.Allocator,
        transport: *core.http.HttpTransport,
        tenant_id: []const u8,
        client_id: []const u8,
        certificate_path: []const u8,
    ) ClientCertificateCredential {
        return .{
            .tenant_id = tenant_id,
            .client_id = client_id,
            .certificate_path = certificate_path,
            .allocator = allocator,
            .transport = transport,
            .credential = .{ .getTokenFn = &getTokenImpl },
        };
    }

    pub fn asCredential(self: *ClientCertificateCredential) *TokenCredential {
        return &self.credential;
    }

    fn getTokenImpl(
        cred: *TokenCredential,
        request_context: TokenRequestContext,
        ctx: Context,
    ) anyerror!AccessToken {
        const self: *ClientCertificateCredential = @fieldParentPtr("credential", cred);
        const allocator = self.allocator;

        // Read the PEM file.
        const pem_content = std.fs.cwd().readFileAlloc(
            allocator,
            self.certificate_path,
            1024 * 1024,
        ) catch return error.CertificateReadFailed;
        defer allocator.free(pem_content);

        // Build a client assertion from the certificate.
        // In a full implementation, this would create a signed JWT.
        // For now, we use the PEM content hash as a placeholder assertion.
        const assertion = try buildCertificateAssertion(
            allocator,
            pem_content,
            self.tenant_id,
            self.client_id,
            self.authority_host,
        );
        defer allocator.free(assertion);

        // Use ClientAssertionCredential with the assertion.
        const StaticAssertion = struct {
            var cached: []const u8 = "";
            fn getAssertion(alloc: std.mem.Allocator) anyerror![]u8 {
                return alloc.dupe(u8, cached);
            }
        };
        StaticAssertion.cached = assertion;

        var assertion_cred = client_assertion.ClientAssertionCredential.init(
            allocator,
            self.transport,
            self.tenant_id,
            self.client_id,
            &StaticAssertion.getAssertion,
        );
        assertion_cred.authority_host = self.authority_host;

        return assertion_cred.asCredential().getToken(request_context, ctx);
    }
};

/// Build a client assertion string from certificate content.
///
/// A complete implementation would:
/// 1. Extract the certificate and private key from PEM
/// 2. Compute the certificate thumbprint (SHA-1 of DER)
/// 3. Build a JWT header with x5t (thumbprint)
/// 4. Build JWT claims (iss, sub, aud, exp, etc.)
/// 5. Sign with the private key (RS256 or ES256)
///
/// This placeholder uses a base64-encoded hash to enable the
/// credential pattern while full JWT signing is implemented.
fn buildCertificateAssertion(
    allocator: std.mem.Allocator,
    pem_content: []const u8,
    tenant_id: []const u8,
    client_id: []const u8,
    authority_host: []const u8,
) ![]u8 {
    // Placeholder: encode a deterministic assertion from the inputs.
    // This allows the full OAuth flow to work with a mock token endpoint.
    _ = authority_host;
    return std.fmt.allocPrint(
        allocator,
        "cert-assertion:{s}:{s}:{d}",
        .{ tenant_id, client_id, pem_content.len },
    );
}

test "ClientCertificateCredential fields" {
    const allocator = std.testing.allocator;
    var mock = core.http.MockTransport.init(allocator, 200, "{}");
    defer mock.deinit();

    const cred = ClientCertificateCredential.init(
        allocator,
        mock.asTransport(),
        "tenant-1",
        "client-1",
        "/path/to/cert.pem",
    );

    try std.testing.expectEqualStrings("tenant-1", cred.tenant_id);
    try std.testing.expectEqualStrings("client-1", cred.client_id);
    try std.testing.expectEqualStrings("/path/to/cert.pem", cred.certificate_path);
}
