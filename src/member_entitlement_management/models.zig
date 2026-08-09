//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A group entity with additional properties including its license, extensions, and project membership
pub const GroupEntitlement = struct {
    group: ?GraphGroup = null,
    /// The unique identifier which matches the Id of the GraphMember.
    id: ?[]const u8 = null,
    /// [Readonly] The last time the group licensing rule was executed (regardless of whether any changes were made).
    last_executed: ?[]const u8 = null,
    license_rule: ?AccessLevel = null,
    /// Group members. Only used when creating a new group.
    members: ?[]const UserEntitlement = null,
    /// Relation between a project and the member's effective permissions in that project.
    project_entitlements: ?[]const ProjectEntitlement = null,
    /// The status of the group rule.
    status: ?enums.GroupEntitlementStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Graph group entity
pub const GraphGroup = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// [Internal Use Only] The legacy descriptor is here in case you need to access old version IMS using identity descriptor.
    legacy_descriptor: ?[]const u8 = null,
    /// The type of source provider for the origin identifier (ex:AD, AAD, MSA)
    origin: ?[]const u8 = null,
    /// The unique identifier from the system of origin. Typically a sid, object id or Guid. Linking and unlinking operations can cause this value to change for a user because the user is not backed by a different provider and has a different unique id in the new provider.
    origin_id: ?[]const u8 = null,
    /// This field identifies the type of the graph subject (ex: Group, Scope, User).
    subject_kind: ?[]const u8 = null,
    /// This represents the name of the container of origin for a graph member. (For MSA this is 'Windows Live ID', for AD the name of the domain, for AAD the tenantID of the directory, for VSTS groups the ScopeId, etc)
    domain: ?[]const u8 = null,
    /// The email address of record for a given graph member. This may be different than the principal name.
    mail_address: ?[]const u8 = null,
    /// This is the PrincipalName of this graph member from the source provider. The source provider may change this field over time and it is not guaranteed to be immutable for the life of the graph member by VSTS.
    principal_name: ?[]const u8 = null,
    /// A short phrase to help human readers disambiguate groups with similar names
    description: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The class to represent a collection of REST reference links.
pub const ReferenceLinks = struct {
    /// The readonly view of the links. Because Reference links are readonly, we only want to expose them as read only.
    links: ?std.json.ArrayHashMap(ReferenceLinksLink) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ReferenceLinksLink = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// License assigned to a user
pub const AccessLevel = struct {
    /// Type of Account License (e.g. Express, Stakeholder etc.). To use the AccountLicenseType, LicensingSource should be defined as 'account' in the request body.
    account_license_type: ?enums.AccessLevelAccountLicenseType = null,
    /// Assignment Source of the License (e.g. Group, Unknown etc.
    assignment_source: ?enums.AccessLevelAssignmentSource = null,
    /// Type of GitHub License (only Enterprise for now). To use the GitHubLicenseType, LicensingSource should be defined as 'github' in the request body.
    git_hub_license_type: ?enums.AccessLevelGitHubLicenseType = null,
    /// Display name of the License
    license_display_name: ?[]const u8 = null,
    /// Licensing Source (e.g. Account. MSDN etc.)
    licensing_source: ?enums.AccessLevelLicensingSource = null,
    /// Type of MSDN License (e.g. Visual Studio Professional, Visual Studio Enterprise etc.). To use the MsdnLicenseType, LicensingSource should be defined as 'msdn' in the request body.
    msdn_license_type: ?enums.AccessLevelMsdnLicenseType = null,
    /// User status in the account
    status: ?enums.AccessLevelStatus = null,
    /// Status message.
    status_message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A user entity with additional properties including their license, extensions, and project membership
pub const UserEntitlement = struct {
    access_level: ?AccessLevel = null,
    /// [Readonly] Date the member was added to the collection.
    date_created: ?[]const u8 = null,
    /// [Readonly] GroupEntitlements that this member belongs to.
    group_assignments: ?[]const GroupEntitlement = null,
    /// The unique identifier which matches the Id of the Identity associated with the GraphMember.
    id: ?[]const u8 = null,
    /// [Readonly] Date the member last accessed the collection.
    last_accessed_date: ?[]const u8 = null,
    /// Relation between a project and the member's effective permissions in that project.
    project_entitlements: ?[]const ProjectEntitlement = null,
    user: ?GraphUser = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Relation between a project and the user's effective permissions in that project.
pub const ProjectEntitlement = struct {
    /// Assignment Source (e.g. Group or Unknown).
    assignment_source: ?enums.ProjectEntitlementAssignmentSource = null,
    group: ?Group = null,
    /// Whether the user is inheriting permissions to a project through a Azure DevOps or AAD group membership.
    project_permission_inherited: ?enums.ProjectEntitlementProjectPermissionInherited = null,
    project_ref: ?ProjectRef = null,
    /// Team Ref.
    team_refs: ?[]const TeamRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Project Group (e.g. Contributor, Reader etc.)
pub const Group = struct {
    /// Display Name of the Group
    display_name: ?[]const u8 = null,
    /// Group Type
    group_type: ?enums.GroupGroupType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A reference to a project
pub const ProjectRef = struct {
    /// Project ID.
    id: ?[]const u8 = null,
    /// Project Name.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A reference to a team
pub const TeamRef = struct {
    /// Team ID
    id: ?[]const u8 = null,
    /// Team Name
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GraphUser = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// [Internal Use Only] The legacy descriptor is here in case you need to access old version IMS using identity descriptor.
    legacy_descriptor: ?[]const u8 = null,
    /// The type of source provider for the origin identifier (ex:AD, AAD, MSA)
    origin: ?[]const u8 = null,
    /// The unique identifier from the system of origin. Typically a sid, object id or Guid. Linking and unlinking operations can cause this value to change for a user because the user is not backed by a different provider and has a different unique id in the new provider.
    origin_id: ?[]const u8 = null,
    /// This field identifies the type of the graph subject (ex: Group, Scope, User).
    subject_kind: ?[]const u8 = null,
    /// This represents the name of the container of origin for a graph member. (For MSA this is 'Windows Live ID', for AD the name of the domain, for AAD the tenantID of the directory, for VSTS groups the ScopeId, etc)
    domain: ?[]const u8 = null,
    /// The email address of record for a given graph member. This may be different than the principal name.
    mail_address: ?[]const u8 = null,
    /// This is the PrincipalName of this graph member from the source provider. The source provider may change this field over time and it is not guaranteed to be immutable for the life of the graph member by VSTS.
    principal_name: ?[]const u8 = null,
    /// The short, generally unique name for the user in the backing directory. For AAD users, this corresponds to the mail nickname, which is often but not necessarily similar to the part of the user's mail address before the @ sign. For GitHub users, this corresponds to the GitHub user handle.
    directory_alias: ?[]const u8 = null,
    /// When true, the group has been deleted in the identity provider
    is_deleted_in_origin: ?bool = null,
    /// The meta type of the user in the origin, such as 'member', 'guest', etc. See UserMetaType for the set of possible values.
    meta_type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const GroupEntitlementOperationReference = struct {
    /// Unique identifier for the operation.
    id: ?[]const u8 = null,
    /// Unique identifier for the plugin.
    plugin_id: ?[]const u8 = null,
    /// The current status of the operation.
    status: ?enums.GroupEntitlementOperationReferenceStatus = null,
    /// URL to get the full operation object.
    url: ?[]const u8 = null,
    /// Operation completed with success or failure.
    completed: ?bool = null,
    /// True if all operations were successful.
    have_results_succeeded: ?bool = null,
    /// List of results for each operation.
    results: ?[]const GroupOperationResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GroupOperationResult = struct {
    /// List of error codes paired with their corresponding error messages
    errors: ?[]const GroupOperationResultError = null,
    /// Success status of the operation
    is_success: ?bool = null,
    /// Identifier of the Group being acted upon
    group_id: ?[]const u8 = null,
    result: ?GroupEntitlement = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GroupOperationResultError = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The JSON model for JSON Patch Operations
pub const JsonPatchDocument = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A page of users
pub const PagedGraphMemberList = struct {
    continuation_token: ?[]const u8 = null,
    items: ?[]const UserEntitlement = null,
    members: ?[]const UserEntitlement = null,
    total_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ServicePrincipalEntitlementOperationReference = struct {
    /// Unique identifier for the operation.
    id: ?[]const u8 = null,
    /// Unique identifier for the plugin.
    plugin_id: ?[]const u8 = null,
    /// The current status of the operation.
    status: ?enums.GroupEntitlementOperationReferenceStatus = null,
    /// URL to get the full operation object.
    url: ?[]const u8 = null,
    /// Operation completed with success or failure.
    completed: ?bool = null,
    /// True if all operations were successful.
    have_results_succeeded: ?bool = null,
    /// List of results for each operation.
    results: ?[]const ServicePrincipalEntitlementOperationResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ServicePrincipalEntitlementOperationResult = struct {
    /// List of error codes paired with their corresponding error messages.
    errors: ?[]const ServicePrincipalEntitlementOperationResultError = null,
    /// Success status of the operation.
    is_success: ?bool = null,
    /// Resulting entitlement property. For specific implementations, see also: <seealso cref='T:Microsoft.VisualStudio.Services.MemberEntitlementManagement.WebApi.ServicePrincipalEntitlementOperationResult' /><seealso cref='T:Microsoft.VisualStudio.Services.MemberEntitlementManagement.WebApi.UserEntitlementOperationResult' />
    result: ?[]const u8 = null,
    /// Identifier of the ServicePrincipal being acted upon.
    service_principal_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ServicePrincipalEntitlementOperationResultError = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ServicePrincipalEntitlement = struct {
    access_level: ?AccessLevel = null,
    /// [Readonly] Date the member was added to the collection.
    date_created: ?[]const u8 = null,
    /// [Readonly] GroupEntitlements that this member belongs to.
    group_assignments: ?[]const GroupEntitlement = null,
    /// The unique identifier which matches the Id of the Identity associated with the GraphMember.
    id: ?[]const u8 = null,
    /// [Readonly] Date the member last accessed the collection.
    last_accessed_date: ?[]const u8 = null,
    /// Relation between a project and the member's effective permissions in that project.
    project_entitlements: ?[]const ProjectEntitlement = null,
    service_principal: ?GraphServicePrincipal = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GraphServicePrincipal = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// [Internal Use Only] The legacy descriptor is here in case you need to access old version IMS using identity descriptor.
    legacy_descriptor: ?[]const u8 = null,
    /// The type of source provider for the origin identifier (ex:AD, AAD, MSA)
    origin: ?[]const u8 = null,
    /// The unique identifier from the system of origin. Typically a sid, object id or Guid. Linking and unlinking operations can cause this value to change for a user because the user is not backed by a different provider and has a different unique id in the new provider.
    origin_id: ?[]const u8 = null,
    /// This field identifies the type of the graph subject (ex: Group, Scope, User).
    subject_kind: ?[]const u8 = null,
    /// This represents the name of the container of origin for a graph member. (For MSA this is 'Windows Live ID', for AD the name of the domain, for AAD the tenantID of the directory, for VSTS groups the ScopeId, etc)
    domain: ?[]const u8 = null,
    /// The email address of record for a given graph member. This may be different than the principal name.
    mail_address: ?[]const u8 = null,
    /// This is the PrincipalName of this graph member from the source provider. The source provider may change this field over time and it is not guaranteed to be immutable for the life of the graph member by VSTS.
    principal_name: ?[]const u8 = null,
    /// The short, generally unique name for the user in the backing directory. For AAD users, this corresponds to the mail nickname, which is often but not necessarily similar to the part of the user's mail address before the @ sign. For GitHub users, this corresponds to the GitHub user handle.
    directory_alias: ?[]const u8 = null,
    /// When true, the group has been deleted in the identity provider
    is_deleted_in_origin: ?bool = null,
    /// The meta type of the user in the origin, such as 'member', 'guest', etc. See UserMetaType for the set of possible values.
    meta_type: ?[]const u8 = null,
    application_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const ServicePrincipalEntitlementsPostResponse = struct {
    is_success: ?bool = null,
    service_principal_entitlement: ?ServicePrincipalEntitlement = null,
    operation_result: ?ServicePrincipalEntitlementOperationResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ServicePrincipalEntitlementsPatchResponse = struct {
    is_success: ?bool = null,
    service_principal_entitlement: ?ServicePrincipalEntitlement = null,
    operation_results: ?[]const ServicePrincipalEntitlementOperationResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A page of user entitlements
pub const PagedUserEntitlementsList = struct {
    /// The continuation token for next page of data. Can be null, if no more data exists.
    continuation_token: ?[]const u8 = null,
    /// The requested user entitlement items.
    items: ?[]const UserEntitlement = null,
    /// The total count of the existing user entitlement items.
    total_count: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UserEntitlementOperationReference = struct {
    /// Unique identifier for the operation.
    id: ?[]const u8 = null,
    /// Unique identifier for the plugin.
    plugin_id: ?[]const u8 = null,
    /// The current status of the operation.
    status: ?enums.GroupEntitlementOperationReferenceStatus = null,
    /// URL to get the full operation object.
    url: ?[]const u8 = null,
    /// Operation completed with success or failure.
    completed: ?bool = null,
    /// True if all operations were successful.
    have_results_succeeded: ?bool = null,
    /// List of results for each operation.
    results: ?[]const UserEntitlementOperationResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UserEntitlementOperationResult = struct {
    /// List of error codes paired with their corresponding error messages.
    errors: ?[]const ServicePrincipalEntitlementOperationResultError = null,
    /// Success status of the operation.
    is_success: ?bool = null,
    /// Resulting entitlement property. For specific implementations, see also: <seealso cref='T:Microsoft.VisualStudio.Services.MemberEntitlementManagement.WebApi.ServicePrincipalEntitlementOperationResult' /><seealso cref='T:Microsoft.VisualStudio.Services.MemberEntitlementManagement.WebApi.UserEntitlementOperationResult' />
    result: ?[]const u8 = null,
    /// Identifier of the Member being acted upon.
    user_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UserEntitlementsPostResponse = struct {
    /// True if all operations were successful.
    is_success: ?bool = null,
    user_entitlement: ?UserEntitlement = null,
    operation_result: ?UserEntitlementOperationResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UserEntitlementsPatchResponse = struct {
    /// True if all operations were successful.
    is_success: ?bool = null,
    user_entitlement: ?UserEntitlement = null,
    /// List of results for each operation.
    operation_results: ?[]const UserEntitlementOperationResult = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Summary of licenses and extensions assigned to users in the organization
pub const UsersSummary = struct {
    /// Available Access Levels
    available_access_levels: ?[]const AccessLevel = null,
    default_access_level: ?AccessLevel = null,
    /// Group Options
    group_options: ?[]const GroupOption = null,
    /// Summary of Licenses in the organization
    licenses: ?[]const LicenseSummaryData = null,
    /// Summary of Projects in the organization
    project_refs: ?[]const ProjectRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Group option to add a user to
pub const GroupOption = struct {
    access_level: ?AccessLevel = null,
    group: ?Group = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Summary of Licenses in the organization.
pub const LicenseSummaryData = struct {
    /// Count of Licenses already assigned.
    assigned: ?i32 = null,
    /// Available Count.
    available: ?i32 = null,
    /// Quantity
    included_quantity: ?i32 = null,
    /// Total Count.
    total: ?i32 = null,
    /// Type of Account License. To use the AccountLicenseType, LicensingSource should be defined as 'account' in the request body.
    account_license_type: ?enums.LicenseSummaryDataAccountLicenseType = null,
    /// Count of Disabled Licenses.
    disabled: ?i32 = null,
    /// Type of GitHub License. To use the GitHubLicenseType, LicensingSource should be defined as 'github' in the request body.
    git_hub_license_type: ?enums.LicenseSummaryDataGitHubLicenseType = null,
    /// Designates if this license quantity can be changed through purchase
    is_purchasable: ?bool = null,
    /// Name of the License.
    license_name: ?[]const u8 = null,
    /// Count of Expired MSDN Licenses.
    msdn_expired: ?i32 = null,
    /// Type of MSDN License. To use the MsdnLicenseType, LicensingSource should be defined as 'msdn' in the request body.
    msdn_license_type: ?enums.LicenseSummaryDataMsdnLicenseType = null,
    /// Specifies the date when billing will charge for paid licenses
    next_billing_date: ?[]const u8 = null,
    /// Source of the License.
    source: ?enums.LicenseSummaryDataSource = null,
    /// Total license count after next billing cycle
    total_after_next_billing_date: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
