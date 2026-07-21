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
// Small fixed LRU bounds keep cache scans predictable for long-lived clients.
const max_refresh_token_entries: usize = 32;
const max_access_token_entries: usize = 128;
const max_route_entries: usize = 128;

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
    /// Additional trusted HTTPS origins. A hostname implies port 443; use an
    /// absolute origin such as `https://registry.example:8443` for another
    /// port.
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
    last_used: u64,

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
    last_used: u64,

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
    last_used: u64,

    fn deinit(self: *RouteEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        self.challenge.deinit();
        self.* = undefined;
    }
};

const TrustedOrigin = struct {
    host: []u8,
    port: u16,

    fn deinit(self: *TrustedOrigin, allocator: std.mem.Allocator) void {
        allocator.free(self.host);
        self.* = undefined;
    }
};

const FlightKind = enum {
    refresh,
    access,
};

const FlightState = enum {
    running,
    succeeded,
    failed,
};

const TokenFlight = struct {
    kind: FlightKind,
    realm: []u8,
    service: []u8,
    tenant: []u8,
    scope: []u8,
    condition: std.Io.Condition = .init,
    state: FlightState = .running,
    participants: usize = 1,
    token: ?[]u8 = null,
    failure: ?anyerror = null,

    fn init(
        allocator: std.mem.Allocator,
        kind: FlightKind,
        realm_value: []const u8,
        service_value: []const u8,
        tenant_value: []const u8,
        scope_value: []const u8,
    ) !TokenFlight {
        const realm = try allocator.dupe(u8, realm_value);
        errdefer allocator.free(realm);
        const service = try allocator.dupe(u8, service_value);
        errdefer allocator.free(service);
        const tenant = try allocator.dupe(u8, tenant_value);
        errdefer allocator.free(tenant);
        const scope = try allocator.dupe(u8, scope_value);
        errdefer allocator.free(scope);
        return .{
            .kind = kind,
            .realm = realm,
            .service = service,
            .tenant = tenant,
            .scope = scope,
        };
    }

    fn deinit(self: *TokenFlight, allocator: std.mem.Allocator) void {
        allocator.free(self.realm);
        allocator.free(self.service);
        allocator.free(self.tenant);
        allocator.free(self.scope);
        if (self.token) |token| allocator.free(token);
        self.* = undefined;
    }
};

