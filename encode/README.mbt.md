# Ion encoders

`encode_text` and `encode_binary` emit deterministic, order-preserving Ion 1.0
values. Binary output includes the Ion 1.0 BVM by default and creates a local
symbol table for text symbols encountered in first-seen order.

Deterministic here means stable for this library's model and options. It is not
a claim of compatibility with an external Canonical Ion profile.
