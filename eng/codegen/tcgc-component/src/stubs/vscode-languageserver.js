// Stub for vscode-languageserver* — TypeSpec only uses these from
// `server/`, which we never invoke during `compile()`. We export plain
// no-op constructors / enums so any import succeeds at bundle time.
//
// If something in the compile path ever actually references one of
// these, it will return undefined and likely surface as a real error,
// at which point we add a real shim.

export const DiagnosticSeverity = {
  Error: 1, Warning: 2, Information: 3, Hint: 4,
};
export const CompletionItemKind = {};
export const MarkupKind = { PlainText: "plaintext", Markdown: "markdown" };
export const Position = {};
export const Range = {};
export const TextEdit = {};
export const TextDocument = {};
export const TextDocuments = function () {};
export const SymbolKind = {};
export const DocumentSymbol = {};
export const NotebookDocuments = function () {};

export default {
  DiagnosticSeverity, CompletionItemKind, MarkupKind,
  Position, Range, TextEdit, TextDocument, TextDocuments,
  SymbolKind, DocumentSymbol, NotebookDocuments,
};
