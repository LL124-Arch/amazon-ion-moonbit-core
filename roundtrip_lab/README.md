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

The current binary fixture is written as hex so that it remains reviewable in a
source checkout. It represents an Ion version marker followed by `1`, `true`,
and the UTF-8 string `ion`.
