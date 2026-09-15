# Ion decoders

Use `parse_text` for Ion 1.0 text and `parse_binary` for an Ion binary value
stream. Both APIs accept optional resource limits and raise `IonError` with a
stable category and offset. Text errors additionally track line and column.

Binary input must begin with the Ion 1.0 BVM. Unsupported version markers,
reserved descriptors, truncated payloads and malformed local symbol tables are
rejected explicitly.
