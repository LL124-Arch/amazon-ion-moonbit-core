///|
/// Summary information for a collection of Ion values.
pub(all) struct IonStats {
  mut value_count : Int
  mut max_depth : Int
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
/// Check the measured value, depth, symbol, text, and binary budgets.
pub fn IonStats::fits(self : IonStats, limits : @model.Limits) -> Bool {
  self.value_count <= limits.max_values() &&
  self.max_depth <= limits.max_depth() &&
  self.symbol_count <= limits.max_symbols() &&
  self.text_bytes <= limits.max_text_bytes() &&
  self.blob_bytes <= limits.max_blob_bytes()
}

///|
fn IonStats::observe(
  self : IonStats,
  value : @model.IonValue,
  depth : Int,
) -> Unit {
  match value {
    @model.IonValue::Annotated(annotations, inner) => {
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
      for child in values {
        self.observe(child, depth + 1)
      }
    }
    @model.IonValue::Struct(fields) => {
      self.record_value(depth)
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
fn IonStats::record_symbol_text(
  self : IonStats,
  symbol : @model.IonSymbol,
) -> Unit {
  match symbol.text_value() {
    Some(text) => self.text_bytes += @utf8.encode(text).length()
    None => ()
  }
}
