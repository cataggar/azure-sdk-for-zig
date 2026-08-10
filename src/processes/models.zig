//! Generated data-transfer-object models.

const std = @import("std");
const enums = @import("enums.zig");

/// A collection of `ProcessInfo` as returned by Azure DevOps.
pub const ProcessInfoList = struct {
    count: ?i32 = null,
    value: ?[]const ProcessInfo = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Process.
pub const ProcessInfo = struct {
    /// Indicates the type of customization on this process. System Process is default process. Inherited Process is modified process that was System process before.
    customization_type: ?enums.ProcessInfoCustomizationType = null,
    /// Description of the process.
    description: ?[]const u8 = null,
    /// Is the process default.
    is_default: ?bool = null,
    /// Is the process enabled.
    is_enabled: ?bool = null,
    /// Name of the process.
    name: ?[]const u8 = null,
    /// ID of the parent process.
    parent_process_type_id: ?[]const u8 = null,
    /// Projects in this process to which the user is subscribed to.
    projects: ?[]const ProjectReference = null,
    /// Reference name of the process.
    reference_name: ?[]const u8 = null,
    /// The ID of the process.
    type_id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines the project reference class.
pub const ProjectReference = struct {
    /// Description of the project
    description: ?[]const u8 = null,
    /// The ID of the project
    id: ?[]const u8 = null,
    /// Name of the project
    name: ?[]const u8 = null,
    /// Url of the project
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a process being created.
pub const CreateProcessModel = struct {
    /// Description of the process
    description: ?[]const u8 = null,
    /// Name of the process
    name: ?[]const u8 = null,
    /// The ID of the parent process
    parent_process_type_id: ?[]const u8 = null,
    /// Reference name of process being created. If not specified, server will assign a unique reference name
    reference_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a request to update a process
pub const UpdateProcessModel = struct {
    /// New description of the process
    description: ?[]const u8 = null,
    /// If true new projects will use this process by default
    is_default: ?bool = null,
    /// If false the process will be disabled and cannot be used to create projects
    is_enabled: ?bool = null,
    /// New name of the process
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ProcessBehavior` as returned by Azure DevOps.
pub const ProcessBehaviorList = struct {
    count: ?i32 = null,
    value: ?[]const ProcessBehavior = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Process Behavior Model.
pub const ProcessBehavior = struct {
    /// Color.
    color: ?[]const u8 = null,
    /// Indicates the type of customization on this work item. System behaviors are inherited from parent process but not modified. Inherited behaviors are modified behaviors that were inherited from parent process. Custom behaviors are behaviors created by user in current process.
    customization: ?enums.ProcessBehaviorCustomization = null,
    /// . Description
    description: ?[]const u8 = null,
    /// Process Behavior Fields.
    fields: ?[]const ProcessBehaviorField = null,
    inherits: ?ProcessBehaviorReference = null,
    /// Behavior Name.
    name: ?[]const u8 = null,
    /// Rank of the behavior
    rank: ?i32 = null,
    /// Behavior Id
    reference_name: ?[]const u8 = null,
    /// Url of the behavior.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Process Behavior Field.
pub const ProcessBehaviorField = struct {
    /// Name of the field.
    name: ?[]const u8 = null,
    /// Reference name of the field.
    reference_name: ?[]const u8 = null,
    /// Url to field.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Process behavior Reference.
pub const ProcessBehaviorReference = struct {
    /// Id of a Behavior.
    behavior_ref_name: ?[]const u8 = null,
    /// Url to behavior.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Process Behavior Create Payload.
pub const ProcessBehaviorCreateRequest = struct {
    /// Color.
    color: ?[]const u8 = null,
    /// Parent behavior id.
    inherits: ?[]const u8 = null,
    /// Name of the behavior.
    name: ?[]const u8 = null,
    /// ReferenceName is optional, if not specified will be auto-generated.
    reference_name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Process Behavior Replace Payload.
pub const ProcessBehaviorUpdateRequest = struct {
    /// Color.
    color: ?[]const u8 = null,
    /// Behavior Name.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ProcessWorkItemType` as returned by Azure DevOps.
pub const ProcessWorkItemTypeList = struct {
    count: ?i32 = null,
    value: ?[]const ProcessWorkItemType = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class that describes a work item type object
pub const ProcessWorkItemType = struct {
    behaviors: ?[]const WorkItemTypeBehavior = null,
    /// Color hexadecimal code to represent the work item type
    color: ?[]const u8 = null,
    /// Indicates the type of customization on this work item System work item types are inherited from parent process but not modified Inherited work item types are modified work item that were inherited from parent process Custom work item types are work item types that were created in the current process
    customization: ?enums.ProcessWorkItemTypeCustomization = null,
    /// Description of the work item type
    description: ?[]const u8 = null,
    /// Icon to represent the work item typ
    icon: ?[]const u8 = null,
    /// Reference name of the parent work item type
    inherits: ?[]const u8 = null,
    /// Indicates if a work item type is disabled
    is_disabled: ?bool = null,
    layout: ?FormLayout = null,
    /// Name of the work item type
    name: ?[]const u8 = null,
    /// Reference name of work item type
    reference_name: ?[]const u8 = null,
    states: ?[]const WorkItemStateResultModel = null,
    /// Url of the work item type
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Association between a work item type and it's behavior
pub const WorkItemTypeBehavior = struct {
    behavior: ?WorkItemBehaviorReference = null,
    /// If true the work item type is the default work item type in the behavior
    is_default: ?bool = null,
    /// If true the work item type is the default work item type in the parent behavior
    is_legacy_default: ?bool = null,
    /// URL of the work item type behavior
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Reference to the behavior of a work item type.
pub const WorkItemBehaviorReference = struct {
    /// The ID of the reference behavior.
    id: ?[]const u8 = null,
    /// The url of the reference behavior.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes the layout of a work item type
pub const FormLayout = struct {
    /// Gets and sets extensions list.
    extensions: ?[]const Extension = null,
    /// Top level tabs of the layout.
    pages: ?[]const Page = null,
    /// Headers controls of the layout.
    system_controls: ?[]const Control = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represents the extensions part of the layout
pub const Extension = struct {
    /// Id of the extension
    id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Describes a page in the work item form layout
pub const Page = struct {
    contribution: ?WitContribution = null,
    /// The id for the layout node.
    id: ?[]const u8 = null,
    /// A value indicating whether this layout node has been inherited from a parent layout. This is expected to only be only set by the combiner.
    inherited: ?bool = null,
    /// A value indicating if the layout node is contribution are not.
    is_contribution: ?bool = null,
    /// The label for the page.
    label: ?[]const u8 = null,
    /// A value indicating whether any user operations are permitted on this page and the contents of this page
    locked: ?bool = null,
    /// Order in which the page should appear in the layout.
    order: ?i32 = null,
    /// A value indicating whether this layout node has been overridden by a child layout.
    overridden: ?bool = null,
    /// The icon for the page.
    page_type: ?enums.PagePageType = null,
    /// The sections of the page.
    sections: ?[]const Section = null,
    /// A value indicating if the page should be hidden or not.
    visible: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Properties of a work item form contribution
pub const WitContribution = struct {
    /// The id for the contribution.
    contribution_id: ?[]const u8 = null,
    /// The height for the contribution.
    height: ?i32 = null,
    /// A dictionary holding key value pairs for contribution inputs.
    inputs: ?std.json.ArrayHashMap(WitContributionInput) = null,
    /// A value indicating if the contribution should be show on deleted workItem.
    show_on_deleted_work_item: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const WitContributionInput = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a section of the work item form layout
pub const Section = struct {
    /// List of child groups in this section
    groups: ?[]const Group = null,
    /// The id for the layout node.
    id: ?[]const u8 = null,
    /// A value indicating whether this layout node has been overridden by a child layout.
    overridden: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represent a group in the form that holds controls in it.
pub const Group = struct {
    contribution: ?WitContribution = null,
    /// Controls to be put in the group.
    controls: ?[]const Control = null,
    /// The height for the contribution.
    height: ?i32 = null,
    /// The id for the layout node.
    id: ?[]const u8 = null,
    /// A value indicating whether this layout node has been inherited from a parent layout. This is expected to only be only set by the combiner.
    inherited: ?bool = null,
    /// A value indicating if the layout node is contribution are not.
    is_contribution: ?bool = null,
    /// Label for the group.
    label: ?[]const u8 = null,
    /// Order in which the group should appear in the section.
    order: ?i32 = null,
    /// A value indicating whether this layout node has been overridden by a child layout.
    overridden: ?bool = null,
    /// A value indicating if the group should be hidden or not.
    visible: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Represent a control in the form.
pub const Control = struct {
    contribution: ?WitContribution = null,
    /// Type of the control.
    control_type: ?[]const u8 = null,
    /// Height of the control, for html controls.
    height: ?i32 = null,
    /// The id for the layout node.
    id: ?[]const u8 = null,
    /// A value indicating whether this layout node has been inherited. from a parent layout. This is expected to only be only set by the combiner.
    inherited: ?bool = null,
    /// A value indicating if the layout node is contribution or not.
    is_contribution: ?bool = null,
    /// Label for the field.
    label: ?[]const u8 = null,
    /// Inner text of the control.
    metadata: ?[]const u8 = null,
    /// Order in which the control should appear in its group.
    order: ?i32 = null,
    /// A value indicating whether this layout node has been overridden . by a child layout.
    overridden: ?bool = null,
    /// A value indicating if the control is readonly.
    read_only: ?bool = null,
    /// A value indicating if the control should be hidden or not.
    visible: ?bool = null,
    /// Watermark text for the textbox.
    watermark: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class that represents a work item state result.
pub const WorkItemStateResultModel = struct {
    /// Work item state color.
    color: ?[]const u8 = null,
    /// Work item state customization type.
    customization_type: ?enums.WorkItemStateResultModelCustomizationType = null,
    /// If the Work item state is hidden.
    hidden: ?bool = null,
    /// Id of the Workitemstate.
    id: ?[]const u8 = null,
    /// Work item state name.
    name: ?[]const u8 = null,
    /// Work item state order.
    order: ?i32 = null,
    /// Work item state statecategory.
    state_category: ?[]const u8 = null,
    /// Work item state url.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class for create work item type request
pub const CreateProcessWorkItemTypeRequest = struct {
    /// Color hexadecimal code to represent the work item type
    color: ?[]const u8 = null,
    /// Description of the work item type
    description: ?[]const u8 = null,
    /// Icon to represent the work item type
    icon: ?[]const u8 = null,
    /// Parent work item type for work item type
    inherits_from: ?[]const u8 = null,
    /// True if the work item type need to be disabled
    is_disabled: ?bool = null,
    /// Name of work item type
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class for update request on a work item type
pub const UpdateProcessWorkItemTypeRequest = struct {
    /// Color of the work item type
    color: ?[]const u8 = null,
    /// Description of the work item type
    description: ?[]const u8 = null,
    /// Icon of the work item type
    icon: ?[]const u8 = null,
    /// If set will disable the work item type
    is_disabled: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ProcessWorkItemTypeField` as returned by Azure DevOps.
pub const ProcessWorkItemTypeFieldList = struct {
    count: ?i32 = null,
    value: ?[]const ProcessWorkItemTypeField = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class that describes a field in a work item type and its properties.
pub const ProcessWorkItemTypeField = struct {
    /// The list of field allowed values.
    allowed_values: ?[]const ProcessWorkItemTypeFieldAllowedValue = null,
    /// Allow setting field value to a group identity. Only applies to identity fields.
    allow_groups: ?bool = null,
    /// Indicates the type of customization on this work item.
    customization: ?enums.ProcessWorkItemTypeFieldCustomization = null,
    /// The default value of the field.
    default_value: ?ProcessWorkItemTypeFieldDefaultValue = null,
    /// Description of the field.
    description: ?[]const u8 = null,
    /// Information about field definition being locked for editing
    is_locked: ?bool = null,
    /// Name of the field.
    name: ?[]const u8 = null,
    /// If true the field cannot be edited.
    read_only: ?bool = null,
    /// Reference name of the field.
    reference_name: ?[]const u8 = null,
    /// If true the field cannot be empty.
    required: ?bool = null,
    /// Type of the field.
    type: ?enums.ProcessWorkItemTypeFieldType = null,
    /// Resource URL of the field.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProcessWorkItemTypeFieldAllowedValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const ProcessWorkItemTypeFieldDefaultValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class that describes a request to add a field in a work item type.
pub const AddProcessWorkItemTypeFieldRequest = struct {
    /// The list of field allowed values.
    allowed_values: ?[]const []const u8 = null,
    /// Allow setting field value to a group identity. Only applies to identity fields.
    allow_groups: ?bool = null,
    /// The default value of the field.
    default_value: ?AddProcessWorkItemTypeFieldRequestDefaultValue = null,
    /// If true the field cannot be edited.
    read_only: ?bool = null,
    /// Reference name of the field.
    reference_name: ?[]const u8 = null,
    /// If true the field cannot be empty.
    required: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const AddProcessWorkItemTypeFieldRequestDefaultValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class to describe a request that updates a field's properties in a work item type.
pub const UpdateProcessWorkItemTypeFieldRequest = struct {
    /// The list of field allowed values.
    allowed_values: ?[]const []const u8 = null,
    /// Allow setting field value to a group identity. Only applies to identity fields.
    allow_groups: ?bool = null,
    /// The default value of the field.
    default_value: ?UpdateProcessWorkItemTypeFieldRequestDefaultValue = null,
    /// If true the field cannot be edited.
    read_only: ?bool = null,
    /// The default value of the field.
    required: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

pub const UpdateProcessWorkItemTypeFieldRequestDefaultValue = struct {
    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `Control` as returned by Azure DevOps.
pub const ControlList = struct {
    count: ?i32 = null,
    value: ?[]const Control = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `ProcessRule` as returned by Azure DevOps.
pub const ProcessRuleList = struct {
    count: ?i32 = null,
    value: ?[]const ProcessRule = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Process Rule Response.
pub const ProcessRule = struct {
    /// List of actions to take when the rule is triggered.
    actions: ?[]const RuleAction = null,
    /// List of conditions when the rule should be triggered.
    conditions: ?[]const RuleCondition = null,
    /// Indicates if the rule is disabled.
    is_disabled: ?bool = null,
    /// Name for the rule.
    name: ?[]const u8 = null,
    /// Indicates if the rule is system generated or created by user.
    customization_type: ?enums.ProcessRuleCustomizationType = null,
    /// Id to uniquely identify the rule.
    id: ?[]const u8 = null,
    /// Resource Url.
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Action to take when the rule is triggered.
pub const RuleAction = struct {
    /// Type of action to take when the rule is triggered.
    action_type: ?enums.RuleActionActionType = null,
    /// Field on which the action should be taken.
    target_field: ?[]const u8 = null,
    /// Value to apply on target field, once the action is taken.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Defines a condition on a field when the rule should be triggered.
pub const RuleCondition = struct {
    /// Type of condition. $When. This condition limits the execution of its children to cases when another field has a particular value, i.e. when the Is value of the referenced field is equal to the given literal value. $WhenNot.This condition limits the execution of its children to cases when another field does not have a particular value, i.e.when the Is value of the referenced field is not equal to the given literal value. $WhenChanged.This condition limits the execution of its children to cases when another field has changed, i.e.when the Is value of the referenced field is not equal to the Was value of that field. $WhenNotChanged.This condition limits the execution of its children to cases when another field has not changed, i.e.when the Is value of the referenced field is equal to the Was value of that field.
    condition_type: ?enums.RuleConditionConditionType = null,
    /// Field that defines condition.
    field: ?[]const u8 = null,
    /// Value of field to define the condition for rule.
    value: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Request object/class for creating a rule on a work item type.
pub const CreateProcessRuleRequest = struct {
    /// List of actions to take when the rule is triggered.
    actions: ?[]const RuleAction = null,
    /// List of conditions when the rule should be triggered.
    conditions: ?[]const RuleCondition = null,
    /// Indicates if the rule is disabled.
    is_disabled: ?bool = null,
    /// Name for the rule.
    name: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Request class/object to update the rule.
pub const UpdateProcessRuleRequest = struct {
    /// List of actions to take when the rule is triggered.
    actions: ?[]const RuleAction = null,
    /// List of conditions when the rule should be triggered.
    conditions: ?[]const RuleCondition = null,
    /// Indicates if the rule is disabled.
    is_disabled: ?bool = null,
    /// Name for the rule.
    name: ?[]const u8 = null,
    /// Id to uniquely identify the rule.
    id: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemStateResultModel` as returned by Azure DevOps.
pub const WorkItemStateResultModelList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemStateResultModel = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class That represents a work item state input.
pub const WorkItemStateInputModel = struct {
    /// Color of the state
    color: ?[]const u8 = null,
    /// Name of the state
    name: ?[]const u8 = null,
    /// Order in which state should appear
    order: ?i32 = null,
    /// Category of the state
    state_category: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Class that describes the work item state is hidden.
pub const HideStateModel = struct {
    /// Returns 'true', if workitem state is hidden, 'false' otherwise.
    hidden: ?bool = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `WorkItemTypeBehavior` as returned by Azure DevOps.
pub const WorkItemTypeBehaviorList = struct {
    count: ?i32 = null,
    value: ?[]const WorkItemTypeBehavior = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// A collection of `PickListMetadata` as returned by Azure DevOps.
pub const PickListMetadataList = struct {
    count: ?i32 = null,
    value: ?[]const PickListMetadata = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Metadata for picklist.
pub const PickListMetadata = struct {
    /// ID of the picklist
    id: ?[]const u8 = null,
    /// Indicates whether items outside of suggested list are allowed
    is_suggested: ?bool = null,
    /// Name of the picklist
    name: ?[]const u8 = null,
    /// DataType of picklist
    type: ?[]const u8 = null,
    /// Url of the picklist
    url: ?[]const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};

/// Picklist.
pub const PickList = struct {
    /// ID of the picklist
    id: ?[]const u8 = null,
    /// Indicates whether items outside of suggested list are allowed
    is_suggested: ?bool = null,
    /// Name of the picklist
    name: ?[]const u8 = null,
    /// DataType of picklist
    type: ?[]const u8 = null,
    /// Url of the picklist
    url: ?[]const u8 = null,
    /// A list of PicklistItemModel.
    items: ?[]const []const u8 = null,

    pub const serde = .{
        .rename_all = .camel_case,
    };
};
