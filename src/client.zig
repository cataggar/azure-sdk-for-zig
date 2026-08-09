//! The Azure DevOps client.
//!
//! Azure DevOps exposes 44 API areas that share an organization, a
//! credential and a release cadence, so `DevOpsClient` owns one pipeline
//! and hands it to every area client rather than making callers build
//! and authenticate 44 clients separately:
//!
//! ```zig
//! var client = try DevOpsClient.init(allocator, .{
//!     .organization = "contoso",
//!     .credential = .fromPat(pat),
//!     .transport = &transport,
//! });
//! defer client.deinit();
//!
//! var repositories = client.git().repositories();
//! const list = try repositories.list(allocator, "contoso", null, null, null, null);
//! ```
//!
//! Areas do not share a host: `git` lives on `dev.azure.com`, `graph` on
//! `vssps.dev.azure.com`, package feeds on `pkgs.dev.azure.com`, and so
//! on. Each generated area client carries the default endpoint for its
//! own host, so an area accessor only overrides the endpoint when the
//! caller supplied one — which is what Azure DevOps Server deployments,
//! serving every area from a single host, need.

const std = @import("std");
const core = @import("azure_sdk_core");
const protocol = @import("azure_rest_devops");
const auth = @import("auth.zig");

const Credential = auth.Credential;
const CredentialPolicy = auth.CredentialPolicy;
const HttpPolicy = core.pipeline.HttpPolicy;

pub const user_agent = "azsdk-zig-devops/" ++ "0.1.0";

pub const ClientOptions = struct {
    /// Azure DevOps organization name, e.g. `contoso` for
    /// `https://dev.azure.com/contoso`. Operations take it as a
    /// parameter; storing it here lets callers pass `client.organization`
    /// instead of threading it through every call site.
    organization: []const u8,
    credential: Credential = .unauthenticated,
    transport: *core.http.HttpTransport,
    /// Overrides every area's own default host. Azure DevOps Server
    /// serves all areas from one collection URL, e.g.
    /// `https://tfs.contoso.com/tfs/DefaultCollection`; Azure DevOps
    /// Services should leave this null.
    endpoint: ?[]const u8 = null,
    /// Entra ID scope requested from a `TokenCredential`.
    scope: []const u8 = auth.devops_scope,
};

