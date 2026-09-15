///|
priv struct TextParser {
  input : Bytes
  mut pos : Int
  mut line : Int
  mut column : Int
  limits : @model.Limits
  mut values : Int
  mut depth : Int
}

///|
fn TextParser::new(input : Bytes, limits : @model.Limits) -> TextParser {
  { input, pos: 0, line: 1, column: 1, limits, values: 0, depth: 0 }
}

///|
fn TextParser::parse_document(
  self : TextParser,
) -> Array[@model.IonValue] raise @model.IonError {
  let result : Array[@model.IonValue] = []
  while true {
    self.skip_space_and_comments()
    if self.pos >= self.input.length() {
      break
    }
    let value = self.parse_value()
    if !self.is_ivm(value) {
      result.push(value)
    }
  }
  result
}

///|
fn TextParser::is_ivm(_self : TextParser, value : @model.IonValue) -> Bool {
  match value {
    @model.IonValue::Symbol(symbol) =>
      symbol.text_value() is Some(text) && text == "$ion_1_0"
    _ => false
  }
}

///|
fn TextParser::parse_value(
  self : TextParser,
) -> @model.IonValue raise @model.IonError {
  self.skip_space_and_comments()
  if self.values >= self.limits.max_values() {
    raise self.limit(@model.LimitKind::Values, "value limit exceeded")
  }
  self.values += 1
  let annotations : Array[@model.IonSymbol] = []
  let mut value = self.parse_atom()
  while true {
    self.skip_space_and_comments()
    if self.peek_is(b':'.to_int()) && self.peek_at(1) is Some(b':') {
      let symbol = match value {
        @model.IonValue::Symbol(symbol) => symbol
        _ => raise self.syntax("annotation must start with a symbol")
      }
      annotations.push(symbol)
      ignore(self.advance())
      ignore(self.advance())
      value = self.parse_atom()
    } else {
      break
    }
  }
  if annotations.is_empty() {
    value
  } else {
    @model.IonValue::Annotated(annotations, value)
  }
}

///|
fn TextParser::parse_atom(
  self : TextParser,
) -> @model.IonValue raise @model.IonError {
  self.skip_space_and_comments()
  match self.peek() {
    Some(b'[') => self.parse_list()
    Some(b'(') => self.parse_sexp()
    Some(b'{') if self.peek_at(1) is Some(b'{') => self.parse_blob_or_clob()
    Some(b'{') => self.parse_struct()
    Some(b'"') => @model.IonValue::String(self.parse_quoted('"'))
    Some(b'\'') if self.is_long_quote() =>
      @model.IonValue::String(self.parse_long_quoted())
    Some(b'\'') =>
      @model.IonValue::Symbol(
        @model.IonSymbol::from_text(self.parse_quoted('\'')),
      )
    Some(b'\x00') => raise self.unexpected_eof()
    Some(_) => self.parse_token_value()
    None => raise self.unexpected_eof()
  }
}

///|
fn TextParser::parse_blob_or_clob(
  self : TextParser,
) -> @model.IonValue raise @model.IonError {
  ignore(self.advance())
  ignore(self.advance())
  self.skip_blob_whitespace()
  match self.peek() {
    Some(b'"') => {
      let text = self.parse_quoted('"')
      self.skip_blob_whitespace()
      self.expect(b'}'.to_int())
      self.expect(b'}'.to_int())
      let bytes = @utf8.encode(text)
      self.check_blob_size(bytes.length())
      @model.IonValue::Clob(bytes)
    }
    Some(b'\'') if self.is_long_quote() => {
      let text = self.parse_long_quoted()
      self.skip_blob_whitespace()
      self.expect(b'}'.to_int())
      self.expect(b'}'.to_int())
      let bytes = @utf8.encode(text)
      self.check_blob_size(bytes.length())
      @model.IonValue::Clob(bytes)
    }
    _ => {
      let buffer = @buffer.Buffer::Buffer()
      while self.peek() is Some(_) {
        if self.peek_is(b'}'.to_int()) && self.peek_at(1) is Some(b'}') {
          break
        }
        match self.peek() {
          Some(byte) if byte == b' ' ||
            byte == b'\t' ||
            byte == b'\n' ||
            byte == b'\r' => ignore(self.advance())
          Some(byte) => {
            buffer.write_byte(byte)
            ignore(self.advance())
          }
          None => break
        }
      }
      self.expect(b'}'.to_int())
      self.expect(b'}'.to_int())
      let encoded = self.decode_utf8(buffer.to_bytes()[:])
      let bytes = @base64.decode(encoded[:]) catch {
        _ => raise self.syntax("invalid blob base64")
      }
      self.check_blob_size(bytes.length())
      @model.IonValue::Blob(bytes)
    }
  }
}

