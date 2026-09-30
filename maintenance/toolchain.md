# Verification environment

- Local verification date: 2026-09-30
- MoonBit CLI: `moon 0.1.20260920`; compiler: `moonc v0.10.14+7d59c7ec9`
- Node.js: `v26.2.0`; npm: `11.13.0`; interoperability oracle: `ion-js 5.2.1`
- Passed locally: `moon fmt --check`; `moon check` (193 warnings, 0 errors); 43 tests on each of the default, native, wasm, wasm-gc, and js targets; native/wasm/js builds; and the `roundtrip_lab` differential check.
- MoonBit commands exit successfully while emitting existing deprecation and convention warnings. The workflow does not deny warnings.
- The `verify` GitHub Actions workflow passed for source commit `bd067e506b9177c2510f851a0308a53c026ea5c6` on 2026-09-30.

The generated `_build/` directory and `pkg.generated.mbti` files are ignored by
Git. Recheck the toolchain and CI result when cutting a release.
