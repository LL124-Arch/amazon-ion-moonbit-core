# Local interoperability check

Date: 2026-09-15  
Oracle: Amazon's official `ion-js` package, version `5.2.1`  
Input: `fixtures/valid/binary-basic.hex`, interpreted as bytes
`E0 01 00 EA 21 01 11 83 69 6F 6E`.

Observed result from `ion-js`:

```text
int:1|bool:true|string:ion
```

This confirms the minimal BVM, integer, bool and UTF-8 string fixture against
one official Ion implementation. It is not a substitute for the full Ion test
suite. Before publication, extend the differential run to annotations, local
symbol tables, decimal, timestamp, clob/blob, nested containers and malformed
inputs, and preserve the exact oracle version and command output.