/// ACR Bearer challenge policy. The policy validates every destination before
/// sending, performs token bootstrap calls without redirects, and replays a
/// challenged request at most once. Concurrent use requires thread-safe
/// allocator, credential, and clock dependencies.
pub const ChallengeAuthenticationPolicy = struct {
    allocator: std.mem.Allocator,
    endpoint: []u8,
    trusted_origins: []TrustedOrigin,
    authentication: Authentication,
    tenant_id: ?[]u8,
    aad_scope: []u8,
    api_version: []u8,
    expiry_skew_seconds: i64,
    time_source: ?TimeSource,
    io: std.Io,
    mutex: std.Io.Mutex = .init,
    waiting_callers: usize = 0,
    cache_clock: u64 = 0,
    refresh_tokens: std.ArrayList(RefreshTokenEntry) = .empty,
    access_tokens: std.ArrayList(AccessTokenEntry) = .empty,
    routes: std.ArrayList(RouteEntry) = .empty,
    token_flights: std.ArrayList(*TokenFlight) = .empty,
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
        const trusted_origins = try copyTrustedOrigins(
            allocator,
            normalized_endpoint,
            options.expected_hosts,
        );
        errdefer deinitTrustedOrigins(allocator, trusted_origins);

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
            .trusted_origins = trusted_origins,
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
        std.debug.assert(self.waiting_callers == 0);
        std.debug.assert(self.token_flights.items.len == 0);
        for (self.refresh_tokens.items) |*entry| entry.deinit(self.allocator);
        self.refresh_tokens.deinit(self.allocator);
        for (self.access_tokens.items) |*entry| entry.deinit(self.allocator);
        self.access_tokens.deinit(self.allocator);
        for (self.routes.items) |*entry| entry.deinit(self.allocator);
        self.routes.deinit(self.allocator);
        self.token_flights.deinit(self.allocator);
        self.mutex.unlock(self.io);

        self.allocator.free(self.endpoint);
        deinitTrustedOrigins(self.allocator, self.trusted_origins);
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
        try checkCancelled(cancellation);
        const current_time = self.now();
        self.mutex.lockUncancelable(self.io);
        self.pruneAccessTokensLocked(current_time);
        if (self.findValidAccessTokenLocked(challenge, current_time)) |token| {
            const copy = self.allocator.dupe(u8, token) catch |err| {
                self.mutex.unlock(self.io);
                return err;
            };
            self.mutex.unlock(self.io);
            return copy;
        }
        if (self.findRunningFlightLocked(.access, challenge)) |flight| {
            flight.participants += 1;
            self.waiting_callers += 1;
            return self.waitForFlightLocked(flight, cancellation);
        }
        const flight = self.createFlightLocked(.access, challenge) catch |err| {
            self.mutex.unlock(self.io);
            return err;
        };
        self.mutex.unlock(self.io);

        const token = self.requestAccessToken(
            challenge,
            cancellation,
            transport,
        ) catch |err| return self.failFlight(flight, err);
        const expires_on = jwtExpiry(self.allocator, token) catch |err| {
            self.allocator.free(token);
            return self.failFlight(flight, err);
        };
        if (!isTokenValid(expires_on, self.now(), self.expiry_skew_seconds)) {
            self.allocator.free(token);
            return self.failFlight(flight, error.AcrTokenExpired);
        }

        self.mutex.lockUncancelable(self.io);
        self.pruneAccessTokensLocked(self.now());
        self.storeAccessTokenLocked(challenge, token, expires_on) catch |err| {
            self.allocator.free(token);
            self.completeFlightFailureLocked(flight, err);
            return self.consumeFlightResultLocked(flight, false);
        };
        self.completeFlightSuccessLocked(flight, token);
        return self.consumeFlightResultLocked(flight, false);
    }

    fn acquireRefreshToken(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        credential: *core.credentials.TokenCredential,
        cancellation: ?*const CancellationToken,
        transport: *HttpTransport,
    ) ![]u8 {
        try checkCancelled(cancellation);
        const current_time = self.now();
        self.mutex.lockUncancelable(self.io);
        self.pruneRefreshTokensLocked(current_time);
        if (self.findValidRefreshTokenLocked(challenge, current_time)) |token| {
            const copy = self.allocator.dupe(u8, token) catch |err| {
                self.mutex.unlock(self.io);
                return err;
            };
            self.mutex.unlock(self.io);
            return copy;
        }
        if (self.findRunningFlightLocked(.refresh, challenge)) |flight| {
            flight.participants += 1;
            self.waiting_callers += 1;
            return self.waitForFlightLocked(flight, cancellation);
        }
        const flight = self.createFlightLocked(.refresh, challenge) catch |err| {
            self.mutex.unlock(self.io);
            return err;
        };
        self.mutex.unlock(self.io);

        const scopes = [_][]const u8{self.aad_scope};
        var aad_token = credential.getToken(
            .{ .scopes = &scopes },
            core.context.Context.none,
        ) catch |err| return self.failFlight(flight, err);
        defer aad_token.deinit();
        checkCancelled(cancellation) catch |err| return self.failFlight(flight, err);

        const refresh_token = self.exchangeRefreshToken(
            challenge,
            aad_token.token,
            cancellation,
            transport,
        ) catch |err| return self.failFlight(flight, err);
        const expires_on = jwtExpiry(self.allocator, refresh_token) catch |err| {
            self.allocator.free(refresh_token);
            return self.failFlight(flight, err);
        };
        if (!isTokenValid(expires_on, self.now(), self.expiry_skew_seconds)) {
            self.allocator.free(refresh_token);
            return self.failFlight(flight, error.AcrRefreshTokenExpired);
        }

        self.mutex.lockUncancelable(self.io);
        self.pruneRefreshTokensLocked(self.now());
        self.storeRefreshTokenLocked(challenge, refresh_token, expires_on) catch |err| {
            self.allocator.free(refresh_token);
            self.completeFlightFailureLocked(flight, err);
            return self.consumeFlightResultLocked(flight, false);
        };
        self.completeFlightSuccessLocked(flight, refresh_token);
        return self.consumeFlightResultLocked(flight, false);
    }

    fn requestAccessToken(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        cancellation: ?*const CancellationToken,
        transport: *HttpTransport,
    ) ![]u8 {
        return switch (self.authentication) {
            .anonymous => self.exchangeAccessToken(
                challenge,
                "",
                .password,
                cancellation,
                transport,
            ),
            .credential => |credential| blk: {
                var retried = false;
                while (true) {
                    const refresh_token = try self.acquireRefreshToken(
                        challenge,
                        credential,
                        cancellation,
                        transport,
                    );
                    defer self.allocator.free(refresh_token);
                    const access_token = self.exchangeAccessToken(
                        challenge,
                        refresh_token,
                        .refresh_token,
                        cancellation,
                        transport,
                    ) catch |err| {
                        if (!isRefreshTokenRejection(err)) return err;
                        self.invalidateRefreshToken(challenge, refresh_token);
                        if (retried) return err;
                        retried = true;
                        continue;
                    };
                    break :blk access_token;
                }
            },
        };
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
        return self.sendTokenRequest(
            url,
            body.items,
            "refresh_token",
            false,
            cancellation,
            transport,
        );
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
        return self.sendTokenRequest(
            url,
            body.items,
            "access_token",
            grant == .refresh_token,
            cancellation,
            transport,
        );
    }

    fn sendTokenRequest(
        self: *ChallengeAuthenticationPolicy,
        url: []const u8,
        body: []const u8,
        response_field: []const u8,
        classify_refresh_rejection: bool,
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
        if (response.status_code == 401) return error.AcrTokenEndpointUnauthorized;
        if (response.status_code == 403) return error.AcrTokenEndpointForbidden;
        if (response.status_code != 200) {
            if (classify_refresh_rejection and
                try isProtocolRefreshTokenRejection(self.allocator, response.body))
            {
                return error.AcrRefreshTokenRejected;
            }
            return error.AcrTokenExchangeFailed;
        }
        return parseTokenResponse(self.allocator, response.body, response_field) catch |err| {
            if (err == error.InvalidAcrTokenResponse and
                classify_refresh_rejection and
                try isProtocolRefreshTokenRejection(self.allocator, response.body))
            {
                return error.AcrRefreshTokenRejected;
            }
            return err;
        };
    }

    fn validateRequestUrl(self: *ChallengeAuthenticationPolicy, url: []const u8) !void {
        try validateTrustedHttpsUrl(url, self.trusted_origins);
    }

    fn validateChallenge(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
    ) !void {
        try validateTrustedHttpsUrl(challenge.realm, self.trusted_origins);
        const realm_uri = std.Uri.parse(challenge.realm) catch return error.InvalidChallengeRealm;
        if (realm_uri.query != null or realm_uri.fragment != null)
            return error.InvalidChallengeRealm;
        const path = if (realm_uri.path.isEmpty()) "/" else switch (realm_uri.path) {
            .raw => |value| value,
            .percent_encoded => |value| value,
        };
        if (!std.mem.eql(u8, path, "/oauth2/token")) return error.InvalidChallengeRealm;

        var host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
        const realm_host = realm_uri.getHost(&host_buffer) catch
            return error.InvalidChallengeRealm;
        if (!serviceMatchesOrigin(
            challenge.service,
            realm_host.bytes,
            effectiveHttpsPort(realm_uri),
        )) {
            return error.UntrustedChallengeService;
        }
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
        for (self.routes.items) |*entry| {
            if (entry.method == request.method and std.mem.eql(u8, entry.url, route_url)) {
                entry.last_used = self.nextUseLocked();
                return try entry.challenge.clone(self.allocator);
            }
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
            entry.last_used = self.nextUseLocked();
            return;
        }

        const url_copy = try self.allocator.dupe(u8, route_url);
        errdefer self.allocator.free(url_copy);
        var challenge_copy = try challenge.clone(self.allocator);
        errdefer challenge_copy.deinit();
        if (self.routes.items.len >= max_route_entries)
            self.evictLeastRecentlyUsedRouteLocked();
        try self.routes.append(self.allocator, .{
            .method = request.method,
            .url = url_copy,
            .challenge = challenge_copy,
            .last_used = self.nextUseLocked(),
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

    fn invalidateRefreshToken(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        rejected_token: []const u8,
    ) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        for (self.refresh_tokens.items, 0..) |*entry, index| {
            if (!refreshKeyMatches(entry, challenge, self.effectiveTenant(challenge)) or
                !std.mem.eql(u8, entry.token, rejected_token))
            {
                continue;
            }
            var removed = self.refresh_tokens.swapRemove(index);
            removed.deinit(self.allocator);
            return;
        }
    }

    fn findValidRefreshTokenLocked(
        self: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        current_time: i64,
    ) ?[]const u8 {
        for (self.refresh_tokens.items) |*entry| {
            if (refreshKeyMatches(entry, challenge, self.effectiveTenant(challenge)) and
                isTokenValid(entry.expires_on, current_time, self.expiry_skew_seconds))
            {
                entry.last_used = self.nextUseLocked();
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
        for (self.access_tokens.items) |*entry| {
            if (accessKeyMatches(entry, challenge, self.effectiveTenant(challenge)) and
                isTokenValid(entry.expires_on, current_time, self.expiry_skew_seconds))
            {
                entry.last_used = self.nextUseLocked();
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
            entry.last_used = self.nextUseLocked();
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
        if (self.refresh_tokens.items.len >= max_refresh_token_entries)
            self.evictLeastRecentlyUsedRefreshTokenLocked();
        try self.refresh_tokens.append(self.allocator, .{
            .realm = realm,
            .service = service,
            .tenant = tenant_copy,
            .token = token_copy,
            .expires_on = expires_on,
            .last_used = self.nextUseLocked(),
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
            entry.last_used = self.nextUseLocked();
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
        if (self.access_tokens.items.len >= max_access_token_entries)
            self.evictLeastRecentlyUsedAccessTokenLocked();
        try self.access_tokens.append(self.allocator, .{
            .realm = realm,
            .service = service,
            .tenant = tenant_copy,
            .scope = scope,
            .token = token_copy,
            .expires_on = expires_on,
            .last_used = self.nextUseLocked(),
        });
    }

    fn pruneRefreshTokensLocked(
        self: *ChallengeAuthenticationPolicy,
        current_time: i64,
    ) void {
        var index: usize = 0;
        while (index < self.refresh_tokens.items.len) {
            if (isTokenValid(
                self.refresh_tokens.items[index].expires_on,
                current_time,
                self.expiry_skew_seconds,
            )) {
                index += 1;
                continue;
            }
            var removed = self.refresh_tokens.swapRemove(index);
            removed.deinit(self.allocator);
        }
    }

    fn pruneAccessTokensLocked(
        self: *ChallengeAuthenticationPolicy,
        current_time: i64,
    ) void {
        var index: usize = 0;
        while (index < self.access_tokens.items.len) {
            if (isTokenValid(
                self.access_tokens.items[index].expires_on,
                current_time,
                self.expiry_skew_seconds,
            )) {
                index += 1;
                continue;
            }
            var removed = self.access_tokens.swapRemove(index);
            removed.deinit(self.allocator);
        }
    }

    fn evictLeastRecentlyUsedRefreshTokenLocked(
        self: *ChallengeAuthenticationPolicy,
    ) void {
        var oldest_index: usize = 0;
        for (self.refresh_tokens.items[1..], 1..) |entry, index| {
            if (entry.last_used < self.refresh_tokens.items[oldest_index].last_used)
                oldest_index = index;
        }
        var removed = self.refresh_tokens.swapRemove(oldest_index);
        removed.deinit(self.allocator);
    }

    fn evictLeastRecentlyUsedAccessTokenLocked(
        self: *ChallengeAuthenticationPolicy,
    ) void {
        var oldest_index: usize = 0;
        for (self.access_tokens.items[1..], 1..) |entry, index| {
            if (entry.last_used < self.access_tokens.items[oldest_index].last_used)
                oldest_index = index;
        }
        var removed = self.access_tokens.swapRemove(oldest_index);
        removed.deinit(self.allocator);
    }

    fn evictLeastRecentlyUsedRouteLocked(
        self: *ChallengeAuthenticationPolicy,
    ) void {
        var oldest_index: usize = 0;
        for (self.routes.items[1..], 1..) |entry, index| {
            if (entry.last_used < self.routes.items[oldest_index].last_used)
                oldest_index = index;
        }
        var removed = self.routes.swapRemove(oldest_index);
        removed.deinit(self.allocator);
    }

    fn nextUseLocked(self: *ChallengeAuthenticationPolicy) u64 {
        self.cache_clock +%= 1;
        if (self.cache_clock == 0) self.cache_clock = 1;
        return self.cache_clock;
    }

    fn findRunningFlightLocked(
        self: *ChallengeAuthenticationPolicy,
        kind: FlightKind,
        challenge: *const BearerChallenge,
    ) ?*TokenFlight {
        for (self.token_flights.items) |flight| {
            if (flight.state == .running and
                flightKeyMatches(flight, kind, challenge, self.effectiveTenant(challenge)))
            {
                return flight;
            }
        }
        return null;
    }

    fn createFlightLocked(
        self: *ChallengeAuthenticationPolicy,
        kind: FlightKind,
        challenge: *const BearerChallenge,
    ) !*TokenFlight {
        const flight = try self.allocator.create(TokenFlight);
        errdefer self.allocator.destroy(flight);
        flight.* = try TokenFlight.init(
            self.allocator,
            kind,
            challenge.realm,
            challenge.service,
            self.effectiveTenant(challenge) orelse "",
            if (kind == .access) challenge.scope else "",
        );
        errdefer flight.deinit(self.allocator);
        try self.token_flights.append(self.allocator, flight);
        return flight;
    }

    fn waitForFlightLocked(
        self: *ChallengeAuthenticationPolicy,
        flight: *TokenFlight,
        cancellation: ?*const CancellationToken,
    ) ![]u8 {
        if (cancellation == null) {
            while (flight.state == .running)
                flight.condition.waitUncancelable(self.io, &self.mutex);
            return self.consumeFlightResultLocked(flight, true);
        }

        self.mutex.unlock(self.io);
        while (true) {
            checkCancelled(cancellation) catch |err|
                return self.leaveFlightWait(flight, err);
            self.io.sleep(.fromMilliseconds(1), .awake) catch |err|
                return self.leaveFlightWait(flight, err);
            self.mutex.lockUncancelable(self.io);
            if (flight.state != .running)
                return self.consumeFlightResultLocked(flight, true);
            self.mutex.unlock(self.io);
        }
    }

    fn leaveFlightWait(
        self: *ChallengeAuthenticationPolicy,
        flight: *TokenFlight,
        failure: anyerror,
    ) anyerror![]u8 {
        self.mutex.lockUncancelable(self.io);
        self.waiting_callers -= 1;
        self.releaseFlightLocked(flight);
        self.mutex.unlock(self.io);
        return failure;
    }

    fn failFlight(
        self: *ChallengeAuthenticationPolicy,
        flight: *TokenFlight,
        failure: anyerror,
    ) anyerror![]u8 {
        self.mutex.lockUncancelable(self.io);
        self.completeFlightFailureLocked(flight, failure);
        return self.consumeFlightResultLocked(flight, false);
    }

    fn completeFlightSuccessLocked(
        self: *ChallengeAuthenticationPolicy,
        flight: *TokenFlight,
        token: []u8,
    ) void {
        std.debug.assert(flight.state == .running);
        flight.token = token;
        flight.state = .succeeded;
        flight.condition.broadcast(self.io);
    }

    fn completeFlightFailureLocked(
        self: *ChallengeAuthenticationPolicy,
        flight: *TokenFlight,
        failure: anyerror,
    ) void {
        std.debug.assert(flight.state == .running);
        flight.failure = failure;
        flight.state = .failed;
        flight.condition.broadcast(self.io);
    }

    fn consumeFlightResultLocked(
        self: *ChallengeAuthenticationPolicy,
        flight: *TokenFlight,
        waiter: bool,
    ) ![]u8 {
        std.debug.assert(flight.state != .running);
        var token: ?[]u8 = null;
        var failure: ?anyerror = null;
        switch (flight.state) {
            .running => unreachable,
            .succeeded => {
                token = self.allocator.dupe(u8, flight.token.?) catch |err| blk: {
                    failure = err;
                    break :blk null;
                };
            },
            .failed => failure = flight.failure.?,
        }
        if (waiter) self.waiting_callers -= 1;
        self.releaseFlightLocked(flight);
        self.mutex.unlock(self.io);
        if (failure) |err| return err;
        return token.?;
    }

    fn releaseFlightLocked(
        self: *ChallengeAuthenticationPolicy,
        flight: *TokenFlight,
    ) void {
        std.debug.assert(flight.participants > 0);
        flight.participants -= 1;
        if (flight.participants != 0) return;
        std.debug.assert(flight.state != .running);
        for (self.token_flights.items, 0..) |candidate, index| {
            if (candidate != flight) continue;
            _ = self.token_flights.swapRemove(index);
            flight.deinit(self.allocator);
            self.allocator.destroy(flight);
            return;
        }
        unreachable;
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

fn copyTrustedOrigins(
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    additional: []const []const u8,
) ![]TrustedOrigin {
    const origins = try allocator.alloc(TrustedOrigin, additional.len + 1);
    errdefer allocator.free(origins);
    var initialized: usize = 0;
    errdefer {
        for (origins[0..initialized]) |*origin| origin.deinit(allocator);
    }

    origins[0] = try trustedOriginFromUrl(allocator, endpoint);
    initialized += 1;
    for (additional, 0..) |value, index| {
        origins[index + 1] = if (std.mem.indexOf(u8, value, "://") != null)
            try trustedOriginFromUrl(allocator, value)
        else blk: {
            try validateExpectedHost(value);
            break :blk .{
                .host = try allocator.dupe(u8, value),
                .port = 443,
            };
        };
        initialized += 1;
    }
    return origins;
}

fn trustedOriginFromUrl(
    allocator: std.mem.Allocator,
    raw: []const u8,
) !TrustedOrigin {
    const uri = std.Uri.parse(raw) catch return error.InvalidExpectedOrigin;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "https"))
        return error.InvalidExpectedOrigin;
    if (uri.host == null or uri.user != null or uri.password != null or
        uri.query != null or uri.fragment != null)
    {
        return error.InvalidExpectedOrigin;
    }
    const path = if (uri.path.isEmpty()) "" else switch (uri.path) {
        .raw => |value| value,
        .percent_encoded => |value| value,
    };
    if (path.len != 0 and !std.mem.eql(u8, path, "/"))
        return error.InvalidExpectedOrigin;
    var host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = uri.getHost(&host_buffer) catch return error.InvalidExpectedOrigin;
    return .{
        .host = try allocator.dupe(u8, host.bytes),
        .port = effectiveHttpsPort(uri),
    };
}

fn validateExpectedHost(host: []const u8) !void {
    if (host.len == 0) return error.InvalidExpectedHost;
    for (host) |byte| {
        if (std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '-') continue;
        return error.InvalidExpectedHost;
    }
}

fn deinitTrustedOrigins(
    allocator: std.mem.Allocator,
    origins: []TrustedOrigin,
) void {
    for (origins) |*origin| origin.deinit(allocator);
    allocator.free(origins);
}

fn validateTrustedHttpsUrl(
    raw: []const u8,
    trusted_origins: []const TrustedOrigin,
) !void {
    const uri = std.Uri.parse(raw) catch return error.InvalidUrl;
    if (!std.ascii.eqlIgnoreCase(uri.scheme, "https")) return error.HttpsRequired;
    if (uri.host == null or uri.user != null or uri.password != null or
        uri.fragment != null)
    {
        return error.InvalidUrl;
    }
    var host_buffer: [std.Io.net.HostName.max_len]u8 = undefined;
    const host = uri.getHost(&host_buffer) catch return error.InvalidUrl;
    const port = effectiveHttpsPort(uri);
    for (trusted_origins) |origin| {
        if (origin.port == port and
            std.ascii.eqlIgnoreCase(origin.host, host.bytes))
        {
            return;
        }
    }
    return error.UnexpectedHost;
}

fn effectiveHttpsPort(uri: std.Uri) u16 {
    return uri.port orelse 443;
}

fn serviceMatchesOrigin(
    service: []const u8,
    host: []const u8,
    port: u16,
) bool {
    if (std.ascii.eqlIgnoreCase(service, host)) return true;
    var authority_buffer: [std.Io.net.HostName.max_len + 8]u8 = undefined;
    const authority = if (std.mem.indexOfScalar(u8, host, ':') != null)
        std.fmt.bufPrint(&authority_buffer, "[{s}]:{d}", .{ host, port }) catch
            unreachable
    else
        std.fmt.bufPrint(&authority_buffer, "{s}:{d}", .{ host, port }) catch
            unreachable;
    return std.ascii.eqlIgnoreCase(service, authority);
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

fn flightKeyMatches(
    flight: *const TokenFlight,
    kind: FlightKind,
    challenge: *const BearerChallenge,
    tenant: ?[]const u8,
) bool {
    return flight.kind == kind and
        std.mem.eql(u8, flight.realm, challenge.realm) and
        std.mem.eql(u8, flight.service, challenge.service) and
        std.mem.eql(u8, flight.tenant, tenant orelse "") and
        (kind == .refresh or std.mem.eql(u8, flight.scope, challenge.scope));
}

fn isTokenValid(expires_on: i64, now: i64, skew: i64) bool {
    return expires_on > now and now < expires_on -| skew;
}

fn isRefreshTokenRejection(err: anyerror) bool {
    return err == error.AcrTokenEndpointUnauthorized or
        err == error.AcrTokenEndpointForbidden or
        err == error.AcrRefreshTokenRejected;
}

fn isProtocolRefreshTokenRejection(
    allocator: std.mem.Allocator,
    body: []const u8,
) !bool {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch |err|
        switch (err) {
            error.OutOfMemory => return err,
            else => return false,
        };
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    if (parsed.value.object.get("error")) |oauth_error| {
        if (oauth_error == .string and
            (std.ascii.eqlIgnoreCase(oauth_error.string, "invalid_grant") or
                std.ascii.eqlIgnoreCase(oauth_error.string, "invalid_token") or
                std.ascii.eqlIgnoreCase(oauth_error.string, "unauthorized")))
        {
            return true;
        }
    }
    const errors = parsed.value.object.get("errors") orelse return false;
    if (errors != .array) return false;
    for (errors.array.items) |acr_error| {
        if (acr_error != .object) continue;
        const code = acr_error.object.get("code") orelse continue;
        if (code == .string and
            (std.ascii.eqlIgnoreCase(code.string, "UNAUTHORIZED") or
                std.ascii.eqlIgnoreCase(code.string, "INVALID_TOKEN")))
        {
            return true;
        }
    }
    return false;
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
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, body, .{}) catch |err|
        switch (err) {
            error.OutOfMemory => return err,
            else => return error.InvalidAcrTokenResponse,
        };
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

    const decoded = core.base64.urlDecode(allocator, payload) catch |err|
        switch (err) {
            error.OutOfMemory => return err,
            else => return error.InvalidAcrToken,
        };
    defer allocator.free(decoded);
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, decoded, .{}) catch |err|
        switch (err) {
            error.OutOfMemory => return err,
            else => return error.InvalidAcrToken,
        };
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

fn parseTestChallenge(
    allocator: std.mem.Allocator,
    realm: []const u8,
    service: []const u8,
    scope: []const u8,
    tenant: ?[]const u8,
) !BearerChallenge {
    const base = try makeChallenge(allocator, realm, service, scope);
    defer allocator.free(base);
    if (tenant) |value| {
        const header = try std.fmt.allocPrint(
            allocator,
            "{s},tenant=\"{s}\"",
            .{ base, value },
        );
        defer allocator.free(header);
        const values = [_][]const u8{header};
        return challenge_mod.parseBearerChallenge(allocator, &values);
    }
    const values = [_][]const u8{base};
    return challenge_mod.parseBearerChallenge(allocator, &values);
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

fn testResponse(
    allocator: std.mem.Allocator,
    status_code: u16,
    body: []const u8,
) !Response {
    return .{
        .status_code = status_code,
        .headers = std.StringHashMap([]const u8).init(allocator),
        .body = try allocator.dupe(u8, body),
        .allocator = allocator,
        .response_headers = core.http.ResponseHeaders.init(allocator),
    };
}

const ParallelAccessTransport = struct {
    allocator: std.mem.Allocator,
    refresh_body: []const u8,
    access_one_body: []const u8,
    access_two_body: []const u8,
    exchange_calls: std.atomic.Value(usize) = .init(0),
    access_calls: std.atomic.Value(usize) = .init(0),
    access_release: std.Io.Semaphore = .{},
    transport: HttpTransport,

    fn init(
        allocator: std.mem.Allocator,
        refresh_body: []const u8,
        access_one_body: []const u8,
        access_two_body: []const u8,
    ) ParallelAccessTransport {
        return .{
            .allocator = allocator,
            .refresh_body = refresh_body,
            .access_one_body = access_one_body,
            .access_two_body = access_two_body,
            .transport = .{ .sendFn = &sendImpl },
        };
    }

    fn asTransport(self: *ParallelAccessTransport) *HttpTransport {
        return &self.transport;
    }

    fn sendImpl(transport: *HttpTransport, request: *Request) !Response {
        const self: *ParallelAccessTransport =
            @alignCast(@fieldParentPtr("transport", transport));
        if (std.mem.indexOf(u8, request.url, "/oauth2/exchange") != null) {
            _ = self.exchange_calls.fetchAdd(1, .monotonic);
            return testResponse(self.allocator, 200, self.refresh_body);
        }
        if (std.mem.indexOf(u8, request.url, "/oauth2/token") == null)
            return error.UnexpectedMockRequest;
        _ = self.access_calls.fetchAdd(1, .monotonic);
        const io = std.Io.Threaded.global_single_threaded.io();
        self.access_release.waitUncancelable(io);
        const body = request.body orelse return error.MissingMockRequestBody;
        if (std.mem.indexOf(u8, body, "repository%3Aone%3Apull") != null)
            return testResponse(self.allocator, 200, self.access_one_body);
        if (std.mem.indexOf(u8, body, "repository%3Atwo%3Apull") != null)
            return testResponse(self.allocator, 200, self.access_two_body);
        return error.UnexpectedMockScope;
    }
};

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
        try io.sleep(.fromMilliseconds(1), .awake);
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

test "trusted origins compare HTTPS host and effective port" {
    const allocator = std.testing.allocator;
    const unused = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 200, .body = "{}" },
    };
    var unused_transport = core.http.SequenceMockTransport.init(allocator, &unused);
    var default_policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .anonymous,
        .{},
    );
    defer default_policy.deinit();

    try std.testing.expectError(
        error.UnexpectedHost,
        sendBuffered(
            allocator,
            &default_policy,
            unused_transport.asTransport(),
            .GET,
            "https://registry.example:8443/v2/_catalog",
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), unused_transport.call_count);

    const untrusted_challenge = try makeChallenge(
        allocator,
        "https://registry.example:8443/oauth2/token",
        "registry.example:8443",
        "registry:catalog:*",
    );
    defer allocator.free(untrusted_challenge);
    const untrusted_headers = [_]core.http.MockTransport.HeaderPair{
        .{ .name = "WWW-Authenticate", .value = untrusted_challenge },
    };
    const untrusted_responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "", .headers = &untrusted_headers },
    };
    var untrusted_transport = core.http.SequenceMockTransport.init(
        allocator,
        &untrusted_responses,
    );
    try std.testing.expectError(
        error.UnexpectedHost,
        sendBuffered(
            allocator,
            &default_policy,
            untrusted_transport.asTransport(),
            .GET,
            "https://registry.example/v2/_catalog",
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), untrusted_transport.call_count);

    var hostname_policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .anonymous,
        .{ .expected_hosts = &.{"auth.example"} },
    );
    defer hostname_policy.deinit();
    try std.testing.expectError(
        error.UnexpectedHost,
        sendBuffered(
            allocator,
            &hostname_policy,
            unused_transport.asTransport(),
            .GET,
            "https://auth.example:8443/v2/_catalog",
        ),
    );

    const access_token = try makeJwt(allocator, 4_102_444_800, "port-8443");
    defer allocator.free(access_token);
    const access_body = try makeTokenResponse(allocator, "access_token", access_token);
    defer allocator.free(access_body);
    const challenge = try makeChallenge(
        allocator,
        "https://registry.example:8443/oauth2/token",
        "REGISTRY.EXAMPLE:8443",
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
    var explicit_transport = core.http.SequenceMockTransport.init(allocator, &responses);
    var explicit_policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .anonymous,
        .{ .expected_hosts = &.{"https://registry.example:8443"} },
    );
    defer explicit_policy.deinit();

    var response = try sendBuffered(
        allocator,
        &explicit_policy,
        explicit_transport.asTransport(),
        .GET,
        "https://REGISTRY.example:8443/v2/_catalog",
    );
    defer response.deinit();
    try std.testing.expectEqual(@as(u16, 200), response.status_code);
    try std.testing.expectEqual(@as(usize, 3), explicit_transport.call_count);
    try std.testing.expectEqualStrings(
        "https://registry.example:8443/oauth2/token?api-version=2021-07-01",
        capturedUrl(&explicit_transport, 1),
    );
    try std.testing.expect(explicit_transport.captured_authorization[2]);
}

test "cached refresh rejection invalidates exact token and recovers once" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    const stale_refresh = try makeJwt(allocator, 5_000, "stale-refresh");
    defer allocator.free(stale_refresh);
    const fresh_refresh = try makeJwt(allocator, 6_000, "fresh-refresh");
    defer allocator.free(fresh_refresh);
    const other_refresh = try makeJwt(allocator, 6_000, "other-refresh");
    defer allocator.free(other_refresh);
    const access_token = try makeJwt(allocator, 4_000, "recovered-access");
    defer allocator.free(access_token);
    const refresh_body = try makeTokenResponse(allocator, "refresh_token", fresh_refresh);
    defer allocator.free(refresh_body);
    const access_body = try makeTokenResponse(allocator, "access_token", access_token);
    defer allocator.free(access_body);
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "{\"errors\":[{\"code\":\"UNAUTHORIZED\"}]}" },
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
    var challenge = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
        null,
    );
    defer challenge.deinit();
    var other_challenge = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
        "other-tenant",
    );
    defer other_challenge.deinit();
    {
        policy.mutex.lockUncancelable(policy.io);
        defer policy.mutex.unlock(policy.io);
        try policy.storeRefreshTokenLocked(&challenge, stale_refresh, 5_000);
        try policy.storeRefreshTokenLocked(&other_challenge, other_refresh, 6_000);
    }

    const token = try policy.acquireAccessToken(
        &challenge,
        null,
        transport.asTransport(),
    );
    defer allocator.free(token);
    try std.testing.expectEqualStrings(access_token, token);
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expectEqual(
        @as(usize, 1),
        countCapturedUrl(&transport, "/oauth2/exchange"),
    );
    try std.testing.expectEqual(
        @as(usize, 2),
        countCapturedUrl(&transport, "/oauth2/token"),
    );
    try std.testing.expect(std.mem.indexOf(u8, capturedBody(&transport, 0), stale_refresh) != null);
    try std.testing.expect(std.mem.indexOf(u8, capturedBody(&transport, 2), fresh_refresh) != null);
    {
        policy.mutex.lockUncancelable(policy.io);
        defer policy.mutex.unlock(policy.io);
        const cached = policy.findValidRefreshTokenLocked(&challenge, clock.value).?;
        try std.testing.expectEqualStrings(fresh_refresh, cached);
        const other_cached = policy.findValidRefreshTokenLocked(
            &other_challenge,
            clock.value,
        ).?;
        try std.testing.expectEqualStrings(other_refresh, other_cached);
        try std.testing.expectEqual(@as(usize, 2), policy.refresh_tokens.items.len);
    }
}

