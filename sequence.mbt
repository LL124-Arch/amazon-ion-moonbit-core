///|
/// Copy at most `length` document values beginning at the zero-based `start`.
///
/// Negative starts and non-positive lengths select an empty sequence. The input
/// values themselves are not modified.
pub fn slice_values(
  values : ArrayView[@model.IonValue],
  start : Int,
  length : Int,
) -> Array[@model.IonValue] {
  let selected : Array[@model.IonValue] = []
  if start < 0 || length <= 0 {
    return selected
  }
  for index, value in values {
    if index >= start && selected.length() < length {
      selected.push(value)
    }
  }
  selected
}

///|
/// Copy document values whose Ion type matches `kind`, preserving their order.
///
/// Type annotations do not affect the match, consistent with `IonValue::kind`.
pub fn filter_values_by_kind(
  values : ArrayView[@model.IonValue],
  kind : @model.IonNull,
) -> Array[@model.IonValue] {
  let selected : Array[@model.IonValue] = []
  for value in values {
    if value.kind() == kind {
      selected.push(value)
    }
  }
  selected
}

///|
/// Concatenate documents in their supplied order after enforcing sequence limits.
///
/// The returned document has no synthetic Ion version marker: version markers are
/// document framing and are emitted by `encode_binary` when configured. Nested
/// values are retained as supplied, while the top-level sequence is newly owned.
pub fn merge_documents(
  documents : ArrayView[Array[@model.IonValue]],
  limits? : @model.Limits,
) -> Array[@model.IonValue] raise @model.IonError {
  let limits = limits.unwrap_or(@model.Limits::default())
  let merged : Array[@model.IonValue] = []
  for document in documents {
    for value in document {
      if merged.length() >= limits.max_values() {
        raise sequence_limit_error(
          @model.LimitKind::Values,
          "merged document exceeds max_values",
        )
      }
      merged.push(value)
    }
  }
  validate_merged_limits(merged[:], limits)
  merged
}

///|
/// Parse a text document, select a bounded range of its values, and encode it.
///
/// Parsing enforces `input_limits`; encoding enforces the limits carried by
/// `options`. This deliberately works on complete, bounded documents rather than
/// presenting itself as a streaming API.
pub fn reencode_text_range(
  input : String,
  start : Int,
  length : Int,
  input_limits? : @model.Limits,
  options? : @model.EncodeOptions,
) -> String raise @model.IonError {
  let values = parse_text(
    input,
    limits=input_limits.unwrap_or(@model.Limits::default()),
  )
  let selected = slice_values(values[:], start, length)
  encode_text(
    selected[:],
    options=options.unwrap_or(@model.EncodeOptions::default()),
  )
}

///|
/// Parse a binary document, select a bounded range of its values, and encode it.
///
/// A selected binary range is written as one new Ion document, so output binary
/// version-marker emission is controlled by `options` rather than copied from the
/// input framing.
pub fn reencode_binary_range(
  input : Bytes,
  start : Int,
  length : Int,
  input_limits? : @model.Limits,
  options? : @model.EncodeOptions,
) -> Bytes raise @model.IonError {
  let values = parse_binary(
    input,
    limits=input_limits.unwrap_or(@model.Limits::default()),
  )
  let selected = slice_values(values[:], start, length)
  encode_binary(
    selected[:],
    options=options.unwrap_or(@model.EncodeOptions::default()),
  )
}

///|
fn validate_merged_limits(
  values : ArrayView[@model.IonValue],
  limits : @model.Limits,
) -> Unit raise @model.IonError {
  let stats = analyze(values)
  if stats.value_count() > limits.max_values() {
    raise sequence_limit_error(
      @model.LimitKind::Values,
      "merged document exceeds max_values",
    )
  }
  if stats.max_depth() > limits.max_depth() {
    raise sequence_limit_error(
      @model.LimitKind::Depth,
      "merged document exceeds max_depth",
    )
  }
  if stats.symbol_count() > limits.max_symbols() {
    raise sequence_limit_error(
      @model.LimitKind::SymbolCount,
      "merged document exceeds max_symbols",
    )
  }
  if stats.text_bytes > limits.max_text_bytes() {
    raise sequence_limit_error(
      @model.LimitKind::TextBytes,
      "merged document exceeds max_text_bytes",
    )
  }
  if stats.blob_bytes > limits.max_blob_bytes() {
    raise sequence_limit_error(
      @model.LimitKind::BlobBytes,
      "merged document exceeds max_blob_bytes",
    )
  }
  for value in values {
    if container_limit_exceeded(value, limits.max_container_items()) {
      raise sequence_limit_error(
        @model.LimitKind::ContainerItems,
        "merged document exceeds max_container_items",
      )
    }
  }
}

///|
fn container_limit_exceeded(value : @model.IonValue, limit : Int) -> Bool {
  match value {
    @model.IonValue::Annotated(_, nested) =>
      container_limit_exceeded(nested, limit)
    @model.IonValue::List(items) | @model.IonValue::Sexp(items) =>
      if items.length() > limit {
        true
      } else {
        for item in items {
          if container_limit_exceeded(item, limit) {
            return true
          }
        }
        false
      }
    @model.IonValue::Struct(fields) =>
      if fields.length() > limit {
        true
      } else {
        for field in fields {
          if container_limit_exceeded(field.1, limit) {
            return true
          }
        }
        false
      }
    _ => false
  }
}

///|
fn sequence_limit_error(
  kind : @model.LimitKind,
  message : String,
) -> @model.IonError {
  @model.IonError::Limit(kind~, offset=0, line=1, column=1, message~)
}
