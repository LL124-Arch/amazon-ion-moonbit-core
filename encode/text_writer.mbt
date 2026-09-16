///|
priv struct TextWriter {
  builder : StringBuilder
  options : @model.EncodeOptions
  mut values : Int
  mut depth : Int
}

///|
fn TextWriter::new(options : @model.EncodeOptions) -> TextWriter {
  { builder: StringBuilder::new(), options, values: 0, depth: 0 }
}

///|
fn TextWriter::write_document(
  self : TextWriter,
  values : ArrayView[@model.IonValue],
) -> String raise @model.IonError {
  let mut first = true
  for value in values {
    if !first {
      self.builder.write_char('\n')
    }
    self.write_value(value)
    first = false
  }
  let output = self.builder.to_string()
  self.options.preflight_output_size(@utf8.encode(output).length())
  output
}

///|
fn TextWriter::write_value(
  self : TextWriter,
  value : @model.IonValue,
) -> Unit raise @model.IonError {
  if self.values >= self.options.limits().max_values() {
    raise self.limit(@model.LimitKind::Values, "value limit exceeded")
  }
  self.values += 1
  match value {
    @model.IonValue::Null(kind) => self.write_null(kind)
    @model.IonValue::Bool(value) =>
      self.builder.write_string(if value { "true" } else { "false" })
    @model.IonValue::Int(value) => self.builder.write_string(value.to_string())
    @model.IonValue::Float(value) => self.write_float(value)
    @model.IonValue::Decimal(value) => self.write_decimal(value)
    @model.IonValue::Timestamp(value) => self.write_timestamp(value)
    @model.IonValue::Symbol(value) => self.write_symbol(value)
    @model.IonValue::String(value) => self.write_string(value)
    @model.IonValue::Blob(value) => self.write_blob(value)
    @model.IonValue::Clob(value) => self.write_clob(value)
    @model.IonValue::List(values) => self.write_list(values)
    @model.IonValue::Sexp(values) => self.write_sexp(values)
    @model.IonValue::Struct(fields) => self.write_struct(fields)
    @model.IonValue::Annotated(annotations, value) => {
      for annotation in annotations {
        self.write_symbol(annotation)
        self.builder.write_string("::")
      }
      self.write_value(value)
    }
  }
}

///|
fn TextWriter::write_null(self : TextWriter, kind : @model.IonNull) -> Unit {
  self.builder.write_string(
    match kind {
      @model.IonNull::Null => "null"
      @model.IonNull::Bool => "null.bool"
      @model.IonNull::Int => "null.int"
      @model.IonNull::Float => "null.float"
      @model.IonNull::Decimal => "null.decimal"
      @model.IonNull::Timestamp => "null.timestamp"
      @model.IonNull::Symbol => "null.symbol"
      @model.IonNull::String => "null.string"
      @model.IonNull::Blob => "null.blob"
      @model.IonNull::Clob => "null.clob"
      @model.IonNull::List => "null.list"
      @model.IonNull::Sexp => "null.sexp"
      @model.IonNull::Struct => "null.struct"
    },
  )
}

///|
fn TextWriter::write_float(self : TextWriter, value : Float) -> Unit {
  if value.is_nan() {
    self.builder.write_string("nan")
  } else if value.is_pos_inf() {
    self.builder.write_string("+inf")
  } else if value.is_neg_inf() {
    self.builder.write_string("-inf")
  } else {
    self.builder.write_string(value.to_string())
  }
}

///|
fn TextWriter::write_decimal(
  self : TextWriter,
  value : @model.IonDecimal,
) -> Unit {
  self.builder.write_string(value.to_ion_text())
}

///|
fn TextWriter::write_timestamp(
  self : TextWriter,
  value : @model.IonTimestamp,
) -> Unit {
  self.builder.write_string(pad_number(value.year(), 4))
  match value.month() {
    Some(month) => {
      self.builder.write_string("-")
      self.builder.write_string(pad_number(month, 2))
      match value.day() {
        Some(day) => {
          self.builder.write_string("-")
          self.builder.write_string(pad_number(day, 2))
        }
        None => ()
      }
      match value.hour() {
        Some(hour) => {
          self.builder.write_string("T")
          self.builder.write_string(pad_number(hour, 2))
          self.builder.write_string(":")
          self.builder.write_string(pad_number(value.minute().unwrap_or(0), 2))
          match value.second() {
            Some(second) => {
              self.builder.write_string(":")
              self.builder.write_string(pad_number(second, 2))
              match (value.fraction_exponent(), value.fraction_coefficient()) {
                (Some(exponent), Some(coefficient)) if exponent < 0 => {
                  let digits = coefficient.to_string()
                  let count = -exponent
                  self.builder.write_string(".")
                  let mut padding = count - digits.length()
                  while padding > 0 {
                    self.builder.write_char('0')
                    padding -= 1
                  }
                  self.builder.write_string(digits)
                }
                _ => ()
              }
            }
            None => ()
          }
          self.write_offset(value)
        }
        None => ()
      }
    }
    None => ()
  }
}

