///|
priv struct BinaryWriter {
  buffer : @buffer.Buffer
  options : @model.EncodeOptions
  mut values : Int
  mut depth : Int
  symbols : Array[String]
}

///|
fn BinaryWriter::new(options : @model.EncodeOptions) -> BinaryWriter {
  {
    buffer: @buffer.Buffer::Buffer(),
    options,
    values: 0,
    depth: 0,
    symbols: [],
  }
}

///|
fn BinaryWriter::write_document(
  self : BinaryWriter,
  values : ArrayView[@model.IonValue],
) -> Bytes raise @model.IonError {
  self.collect_symbols(values)
  if self.options.emit_bvm() {
    self.buffer.write_bytes(b"\xE0\x01\x00\xEA")
  }
  if self.symbols.length() > 0 {
    self.write_local_symbol_table()
  }
  for value in values {
    self.write_value_to(self.buffer, value)
  }
  self.buffer.to_bytes()
}

///|
fn BinaryWriter::collect_symbols(
  self : BinaryWriter,
  values : ArrayView[@model.IonValue],
) -> Unit raise @model.IonError {
  for value in values {
    self.collect_symbol_value(value)
  }
}

///|
fn BinaryWriter::collect_symbol_value(
  self : BinaryWriter,
  value : @model.IonValue,
) -> Unit raise @model.IonError {
  match value {
    @model.IonValue::Symbol(symbol) => self.collect_symbol(symbol)
    @model.IonValue::Annotated(annotations, value) => {
      for symbol in annotations {
        self.collect_symbol(symbol)
      }
      self.collect_symbol_value(value)
    }
    @model.IonValue::List(values) | @model.IonValue::Sexp(values) =>
      for item in values {
        self.collect_symbol_value(item)
      }
    @model.IonValue::Struct(fields) =>
      for field in fields {
        self.collect_symbol(field.0)
        self.collect_symbol_value(field.1)
      }
    _ => ()
  }
}

///|
fn BinaryWriter::collect_symbol(
  self : BinaryWriter,
  symbol : @model.IonSymbol,
) -> Unit raise @model.IonError {
  match symbol.text_value() {
    Some(text) if system_sid(text) is Some(_) => ()
    Some(text) => {
      let mut found = false
      for existing in self.symbols {
        if existing == text {
          found = true
        }
      }
      if !found {
        if self.symbols.length() >= self.options.limits().max_symbols() {
          raise self.limit(
            @model.LimitKind::SymbolCount,
            "local symbol table limit exceeded",
          )
        }
        self.symbols.push(text)
      }
    }
    None => ()
  }
}

///|
fn BinaryWriter::write_local_symbol_table(
  self : BinaryWriter,
) -> Unit raise @model.IonError {
  let list_payload = @buffer.Buffer::Buffer()
  for text in self.symbols {
    let bytes = @utf8.encode(text)
    if bytes.length() > self.options.limits().max_text_bytes() {
      raise self.limit(
        @model.LimitKind::TextBytes,
        "symbol value exceeds configured limit",
      )
    }
    write_tlv(list_payload, 8, bytes)
  }
  let list = @buffer.Buffer::Buffer()
  write_tlv(list, 11, list_payload.to_bytes())

  let struct_payload = @buffer.Buffer::Buffer()
  write_var_uint(struct_payload, 7)
  struct_payload.write_bytes(list.to_bytes()[:])
  let struct_value = @buffer.Buffer::Buffer()
  write_tlv(struct_value, 13, struct_payload.to_bytes())

  let annotation_payload = @buffer.Buffer::Buffer()
  write_var_uint(annotation_payload, 1)
  write_var_uint(annotation_payload, 3)
  annotation_payload.write_bytes(struct_value.to_bytes()[:])
  write_tlv(self.buffer, 14, annotation_payload.to_bytes())
}

