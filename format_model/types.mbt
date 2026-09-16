///|
pub(all) enum IonNull {
  Null
  Bool
  Int
  Float
  Decimal
  Timestamp
  Symbol
  String
  Blob
  Clob
  List
  Sexp
  Struct
} derive(Debug, Eq)

///|
pub(all) struct IonSymbol {
  text : String?
  sid : Int?
} derive(Debug, Eq)

///|
pub fn IonSymbol::from_text(text : String) -> IonSymbol {
  { text: Some(text), sid: None }
}

///|
pub fn IonSymbol::from_sid(sid : Int) -> IonSymbol {
  { text: None, sid: Some(sid) }
}

///|
pub fn IonSymbol::unknown() -> IonSymbol {
  { text: None, sid: Some(0) }
}

///|
pub fn IonSymbol::text_value(self : IonSymbol) -> String? {
  self.text
}

///|
pub fn IonSymbol::sid_value(self : IonSymbol) -> Int? {
  self.sid
}

///|
pub(all) struct IonDecimal {
  coefficient : @bigint.BigInt
  exponent : Int
} derive(Debug, Eq)

///|
pub fn IonDecimal::new(
  coefficient~ : @bigint.BigInt,
  exponent~ : Int,
) -> IonDecimal {
  { coefficient, exponent }
}

///|
pub fn IonDecimal::coefficient(self : IonDecimal) -> @bigint.BigInt {
  self.coefficient
}

///|
pub fn IonDecimal::exponent(self : IonDecimal) -> Int {
  self.exponent
}

///|
pub(all) struct IonTimestamp {
  offset_minutes : Int?
  year : Int
  month : Int?
  day : Int?
  hour : Int?
  minute : Int?
  second : Int?
  fraction_exponent : Int?
  fraction_coefficient : @bigint.BigInt?
} derive(Debug, Eq)

///|
pub fn IonTimestamp::new(
  year~ : Int,
  month~ : Int?,
  day~ : Int?,
  hour~ : Int?,
  minute~ : Int?,
  second~ : Int?,
  offset_minutes~ : Int?,
  fraction_exponent~ : Int?,
  fraction_coefficient~ : @bigint.BigInt?,
) -> IonTimestamp {
  {
    offset_minutes,
    year,
    month,
    day,
    hour,
    minute,
    second,
    fraction_exponent,
    fraction_coefficient,
  }
}

///|
pub fn IonTimestamp::year(self : IonTimestamp) -> Int {
  self.year
}

///|
pub fn IonTimestamp::month(self : IonTimestamp) -> Int? {
  self.month
}

///|
pub fn IonTimestamp::day(self : IonTimestamp) -> Int? {
  self.day
}

///|
pub fn IonTimestamp::hour(self : IonTimestamp) -> Int? {
  self.hour
}

///|
pub fn IonTimestamp::minute(self : IonTimestamp) -> Int? {
  self.minute
}

///|
pub fn IonTimestamp::second(self : IonTimestamp) -> Int? {
  self.second
}

///|
pub fn IonTimestamp::offset_minutes(self : IonTimestamp) -> Int? {
  self.offset_minutes
}

///|
pub fn IonTimestamp::fraction_exponent(self : IonTimestamp) -> Int? {
  self.fraction_exponent
}

///|
pub fn IonTimestamp::fraction_coefficient(
  self : IonTimestamp,
) -> @bigint.BigInt? {
  self.fraction_coefficient
}

///|
pub(all) enum IonValue {
  Null(IonNull)
  Bool(Bool)
  Int(@bigint.BigInt)
  Float(Float)
  Decimal(IonDecimal)
  Timestamp(IonTimestamp)
  Symbol(IonSymbol)
  String(String)
  Blob(Bytes)
  Clob(Bytes)
  List(Array[IonValue])
  Sexp(Array[IonValue])
  Struct(Array[(IonSymbol, IonValue)])
  Annotated(Array[IonSymbol], IonValue)
} derive(Debug, Eq)

///|
pub fn IonValue::null(kind~ : IonNull) -> IonValue {
  Null(kind)
}

///|
pub fn IonValue::symbol(text~ : String) -> IonValue {
  Symbol(IonSymbol::from_text(text))
}

///|
pub fn IonValue::empty_struct() -> IonValue {
  Struct([])
}

///|
pub fn IonValue::empty_list() -> IonValue {
  List([])
}