///|
fn TextParser::parse_list(
  self : TextParser,
) -> @model.IonValue raise @model.IonError {
  self.enter_container()
  self.expect('['.to_int())
  let values : Array[@model.IonValue] = []
  self.skip_space_and_comments()
  if self.peek_is(']'.to_int()) {
    ignore(self.advance())
    self.leave_container()
    return @model.IonValue::List(values)
  }
  while true {
    if values.length() >= self.limits.max_container_items() {
      raise self.limit(
        @model.LimitKind::ContainerItems,
        "list item limit exceeded",
      )
    }
    values.push(self.parse_value())
    self.skip_space_and_comments()
    if self.peek_is(','.to_int()) {
      ignore(self.advance())
      self.skip_space_and_comments()
      if self.peek_is(']'.to_int()) {
        ignore(self.advance())
        break
      }
    } else if self.peek_is(']'.to_int()) {
      ignore(self.advance())
      break
    } else {
      raise self.syntax("expected ',' or ']'")
    }
  }
  self.leave_container()
  @model.IonValue::List(values)
}

///|
fn TextParser::parse_sexp(
  self : TextParser,
) -> @model.IonValue raise @model.IonError {
  self.enter_container()
  self.expect('('.to_int())
  let values : Array[@model.IonValue] = []
  while true {
    self.skip_space_and_comments()
    if self.peek_is(')'.to_int()) {
      ignore(self.advance())
      break
    }
    if self.peek() is None {
      raise self.unexpected_eof()
    }
    if values.length() >= self.limits.max_container_items() {
      raise self.limit(
        @model.LimitKind::ContainerItems,
        "sexp item limit exceeded",
      )
    }
    values.push(self.parse_value())
  }
  self.leave_container()
  @model.IonValue::Sexp(values)
}

///|
fn TextParser::parse_struct(
  self : TextParser,
) -> @model.IonValue raise @model.IonError {
  self.enter_container()
  self.expect('{'.to_int())
  let fields : Array[(@model.IonSymbol, @model.IonValue)] = []
  self.skip_space_and_comments()
  if self.peek_is('}'.to_int()) {
    ignore(self.advance())
    self.leave_container()
    return @model.IonValue::Struct(fields)
  }
  while true {
    if fields.length() >= self.limits.max_container_items() {
      raise self.limit(
        @model.LimitKind::ContainerItems,
        "struct field limit exceeded",
      )
    }
    let key = self.parse_field_symbol()
    self.skip_space_and_comments()
    self.expect(':'.to_int())
    fields.push((key, self.parse_value()))
    self.skip_space_and_comments()
    if self.peek_is(','.to_int()) {
      ignore(self.advance())
      self.skip_space_and_comments()
      if self.peek_is('}'.to_int()) {
        ignore(self.advance())
        break
      }
    } else if self.peek_is('}'.to_int()) {
      ignore(self.advance())
      break
    } else {
      raise self.syntax("expected ',' or '}'")
    }
  }
  self.leave_container()
  @model.IonValue::Struct(fields)
}

///|
fn TextParser::parse_field_symbol(
  self : TextParser,
) -> @model.IonSymbol raise @model.IonError {
  self.skip_space_and_comments()
  match self.peek() {
    Some(b'\'') if self.is_long_quote() =>
      @model.IonSymbol::from_text(self.parse_long_quoted())
    Some(b'\'') => @model.IonSymbol::from_text(self.parse_quoted('\''))
    Some(b'"') => @model.IonSymbol::from_text(self.parse_quoted('"'))
    Some(_) => {
      let token = self.read_token(stop_at_colon=true)
      if token.is_empty() {
        raise self.syntax("empty struct field name")
      }
      self.symbol_from_token(token)
    }
    None => raise self.unexpected_eof()
  }
}

