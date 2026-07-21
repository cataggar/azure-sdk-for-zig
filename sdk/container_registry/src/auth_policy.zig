const std = @import("std");
const core = @import("azure_core");
const challenge_mod = @import("challenge.zig");

const BearerChallenge = challenge_mod.BearerChallenge;
const Request = core.http.Request;
const Response = core.http.Response;
const HttpOperation = core.http.HttpOperation;
const HttpPolicy = core.pipeline.HttpPolicy;
const HttpTransport = core.http.HttpTransport;
const OpenOptions = core.http.OpenOptions;
const CancellationToken = core.http.CancellationToken;

const default_aad_scope = "https://containerregistry.azure.net/.default";
const default_api_version = "2021-07-01";
const default_expiry_skew_seconds: i64 = 300;

pub const Authentication = union(enum) {
    credential: *core.credentials.TokenCredential,
    anonymous,
};

pub const TimeSource = struct {
    context: *anyopaque,
    nowFn: *const fn (context: *anyopaque) i64,

    pub fn now(self: TimeSource) i64 {
        return self.nowFn(self.context);
    }
};

pub const Options = struct {
    /// Optional tenant sent during AAD-to-ACR token exchange.
    tenant_id: ?[]const u8 = null,
    /// AAD scope requested from the supplied TokenCredential.
    aad_scope: []const u8 = default_aad_scope,
    /// ACR authentication API version.
    api_version: []const u8 = default_api_version,
    /// Additional exact HTTPS hosts trusted for registry requests and realms.
    expected_hosts: []const []const u8 = &.{},
    /// Tokens at or within this many seconds of expiry are refreshed.
    expiry_skew_seconds: i64 = default_expiry_skew_seconds,
    /// Deterministic clock override, primarily for tests.
    time_source: ?TimeSource = null,
};

const RefreshTokenEntry = struct {
    realm: []u8,
    service: []u8,
    tenant: []u8,
    token: []u8,
    expires_on: i64,

    fn deinit(self: *RefreshTokenEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.realm);
        allocator.free(self.service);
        allocator.free(self.tenant);
        allocator.free(self.token);
        self.* = undefined;
    }
};

const AccessTokenEntry = struct {
    realm: []u8,
    service: []u8,
    tenant: []u8,
    scope: []u8,
    token: []u8,
    expires_on: i64,

    fn deinit(self: *AccessTokenEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.realm);
        allocator.free(self.service);
        allocator.free(self.tenant);
        allocator.free(self.scope);
        allocator.free(self.token);
        self.* = undefined;
    }
};

const RouteEntry = struct {
    method: core.http.Method,
    url: []u8,
    challenge: BearerChallenge,

    fn deinit(self: *RouteEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        self.challenge.deinit();
        self.* = undefined;
    }
};

