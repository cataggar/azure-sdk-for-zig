//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

pub const GitDeletedRepository = struct {
    created_date: ?[]const u8 = null,
    deleted_by: ?IdentityRef = null,
    deleted_date: ?[]const u8 = null,
    id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    project: ?TeamProjectReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const IdentityRef = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph user referenced in the 'self' entry of the IdentityRef '_links' dictionary
    directory_alias: ?[]const u8 = null,
    id: ?[]const u8 = null,
    /// Deprecated - Available in the 'avatar' entry of the IdentityRef '_links' dictionary
    image_url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph membership state referenced in the 'membershipState' entry of the GraphUser '_links' dictionary
    inactive: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsAadUserType/Descriptor.IsAadGroupType)
    is_aad_identity: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsGroupType)
    is_container: ?bool = null,
    is_deleted_in_origin: ?bool = null,
    /// Deprecated - not in use in most preexisting implementations of ToIdentityRef
    profile_url: ?[]const u8 = null,
    /// Deprecated - use Domain+PrincipalName instead
    unique_name: ?[]const u8 = null,

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

/// Represents a shallow reference to a TeamProject.
pub const TeamProjectReference = struct {
    /// Project abbreviation.
    abbreviation: ?[]const u8 = null,
    /// Url to default team identity image.
    default_team_image_url: ?[]const u8 = null,
    /// The project's description (if any).
    description: ?[]const u8 = null,
    /// Project identifier.
    id: ?[]const u8 = null,
    /// Project last update time.
    last_update_time: ?[]const u8 = null,
    /// Project name.
    name: ?[]const u8 = null,
    /// Project revision.
    revision: ?i64 = null,
    /// Project state.
    state: ?enums.TeamProjectReferenceState = null,
    /// Url to the full version of the object.
    url: ?[]const u8 = null,
    /// Project visibility.
    visibility: ?enums.TeamProjectReferenceVisibility = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitRecycleBinRepositoryDetails = struct {
    /// Setting to false will undo earlier deletion and restore the repository.
    deleted: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitRepository = struct {
    links: ?ReferenceLinks = null,
    /// The timestamp when the repository was created.
    creation_date: ?[]const u8 = null,
    default_branch: ?[]const u8 = null,
    id: ?[]const u8 = null,
    /// True if the repository is disabled. False otherwise.
    is_disabled: ?bool = null,
    /// True if the repository was created as a fork.
    is_fork: ?bool = null,
    /// True if the repository is in maintenance. False otherwise.
    is_in_maintenance: ?bool = null,
    name: ?[]const u8 = null,
    parent_repository: ?GitRepositoryRef = null,
    project: ?TeamProjectReference = null,
    remote_url: ?[]const u8 = null,
    /// Compressed size (bytes) of the repository.
    size: ?i64 = null,
    ssh_url: ?[]const u8 = null,
    url: ?[]const u8 = null,
    valid_remote_urls: ?[]const []const u8 = null,
    web_url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const GitRepositoryRef = struct {
    collection: ?TeamProjectCollectionReference = null,
    id: ?[]const u8 = null,
    /// True if the repository was created as a fork
    is_fork: ?bool = null,
    name: ?[]const u8 = null,
    project: ?TeamProjectReference = null,
    remote_url: ?[]const u8 = null,
    ssh_url: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference object for a TeamProjectCollection.
pub const TeamProjectCollectionReference = struct {
    /// Collection avatar Url.
    avatar_url: ?[]const u8 = null,
    /// Collection Id.
    id: ?[]const u8 = null,
    /// Collection Name.
    name: ?[]const u8 = null,
    /// Collection REST Url.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitRepositoryCreateOptions = struct {
    name: ?[]const u8 = null,
    parent_repository: ?GitRepositoryRef = null,
    project: ?TeamProjectReference = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitRefFavorite = struct {
    links: ?ReferenceLinks = null,
    id: ?i32 = null,
    identity_id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    repository_id: ?[]const u8 = null,
    type: ?enums.GitRefFavoriteType = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The full policy configuration with settings.
pub const PolicyConfiguration = struct {
    /// The policy configuration ID.
    id: ?i32 = null,
    type: ?PolicyTypeRef = null,
    /// The URL where the policy configuration can be retrieved.
    url: ?[]const u8 = null,
    /// The policy configuration revision ID.
    revision: ?i32 = null,
    links: ?ReferenceLinks = null,
    created_by: ?IdentityRef = null,
    /// The date and time when the policy was created.
    created_date: ?[]const u8 = null,
    /// Indicates whether the policy is blocking.
    is_blocking: ?bool = null,
    /// Indicates whether the policy has been (soft) deleted.
    is_deleted: ?bool = null,
    /// Indicates whether the policy is enabled.
    is_enabled: ?bool = null,
    /// If set, this policy requires 'Manage Enterprise Policies' permission to create, edit, or delete.
    is_enterprise_managed: ?bool = null,
    /// The policy configuration settings.
    settings: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Policy type reference.
pub const PolicyTypeRef = struct {
    /// Display name of the policy type.
    display_name: ?[]const u8 = null,
    /// The policy type ID.
    id: ?[]const u8 = null,
    /// The URL where the policy type can be retrieved.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents all the data associated with a pull request.
pub const GitPullRequest = struct {
    links: ?ReferenceLinks = null,
    /// A string which uniquely identifies this pull request. To generate an artifact ID for a pull request, use this template: ```vstfs:///Git/PullRequestId/{projectId}/{repositoryId}/{pullRequestId}```
    artifact_id: ?[]const u8 = null,
    auto_complete_set_by: ?IdentityRef = null,
    closed_by: ?IdentityRef = null,
    /// The date when the pull request was closed (completed, abandoned, or merged externally).
    closed_date: ?[]const u8 = null,
    /// The code review ID of the pull request. Used internally.
    code_review_id: ?i32 = null,
    /// The commits contained in the pull request.
    commits: ?[]const GitCommitRef = null,
    completion_options: ?GitPullRequestCompletionOptions = null,
    /// The most recent date at which the pull request entered the queue to be completed. Used internally.
    completion_queue_time: ?[]const u8 = null,
    created_by: ?IdentityRef = null,
    /// The date when the pull request was created.
    creation_date: ?[]const u8 = null,
    /// The description of the pull request.
    description: ?[]const u8 = null,
    fork_source: ?GitForkRef = null,
    /// Multiple mergebases warning
    has_multiple_merge_bases: ?bool = null,
    /// This optional parameter allows clients to use server-side dynamic choices for the target ref. Due to preexisting contracts, users _must_ specify a target ref, but this option will cause the server to ignore it and choose dynamically from the user's favorites (or the default branch).
    ignore_target_ref_and_choose_dynamically: ?bool = null,
    /// Draft / WIP pull request.
    is_draft: ?bool = null,
    /// The labels associated with the pull request.
    labels: ?[]const WebApiTagDefinition = null,
    last_merge_commit: ?GitCommitRef = null,
    last_merge_source_commit: ?GitCommitRef = null,
    last_merge_target_commit: ?GitCommitRef = null,
    /// If set, pull request merge failed for this reason.
    merge_failure_message: ?[]const u8 = null,
    /// The type of failure (if any) of the pull request merge.
    merge_failure_type: ?enums.GitPullRequestMergeFailureType = null,
    /// The ID of the job used to run the pull request merge. Used internally.
    merge_id: ?[]const u8 = null,
    merge_options: ?GitPullRequestMergeOptions = null,
    /// The current status of the pull request merge.
    merge_status: ?enums.GitPullRequestMergeStatus = null,
    /// The ID of the pull request.
    pull_request_id: ?i32 = null,
    /// Used internally.
    remote_url: ?[]const u8 = null,
    repository: ?GitRepository = null,
    /// A list of reviewers on the pull request along with the state of their votes.
    reviewers: ?[]const IdentityRefWithVote = null,
    /// The name of the source branch of the pull request.
    source_ref_name: ?[]const u8 = null,
    /// The status of the pull request.
    status: ?enums.GitPullRequestStatus1 = null,
    /// If true, this pull request supports multiple iterations. Iteration support means individual pushes to the source branch of the pull request can be reviewed and comments left in one iteration will be tracked across future iterations.
    supports_iterations: ?bool = null,
    /// The name of the target branch of the pull request.
    target_ref_name: ?[]const u8 = null,
    /// The title of the pull request.
    title: ?[]const u8 = null,
    /// Used internally.
    url: ?[]const u8 = null,
    /// Any work item references associated with this pull request.
    work_item_refs: ?[]const ResourceRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Provides properties that describe a Git commit and associated metadata.
pub const GitCommitRef = struct {
    links: ?ReferenceLinks = null,
    author: ?GitUserDate = null,
    change_counts: ?ChangeCountDictionary = null,
    /// An enumeration of the changes included with the commit.
    changes: ?[]const GitChange = null,
    /// Comment or message of the commit.
    comment: ?[]const u8 = null,
    /// Indicates if the comment is truncated from the full Git commit comment message.
    comment_truncated: ?bool = null,
    /// ID (SHA-1) of the commit.
    commit_id: ?[]const u8 = null,
    committer: ?GitUserDate = null,
    /// Indicates that commit contains too many changes to be displayed
    commit_too_many_changes: ?bool = null,
    /// An enumeration of the parent commit IDs for this commit.
    parents: ?[]const []const u8 = null,
    push: ?GitPushRef = null,
    /// Remote URL path to the commit.
    remote_url: ?[]const u8 = null,
    /// A list of status metadata from services and extensions that may associate additional information to the commit.
    statuses: ?[]const GitStatus = null,
    /// REST URL for this resource.
    url: ?[]const u8 = null,
    /// A list of workitems associated with this commit.
    work_items: ?[]const ResourceRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// User info and date for Git operations.
pub const GitUserDate = struct {
    /// Date of the Git operation.
    date: ?[]const u8 = null,
    /// Email address of the user performing the Git operation.
    email: ?[]const u8 = null,
    /// Url for the user's avatar.
    image_url: ?[]const u8 = null,
    /// Name of the user performing the Git operation.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ChangeCountDictionary = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitChange = struct {
    /// The type of change that was made to the item.
    change_type: ?enums.GitChangeChangeType = null,
    /// Current version.
    item: ?[]const u8 = null,
    new_content: ?ItemContent = null,
    /// Path of the item on the server.
    source_server_item: ?[]const u8 = null,
    /// URL to retrieve the item.
    url: ?[]const u8 = null,
    /// ID of the change within the group of changes.
    change_id: ?i32 = null,
    new_content_template: ?GitTemplate = null,
    /// Original path of item if different from current path.
    original_path: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ItemContent = struct {
    content: ?[]const u8 = null,
    content_type: ?enums.ItemContentContentType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitTemplate = struct {
    /// Name of the Template
    name: ?[]const u8 = null,
    /// Type of the Template
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitPushRef = struct {
    links: ?ReferenceLinks = null,
    date: ?[]const u8 = null,
    pushed_by: ?IdentityRef = null,
    push_id: ?i32 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// This class contains the metadata of a service/extension posting a status.
pub const GitStatus = struct {
    links: ?ReferenceLinks = null,
    context: ?GitStatusContext = null,
    created_by: ?IdentityRef = null,
    /// Creation date and time of the status.
    creation_date: ?[]const u8 = null,
    /// Status description. Typically describes current state of the status.
    description: ?[]const u8 = null,
    /// Status identifier.
    id: ?i32 = null,
    /// State of the status.
    state: ?enums.GitStatusState = null,
    /// URL with status details.
    target_url: ?[]const u8 = null,
    /// Last update date and time of the status.
    updated_date: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Status context that uniquely identifies the status.
pub const GitStatusContext = struct {
    /// Genre of the status. Typically name of the service/tool generating the status, can be empty.
    genre: ?[]const u8 = null,
    /// Name identifier of the status, cannot be null or empty.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ResourceRef = struct {
    id: ?[]const u8 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Preferences about how the pull request should be completed.
pub const GitPullRequestCompletionOptions = struct {
    /// List of any policy configuration Id's which auto-complete should not wait for. Only applies to optional policies (isBlocking == false). Auto-complete always waits for required policies (isBlocking == true).
    auto_complete_ignore_config_ids: ?[]const i32 = null,
    /// If true, policies will be explicitly bypassed while the pull request is completed.
    bypass_policy: ?bool = null,
    /// If policies are bypassed, this reason is stored as to why bypass was used.
    bypass_reason: ?[]const u8 = null,
    /// If true, the source branch of the pull request will be deleted after completion.
    delete_source_branch: ?bool = null,
    /// If set, this will be used as the commit message of the merge commit.
    merge_commit_message: ?[]const u8 = null,
    /// Specify the strategy used to merge the pull request during completion. If MergeStrategy is not set to any value, the service selects the first merge strategy not prohibited by the target branch’s policy. If the limit merge type policy is not configured, the default is noFastForward unless the deprecated SquashMerge is true, in which case the default is squash. If an explicit value is provided for MergeStrategy, the SquashMerge property will be ignored.
    merge_strategy: ?enums.GitPullRequestCompletionOptionsMergeStrategy = null,
    /// SquashMerge is deprecated. You should explicitly set the value of MergeStrategy. This flag is only used when MergeStrategy is not specified and the target branch has no merge-strategy policy configured. In all other cases it is ignored.
    squash_merge: ?bool = null,
    /// If true, we will attempt to transition any work items linked to the pull request into the next logical state (i.e. Active -> Resolved)
    transition_work_items: ?bool = null,
    /// If true, the current completion attempt was triggered via auto-complete. Used internally.
    triggered_by_auto_complete: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Information about a fork ref.
pub const GitForkRef = struct {
    links: ?ReferenceLinks = null,
    creator: ?IdentityRef = null,
    is_locked: ?bool = null,
    is_locked_by: ?IdentityRef = null,
    name: ?[]const u8 = null,
    object_id: ?[]const u8 = null,
    peeled_object_id: ?[]const u8 = null,
    statuses: ?[]const GitStatus = null,
    url: ?[]const u8 = null,
    repository: ?GitRepository = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The representation of a tag definition which is sent across the wire.
pub const WebApiTagDefinition = struct {
    /// Whether or not the tag definition is active.
    active: ?bool = null,
    /// ID of the tag definition.
    id: ?[]const u8 = null,
    /// The name of the tag definition.
    name: ?[]const u8 = null,
    /// Resource URL for the Tag Definition.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The options which are used when a pull request merge is created.
pub const GitPullRequestMergeOptions = struct {
    /// If true, conflict resolutions applied during the merge will be put in separate commits to preserve authorship info for git blame, etc.
    conflict_authorship_commits: ?bool = null,
    /// If true, renames where there is more than one valid way to map the original file locations to renamed file locations will be treated as false positives and ignored.
    detect_rename_false_positives: ?bool = null,
    /// If true, rename detection will not be performed during the merge.
    disable_renames: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Identity information including a vote on a pull request.
pub const IdentityRefWithVote = struct {
    links: ?ReferenceLinks = null,
    /// The descriptor is the primary way to reference the graph subject while the system is running. This field will uniquely identify the same graph subject across both Accounts and Organizations.
    descriptor: ?[]const u8 = null,
    /// This is the non-unique display name of the graph subject. To change this field, you must alter its value in the source provider.
    display_name: ?[]const u8 = null,
    /// This url is the full route to the source resource of this graph subject.
    url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph user referenced in the 'self' entry of the IdentityRef '_links' dictionary
    directory_alias: ?[]const u8 = null,
    id: ?[]const u8 = null,
    /// Deprecated - Available in the 'avatar' entry of the IdentityRef '_links' dictionary
    image_url: ?[]const u8 = null,
    /// Deprecated - Can be retrieved by querying the Graph membership state referenced in the 'membershipState' entry of the GraphUser '_links' dictionary
    inactive: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsAadUserType/Descriptor.IsAadGroupType)
    is_aad_identity: ?bool = null,
    /// Deprecated - Can be inferred from the subject type of the descriptor (Descriptor.IsGroupType)
    is_container: ?bool = null,
    is_deleted_in_origin: ?bool = null,
    /// Deprecated - not in use in most preexisting implementations of ToIdentityRef
    profile_url: ?[]const u8 = null,
    /// Deprecated - use Domain+PrincipalName instead
    unique_name: ?[]const u8 = null,
    /// Indicates if this reviewer has declined to review this pull request.
    has_declined: ?bool = null,
    /// Indicates if this reviewer is flagged for attention on this pull request.
    is_flagged: ?bool = null,
    /// Indicates if this approve vote should still be handled even though vote didn't change.
    is_reapprove: ?bool = null,
    /// Indicates if this is a required reviewer for this pull request. <br /> Branches can have policies that require particular reviewers are required for pull requests.
    is_required: ?bool = null,
    /// URL to retrieve information about this identity
    reviewer_url: ?[]const u8 = null,
    /// Vote on a pull request:<br /> 10 - approved 5 - approved with suggestions 0 - no vote -5 - waiting for author -10 - rejected
    vote: ?i16 = null,
    /// Groups or teams that this reviewer contributed to. <br /> Groups and teams can be reviewers on pull requests but can not vote directly. When a member of the group or team votes, that vote is rolled up into the group or team vote. VotedFor is a list of such votes.
    voted_for: ?[]const IdentityRefWithVote = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// A Git annotated tag.
pub const GitAnnotatedTag = struct {
    /// The tagging Message
    message: ?[]const u8 = null,
    /// The name of the annotated tag.
    name: ?[]const u8 = null,
    /// The objectId (Sha1Id) of the tag.
    object_id: ?[]const u8 = null,
    tagged_by: ?GitUserDate = null,
    tagged_object: ?GitObject = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Git object identifier and type information.
pub const GitObject = struct {
    /// Object Id (Sha1Id).
    object_id: ?[]const u8 = null,
    /// Type of object (Commit, Tree, Blob, Tag)
    object_type: ?enums.GitObjectObjectType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitBlobRef = struct {
    links: ?ReferenceLinks = null,
    /// SHA1 hash of git object
    object_id: ?[]const u8 = null,
    /// Size of blob content (in bytes)
    size: ?i64 = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// This object is returned from Cherry Pick operations and provides the id and status of the operation
pub const GitCherryPick = struct {
    links: ?ReferenceLinks = null,
    detailed_status: ?GitAsyncRefOperationDetail = null,
    parameters: ?GitAsyncRefOperationParameters = null,
    status: ?enums.GitCherryPickStatus = null,
    /// A URL that can be used to make further requests for status about the operation
    url: ?[]const u8 = null,
    cherry_pick_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Information about the progress of a cherry pick or revert operation.
pub const GitAsyncRefOperationDetail = struct {
    /// Indicates if there was a conflict generated when trying to cherry pick or revert the changes.
    conflict: ?bool = null,
    /// The current commit from the list of commits that are being cherry picked or reverted.
    current_commit_id: ?[]const u8 = null,
    /// Detailed information about why the cherry pick or revert failed to complete.
    failure_message: ?[]const u8 = null,
    /// A number between 0 and 1 indicating the percent complete of the operation.
    progress: ?f64 = null,
    /// Provides a status code that indicates the reason the cherry pick or revert failed.
    status: ?enums.GitAsyncRefOperationDetailStatus = null,
    /// Indicates if the operation went beyond the maximum time allowed for a cherry pick or revert operation.
    timedout: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters that are provided in the request body when requesting to cherry pick or revert.
pub const GitAsyncRefOperationParameters = struct {
    /// Proposed target branch name for the cherry pick or revert operation.
    generated_ref_name: ?[]const u8 = null,
    /// The target branch for the cherry pick or revert operation.
    onto_ref_name: ?[]const u8 = null,
    repository: ?GitRepository = null,
    source: ?GitAsyncRefOperationSource = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// GitAsyncRefOperationSource specifies the pull request or list of commits to use when making a cherry pick and revert operation request. Only one should be provided.
pub const GitAsyncRefOperationSource = struct {
    /// A list of commits to cherry pick or revert
    commit_list: ?[]const GitCommitRef = null,
    /// Id of the pull request to cherry pick or revert
    pull_request_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitCommit = struct {
    links: ?ReferenceLinks = null,
    author: ?GitUserDate = null,
    change_counts: ?ChangeCountDictionary = null,
    /// An enumeration of the changes included with the commit.
    changes: ?[]const GitChange = null,
    /// Comment or message of the commit.
    comment: ?[]const u8 = null,
    /// Indicates if the comment is truncated from the full Git commit comment message.
    comment_truncated: ?bool = null,
    /// ID (SHA-1) of the commit.
    commit_id: ?[]const u8 = null,
    committer: ?GitUserDate = null,
    /// Indicates that commit contains too many changes to be displayed
    commit_too_many_changes: ?bool = null,
    /// An enumeration of the parent commit IDs for this commit.
    parents: ?[]const []const u8 = null,
    push: ?GitPushRef = null,
    /// Remote URL path to the commit.
    remote_url: ?[]const u8 = null,
    /// A list of status metadata from services and extensions that may associate additional information to the commit.
    statuses: ?[]const GitStatus = null,
    /// REST URL for this resource.
    url: ?[]const u8 = null,
    /// A list of workitems associated with this commit.
    work_items: ?[]const ResourceRef = null,
    tree_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const GitCommitChanges = struct {
    change_counts: ?ChangeCountDictionary = null,
    changes: ?[]const GitChange = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitQueryCommitsCriteria = struct {
    /// Number of entries to skip
    @"$skip": ?i32 = null,
    /// Maximum number of entries to retrieve
    @"$top": ?i32 = null,
    /// Alias or display name of the author
    author: ?[]const u8 = null,
    compare_version: ?GitVersionDescriptor = null,
    /// Only applies when an itemPath is specified. This determines whether to exclude delete entries of the specified path.
    exclude_deletes: ?bool = null,
    /// If provided, a lower bound for filtering commits alphabetically
    from_commit_id: ?[]const u8 = null,
    /// If provided, only include history entries created after this date (string)
    from_date: ?[]const u8 = null,
    /// What Git history mode should be used. This only applies to the search criteria when Ids = null and an itemPath is specified.
    history_mode: ?enums.GitQueryCommitsCriteriaHistoryMode = null,
    /// If provided, specifies the exact commit ids of the commits to fetch. May not be combined with other parameters.
    ids: ?[]const []const u8 = null,
    /// Whether to include the _links field on the shallow references
    include_links: ?bool = null,
    /// Whether to include the push information
    include_push_data: ?bool = null,
    /// Whether to include the image Url for committers and authors
    include_user_image_url: ?bool = null,
    /// Whether to include linked work items
    include_work_items: ?bool = null,
    /// Path of item to search under
    item_path: ?[]const u8 = null,
    item_version: ?GitVersionDescriptor = null,
    /// If enabled, this option will ignore the itemVersion and compareVersion parameters
    show_oldest_commits_first: ?bool = null,
    /// If provided, an upper bound for filtering commits alphabetically
    to_commit_id: ?[]const u8 = null,
    /// If provided, only include history entries created before this date (string)
    to_date: ?[]const u8 = null,
    /// Alias or display name of the committer
    user: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitVersionDescriptor = struct {
    /// Version string identifier (name of tag/branch, SHA1 of commit)
    version: ?[]const u8 = null,
    /// Version options - Specify additional modifiers to version (e.g Previous)
    version_options: ?enums.GitVersionDescriptorVersionOptions = null,
    /// Version type (branch, tag, or commit). Determines how Id is interpreted
    version_type: ?enums.GitVersionDescriptorVersionType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitCommitDiffs = struct {
    ahead_count: ?i32 = null,
    all_changes_included: ?bool = null,
    base_commit: ?[]const u8 = null,
    behind_count: ?i32 = null,
    change_counts: ?std.json.ArrayHashMap(i32) = null,
    changes: ?[]const GitChange = null,
    common_commit: ?[]const u8 = null,
    target_commit: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A request to import data from a remote source control system.
pub const GitImportRequest = struct {
    links: ?ReferenceLinks = null,
    detailed_status: ?GitImportStatusDetail = null,
    /// The unique identifier for this import request.
    import_request_id: ?i32 = null,
    parameters: ?GitImportRequestParameters = null,
    repository: ?GitRepository = null,
    /// Current status of the import.
    status: ?enums.GitImportRequestStatus = null,
    /// A link back to this import request resource.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Additional status information about an import request.
pub const GitImportStatusDetail = struct {
    /// All valid steps for the import process
    all_steps: ?[]const []const u8 = null,
    /// Index into AllSteps for the current step
    current_step: ?i32 = null,
    /// Error message if the operation failed.
    error_message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters for creating an import request
pub const GitImportRequestParameters = struct {
    /// Option to delete service endpoint when import is done
    delete_service_endpoint_after_import_is_done: ?bool = null,
    git_source: ?GitImportGitSource = null,
    /// Service Endpoint for connection to external endpoint
    service_endpoint_id: ?[]const u8 = null,
    tfvc_source: ?GitImportTfvcSource = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameter for creating a git import request when source is Git version control
pub const GitImportGitSource = struct {
    /// Tells if this is a sync request or not
    overwrite: ?bool = null,
    /// Url for the source repo
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameter for creating a git import request when source is tfvc version control
pub const GitImportTfvcSource = struct {
    /// Set true to import History, false otherwise
    import_history: ?bool = null,
    /// Get history for last n days (max allowed value is 180 days)
    import_history_duration_in_days: ?i32 = null,
    /// Path which we want to import (this can be copied from Path Control in Explorer)
    path: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitItem = struct {
    links: ?ReferenceLinks = null,
    content: ?[]const u8 = null,
    content_metadata: ?FileContentMetadata = null,
    is_folder: ?bool = null,
    is_sym_link: ?bool = null,
    path: ?[]const u8 = null,
    url: ?[]const u8 = null,
    /// SHA1 of commit item was fetched at
    commit_id: ?[]const u8 = null,
    /// Type of object (Commit, Tree, Blob, Tag, ...)
    git_object_type: ?enums.GitItemGitObjectType = null,
    latest_processed_change: ?GitCommitRef = null,
    /// Git object id
    object_id: ?[]const u8 = null,
    /// Git object id
    original_object_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const FileContentMetadata = struct {
    content_type: ?[]const u8 = null,
    encoding: ?i32 = null,
    extension: ?[]const u8 = null,
    file_name: ?[]const u8 = null,
    is_binary: ?bool = null,
    is_image: ?bool = null,
    vs_link: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitItemRequestData = struct {
    /// Whether to include metadata for all items
    include_content_metadata: ?bool = null,
    /// Whether to include the _links field on the shallow references
    include_links: ?bool = null,
    /// Collection of items to fetch, including path, version, and recursion level
    item_descriptors: ?[]const GitItemDescriptor = null,
    /// Whether to include shallow ref to commit that last changed each item
    latest_processed_change: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitItemDescriptor = struct {
    /// Path to item
    path: ?[]const u8 = null,
    /// Specifies whether to include children (OneLevel), all descendants (Full), or None
    recursion_level: ?enums.GitItemDescriptorRecursionLevel = null,
    /// Version string (interpretation based on VersionType defined in subclass
    version: ?[]const u8 = null,
    /// Version modifiers (e.g. previous)
    version_options: ?enums.GitItemDescriptorVersionOptions = null,
    /// How to interpret version (branch,tag,commit)
    version_type: ?enums.GitItemDescriptorVersionType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A set of pull request queries and their results.
pub const GitPullRequestQuery = struct {
    /// The queries to perform.
    queries: ?[]const GitPullRequestQueryInput = null,
    /// The results of the queries. This matches the QueryInputs list so Results[n] are the results of QueryInputs[n]. Each entry in the list is a dictionary of commit->pull requests.
    results: ?[]const std.json.ArrayHashMap([]const GitPullRequest) = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Pull request query input parameters.
pub const GitPullRequestQueryInput = struct {
    /// Options for including additional PR properties in the response.
    include: ?enums.GitPullRequestQueryInputInclude = null,
    /// The list of commit IDs to search for.
    items: ?[]const []const u8 = null,
    /// The type of query to perform.
    type: ?enums.GitPullRequestQueryInputType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Meta data for a file attached to an artifact.
pub const Attachment = struct {
    links: ?ReferenceLinks = null,
    author: ?IdentityRef = null,
    /// Content hash of on-disk representation of file content. Its calculated by the server by using SHA1 hash function.
    content_hash: ?[]const u8 = null,
    /// The time the attachment was uploaded.
    created_date: ?[]const u8 = null,
    /// The description of the attachment.
    description: ?[]const u8 = null,
    /// The display name of the attachment. Can't be null or empty.
    display_name: ?[]const u8 = null,
    /// Id of the attachment.
    id: ?i32 = null,
    properties: ?PropertiesCollection = null,
    /// The url to download the content of the attachment.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The class represents a property bag as a collection of key-value pairs. Values of all primitive types (any type with a `TypeCode != TypeCode.Object`) except for `DBNull` are accepted. Values of type Byte[], Int32, Double, DateType and String preserve their type, other primitives are retuned as a String. Byte[] expected as base64 encoded string.
pub const PropertiesCollection = struct {
    /// The count of properties in the collection.
    count: ?i32 = null,
    item: ?PropertiesCollectionItem = null,
    /// The set of keys in the collection.
    keys: ?[]const []const u8 = null,
    /// The set of values in the collection.
    values: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const PropertiesCollectionItem = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Provides properties that describe a Git pull request iteration. Iterations are created as a result of creating and pushing updates to a pull request.
pub const GitPullRequestIteration = struct {
    links: ?ReferenceLinks = null,
    author: ?IdentityRef = null,
    /// Changes included with the pull request iteration.
    change_list: ?[]const GitPullRequestChange = null,
    /// The commits included with the pull request iteration.
    commits: ?[]const GitCommitRef = null,
    common_ref_commit: ?GitCommitRef = null,
    /// The creation date of the pull request iteration.
    created_date: ?[]const u8 = null,
    /// Description of the pull request iteration.
    description: ?[]const u8 = null,
    /// Indicates if the Commits property contains a truncated list of commits in this pull request iteration.
    has_more_commits: ?bool = null,
    /// ID of the pull request iteration. Iterations are created as a result of creating and pushing updates to a pull request.
    id: ?i32 = null,
    /// If the iteration reason is Retarget, this is the refName of the new target
    new_target_ref_name: ?[]const u8 = null,
    /// If the iteration reason is Retarget, this is the original target refName
    old_target_ref_name: ?[]const u8 = null,
    push: ?GitPushRef = null,
    /// The reason for which the pull request iteration was created.
    reason: ?enums.GitPullRequestIterationReason = null,
    source_ref_commit: ?GitCommitRef = null,
    target_ref_commit: ?GitCommitRef = null,
    /// The updated date of the pull request iteration.
    updated_date: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Change made in a pull request.
pub const GitPullRequestChange = struct {
    /// The type of change that was made to the item.
    change_type: ?enums.GitChangeChangeType = null,
    /// Current version.
    item: ?[]const u8 = null,
    new_content: ?ItemContent = null,
    /// Path of the item on the server.
    source_server_item: ?[]const u8 = null,
    /// URL to retrieve the item.
    url: ?[]const u8 = null,
    /// ID of the change within the group of changes.
    change_id: ?i32 = null,
    new_content_template: ?GitTemplate = null,
    /// Original path of item if different from current path.
    original_path: ?[]const u8 = null,
    /// ID used to track files through multiple changes.
    change_tracking_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Collection of changes made in a pull request.
pub const GitPullRequestIterationChanges = struct {
    /// Changes made in the iteration.
    change_entries: ?[]const GitPullRequestChange = null,
    /// Value to specify as skip to get the next page of changes. This will be zero if there are no more changes.
    next_skip: ?i32 = null,
    /// Value to specify as top to get the next page of changes. This will be zero if there are no more changes.
    next_top: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// This class contains the metadata of a service/extension posting pull request status. Status can be associated with a pull request or an iteration.
pub const GitPullRequestStatus = struct {
    links: ?ReferenceLinks = null,
    context: ?GitStatusContext = null,
    created_by: ?IdentityRef = null,
    /// Creation date and time of the status.
    creation_date: ?[]const u8 = null,
    /// Status description. Typically describes current state of the status.
    description: ?[]const u8 = null,
    /// Status identifier.
    id: ?i32 = null,
    /// State of the status.
    state: ?enums.GitStatusState = null,
    /// URL with status details.
    target_url: ?[]const u8 = null,
    /// Last update date and time of the status.
    updated_date: ?[]const u8 = null,
    /// ID of the iteration to associate status with. Minimum value is 1.
    iteration_id: ?i32 = null,
    properties: ?PropertiesCollection = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// The JSON model for JSON Patch Operations
pub const JsonPatchDocument = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// The representation of data needed to create a tag definition which is sent across the wire.
pub const WebApiCreateTagRequestData = struct {
    /// Name of the tag definition that will be created.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Context used while sharing a pull request.
pub const ShareNotificationContext = struct {
    /// Optional user note or message.
    message: ?[]const u8 = null,
    /// Identities of users who will receive a share notification.
    receivers: ?[]const IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents a comment thread of a pull request. A thread contains meta data about the file it was left on (if any) along with one or more comments (an initial comment and the subsequent replies).
pub const GitPullRequestCommentThread = struct {
    links: ?ReferenceLinks = null,
    /// A list of the comments.
    comments: ?[]const Comment = null,
    /// The comment thread id.
    id: ?i32 = null,
    /// Set of identities related to this thread
    identities: ?std.json.ArrayHashMap(IdentityRef) = null,
    /// Specify if the thread is deleted which happens when all comments are deleted.
    is_deleted: ?bool = null,
    /// The time this thread was last updated.
    last_updated_date: ?[]const u8 = null,
    properties: ?PropertiesCollection = null,
    /// The time this thread was published.
    published_date: ?[]const u8 = null,
    /// The status of the comment thread.
    status: ?enums.GitPullRequestCommentThreadStatus = null,
    thread_context: ?CommentThreadContext = null,
    pull_request_thread_context: ?GitPullRequestCommentThreadContext = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Represents a comment which is one of potentially many in a comment thread.
pub const Comment = struct {
    links: ?ReferenceLinks = null,
    author: ?IdentityRef = null,
    /// The comment type at the time of creation.
    comment_type: ?enums.CommentCommentType = null,
    /// The comment content.
    content: ?[]const u8 = null,
    /// The comment ID. IDs start at 1 and are unique to a pull request.
    id: ?i16 = null,
    /// Whether or not this comment was soft-deleted.
    is_deleted: ?bool = null,
    /// The date the comment's content was last updated.
    last_content_updated_date: ?[]const u8 = null,
    /// The date the comment was last updated.
    last_updated_date: ?[]const u8 = null,
    /// The ID of the parent comment. This is used for replies.
    parent_comment_id: ?i16 = null,
    /// The date the comment was first published.
    published_date: ?[]const u8 = null,
    /// A list of the users who have liked this comment.
    users_liked: ?[]const IdentityRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const CommentThreadContext = struct {
    /// File path relative to the root of the repository. It's up to the client to use any path format.
    file_path: ?[]const u8 = null,
    left_file_end: ?CommentPosition = null,
    left_file_start: ?CommentPosition = null,
    right_file_end: ?CommentPosition = null,
    right_file_start: ?CommentPosition = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const CommentPosition = struct {
    /// The line number of a thread's position. Starts at 1.
    line: ?i32 = null,
    /// The character offset of a thread's position inside of a line. Starts at 1.
    offset: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Comment thread context contains details about what diffs were being viewed at the time of thread creation and whether or not the thread has been tracked from that original diff.
pub const GitPullRequestCommentThreadContext = struct {
    /// Used to track a comment across iterations. This value can be found by looking at the iteration's changes list. Must be set for pull requests with iteration support. Otherwise, it's not required for 'legacy' pull requests.
    change_tracking_id: ?i32 = null,
    iteration_context: ?CommentIterationContext = null,
    tracking_criteria: ?CommentTrackingCriteria = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Comment iteration context is used to identify which diff was being viewed when the thread was created.
pub const CommentIterationContext = struct {
    /// The iteration of the file on the left side of the diff when the thread was created. If this value is equal to SecondComparingIteration, then this version is the common commit between the source and target branches of the pull request.
    first_comparing_iteration: ?i16 = null,
    /// The iteration of the file on the right side of the diff when the thread was created.
    second_comparing_iteration: ?i16 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Comment tracking criteria is used to identify which iteration context the thread has been tracked to (if any) along with some detail about the original position and filename.
pub const CommentTrackingCriteria = struct {
    /// The iteration of the file on the left side of the diff that the thread will be tracked to. Threads were tracked if this is greater than 0.
    first_comparing_iteration: ?i32 = null,
    /// Original filepath the thread was created on before tracking. This will be different than the current thread filepath if the file in question was renamed in a later iteration.
    orig_file_path: ?[]const u8 = null,
    orig_left_file_end: ?CommentPosition = null,
    orig_left_file_start: ?CommentPosition = null,
    orig_right_file_end: ?CommentPosition = null,
    orig_right_file_start: ?CommentPosition = null,
    /// The iteration of the file on the right side of the diff that the thread will be tracked to. Threads were tracked if this is greater than 0.
    second_comparing_iteration: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitPush = struct {
    links: ?ReferenceLinks = null,
    date: ?[]const u8 = null,
    pushed_by: ?IdentityRef = null,
    push_id: ?i32 = null,
    url: ?[]const u8 = null,
    commits: ?[]const GitCommitRef = null,
    ref_updates: ?[]const GitRefUpdate = null,
    repository: ?GitRepository = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const GitRefUpdate = struct {
    is_locked: ?bool = null,
    name: ?[]const u8 = null,
    new_object_id: ?[]const u8 = null,
    old_object_id: ?[]const u8 = null,
    repository_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitRef = struct {
    links: ?ReferenceLinks = null,
    creator: ?IdentityRef = null,
    is_locked: ?bool = null,
    is_locked_by: ?IdentityRef = null,
    name: ?[]const u8 = null,
    object_id: ?[]const u8 = null,
    peeled_object_id: ?[]const u8 = null,
    statuses: ?[]const GitStatus = null,
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const GitRefUpdateResult = struct {
    /// Custom message for the result object For instance, Reason for failing.
    custom_message: ?[]const u8 = null,
    /// Whether the ref is locked or not
    is_locked: ?bool = null,
    /// Ref name
    name: ?[]const u8 = null,
    /// New object ID
    new_object_id: ?[]const u8 = null,
    /// Old object ID
    old_object_id: ?[]const u8 = null,
    /// Name of the plugin that rejected the updated.
    rejected_by: ?[]const u8 = null,
    /// Repository ID
    repository_id: ?[]const u8 = null,
    /// True if the ref update succeeded, false otherwise
    success: ?bool = null,
    /// Status of the update from the TFS server.
    update_status: ?enums.GitRefUpdateResultUpdateStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitRevert = struct {
    links: ?ReferenceLinks = null,
    detailed_status: ?GitAsyncRefOperationDetail = null,
    parameters: ?GitAsyncRefOperationParameters = null,
    status: ?enums.GitCherryPickStatus = null,
    /// A URL that can be used to make further requests for status about the operation
    url: ?[]const u8 = null,
    revert_id: ?i32 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Ahead and behind counts for a particular ref.
pub const GitBranchStats = struct {
    /// Number of commits ahead.
    ahead_count: ?i32 = null,
    /// Number of commits behind.
    behind_count: ?i32 = null,
    commit: ?GitCommitRef = null,
    /// True if this is the result for the base version.
    is_base_version: ?bool = null,
    /// Name of the ref.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// An object describing the git suggestion. Git suggestions are currently limited to suggested pull requests.
pub const GitSuggestion = struct {
    /// Specific properties describing the suggestion.
    properties: ?std.json.ArrayHashMap(GitSuggestionProperty) = null,
    /// The type of suggestion (e.g. pull request).
    type: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitSuggestionProperty = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitTreeRef = struct {
    links: ?ReferenceLinks = null,
    /// SHA1 hash of git object
    object_id: ?[]const u8 = null,
    /// Sum of sizes of all children
    size: ?i64 = null,
    /// Blobs and trees under this tree
    tree_entries: ?[]const GitTreeEntryRef = null,
    /// Url to tree
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

pub const GitTreeEntryRef = struct {
    /// Blob or tree
    git_object_type: ?enums.GitTreeEntryRefGitObjectType = null,
    /// Mode represented as octal string
    mode: ?[]const u8 = null,
    /// SHA1 hash of git object
    object_id: ?[]const u8 = null,
    /// Path relative to parent tree object
    relative_path: ?[]const u8 = null,
    /// Size of content
    size: ?i64 = null,
    /// url to retrieve tree or blob
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Request to sync data between two forks.
pub const GitForkSyncRequest = struct {
    links: ?ReferenceLinks = null,
    detailed_status: ?GitForkOperationStatusDetail = null,
    /// Unique identifier for the operation.
    operation_id: ?i32 = null,
    source: ?GlobalGitRepositoryKey = null,
    /// If supplied, the set of ref mappings to use when performing a 'sync' or create. If missing, all refs will be synchronized.
    source_to_target_refs: ?[]const SourceToTargetRef = null,
    status: ?enums.GitForkSyncRequestStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Status information about a requested fork operation.
pub const GitForkOperationStatusDetail = struct {
    /// All valid steps for the forking process
    all_steps: ?[]const []const u8 = null,
    /// Index into AllSteps for the current step
    current_step: ?i32 = null,
    /// Error message if the operation failed.
    error_message: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Globally unique key for a repository.
pub const GlobalGitRepositoryKey = struct {
    /// Team Project Collection ID of the collection for the repository.
    collection_id: ?[]const u8 = null,
    /// Team Project ID of the project for the repository.
    project_id: ?[]const u8 = null,
    /// ID of the repository.
    repository_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const SourceToTargetRef = struct {
    /// The source ref to copy. For example, refs/heads/master.
    source_ref: ?[]const u8 = null,
    /// The target ref to update. For example, refs/heads/master.
    target_ref: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters for creating a fork request
pub const GitForkSyncRequestParameters = struct {
    source: ?GlobalGitRepositoryKey = null,
    /// If supplied, the set of ref mappings to use when performing a 'sync' or create. If missing, all refs will be synchronized.
    source_to_target_refs: ?[]const SourceToTargetRef = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Parameters required for performing git merge.
pub const GitMergeParameters = struct {
    /// Comment or message of the commit.
    comment: ?[]const u8 = null,
    /// An enumeration of the parent commit IDs for the merge commit.
    parents: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const GitMerge = struct {
    /// Comment or message of the commit.
    comment: ?[]const u8 = null,
    /// An enumeration of the parent commit IDs for the merge commit.
    parents: ?[]const []const u8 = null,
    links: ?ReferenceLinks = null,
    detailed_status: ?GitMergeOperationStatusDetail = null,
    /// Unique identifier for the merge operation.
    merge_operation_id: ?i32 = null,
    /// Status of the merge operation.
    status: ?enums.GitMergeStatus = null,

    pub const serde = .{
        .rename_all = .camel_case,
        .rename = .{
            .links = "_links",
        },
    };
};

/// Status information about a requested merge operation.
pub const GitMergeOperationStatusDetail = struct {
    /// Error message if the operation failed.
    failure_message: ?[]const u8 = null,
    /// The commitId of the resultant merge commit.
    merge_commit_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
