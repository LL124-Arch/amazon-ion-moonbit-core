///|
priv struct BinaryParser {
  data : Bytes
  mut pos : Int
  limits : @model.Limits
  mut values : Int
  mut depth : Int
  mut symbols : Array[String?]
}

///|
fn BinaryParser::new(data : Bytes, limits : @model.Limits) -> BinaryParser {
  let symbols : Array[String?] = [
    None,
    Some("$ion"),
    Some("$ion_1_0"),
    Some("$ion_symbol_table"),
    Some("name"),
    Some("version"),
    Some("imports"),
    Some("symbols"),
    Some("max_id"),
    Some("$ion_shared_symbol_table"),
  ]
  { data, pos: 0, limits, values: 0, depth: 0, symbols }
}

///|
fn BinaryParser::parse_document(
  self : BinaryParser,
) -> Array[@model.IonValue] raise @model.IonError {
  if self.data.length() < 4 {
    raise self.invalid("binary input must start with the Ion version marker")
  }
  if self.data[0] != 0xE0 ||
    self.data[1] != 0x01 ||
    self.data[2] != 0x00 ||
    self.data[3] != 0xEA {
    raise @model.IonError::UnsupportedVersion(
      major=self.data[1].to_int(),
      minor=self.data[2].to_int(),
      offset=0,
    )
  }
  self.pos = 4
  let result : Array[@model.IonValue] = []
  while self.pos < self.data.length() {
    if self.is_bvm_at_pos() {
      self.pos += 4
      self.reset_symbols()
      continue
    }
    match self.parse_value(self.data.length()) {
      Some(value) => if !self.consume_symbol_table(value) { result.push(value) }
      None => ()
    }
  }
  result
}

///|
fn BinaryParser::consume_symbol_table(
  self : BinaryParser,
  value : @model.IonValue,
) -> Bool raise @model.IonError {
  let (annotations, body) = match value {
    @model.IonValue::Annotated(annotations, body) => (annotations, body)
    _ => return false
  }
  if annotations.length() == 0 ||
    !self.is_system_symbol(annotations[0], "$ion_symbol_table", 3) {
    return false
  }
  let fields = match body {
    @model.IonValue::Struct(fields) => fields
    _ =>
      raise self.invalid("local symbol table annotation must contain a struct")
  }
  for field in fields {
    let key = field.0
    let field_value = field.1
    if self.is_system_symbol(key, "symbols", 7) {
      let entries = match field_value {
        @model.IonValue::List(entries) => entries
        _ =>
          raise self.invalid("local symbol table symbols field must be a list")
      }
      for entry in entries {
        if self.symbols.length() - 10 >= self.limits.max_symbols() {
          raise self.limit(
            @model.LimitKind::SymbolCount,
            "local symbol table limit exceeded",
          )
        }
        match entry {
          @model.IonValue::String(text) => self.symbols.push(Some(text))
          @model.IonValue::Null(_) => self.symbols.push(None)
          _ => raise self.invalid("local symbol table entries must be strings")
        }
      }
    }
  }
  true
}

///|
fn BinaryParser::is_system_symbol(
  _self : BinaryParser,
  symbol : @model.IonSymbol,
  text : String,
  sid : Int,
) -> Bool {
  match symbol.sid_value() {
    Some(value) if value == sid => true
    _ => symbol.text_value() is Some(value) && value == text
  }
}