/// ACR Bearer challenge policy. The policy validates every destination before
/// sending, performs token bootstrap calls without redirects, and replays a
/// challenged request at most once.
pub const ChallengeAuthenticationPolicy = struct {
    allocator: std.mem.Allocator,
    endpoint: []u8,
    endpoint_host: []u8,
    expected_hosts: [][]u8,
    authentication: Authentication,
    tenant_id: ?[]u8,
    aad_scope: []u8,
    api_version: []u8,
    expiry_skew_seconds: i64,
    time_source: ?TimeSource,
    io: std.Io,
    mutex: std.Io.Mutex = .init,
    refresh_finished: std.Io.Condition = .init,
    refreshing: bool = false,
    waiting_callers: usize = 0,
    refresh_tokens: std.ArrayList(RefreshTokenEntry) = .empty,
    access_tokens: std.ArrayList(AccessTokenEntry) = .empty,
    routes: std.ArrayList(RouteEntry) = .empty,
    policy: HttpPolicy,

    pub fn init(
        allocator: std.mem.Allocator,
        endpoint: []const u8,
        authentication: Authentication,
        options: Options,
    ) !ChallengeAuthenticationPolicy {
        if (options.aad_scope.len == 0) return error.AadScopeRequired;
        if (options.api_version.len == 0) return error.ApiVersionRequired;
        if (options.expiry_skew_seconds < 0) return error.InvalidExpirySkew;

        const normalized_endpoint = try normalizeEndpoint(allocator, endpoint);
        errdefer allocator.free(normalized_endpoint);
        const endpoint_host = try extractHost(allocator, normalized_endpoint);
        errdefer allocator.free(endpoint_host);
        const expected_hosts = try copyExpectedHosts(
            allocator,
            endpoint_host,
            options.expected_hosts,
        );
        errdefer deinitStringSlice(allocator, expected_hosts);

        const tenant_id = if (options.tenant_id) |tenant|
            try allocator.dupe(u8, tenant)
        else
            null;
        errdefer if (tenant_id) |tenant| allocator.free(tenant);
        const aad_scope = try allocator.dupe(u8, options.aad_scope);
        errdefer allocator.free(aad_scope);
        const api_version = try allocator.dupe(u8, options.api_version);
        errdefer allocator.free(api_version);

        return .{
            .allocator = allocator,
            .endpoint = normalized_endpoint,
            .endpoint_host = endpoint_host,
            .expected_hosts = expected_hosts,
            .authentication = authentication,
            .tenant_id = tenant_id,
            .aad_scope = aad_scope,
            .api_version = api_version,
            .expiry_skew_seconds = options.expiry_skew_seconds,
            .time_source = options.time_source,
            .io = std.Io.Threaded.global_single_threaded.io(),
            .policy = .{
                .processFn = &processImpl,
                .prepareFn = &prepareImpl,
                .openFn = &openImpl,
            },
        };
    }

    /// Requires that no callers are using or waiting on this policy.
    pub fn deinit(self: *ChallengeAuthenticationPolicy) void {
        self.mutex.lockUncancelable(self.io);
        std.debug.assert(!self.refreshing);
        std.debug.assert(self.waiting_callers == 0);
        for (self.refresh_tokens.items) |*entry| entry.deinit(self.allocator);
        self.refresh_tokens.deinit(self.allocator);
        for (self.access_tokens.items) |*entry| entry.deinit(self.allocator);
        self.access_tokens.deinit(self.allocator);
        for (self.routes.items) |*entry| entry.deinit(self.allocator);
        self.routes.deinit(self.allocator);
        self.mutex.unlock(self.io);

        self.allocator.free(self.endpoint);
        self.allocator.free(self.endpoint_host);
        deinitStringSlice(self.allocator, self.expected_hosts);
        if (self.tenant_id) |tenant| self.allocator.free(tenant);
        self.allocator.free(self.aad_scope);
        self.allocator.free(self.api_version);
        self.* = undefined;
    }

    pub fn asPolicy(self: *ChallengeAuthenticationPolicy) *HttpPolicy {
        return &self.policy;
    }

    fn processImpl(
        policy: *HttpPolicy,
        request: *Request,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !Response {
        const self: *ChallengeAuthenticationPolicy =
            @alignCast(@fieldParentPtr("policy", policy));
        try self.validateRequestUrl(request.url);

        var known_challenge: ?BearerChallenge = null;
        defer if (known_challenge) |*challenge| challenge.deinit();
        var sdk_authorized = false;

        if (request.getHeader("Authorization") == null) {
            known_challenge = try self.findRoute(request);
            if (known_challenge) |*challenge| {
                const token = try self.acquireAccessToken(
                    challenge,
                    null,
                    final_transport,
                );
                defer self.allocator.free(token);
                try setBearerHeader(request, token);
                sdk_authorized = true;
            }
        }

        var response = try callNext(request, next, final_transport);
        if (response.status_code != 401) return response;

        if (!sdk_authorized and request.getHeader("Authorization") != null)
            return response;
        if (sdk_authorized) self.invalidateAccessToken(&known_challenge.?);

        var challenge = parseChallengeFromResponse(self.allocator, &response) catch |err| {
            response.deinit();
            return err;
        };
        defer challenge.deinit();
        self.validateChallenge(&challenge) catch |err| {
            response.deinit();
            return err;
        };
        self.storeRoute(request, &challenge) catch |err| {
            response.deinit();
            return err;
        };

        const token = self.acquireAccessToken(
            &challenge,
            null,
            final_transport,
        ) catch |err| {
            response.deinit();
            return err;
        };
        defer self.allocator.free(token);
        setBearerHeader(request, token) catch |err| {
            response.deinit();
            return err;
        };

        response.deinit();
        const replay = try callNext(request, next, final_transport);
        if (replay.status_code == 401) self.invalidateAccessToken(&challenge);
        return replay;
    }

    fn prepareImpl(policy: *HttpPolicy, request: *Request) !void {
        const self: *ChallengeAuthenticationPolicy =
            @alignCast(@fieldParentPtr("policy", policy));
        try self.validateRequestUrl(request.url);
    }

    fn openImpl(
        policy: *HttpPolicy,
        request: *Request,
        options: OpenOptions,
        next: []*HttpPolicy,
        final_transport: *HttpTransport,
    ) !*HttpOperation {
        const self: *ChallengeAuthenticationPolicy =
            @alignCast(@fieldParentPtr("policy", policy));
        try self.validateRequestUrl(request.url);
        try checkCancelled(options.cancellation);

        var known_challenge: ?BearerChallenge = null;
        defer if (known_challenge) |*challenge| challenge.deinit();
        var sdk_authorized = false;

        if (request.getHeader("Authorization") == null) {
            known_challenge = try self.findRoute(request);
            if (known_challenge) |*challenge| {
                const token = try self.acquireAccessToken(
                    challenge,
                    options.cancellation,
                    final_transport,
                );
                defer self.allocator.free(token);
                try setBearerHeader(request, token);
                sdk_authorized = true;
            }
        }

        var operation = try callNextOpen(
            request,
            options,
            next,
            final_transport,
        );
        if (operation.status_code != 401) return operation;

        if (!sdk_authorized and request.getHeader("Authorization") != null)
            return operation;
        if (sdk_authorized) self.invalidateAccessToken(&known_challenge.?);

        var challenge = parseChallengeFromResponse(self.allocator, operation) catch |err| {
            operation.deinit();
            return err;
        };
        defer challenge.deinit();
        self.validateChallenge(&challenge) catch |err| {
            operation.deinit();
            return err;
        };
        if (!options.isReplayable()) {
            operation.deinit();
            return error.RequestBodyNotReplayable;
        }
        try checkCancelled(options.cancellation);
        self.storeRoute(request, &challenge) catch |err| {
            operation.deinit();
            return err;
        };

        const token = self.acquireAccessToken(
            &challenge,
            options.cancellation,
            final_transport,
        ) catch |err| {
            operation.deinit();
            return err;
        };
        defer self.allocator.free(token);
        setBearerHeader(request, token) catch |err| {
            operation.deinit();
            return err;
        };

        var replay_options = options;
        if (replay_options.body) |*body| {
            body.rewind() catch |err| {
                operation.deinit();
                return err;
            };
        }
        try checkCancelled(options.cancellation);
        operation.deinit();
        operation = try callNextOpen(
            request,
            replay_options,
            next,
            final_transport,
        );
        if (operation.status_code == 401) self.invalidateAccessToken(&challenge);
        return operation;
    }

    fn acquireAccessToken(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        cancellation: ?*const CancellationToken,
        transport: *HttpTransport,
    ) ![]u8 {
        while (true) {
            try checkCancelled(cancellation);
            const current_time = self.now();
            self.mutex.lockUncancelable(self.io);
            if (self.findValidAccessTokenLocked(challenge, current_time)) |token| {
                const copy = self.allocator.dupe(u8, token) catch |err| {
                    self.mutex.unlock(self.io);
                    return err;
                };
                self.mutex.unlock(self.io);
                return copy;
            }
            if (self.refreshing) {
                if (cancellation == null) {
                    self.waiting_callers += 1;
                    self.refresh_finished.waitUncancelable(self.io, &self.mutex);
                    self.waiting_callers -= 1;
                    self.mutex.unlock(self.io);
                } else {
                    self.mutex.unlock(self.io);
                    while (true) {
                        try checkCancelled(cancellation);
                        self.io.sleep(.fromMilliseconds(1), .awake) catch {};
                        self.mutex.lockUncancelable(self.io);
                        if (!self.refreshing) {
                            self.mutex.unlock(self.io);
                            break;
                        }
                        self.mutex.unlock(self.io);
                    }
                }
                continue;
            }
            self.refreshing = true;
            self.mutex.unlock(self.io);
            break;
        }

        errdefer self.finishRefresh();
        const token = switch (self.authentication) {
            .anonymous => try self.exchangeAccessToken(
                challenge,
                "",
                .password,
                cancellation,
                transport,
            ),
            .credential => |credential| blk: {
                const refresh_token = try self.acquireRefreshToken(
                    challenge,
                    credential,
                    cancellation,
                    transport,
                );
                defer self.allocator.free(refresh_token);
                break :blk try self.exchangeAccessToken(
                    challenge,
                    refresh_token,
                    .refresh_token,
                    cancellation,
                    transport,
                );
            },
        };
        errdefer self.allocator.free(token);
        const expires_on = try jwtExpiry(self.allocator, token);
        if (!isTokenValid(expires_on, self.now(), self.expiry_skew_seconds))
            return error.AcrTokenExpired;

        self.mutex.lockUncancelable(self.io);
        self.storeAccessTokenLocked(challenge, token, expires_on) catch |err| {
            self.mutex.unlock(self.io);
            return err;
        };
        self.refreshing = false;
        self.refresh_finished.broadcast(self.io);
        self.mutex.unlock(self.io);
        return token;
    }

    fn acquireRefreshToken(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        credential: *core.credentials.TokenCredential,
        cancellation: ?*const CancellationToken,
        transport: *HttpTransport,
    ) ![]u8 {
        const current_time = self.now();
        self.mutex.lockUncancelable(self.io);
        if (self.findValidRefreshTokenLocked(challenge, current_time)) |token| {
            const copy = self.allocator.dupe(u8, token) catch |err| {
                self.mutex.unlock(self.io);
                return err;
            };
            self.mutex.unlock(self.io);
            return copy;
        }
        self.mutex.unlock(self.io);

        try checkCancelled(cancellation);
        const scopes = [_][]const u8{self.aad_scope};
        var aad_token = try credential.getToken(
            .{ .scopes = &scopes },
            core.context.Context.none,
        );
        defer aad_token.deinit();
        try checkCancelled(cancellation);

        const refresh_token = try self.exchangeRefreshToken(
            challenge,
            aad_token.token,
            cancellation,
            transport,
        );
        errdefer self.allocator.free(refresh_token);
        const expires_on = try jwtExpiry(self.allocator, refresh_token);
        if (!isTokenValid(expires_on, self.now(), self.expiry_skew_seconds))
            return error.AcrRefreshTokenExpired;

        self.mutex.lockUncancelable(self.io);
        self.storeRefreshTokenLocked(challenge, refresh_token, expires_on) catch |err| {
            self.mutex.unlock(self.io);
            return err;
        };
        self.mutex.unlock(self.io);
        return refresh_token;
    }

    fn exchangeRefreshToken(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        aad_token: []const u8,
        cancellation: ?*const CancellationToken,
        transport: *HttpTransport,
    ) ![]u8 {
        const url = try self.tokenUrl(challenge.realm, "/oauth2/exchange");
        defer self.allocator.free(url);

        var body: std.ArrayList(u8) = .empty;
        defer body.deinit(self.allocator);
        var first = true;
        try appendFormField(self.allocator, &body, &first, "grant_type", "access_token");
        try appendFormField(self.allocator, &body, &first, "service", challenge.service);
        if (self.effectiveTenant(challenge)) |tenant| {
            try appendFormField(self.allocator, &body, &first, "tenant", tenant);
        }
        try appendFormField(self.allocator, &body, &first, "access_token", aad_token);
        return self.sendTokenRequest(url, body.items, "refresh_token", cancellation, transport);
    }

    const AccessGrant = enum {
        refresh_token,
        password,
    };

    fn exchangeAccessToken(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        refresh_token: []const u8,
        grant: AccessGrant,
        cancellation: ?*const CancellationToken,
        transport: *HttpTransport,
    ) ![]u8 {
        const url = try self.tokenUrl(challenge.realm, "/oauth2/token");
        defer self.allocator.free(url);

        var body: std.ArrayList(u8) = .empty;
        defer body.deinit(self.allocator);
        var first = true;
        try appendFormField(self.allocator, &body, &first, "grant_type", @tagName(grant));
        try appendFormField(self.allocator, &body, &first, "service", challenge.service);
        try appendFormField(self.allocator, &body, &first, "scope", challenge.scope);
        try appendFormField(self.allocator, &body, &first, "refresh_token", refresh_token);
        return self.sendTokenRequest(url, body.items, "access_token", cancellation, transport);
    }

    fn sendTokenRequest(
        self: *ChallengeAuthenticationPolicy,
        url: []const u8,
        body: []const u8,
        response_field: []const u8,
        cancellation: ?*const CancellationToken,
        transport: *HttpTransport,
    ) ![]u8 {
        try checkCancelled(cancellation);
        var request = Request.init(self.allocator, .POST, url);
        defer request.deinit();
        request.body = body;
        request.redirect_policy = .not_allowed;
        try request.setHeader("Accept", "application/json");
        try request.setHeader("Content-Type", "application/x-www-form-urlencoded");

        var response = try transport.send(&request);
        defer response.deinit();
        try checkCancelled(cancellation);
        if (response.status_code != 200) return error.AcrTokenExchangeFailed;
        return parseTokenResponse(self.allocator, response.body, response_field);
    }

    fn validateRequestUrl(self: *ChallengeAuthenticationPolicy, url: []const u8) !void {
        const hosts: []const []const u8 = @ptrCast(self.expected_hosts);
        try core.url.validateHttpsUrl(url, hosts);
    }

    fn validateChallenge(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
    ) !void {
        const hosts: []const []const u8 = @ptrCast(self.expected_hosts);
        try core.url.validateHttpsUrl(challenge.realm, hosts);
        const realm_uri = std.Uri.parse(challenge.realm) catch return error.InvalidChallengeRealm;
        if (realm_uri.query != null or realm_uri.fragment != null)
            return error.InvalidChallengeRealm;
        const path = if (realm_uri.path.isEmpty()) "/" else switch (realm_uri.path) {
            .raw => |value| value,
            .percent_encoded => |value| value,
        };
        if (!std.mem.eql(u8, path, "/oauth2/token")) return error.InvalidChallengeRealm;

        const realm_host = try extractHost(self.allocator, challenge.realm);
        defer self.allocator.free(realm_host);
        if (!std.ascii.eqlIgnoreCase(realm_host, challenge.service))
            return error.UntrustedChallengeService;
        if (!hostExpected(hosts, challenge.service))
            return error.UntrustedChallengeService;
        if (challenge.tenant) |challenge_tenant| {
            if (challenge_tenant.len == 0) return error.InvalidChallengeTenant;
            if (self.tenant_id) |configured| {
                if (!std.mem.eql(u8, configured, challenge_tenant))
                    return error.UntrustedChallengeTenant;
            }
        }
    }

    fn findRoute(
        self: *ChallengeAuthenticationPolicy,
        request: *const Request,
    ) !?BearerChallenge {
        const route_url = requestRoute(request.url);
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        for (self.routes.items) |entry| {
            if (entry.method == request.method and std.mem.eql(u8, entry.url, route_url))
                return try entry.challenge.clone(self.allocator);
        }
        return null;
    }

    fn storeRoute(
        self: *ChallengeAuthenticationPolicy,
        request: *const Request,
        challenge: *const BearerChallenge,
    ) !void {
        const route_url = requestRoute(request.url);
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        for (self.routes.items) |*entry| {
            if (entry.method != request.method or !std.mem.eql(u8, entry.url, route_url))
                continue;
            const replacement = try challenge.clone(self.allocator);
            entry.challenge.deinit();
            entry.challenge = replacement;
            return;
        }

        const url_copy = try self.allocator.dupe(u8, route_url);
        errdefer self.allocator.free(url_copy);
        var challenge_copy = try challenge.clone(self.allocator);
        errdefer challenge_copy.deinit();
        try self.routes.append(self.allocator, .{
            .method = request.method,
            .url = url_copy,
            .challenge = challenge_copy,
        });
    }

    fn invalidateAccessToken(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
    ) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        var index: usize = 0;
        while (index < self.access_tokens.items.len) {
            if (accessKeyMatches(&self.access_tokens.items[index], challenge, self.effectiveTenant(challenge))) {
                var removed = self.access_tokens.swapRemove(index);
                removed.deinit(self.allocator);
            } else {
                index += 1;
            }
        }
    }

    fn findValidRefreshTokenLocked(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        current_time: i64,
    ) ?[]const u8 {
        for (self.refresh_tokens.items) |entry| {
            if (refreshKeyMatches(&entry, challenge, self.effectiveTenant(challenge)) and
                isTokenValid(entry.expires_on, current_time, self.expiry_skew_seconds))
            {
                return entry.token;
            }
        }
        return null;
    }

    fn findValidAccessTokenLocked(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        current_time: i64,
    ) ?[]const u8 {
        for (self.access_tokens.items) |entry| {
            if (accessKeyMatches(&entry, challenge, self.effectiveTenant(challenge)) and
                isTokenValid(entry.expires_on, current_time, self.expiry_skew_seconds))
            {
                return entry.token;
            }
        }
        return null;
    }

    fn storeRefreshTokenLocked(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        token: []const u8,
        expires_on: i64,
    ) !void {
        const tenant = self.effectiveTenant(challenge) orelse "";
        for (self.refresh_tokens.items) |*entry| {
            if (!refreshKeyMatches(entry, challenge, tenant)) continue;
            const replacement = try self.allocator.dupe(u8, token);
            self.allocator.free(entry.token);
            entry.token = replacement;
            entry.expires_on = expires_on;
            return;
        }

        const realm = try self.allocator.dupe(u8, challenge.realm);
        errdefer self.allocator.free(realm);
        const service = try self.allocator.dupe(u8, challenge.service);
        errdefer self.allocator.free(service);
        const tenant_copy = try self.allocator.dupe(u8, tenant);
        errdefer self.allocator.free(tenant_copy);
        const token_copy = try self.allocator.dupe(u8, token);
        errdefer self.allocator.free(token_copy);
        try self.refresh_tokens.append(self.allocator, .{
            .realm = realm,
            .service = service,
            .tenant = tenant_copy,
            .token = token_copy,
            .expires_on = expires_on,
        });
    }

    fn storeAccessTokenLocked(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        token: []const u8,
        expires_on: i64,
    ) !void {
        const tenant = self.effectiveTenant(challenge) orelse "";
        for (self.access_tokens.items) |*entry| {
            if (!accessKeyMatches(entry, challenge, tenant)) continue;
            const replacement = try self.allocator.dupe(u8, token);
            self.allocator.free(entry.token);
            entry.token = replacement;
            entry.expires_on = expires_on;
            return;
        }

        const realm = try self.allocator.dupe(u8, challenge.realm);
        errdefer self.allocator.free(realm);
        const service = try self.allocator.dupe(u8, challenge.service);
        errdefer self.allocator.free(service);
        const tenant_copy = try self.allocator.dupe(u8, tenant);
        errdefer self.allocator.free(tenant_copy);
        const scope = try self.allocator.dupe(u8, challenge.scope);
        errdefer self.allocator.free(scope);
        const token_copy = try self.allocator.dupe(u8, token);
        errdefer self.allocator.free(token_copy);
        try self.access_tokens.append(self.allocator, .{
            .realm = realm,
            .service = service,
            .tenant = tenant_copy,
            .scope = scope,
            .token = token_copy,
            .expires_on = expires_on,
        });
    }

    fn finishRefresh(self: *ChallengeAuthenticationPolicy) void {
        self.mutex.lockUncancelable(self.io);
        self.refreshing = false;
        self.refresh_finished.broadcast(self.io);
        self.mutex.unlock(self.io);
    }

    fn effectiveTenant(
        self: *const ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
    ) ?[]const u8 {
        return challenge.tenant orelse self.tenant_id;
    }

    fn tokenUrl(
        self: *ChallengeAuthenticationPolicy,
        realm: []const u8,
        path: []const u8,
    ) ![]u8 {
        const parsed = try core.url.Url.parse(realm);
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(self.allocator);
        try output.print(self.allocator, "{s}://{s}", .{ parsed.scheme, parsed.host });
        if (parsed.port) |port| try output.print(self.allocator, ":{d}", .{port});
        try output.appendSlice(self.allocator, path);
        try output.appendSlice(self.allocator, "?api-version=");
        const encoded = try core.url.percentEncode(self.allocator, self.api_version);
        defer self.allocator.free(encoded);
        try output.appendSlice(self.allocator, encoded);
        return output.toOwnedSlice(self.allocator);
    }

    fn now(self: *const ChallengeAuthenticationPolicy) i64 {
        if (self.time_source) |source| return source.now();
        var threaded: std.Io.Threaded = .init_single_threaded;
        return std.Io.Timestamp.now(threaded.io(), .real).toSeconds();
    }
};