///|
fn TextParser::parse_token_value(
  self : TextParser,
) -> @model.IonValue raise @model.IonError {
  let token = self.read_token(stop_at_colon=false)
  if token.is_empty() {
    raise self.syntax("expected an Ion value")
  }
  if token.has_suffix("::") {
    let annotation_text = token.sub(end=token.length() - 2).to_owned()
    let annotations : Array[@model.IonSymbol] = []
    let parts = annotation_text.split("::").to_array()
    for part_view in parts {
      let part = part_view.to_owned()
      if part.is_empty() {
        raise self.syntax("empty annotation")
      }
      annotations.push(self.symbol_from_token(part))
    }
    return @model.IonValue::Annotated(annotations, self.parse_atom())
  }
  let annotation_parts = token.split("::").to_array()
  if annotation_parts.length() > 1 {
    let annotations : Array[@model.IonSymbol] = []
    let mut index = 0
    while index < annotation_parts.length() - 1 {
      let part = annotation_parts[index].to_owned()
      if part.is_empty() {
        raise self.syntax("empty annotation")
      }
      annotations.push(self.symbol_from_token(part))
      index += 1
    }
    let value = self.parse_scalar_token(
      annotation_parts[annotation_parts.length() - 1].to_owned(),
    )
    return @model.IonValue::Annotated(annotations, value)
  }
  self.parse_scalar_token(token)
}

///|
fn TextParser::parse_scalar_token(
  self : TextParser,
  token : String,
) -> @model.IonValue raise @model.IonError {
  if token == "null" {
    return @model.IonValue::Null(@model.IonNull::Null)
  }
  if token.has_prefix("null.") {
    return @model.IonValue::Null(self.parse_null_kind(token.sub(start=5)))
  }
  if token == "true" {
    return @model.IonValue::Bool(true)
  }
  if token == "false" {
    return @model.IonValue::Bool(false)
  }
  if token == "nan" {
    return @model.IonValue::Float(@float.not_a_number)
  }
  if token == "+inf" {
    return @model.IonValue::Float(@float.infinity)
  }
  if token == "-inf" {
    return @model.IonValue::Float(@float.neg_infinity)
  }
  if self.looks_like_number(token) && self.looks_like_timestamp(token) {
    return @model.IonValue::Timestamp(self.parse_timestamp(token))
  }
  if self.looks_like_integer(token) {
    return @model.IonValue::Int(self.parse_bigint(token))
  }
  if self.looks_like_number(token) &&
    (
      token.contains_char('d') ||
      token.contains_char('D') ||
      self.has_decimal_point(token)
    ) {
    return @model.IonValue::Decimal(self.parse_decimal(token))
  }
  if self.looks_like_number(token) &&
    (token.contains_char('e') || token.contains_char('E')) {
    return @model.IonValue::Float(self.parse_double(token))
  }
  self.symbol_from_token(token) |> @model.IonValue::Symbol
}

///|
fn TextParser::symbol_from_token(
  self : TextParser,
  token : String,
) -> @model.IonSymbol raise @model.IonError {
  if token.has_prefix("$") &&
    token.length() > 1 &&
    self.all_ascii_digits(token.sub(start=1)) {
    @model.IonSymbol::from_sid(self.parse_small_int(token.sub(start=1)))
  } else {
    @model.IonSymbol::from_text(token)
  }
}

///|
fn TextParser::parse_null_kind(
  self : TextParser,
  name : StringView,
) -> @model.IonNull raise @model.IonError {
  match name.to_owned() {
    "bool" => @model.IonNull::Bool
    "int" => @model.IonNull::Int
    "float" => @model.IonNull::Float
    "decimal" => @model.IonNull::Decimal
    "timestamp" => @model.IonNull::Timestamp
    "symbol" => @model.IonNull::Symbol
    "string" => @model.IonNull::String
    "blob" => @model.IonNull::Blob
    "clob" => @model.IonNull::Clob
    "list" => @model.IonNull::List
    "sexp" => @model.IonNull::Sexp
    "struct" => @model.IonNull::Struct
    _ => raise self.syntax("unknown typed null")
  }
}