///|
fn BinaryParser::parse_value(
  self : BinaryParser,
  bound : Int,
) -> @model.IonValue? raise @model.IonError {
  if self.pos >= bound {
    raise self.unexpected_eof()
  }
  if self.values >= self.limits.max_values() {
    raise self.limit(@model.LimitKind::Values, "value limit exceeded")
  }
  self.values += 1
  let descriptor = self.read_byte(bound)
  let type_code = descriptor.to_int() >> 4
  let length_code = descriptor.to_int() & 0x0F
  if type_code == 0 && length_code == 0 {
    return None
  }
  if type_code == 0 && length_code == 15 {
    return Some(@model.IonValue::Null(@model.IonNull::Null))
  }
  if type_code == 15 {
    raise self.invalid("reserved Ion type code")
  }
  if length_code == 15 {
    return Some(@model.IonValue::Null(null_kind(type_code)))
  }
  if type_code == 14 && length_code <= 2 {
    raise self.invalid("annotation wrapper is too short")
  }
  let length = if type_code == 13 && length_code == 1 {
    self.read_var_uint(bound)
  } else {
    self.read_length(length_code, bound)
  }
  let end = if type_code == 1 && (length_code == 0 || length_code == 1) {
    self.pos
  } else {
    self.payload_end(length, bound)
  }
  let value = match type_code {
    0 => {
      self.pos = end
      None
    }
    1 => Some(self.parse_bool(length, end))
    2 => Some(@model.IonValue::Int(self.parse_integer(end, false)))
    3 => {
      if length == 0 {
        raise self.invalid("negative zero is not a valid Ion integer")
      }
      Some(@model.IonValue::Int(self.parse_integer(end, true)))
    }
    4 => Some(@model.IonValue::Float(self.parse_float(length, end)))
    5 => Some(@model.IonValue::Decimal(self.parse_decimal(end)))
    6 => Some(@model.IonValue::Timestamp(self.parse_timestamp(end)))
    7 => Some(@model.IonValue::Symbol(self.parse_symbol(end)))
    8 => Some(@model.IonValue::String(self.parse_string(end)))
    9 =>
      Some(
        @model.IonValue::Clob(
          self.parse_bytes(
            end,
            self.limits.max_blob_bytes(),
            @model.LimitKind::BlobBytes,
          ),
        ),
      )
    10 =>
      Some(
        @model.IonValue::Blob(
          self.parse_bytes(
            end,
            self.limits.max_blob_bytes(),
            @model.LimitKind::BlobBytes,
          ),
        ),
      )
    11 => Some(@model.IonValue::List(self.parse_list(end)))
    12 => Some(@model.IonValue::Sexp(self.parse_sexp(end)))
    13 => Some(self.parse_struct(end))
    14 => Some(self.parse_annotation(end))
    _ => raise self.invalid("reserved Ion type code")
  }
  if self.pos != end {
    raise self.invalid("Ion value length does not match its payload")
  }
  value
}

///|
fn BinaryParser::parse_bool(
  self : BinaryParser,
  length : Int,
  _end : Int,
) -> @model.IonValue raise @model.IonError {
  if length == 0 {
    return @model.IonValue::Bool(false)
  }
  if length == 1 {
    return @model.IonValue::Bool(true)
  }
  raise self.invalid("invalid binary boolean")
}

///|
fn BinaryParser::parse_integer(
  self : BinaryParser,
  end : Int,
  negative : Bool,
) -> @bigint.BigInt raise @model.IonError {
  let mut value = @bigint.BigInt::from_int(0)
  while self.pos < end {
    let byte = self.read_byte(end)
    value = value
      .mul(@bigint.BigInt::from_int(256))
      .add(@bigint.BigInt::from_int(byte.to_int()))
  }
  if negative {
    value.neg()
  } else {
    value
  }
}

///|
fn BinaryParser::parse_float(
  self : BinaryParser,
  length : Int,
  end : Int,
) -> Float raise @model.IonError {
  if length == 0 {
    return 0.0
  }
  if length == 4 {
    let mut bits = 0
    while self.pos < end {
      bits = bits * 256 + self.read_byte(end).to_int()
    }
    return Float::reinterpret_from_int(bits)
  }
  if length == 8 {
    let mut bits : Int64 = Int64::from_int(0)
    while self.pos < end {
      bits = bits * Int64::from_int(256) +
        Int64::from_int(self.read_byte(end).to_int())
    }
    return Float::from_double(Int64::reinterpret_as_double(bits))
  }
  raise self.invalid("binary float must be 0, 4, or 8 bytes")
}

