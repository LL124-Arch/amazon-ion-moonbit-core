///|
/// Summary information for a collection of Ion values.
pub(all) struct IonStats {
  mut value_count : Int
  mut max_depth : Int
  mut max_container_items : Int
  mut symbol_count : Int
  mut text_bytes : Int
  mut blob_bytes : Int
} derive(Debug, Eq)

///|
/// Analyze value count, nesting, symbols, and payload sizes before encoding.
pub fn analyze(values : ArrayView[@model.IonValue]) -> IonStats {
  let stats = {
    value_count: 0,
    max_depth: 0,
    max_container_items: 0,
    symbol_count: 0,
    text_bytes: 0,
    blob_bytes: 0,
  }
  for value in values {
    stats.observe(value, 1)
  }
  stats
}

///|
/// Return the number of Ion values, excluding annotation wrappers.
pub fn IonStats::value_count(self : IonStats) -> Int {
  self.value_count
}

///|
/// Return the deepest structural level encountered by the analysis.
pub fn IonStats::max_depth(self : IonStats) -> Int {
  self.max_depth
}

///|
/// Return the largest element, field, or annotation count in one container.
pub fn IonStats::max_container_items(self : IonStats) -> Int {
  self.max_container_items
}

///|
/// Return the number of symbol occurrences, including field names and annotations.
pub fn IonStats::symbol_count(self : IonStats) -> Int {
  self.symbol_count
}

///|
/// Return the combined UTF-8 and blob/clob payload size in bytes.
pub fn IonStats::payload_bytes(self : IonStats) -> Int {
  self.text_bytes + self.blob_bytes
}

///|
/// Check the measured value, depth, container, symbol, text, and binary budgets.
pub fn IonStats::fits(self : IonStats, limits : @model.Limits) -> Bool {
  self.first_exceeded_limit(limits) is None
}

///|
/// Return the first measured resource budget that this document exceeds.
///
/// `TotalBytes` is intentionally omitted: the final encoded size depends on
/// text escaping, binary length encoding, and output options, and is checked
/// by the encoder after it has produced the representation.
pub fn IonStats::first_exceeded_limit(
  self : IonStats,
  limits : @model.Limits,
) -> @model.LimitKind? {
  if self.value_count > limits.max_values() {
    Some(@model.LimitKind::Values)
  } else if self.max_depth > limits.max_depth() {
    Some(@model.LimitKind::Depth)
  } else if self.max_container_items > limits.max_container_items() {
    Some(@model.LimitKind::ContainerItems)
  } else if self.symbol_count > limits.max_symbols() {
    Some(@model.LimitKind::SymbolCount)
  } else if self.text_bytes > limits.max_text_bytes() {
    Some(@model.LimitKind::TextBytes)
  } else if self.blob_bytes > limits.max_blob_bytes() {
    Some(@model.LimitKind::BlobBytes)
  } else {
    None
  }
}

///|
/// Analyze a document and reject the first measured resource budget it exceeds.
///
/// This is suitable immediately before writing an application-owned value
/// document. It preserves the `IonError::Limit` category and its `LimitKind`;
/// encoded byte size remains checked by `encode_text` or `encode_binary`.
///
/// # Example
/// ```mbt check
/// test {
///   let values = [@model.IonValue::string("ion")]
///   let stats = preflight_values(
///     values[:],
///     limits=@model.Limits::new(max_text_bytes=3),
///   )
///   assert_eq(stats.value_count(), 1)
/// }
/// ```
pub fn preflight_values(
  values : ArrayView[@model.IonValue],
  limits? : @model.Limits,
) -> IonStats raise @model.IonError {
  let stats = analyze(values)
  let limits = limits.unwrap_or(@model.Limits::default())
  match stats.first_exceeded_limit(limits) {
    Some(kind) =>
      raise @model.IonError::Limit(
        kind~,
        offset=0,
        line=1,
        column=1,
        message=preflight_limit_message(kind),
      )
    None => stats
  }
}

///|
fn IonStats::observe(
  self : IonStats,
  value : @model.IonValue,
  depth : Int,
) -> Unit {
  match value {
    @model.IonValue::Annotated(annotations, inner) => {
      self.record_container_items(annotations.length())
      self.symbol_count += annotations.length()
      for annotation in annotations {
        match annotation.text_value() {
          Some(text) => self.text_bytes += @utf8.encode(text).length()
          None => ()
        }
      }
      self.observe(inner, depth)
    }
    @model.IonValue::Symbol(symbol) => {
      self.record_value(depth)
      self.symbol_count += 1
      self.record_symbol_text(symbol)
    }
    @model.IonValue::String(text) => {
      self.record_value(depth)
      self.text_bytes += @utf8.encode(text).length()
    }
    @model.IonValue::Blob(bytes) | @model.IonValue::Clob(bytes) => {
      self.record_value(depth)
      self.blob_bytes += bytes.length()
    }
    @model.IonValue::List(values) | @model.IonValue::Sexp(values) => {
      self.record_value(depth)
      self.record_container_items(values.length())
      for child in values {
        self.observe(child, depth + 1)
      }
    }
    @model.IonValue::Struct(fields) => {
      self.record_value(depth)
      self.record_container_items(fields.length())
      for field in fields {
        self.symbol_count += 1
        self.record_symbol_text(field.0)
        self.observe(field.1, depth + 1)
      }
    }
    _ => self.record_value(depth)
  }
}

///|
fn IonStats::record_value(self : IonStats, depth : Int) -> Unit {
  self.value_count += 1
  if depth > self.max_depth {
    self.max_depth = depth
  }
}

///|
fn IonStats::record_container_items(self : IonStats, count : Int) -> Unit {
  if count > self.max_container_items {
    self.max_container_items = count
  }
}

///|
fn IonStats::record_symbol_text(
  self : IonStats,
  symbol : @model.IonSymbol,
) -> Unit {
  match symbol.text_value() {
    Some(text) => self.text_bytes += @utf8.encode(text).length()
    None => ()
  }
}

///|
fn preflight_limit_message(kind : @model.LimitKind) -> String {
  match kind {
    @model.LimitKind::Values => "document exceeds max_values"
    @model.LimitKind::Depth => "document exceeds max_depth"
    @model.LimitKind::ContainerItems => "document exceeds max_container_items"
    @model.LimitKind::TextBytes => "document exceeds max_text_bytes"
    @model.LimitKind::BlobBytes => "document exceeds max_blob_bytes"
    @model.LimitKind::SymbolCount => "document exceeds max_symbols"
    @model.LimitKind::TotalBytes => "document exceeds max_total_bytes"
  }
}
