# Round-trip lab

This directory records the smallest repeatable checks for the Ion 1.0 text and
binary representations. The executable examples intentionally use only the
public package APIs, so they can become future compatibility smoke tests.

Suggested commands:

```text
moon check
moon test
moon run examples/tiny_read
moon run examples/tiny_write
```

## Official Ion implementation differential check

The repeatable Node.js check uses Amazon's official `amazon-ion/ion-js` package
5.2.1. It reads the checked-in binary scalar fixture, parses an annotated Ion
1.0 struct with duplicate fields and rich scalar values, writes it back to Ion
binary, reads it again, and rejects the checked-in truncated binary fixture.

```text
npm install
node ion-js-diff.mjs
```

The script intentionally checks semantic properties rather than byte-for-byte
writer output: Ion permits different valid symbol-table and length encodings.
The package is a development-time oracle only and is not a runtime dependency
of the MoonBit module.

The current binary fixture is written as hex so that it remains reviewable in a
source checkout. It represents an Ion version marker followed by `1`, `true`,
and the UTF-8 string `ion`.
