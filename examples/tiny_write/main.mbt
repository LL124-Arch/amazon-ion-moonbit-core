///|
fn main {
  let values : Array[@model.IonValue] = [
    @model.IonValue::Struct([
      (
        @model.IonSymbol::from_text("message"),
        @model.IonValue::String("hello from MoonBit"),
      ),
      (
        @model.IonSymbol::from_text("answer"),
        @model.IonValue::Int(@bigint.BigInt::from_int(42)),
      ),
    ]),
  ]
  let text = @encode.encode_text(values[:]) catch { _ => "<write error>" }
  println(text)
}
