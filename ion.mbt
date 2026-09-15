///|
pub fn parse_text(
  input : String,
  limits? : @model.Limits,
) -> Array[@model.IonValue] raise @model.IonError {
  @decode.parse_text(input, limits=limits.unwrap_or(@model.Limits::default()))
}

///|
pub fn parse_binary(
  input : Bytes,
  limits? : @model.Limits,
) -> Array[@model.IonValue] raise @model.IonError {
  @decode.parse_binary(input, limits=limits.unwrap_or(@model.Limits::default()))
}

///|
pub fn encode_text(
  values : ArrayView[@model.IonValue],
  options? : @model.EncodeOptions,
) -> String raise @model.IonError {
  @encode.encode_text(
    values,
    options=options.unwrap_or(@model.EncodeOptions::default()),
  )
}

///|
pub fn encode_binary(
  values : ArrayView[@model.IonValue],
  options? : @model.EncodeOptions,
) -> Bytes raise @model.IonError {
  @encode.encode_binary(
    values,
    options=options.unwrap_or(@model.EncodeOptions::default()),
  )
}

///|
/// Parse exactly one Ion value from a text document.
pub fn parse_one_text(
  input : String,
  limits? : @model.Limits,
) -> @model.IonValue raise @model.IonError {
  let values = parse_text(
    input,
    limits=limits.unwrap_or(@model.Limits::default()),
  )
  match values {
    [value] => value
    _ => raise single_value_error("expected exactly one Ion text value")
  }
}

///|
/// Parse exactly one Ion value from a binary document.
pub fn parse_one_binary(
  input : Bytes,
  limits? : @model.Limits,
) -> @model.IonValue raise @model.IonError {
  let values = parse_binary(
    input,
    limits=limits.unwrap_or(@model.Limits::default()),
  )
  match values {
    [value] => value
    _ => raise single_value_error("expected exactly one Ion binary value")
  }
}

///|
/// Encode one Ion value as text without a document separator.
pub fn encode_value_text(
  value : @model.IonValue,
  options? : @model.EncodeOptions,
) -> String raise @model.IonError {
  encode_text(
    [value][:],
    options=options.unwrap_or(@model.EncodeOptions::default()),
  )
}

///|
/// Encode one Ion value as a binary Ion document.
pub fn encode_value_binary(
  value : @model.IonValue,
  options? : @model.EncodeOptions,
) -> Bytes raise @model.IonError {
  encode_binary(
    [value][:],
    options=options.unwrap_or(@model.EncodeOptions::default()),
  )
}

///|
fn single_value_error(message : String) -> @model.IonError {
  @model.IonError::Parse(
    kind=@model.ErrorKind::InvalidSyntax,
    offset=0,
    line=1,
    column=1,
    message~,
  )
}

///|
/// Return the Ion version marker when the input begins with a binary version marker.
pub fn binary_version(input : Bytes) -> (Int, Int)? {
  if input.length() >= 4 && input[0] == 0xE0 && input[3] == 0xEA {
    Some((input[1].to_int(), input[2].to_int()))
  } else {
    None
  }
}

///|
/// Report whether the input begins with an Ion binary version marker.
pub fn is_binary(input : Bytes) -> Bool {
  binary_version(input) is Some(_)
}

///|
/// Parse either UTF-8 Ion text or a binary document based on its prefix.
pub fn parse_bytes(
  input : Bytes,
  limits? : @model.Limits,
) -> Array[@model.IonValue] raise @model.IonError {
  let limits = limits.unwrap_or(@model.Limits::default())
  if is_binary(input) {
    parse_binary(input, limits~)
  } else {
    let text = @utf8.decode(input[:]) catch {
      _ =>
        raise @model.IonError::Parse(
          kind=@model.ErrorKind::InvalidUtf8,
          offset=0,
          line=1,
          column=1,
          message="input is not valid UTF-8 Ion text",
        )
    }
    parse_text(text, limits~)
  }
}

///|
/// Parse exactly one value from either UTF-8 text or binary input.
pub fn parse_one_bytes(
  input : Bytes,
  limits? : @model.Limits,
) -> @model.IonValue raise @model.IonError {
  let values = parse_bytes(
    input,
    limits=limits.unwrap_or(@model.Limits::default()),
  )
  match values {
    [value] => value
    _ => raise single_value_error("expected exactly one Ion byte input value")
  }
}
