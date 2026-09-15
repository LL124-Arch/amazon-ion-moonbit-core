///|
pub fn parse_text(
  input : String,
  limits? : @model.Limits,
) -> Array[@model.IonValue] raise @model.IonError {
  let limits = limits.unwrap_or(@model.Limits::default())
  let bytes = @utf8.encode(input)
  if bytes.length() > limits.max_total_bytes() {
    raise @model.IonError::Limit(
      kind=@model.LimitKind::TotalBytes,
      offset=0,
      line=1,
      column=1,
      message="text input exceeds max_total_bytes",
    )
  }
  TextParser::new(bytes, limits).parse_document()
}

///|
pub fn parse_binary(
  input : Bytes,
  limits? : @model.Limits,
) -> Array[@model.IonValue] raise @model.IonError {
  let limits = limits.unwrap_or(@model.Limits::default())
  if input.length() > limits.max_total_bytes() {
    raise @model.IonError::Limit(
      kind=@model.LimitKind::TotalBytes,
      offset=0,
      line=1,
      column=1,
      message="binary input exceeds max_total_bytes",
    )
  }
  BinaryParser::new(input, limits).parse_document()
}
