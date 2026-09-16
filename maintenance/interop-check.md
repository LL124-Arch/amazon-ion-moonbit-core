# Local interoperability check

Date: 2026-09-16
Oracle: Amazon's official `amazon-ion/ion-js` package, version `5.2.1`
Runner: `roundtrip_lab/ion-js-diff.mjs`
Inputs: `fixtures/valid/binary-basic.hex`, `fixtures/valid/text-rich.ion`,
and `fixtures/invalid/truncated-binary.hex`.

Observed result from `ion-js`:

```text
int:1|bool:true|string:ion
```

The repeatable run also confirms an annotated ordered struct with duplicate
fields, decimal, timestamp, blob, clob and sexp values; it checks an Ion binary
round-trip and expects the truncated binary fixture to be rejected. The script
checks semantic structure rather than byte identity because valid Ion writers
may choose different local symbol-table and length encodings.

This remains an interoperability smoke test, not a substitute for the full Ion
test suite. The exact oracle version and command are kept in the repository so
the matrix can be extended without changing the runtime dependency surface.