test "refresh rejection retry is bounded and unrelated failures are not retried" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    const stale_refresh = try makeJwt(allocator, 5_000, "stale");
    defer allocator.free(stale_refresh);
    const rejected_refresh = try makeJwt(allocator, 6_000, "rejected");
    defer allocator.free(rejected_refresh);
    const refresh_body = try makeTokenResponse(allocator, "refresh_token", rejected_refresh);
    defer allocator.free(refresh_body);
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 403, .body = "{}" },
        .{ .status = 200, .body = refresh_body },
        .{ .status = 200, .body = "{\"error\":\"invalid_grant\"}" },
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
    var challenge = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
        null,
    );
    defer challenge.deinit();
    {
        policy.mutex.lockUncancelable(policy.io);
        defer policy.mutex.unlock(policy.io);
        try policy.storeRefreshTokenLocked(&challenge, stale_refresh, 5_000);
    }

    try std.testing.expectError(
        error.AcrRefreshTokenRejected,
        policy.acquireAccessToken(&challenge, null, transport.asTransport()),
    );
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    {
        policy.mutex.lockUncancelable(policy.io);
        defer policy.mutex.unlock(policy.io);
        try std.testing.expectEqual(@as(usize, 0), policy.refresh_tokens.items.len);
    }

    var unrelated_credential = TestCredential.init();
    const unrelated_responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 500, .body = "{\"errors\":[{\"code\":\"UNAVAILABLE\"}]}" },
    };
    var unrelated_transport = core.http.SequenceMockTransport.init(
        allocator,
        &unrelated_responses,
    );
    var unrelated_policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .{ .credential = &unrelated_credential.credential },
        .{
            .expiry_skew_seconds = 10,
            .time_source = clock.source(),
        },
    );
    defer unrelated_policy.deinit();
    {
        unrelated_policy.mutex.lockUncancelable(unrelated_policy.io);
        defer unrelated_policy.mutex.unlock(unrelated_policy.io);
        try unrelated_policy.storeRefreshTokenLocked(&challenge, stale_refresh, 5_000);
    }
    try std.testing.expectError(
        error.AcrTokenExchangeFailed,
        unrelated_policy.acquireAccessToken(
            &challenge,
            null,
            unrelated_transport.asTransport(),
        ),
    );
    try std.testing.expectEqual(@as(usize, 1), unrelated_transport.call_count);
    try std.testing.expectEqual(
        @as(usize, 0),
        unrelated_credential.calls.load(.monotonic),
    );
    {
        unrelated_policy.mutex.lockUncancelable(unrelated_policy.io);
        defer unrelated_policy.mutex.unlock(unrelated_policy.io);
        const cached = unrelated_policy.findValidRefreshTokenLocked(
            &challenge,
            clock.value,
        ).?;
        try std.testing.expectEqualStrings(stale_refresh, cached);
    }
}

