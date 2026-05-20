// Stub for is-unicode-supported.
//
// Used only by TypeSpec's dynamic-task progress reporter for picking
// Unicode glyphs. Inside the component we always pretend the terminal
// is ASCII-only.

export default function isUnicodeSupported() {
  return false;
}