///|
fn TextParser::parse_bigint(
  self : TextParser,
  token : String,
) -> @bigint.BigInt raise @model.IonError {
  let mut body = token
  let mut negative = false
  if body.has_prefix("-") {
    negative = true
    body = body.sub(start=1).to_owned()
  } else if body.has_prefix("+") {
    body = body.sub(start=1).to_owned()
  }
  let radix = if body.has_prefix("0x") || body.has_prefix("0X") {
    body = body.sub(start=2).to_owned()
    16
  } else if body.has_prefix("0b") || body.has_prefix("0B") {
    body = body.sub(start=2).to_owned()
    2
  } else {
    10
  }
  if !valid_numeric_separators(body) {
    raise self.syntax("invalid numeric separator")
  }
  body = self.strip_numeric_separators(body)
  if body.is_empty() || !self.valid_digits(body, radix) {
    raise self.syntax("invalid integer literal")
  }
  let value = @bigint.BigInt::from_string(body, radix~)
  if negative {
    value.neg()
  } else {
    value
  }
}

///|
fn TextParser::parse_decimal(
  self : TextParser,
  token : String,
) -> @model.IonDecimal raise @model.IonError {
  let mut mantissa = token
  let mut exponent = 0
  match token.find("d") {
    Some(index) => {
      mantissa = token.sub(end=index).to_owned()
      exponent = self.parse_small_int(token.sub(start=index + 1))
    }
    None =>
      match token.find("D") {
        Some(index) => {
          mantissa = token.sub(end=index).to_owned()
          exponent = self.parse_small_int(token.sub(start=index + 1))
        }
        None => ()
      }
  }
  let mut sign = ""
  if mantissa.has_prefix("-") || mantissa.has_prefix("+") {
    sign = mantissa.sub(end=1).to_owned()
    mantissa = mantissa.sub(start=1).to_owned()
  }
  if !valid_numeric_separators(mantissa) {
    raise self.syntax("invalid numeric separator")
  }
  mantissa = self.strip_numeric_separators(mantissa)
  let mut fractional_digits = 0
  let digits = match mantissa.find(".") {
    Some(index) => {
      let left = mantissa.sub(end=index).to_owned()
      let right = mantissa.sub(start=index + 1).to_owned()
      fractional_digits = right.length()
      left + right
    }
    None => mantissa
  }
  if digits.is_empty() || !self.all_ascii_digits(digits[:]) {
    raise self.syntax("invalid decimal literal")
  }
  let mut coefficient = @bigint.BigInt::from_string(digits)
  if sign == "-" {
    coefficient = coefficient.neg()
  }
  @model.IonDecimal::new(coefficient~, exponent=exponent - fractional_digits)
}

///|
fn TextParser::parse_double(
  self : TextParser,
  token : String,
) -> Float raise @model.IonError {
  if !valid_numeric_separators(token) {
    raise self.syntax("invalid numeric separator")
  }
  let normalized = self.strip_numeric_separators(token)
  let value = @string.parse_double(normalized[:]) catch {
    _ => raise self.syntax("invalid floating-point literal")
  }
  Float::from_double(value)
}