///|
fn TextWriter::write_offset(
  self : TextWriter,
  timestamp : @model.IonTimestamp,
) -> Unit {
  self.builder.write_string(timestamp.offset_text())
}

///|
fn TextWriter::write_symbol(
  self : TextWriter,
  symbol : @model.IonSymbol,
) -> Unit {
  match symbol.text_value() {
    Some(text) if is_safe_symbol(text) => self.builder.write_string(text)
    Some(text) => {
      self.builder.write_char('\'')
      self.write_escaped(text, '\'')
      self.builder.write_char('\'')
    }
    None => self.builder.write_string("${symbol.sid_value().unwrap_or(0)}")
  }
}

///|
fn TextWriter::write_string(
  self : TextWriter,
  value : String,
) -> Unit raise @model.IonError {
  if @utf8.encode(value).length() > self.options.limits().max_text_bytes() {
    raise self.limit(
      @model.LimitKind::TextBytes,
      "string value exceeds configured limit",
    )
  }
  self.builder.write_char('"')
  self.write_escaped(value, '"')
  self.builder.write_char('"')
}

///|
fn TextWriter::write_blob(
  self : TextWriter,
  value : Bytes,
) -> Unit raise @model.IonError {
  if value.length() > self.options.limits().max_blob_bytes() {
    raise self.limit(
      @model.LimitKind::BlobBytes,
      "blob value exceeds configured limit",
    )
  }
  self.builder.write_string("{{")
  self.builder.write_string(base64_encode(value))
  self.builder.write_string("}}")
}

///|
fn TextWriter::write_clob(
  self : TextWriter,
  value : Bytes,
) -> Unit raise @model.IonError {
  if value.length() > self.options.limits().max_blob_bytes() {
    raise self.limit(
      @model.LimitKind::BlobBytes,
      "clob value exceeds configured limit",
    )
  }
  let text = @utf8.decode(value[:]) catch {
    _ =>
      raise @model.IonError::Parse(
        kind=@model.ErrorKind::InvalidUtf8,
        offset=0,
        line=1,
        column=1,
        message="clob is not valid UTF-8",
      )
  }
  self.builder.write_string("{{")
  self.builder.write_char('"')
  self.write_escaped(text, '"')
  self.builder.write_string("}}")
}

///|
fn TextWriter::write_list(
  self : TextWriter,
  values : Array[@model.IonValue],
) -> Unit raise @model.IonError {
  self.enter_container()
  self.builder.write_char('[')
  if self.options.pretty() && values.length() > 0 {
    for index, value in values {
      self.builder.write_char('\n')
      self.write_indent(self.depth)
      self.write_value(value)
      if index + 1 < values.length() {
        self.builder.write_char(',')
      }
    }
    self.builder.write_char('\n')
    self.write_indent(self.depth - 1)
  } else {
    self.write_sequence(values, ',')
  }
  self.builder.write_char(']')
  self.leave_container()
}

///|
fn TextWriter::write_sexp(
  self : TextWriter,
  values : Array[@model.IonValue],
) -> Unit raise @model.IonError {
  self.enter_container()
  self.builder.write_char('(')
  if self.options.pretty() && values.length() > 0 {
    for value in values {
      self.builder.write_char('\n')
      self.write_indent(self.depth)
      self.write_value(value)
    }
    self.builder.write_char('\n')
    self.write_indent(self.depth - 1)
  } else {
    let mut first = true
    for value in values {
      if !first {
        self.builder.write_char(' ')
      }
      self.write_value(value)
      first = false
    }
  }
  self.builder.write_char(')')
  self.leave_container()
}