test "token endpoint preserves authentication rejection classification" {
    const allocator = std.testing.allocator;
    var policy = try ChallengeAuthenticationPolicy.init(
        allocator,
        "https://registry.example",
        .anonymous,
        .{},
    );
    defer policy.deinit();
    const url = "https://registry.example/oauth2/token";
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
        .{ .status = 401, .body = "{}" },
        .{ .status = 403, .body = "{}" },
        .{ .status = 200, .body = "{\"errors\":[{\"code\":\"UNAUTHORIZED\"}]}" },
    };
    var transport = core.http.SequenceMockTransport.init(allocator, &responses);
    try std.testing.expectError(
        error.AcrTokenEndpointUnauthorized,
        policy.sendTokenRequest(
            url,
            "",
            "access_token",
            true,
            null,
            transport.asTransport(),
        ),
    );
    try std.testing.expectError(
        error.AcrTokenEndpointForbidden,
        policy.sendTokenRequest(
            url,
            "",
            "access_token",
            true,
            null,
            transport.asTransport(),
        ),
    );
    try std.testing.expectError(
        error.AcrRefreshTokenRejected,
        policy.sendTokenRequest(
            url,
            "",
            "access_token",
            true,
            null,
            transport.asTransport(),
        ),
    );
    try std.testing.expectEqual(@as(usize, 3), transport.call_count);
}