///|
fn TextParser::parse_timestamp(
  self : TextParser,
  token : String,
) -> @model.IonTimestamp raise @model.IonError {
  let t_index = token.find("T")
  let date_end = t_index.unwrap_or(token.length())
  let date = token.sub(end=date_end).to_owned()
  let date_parts = date.split("-").to_array()
  if date_parts.length() < 1 || date_parts.length() > 3 {
    raise self.syntax("invalid timestamp date")
  }
  let year = self.parse_small_int(date_parts[0])
  let month = if date_parts.length() >= 2 {
    Some(self.parse_small_int(date_parts[1]))
  } else {
    None
  }
  let day = if date_parts.length() == 3 {
    Some(self.parse_small_int(date_parts[2]))
  } else {
    None
  }
  let rest = match t_index {
    Some(index) => token.sub(start=index + 1).to_owned()
    None => {
      if date_parts.length() != 3 {
        raise self.syntax("month and year timestamps must end with T")
      }
      return @model.IonTimestamp::new(
        year~,
        month~,
        day~,
        hour=None,
        minute=None,
        second=None,
        offset_minutes=None,
        fraction_exponent=None,
        fraction_coefficient=None,
      )
    }
  }
  if rest.is_empty() {
    return @model.IonTimestamp::new(
      year~,
      month~,
      day~,
      hour=None,
      minute=None,
      second=None,
      offset_minutes=None,
      fraction_exponent=None,
      fraction_coefficient=None,
    )
  }
  let mut time = rest
  let mut offset_minutes : Int? = None
  if time.has_suffix("Z") {
    offset_minutes = Some(0)
    time = time.sub(end=time.length() - 1).to_owned()
  } else {
    let mut split_at : Int? = None
    let mut i = time.length() - 1
    while i >= 0 {
      let c = time.get_char(i)
      if c is Some('+') || c is Some('-') {
        split_at = Some(i)
        break
      }
      i = i - 1
    }
    match split_at {
      Some(index) => {
        let sign = if time.get_char(index) == Some('-') { -1 } else { 1 }
        let part = time.sub(start=index + 1).to_owned()
        let hm = part.split(":").to_array()
        if hm.length() != 2 {
          raise self.syntax("invalid timestamp offset")
        }
        let offset = self.parse_small_int(hm[0]) * 60 +
          self.parse_small_int(hm[1])
        offset_minutes = if sign == -1 && offset == 0 {
          None
        } else {
          Some(sign * offset)
        }
        time = time.sub(end=index).to_owned()
      }
      None => ()
    }
  }
  let time_parts = time.split(":").to_array()
  if time_parts.length() != 2 && time_parts.length() != 3 {
    raise self.syntax("timestamp requires hour and minute")
  }
  let hour = self.parse_small_int(time_parts[0])
  let minute = self.parse_small_int(time_parts[1])
  let mut second : Int? = None
  let mut fraction_exponent : Int? = None
  let mut fraction_coefficient : @bigint.BigInt? = None
  if time_parts.length() == 3 {
    let seconds = time_parts[2]
    match seconds.find(".") {
      Some(index) => {
        second = Some(self.parse_small_int(seconds.sub(end=index)))
        let fraction = seconds.sub(start=index + 1).to_owned()
        if fraction.is_empty() || !self.all_ascii_digits(fraction[:]) {
          raise self.syntax("invalid timestamp fraction")
        }
        fraction_exponent = Some(-fraction.length())
        fraction_coefficient = Some(@bigint.BigInt::from_string(fraction))
      }
      None => second = Some(self.parse_small_int(seconds))
    }
  }
  @model.IonTimestamp::new(
    year~,
    month~,
    day~,
    hour=Some(hour),
    minute=Some(minute),
    second~,
    offset_minutes~,
    fraction_exponent~,
    fraction_coefficient~,
  )
}

///|
fn TextParser::parse_quoted(
  self : TextParser,
  quote : Char,
) -> String raise @model.IonError {
  self.expect(quote.to_int())
  let buffer = @buffer.Buffer::Buffer()
  while self.pos < self.input.length() {
    let byte = self.advance()
    if byte.to_int() == quote.to_int() {
      let text = self.decode_utf8(buffer.to_bytes()[:])
      self.check_text_size(@utf8.encode(text).length())
      return text
    }
    if byte == b'\\' {
      let escaped = self.advance()
      match escaped {
        b'"' => buffer.write_byte(b'"')
        b'\'' => buffer.write_byte(b'\'')
        b'\\' => buffer.write_byte(b'\\')
        b'/' => buffer.write_byte(b'/')
        b'b' => buffer.write_byte(8)
        b'f' => buffer.write_byte(12)
        b'n' => buffer.write_byte(10)
        b'r' => buffer.write_byte(13)
        b't' => buffer.write_byte(9)
        b'0' => buffer.write_byte(0)
        b'a' => buffer.write_byte(7)
        b'v' => buffer.write_byte(11)
        b'?' => buffer.write_byte(b'?')
        b'x' => {
          let code = self.read_hex_digits(2)
          match code.to_char() {
            Some(char) => buffer.write_char_utf8(char)
            None => raise self.syntax("invalid unicode escape")
          }
        }
        b'u' => {
          let code = self.read_hex_quad()
          match code.to_char() {
            Some(char) => buffer.write_char_utf8(char)
            None => raise self.syntax("invalid unicode escape")
          }
        }
        b'U' => {
          let code = self.read_hex_digits(8)
          match code.to_char() {
            Some(char) => buffer.write_char_utf8(char)
            None => raise self.syntax("invalid unicode escape")
          }
        }
        _ => raise self.syntax("invalid escape sequence")
      }
    } else {
      buffer.write_byte(byte)
    }
  }
  raise self.unexpected_eof()
}

