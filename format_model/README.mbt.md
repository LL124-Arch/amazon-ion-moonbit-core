# Ion value model

`IonValue` is deliberately structural. Struct fields are an ordered array of
pairs, annotations are an ordered array, and `IonSymbol` can retain an unknown
SID. This prevents a future symbol-table or Ion extension from being erased by
a convenient map-based representation.

`Limits`, `IonError`, `IonDecimal`, and `IonTimestamp` are shared by the
decoder and encoder packages.
