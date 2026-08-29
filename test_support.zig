const std = @import("std");
const core = @import("azure_sdk_core");

var standard_crypto = core.crypto.StdCryptoProvider.init(std.testing.io);

pub fn runtime(transport: core.http.HttpTransport) core.http.HttpRuntime {
    return .init(transport, standard_crypto.asProvider());
}

pub const StaticCredential = struct {
    credential: core.credentials.TokenCredential = .{ .getTokenFn = &getToken },
    calls: usize = 0,
    last_scope: ?[]const u8 = null,

    pub fn asCredential(self: *StaticCredential) *core.credentials.TokenCredential {
        return &self.credential;
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        request_context: core.credentials.TokenRequestContext,
        _: core.context.Context,
        _: core.http.HttpRuntime,
    ) !core.credentials.AccessToken {
        const self: *StaticCredential = @alignCast(
            @fieldParentPtr("credential", credential),
        );
        self.calls += 1;
        self.last_scope = if (request_context.scopes.len == 0)
            null
        else
            request_context.scopes[0];
        return .{
            .token = "test-token",
            .expires_on = 7_258_118_400,
        };
    }
};