///|
fn BinaryParser::parse_decimal(
  self : BinaryParser,
  end : Int,
) -> @model.IonDecimal raise @model.IonError {
  if self.pos == end {
    return @model.IonDecimal::new(
      coefficient=@bigint.BigInt::from_int(0),
      exponent=0,
    )
  }
  let exponent = self.read_var_int(end).0
  let mut coefficient = @bigint.BigInt::from_int(0)
  let mut negative = false
  if self.pos < end {
    let first = self.read_byte(end).to_int()
    negative = (first & 0x80) != 0
    coefficient = @bigint.BigInt::from_int(first & 0x7F)
    while self.pos < end {
      coefficient = coefficient
        .mul(@bigint.BigInt::from_int(256))
        .add(@bigint.BigInt::from_int(self.read_byte(end).to_int()))
    }
  }
  if negative {
    coefficient = coefficient.neg()
  }
  @model.IonDecimal::new(coefficient~, exponent~)
}

///|
fn BinaryParser::parse_timestamp(
  self : BinaryParser,
  end : Int,
) -> @model.IonTimestamp raise @model.IonError {
  let offset_pair = self.read_var_int(end)
  let offset_minutes = if offset_pair.1 && offset_pair.0 == 0 {
    None
  } else {
    Some(offset_pair.0)
  }
  let year = self.read_var_uint(end)
  let month = if self.pos < end { Some(self.read_var_uint(end)) } else { None }
  let day = if self.pos < end { Some(self.read_var_uint(end)) } else { None }
  let hour = if self.pos < end { Some(self.read_var_uint(end)) } else { None }
  let minute = if self.pos < end { Some(self.read_var_uint(end)) } else { None }
  let second = if self.pos < end { Some(self.read_var_uint(end)) } else { None }
  let mut fraction_exponent : Int? = None
  let mut fraction_coefficient : @bigint.BigInt? = None
  if self.pos < end {
    fraction_exponent = Some(self.read_var_int(end).0)
    if self.pos < end {
      let first = self.read_byte(end).to_int()
      let negative = (first & 0x80) != 0
      let mut coefficient = @bigint.BigInt::from_int(first & 0x7F)
      while self.pos < end {
        coefficient = coefficient
          .mul(@bigint.BigInt::from_int(256))
          .add(@bigint.BigInt::from_int(self.read_byte(end).to_int()))
      }
      fraction_coefficient = Some(
        if negative {
          coefficient.neg()
        } else {
          coefficient
        },
      )
    }
  }
  @model.IonTimestamp::new(
    year~,
    month~,
    day~,
    hour~,
    minute~,
    second~,
    offset_minutes~,
    fraction_exponent~,
    fraction_coefficient~,
  )
}

///|
fn BinaryParser::parse_symbol(
  self : BinaryParser,
  end : Int,
) -> @model.IonSymbol raise @model.IonError {
  if self.pos == end {
    return @model.IonSymbol::from_sid(0)
  }
  let sid = self.read_var_uint(end)
  self.resolve_symbol(sid)
}

///|
fn BinaryParser::parse_string(
  self : BinaryParser,
  end : Int,
) -> String raise @model.IonError {
  self.check_text_size(end - self.pos)
  let text = @utf8.decode(self.data[self.pos:end]) catch {
    _ =>
      raise @model.IonError::Parse(
        kind=@model.ErrorKind::InvalidUtf8,
        offset=self.pos,
        line=1,
        column=1,
        message="invalid UTF-8 string",
      )
  }
  self.pos = end
  text
}

///|
fn BinaryParser::parse_bytes(
  self : BinaryParser,
  end : Int,
  max_size : Int,
  kind : @model.LimitKind,
) -> Bytes raise @model.IonError {
  let size = end - self.pos
  if size > max_size {
    raise self.limit(kind, "binary byte value exceeds configured limit")
  }
  let result = self.data[self.pos:end].to_owned()
  self.pos = end
  result
}

