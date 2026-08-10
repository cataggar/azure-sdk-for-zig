//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const TeamProjectReferenceState = union(enum) {
    deleting,
    new,
    well_formed,
    create_pending,
    all,
    unchanged,
    deleted,
    unrecognized: []const u8,

    const wire_names = .{
        .deleting = "deleting",
        .new = "new",
        .well_formed = "wellFormed",
        .create_pending = "createPending",
        .all = "all",
        .unchanged = "unchanged",
        .deleted = "deleted",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const TeamProjectReferenceVisibility = union(enum) {
    private,
    public,
    unrecognized: []const u8,

    const wire_names = .{
        .private = "private",
        .public = "public",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitRefFavoriteType = union(enum) {
    invalid,
    folder,
    ref,
    unrecognized: []const u8,

    const wire_names = .{
        .invalid = "invalid",
        .folder = "folder",
        .ref = "ref",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
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

pub const GitChangeChangeType = union(enum) {
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
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .add = "add",
        .edit = "edit",
        .encoding = "encoding",
        .rename = "rename",
        .delete = "delete",
        .undelete = "undelete",
        .branch = "branch",
        .merge = "merge",
        .lock = "lock",
        .rollback = "rollback",
        .source_rename = "sourceRename",
        .target_rename = "targetRename",
        .property = "property",
        .all = "all",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const ItemContentContentType = union(enum) {
    raw_text,
    base64encoded,
    unrecognized: []const u8,

    const wire_names = .{
        .raw_text = "rawText",
        .base64encoded = "base64Encoded",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitStatusState = union(enum) {
    not_set,
    pending,
    succeeded,
    failed,
    @"error",
    not_applicable,
    partially_succeeded,
    unrecognized: []const u8,

    const wire_names = .{
        .not_set = "notSet",
        .pending = "pending",
        .succeeded = "succeeded",
        .failed = "failed",
        .@"error" = "error",
        .not_applicable = "notApplicable",
        .partially_succeeded = "partiallySucceeded",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitPullRequestCompletionOptionsMergeStrategy = union(enum) {
    no_fast_forward,
    squash,
    rebase,
    rebase_merge,
    unrecognized: []const u8,

    const wire_names = .{
        .no_fast_forward = "noFastForward",
        .squash = "squash",
        .rebase = "rebase",
        .rebase_merge = "rebaseMerge",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitPullRequestMergeFailureType = union(enum) {
    none,
    unknown,
    case_sensitive,
    object_too_large,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .unknown = "unknown",
        .case_sensitive = "caseSensitive",
        .object_too_large = "objectTooLarge",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitPullRequestMergeStatus = union(enum) {
    not_set,
    queued,
    conflicts,
    succeeded,
    rejected_by_policy,
    failure,
    unrecognized: []const u8,

    const wire_names = .{
        .not_set = "notSet",
        .queued = "queued",
        .conflicts = "conflicts",
        .succeeded = "succeeded",
        .rejected_by_policy = "rejectedByPolicy",
        .failure = "failure",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitPullRequestStatus1 = union(enum) {
    not_set,
    active,
    abandoned,
    completed,
    all,
    unrecognized: []const u8,

    const wire_names = .{
        .not_set = "notSet",
        .active = "active",
        .abandoned = "abandoned",
        .completed = "completed",
        .all = "all",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
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

pub const GitObjectObjectType = union(enum) {
    bad,
    commit,
    tree,
    blob,
    tag,
    ext2,
    ofs_delta,
    ref_delta,
    unrecognized: []const u8,

    const wire_names = .{
        .bad = "bad",
        .commit = "commit",
        .tree = "tree",
        .blob = "blob",
        .tag = "tag",
        .ext2 = "ext2",
        .ofs_delta = "ofsDelta",
        .ref_delta = "refDelta",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitAsyncRefOperationDetailStatus = union(enum) {
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
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .invalid_ref_name = "invalidRefName",
        .ref_name_conflict = "refNameConflict",
        .create_branch_permission_required = "createBranchPermissionRequired",
        .write_permission_required = "writePermissionRequired",
        .target_branch_deleted = "targetBranchDeleted",
        .git_object_too_large = "gitObjectTooLarge",
        .operation_indentity_not_found = "operationIndentityNotFound",
        .async_operation_not_found = "asyncOperationNotFound",
        .other = "other",
        .empty_committer_signature = "emptyCommitterSignature",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitCherryPickStatus = union(enum) {
    queued,
    in_progress,
    completed,
    failed,
    abandoned,
    unrecognized: []const u8,

    const wire_names = .{
        .queued = "queued",
        .in_progress = "inProgress",
        .completed = "completed",
        .failed = "failed",
        .abandoned = "abandoned",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitVersionDescriptorVersionOptions = union(enum) {
    none,
    previous_change,
    first_parent,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .previous_change = "previousChange",
        .first_parent = "firstParent",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitVersionDescriptorVersionType = union(enum) {
    branch,
    tag,
    commit,
    unrecognized: []const u8,

    const wire_names = .{
        .branch = "branch",
        .tag = "tag",
        .commit = "commit",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitQueryCommitsCriteriaHistoryMode = union(enum) {
    simplified_history,
    first_parent,
    full_history,
    full_history_simplify_merges,
    unrecognized: []const u8,

    const wire_names = .{
        .simplified_history = "simplifiedHistory",
        .first_parent = "firstParent",
        .full_history = "fullHistory",
        .full_history_simplify_merges = "fullHistorySimplifyMerges",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
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

pub const GitImportRequestStatus = union(enum) {
    queued,
    in_progress,
    completed,
    failed,
    abandoned,
    unrecognized: []const u8,

    const wire_names = .{
        .queued = "queued",
        .in_progress = "inProgress",
        .completed = "completed",
        .failed = "failed",
        .abandoned = "abandoned",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
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

pub const GitItemGitObjectType = union(enum) {
    bad,
    commit,
    tree,
    blob,
    tag,
    ext2,
    ofs_delta,
    ref_delta,
    unrecognized: []const u8,

    const wire_names = .{
        .bad = "bad",
        .commit = "commit",
        .tree = "tree",
        .blob = "blob",
        .tag = "tag",
        .ext2 = "ext2",
        .ofs_delta = "ofsDelta",
        .ref_delta = "refDelta",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitItemDescriptorRecursionLevel = union(enum) {
    none,
    one_level,
    one_level_plus_nested_empty_folders,
    full,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .one_level = "oneLevel",
        .one_level_plus_nested_empty_folders = "oneLevelPlusNestedEmptyFolders",
        .full = "full",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitItemDescriptorVersionOptions = union(enum) {
    none,
    previous_change,
    first_parent,
    unrecognized: []const u8,

    const wire_names = .{
        .none = "none",
        .previous_change = "previousChange",
        .first_parent = "firstParent",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitItemDescriptorVersionType = union(enum) {
    branch,
    tag,
    commit,
    unrecognized: []const u8,

    const wire_names = .{
        .branch = "branch",
        .tag = "tag",
        .commit = "commit",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitPullRequestQueryInputInclude = union(enum) {
    not_set,
    labels,
    unrecognized: []const u8,

    const wire_names = .{
        .not_set = "notSet",
        .labels = "labels",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitPullRequestQueryInputType = union(enum) {
    not_set,
    last_merge_commit,
    commit,
    unrecognized: []const u8,

    const wire_names = .{
        .not_set = "notSet",
        .last_merge_commit = "lastMergeCommit",
        .commit = "commit",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitPullRequestIterationReason = union(enum) {
    push,
    force_push,
    create,
    rebase,
    unknown,
    retarget,
    resolve_conflicts,
    unrecognized: []const u8,

    const wire_names = .{
        .push = "push",
        .force_push = "forcePush",
        .create = "create",
        .rebase = "rebase",
        .unknown = "unknown",
        .retarget = "retarget",
        .resolve_conflicts = "resolveConflicts",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const CommentCommentType = union(enum) {
    unknown,
    text,
    code_change,
    system,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .text = "text",
        .code_change = "codeChange",
        .system = "system",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitPullRequestCommentThreadStatus = union(enum) {
    unknown,
    active,
    fixed,
    wont_fix,
    closed,
    by_design,
    pending,
    unrecognized: []const u8,

    const wire_names = .{
        .unknown = "unknown",
        .active = "active",
        .fixed = "fixed",
        .wont_fix = "wontFix",
        .closed = "closed",
        .by_design = "byDesign",
        .pending = "pending",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitRefUpdateResultUpdateStatus = union(enum) {
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
    unrecognized: []const u8,

    const wire_names = .{
        .succeeded = "succeeded",
        .force_push_required = "forcePushRequired",
        .stale_old_object_id = "staleOldObjectId",
        .invalid_ref_name = "invalidRefName",
        .unprocessed = "unprocessed",
        .unresolvable_to_commit = "unresolvableToCommit",
        .write_permission_required = "writePermissionRequired",
        .manage_note_permission_required = "manageNotePermissionRequired",
        .create_branch_permission_required = "createBranchPermissionRequired",
        .create_tag_permission_required = "createTagPermissionRequired",
        .rejected_by_plugin = "rejectedByPlugin",
        .locked = "locked",
        .ref_name_conflict = "refNameConflict",
        .rejected_by_policy = "rejectedByPolicy",
        .succeeded_non_existent_ref = "succeededNonExistentRef",
        .succeeded_corrupt_ref = "succeededCorruptRef",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
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

pub const GitTreeEntryRefGitObjectType = union(enum) {
    bad,
    commit,
    tree,
    blob,
    tag,
    ext2,
    ofs_delta,
    ref_delta,
    unrecognized: []const u8,

    const wire_names = .{
        .bad = "bad",
        .commit = "commit",
        .tree = "tree",
        .blob = "blob",
        .tag = "tag",
        .ext2 = "ext2",
        .ofs_delta = "ofsDelta",
        .ref_delta = "refDelta",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitForkSyncRequestStatus = union(enum) {
    queued,
    in_progress,
    completed,
    failed,
    abandoned,
    unrecognized: []const u8,

    const wire_names = .{
        .queued = "queued",
        .in_progress = "inProgress",
        .completed = "completed",
        .failed = "failed",
        .abandoned = "abandoned",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
    }
};

pub const GitMergeStatus = union(enum) {
    queued,
    in_progress,
    completed,
    failed,
    abandoned,
    unrecognized: []const u8,

    const wire_names = .{
        .queued = "queued",
        .in_progress = "inProgress",
        .completed = "completed",
        .failed = "failed",
        .abandoned = "abandoned",
    };

    pub fn zerdeDeserialize(
        comptime T: type,
        allocator: std.mem.Allocator,
        deserializer: anytype,
    ) @TypeOf(deserializer.*).Error!T {
        return core.open_enum.deserialize(T, wire_names, allocator, deserializer);
    }

    pub fn zerdeSerialize(self: @This(), serializer: anytype) !void {
        return core.open_enum.serialize(self, wire_names, serializer);
    }

    pub fn toWire(self: @This()) []const u8 {
        return core.open_enum.toWire(self, wire_names);
    }

    pub fn fromWire(allocator: std.mem.Allocator, s: []const u8) !@This() {
        return core.open_enum.fromWire(@This(), wire_names, allocator, s);
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