fn callNext(
    request: *Request,
    next: []*HttpPolicy,
    final_transport: *HttpTransport,
) !Response {
    if (next.len == 0) return final_transport.send(request);
    return next[0].process(request, next[1..], final_transport);
}

fn callNextOpen(
    request: *Request,
    options: OpenOptions,
    next: []*HttpPolicy,
    final_transport: *HttpTransport,
) !*HttpOperation {
    if (next.len == 0) return final_transport.open(request, options);
    return next[0].open(request, options, next[1..], final_transport);
}

fn parseChallengeFromResponse(
    allocator: std.mem.Allocator,
    response: anytype,
) !BearerChallenge {
    const values = try response.getHeaderValues(allocator, "WWW-Authenticate");
    defer allocator.free(values);
    return challenge_mod.parseBearerChallenge(allocator, values);
}

fn normalizeEndpoint(allocator: std.mem.Allocator, endpoint: []const u8) ![]u8 {
    try core.url.validateHttpsUrl(endpoint, &.{});
    const uri = std.Uri.parse(endpoint) catch return error.InvalidRegistryEndpoint;
    if (uri.query != null or uri.fragment != null) return error.InvalidRegistryEndpoint;
    const path = if (uri.path.isEmpty()) "" else switch (uri.path) {
        .raw => |value| value,
        .percent_encoded => |value| value,
    };
    if (path.len != 0 and !std.mem.eql(u8, path, "/"))
        return error.InvalidRegistryEndpoint;
    return allocator.dupe(u8, if (std.mem.endsWith(u8, endpoint, "/"))
        endpoint[0 .. endpoint.len - 1]
    else
        endpoint);
}