test "token caches prune expired entries and preserve valid keys" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
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
    var expired_access = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:expired:pull",
        null,
    );
    defer expired_access.deinit();
    var valid_access = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:valid:pull",
        null,
    );
    defer valid_access.deinit();
    var expired_refresh = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
        "expired-tenant",
    );
    defer expired_refresh.deinit();
    var valid_refresh = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
        "valid-tenant",
    );
    defer valid_refresh.deinit();

    {
        policy.mutex.lockUncancelable(policy.io);
        defer policy.mutex.unlock(policy.io);
        try policy.storeAccessTokenLocked(&expired_access, "expired-access", 1_005);
        try policy.storeAccessTokenLocked(&valid_access, "valid-access", 5_000);
        try policy.storeRefreshTokenLocked(&expired_refresh, "expired-refresh", 1_005);
        try policy.storeRefreshTokenLocked(&valid_refresh, "valid-refresh", 5_000);
        policy.pruneAccessTokensLocked(clock.value);
        policy.pruneRefreshTokensLocked(clock.value);
        try std.testing.expectEqual(@as(usize, 1), policy.access_tokens.items.len);
        try std.testing.expectEqual(@as(usize, 1), policy.refresh_tokens.items.len);
        try std.testing.expect(
            policy.findValidAccessTokenLocked(&expired_access, clock.value) == null,
        );
        try std.testing.expect(
            policy.findValidRefreshTokenLocked(&expired_refresh, clock.value) == null,
        );
        try std.testing.expectEqualStrings(
            "valid-access",
            policy.findValidAccessTokenLocked(&valid_access, clock.value).?,
        );
        try std.testing.expectEqualStrings(
            "valid-refresh",
            policy.findValidRefreshTokenLocked(&valid_refresh, clock.value).?,
        );
    }
}

