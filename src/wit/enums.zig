//! Generated enums.
//!
//! Azure data-plane enums are typically *extensible* — the wire
//! contract may grow with new values that older clients still
//! need to round-trip. Represented as a tagged union with a
//! catch-all `unrecognized` variant.

const std = @import("std");
const core = @import("azure_sdk_core");

pub const AccountRecentActivityWorkItemModel2ActivityType = enum {
    visited,
    edited,
    deleted,
    restored,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .visited => "visited",
            .edited => "edited",
            .deleted => "deleted",
            .restored => "restored",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "visited")) return .visited;
        if (std.mem.eql(u8, s, "edited")) return .edited;
        if (std.mem.eql(u8, s, "deleted")) return .deleted;
        if (std.mem.eql(u8, s, "restored")) return .restored;
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

pub const WorkItemClassificationNodeStructureType = enum {
    area,
    iteration,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .area => "area",
            .iteration => "iteration",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "area")) return .area;
        if (std.mem.eql(u8, s, "iteration")) return .iteration;
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

pub const DeleteRequestStructureGroup = enum {
    areas,
    iterations,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .areas => "areas",
            .iterations => "iterations",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "areas")) return .areas;
        if (std.mem.eql(u8, s, "iterations")) return .iterations;
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

pub const GetRequestStructureGroup = enum {
    areas,
    iterations,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .areas => "areas",
            .iterations => "iterations",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "areas")) return .areas;
        if (std.mem.eql(u8, s, "iterations")) return .iterations;
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

pub const UpdateRequestStructureGroup = enum {
    areas,
    iterations,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .areas => "areas",
            .iterations => "iterations",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "areas")) return .areas;
        if (std.mem.eql(u8, s, "iterations")) return .iterations;
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

pub const CreateOrUpdateRequestStructureGroup = enum {
    areas,
    iterations,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .areas => "areas",
            .iterations => "iterations",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "areas")) return .areas;
        if (std.mem.eql(u8, s, "iterations")) return .iterations;
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

pub const ListRequestExpand = enum {
    none,
    extension_fields,
    include_deleted,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .extension_fields => "extensionFields",
            .include_deleted => "includeDeleted",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "extensionFields")) return .extension_fields;
        if (std.mem.eql(u8, s, "includeDeleted")) return .include_deleted;
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

pub const WorkItemField2Type = enum {
    string,
    integer,
    date_time,
    plain_text,
    html,
    tree_path,
    history,
    double,
    guid,
    boolean,
    identity,
    picklist_string,
    picklist_integer,
    picklist_double,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .string => "string",
            .integer => "integer",
            .date_time => "dateTime",
            .plain_text => "plainText",
            .html => "html",
            .tree_path => "treePath",
            .history => "history",
            .double => "double",
            .guid => "guid",
            .boolean => "boolean",
            .identity => "identity",
            .picklist_string => "picklistString",
            .picklist_integer => "picklistInteger",
            .picklist_double => "picklistDouble",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "string")) return .string;
        if (std.mem.eql(u8, s, "integer")) return .integer;
        if (std.mem.eql(u8, s, "dateTime")) return .date_time;
        if (std.mem.eql(u8, s, "plainText")) return .plain_text;
        if (std.mem.eql(u8, s, "html")) return .html;
        if (std.mem.eql(u8, s, "treePath")) return .tree_path;
        if (std.mem.eql(u8, s, "history")) return .history;
        if (std.mem.eql(u8, s, "double")) return .double;
        if (std.mem.eql(u8, s, "guid")) return .guid;
        if (std.mem.eql(u8, s, "boolean")) return .boolean;
        if (std.mem.eql(u8, s, "identity")) return .identity;
        if (std.mem.eql(u8, s, "picklistString")) return .picklist_string;
        if (std.mem.eql(u8, s, "picklistInteger")) return .picklist_integer;
        if (std.mem.eql(u8, s, "picklistDouble")) return .picklist_double;
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

