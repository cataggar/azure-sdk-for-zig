//! git — generated from TypeSpec.
//!
//! Do not edit by hand. Regenerate with `codegen`.

const clients = @import("clients.zig");
pub const models = @import("models.zig");
pub const enums = @import("enums.zig");
pub const GitClient = clients.GitClient;
pub const Repositories = clients.Repositories;
pub const RefsFavorites = clients.RefsFavorites;
pub const RefsFavoritesForProject = clients.RefsFavoritesForProject;
pub const PolicyConfigurations = clients.PolicyConfigurations;
pub const PullRequests = clients.PullRequests;
pub const AnnotatedTags = clients.AnnotatedTags;
pub const Blobs = clients.Blobs;
pub const CherryPicks = clients.CherryPicks;
pub const Commits = clients.Commits;
pub const Statuses = clients.Statuses;
pub const Diffs = clients.Diffs;
pub const ImportRequests = clients.ImportRequests;
pub const Items = clients.Items;
pub const PullRequestQuery = clients.PullRequestQuery;
pub const PullRequestAttachments = clients.PullRequestAttachments;
pub const PullRequestCommits = clients.PullRequestCommits;
pub const PullRequestIterations = clients.PullRequestIterations;
pub const PullRequestIterationChanges = clients.PullRequestIterationChanges;
pub const PullRequestIterationStatuses = clients.PullRequestIterationStatuses;
pub const PullRequestLabels = clients.PullRequestLabels;
pub const PullRequestProperties = clients.PullRequestProperties;
pub const PullRequestReviewers = clients.PullRequestReviewers;
pub const PullRequestShare = clients.PullRequestShare;
pub const PullRequestStatuses = clients.PullRequestStatuses;
pub const PullRequestThreads = clients.PullRequestThreads;
pub const PullRequestThreadComments = clients.PullRequestThreadComments;
pub const PullRequestCommentLikes = clients.PullRequestCommentLikes;
pub const PullRequestWorkItems = clients.PullRequestWorkItems;
pub const Pushes = clients.Pushes;
pub const Refs = clients.Refs;
pub const Reverts = clients.Reverts;
pub const Stats = clients.Stats;
pub const Suggestions = clients.Suggestions;
pub const Trees = clients.Trees;
pub const MergeBases = clients.MergeBases;
pub const Forks = clients.Forks;
pub const Merges = clients.Merges;
