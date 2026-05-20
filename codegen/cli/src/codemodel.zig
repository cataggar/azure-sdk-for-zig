//! Code model types deserialized from the JSON produced by
//! `codegen/tcgc-component`. The shape is duplicated on the JS
//! side in `tcgc-component/src/index.js`; the two must evolve together.
//!
//! Keep the types open (`additionalProperties` on the JS side) and
//! tolerant of missing fields here — TCGC adds new metadata over time
//! and we don't want every TypeSpec compiler upgrade to break codegen.

const std = @import("std");

pub const CodeModel = struct {
    package_name: []const u8,
    package_version: []const u8,
    target_kind: []const u8,
    service_kind: []const u8,
    clients: []Client = &.{},
    models: []Model = &.{},
    enums: []Enum = &.{},
    unions: []Union = &.{},
};

pub const Client = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: ?[]const u8 = null,
    parameters: []ClientParameter = &.{},
    endpoint: Endpoint,
    methods: []Method = &.{},
    sub_clients: []SubClient = &.{},
    credential_scopes: [][]const u8 = &.{},
};

pub const Endpoint = struct {
    name: []const u8,
    default_value: ?[]const u8 = null,
};

pub const ClientParameter = struct {
    name: []const u8,
    doc: ?[]const u8 = null,
    param_type: TypeRef,
    optional: bool = false,
};

pub const SubClient = struct {
    name: []const u8,
    accessor_name: []const u8,
    client_name: []const u8,
};

pub const Method = struct {
    name: []const u8,
    doc: ?[]const u8 = null,
    http_method: []const u8,
    path: []const u8,
    parameters: []MethodParameter = &.{},
    response: MethodResponse,
    paging: ?Paging = null,
    long_running: ?LongRunning = null,
    kind: []const u8 = "basic",
};

pub const MethodParameter = struct {
    name: []const u8,
    serialized_name: []const u8,
    location: []const u8,
    doc: ?[]const u8 = null,
    param_type: TypeRef,
    optional: bool = false,
};

pub const MethodResponse = struct {
    response_type: ?TypeRef = null,
    status_codes: []std.json.Value = &.{},
};

pub const Paging = struct {
    items_segments: []?[]const u8 = &.{},
    next_link_segments: []?[]const u8 = &.{},
    next_link_verb: ?[]const u8 = null,
    next_link_operation: ?[]const u8 = null,
};

pub const LongRunning = struct {
    final_state_via: ?[]const u8 = null,
    final_response_type: ?TypeRef = null,
};

pub const Model = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: ?[]const u8 = null,
    fields: []Field = &.{},
    parents: [][]const u8 = &.{},
    discriminator: ?[]const u8 = null,
    is_input: bool = false,
    is_output: bool = false,
    /// ARM base-type kind, set by the TCGC adapter when this model's
    /// `baseModel` chain terminates in `Azure.ResourceManager.{Proxy,
    /// Tracked,Extension}Resource`. The emitter renders a
    /// `pub const arm_resource_kind: core.arm.ResourceKind = .<kind>;`
    /// inside the generated struct so `core.arm` helpers can dispatch
    /// on it.
    arm_resource_kind: ?[]const u8 = null,
};

pub const Field = struct {
    name: []const u8,
    serialized_name: []const u8,
    doc: ?[]const u8 = null,
    field_type: TypeRef,
    optional: bool = false,
    read_only: bool = false,
    flatten: bool = false,
};

pub const Enum = struct {
    name: []const u8,
    namespace: ?[]const u8 = null,
    doc: ?[]const u8 = null,
    values: []EnumValue = &.{},
    value_type: []const u8 = "string",
    extensible: bool = true,
};

pub const EnumValue = struct {
    name: []const u8,
    value: std.json.Value,
    doc: ?[]const u8 = null,
};

pub const Union = struct {
    name: []const u8,
    doc: ?[]const u8 = null,
};

pub const TypeRef = struct {
    kind: []const u8,
    value: std.json.Value,

    pub fn isModel(self: TypeRef) bool {
        return std.mem.eql(u8, self.kind, "Model");
    }
    pub fn isEnum(self: TypeRef) bool {
        return std.mem.eql(u8, self.kind, "Enum");
    }
    pub fn isOption(self: TypeRef) bool {
        return std.mem.eql(u8, self.kind, "Option");
    }
    pub fn isArray(self: TypeRef) bool {
        return std.mem.eql(u8, self.kind, "Array");
    }
    pub fn isMap(self: TypeRef) bool {
        return std.mem.eql(u8, self.kind, "Map");
    }
    pub fn isScalar(self: TypeRef) bool {
        return std.mem.eql(u8, self.kind, "Scalar");
    }

    /// Returns the scalar string (e.g. "string", "i32") if this is a
    /// `Scalar` type, otherwise null.
    pub fn scalarName(self: TypeRef) ?[]const u8 {
        if (!self.isScalar()) return null;
        return switch (self.value) {
            .string => |s| s,
            else => null,
        };
    }

    /// Returns the named type (model / enum / union name) if this is a
    /// reference type.
    pub fn namedTypeName(self: TypeRef) ?[]const u8 {
        if (!self.isModel() and !self.isEnum() and
            !std.mem.eql(u8, self.kind, "Union")) return null;
        return switch (self.value) {
            .string => |s| s,
            else => null,
        };
    }
};
