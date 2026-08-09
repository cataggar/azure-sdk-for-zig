//! Azure DevOps REST for Zig — generated from TypeSpec.
//!
//! Do not edit by hand. Regenerate with `codegen`.
//!
//! Each API area is a namespace with its own clients, models and
//! enums; area names are the ones Azure DevOps uses in its REST
//! documentation.

pub const account = @import("account/root.zig");
pub const advanced_security = @import("advanced_security/root.zig");
pub const approvals_and_checks = @import("approvals_and_checks/root.zig");
pub const artifacts = @import("artifacts/root.zig");
pub const artifacts_package_types = @import("artifacts_package_types/root.zig");
pub const audit = @import("audit/root.zig");
pub const build = @import("build/root.zig");
pub const core = @import("core/root.zig");
pub const dashboard = @import("dashboard/root.zig");
pub const delegated_auth = @import("delegated_auth/root.zig");
pub const distributed_task = @import("distributed_task/root.zig");
pub const environments = @import("environments/root.zig");
pub const extension_management = @import("extension_management/root.zig");
pub const favorite = @import("favorite/root.zig");
pub const git = @import("git/root.zig");
pub const graph = @import("graph/root.zig");
pub const hooks = @import("hooks/root.zig");
pub const ims = @import("ims/root.zig");
pub const member_entitlement_management = @import("member_entitlement_management/root.zig");
pub const notification = @import("notification/root.zig");
pub const operations = @import("operations/root.zig");
pub const permissions_report = @import("permissions_report/root.zig");
pub const pipelines = @import("pipelines/root.zig");
pub const policy = @import("policy/root.zig");
pub const processadmin = @import("processadmin/root.zig");
pub const processes = @import("processes/root.zig");
pub const profile = @import("profile/root.zig");
pub const release = @import("release/root.zig");
pub const resource_usage = @import("resource_usage/root.zig");
pub const search = @import("search/root.zig");
pub const security = @import("security/root.zig");
pub const security_roles = @import("security_roles/root.zig");
pub const service_endpoint = @import("service_endpoint/root.zig");
pub const status = @import("status/root.zig");
pub const symbol = @import("symbol/root.zig");
pub const @"test" = @import("test/root.zig");
pub const test_plan = @import("test_plan/root.zig");
pub const test_results = @import("test_results/root.zig");
pub const tfvc = @import("tfvc/root.zig");
pub const token_admin = @import("token_admin/root.zig");
pub const tokens = @import("tokens/root.zig");
pub const wiki = @import("wiki/root.zig");
pub const wit = @import("wit/root.zig");
pub const work = @import("work/root.zig");

test {
    _ = @import("clients_test.zig");
}
