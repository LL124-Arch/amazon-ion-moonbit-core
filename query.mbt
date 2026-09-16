///|
/// Return every field with the requested name from a struct value.
pub fn select_field(
  value : @model.IonValue,
  name : String,
) -> Array[@model.IonValue] {
  value.get_fields(name)
}

///|
/// Return an element by index from a list or s-expression.
pub fn select_index(value : @model.IonValue, index : Int) -> @model.IonValue? {
  if index < 0 {
    return None
  }
  for i, child in value.elements() {
    if i == index {
      return Some(child)
    }
  }
  None
}

///|
/// Select values by alternating struct field names and non-negative indexes.
pub fn select_path(
  value : @model.IonValue,
  path : ArrayView[String],
) -> Array[@model.IonValue] {
  let mut current : Array[@model.IonValue] = [value]
  for segment in path {
    let next : Array[@model.IonValue] = []
    for candidate in current {
      match parse_path_index(segment) {
        Some(index) =>
          match select_index(candidate, index) {
            Some(child) => next.push(child)
            None => ()
          }
        None =>
          for child in select_field(candidate, segment) {
            next.push(child)
          }
      }
    }
    current = next
  }
  current
}

///|
/// Return the first value selected by a path, if the path has a result.
pub fn select_first_path(
  value : @model.IonValue,
  path : ArrayView[String],
) -> @model.IonValue? {
  match select_path(value, path) {
    [first, ..] => Some(first)
    _ => None
  }
}

///|
fn parse_path_index(text : String) -> Int? {
  try @string.parse_int(text[:]) catch {
    _ => None
  } noraise {
    index => if index >= 0 { Some(index) } else { None }
  }
}