test "bounded caches evict least recently used keys without mixups" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
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

    for (0..max_access_token_entries) |index| {
        const scope = try std.fmt.allocPrint(
            allocator,
            "repository:access-{d}:pull",
            .{index},
        );
        defer allocator.free(scope);
        const token = try std.fmt.allocPrint(allocator, "access-token-{d}", .{index});
        defer allocator.free(token);
        var challenge = try parseTestChallenge(
            allocator,
            "https://registry.example/oauth2/token",
            "registry.example",
            scope,
            null,
        );
        defer challenge.deinit();
        policy.mutex.lockUncancelable(policy.io);
        {
            defer policy.mutex.unlock(policy.io);
            try policy.storeAccessTokenLocked(&challenge, token, 5_000);
        }
    }
    var access_zero = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:access-0:pull",
        null,
    );
    defer access_zero.deinit();
    var access_one = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:access-1:pull",
        null,
    );
    defer access_one.deinit();
    const overflow_scope = try std.fmt.allocPrint(
        allocator,
        "repository:access-{d}:pull",
        .{max_access_token_entries},
    );
    defer allocator.free(overflow_scope);
    var access_overflow = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        overflow_scope,
        null,
    );
    defer access_overflow.deinit();
    {
        policy.mutex.lockUncancelable(policy.io);
        defer policy.mutex.unlock(policy.io);
        try std.testing.expectEqualStrings(
            "access-token-0",
            policy.findValidAccessTokenLocked(&access_zero, clock.value).?,
        );
        try policy.storeAccessTokenLocked(
            &access_overflow,
            "access-token-overflow",
            5_000,
        );
        try std.testing.expectEqual(max_access_token_entries, policy.access_tokens.items.len);
        try std.testing.expect(
            policy.findValidAccessTokenLocked(&access_one, clock.value) == null,
        );
        try std.testing.expectEqualStrings(
            "access-token-0",
            policy.findValidAccessTokenLocked(&access_zero, clock.value).?,
        );
        try std.testing.expectEqualStrings(
            "access-token-overflow",
            policy.findValidAccessTokenLocked(&access_overflow, clock.value).?,
        );
    }

    for (0..max_refresh_token_entries) |index| {
        const tenant = try std.fmt.allocPrint(allocator, "tenant-{d}", .{index});
        defer allocator.free(tenant);
        const token = try std.fmt.allocPrint(allocator, "refresh-token-{d}", .{index});
        defer allocator.free(token);
        var challenge = try parseTestChallenge(
            allocator,
            "https://registry.example/oauth2/token",
            "registry.example",
            "repository:refresh:pull",
            tenant,
        );
        defer challenge.deinit();
        policy.mutex.lockUncancelable(policy.io);
        {
            defer policy.mutex.unlock(policy.io);
            try policy.storeRefreshTokenLocked(&challenge, token, 5_000);
        }
    }
    var refresh_zero = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:refresh:pull",
        "tenant-0",
    );
    defer refresh_zero.deinit();
    var refresh_one = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:refresh:pull",
        "tenant-1",
    );
    defer refresh_one.deinit();
    const overflow_tenant = try std.fmt.allocPrint(
        allocator,
        "tenant-{d}",
        .{max_refresh_token_entries},
    );
    defer allocator.free(overflow_tenant);
    var refresh_overflow = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:refresh:pull",
        overflow_tenant,
    );
    defer refresh_overflow.deinit();
    {
        policy.mutex.lockUncancelable(policy.io);
        defer policy.mutex.unlock(policy.io);
        try std.testing.expectEqualStrings(
            "refresh-token-0",
            policy.findValidRefreshTokenLocked(&refresh_zero, clock.value).?,
        );
        try policy.storeRefreshTokenLocked(
            &refresh_overflow,
            "refresh-token-overflow",
            5_000,
        );
        try std.testing.expectEqual(max_refresh_token_entries, policy.refresh_tokens.items.len);
        try std.testing.expect(
            policy.findValidRefreshTokenLocked(&refresh_one, clock.value) == null,
        );
        try std.testing.expectEqualStrings(
            "refresh-token-0",
            policy.findValidRefreshTokenLocked(&refresh_zero, clock.value).?,
        );
        try std.testing.expectEqualStrings(
            "refresh-token-overflow",
            policy.findValidRefreshTokenLocked(&refresh_overflow, clock.value).?,
        );
    }

    var route_challenge = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:route:pull",
        null,
    );
    defer route_challenge.deinit();
    for (0..max_route_entries) |index| {
        const url = try std.fmt.allocPrint(
            allocator,
            "https://registry.example/v2/route-{d}/tags/list",
            .{index},
        );
        defer allocator.free(url);
        var request = Request.init(allocator, .GET, url);
        defer request.deinit();
        try policy.storeRoute(&request, &route_challenge);
    }
    var route_zero_request = Request.init(
        allocator,
        .GET,
        "https://registry.example/v2/route-0/tags/list",
    );
    defer route_zero_request.deinit();
    var route_one_request = Request.init(
        allocator,
        .GET,
        "https://registry.example/v2/route-1/tags/list",
    );
    defer route_one_request.deinit();
    const overflow_url = try std.fmt.allocPrint(
        allocator,
        "https://registry.example/v2/route-{d}/tags/list",
        .{max_route_entries},
    );
    defer allocator.free(overflow_url);
    var overflow_request = Request.init(allocator, .GET, overflow_url);
    defer overflow_request.deinit();
    var touched_route = (try policy.findRoute(&route_zero_request)).?;
    touched_route.deinit();
    try policy.storeRoute(&overflow_request, &route_challenge);
    try std.testing.expectEqual(max_route_entries, policy.routes.items.len);
    try std.testing.expect((try policy.findRoute(&route_one_request)) == null);
    var retained_route = (try policy.findRoute(&route_zero_request)).?;
    defer retained_route.deinit();
    var newest_route = (try policy.findRoute(&overflow_request)).?;
    defer newest_route.deinit();
    try std.testing.expectEqualStrings(route_challenge.scope, retained_route.scope);
    try std.testing.expectEqualStrings(route_challenge.scope, newest_route.scope);
}