fn extractHost(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    const uri = std.Uri.parse(raw) catch return error.InvalidUrl;
    if (uri.host == null) return error.InvalidUrl;
    var buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = uri.getHost(&buffer) catch return error.InvalidUrl;
    return allocator.dupe(u8, host.bytes);
}

fn copyExpectedHosts(
    allocator: std.mem.Allocator,
    endpoint_host: []const u8,
    additional: []const []const u8,
) ![][]u8 {
    const hosts = try allocator.alloc([]u8, additional.len + 1);
    errdefer allocator.free(hosts);
    var initialized: usize = 0;
    errdefer {
        for (hosts[0..initialized]) |host| allocator.free(host);
    }

    hosts[0] = try allocator.dupe(u8, endpoint_host);
    initialized += 1;
    for (additional, 0..) |host, index| {
        try validateExpectedHost(host);
        hosts[index + 1] = try allocator.dupe(u8, host);
        initialized += 1;
    }
    return hosts;
}

fn validateExpectedHost(host: []const u8) !void {
    if (host.len == 0) return error.InvalidExpectedHost;
    for (host) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '-') continue;
        return error.InvalidExpectedHost;
    }
}

fn deinitStringSlice(allocator: std.mem.Allocator, values: [][]u8) void {
    for (values) |value| allocator.free(value);
    allocator.free(values);
}

