// SPDX-License-Identifier: MIT
//
// Stub for `change-case`.
//
// The real `change-case` uses Unicode property escapes (`\p{Ll}`,
// `\p{Lu}`) inside regex character classes, which StarlingMonkey's
// SpiderMonkey embed rejects. We re-implement the few functions
// TypeSpec / TCGC actually call (camelCase, pascalCase, kebabCase, …)
// against ASCII semantics, which is sufficient for the identifier
// transforms in the compile path.

function splitWords(s) {
  return String(s)
    .replace(/([a-z\d])([A-Z])/g, "$1 $2")
    .replace(/([A-Z]+)([A-Z][a-z])/g, "$1 $2")
    .replace(/[_\-.]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean);
}

function up(w) {
  return w.length === 0 ? w : w[0].toUpperCase() + w.slice(1).toLowerCase();
}

export function camelCase(s) {
  const words = splitWords(s);
  if (words.length === 0) return "";
  return words[0].toLowerCase() + words.slice(1).map(up).join("");
}

export function pascalCase(s) {
  return splitWords(s).map(up).join("");
}

export function kebabCase(s) {
  return splitWords(s).map((w) => w.toLowerCase()).join("-");
}

export function snakeCase(s) {
  return splitWords(s).map((w) => w.toLowerCase()).join("_");
}

export function constantCase(s) {
  return splitWords(s).map((w) => w.toUpperCase()).join("_");
}

export function capitalCase(s) {
  return splitWords(s).map(up).join(" ");
}

export function noCase(s) {
  return splitWords(s).map((w) => w.toLowerCase()).join(" ");
}

export function dotCase(s) {
  return splitWords(s).map((w) => w.toLowerCase()).join(".");
}

export function pathCase(s) {
  return splitWords(s).map((w) => w.toLowerCase()).join("/");
}

export function pascalSnakeCase(s) {
  return splitWords(s).map(up).join("_");
}

export function sentenceCase(s) {
  const words = splitWords(s);
  if (words.length === 0) return "";
  return up(words[0]) + (words.length > 1 ? " " + words.slice(1).map((w) => w.toLowerCase()).join(" ") : "");
}

export function trainCase(s) {
  return splitWords(s).map(up).join("-");
}

export function split(s) {
  return splitWords(s);
}

export function splitSeparateNumbers(s) {
  return splitWords(s).flatMap((w) => w.split(/(\d+)/).filter(Boolean));
}

export default {
  camelCase, pascalCase, kebabCase, snakeCase, constantCase,
  capitalCase, noCase, dotCase, pathCase, pascalSnakeCase,
  sentenceCase, trainCase, split, splitSeparateNumbers,
};
