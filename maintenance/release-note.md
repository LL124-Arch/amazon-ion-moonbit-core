# Release note draft

## 0.1.0

Initial Apache-2.0 compatible Amazon Ion 1.0 core codec for MoonBit. This
release is intentionally a publication-preparation milestone, not a release
request: run the registry audit again, review compatibility and license
evidence, confirm the MoonBit account identity, and obtain human approval before
`moon publish`.

Verification includes `moon check`, `moon test`, WebAssembly and JavaScript
builds, fixture round trips, and a repeatable `ion-js` 5.2.1 differential
smoke test covering scalars, annotations, duplicate fields, decimal, timestamp,
blob/clob, nested values, binary round-trip and truncated input rejection.

The module identity is `LL124-Arch/amazon-ion-moonbit-core` and its repository
metadata points to the matching GitHub repository. Publication remains blocked
until `moon whoami` returns `LL124-Arch`; no `moon publish` command is part of
this preparation.
