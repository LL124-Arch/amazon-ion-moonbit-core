# Upstream and compatibility map

## Amazon Ion 1.0

- Specification: <https://amazon-ion.github.io/ion-docs/docs/spec.html>
- Binary representation: <https://amazon-ion.github.io/ion-docs/docs/binary.html>
- Symbols and local symbol tables: <https://amazon-ion.github.io/ion-docs/docs/symbols.html>
- Official implementation index: <https://amazon-ion.github.io/ion-docs/libs.html>

The code intentionally follows the public Ion 1.0 type and binary descriptor
rules, while the public model keeps unknown annotations and symbol IDs visible.
The shared symbol table catalog, Ion Schema, Ion Hash and Ion 1.1 are reserved
for later packages so the first release does not silently invent compatibility.

## Fixture policy

The checked-in fixtures are original minimal cases. Future upstream fixtures
must include their exact source URL, version/tag, license, and any required
notice before being copied into this repository.
