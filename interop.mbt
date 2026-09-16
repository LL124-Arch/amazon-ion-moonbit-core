///|
/// Encode bytes as lowercase hexadecimal for portable binary Ion fixtures.
pub fn encode_hex(input : Bytes) -> String {
  let digits = "0123456789abcdef"
  let builder = StringBuilder::new(size_hint=input.length() * 2)
  for byte in input {
    let value = byte.to_int()
    builder.write_char(digits.get_char(value >> 4).unwrap())
    builder.write_char(digits.get_char(value & 0x0f).unwrap())
  }
  builder.to_string()
}

///|
/// Decode hexadecimal fixture text.
///
/// ASCII whitespace and `#` line comments are ignored; every remaining
/// character must be a hexadecimal digit and digits must occur in pairs.
pub fn decode_hex(input : String) -> Bytes raise @model.IonError {
  let result : Array[Byte] = []
  let mut high : Int? = None
  let mut offset = 0
  let mut line = 1
  let mut column = 1
  let mut in_comment = false
  for character in input {
    if in_comment {
      if character == '\n' {
        in_comment = false
      }
    } else if character == '#' {
      in_comment = true
    } else if character.is_ascii_whitespace() {
      ()
    } else {
      match hex_digit(character) {
        Some(digit) =>
          match high {
            Some(first) => {
              result.push(((first << 4) | digit).to_byte())
              high = None
            }
            None => high = Some(digit)
          }
        None =>
          raise hex_error(
            @model.ErrorKind::InvalidSyntax,
            offset,
            line,
            column,
            "hex fixtures may contain only hexadecimal digits, whitespace, and # comments",
          )
      }
    }
    offset += 1
    if character == '\n' {
      line += 1
      column = 1
    } else {
      column += 1
    }
  }
  match high {
    Some(_) =>
      raise hex_error(
        @model.ErrorKind::InvalidLength,
        offset,
        line,
        column,
        "hex fixtures must contain complete byte pairs",
      )
    None => Bytes::from_array(result)
  }
}

///|
fn hex_digit(character : Char) -> Int? {
  let value = character.to_int()
  if value >= '0'.to_int() && value <= '9'.to_int() {
    Some(value - '0'.to_int())
  } else if value >= 'a'.to_int() && value <= 'f'.to_int() {
    Some(value - 'a'.to_int() + 10)
  } else if value >= 'A'.to_int() && value <= 'F'.to_int() {
    Some(value - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn hex_error(
  kind : @model.ErrorKind,
  offset : Int,
  line : Int,
  column : Int,
  message : String,
) -> @model.IonError {
  @model.IonError::Parse(kind~, offset~, line~, column~, message~)
}

///|
/// Result of comparing text and binary Ion documents without normalizing them.
pub(all) struct InteropReport {
  text_values : Int
  binary_values : Int
  matches : Bool
} derive(Debug, Eq)

///|
/// Return the number of top-level values found in the text input.
pub fn InteropReport::text_value_count(self : InteropReport) -> Int {
  self.text_values
}

///|
/// Return the number of top-level values found in the binary input.
pub fn InteropReport::binary_value_count(self : InteropReport) -> Int {
  self.binary_values
}

///|
/// Report whether parsed values are exactly equal, including annotations,
/// symbols, duplicate fields, and field order.
pub fn InteropReport::matches(self : InteropReport) -> Bool {
  self.matches
}

///|
/// Parse text and binary Ion and compare their preserved value models.
pub fn diagnose_text_binary(
  text : String,
  binary : Bytes,
  limits? : @model.Limits,
) -> InteropReport raise @model.IonError {
  let limits = limits.unwrap_or(@model.Limits::default())
  let text_values = parse_text(text, limits~)
  let binary_values = parse_binary(binary, limits~)
  {
    text_values: text_values.length(),
    binary_values: binary_values.length(),
    matches: text_values == binary_values,
  }
}
