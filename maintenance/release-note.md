# Release note draft

## 0.1.0

Initial local implementation of an Apache-2.0 compatible Amazon Ion 1.0 core
codec for MoonBit. This release is intentionally a validation milestone, not a
publication request: run the registry audit again, review compatibility and
license evidence, and obtain human approval before `moon publish`.

Verification should include `moon check`, `moon test`, WebAssembly and
JavaScript builds, fixture round trips, and at least one official Ion
implementation as an external interoperability oracle. The minimal scalar
fixture has already been checked with Amazon's official `ion-js` 5.2.1; the
extended differential matrix remains a publication-time follow-up.