test "different access keys refresh concurrently while sharing refresh flight" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var credential = TestCredential.init();
    const refresh_token = try makeJwt(allocator, 5_000, "shared-refresh");
    defer allocator.free(refresh_token);
    const access_one = try makeJwt(allocator, 4_000, "parallel-one");
    defer allocator.free(access_one);
    const access_two = try makeJwt(allocator, 4_000, "parallel-two");
    defer allocator.free(access_two);
    const refresh_body = try makeTokenResponse(allocator, "refresh_token", refresh_token);
    defer allocator.free(refresh_body);
    const access_one_body = try makeTokenResponse(allocator, "access_token", access_one);
    defer allocator.free(access_one_body);
    const access_two_body = try makeTokenResponse(allocator, "access_token", access_two);
    defer allocator.free(access_two_body);
    var transport = ParallelAccessTransport.init(
        allocator,
        refresh_body,
        access_one_body,
        access_two_body,
    );
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
    var challenge_one = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
        null,
    );
    defer challenge_one.deinit();
    var challenge_two = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:two:pull",
        null,
    );
    defer challenge_two.deinit();

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
        .challenge = &challenge_one,
        .transport = transport.asTransport(),
    };
    var second = AcquireContext{
        .policy = &policy,
        .challenge = &challenge_two,
        .transport = transport.asTransport(),
    };
    const first_thread = try std.Thread.spawn(.{}, AcquireContext.run, .{&first});
    const second_thread = std.Thread.spawn(.{}, AcquireContext.run, .{&second}) catch |err| {
        transport.access_release.post(policy.io);
        first_thread.join();
        return err;
    };
    var parallel = false;
    for (0..1_000) |_| {
        if (transport.access_calls.load(.monotonic) == 2) {
            parallel = true;
            break;
        }
        try policy.io.sleep(.fromMilliseconds(1), .awake);
    }
    transport.access_release.post(policy.io);
    transport.access_release.post(policy.io);
    first_thread.join();
    second_thread.join();
    defer if (first.token) |token| allocator.free(token);
    defer if (second.token) |token| allocator.free(token);

    try std.testing.expect(parallel);
    try std.testing.expect(first.err == null);
    try std.testing.expect(second.err == null);
    try std.testing.expectEqualStrings(access_one, first.token.?);
    try std.testing.expectEqualStrings(access_two, second.token.?);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expectEqual(@as(usize, 1), transport.exchange_calls.load(.monotonic));
    try std.testing.expectEqual(@as(usize, 2), transport.access_calls.load(.monotonic));
}