///|
/// Return the Ion type of a value, ignoring any annotations around it.
pub fn IonValue::kind(self : IonValue) -> IonNull {
  match self {
    Null(kind) => kind
    Bool(_) => IonNull::Bool
    Int(_) => IonNull::Int
    Float(_) => IonNull::Float
    Decimal(_) => IonNull::Decimal
    Timestamp(_) => IonNull::Timestamp
    Symbol(_) => IonNull::Symbol
    String(_) => IonNull::String
    Blob(_) => IonNull::Blob
    Clob(_) => IonNull::Clob
    List(_) => IonNull::List
    Sexp(_) => IonNull::Sexp
    Struct(_) => IonNull::Struct
    Annotated(_, value) => value.kind()
  }
}

///|
/// Report whether a value is either a plain or typed Ion null.
pub fn IonValue::is_null(self : IonValue) -> Bool {
  match self {
    Null(_) => true
    Annotated(_, value) => value.is_null()
    _ => false
  }
}

///|
/// Return a copy of the annotations attached to a value.
pub fn IonValue::annotations(self : IonValue) -> Array[IonSymbol] {
  let result : Array[IonSymbol] = []
  match self {
    Annotated(annotations, _) =>
      for annotation in annotations {
        result.push(annotation)
      }
    _ => ()
  }
  result
}

///|
/// Attach annotations while keeping existing annotations in their original order.
pub fn IonValue::with_annotations(
  self : IonValue,
  annotations : ArrayView[IonSymbol],
) -> IonValue {
  if annotations.length() == 0 {
    return self
  }
  let combined : Array[IonSymbol] = []
  for annotation in annotations {
    combined.push(annotation)
  }
  match self {
    Annotated(existing, value) => {
      for annotation in existing {
        combined.push(annotation)
      }
      Annotated(combined, value)
    }
    _ => Annotated(combined, self)
  }
}

///|
/// Remove all annotations and return the underlying value.
pub fn IonValue::without_annotations(self : IonValue) -> IonValue {
  match self {
    Annotated(_, value) => value.without_annotations()
    _ => self
  }
}

///|
/// Return a copy of the elements in a list or s-expression.
pub fn IonValue::elements(self : IonValue) -> Array[IonValue] {
  let result : Array[IonValue] = []
  match self.without_annotations() {
    List(values) | Sexp(values) =>
      for value in values {
        result.push(value)
      }
    _ => ()
  }
  result
}

///|
/// Return a copy of the ordered fields in a struct.
pub fn IonValue::fields(self : IonValue) -> Array[(IonSymbol, IonValue)] {
  let result : Array[(IonSymbol, IonValue)] = []
  match self.without_annotations() {
    Struct(fields) =>
      for field in fields {
        result.push(field)
      }
    _ => ()
  }
  result
}

///|
/// Return the first struct field whose symbol has the requested text.
pub fn IonValue::get_field(self : IonValue, name : String) -> IonValue? {
  for field in self.fields() {
    match field.0.text_value() {
      Some(text) if text == name => return Some(field.1)
      _ => ()
    }
  }
  None
}

///|
/// Return all struct fields whose symbols have the requested text.
pub fn IonValue::get_fields(self : IonValue, name : String) -> Array[IonValue] {
  let result : Array[IonValue] = []
  for field in self.fields() {
    match field.0.text_value() {
      Some(text) if text == name => result.push(field.1)
      _ => ()
    }
  }
  result
}

///|
/// Return the underlying string when the value is a string.
pub fn IonValue::as_string(self : IonValue) -> String? {
  match self.without_annotations() {
    String(value) => Some(value)
    _ => None
  }
}

///|
/// Return the underlying boolean when the value is a boolean.
pub fn IonValue::as_bool(self : IonValue) -> Bool? {
  match self.without_annotations() {
    Bool(value) => Some(value)
    _ => None
  }
}

///|
/// Return the arbitrary-precision integer when the value is an integer.
pub fn IonValue::as_int(self : IonValue) -> @bigint.BigInt? {
  match self.without_annotations() {
    Int(value) => Some(value)
    _ => None
  }
}

///|
/// Return the decimal payload when the value is a decimal.
pub fn IonValue::as_decimal(self : IonValue) -> IonDecimal? {
  match self.without_annotations() {
    Decimal(value) => Some(value)
    _ => None
  }
}

///|
/// Return the timestamp payload when the value is a timestamp.
pub fn IonValue::as_timestamp(self : IonValue) -> IonTimestamp? {
  match self.without_annotations() {
    Timestamp(value) => Some(value)
    _ => None
  }
}

///|
pub(all) enum LimitKind {
  TotalBytes
  Depth
  Values
  ContainerItems
  TextBytes
  BlobBytes
  SymbolCount
} derive(Debug, Eq)

///|
pub(all) enum ErrorKind {
  UnexpectedEof
  InvalidSyntax
  InvalidBinary
  InvalidUtf8
  InvalidNumber
  InvalidTimestamp
  InvalidSymbol
  InvalidLength
  UnsupportedVersion
  LimitExceeded
} derive(Debug, Eq)

