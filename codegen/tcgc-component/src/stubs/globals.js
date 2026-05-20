// SPDX-License-Identifier: MIT
//
// Minimal globals to satisfy libraries that probe for capabilities
// StarlingMonkey doesn't ship (Intl, etc.).
//
// We intentionally provide near-empty implementations so feature
// detection paths fall back to ASCII / UTC behaviour. Anything that
// actually CALLS these (rather than detecting them) will throw.

const stubFn = () => {
  throw new Error("stub: Intl/* not available inside the wasm component");
};

class StubFormatter {
  constructor() {}
  format() { return ""; }
  formatToParts() { return []; }
  resolvedOptions() { return {}; }
}

if (typeof globalThis.Intl === "undefined") {
  globalThis.Intl = {
    Collator: StubFormatter,
    DateTimeFormat: StubFormatter,
    NumberFormat: StubFormatter,
    PluralRules: StubFormatter,
    RelativeTimeFormat: StubFormatter,
    Locale: function () { return { baseName: "en", maximize() { return this; }, minimize() { return this; } }; },
    getCanonicalLocales: (l) => Array.isArray(l) ? l : [l ?? "en"],
    supportedValuesOf: () => [],
    Segmenter: StubFormatter,
    DisplayNames: StubFormatter,
    ListFormat: StubFormatter,
  };
}