///|
fn BinaryWriter::write_value_to(
  self : BinaryWriter,
  output : @buffer.Buffer,
  value : @model.IonValue,
) -> Unit raise @model.IonError {
  if self.values >= self.options.limits().max_values() {
    raise self.limit(@model.LimitKind::Values, "value limit exceeded")
  }
  self.values += 1
  match value {
    @model.IonValue::Null(kind) =>
      output.write_byte(((null_type(kind) << 4) | 15).to_byte())
    @model.IonValue::Bool(value) =>
      output.write_byte(if value { 0x11 } else { 0x10 })
    @model.IonValue::Int(value) => self.write_integer(output, value)
    @model.IonValue::Float(value) => self.write_float(output, value)
    @model.IonValue::Decimal(value) => self.write_decimal(output, value)
    @model.IonValue::Timestamp(value) => self.write_timestamp(output, value)
    @model.IonValue::Symbol(value) => {
      let payload = @buffer.Buffer::Buffer()
      write_var_uint(payload, self.symbol_sid(value))
      write_tlv(output, 7, payload.to_bytes())
    }
    @model.IonValue::String(value) => self.write_string(output, value)
    @model.IonValue::Blob(value) => self.write_blob(output, 10, value)
    @model.IonValue::Clob(value) => self.write_blob(output, 9, value)
    @model.IonValue::List(values) => self.write_container(output, 11, values)
    @model.IonValue::Sexp(values) => self.write_container(output, 12, values)
    @model.IonValue::Struct(fields) => self.write_struct(output, fields)
    @model.IonValue::Annotated(annotations, value) =>
      self.write_annotated(output, annotations, value)
  }
}

///|
fn BinaryWriter::write_integer(
  _self : BinaryWriter,
  output : @buffer.Buffer,
  value : @bigint.BigInt,
) -> Unit {
  let text = value.to_string()
  if text == "0" {
    output.write_byte(0x20)
    return
  }
  let negative = text.has_prefix("-")
  let digits = if negative { text.sub(start=1).to_owned() } else { text }
  let magnitude = @bigint.BigInt::from_string(digits)
  write_tlv(output, if negative { 3 } else { 2 }, magnitude.to_octets())
}

///|
fn BinaryWriter::write_float(
  _self : BinaryWriter,
  output : @buffer.Buffer,
  value : Float,
) -> Unit {
  let bits = value.reinterpret_as_int()
  let payload = @buffer.Buffer::Buffer()
  payload.write_byte((bits >> 24).to_byte())
  payload.write_byte((bits >> 16).to_byte())
  payload.write_byte((bits >> 8).to_byte())
  payload.write_byte(bits.to_byte())
  write_tlv(output, 4, payload.to_bytes())
}

///|
fn BinaryWriter::write_decimal(
  _self : BinaryWriter,
  output : @buffer.Buffer,
  value : @model.IonDecimal,
) -> Unit {
  let payload = @buffer.Buffer::Buffer()
  write_var_int(payload, value.exponent(), negative=value.exponent() < 0)
  let text = value.coefficient().to_string()
  let negative = text.has_prefix("-")
  let digits = if negative { text.sub(start=1).to_owned() } else { text }
  let magnitude = @bigint.BigInt::from_string(digits)
  let octets = magnitude.to_octets()
  if text == "0" {
    payload.write_byte(if negative { 0x80 } else { 0 })
  } else {
    let sign_bit = if negative { 0x80 } else { 0 }
    payload.write_byte((octets[0].to_int() | sign_bit).to_byte())
    if octets.length() > 1 {
      payload.write_bytes(octets[1:])
    }
  }
  write_tlv(output, 5, payload.to_bytes())
}