///|
fn BinaryParser::parse_list(
  self : BinaryParser,
  end : Int,
) -> Array[@model.IonValue] raise @model.IonError {
  self.enter_container()
  let values : Array[@model.IonValue] = []
  while self.pos < end {
    if values.length() >= self.limits.max_container_items() {
      raise self.limit(
        @model.LimitKind::ContainerItems,
        "list item limit exceeded",
      )
    }
    match self.parse_value(end) {
      Some(value) => values.push(value)
      None => ()
    }
  }
  self.leave_container()
  values
}

///|
fn BinaryParser::parse_sexp(
  self : BinaryParser,
  end : Int,
) -> Array[@model.IonValue] raise @model.IonError {
  self.enter_container()
  let values : Array[@model.IonValue] = []
  while self.pos < end {
    if values.length() >= self.limits.max_container_items() {
      raise self.limit(
        @model.LimitKind::ContainerItems,
        "sexp item limit exceeded",
      )
    }
    match self.parse_value(end) {
      Some(value) => values.push(value)
      None => ()
    }
  }
  self.leave_container()
  values
}

///|
fn BinaryParser::parse_struct(
  self : BinaryParser,
  end : Int,
) -> @model.IonValue raise @model.IonError {
  self.enter_container()
  let fields : Array[(@model.IonSymbol, @model.IonValue)] = []
  while self.pos < end {
    if fields.length() >= self.limits.max_container_items() {
      raise self.limit(
        @model.LimitKind::ContainerItems,
        "struct field limit exceeded",
      )
    }
    let sid = self.read_var_uint(end)
    match self.parse_value(end) {
      Some(value) => fields.push((self.resolve_symbol(sid), value))
      None => raise self.invalid("NOP is not valid as a struct field value")
    }
  }
  self.leave_container()
  @model.IonValue::Struct(fields)
}

///|
fn BinaryParser::parse_annotation(
  self : BinaryParser,
  end : Int,
) -> @model.IonValue raise @model.IonError {
  let annotation_size = self.read_var_uint(end)
  let annotation_end = self.payload_end(annotation_size, end)
  let annotations : Array[@model.IonSymbol] = []
  while self.pos < annotation_end {
    annotations.push(self.resolve_symbol(self.read_var_uint(annotation_end)))
  }
  let value = match self.parse_value(end) {
    Some(value) => value
    None => raise self.invalid("annotation wrapper has no value")
  }
  @model.IonValue::Annotated(annotations, value)
}

///|
fn BinaryParser::read_length(
  self : BinaryParser,
  code : Int,
  bound : Int,
) -> Int raise @model.IonError {
  if code == 14 {
    self.read_var_uint(bound)
  } else {
    code
  }
}

///|
fn BinaryParser::payload_end(
  self : BinaryParser,
  length : Int,
  bound : Int,
) -> Int raise @model.IonError {
  if length < 0 || length > self.limits.max_total_bytes() {
    raise self.limit(
      @model.LimitKind::TotalBytes,
      "binary value length exceeds configured limit",
    )
  }
  let end = self.pos + length
  if end < self.pos || end > bound || end > self.data.length() {
    raise self.unexpected_eof()
  }
  end
}

///|
fn BinaryParser::read_var_uint(
  self : BinaryParser,
  bound : Int,
) -> Int raise @model.IonError {
  let mut value = 0
  while true {
    let byte = self.read_byte(bound).to_int()
    let payload = byte & 0x7F
    if value > (self.limits.max_total_bytes() - payload) / 128 {
      raise self.invalid("VarUInt overflows the supported integer range")
    }
    value = value * 128 + payload
    if (byte & 0x80) != 0 {
      break
    }
  }
  value
}

///|
fn BinaryParser::read_var_int(
  self : BinaryParser,
  bound : Int,
) -> (Int, Bool) raise @model.IonError {
  let first = self.read_byte(bound).to_int()
  let negative = (first & 0x40) != 0
  let mut value = first & 0x3F
  if (first & 0x80) == 0 {
    while true {
      let byte = self.read_byte(bound).to_int()
      let payload = byte & 0x7F
      if value > (self.limits.max_total_bytes() - payload) / 128 {
        raise self.invalid("VarInt overflows the supported integer range")
      }
      value = value * 128 + payload
      if (byte & 0x80) != 0 {
        break
      }
    }
  }
  (if negative { -value } else { value }, negative)
}

