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