fn hostExpected(hosts: []const []const u8, value: []const u8) bool {
    for (hosts) |host| {
        if (std.ascii.eqlIgnoreCase(host, value)) return true;
    }
    return false;
}

fn requestRoute(url: []const u8) []const u8 {
    const query = std.mem.indexOfScalar(u8, url, '?') orelse url.len;
    return url[0..query];
}

fn refreshKeyMatches(
    entry: *const RefreshTokenEntry,
    challenge: *const BearerChallenge,
    tenant: ?[]const u8,
) bool {
    return std.mem.eql(u8, entry.realm, challenge.realm) and
        std.mem.eql(u8, entry.service, challenge.service) and
        std.mem.eql(u8, entry.tenant, tenant orelse "");
}

fn accessKeyMatches(
    entry: *const AccessTokenEntry,
    challenge: *const BearerChallenge,
    tenant: ?[]const u8,
) bool {
    return std.mem.eql(u8, entry.realm, challenge.realm) and
        std.mem.eql(u8, entry.service, challenge.service) and
        std.mem.eql(u8, entry.tenant, tenant orelse "") and
        std.mem.eql(u8, entry.scope, challenge.scope);
}

fn isTokenValid(expires_on: i64, now: i64, skew: i64) bool {
    return expires_on > now and now < expires_on -| skew;
}

fn setBearerHeader(request: *Request, token: []const u8) !void {
    const value = try std.fmt.allocPrint(request.allocator, "Bearer {s}", .{token});
    defer request.allocator.free(value);
    try request.setHeader("Authorization", value);
}

fn appendFormField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    first: *bool,
    key: []const u8,
    value: []const u8,
) !void {
    if (!first.*) try output.append(allocator, '&');
    first.* = false;
    try formEncodeAppend(allocator, output, key);
    try output.append(allocator, '=');
    try formEncodeAppend(allocator, output, value);
}

fn formEncodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: []const u8,
) !void {
    const hex = "0123456789ABCDEF";
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or
            byte == '-' or byte == '.' or byte == '_' or byte == '*')
        {
            try output.append(allocator, byte);
        } else if (byte == ' ') {
            try output.append(allocator, '+');
        } else {
            try output.append(allocator, '%');
            try output.append(allocator, hex[byte >> 4]);
            try output.append(allocator, hex[byte & 0x0f]);
        }
    }
}

fn parseTokenResponse(
    allocator: std.mem.Allocator,
    body: []const u8,
    field: []const u8,
) ![]u8 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch
        return error.InvalidAcrTokenResponse;
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidAcrTokenResponse;
    const token = parsed.value.object.get(field) orelse
        return error.InvalidAcrTokenResponse;
    if (token != .string or token.string.len == 0)
        return error.InvalidAcrTokenResponse;
    return allocator.dupe(u8, token.string);
}

fn jwtExpiry(allocator: std.mem.Allocator, token: []const u8) !i64 {
    const first_dot = std.mem.indexOfScalar(u8, token, '.') orelse
        return error.InvalidAcrToken;
    const rest = token[first_dot + 1 ..];
    const second_dot = std.mem.indexOfScalar(u8, rest, '.') orelse
        return error.InvalidAcrToken;
    var payload = rest[0..second_dot];
    while (payload.len > 0 and payload[payload.len - 1] == '=')
        payload = payload[0 .. payload.len - 1];
    if (payload.len == 0) return error.InvalidAcrToken;

    const decoded = core.base64.urlDecode(allocator, payload) catch
        return error.InvalidAcrToken;
    defer allocator.free(decoded);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, decoded, .{}) catch
        return error.InvalidAcrToken;
    defer parsed.deinit();
    if (parsed.value != .object) return error.InvalidAcrToken;
    const expires = parsed.value.object.get("exp") orelse return error.InvalidAcrToken;
    if (expires != .integer or expires.integer <= 0) return error.InvalidAcrToken;
    return expires.integer;
}

fn checkCancelled(cancellation: ?*const CancellationToken) !void {
    if (cancellation) |token| {
        if (token.isCancelled()) return error.OperationCancelled;
    }
}

const TestClock = struct {
    value: i64,

    fn source(self: *TestClock) TimeSource {
        return .{ .context = self, .nowFn = &now };
    }

    fn now(context: *anyopaque) i64 {
        const self: *TestClock = @ptrCast(@alignCast(context));
        return self.value;
    }
};

const TestCredential = struct {
    credential: core.credentials.TokenCredential,
    calls: std.atomic.Value(usize) = .init(0),
    token: []const u8 = "aad-token",
    fail: bool = false,
    entered: ?*std.Io.Semaphore = null,
    release: ?*std.Io.Semaphore = null,

    fn init() TestCredential {
        return .{ .credential = .{ .getTokenFn = &getToken } };
    }

    fn getToken(
        credential: *core.credentials.TokenCredential,
        _: core.credentials.TokenRequestContext,
        _: core.context.Context,
    ) anyerror!core.credentials.AccessToken {
        const self: *TestCredential =
            @alignCast(@fieldParentPtr("credential", credential));
        _ = self.calls.fetchAdd(1, .monotonic);
        const io = std.Io.Threaded.global_single_threaded.io();
        if (self.entered) |entered| entered.post(io);
        if (self.release) |release| release.waitUncancelable(io);
        if (self.fail) return error.MockCredentialFailure;
        return .{ .token = self.token, .expires_on = 10_000 };
    }
};

fn makeJwt(
    allocator: std.mem.Allocator,
    expires_on: i64,
    marker: []const u8,
) ![]u8 {
    const payload = try std.fmt.allocPrint(
        allocator,
        "{{\"exp\":{d},\"jti\":\"{s}\"}}",
        .{ expires_on, marker },
    );
    defer allocator.free(payload);
    const encoded = try core.base64.urlEncode(allocator, payload);
    defer allocator.free(encoded);
    return std.fmt.allocPrint(allocator, "e30.{s}.signature", .{encoded});
}

fn makeTokenResponse(
    allocator: std.mem.Allocator,
    field: []const u8,
    token: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(allocator, "{{\"{s}\":\"{s}\"}}", .{ field, token });
}

fn makeChallenge(
    allocator: std.mem.Allocator,
    realm: []const u8,
    service: []const u8,
    scope: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "Bearer realm=\"{s}\",service=\"{s}\",scope=\"{s}\"",
        .{ realm, service, scope },
    );
}

fn capturedUrl(
    transport: *const core.http.SequenceMockTransport,
    index: usize,
) []const u8 {
    return transport.captured_urls[index][0..transport.captured_url_lengths[index]];
}

