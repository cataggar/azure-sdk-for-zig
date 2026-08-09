//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const TeamProjectReferenceState = enum {
    deleting,
    new,
    well_formed,
    create_pending,
    all,
    unchanged,
    deleted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .deleting => "deleting",
            .new => "new",
            .well_formed => "wellFormed",
            .create_pending => "createPending",
            .all => "all",
            .unchanged => "unchanged",
            .deleted => "deleted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "deleting")) return .deleting;
        if (std.mem.eql(u8, s, "new")) return .new;
        if (std.mem.eql(u8, s, "wellFormed")) return .well_formed;
        if (std.mem.eql(u8, s, "createPending")) return .create_pending;
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "unchanged")) return .unchanged;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const TeamProjectReferenceVisibility = enum {
    private,
    public,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .private => "private",
            .public => "public",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "private")) return .private;
        if (std.mem.eql(u8, s, "public")) return .public;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitRefFavoriteType = enum {
    invalid,
    folder,
    ref,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .invalid => "invalid",
            .folder => "folder",
            .ref => "ref",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "invalid")) return .invalid;
        if (std.mem.eql(u8, s, "folder")) return .folder;
        if (std.mem.eql(u8, s, "ref")) return .ref;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetPullRequestsByProjectRequestSearchCriteriaQueryTimeRangeType = enum {
    created,
    closed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .created => "created",
            .closed => "closed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "created")) return .created;
        if (std.mem.eql(u8, s, "closed")) return .closed;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetPullRequestsByProjectRequestSearchCriteriaStatus = enum {
    not_set,
    active,
    abandoned,
    completed,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .active => "active",
            .abandoned => "abandoned",
            .completed => "completed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "all")) return .all;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetPullRequestsByProjectRequestSearchCriteriaTagsFilterOperator = enum {
    @"and",
    @"or",

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .@"and" => "and",
            .@"or" => "or",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "and")) return .@"and";
        if (std.mem.eql(u8, s, "or")) return .@"or";
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitChangeChangeType = enum {
    none,
    add,
    edit,
    encoding,
    rename,
    delete,
    undelete,
    branch,
    merge,
    lock,
    rollback,
    source_rename,
    target_rename,
    property,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .add => "add",
            .edit => "edit",
            .encoding => "encoding",
            .rename => "rename",
            .delete => "delete",
            .undelete => "undelete",
            .branch => "branch",
            .merge => "merge",
            .lock => "lock",
            .rollback => "rollback",
            .source_rename => "sourceRename",
            .target_rename => "targetRename",
            .property => "property",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "add")) return .add;
        if (std.mem.eql(u8, s, "edit")) return .edit;
        if (std.mem.eql(u8, s, "encoding")) return .encoding;
        if (std.mem.eql(u8, s, "rename")) return .rename;
        if (std.mem.eql(u8, s, "delete")) return .delete;
        if (std.mem.eql(u8, s, "undelete")) return .undelete;
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "merge")) return .merge;
        if (std.mem.eql(u8, s, "lock")) return .lock;
        if (std.mem.eql(u8, s, "rollback")) return .rollback;
        if (std.mem.eql(u8, s, "sourceRename")) return .source_rename;
        if (std.mem.eql(u8, s, "targetRename")) return .target_rename;
        if (std.mem.eql(u8, s, "property")) return .property;
        if (std.mem.eql(u8, s, "all")) return .all;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const ItemContentContentType = enum {
    raw_text,
    base64encoded,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .raw_text => "rawText",
            .base64encoded => "base64Encoded",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "rawText")) return .raw_text;
        if (std.mem.eql(u8, s, "base64Encoded")) return .base64encoded;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitStatusState = enum {
    not_set,
    pending,
    succeeded,
    failed,
    @"error",
    not_applicable,
    partially_succeeded,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .pending => "pending",
            .succeeded => "succeeded",
            .failed => "failed",
            .@"error" => "error",
            .not_applicable => "notApplicable",
            .partially_succeeded => "partiallySucceeded",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "error")) return .@"error";
        if (std.mem.eql(u8, s, "notApplicable")) return .not_applicable;
        if (std.mem.eql(u8, s, "partiallySucceeded")) return .partially_succeeded;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitPullRequestCompletionOptionsMergeStrategy = enum {
    no_fast_forward,
    squash,
    rebase,
    rebase_merge,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .no_fast_forward => "noFastForward",
            .squash => "squash",
            .rebase => "rebase",
            .rebase_merge => "rebaseMerge",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "noFastForward")) return .no_fast_forward;
        if (std.mem.eql(u8, s, "squash")) return .squash;
        if (std.mem.eql(u8, s, "rebase")) return .rebase;
        if (std.mem.eql(u8, s, "rebaseMerge")) return .rebase_merge;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitPullRequestMergeFailureType = enum {
    none,
    unknown,
    case_sensitive,
    object_too_large,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .unknown => "unknown",
            .case_sensitive => "caseSensitive",
            .object_too_large => "objectTooLarge",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "caseSensitive")) return .case_sensitive;
        if (std.mem.eql(u8, s, "objectTooLarge")) return .object_too_large;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitPullRequestMergeStatus = enum {
    not_set,
    queued,
    conflicts,
    succeeded,
    rejected_by_policy,
    failure,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .queued => "queued",
            .conflicts => "conflicts",
            .succeeded => "succeeded",
            .rejected_by_policy => "rejectedByPolicy",
            .failure => "failure",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "conflicts")) return .conflicts;
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "rejectedByPolicy")) return .rejected_by_policy;
        if (std.mem.eql(u8, s, "failure")) return .failure;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitPullRequestStatus1 = enum {
    not_set,
    active,
    abandoned,
    completed,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .active => "active",
            .abandoned => "abandoned",
            .completed => "completed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "all")) return .all;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetPullRequestsRequestSearchCriteriaQueryTimeRangeType = enum {
    created,
    closed,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .created => "created",
            .closed => "closed",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "created")) return .created;
        if (std.mem.eql(u8, s, "closed")) return .closed;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetPullRequestsRequestSearchCriteriaStatus = enum {
    not_set,
    active,
    abandoned,
    completed,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .active => "active",
            .abandoned => "abandoned",
            .completed => "completed",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "all")) return .all;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetPullRequestsRequestSearchCriteriaTagsFilterOperator = enum {
    @"and",
    @"or",

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .@"and" => "and",
            .@"or" => "or",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "and")) return .@"and";
        if (std.mem.eql(u8, s, "or")) return .@"or";
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitObjectObjectType = enum {
    bad,
    commit,
    tree,
    blob,
    tag,
    ext2,
    ofs_delta,
    ref_delta,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .bad => "bad",
            .commit => "commit",
            .tree => "tree",
            .blob => "blob",
            .tag => "tag",
            .ext2 => "ext2",
            .ofs_delta => "ofsDelta",
            .ref_delta => "refDelta",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "bad")) return .bad;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        if (std.mem.eql(u8, s, "tree")) return .tree;
        if (std.mem.eql(u8, s, "blob")) return .blob;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "ext2")) return .ext2;
        if (std.mem.eql(u8, s, "ofsDelta")) return .ofs_delta;
        if (std.mem.eql(u8, s, "refDelta")) return .ref_delta;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitAsyncRefOperationDetailStatus = enum {
    none,
    invalid_ref_name,
    ref_name_conflict,
    create_branch_permission_required,
    write_permission_required,
    target_branch_deleted,
    git_object_too_large,
    operation_indentity_not_found,
    async_operation_not_found,
    other,
    empty_committer_signature,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .invalid_ref_name => "invalidRefName",
            .ref_name_conflict => "refNameConflict",
            .create_branch_permission_required => "createBranchPermissionRequired",
            .write_permission_required => "writePermissionRequired",
            .target_branch_deleted => "targetBranchDeleted",
            .git_object_too_large => "gitObjectTooLarge",
            .operation_indentity_not_found => "operationIndentityNotFound",
            .async_operation_not_found => "asyncOperationNotFound",
            .other => "other",
            .empty_committer_signature => "emptyCommitterSignature",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "invalidRefName")) return .invalid_ref_name;
        if (std.mem.eql(u8, s, "refNameConflict")) return .ref_name_conflict;
        if (std.mem.eql(u8, s, "createBranchPermissionRequired")) return .create_branch_permission_required;
        if (std.mem.eql(u8, s, "writePermissionRequired")) return .write_permission_required;
        if (std.mem.eql(u8, s, "targetBranchDeleted")) return .target_branch_deleted;
        if (std.mem.eql(u8, s, "gitObjectTooLarge")) return .git_object_too_large;
        if (std.mem.eql(u8, s, "operationIndentityNotFound")) return .operation_indentity_not_found;
        if (std.mem.eql(u8, s, "asyncOperationNotFound")) return .async_operation_not_found;
        if (std.mem.eql(u8, s, "other")) return .other;
        if (std.mem.eql(u8, s, "emptyCommitterSignature")) return .empty_committer_signature;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitCherryPickStatus = enum {
    queued,
    in_progress,
    completed,
    failed,
    abandoned,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .queued => "queued",
            .in_progress => "inProgress",
            .completed => "completed",
            .failed => "failed",
            .abandoned => "abandoned",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitVersionDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitVersionDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitQueryCommitsCriteriaHistoryMode = enum {
    simplified_history,
    first_parent,
    full_history,
    full_history_simplify_merges,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .simplified_history => "simplifiedHistory",
            .first_parent => "firstParent",
            .full_history => "fullHistory",
            .full_history_simplify_merges => "fullHistorySimplifyMerges",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "simplifiedHistory")) return .simplified_history;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
        if (std.mem.eql(u8, s, "fullHistory")) return .full_history;
        if (std.mem.eql(u8, s, "fullHistorySimplifyMerges")) return .full_history_simplify_merges;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetRequestBaseVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetRequestBaseVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetRequestTargetVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GetRequestTargetVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitImportRequestStatus = enum {
    queued,
    in_progress,
    completed,
    failed,
    abandoned,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .queued => "queued",
            .in_progress => "inProgress",
            .completed => "completed",
            .failed => "failed",
            .abandoned => "abandoned",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const ListRequestRecursionLevel = enum {
    none,
    one_level,
    one_level_plus_nested_empty_folders,
    full,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .one_level => "oneLevel",
            .one_level_plus_nested_empty_folders => "oneLevelPlusNestedEmptyFolders",
            .full => "full",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "oneLevel")) return .one_level;
        if (std.mem.eql(u8, s, "oneLevelPlusNestedEmptyFolders")) return .one_level_plus_nested_empty_folders;
        if (std.mem.eql(u8, s, "full")) return .full;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const ListRequestVersionDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const ListRequestVersionDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitItemGitObjectType = enum {
    bad,
    commit,
    tree,
    blob,
    tag,
    ext2,
    ofs_delta,
    ref_delta,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .bad => "bad",
            .commit => "commit",
            .tree => "tree",
            .blob => "blob",
            .tag => "tag",
            .ext2 => "ext2",
            .ofs_delta => "ofsDelta",
            .ref_delta => "refDelta",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "bad")) return .bad;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        if (std.mem.eql(u8, s, "tree")) return .tree;
        if (std.mem.eql(u8, s, "blob")) return .blob;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "ext2")) return .ext2;
        if (std.mem.eql(u8, s, "ofsDelta")) return .ofs_delta;
        if (std.mem.eql(u8, s, "refDelta")) return .ref_delta;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitItemDescriptorRecursionLevel = enum {
    none,
    one_level,
    one_level_plus_nested_empty_folders,
    full,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .one_level => "oneLevel",
            .one_level_plus_nested_empty_folders => "oneLevelPlusNestedEmptyFolders",
            .full => "full",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "oneLevel")) return .one_level;
        if (std.mem.eql(u8, s, "oneLevelPlusNestedEmptyFolders")) return .one_level_plus_nested_empty_folders;
        if (std.mem.eql(u8, s, "full")) return .full;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitItemDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitItemDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitPullRequestQueryInputInclude = enum {
    not_set,
    labels,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .labels => "labels",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "labels")) return .labels;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitPullRequestQueryInputType = enum {
    not_set,
    last_merge_commit,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .not_set => "notSet",
            .last_merge_commit => "lastMergeCommit",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "notSet")) return .not_set;
        if (std.mem.eql(u8, s, "lastMergeCommit")) return .last_merge_commit;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitPullRequestIterationReason = enum {
    push,
    force_push,
    create,
    rebase,
    unknown,
    retarget,
    resolve_conflicts,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .push => "push",
            .force_push => "forcePush",
            .create => "create",
            .rebase => "rebase",
            .unknown => "unknown",
            .retarget => "retarget",
            .resolve_conflicts => "resolveConflicts",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "push")) return .push;
        if (std.mem.eql(u8, s, "forcePush")) return .force_push;
        if (std.mem.eql(u8, s, "create")) return .create;
        if (std.mem.eql(u8, s, "rebase")) return .rebase;
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "retarget")) return .retarget;
        if (std.mem.eql(u8, s, "resolveConflicts")) return .resolve_conflicts;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const CommentCommentType = enum {
    unknown,
    text,
    code_change,
    system,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .text => "text",
            .code_change => "codeChange",
            .system => "system",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "text")) return .text;
        if (std.mem.eql(u8, s, "codeChange")) return .code_change;
        if (std.mem.eql(u8, s, "system")) return .system;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitPullRequestCommentThreadStatus = enum {
    unknown,
    active,
    fixed,
    wont_fix,
    closed,
    by_design,
    pending,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .unknown => "unknown",
            .active => "active",
            .fixed => "fixed",
            .wont_fix => "wontFix",
            .closed => "closed",
            .by_design => "byDesign",
            .pending => "pending",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "unknown")) return .unknown;
        if (std.mem.eql(u8, s, "active")) return .active;
        if (std.mem.eql(u8, s, "fixed")) return .fixed;
        if (std.mem.eql(u8, s, "wontFix")) return .wont_fix;
        if (std.mem.eql(u8, s, "closed")) return .closed;
        if (std.mem.eql(u8, s, "byDesign")) return .by_design;
        if (std.mem.eql(u8, s, "pending")) return .pending;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitRefUpdateResultUpdateStatus = enum {
    succeeded,
    force_push_required,
    stale_old_object_id,
    invalid_ref_name,
    unprocessed,
    unresolvable_to_commit,
    write_permission_required,
    manage_note_permission_required,
    create_branch_permission_required,
    create_tag_permission_required,
    rejected_by_plugin,
    locked,
    ref_name_conflict,
    rejected_by_policy,
    succeeded_non_existent_ref,
    succeeded_corrupt_ref,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .succeeded => "succeeded",
            .force_push_required => "forcePushRequired",
            .stale_old_object_id => "staleOldObjectId",
            .invalid_ref_name => "invalidRefName",
            .unprocessed => "unprocessed",
            .unresolvable_to_commit => "unresolvableToCommit",
            .write_permission_required => "writePermissionRequired",
            .manage_note_permission_required => "manageNotePermissionRequired",
            .create_branch_permission_required => "createBranchPermissionRequired",
            .create_tag_permission_required => "createTagPermissionRequired",
            .rejected_by_plugin => "rejectedByPlugin",
            .locked => "locked",
            .ref_name_conflict => "refNameConflict",
            .rejected_by_policy => "rejectedByPolicy",
            .succeeded_non_existent_ref => "succeededNonExistentRef",
            .succeeded_corrupt_ref => "succeededCorruptRef",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "succeeded")) return .succeeded;
        if (std.mem.eql(u8, s, "forcePushRequired")) return .force_push_required;
        if (std.mem.eql(u8, s, "staleOldObjectId")) return .stale_old_object_id;
        if (std.mem.eql(u8, s, "invalidRefName")) return .invalid_ref_name;
        if (std.mem.eql(u8, s, "unprocessed")) return .unprocessed;
        if (std.mem.eql(u8, s, "unresolvableToCommit")) return .unresolvable_to_commit;
        if (std.mem.eql(u8, s, "writePermissionRequired")) return .write_permission_required;
        if (std.mem.eql(u8, s, "manageNotePermissionRequired")) return .manage_note_permission_required;
        if (std.mem.eql(u8, s, "createBranchPermissionRequired")) return .create_branch_permission_required;
        if (std.mem.eql(u8, s, "createTagPermissionRequired")) return .create_tag_permission_required;
        if (std.mem.eql(u8, s, "rejectedByPlugin")) return .rejected_by_plugin;
        if (std.mem.eql(u8, s, "locked")) return .locked;
        if (std.mem.eql(u8, s, "refNameConflict")) return .ref_name_conflict;
        if (std.mem.eql(u8, s, "rejectedByPolicy")) return .rejected_by_policy;
        if (std.mem.eql(u8, s, "succeededNonExistentRef")) return .succeeded_non_existent_ref;
        if (std.mem.eql(u8, s, "succeededCorruptRef")) return .succeeded_corrupt_ref;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const ListRequestBaseVersionDescriptorVersionOptions = enum {
    none,
    previous_change,
    first_parent,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .previous_change => "previousChange",
            .first_parent => "firstParent",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "previousChange")) return .previous_change;
        if (std.mem.eql(u8, s, "firstParent")) return .first_parent;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const ListRequestBaseVersionDescriptorVersionType = enum {
    branch,
    tag,
    commit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .branch => "branch",
            .tag => "tag",
            .commit => "commit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "branch")) return .branch;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitTreeEntryRefGitObjectType = enum {
    bad,
    commit,
    tree,
    blob,
    tag,
    ext2,
    ofs_delta,
    ref_delta,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .bad => "bad",
            .commit => "commit",
            .tree => "tree",
            .blob => "blob",
            .tag => "tag",
            .ext2 => "ext2",
            .ofs_delta => "ofsDelta",
            .ref_delta => "refDelta",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "bad")) return .bad;
        if (std.mem.eql(u8, s, "commit")) return .commit;
        if (std.mem.eql(u8, s, "tree")) return .tree;
        if (std.mem.eql(u8, s, "blob")) return .blob;
        if (std.mem.eql(u8, s, "tag")) return .tag;
        if (std.mem.eql(u8, s, "ext2")) return .ext2;
        if (std.mem.eql(u8, s, "ofsDelta")) return .ofs_delta;
        if (std.mem.eql(u8, s, "refDelta")) return .ref_delta;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitForkSyncRequestStatus = enum {
    queued,
    in_progress,
    completed,
    failed,
    abandoned,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .queued => "queued",
            .in_progress => "inProgress",
            .completed => "completed",
            .failed => "failed",
            .abandoned => "abandoned",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const GitMergeStatus = enum {
    queued,
    in_progress,
    completed,
    failed,
    abandoned,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .queued => "queued",
            .in_progress => "inProgress",
            .completed => "completed",
            .failed => "failed",
            .abandoned => "abandoned",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "queued")) return .queued;
        if (std.mem.eql(u8, s, "inProgress")) return .in_progress;
        if (std.mem.eql(u8, s, "completed")) return .completed;
        if (std.mem.eql(u8, s, "failed")) return .failed;
        if (std.mem.eql(u8, s, "abandoned")) return .abandoned;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};

pub const ServiceApiVersions = enum {
    v7_2_preview,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .v7_2_preview => "7.2-preview",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "7.2-preview")) return .v7_2_preview;
        return null;
    }

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.fixed_enum.deserialize(T, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.fixed_enum.serialize(self, serializer);
    }
};