test "same-key flight wakes waiters with the leader failure" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var entered: std.Io.Semaphore = .{};
    var release: std.Io.Semaphore = .{};
    var credential = TestCredential.init();
    credential.fail = true;
    credential.entered = &entered;
    credential.release = &release;
    const responses = [_]core.http.SequenceMockTransport.CannedResponse{
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
    var challenge = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
        null,
    );
    defer challenge.deinit();

    const AcquireContext = struct {
        policy: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        transport: *HttpTransport,
        err: ?anyerror = null,

        fn run(self: *@This()) void {
            const token = self.policy.acquireAccessToken(
                self.challenge,
                null,
                self.transport,
            ) catch |err| {
                self.err = err;
                return;
            };
            self.policy.allocator.free(token);
        }
    };
    var first = AcquireContext{
        .policy = &policy,
        .challenge = &challenge,
        .transport = transport.asTransport(),
    };
    var second = first;
    const first_thread = try std.Thread.spawn(.{}, AcquireContext.run, .{&first});
    entered.waitUncancelable(policy.io);
    const second_thread = std.Thread.spawn(.{}, AcquireContext.run, .{&second}) catch |err| {
        release.post(policy.io);
        first_thread.join();
        return err;
    };
    while (true) {
        policy.mutex.lockUncancelable(policy.io);
        const waiting = policy.waiting_callers;
        policy.mutex.unlock(policy.io);
        if (waiting > 0) break;
        try policy.io.sleep(.fromMilliseconds(1), .awake);
    }
    release.post(policy.io);
    first_thread.join();
    second_thread.join();

    try std.testing.expectEqual(error.MockCredentialFailure, first.err.?);
    try std.testing.expectEqual(error.MockCredentialFailure, second.err.?);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expectEqual(@as(usize, 0), transport.call_count);
}

test "cancelling a same-key waiter leaves the leader race safe" {
    const allocator = std.testing.allocator;
    var clock = TestClock{ .value = 1_000 };
    var entered: std.Io.Semaphore = .{};
    var release: std.Io.Semaphore = .{};
    var credential = TestCredential.init();
    credential.entered = &entered;
    credential.release = &release;
    const refresh_token = try makeJwt(allocator, 5_000, "refresh");
    defer allocator.free(refresh_token);
    const access_token = try makeJwt(allocator, 4_000, "access");
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
    var challenge = try parseTestChallenge(
        allocator,
        "https://registry.example/oauth2/token",
        "registry.example",
        "repository:one:pull",
        null,
    );
    defer challenge.deinit();
    var cancellation = CancellationToken{};

    const AcquireContext = struct {
        policy: *ChallengeAuthenticationPolicy,
        challenge: *const BearerChallenge,
        cancellation: ?*const CancellationToken,
        transport: *HttpTransport,
        token: ?[]u8 = null,
        err: ?anyerror = null,

        fn run(self: *@This()) void {
            self.token = self.policy.acquireAccessToken(
                self.challenge,
                self.cancellation,
                self.transport,
            ) catch |err| {
                self.err = err;
                return;
            };
        }
    };
    var leader = AcquireContext{
        .policy = &policy,
        .challenge = &challenge,
        .cancellation = null,
        .transport = transport.asTransport(),
    };
    var waiter = AcquireContext{
        .policy = &policy,
        .challenge = &challenge,
        .cancellation = &cancellation,
        .transport = transport.asTransport(),
    };
    const leader_thread = try std.Thread.spawn(.{}, AcquireContext.run, .{&leader});
    entered.waitUncancelable(policy.io);
    const waiter_thread = std.Thread.spawn(.{}, AcquireContext.run, .{&waiter}) catch |err| {
        release.post(policy.io);
        leader_thread.join();
        return err;
    };
    while (true) {
        policy.mutex.lockUncancelable(policy.io);
        const waiting = policy.waiting_callers;
        policy.mutex.unlock(policy.io);
        if (waiting > 0) break;
        try policy.io.sleep(.fromMilliseconds(1), .awake);
    }
    cancellation.cancel();
    waiter_thread.join();
    release.post(policy.io);
    leader_thread.join();
    defer if (leader.token) |token| allocator.free(token);
    defer if (waiter.token) |token| allocator.free(token);

    try std.testing.expectEqual(error.OperationCancelled, waiter.err.?);
    try std.testing.expect(leader.err == null);
    try std.testing.expectEqualStrings(access_token, leader.token.?);
    try std.testing.expectEqual(@as(usize, 1), credential.calls.load(.monotonic));
    try std.testing.expectEqual(@as(usize, 2), transport.call_count);
}
