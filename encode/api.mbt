///|
pub fn encode_text(
  values : ArrayView[@model.IonValue],
  options? : @model.EncodeOptions,
) -> String raise @model.IonError {
  let options = options.unwrap_or(@model.EncodeOptions::default())
  TextWriter::new(options).write_document(values)
}

///|
pub fn encode_binary(
  values : ArrayView[@model.IonValue],
  options? : @model.EncodeOptions,
) -> Bytes raise @model.IonError {
  let options = options.unwrap_or(@model.EncodeOptions::default())
  BinaryWriter::new(options).write_document(values)
}
