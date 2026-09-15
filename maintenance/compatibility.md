# Compatibility matrix

| Capability | Current status | Notes |
| --- | --- | --- |
| Ion 1.0 text | implemented | Scalars, containers, annotations, comments and typed nulls |
| Ion 1.0 binary | implemented | BVM, descriptors, VarUInt/VarInt, containers and local symbol table |
| Native | locally checked | Run `moon check --target native` when the installed toolchain exposes it |
| WebAssembly | locally checked | Stable target for CI and release smoke tests |
| JavaScript | locally checked | Stable target for release smoke tests |
| Ion 1.1 | not implemented | Explicitly rejected with version/error boundary |
| Shared symbol catalog | not implemented | Local symbol table only |
| Ion Schema / Ion Hash | not implemented | Separate future packages |
| Streaming / zero-copy / compression | not implemented | Deliberately outside the first API |
