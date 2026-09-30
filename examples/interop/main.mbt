///|
fn write_encoded(values : Array[@model.IonValue]) -> Unit raise @model.IonError {
  let text = @ion.encode_text(values[:])
  let binary = @ion.encode_binary(values[:])
  println("TEXT_HEX=" + @ion.encode_hex(@utf8.encode(text)))
  println("BINARY_HEX=" + @ion.encode_hex(binary))
}

///|
fn write_normalized(
  values : Array[@model.IonValue],
) -> Unit raise @model.IonError {
  let text = @ion.encode_text(values[:])
  println("TEXT_HEX=" + @ion.encode_hex(@utf8.encode(text)))
}

///|
fn main {
  let args = @env.args()
  if args.length() != 3 {
    println("ERROR=expected a mode and one Ion payload")
    return
  }
  try {
    match args[1] {
      "roundtrip" => write_encoded(@ion.parse_text(args[2]))
      "parse-text" => write_normalized(@ion.parse_text(args[2]))
      "parse-binary" => {
        let bytes = @ion.decode_hex(args[2])
        write_normalized(@ion.parse_binary(bytes))
      }
      _ => println("ERROR=unknown mode")
    }
  } catch {
    error => println("ERROR=" + error.summary())
  }
}
