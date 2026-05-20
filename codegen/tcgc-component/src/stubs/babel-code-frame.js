// SPDX-License-Identifier: MIT
//
// Stub for @babel/code-frame.
//
// The real @babel/code-frame pulls in js-tokens, which uses Unicode
// property escapes (\p{ID_Continue}) in regular expressions that
// StarlingMonkey's SpiderMonkey embed rejects. We never need pretty
// source-context formatting inside the component (diagnostics come back
// over WIT as plain strings), so a no-op suffices.

export function codeFrameColumns(_rawLines, _loc, _opts) {
  return "";
}

export function codeFrame(_rawLines, _lineNumber, _colNumber, _opts) {
  return "";
}

export default { codeFrameColumns, codeFrame };