fn capturedBody(
    transport: *const core.http.SequenceMockTransport,
    index: usize,
) []const u8 {
    return transport.captured_bodies[index][0..transport.captured_body_lengths[index]];
}

fn countCapturedUrl(
    transport: *const core.http.SequenceMockTransport,
    needle: []const u8,
) usize {
    var count: usize = 0;
    for (0..transport.call_count) |index| {
        if (std.mem.indexOf(u8, capturedUrl(transport, index), needle) != null)
            count += 1;
    }
    return count;
}

fn sendBuffered(
    allocator: std.mem.Allocator,
    policy: *ChallengeAuthenticationPolicy,
    transport: *HttpTransport,
    method: core.http.Method,
    url: []const u8,
) !Response {
    var policies = [_]*HttpPolicy{policy.asPolicy()};
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &policies,
        .transport_impl = transport,
    };
    var request = Request.init(allocator, method, url);
    defer request.deinit();
    return pipeline.send(&request);
}

test "authenticated challenge flow uses form encoding and caches both tokens" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    credential.token = "aad token+secret";

    const refresh_token = try makeJwt(allocator, 4_000, "refresh");
    defer allocator.free(refresh_token);
    const access_token = try makeJwt(allocator, 2_000, "access");
    defer allocator.free(access_token);
    const refresh_body = try makeTokenResponse(
        allocator,
        "refresh_token",
        refresh_token,
    );
    defer allocator.free(refresh_body);
    const access_body = try makeTokenResponse(allocator, "access_token", access_token);
    defer allocator.free(access_body);
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:team/image:pull",
    );
    defer allocator.free(challenge);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{ .status = 200, .body = refresh_body },
        .{ .status = 200, .body = access_body },
        .{ .status = 200, .body = "{}" },
        .{ .status = 200, .body = "{}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{
            .tenant_id = "tenant one",
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer policy.deinit();

    var first = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/team/image/manifests/latest",
    );
    defer first.deinit();
    try std.testing.expectEqual(@as(u16, 200), first.status_code);
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expect(!transport.captured_authorization[0]);
    try std.testing.expect(transport.captured_authorization[3]);
    try std.testing.expect(transport.captured_content_type[1]);
    try std.testing.expect(transport.captured_content_type[2]);
    try std.testing.expectEqualStrings(
        "grant_type=access_token&service=registry.example&tenant=tenant+one&access_token=aad+token%2Bsecret",
        capturedBody(&transport, 1),
    );
    try std.testing.expect(std.mem.startsWith(
        u8,
        capturedBody(&transport, 2),
        "grant_type=refresh_token&service=registry.example&scope=repository%3Ateam%2Fimage%3Apull&refresh_token=",
    ));

    var second = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/team/image/manifests/latest?reference=other",
    );
    defer second.deinit();
    try std.testing.expectEqual(@as(u16, 200), second.status_code);
    try std.testing.expectEqual(@as(usize, 5), transport.call_count);
    try std.testing.expect(transport.captured_authorization[4]);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expectEqual(
        @as(usize, 1),
        countCapturedUrl(&transport, "/oauth2/exchange"),
    );
    try std.testing.expectEqual(
        @as(usize, 1),
        countCapturedUrl(&transport, "/oauth2/token"),
    );
}

test "explicit anonymous mode obtains an anonymous scoped token" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    const access_token = try makeJwt(allocator, 2_000, "anonymous");
    defer allocator.free(access_token);
    const access_body = try makeTokenResponse(allocator, "access_token", access_token);
    defer allocator.free(access_body);
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "registry:catalog:*",
    );
    defer allocator.free(challenge);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{ .status = 200, .body = access_body },
        .{ .status = 200, .body = "{}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .anonymous,
        .{
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer policy.deinit();

    var response = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/_catalog",
    );
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expectEqual(
        @as(usize, 0),
        countCapturedUrl(&transport, "/oauth2/exchange"),
    );
    try std.testing.expectEqualStrings(
        "grant_type=password&service=registry.example&scope=registry%3Acatalog%3A*&refresh_token=",
        capturedBody(&transport, 1),
    );
}

test "authenticated credential failures never downgrade to anonymous" {
    const allocator = std.testing.allocator;
    var credential = TestCredential.init();
    credential.fail = true;
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "registry:catalog:*",
    );
    defer allocator.free(challenge);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{ .expiry_skew_seconds = 10 },
    );
    defer policy.deinit();

    try std.testing.expectError(
        error.MockCredentialFailure,
        sendBuffered(
            allocator,
            &policy,
            transport.asTransport(),
            .GET,
            "https://registry.example/v2/_catalog",
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
}

test "expired refresh and access tokens are refreshed before sending" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    const refresh_one = try makeJwt(allocator, 2_000, "refresh-one");
    defer allocator.free(refresh_one);
    const access_one = try makeJwt(allocator, 1_500, "access-one");
    defer allocator.free(access_one);
    const refresh_two = try makeJwt(allocator, 5_000, "refresh-two");
    defer allocator.free(refresh_two);
    const access_two = try makeJwt(allocator, 4_000, "access-two");
    defer allocator.free(access_two);
    const refresh_one_body = try makeTokenResponse(allocator, "refresh_token", refresh_one);
    defer allocator.free(refresh_one_body);
    const access_one_body = try makeTokenResponse(allocator, "access_token", access_one);
    defer allocator.free(access_one_body);
    const refresh_two_body = try makeTokenResponse(allocator, "refresh_token", refresh_two);
    defer allocator.free(refresh_two_body);
    const access_two_body = try makeTokenResponse(allocator, "access_token", access_two);
    defer allocator.free(access_two_body);
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
    );
    defer allocator.free(challenge);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{ .status = 200, .body = refresh_one_body },
        .{ .status = 200, .body = access_one_body },
        .{ .status = 200, .body = "{}" },
        .{ .status = 200, .body = refresh_two_body },
        .{ .status = 200, .body = access_two_body },
        .{ .status = 200, .body = "{}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer policy.deinit();

    var first = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/one/manifests/latest",
    );
    first.deinit();
    clock.value = 2_500;
    var second = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/one/manifests/latest",
    );
    defer second.deinit();

    try std.testing.expectEqual(@as(usize, 7), transport.call_count);
    try std.testing.expectEqual(@as(usize, 2), credential.calls.load(.monotonic));
    try std.testing.expectEqual(
        @as(usize, 2),
        countCapturedUrl(&transport, "/oauth2/exchange"),
    );
    try std.testing.expectEqual(
        @as(usize, 2),
        countCapturedUrl(&transport, "/oauth2/token"),
    );
    try std.testing.expect(transport.captured_authorization[6]);
}

