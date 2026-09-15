# Verification environment

- Date: 2026-09-15
- Moon toolchain: `moon 0.1.20260819 (fc2a4ee 2026-08-19)`
- Module layout: current `moon.mod` / `moon.pkg` format
- Checked targets: native, wasm, wasm-gc, js
- Documentation: generated with `moon doc --quiet`

The generated `_build/` directory and `pkg.generated.mbti` files are ignored by
Git. Release verification should repeat these checks with the toolchain
selected for the actual publication environment.
