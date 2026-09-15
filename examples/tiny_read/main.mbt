///|
fn main {
  let values = @decode.parse_text("{service: \"ion\", enabled: true}") catch {
    error => {
      println("parse error: \{error.message()}")
      return
    }
  }
  println(@encode.encode_text(values[:]) catch { _ => "<write error>" })
}