///|
fn TextParser::parse_long_quoted(
  self : TextParser,
) -> String raise @model.IonError {
  let buffer = @buffer.Buffer::Buffer()
  while true {
    self.expect(b'\''.to_int())
    self.expect(b'\''.to_int())
    self.expect(b'\''.to_int())
    let mut closed = false
    while self.pos < self.input.length() {
      if self.is_long_quote() {
        ignore(self.advance())
        ignore(self.advance())
        ignore(self.advance())
        closed = true
        break
      }
      let byte = self.advance()
      if byte == b'\\' {
        let escaped = self.advance()
        match escaped {
          b'"' => buffer.write_byte(b'"')
          b'\'' => buffer.write_byte(b'\'')
          b'\\' => buffer.write_byte(b'\\')
          b'/' => buffer.write_byte(b'/')
          b'b' => buffer.write_byte(8)
          b'f' => buffer.write_byte(12)
          b'n' => buffer.write_byte(10)
          b'r' => buffer.write_byte(13)
          b't' => buffer.write_byte(9)
          b'0' => buffer.write_byte(0)
          b'a' => buffer.write_byte(7)
          b'v' => buffer.write_byte(11)
          b'?' => buffer.write_byte(b'?')
          b'x' => {
            let code = self.read_hex_digits(2)
            match code.to_char() {
              Some(char) => buffer.write_char_utf8(char)
              None => raise self.syntax("invalid unicode escape")
            }
          }
          b'u' => {
            let code = self.read_hex_quad()
            match code.to_char() {
              Some(char) => buffer.write_char_utf8(char)
              None => raise self.syntax("invalid unicode escape")
            }
          }
          b'U' => {
            let code = self.read_hex_digits(8)
            match code.to_char() {
              Some(char) => buffer.write_char_utf8(char)
              None => raise self.syntax("invalid unicode escape")
            }
          }
          _ => raise self.syntax("invalid escape sequence")
        }
      } else {
        buffer.write_byte(byte)
      }
    }
    if !closed {
      raise self.unexpected_eof()
    }
    self.skip_space_and_comments()
    if !self.is_long_quote() {
      break
    }
  }
  let text = self.decode_utf8(buffer.to_bytes()[:])
  self.check_text_size(@utf8.encode(text).length())
  text
}

///|
fn TextParser::read_hex_quad(self : TextParser) -> Int raise @model.IonError {
  self.read_hex_digits(4)
}

///|
fn TextParser::read_hex_digits(
  self : TextParser,
  count : Int,
) -> Int raise @model.IonError {
  let mut value = 0
  let mut index = 0
  while index < count {
    let byte = self.advance() catch { _ => raise self.unexpected_eof() }
    let digit = match byte.to_int() {
      x if x >= '0'.to_int() && x <= '9'.to_int() => x - '0'.to_int()
      x if x >= 'a'.to_int() && x <= 'f'.to_int() => x - 'a'.to_int() + 10
      x if x >= 'A'.to_int() && x <= 'F'.to_int() => x - 'A'.to_int() + 10
      _ => raise self.syntax("invalid unicode escape")
    }
    value = value * 16 + digit
    index += 1
  }
  value
}