///|
fn BinaryWriter::write_timestamp(
  self : BinaryWriter,
  output : @buffer.Buffer,
  value : @model.IonTimestamp,
) -> Unit {
  let payload = @buffer.Buffer::Buffer()
  match value.offset_minutes() {
    None => write_var_int(payload, 0, negative=true)
    Some(offset) => write_var_int(payload, offset, negative=offset < 0)
  }
  write_var_uint(payload, value.year())
  self.write_optional_uint(payload, value.month())
  self.write_optional_uint(payload, value.day())
  self.write_optional_uint(payload, value.hour())
  self.write_optional_uint(payload, value.minute())
  self.write_optional_uint(payload, value.second())
  match (value.fraction_exponent(), value.fraction_coefficient()) {
    (Some(exponent), Some(coefficient)) => {
      write_var_int(payload, exponent, negative=exponent < 0)
      let text = coefficient.to_string()
      let negative = text.has_prefix("-")
      let digits = if negative { text.sub(start=1).to_owned() } else { text }
      let octets = @bigint.BigInt::from_string(digits).to_octets()
      let sign_bit = if negative { 0x80 } else { 0 }
      payload.write_byte((octets[0].to_int() | sign_bit).to_byte())
      if octets.length() > 1 {
        payload.write_bytes(octets[1:])
      }
    }
    _ => ()
  }
  write_tlv(output, 6, payload.to_bytes())
}

///|
fn BinaryWriter::write_optional_uint(
  _self : BinaryWriter,
  output : @buffer.Buffer,
  value : Int?,
) -> Unit {
  match value {
    Some(value) => write_var_uint(output, value)
    None => ()
  }
}

///|
fn BinaryWriter::write_string(
  self : BinaryWriter,
  output : @buffer.Buffer,
  value : String,
) -> Unit raise @model.IonError {
  let bytes = @utf8.encode(value)
  if bytes.length() > self.options.limits().max_text_bytes() {
    raise self.limit(
      @model.LimitKind::TextBytes,
      "string value exceeds configured limit",
    )
  }
  write_tlv(output, 8, bytes)
}

///|
fn BinaryWriter::write_blob(
  self : BinaryWriter,
  output : @buffer.Buffer,
  type_code : Int,
  value : Bytes,
) -> Unit raise @model.IonError {
  if value.length() > self.options.limits().max_blob_bytes() {
    raise self.limit(
      @model.LimitKind::BlobBytes,
      "blob or clob value exceeds configured limit",
    )
  }
  write_tlv(output, type_code, value)
}

///|
fn BinaryWriter::write_container(
  self : BinaryWriter,
  output : @buffer.Buffer,
  type_code : Int,
  values : Array[@model.IonValue],
) -> Unit raise @model.IonError {
  self.enter_container()
  if values.length() > self.options.limits().max_container_items() {
    raise self.limit(
      @model.LimitKind::ContainerItems,
      "container item limit exceeded",
    )
  }
  let payload = @buffer.Buffer::Buffer()
  for value in values {
    self.write_value_to(payload, value)
  }
  write_tlv(output, type_code, payload.to_bytes())
  self.leave_container()
}

///|
fn BinaryWriter::write_struct(
  self : BinaryWriter,
  output : @buffer.Buffer,
  fields : Array[(@model.IonSymbol, @model.IonValue)],
) -> Unit raise @model.IonError {
  self.enter_container()
  if fields.length() > self.options.limits().max_container_items() {
    raise self.limit(
      @model.LimitKind::ContainerItems,
      "struct field limit exceeded",
    )
  }
  let payload = @buffer.Buffer::Buffer()
  for field in fields {
    write_var_uint(payload, self.symbol_sid(field.0))
    self.write_value_to(payload, field.1)
  }
  write_tlv(output, 13, payload.to_bytes())
  self.leave_container()
}

///|
fn BinaryWriter::write_annotated(
  self : BinaryWriter,
  output : @buffer.Buffer,
  annotations : Array[@model.IonSymbol],
  value : @model.IonValue,
) -> Unit raise @model.IonError {
  if annotations.length() > self.options.limits().max_container_items() {
    raise self.limit(
      @model.LimitKind::ContainerItems,
      "annotation count limit exceeded",
    )
  }
  let annotation_bytes = @buffer.Buffer::Buffer()
  for annotation in annotations {
    write_var_uint(annotation_bytes, self.symbol_sid(annotation))
  }
  let payload = @buffer.Buffer::Buffer()
  write_var_uint(payload, annotation_bytes.to_bytes().length())
  payload.write_bytes(annotation_bytes.to_bytes()[:])
  self.write_value_to(payload, value)
  write_tlv(output, 14, payload.to_bytes())
}