test "401 invalidates one scoped access token and replays exactly once" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    const refresh_token = try makeJwt(allocator, 5_000, "refresh");
    defer allocator.free(refresh_token);
    const access_one = try makeJwt(allocator, 3_000, "access-one");
    defer allocator.free(access_one);
    const access_two = try makeJwt(allocator, 3_000, "access-two");
    defer allocator.free(access_two);
    const refresh_body = try makeTokenResponse(allocator, "refresh_token", refresh_token);
    defer allocator.free(refresh_body);
    const access_one_body = try makeTokenResponse(allocator, "access_token", access_one);
    defer allocator.free(access_one_body);
    const access_two_body = try makeTokenResponse(allocator, "access_token", access_two);
    defer allocator.free(access_two_body);
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
    );
    defer allocator.free(challenge);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{ .status = 200, .body = refresh_body },
        .{ .status = 200, .body = access_one_body },
        .{ .status = 200, .body = "{}" },
        .{ .status = 401, .body = "", .headers = &headers },
        .{ .status = 200, .body = access_two_body },
        .{ .status = 200, .body = "{}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer policy.deinit();

    var first = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/one/manifests/latest",
    );
    first.deinit();
    var second = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/one/manifests/latest",
    );
    defer second.deinit();

    try std.testing.expectEqual(@as(u16, 200), second.status_code);
    try std.testing.expectEqual(@as(usize, 7), transport.call_count);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expectEqual(
        @as(usize, 1),
        countCapturedUrl(&transport, "/oauth2/exchange"),
    );
    try std.testing.expectEqual(
        @as(usize, 2),
        countCapturedUrl(&transport, "/oauth2/token"),
    );
}

test "repository scopes use isolated access token cache entries" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    const refresh_token = try makeJwt(allocator, 5_000, "refresh");
    defer allocator.free(refresh_token);
    const access_one = try makeJwt(allocator, 3_000, "access-one");
    defer allocator.free(access_one);
    const access_two = try makeJwt(allocator, 3_000, "access-two");
    defer allocator.free(access_two);
    const refresh_body = try makeTokenResponse(allocator, "refresh_token", refresh_token);
    defer allocator.free(refresh_body);
    const access_one_body = try makeTokenResponse(allocator, "access_token", access_one);
    defer allocator.free(access_one_body);
    const access_two_body = try makeTokenResponse(allocator, "access_token", access_two);
    defer allocator.free(access_two_body);
    const challenge_one = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
    );
    defer allocator.free(challenge_one);
    const challenge_two = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:two:pull",
    );
    defer allocator.free(challenge_two);
    const headers_one = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge_one },
    };
    const headers_two = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge_two },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers_one },
        .{ .status = 200, .body = refresh_body },
        .{ .status = 200, .body = access_one_body },
        .{ .status = 200, .body = "{}" },
        .{ .status = 401, .body = "", .headers = &headers_two },
        .{ .status = 200, .body = access_two_body },
        .{ .status = 200, .body = "{}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer policy.deinit();

    var one = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/one/manifests/latest",
    );
    one.deinit();
    var two = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/two/manifests/latest",
    );
    defer two.deinit();

    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expectEqual(
        @as(usize, 1),
        countCapturedUrl(&transport, "/oauth2/exchange"),
    );
    try std.testing.expectEqual(
        @as(usize, 2),
        countCapturedUrl(&transport, "/oauth2/token"),
    );
    try std.testing.expect(std.mem.indexOf(
        u8,
        capturedBody(&transport, 2),
        "scope=repository%3Aone%3Apull",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        capturedBody(&transport, 5),
        "scope=repository%3Atwo%3Apull",
    ) != null);
}

test "concurrent token acquisition is single flight" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var entered: std.Io.Semaphore = .{};
    var release: std.Io.Semaphore = .{};
    var credential = TestCredential.init();
    credential.entered = &entered;
    credential.release = &release;
    const refresh_token = try makeJwt(allocator, 5_000, "refresh");
    defer allocator.free(refresh_token);
    const access_token = try makeJwt(allocator, 3_000, "access");
    defer allocator.free(access_token);
    const refresh_body = try makeTokenResponse(allocator, "refresh_token", refresh_token);
    defer allocator.free(refresh_body);
    const access_body = try makeTokenResponse(allocator, "access_token", access_token);
    defer allocator.free(access_body);
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body = refresh_body },
        .{ .status = 200, .body = access_body },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer policy.deinit();
    const values = [_][]const u8{
        "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"repository:one:pull\"",
    };
    var challenge = try challenge_mod.parseBearerChallenge(allocator, &values);
    defer challenge.deinit();

    const AcquireContext = struct {
        policy: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        transport: *HttpTransport,
        token: ?[]u8 = null,
        err: ?anyerror = null,

        fn run(self: *@This()) void {
            self.token = self.policy.acquireAccessToken(
                self.challenge,
                null,
                self.transport,
            ) catch |err| {
                self.err = err;
                return;
            };
        }
    };

    var first = AcquireContext{
        .policy = &policy,
        .challenge = &challenge,
        .transport = transport.asTransport(),
    };
    var second = first;
    const first_thread = try std.Thread.spawn(.{}, AcquireContext.run, .{&first});
    const io = std.Io.Threaded.global_single_threaded.io();
    entered.waitUncancelable(io);
    const second_thread = std.Thread.spawn(.{}, AcquireContext.run, .{&second}) catch |err| {
        release.post(io);
        first_thread.join();
        return err;
    };
    while (true) {
        policy.mutex.lockUncancelable(policy.io);
        const waiting = policy.waiting_callers;
        policy.mutex.unlock(policy.io);
        if (waiting > 0) break;
        io.sleep(.fromMilliseconds(1), .awake) catch {};
    }
    release.post(io);
    first_thread.join();
    second_thread.join();
    if (first.token) |token| allocator.free(token);
    if (second.token) |token| allocator.free(token);
    try std.testing.expect(first.err == null);
    try std.testing.expect(second.err == null);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
}

test "untrusted request and challenge hosts never receive tokens" {
    const allocator = std.testing.allocator;
    var credential = TestCredential.init();
    const unused = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body = "{}" },
    };
    var untrusted_transport = core.http.SequenceMockTransport.init(allocator, &unused);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{},
    );
    defer policy.deinit();
    try std.testing.expectError(
        error.UnexpectedHost,
        sendBuffered(
            allocator,
            &policy,
            untrusted_transport.asTransport(),
            .GET,
            "https://evil.example/v2/_catalog",
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), untrusted_transport.call_count);

    const malicious = try makeChallenge(
        allocator,
        "https://evil.example/oauth2/token",
        "evil.example",
        "registry:catalog:*",
    );
    defer allocator.free(malicious);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = malicious },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
    };
    var malicious_transport = core.http.SequenceMockTransport.init(allocator, &responses);
    try std.testing.expectError(
        error.UnexpectedHost,
        sendBuffered(
            allocator,
            &policy,
            malicious_transport.asTransport(),
            .GET,
            "https://registry.example/v2/_catalog",
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), malicious_transport.call_count);
    try std.testing.expectEqual(@as(usize, 0), credential.calls.load(.monotonic));
}