pub const WorkItemField2Usage = enum {
    none,
    work_item,
    work_item_link,
    tree,
    work_item_type_extension,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .work_item => "workItem",
            .work_item_link => "workItemLink",
            .tree => "tree",
            .work_item_type_extension => "workItemTypeExtension",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "workItem")) return .work_item;
        if (std.mem.eql(u8, s, "workItemLink")) return .work_item_link;
        if (std.mem.eql(u8, s, "tree")) return .tree;
        if (std.mem.eql(u8, s, "workItemTypeExtension")) return .work_item_type_extension;
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

pub const ListRequestExpand1 = enum {
    none,
    wiql,
    clauses,
    all,
    minimal,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .wiql => "wiql",
            .clauses => "clauses",
            .all => "all",
            .minimal => "minimal",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "wiql")) return .wiql;
        if (std.mem.eql(u8, s, "clauses")) return .clauses;
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "minimal")) return .minimal;
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

pub const WorkItemQueryClauseLogicalOperator = enum {
    none,
    @"and",
    @"or",

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .@"and" => "and",
            .@"or" => "or",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
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

pub const QueryHierarchyItemFilterOptions = enum {
    work_items,
    links_one_hop_must_contain,
    links_one_hop_may_contain,
    links_one_hop_does_not_contain,
    links_recursive_must_contain,
    links_recursive_may_contain,
    links_recursive_does_not_contain,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .work_items => "workItems",
            .links_one_hop_must_contain => "linksOneHopMustContain",
            .links_one_hop_may_contain => "linksOneHopMayContain",
            .links_one_hop_does_not_contain => "linksOneHopDoesNotContain",
            .links_recursive_must_contain => "linksRecursiveMustContain",
            .links_recursive_may_contain => "linksRecursiveMayContain",
            .links_recursive_does_not_contain => "linksRecursiveDoesNotContain",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "workItems")) return .work_items;
        if (std.mem.eql(u8, s, "linksOneHopMustContain")) return .links_one_hop_must_contain;
        if (std.mem.eql(u8, s, "linksOneHopMayContain")) return .links_one_hop_may_contain;
        if (std.mem.eql(u8, s, "linksOneHopDoesNotContain")) return .links_one_hop_does_not_contain;
        if (std.mem.eql(u8, s, "linksRecursiveMustContain")) return .links_recursive_must_contain;
        if (std.mem.eql(u8, s, "linksRecursiveMayContain")) return .links_recursive_may_contain;
        if (std.mem.eql(u8, s, "linksRecursiveDoesNotContain")) return .links_recursive_does_not_contain;
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

pub const QueryHierarchyItemQueryRecursionOption = enum {
    parent_first,
    child_first,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .parent_first => "parentFirst",
            .child_first => "childFirst",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "parentFirst")) return .parent_first;
        if (std.mem.eql(u8, s, "childFirst")) return .child_first;
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

pub const QueryHierarchyItemQueryType = enum {
    flat,
    tree,
    one_hop,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .flat => "flat",
            .tree => "tree",
            .one_hop => "oneHop",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "flat")) return .flat;
        if (std.mem.eql(u8, s, "tree")) return .tree;
        if (std.mem.eql(u8, s, "oneHop")) return .one_hop;
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

pub const GetRequestExpand = enum {
    none,
    wiql,
    clauses,
    all,
    minimal,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .wiql => "wiql",
            .clauses => "clauses",
            .all => "all",
            .minimal => "minimal",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "wiql")) return .wiql;
        if (std.mem.eql(u8, s, "clauses")) return .clauses;
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "minimal")) return .minimal;
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

pub const QueryBatchGetRequestExpand = enum {
    none,
    wiql,
    clauses,
    all,
    minimal,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .wiql => "wiql",
            .clauses => "clauses",
            .all => "all",
            .minimal => "minimal",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "wiql")) return .wiql;
        if (std.mem.eql(u8, s, "clauses")) return .clauses;
        if (std.mem.eql(u8, s, "all")) return .all;
        if (std.mem.eql(u8, s, "minimal")) return .minimal;
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