///|
fn BinaryParser::read_byte(
  self : BinaryParser,
  bound : Int,
) -> Byte raise @model.IonError {
  if self.pos >= bound || self.pos >= self.data.length() {
    raise self.unexpected_eof()
  }
  let byte = self.data[self.pos]
  self.pos += 1
  byte
}

///|
fn BinaryParser::resolve_symbol(
  self : BinaryParser,
  sid : Int,
) -> @model.IonSymbol {
  if sid >= 0 && sid < self.symbols.length() {
    match self.symbols[sid] {
      Some(text) => @model.IonSymbol::from_text(text)
      None => @model.IonSymbol::from_sid(sid)
    }
  } else {
    @model.IonSymbol::from_sid(sid)
  }
}

///|
fn BinaryParser::reset_symbols(self : BinaryParser) -> Unit {
  self.symbols = [
    None,
    Some("$ion"),
    Some("$ion_1_0"),
    Some("$ion_symbol_table"),
    Some("name"),
    Some("version"),
    Some("imports"),
    Some("symbols"),
    Some("max_id"),
    Some("$ion_shared_symbol_table"),
  ]
}

///|
fn BinaryParser::is_bvm_at_pos(self : BinaryParser) -> Bool {
  self.pos + 4 <= self.data.length() &&
  self.data[self.pos] == 0xE0 &&
  self.data[self.pos + 1] == 0x01 &&
  self.data[self.pos + 2] == 0x00 &&
  self.data[self.pos + 3] == 0xEA
}

///|
fn BinaryParser::check_text_size(
  self : BinaryParser,
  size : Int,
) -> Unit raise @model.IonError {
  if size > self.limits.max_text_bytes() {
    raise self.limit(
      @model.LimitKind::TextBytes,
      "text value exceeds configured limit",
    )
  }
}

///|
fn BinaryParser::enter_container(
  self : BinaryParser,
) -> Unit raise @model.IonError {
  if self.depth >= self.limits.max_depth() {
    raise self.limit(@model.LimitKind::Depth, "nesting depth limit exceeded")
  }
  self.depth += 1
}

///|
fn BinaryParser::leave_container(self : BinaryParser) -> Unit {
  self.depth -= 1
}

///|
fn BinaryParser::limit(
  self : BinaryParser,
  kind : @model.LimitKind,
  message : String,
) -> @model.IonError {
  @model.IonError::Limit(kind~, offset=self.pos, line=1, column=1, message~)
}

///|
fn BinaryParser::invalid(
  self : BinaryParser,
  message : String,
) -> @model.IonError {
  @model.IonError::Parse(
    kind=@model.ErrorKind::InvalidBinary,
    offset=self.pos,
    line=1,
    column=1,
    message~,
  )
}

///|
fn BinaryParser::unexpected_eof(self : BinaryParser) -> @model.IonError {
  @model.IonError::Parse(
    kind=@model.ErrorKind::UnexpectedEof,
    offset=self.pos,
    line=1,
    column=1,
    message="unexpected end of binary input",
  )
}

///|
fn null_kind(type_code : Int) -> @model.IonNull {
  match type_code {
    1 => @model.IonNull::Bool
    2 | 3 => @model.IonNull::Int
    4 => @model.IonNull::Float
    5 => @model.IonNull::Decimal
    6 => @model.IonNull::Timestamp
    7 => @model.IonNull::Symbol
    8 => @model.IonNull::String
    9 => @model.IonNull::Clob
    10 => @model.IonNull::Blob
    11 => @model.IonNull::List
    12 => @model.IonNull::Sexp
    13 => @model.IonNull::Struct
    _ => @model.IonNull::Null
  }
}