///|
fn BinaryWriter::symbol_sid(
  self : BinaryWriter,
  symbol : @model.IonSymbol,
) -> Int {
  match symbol.text_value() {
    Some(text) =>
      match system_sid(text) {
        Some(sid) => sid
        None => {
          let mut index = 0
          for existing in self.symbols {
            if existing == text {
              return 10 + index
            }
            index += 1
          }
          symbol.sid_value().unwrap_or(0)
        }
      }
    None => symbol.sid_value().unwrap_or(0)
  }
}

///|
fn BinaryWriter::enter_container(
  self : BinaryWriter,
) -> Unit raise @model.IonError {
  if self.depth >= self.options.limits().max_depth() {
    raise self.limit(@model.LimitKind::Depth, "nesting depth limit exceeded")
  }
  self.depth += 1
}

///|
fn BinaryWriter::leave_container(self : BinaryWriter) -> Unit {
  self.depth -= 1
}

///|
fn BinaryWriter::limit(
  _self : BinaryWriter,
  kind : @model.LimitKind,
  message : String,
) -> @model.IonError {
  @model.IonError::Limit(kind~, offset=0, line=1, column=1, message~)
}

///|
fn system_sid(text : String) -> Int? {
  match text {
    "$ion" => Some(1)
    "$ion_1_0" => Some(2)
    "$ion_symbol_table" => Some(3)
    "name" => Some(4)
    "version" => Some(5)
    "imports" => Some(6)
    "symbols" => Some(7)
    "max_id" => Some(8)
    "$ion_shared_symbol_table" => Some(9)
    _ => None
  }
}

///|
fn null_type(kind : @model.IonNull) -> Int {
  match kind {
    @model.IonNull::Null => 0
    @model.IonNull::Bool => 1
    @model.IonNull::Int => 2
    @model.IonNull::Float => 4
    @model.IonNull::Decimal => 5
    @model.IonNull::Timestamp => 6
    @model.IonNull::Symbol => 7
    @model.IonNull::String => 8
    @model.IonNull::Clob => 9
    @model.IonNull::Blob => 10
    @model.IonNull::List => 11
    @model.IonNull::Sexp => 12
    @model.IonNull::Struct => 13
  }
}

///|
fn write_tlv(output : @buffer.Buffer, type_code : Int, payload : Bytes) -> Unit {
  let length = payload.length()
  if length < 14 && !(type_code == 13 && length == 1) {
    output.write_byte(((type_code << 4) | length).to_byte())
  } else {
    output.write_byte(((type_code << 4) | 14).to_byte())
    write_var_uint(output, length)
  }
  if length > 0 {
    output.write_bytes(payload[:])
  }
}

///|
fn write_var_uint(output : @buffer.Buffer, value : Int) -> Unit {
  let mut n = if value < 0 { 0 } else { value }
  let digits : Array[Byte] = []
  while n >= 128 {
    digits.push((n & 127).to_byte())
    n /= 128
  }
  digits.push(n.to_byte())
  let mut index = digits.length() - 1
  while index >= 0 {
    let digit = digits[index].to_int()
    if index == 0 {
      output.write_byte((digit | 128).to_byte())
    } else {
      output.write_byte(digit.to_byte())
    }
    index -= 1
  }
}

///|
fn write_var_int(
  output : @buffer.Buffer,
  value : Int,
  negative~ : Bool,
) -> Unit {
  let mut magnitude = if value < 0 { -value } else { value }
  if magnitude < 64 {
    let sign_bit = if negative { 0x40 } else { 0 }
    output.write_byte((0x80 | sign_bit | magnitude).to_byte())
    return
  }
  let digits : Array[Byte] = []
  while magnitude >= 64 {
    digits.push((magnitude & 127).to_byte())
    magnitude /= 128
  }
  let sign_bit = if negative { 0x40 } else { 0 }
  output.write_byte((sign_bit | magnitude).to_byte())
  let mut index = digits.length() - 1
  while index >= 0 {
    let digit = digits[index]
    output.write_byte(
      if index == 0 {
        (digit.to_int() | 0x80).to_byte()
      } else {
        digit
      },
    )
    index -= 1
  }
}