pub const DevOpsClient = struct {
    allocator: std.mem.Allocator,
    organization: []const u8,
    endpoint: ?[]const u8,
    credential_policy: *CredentialPolicy,
    telemetry_policy: *core.pipeline.TelemetryPolicy,
    retry_policy: *core.pipeline.RetryPolicy,
    policy_ptrs: []*HttpPolicy,
    pipeline: core.pipeline.HttpPipeline,

    pub fn init(allocator: std.mem.Allocator, options: ClientOptions) !DevOpsClient {
        const credential_policy = try allocator.create(CredentialPolicy);
        errdefer allocator.destroy(credential_policy);
        credential_policy.* = try CredentialPolicy.init(
            allocator,
            options.credential,
            .{ .scope = options.scope },
        );
        errdefer credential_policy.deinit();

        const telemetry_policy = try allocator.create(core.pipeline.TelemetryPolicy);
        errdefer allocator.destroy(telemetry_policy);
        telemetry_policy.* = core.pipeline.TelemetryPolicy.init(user_agent);

        const retry_policy = try allocator.create(core.pipeline.RetryPolicy);
        errdefer allocator.destroy(retry_policy);
        retry_policy.* = core.pipeline.RetryPolicy.init();

        const policy_ptrs = try allocator.alloc(*HttpPolicy, 3);
        errdefer allocator.free(policy_ptrs);
        policy_ptrs[0] = telemetry_policy.asPolicy();
        policy_ptrs[1] = retry_policy.asPolicy();
        policy_ptrs[2] = credential_policy.asPolicy();

        return .{
            .allocator = allocator,
            .organization = options.organization,
            .endpoint = options.endpoint,
            .credential_policy = credential_policy,
            .telemetry_policy = telemetry_policy,
            .retry_policy = retry_policy,
            .policy_ptrs = policy_ptrs,
            .pipeline = .{
                .policies = policy_ptrs,
                .transport_impl = options.transport,
            },
        };
    }

    pub fn deinit(self: *DevOpsClient) void {
        self.credential_policy.deinit();
        self.allocator.destroy(self.credential_policy);
        self.allocator.destroy(self.telemetry_policy);
        self.allocator.destroy(self.retry_policy);
        self.allocator.free(self.policy_ptrs);
        self.* = undefined;
    }

    /// Build any area client over this client's pipeline.
    ///
    /// The area accessors below are thin wrappers over this; use it
    /// directly to reach an area generically, e.g. in a helper that is
    /// itself generic over the area.
    pub fn areaClient(self: *DevOpsClient, comptime Client: type) Client {
        if (self.endpoint) |endpoint| {
            return Client.initWithPipeline(self.allocator, self.pipeline, .{
                .endpoint = endpoint,
            });
        }
        return Client.initWithPipeline(self.allocator, self.pipeline, .{});
    }

    pub fn account(self: *DevOpsClient) protocol.account.AccountClient {
        return self.areaClient(protocol.account.AccountClient);
    }
    pub fn advancedSecurity(self: *DevOpsClient) protocol.advanced_security.AdvancedSecurityClient {
        return self.areaClient(protocol.advanced_security.AdvancedSecurityClient);
    }
    pub fn approvalsAndChecks(self: *DevOpsClient) protocol.approvals_and_checks.ApprovalsAndChecksClient {
        return self.areaClient(protocol.approvals_and_checks.ApprovalsAndChecksClient);
    }
    pub fn artifacts(self: *DevOpsClient) protocol.artifacts.ArtifactsClient {
        return self.areaClient(protocol.artifacts.ArtifactsClient);
    }
    pub fn artifactsPackageTypes(self: *DevOpsClient) protocol.artifacts_package_types.ArtifactsPackageTypesClient {
        return self.areaClient(protocol.artifacts_package_types.ArtifactsPackageTypesClient);
    }
    pub fn audit(self: *DevOpsClient) protocol.audit.AuditClient {
        return self.areaClient(protocol.audit.AuditClient);
    }
    pub fn build(self: *DevOpsClient) protocol.build.BuildClient {
        return self.areaClient(protocol.build.BuildClient);
    }
    pub fn core_area(self: *DevOpsClient) protocol.core.CoreClient {
        return self.areaClient(protocol.core.CoreClient);
    }
    pub fn dashboard(self: *DevOpsClient) protocol.dashboard.DashboardClient {
        return self.areaClient(protocol.dashboard.DashboardClient);
    }
    pub fn delegatedAuth(self: *DevOpsClient) protocol.delegated_auth.DelegatedAuthorizationClient {
        return self.areaClient(protocol.delegated_auth.DelegatedAuthorizationClient);
    }
    pub fn distributedTask(self: *DevOpsClient) protocol.distributed_task.DistributedTaskClient {
        return self.areaClient(protocol.distributed_task.DistributedTaskClient);
    }
    pub fn environments(self: *DevOpsClient) protocol.environments.EnvironmentsClient {
        return self.areaClient(protocol.environments.EnvironmentsClient);
    }
    pub fn extensionManagement(self: *DevOpsClient) protocol.extension_management.ExtensionManagementClient {
        return self.areaClient(protocol.extension_management.ExtensionManagementClient);
    }
    pub fn favorite(self: *DevOpsClient) protocol.favorite.FavoriteClient {
        return self.areaClient(protocol.favorite.FavoriteClient);
    }
    pub fn git(self: *DevOpsClient) protocol.git.GitClient {
        return self.areaClient(protocol.git.GitClient);
    }
    pub fn graph(self: *DevOpsClient) protocol.graph.GraphClient {
        return self.areaClient(protocol.graph.GraphClient);
    }
    pub fn hooks(self: *DevOpsClient) protocol.hooks.ServiceHooksClient {
        return self.areaClient(protocol.hooks.ServiceHooksClient);
    }
    pub fn identities(self: *DevOpsClient) protocol.ims.IdentityClient {
        return self.areaClient(protocol.ims.IdentityClient);
    }
    pub fn memberEntitlementManagement(self: *DevOpsClient) protocol.member_entitlement_management.MemberEntitlementManagementClient {
        return self.areaClient(protocol.member_entitlement_management.MemberEntitlementManagementClient);
    }
    pub fn notification(self: *DevOpsClient) protocol.notification.NotificationClient {
        return self.areaClient(protocol.notification.NotificationClient);
    }
    pub fn operations(self: *DevOpsClient) protocol.operations.OperationsClient {
        return self.areaClient(protocol.operations.OperationsClient);
    }
    pub fn permissionsReport(self: *DevOpsClient) protocol.permissions_report.PermissionsReportClient {
        return self.areaClient(protocol.permissions_report.PermissionsReportClient);
    }
    pub fn pipelines(self: *DevOpsClient) protocol.pipelines.PipelinesClient {
        return self.areaClient(protocol.pipelines.PipelinesClient);
    }
    pub fn policy(self: *DevOpsClient) protocol.policy.PolicyClient {
        return self.areaClient(protocol.policy.PolicyClient);
    }
    pub fn processAdmin(self: *DevOpsClient) protocol.processadmin.WorkItemTrackingProcessTemplateClient {
        return self.areaClient(protocol.processadmin.WorkItemTrackingProcessTemplateClient);
    }
    pub fn processes(self: *DevOpsClient) protocol.processes.WorkItemTrackingClient {
        return self.areaClient(protocol.processes.WorkItemTrackingClient);
    }
    pub fn profile(self: *DevOpsClient) protocol.profile.ProfileClient {
        return self.areaClient(protocol.profile.ProfileClient);
    }
    pub fn release(self: *DevOpsClient) protocol.release.ReleaseClient {
        return self.areaClient(protocol.release.ReleaseClient);
    }
    pub fn resourceUsage(self: *DevOpsClient) protocol.resource_usage.ResourceUsageClient {
        return self.areaClient(protocol.resource_usage.ResourceUsageClient);
    }
    pub fn search(self: *DevOpsClient) protocol.search.SearchClient {
        return self.areaClient(protocol.search.SearchClient);
    }
    pub fn security(self: *DevOpsClient) protocol.security.SecurityClient {
        return self.areaClient(protocol.security.SecurityClient);
    }
    pub fn securityRoles(self: *DevOpsClient) protocol.security_roles.SecurityRolesClient {
        return self.areaClient(protocol.security_roles.SecurityRolesClient);
    }
    pub fn serviceEndpoint(self: *DevOpsClient) protocol.service_endpoint.ServiceEndpointClient {
        return self.areaClient(protocol.service_endpoint.ServiceEndpointClient);
    }
    pub fn status(self: *DevOpsClient) protocol.status.StatusClient {
        return self.areaClient(protocol.status.StatusClient);
    }
    pub fn symbol(self: *DevOpsClient) protocol.symbol.SymbolClient {
        return self.areaClient(protocol.symbol.SymbolClient);
    }
    pub fn testManagement(self: *DevOpsClient) protocol.@"test".TestClient {
        return self.areaClient(protocol.@"test".TestClient);
    }
    pub fn testPlan(self: *DevOpsClient) protocol.test_plan.TestPlanClient {
        return self.areaClient(protocol.test_plan.TestPlanClient);
    }
    pub fn testResults(self: *DevOpsClient) protocol.test_results.TestResultsClient {
        return self.areaClient(protocol.test_results.TestResultsClient);
    }
    pub fn tfvc(self: *DevOpsClient) protocol.tfvc.TfvcClient {
        return self.areaClient(protocol.tfvc.TfvcClient);
    }
    pub fn tokenAdmin(self: *DevOpsClient) protocol.token_admin.TokenAdminClient {
        return self.areaClient(protocol.token_admin.TokenAdminClient);
    }
    pub fn tokens(self: *DevOpsClient) protocol.tokens.TokensClient {
        return self.areaClient(protocol.tokens.TokensClient);
    }
    pub fn wiki(self: *DevOpsClient) protocol.wiki.WikiClient {
        return self.areaClient(protocol.wiki.WikiClient);
    }
    pub fn workItemTracking(self: *DevOpsClient) protocol.wit.WorkItemTrackingClient {
        return self.areaClient(protocol.wit.WorkItemTrackingClient);
    }
    pub fn work(self: *DevOpsClient) protocol.work.WorkClient {
        return self.areaClient(protocol.work.WorkClient);
    }
};