///|
fn TextWriter::write_struct(
  self : TextWriter,
  fields : Array[(@model.IonSymbol, @model.IonValue)],
) -> Unit raise @model.IonError {
  self.enter_container()
  self.builder.write_char('{')
  if self.options.pretty() && fields.length() > 0 {
    for index, field in fields {
      self.builder.write_char('\n')
      self.write_indent(self.depth)
      self.write_symbol(field.0)
      self.builder.write_string(": ")
      self.write_value(field.1)
      if index + 1 < fields.length() {
        self.builder.write_char(',')
      }
    }
    self.builder.write_char('\n')
    self.write_indent(self.depth - 1)
  } else {
    let mut first = true
    for field in fields {
      if !first {
        self.builder.write_string(", ")
      }
      self.write_symbol(field.0)
      self.builder.write_string(": ")
      self.write_value(field.1)
      first = false
    }
  }
  self.builder.write_char('}')
  self.leave_container()
}

///|
fn TextWriter::write_sequence(
  self : TextWriter,
  values : Array[@model.IonValue],
  separator : Char,
) -> Unit raise @model.IonError {
  let mut first = true
  for value in values {
    if !first {
      self.builder.write_char(separator)
      self.builder.write_char(' ')
    }
    self.write_value(value)
    first = false
  }
}

///|
fn TextWriter::write_indent(self : TextWriter, depth : Int) -> Unit {
  let mut spaces = depth * self.options.indent()
  while spaces > 0 {
    self.builder.write_char(' ')
    spaces -= 1
  }
}

///|
fn TextWriter::write_escaped(
  self : TextWriter,
  value : String,
  quote : Char,
) -> Unit {
  for char in value.iter() {
    match char {
      '\\' => self.builder.write_string("\\\\")
      c if c == quote => {
        self.builder.write_char('\\')
        self.builder.write_char(c)
      }
      '\n' => self.builder.write_string("\\n")
      '\r' => self.builder.write_string("\\r")
      '\t' => self.builder.write_string("\\t")
      '\b' => self.builder.write_string("\\b")
      '\f' => self.builder.write_string("\\f")
      c => self.builder.write_char(c)
    }
  }
}

///|
fn TextWriter::enter_container(self : TextWriter) -> Unit raise @model.IonError {
  if self.depth >= self.options.limits().max_depth() {
    raise self.limit(@model.LimitKind::Depth, "nesting depth limit exceeded")
  }
  self.depth += 1
}

///|
fn TextWriter::leave_container(self : TextWriter) -> Unit {
  self.depth -= 1
}

///|
fn TextWriter::limit(
  _self : TextWriter,
  kind : @model.LimitKind,
  message : String,
) -> @model.IonError {
  @model.IonError::Limit(kind~, offset=0, line=1, column=1, message~)
}

///|
fn pad_number(value : Int, width : Int) -> String {
  let text = value.to_string()
  if text.length() >= width {
    text
  } else if width == 2 && text.length() == 1 {
    "0\{text}"
  } else if width == 4 {
    if text.length() == 1 {
      "000\{text}"
    } else if text.length() == 2 {
      "00\{text}"
    } else {
      "0\{text}"
    }
  } else {
    text
  }
}

///|
fn is_safe_symbol(text : String) -> Bool {
  if text.is_empty() ||
    text == "true" ||
    text == "false" ||
    text == "null" ||
    text == "nan" ||
    text == "+inf" ||
    text == "-inf" {
    return false
  }
  if text.has_prefix("$") &&
    text.length() > 1 &&
    text.sub(start=1).all(fn(char) { char.is_ascii_digit() }) {
    return false
  }
  let starts_non_digit = match text.get_char(0) {
    Some(char) => !char.is_ascii_digit()
    None => false
  }
  text.all(fn(char) {
    let value = char.to_int()
    (value >= 'a'.to_int() && value <= 'z'.to_int()) ||
    (value >= 'A'.to_int() && value <= 'Z'.to_int()) ||
    char.is_ascii_digit() ||
    char == '_' ||
    char == '$'
  }) &&
  starts_non_digit
}

///|
fn base64_encode(value : Bytes) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  let builder = StringBuilder::new()
  let mut index = 0
  while index < value.length() {
    let a = value[index].to_int()
    let has_b = index + 1 < value.length()
    let has_c = index + 2 < value.length()
    let b = if has_b { value[index + 1].to_int() } else { 0 }
    let c = if has_c { value[index + 2].to_int() } else { 0 }
    builder.write_char(alphabet.get_char(a >> 2).unwrap())
    builder.write_char(alphabet.get_char(((a & 3) << 4) | (b >> 4)).unwrap())
    builder.write_char(
      if has_b {
        alphabet.get_char(((b & 15) << 2) | (c >> 6)).unwrap()
      } else {
        '='
      },
    )
    builder.write_char(
      if has_c {
        alphabet.get_char(c & 63).unwrap()
      } else {
        '='
      },
    )
    index += 3
  }
  builder.to_string()
}