///|
fn TextParser::read_token(
  self : TextParser,
  stop_at_colon~ : Bool,
) -> String raise @model.IonError {
  let start = self.pos
  while self.pos < self.input.length() {
    let byte = self.input[self.pos]
    let value = byte.to_int()
    if value == 9 ||
      value == 10 ||
      value == 13 ||
      value == 32 ||
      value == ','.to_int() ||
      value == ']'.to_int() ||
      value == '}'.to_int() ||
      value == ')'.to_int() ||
      value == '['.to_int() ||
      value == '{'.to_int() ||
      value == '"'.to_int() ||
      value == '\''.to_int() ||
      (stop_at_colon && value == ':'.to_int()) {
      break
    }
    ignore(self.advance())
  }
  self.decode_utf8(self.input[start:self.pos])
}

///|
fn TextParser::skip_space_and_comments(
  self : TextParser,
) -> Unit raise @model.IonError {
  while true {
    while self.peek() is Some(byte) &&
          (byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r') {
      ignore(self.advance())
    }
    if self.peek_is(b'/'.to_int()) && self.peek_at(1) is Some(b'/') {
      ignore(self.advance())
      ignore(self.advance())
      while self.peek() is Some(byte) && byte != b'\n' {
        ignore(self.advance())
      }
      continue
    }
    if self.peek_is(b'/'.to_int()) && self.peek_at(1) is Some(b'*') {
      ignore(self.advance())
      ignore(self.advance())
      let mut closed = false
      while self.peek() is Some(_) {
        if self.peek_is(b'*'.to_int()) && self.peek_at(1) is Some(b'/') {
          ignore(self.advance())
          ignore(self.advance())
          closed = true
          break
        }
        ignore(self.advance())
      }
      if !closed {
        raise self.unexpected_eof()
      }
      continue
    }
    break
  }
}

///|
fn TextParser::skip_blob_whitespace(self : TextParser) -> Unit {
  while self.peek() is Some(byte) &&
        (byte == b' ' || byte == b'\t' || byte == b'\n' || byte == b'\r') {
    ignore(self.advance() catch { _ => return })
  }
}

///|
fn TextParser::enter_container(self : TextParser) -> Unit raise @model.IonError {
  if self.depth >= self.limits.max_depth() {
    raise self.limit(@model.LimitKind::Depth, "nesting depth limit exceeded")
  }
  self.depth = self.depth + 1
}

///|
fn TextParser::leave_container(self : TextParser) -> Unit {
  self.depth = self.depth - 1
}

///|
fn TextParser::advance(self : TextParser) -> Byte raise @model.IonError {
  let byte = match self.input.get(self.pos) {
    Some(byte) => byte
    None => raise self.unexpected_eof()
  }
  self.pos = self.pos + 1
  if byte == b'\n' {
    self.line = self.line + 1
    self.column = 1
  } else {
    self.column = self.column + 1
  }
  byte
}

///|
fn TextParser::peek(self : TextParser) -> Byte? {
  self.input.get(self.pos)
}

///|
fn TextParser::peek_at(self : TextParser, delta : Int) -> Byte? {
  self.input.get(self.pos + delta)
}

///|
fn TextParser::peek_is(self : TextParser, value : Int) -> Bool {
  self.peek() is Some(byte) && byte.to_int() == value
}

///|
fn TextParser::is_long_quote(self : TextParser) -> Bool {
  self.peek_is(b'\''.to_int()) &&
  self.peek_at(1) is Some(b'\'') &&
  self.peek_at(2) is Some(b'\'')
}

///|
fn TextParser::expect(
  self : TextParser,
  value : Int,
) -> Unit raise @model.IonError {
  let byte = self.advance()
  if byte.to_int() != value {
    raise self.syntax("unexpected byte")
  }
}

///|
fn TextParser::decode_utf8(
  self : TextParser,
  bytes : BytesView,
) -> String raise @model.IonError {
  @utf8.decode(bytes) catch {
    _ =>
      raise @model.IonError::Parse(
        kind=@model.ErrorKind::InvalidUtf8,
        offset=self.pos,
        line=self.line,
        column=self.column,
        message="invalid UTF-8 text",
      )
  }
}

