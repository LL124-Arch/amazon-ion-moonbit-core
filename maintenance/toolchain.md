# Verification environment

- Date: 2026-09-16
- Moon toolchain: `moon 0.1.20260819 (fc2a4ee 2026-08-19)`
- CI installer: latest MoonBit toolchain observed as `moon 0.1.20260915`
- Module layout: current `moon.mod` / `moon.pkg` format
- Checked targets: native, wasm, wasm-gc, js
- Documentation: generated with `moon doc --quiet`
- CI formatting: checked with `moon fmt --check`; source is normalized to the
  CI formatter's trailing-comma style.

The generated `_build/` directory and `pkg.generated.mbti` files are ignored by
Git. Release verification should repeat these checks with the toolchain
selected for the actual publication environment.