pub const QueryBatchGetRequestErrorPolicy = enum {
    fail,
    omit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .fail => "fail",
            .omit => "omit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "fail")) return .fail;
        if (std.mem.eql(u8, s, "omit")) return .omit;
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

pub const WorkItemMultilineFieldsFormat = enum {
    markdown,
    html,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .markdown => "markdown",
            .html => "html",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "markdown")) return .markdown;
        if (std.mem.eql(u8, s, "html")) return .html;
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

pub const ReadReportingRevisionsGetRequestExpand = enum {
    none,
    fields,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .fields => "fields",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "fields")) return .fields;
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

pub const ReadReportingRevisionsPostRequestExpand = enum {
    none,
    fields,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .fields => "fields",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "fields")) return .fields;
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

pub const ListRequestExpand2 = enum {
    none,
    relations,
    fields,
    links,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .relations => "relations",
            .fields => "fields",
            .links => "links",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "relations")) return .relations;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "links")) return .links;
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

pub const ListRequestErrorPolicy = enum {
    fail,
    omit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .fail => "fail",
            .omit => "omit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "fail")) return .fail;
        if (std.mem.eql(u8, s, "omit")) return .omit;
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

pub const GetWorkItemTemplateRequestExpand = enum {
    none,
    relations,
    fields,
    links,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .relations => "relations",
            .fields => "fields",
            .links => "links",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "relations")) return .relations;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "links")) return .links;
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

pub const CreateRequestExpand = enum {
    none,
    relations,
    fields,
    links,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .relations => "relations",
            .fields => "fields",
            .links => "links",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "relations")) return .relations;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "links")) return .links;
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

pub const GetWorkItemRequestExpand = enum {
    none,
    relations,
    fields,
    links,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .relations => "relations",
            .fields => "fields",
            .links => "links",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "relations")) return .relations;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "links")) return .links;
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

pub const UpdateRequestExpand = enum {
    none,
    relations,
    fields,
    links,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .relations => "relations",
            .fields => "fields",
            .links => "links",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "relations")) return .relations;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "links")) return .links;
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

pub const WorkItemBatchGetRequestExpand = enum {
    none,
    relations,
    fields,
    links,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .relations => "relations",
            .fields => "fields",
            .links => "links",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "relations")) return .relations;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "links")) return .links;
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

pub const WorkItemBatchGetRequestErrorPolicy = enum {
    fail,
    omit,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .fail => "fail",
            .omit => "omit",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "fail")) return .fail;
        if (std.mem.eql(u8, s, "omit")) return .omit;
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

pub const ListRequestExpand3 = enum {
    none,
    relations,
    fields,
    links,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .relations => "relations",
            .fields => "fields",
            .links => "links",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "relations")) return .relations;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "links")) return .links;
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

pub const GetRequestExpand1 = enum {
    none,
    relations,
    fields,
    links,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .relations => "relations",
            .fields => "fields",
            .links => "links",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "relations")) return .relations;
        if (std.mem.eql(u8, s, "fields")) return .fields;
        if (std.mem.eql(u8, s, "links")) return .links;
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

pub const GetCommentsBatchRequestExpand = enum {
    none,
    reactions,
    rendered_text,
    rendered_text_only,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .reactions => "reactions",
            .rendered_text => "renderedText",
            .rendered_text_only => "renderedTextOnly",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "reactions")) return .reactions;
        if (std.mem.eql(u8, s, "renderedText")) return .rendered_text;
        if (std.mem.eql(u8, s, "renderedTextOnly")) return .rendered_text_only;
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

pub const CommentFormat = enum {
    markdown,
    html,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .markdown => "markdown",
            .html => "html",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "markdown")) return .markdown;
        if (std.mem.eql(u8, s, "html")) return .html;
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

pub const CommentReactionType = enum {
    like,
    dislike,
    heart,
    hooray,
    smile,
    confused,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .like => "like",
            .dislike => "dislike",
            .heart => "heart",
            .hooray => "hooray",
            .smile => "smile",
            .confused => "confused",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "like")) return .like;
        if (std.mem.eql(u8, s, "dislike")) return .dislike;
        if (std.mem.eql(u8, s, "heart")) return .heart;
        if (std.mem.eql(u8, s, "hooray")) return .hooray;
        if (std.mem.eql(u8, s, "smile")) return .smile;
        if (std.mem.eql(u8, s, "confused")) return .confused;
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