///|
fn TextParser::parse_small_int(
  self : TextParser,
  text : StringView,
) -> Int raise @model.IonError {
  let original = text.to_owned()
  if !valid_numeric_separators(original) {
    raise self.syntax("invalid numeric separator")
  }
  let normalized = self.strip_numeric_separators(original)
  @string.parse_int(normalized[:]) catch {
    _ => raise self.syntax("integer is outside supported range")
  }
}

///|
fn TextParser::all_ascii_digits(_self : TextParser, text : StringView) -> Bool {
  text.length() > 0 && text.all(fn(char) { char.is_ascii_digit() })
}

///|
fn TextParser::check_text_size(
  self : TextParser,
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
fn TextParser::check_blob_size(
  self : TextParser,
  size : Int,
) -> Unit raise @model.IonError {
  if size > self.limits.max_blob_bytes() {
    raise self.limit(
      @model.LimitKind::BlobBytes,
      "blob or clob value exceeds configured limit",
    )
  }
}

///|
fn TextParser::valid_digits(
  _self : TextParser,
  text : String,
  radix : Int,
) -> Bool {
  let normalized = _self.strip_numeric_separators(text)
  valid_numeric_separators(text) &&
  normalized.length() > 0 &&
  normalized.all(fn(char) {
    let value = char.to_int()
    if value >= '0'.to_int() && value <= '9'.to_int() {
      value - '0'.to_int() < radix
    } else if value >= 'a'.to_int() && value <= 'f'.to_int() {
      value - 'a'.to_int() + 10 < radix
    } else if value >= 'A'.to_int() && value <= 'F'.to_int() {
      value - 'A'.to_int() + 10 < radix
    } else {
      false
    }
  })
}

///|
fn TextParser::strip_numeric_separators(
  _self : TextParser,
  text : String,
) -> String {
  let mut result = text
  while result.contains_char('_') {
    result = result.replace(old="_", new="")
  }
  result
}

///|
fn valid_numeric_separators(text : String) -> Bool {
  !text.has_prefix("_") &&
  !text.has_suffix("_") &&
  !text.contains("__") &&
  !text.contains("_.") &&
  !text.contains("._")
}

///|
fn TextParser::looks_like_integer(self : TextParser, token : String) -> Bool {
  let body = if token.has_prefix("+") || token.has_prefix("-") {
    token.sub(start=1)
  } else {
    token[:]
  }
  if body.has_prefix("0x") || body.has_prefix("0X") {
    self.valid_digits(body.sub(start=2).to_owned(), 16)
  } else if body.has_prefix("0b") || body.has_prefix("0B") {
    self.valid_digits(body.sub(start=2).to_owned(), 2)
  } else {
    self.all_ascii_digits(body)
  }
}

///|
fn TextParser::has_decimal_point(_self : TextParser, token : String) -> Bool {
  token.contains_char('.') &&
  !token.contains_char('e') &&
  !token.contains_char('E')
}

///|
fn TextParser::looks_like_timestamp(_self : TextParser, token : String) -> Bool {
  match token.get_char(0) {
    Some(char) =>
      char.is_ascii_digit() &&
      (token.contains_char('-') || token.contains_char('T'))
    None => false
  }
}

///|
fn TextParser::looks_like_number(_self : TextParser, token : String) -> Bool {
  match token.get_char(0) {
    Some(char) => char.is_ascii_digit() || char == '+' || char == '-'
    None => false
  }
}

///|
fn TextParser::limit(
  self : TextParser,
  kind : @model.LimitKind,
  message : String,
) -> @model.IonError {
  @model.IonError::Limit(
    kind~,
    offset=self.pos,
    line=self.line,
    column=self.column,
    message~,
  )
}

///|
fn TextParser::syntax(self : TextParser, message : String) -> @model.IonError {
  @model.IonError::Parse(
    kind=@model.ErrorKind::InvalidSyntax,
    offset=self.pos,
    line=self.line,
    column=self.column,
    message~,
  )
}

///|
fn TextParser::unexpected_eof(self : TextParser) -> @model.IonError {
  @model.IonError::Parse(
    kind=@model.ErrorKind::UnexpectedEof,
    offset=self.pos,
    line=self.line,
    column=self.column,
    message="unexpected end of input",
  )
}