///|
pub(all) suberror IonError {
  Parse(
    kind~ : ErrorKind,
    offset~ : Int,
    line~ : Int,
    column~ : Int,
    message~ : String
  )
  Limit(
    kind~ : LimitKind,
    offset~ : Int,
    line~ : Int,
    column~ : Int,
    message~ : String
  )
  UnsupportedVersion(major~ : Int, minor~ : Int, offset~ : Int)
} derive(Debug)

///|
pub fn IonError::kind(self : IonError) -> ErrorKind {
  match self {
    Parse(kind~, ..) => kind
    Limit(..) => ErrorKind::LimitExceeded
    UnsupportedVersion(..) => ErrorKind::UnsupportedVersion
  }
}

///|
pub fn IonError::offset(self : IonError) -> Int {
  match self {
    Parse(offset~, ..) => offset
    Limit(offset~, ..) => offset
    UnsupportedVersion(offset~, ..) => offset
  }
}

///|
pub fn IonError::line(self : IonError) -> Int {
  match self {
    Parse(line~, ..) => line
    Limit(line~, ..) => line
    UnsupportedVersion(..) => 1
  }
}

///|
pub fn IonError::column(self : IonError) -> Int {
  match self {
    Parse(column~, ..) => column
    Limit(column~, ..) => column
    UnsupportedVersion(..) => 1
  }
}

///|
pub fn IonError::message(self : IonError) -> String {
  match self {
    Parse(message~, ..) => message
    Limit(message~, ..) => message
    UnsupportedVersion(major~, minor~, ..) =>
      "unsupported Ion version \{major}.\{minor}"
  }
}

///|
pub(all) struct Limits {
  max_depth : Int
  max_values : Int
  max_container_items : Int
  max_text_bytes : Int
  max_blob_bytes : Int
  max_total_bytes : Int
  max_symbols : Int
} derive(Debug, Eq)

///|
pub fn Limits::default() -> Limits {
  {
    max_depth: 64,
    max_values: 100000,
    max_container_items: 100000,
    max_text_bytes: 16 * 1024 * 1024,
    max_blob_bytes: 64 * 1024 * 1024,
    max_total_bytes: 128 * 1024 * 1024,
    max_symbols: 100000,
  }
}

///|
pub fn Limits::new(
  max_depth? : Int = 64,
  max_values? : Int = 100000,
  max_container_items? : Int = 100000,
  max_text_bytes? : Int = 16 * 1024 * 1024,
  max_blob_bytes? : Int = 64 * 1024 * 1024,
  max_total_bytes? : Int = 128 * 1024 * 1024,
  max_symbols? : Int = 100000,
) -> Limits {
  {
    max_depth,
    max_values,
    max_container_items,
    max_text_bytes,
    max_blob_bytes,
    max_total_bytes,
    max_symbols,
  }
}

///|
pub fn Limits::max_depth(self : Limits) -> Int {
  self.max_depth
}

///|
pub fn Limits::max_values(self : Limits) -> Int {
  self.max_values
}

///|
pub fn Limits::max_container_items(self : Limits) -> Int {
  self.max_container_items
}

///|
pub fn Limits::max_text_bytes(self : Limits) -> Int {
  self.max_text_bytes
}

///|
pub fn Limits::max_blob_bytes(self : Limits) -> Int {
  self.max_blob_bytes
}

///|
pub fn Limits::max_total_bytes(self : Limits) -> Int {
  self.max_total_bytes
}

///|
pub fn Limits::max_symbols(self : Limits) -> Int {
  self.max_symbols
}

///|
pub(all) struct EncodeOptions {
  pretty : Bool
  indent : Int
  emit_bvm : Bool
  limits : Limits
} derive(Debug)

///|
pub fn EncodeOptions::default() -> EncodeOptions {
  { pretty: false, indent: 2, emit_bvm: true, limits: Limits::default() }
}

///|
pub fn EncodeOptions::new(
  pretty? : Bool = false,
  indent? : Int = 2,
  emit_bvm? : Bool = true,
  limits? : Limits = Limits::default(),
) -> EncodeOptions {
  { pretty, indent, emit_bvm, limits }
}

///|
pub fn EncodeOptions::pretty(self : EncodeOptions) -> Bool {
  self.pretty
}

///|
pub fn EncodeOptions::indent(self : EncodeOptions) -> Int {
  self.indent
}

///|
pub fn EncodeOptions::emit_bvm(self : EncodeOptions) -> Bool {
  self.emit_bvm
}

///|
pub fn EncodeOptions::limits(self : EncodeOptions) -> Limits {
  self.limits
}
