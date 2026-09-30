# Local interoperability check

- Verification date: 2026-09-30
- Oracle: Amazon's official `amazon-ion/ion-js` package, version `5.2.1`
- Runner: `roundtrip_lab/ion-js-diff.mjs`
- Inputs: `fixtures/valid/binary-basic.hex`, `fixtures/valid/text-rich.ion`, and `fixtures/invalid/truncated-binary.hex`
- Command: from `roundtrip_lab`, run `npm ci` and then `node ion-js-diff.mjs`.

Observed result:

```json
{
  "oracle": "amazon-ion/ion-js",
  "version": "5.2.1",
  "checks": [
    "binary scalar fixture",
    "annotated ordered struct text parse",
    "binary round-trip",
    "truncated binary rejection"
  ],
  "result": "passed"
}
```

The comparison checks semantic structure rather than byte identity because valid
Ion writers may choose different local symbol-table and length encodings. This
is an interoperability smoke test, not a substitute for the full Ion test
suite. `ion-js` is a development-time oracle, not a MoonBit runtime dependency.