pub const GetCommentRequestExpand = enum {
    none,
    reactions,
    rendered_text,
    rendered_text_only,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .reactions => "reactions",
            .rendered_text => "renderedText",
            .rendered_text_only => "renderedTextOnly",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "reactions")) return .reactions;
        if (std.mem.eql(u8, s, "renderedText")) return .rendered_text;
        if (std.mem.eql(u8, s, "renderedTextOnly")) return .rendered_text_only;
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

pub const DeleteRequestReactionType = enum {
    like,
    dislike,
    heart,
    hooray,
    smile,
    confused,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .like => "like",
            .dislike => "dislike",
            .heart => "heart",
            .hooray => "hooray",
            .smile => "smile",
            .confused => "confused",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "like")) return .like;
        if (std.mem.eql(u8, s, "dislike")) return .dislike;
        if (std.mem.eql(u8, s, "heart")) return .heart;
        if (std.mem.eql(u8, s, "hooray")) return .hooray;
        if (std.mem.eql(u8, s, "smile")) return .smile;
        if (std.mem.eql(u8, s, "confused")) return .confused;
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

pub const CreateRequestReactionType = enum {
    like,
    dislike,
    heart,
    hooray,
    smile,
    confused,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .like => "like",
            .dislike => "dislike",
            .heart => "heart",
            .hooray => "hooray",
            .smile => "smile",
            .confused => "confused",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "like")) return .like;
        if (std.mem.eql(u8, s, "dislike")) return .dislike;
        if (std.mem.eql(u8, s, "heart")) return .heart;
        if (std.mem.eql(u8, s, "hooray")) return .hooray;
        if (std.mem.eql(u8, s, "smile")) return .smile;
        if (std.mem.eql(u8, s, "confused")) return .confused;
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

pub const ListRequestReactionType = enum {
    like,
    dislike,
    heart,
    hooray,
    smile,
    confused,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .like => "like",
            .dislike => "dislike",
            .heart => "heart",
            .hooray => "hooray",
            .smile => "smile",
            .confused => "confused",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "like")) return .like;
        if (std.mem.eql(u8, s, "dislike")) return .dislike;
        if (std.mem.eql(u8, s, "heart")) return .heart;
        if (std.mem.eql(u8, s, "hooray")) return .hooray;
        if (std.mem.eql(u8, s, "smile")) return .smile;
        if (std.mem.eql(u8, s, "confused")) return .confused;
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

pub const ListRequestExpand4 = enum {
    none,
    allowed_values,
    dependent_fields,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .allowed_values => "allowedValues",
            .dependent_fields => "dependentFields",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "allowedValues")) return .allowed_values;
        if (std.mem.eql(u8, s, "dependentFields")) return .dependent_fields;
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

pub const GetRequestExpand2 = enum {
    none,
    allowed_values,
    dependent_fields,
    all,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .none => "none",
            .allowed_values => "allowedValues",
            .dependent_fields => "dependentFields",
            .all => "all",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "none")) return .none;
        if (std.mem.eql(u8, s, "allowedValues")) return .allowed_values;
        if (std.mem.eql(u8, s, "dependentFields")) return .dependent_fields;
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

pub const WorkItemQueryResultQueryResultType = enum {
    work_item,
    work_item_link,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .work_item => "workItem",
            .work_item_link => "workItemLink",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "workItem")) return .work_item;
        if (std.mem.eql(u8, s, "workItemLink")) return .work_item_link;
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

pub const WorkItemQueryResultQueryType = enum {
    flat,
    tree,
    one_hop,

    pub fn toWire(self: @This()) []const u8 {
        return switch (self) {
            .flat => "flat",
            .tree => "tree",
            .one_hop => "oneHop",
        };
    }

    pub fn fromWire(s: []const u8) ?@This() {
        if (std.mem.eql(u8, s, "flat")) return .flat;
        if (std.mem.eql(u8, s, "tree")) return .tree;
        if (std.mem.eql(u8, s, "oneHop")) return .one_hop;
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
