# Changelog

## 0.1.2 — 2026-09-30

- enforce depth, value-count, container-item, annotation, and blob-size limits
  consistently across text and binary parsing and encoding;
- correct text output for symbols represented by unresolved SIDs;
- add boundary coverage for exact limits, one-over failures, malformed binary
  framing, and NOP padding.

## 0.1.1 — 2026-09-30

- added a reproducible acceptance demo with expected example and interop output;
- documented architecture decisions, AI-assisted development, and Ion source boundaries;
- aligned the validation commands with the CI workflow.

## 0.1.0 — 2026-09-17

- aligned the module name and repository metadata with
  `LL124-Arch/amazon-ion-moonbit-core`;
- changed CI formatting verification to `moon fmt --check` and added native,
  WebAssembly, WebAssembly GC, JavaScript, and official Ion differential jobs;
- added a repeatable `amazon-ion/ion-js` 5.2.1 smoke test for scalar fixtures,
  annotated ordered structs, duplicate fields, binary round-trip, and
  truncated input rejection;
- documented the compatibility matrix, upstream references, toolchain details,
  and fixture policy for future maintenance.