test "token bootstrap redirects cannot forward AAD credentials" {
    const allocator = std.testing.allocator;
    var credential = TestCredential.init();
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "registry:catalog:*",
    );
    defer allocator.free(challenge);
    const challenge_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const redirect_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "Location", .value = "https://evil.example/steal" },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &challenge_headers },
        .{ .status = 302, .body = "", .headers = &redirect_headers },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{},
    );
    defer policy.deinit();

    try std.testing.expectError(
        error.AcrTokenExchangeFailed,
        sendBuffered(
            allocator,
            &policy,
            transport.asTransport(),
            .GET,
            "https://registry.example/v2/_catalog",
        ),
    );
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
    try std.testing.expectEqualStrings(
        "https://registry.example/oauth2/exchange?api-version=2021-07-01",
        capturedUrl(&transport, 1),
    );
}

test "refresh token cache keys include the challenge tenant" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    const refresh_one = try makeJwt(allocator, 5_000, "refresh-one");
    defer allocator.free(refresh_one);
    const access_one = try makeJwt(allocator, 3_000, "access-one");
    defer allocator.free(access_one);
    const refresh_two = try makeJwt(allocator, 5_000, "refresh-two");
    defer allocator.free(refresh_two);
    const access_two = try makeJwt(allocator, 3_000, "access-two");
    defer allocator.free(access_two);
    const refresh_one_body = try makeTokenResponse(allocator, "refresh_token", refresh_one);
    defer allocator.free(refresh_one_body);
    const access_one_body = try makeTokenResponse(allocator, "access_token", access_one);
    defer allocator.free(access_one_body);
    const refresh_two_body = try makeTokenResponse(allocator, "refresh_token", refresh_two);
    defer allocator.free(refresh_two_body);
    const access_two_body = try makeTokenResponse(allocator, "access_token", access_two);
    defer allocator.free(access_two_body);
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body = refresh_one_body },
        .{ .status = 200, .body = access_one_body },
        .{ .status = 200, .body = refresh_two_body },
        .{ .status = 200, .body = access_two_body },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer policy.deinit();
    const first_values = [_][]const u8{
        "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"repository:one:pull\",tenant=\"tenant-one\"",
    };
    const second_values = [_][]const u8{
        "Bearer realm=\"https://registry.example/oauth2/token\",service=\"registry.example\",scope=\"repository:one:pull\",tenant=\"tenant-two\"",
    };
    var first = try challenge_mod.parseBearerChallenge(allocator, &first_values);
    defer first.deinit();
    var second = try challenge_mod.parseBearerChallenge(allocator, &second_values);
    defer second.deinit();
    try policy.validateChallenge(&first);
    try policy.validateChallenge(&second);

    const first_token = try policy.acquireAccessToken(
        &first,
        null,
        transport.asTransport(),
    );
    defer allocator.free(first_token);
    const second_token = try policy.acquireAccessToken(
        &second,
        null,
        transport.asTransport(),
    );
    defer allocator.free(second_token);

    try std.testing.expectEqual(@as(usize, 2), credential.calls.load(.monotonic));
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
    try std.testing.expect(std.mem.indexOf(
        u8,
        capturedBody(&transport, 0),
        "tenant=tenant-one",
    ) != null);
    try std.testing.expect(std.mem.indexOf(
        u8,
        capturedBody(&transport, 2),
        "tenant=tenant-two",
    ) != null);
}

test "a replayed 401 is returned without a second replay" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    const refresh_token = try makeJwt(allocator, 5_000, "refresh");
    defer allocator.free(refresh_token);
    const access_token = try makeJwt(allocator, 3_000, "access");
    defer allocator.free(access_token);
    const refresh_body = try makeTokenResponse(allocator, "refresh_token", refresh_token);
    defer allocator.free(refresh_body);
    const access_body = try makeTokenResponse(allocator, "access_token", access_token);
    defer allocator.free(access_body);
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "registry:catalog:*",
    );
    defer allocator.free(challenge);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{ .status = 200, .body = refresh_body },
        .{ .status = 200, .body = access_body },
        .{ .status = 401, .body = "", .headers = &headers },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer policy.deinit();

    var response = try sendBuffered(
        allocator,
        &policy,
        transport.asTransport(),
        .GET,
        "https://registry.example/v2/_catalog",
    );
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 401), response.status_code);
    try std.testing.expectEqual(@as(usize, 4), transport.call_count);
}

test "non-rewindable streaming bodies are not replayed" {
    const allocator = std.testing.allocator;
    var credential = TestCredential.init();
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:push",
    );
    defer allocator.free(challenge);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &credential.credential },
        .{},
    );
    defer policy.deinit();
    var policies = [_]*HttpPolicy{policy.asPolicy()};
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &policies,
        .transport_impl = transport.asTransport(),
    };
    var request = Request.init(
        allocator,
        .PATCH,
        "https://registry.example/v2/one/blobs/uploads/id",
    );
    defer request.deinit();
    var reader = std.Io.Reader.fixed("data");
    try std.testing.expectError(
        error.RequestBodyNotReplayable,
        pipeline.open(
            &request,
            .{ .body = core.http.StreamingRequestBody.knownLength(&reader, 4) },
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), transport.call_count);
    try std.testing.expectEqual(@as(usize, 0), credential.calls.load(.monotonic));
}

test "rewindable streaming bodies are replayed once after authentication" {
    const allocator = std.testing.allocator;
    const access_token = try makeJwt(allocator, 4_102_444_800, "anonymous");
    defer allocator.free(access_token);
    const access_body = try makeTokenResponse(allocator, "access_token", access_token);
    defer allocator.free(access_body);
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:push",
    );
    defer allocator.free(challenge);
    const headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = challenge },
    };
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &headers },
        .{ .status = 200, .body = access_body },
        .{ .status = 200, .body = "ok" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .anonymous,
        .{},
    );
    defer policy.deinit();
    var policies = [_]*HttpPolicy{policy.asPolicy()};
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &policies,
        .transport_impl = transport.asTransport(),
    };
    var request = Request.init(
        allocator,
        .PATCH,
        "https://registry.example/v2/one/blobs/uploads/id",
    );
    defer request.deinit();
    var replayable = core.http.ReplayableBytes.init("data");
    var operation = try pipeline.open(&request, .{ .body = replayable.body() });
    defer operation.deinit();
    try std.testing.expectEqual(@as(u16, 200), operation.status_code);
    try operation.finish();
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expectEqualStrings("data", capturedBody(&transport, 0));
    try std.testing.expectEqualStrings("data", capturedBody(&transport, 2));
    try std.testing.expect(transport.captured_authorization[2]);
}

test "streaming cancellation is preserved before transport" {
    const allocator = std.testing.allocator;
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body = "{}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .anonymous,
        .{},
    );
    defer policy.deinit();
    var policies = [_]*HttpPolicy{policy.asPolicy()};
    var pipeline = core.pipeline.HttpPipeline{
        .policies = &policies,
        .transport_impl = transport.asTransport(),
    };
    var request = Request.init(allocator, .GET, "https://registry.example/v2/_catalog");
    defer request.deinit();
    var cancellation = CancellationToken{};
    cancellation.cancel();
    try std.testing.expectError(
        error.OperationCancelled,
        pipeline.open(&request, .{ .cancellation = &cancellation }),
    );
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}
