///|
/// An unambiguous segment in a read-only Ion path query.
///
/// `Field` selects every matching ordered struct field, including a field whose
/// name is numeric. `Index` selects one element from a list or s-expression.
pub(all) enum PathSegment {
  Field(String)
  Index(Int)
} derive(Debug, Eq)

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
  let typed_path : Array[PathSegment] = []
  for segment in path {
    match parse_path_index(segment) {
      Some(index) => typed_path.push(PathSegment::Index(index))
      None => typed_path.push(PathSegment::Field(segment))
    }
  }
  select_typed_path(value, typed_path[:])
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
/// Select values with explicit field and index path segments.
///
/// Unlike `select_path`, a `Field("0")` always means the struct field named
/// `"0"`, never list element zero. Repeated fields and document order are
/// preserved, while a missing field, invalid container kind, or out-of-range
/// index returns an empty result without changing the input.
pub fn select_typed_path(
  value : @model.IonValue,
  path : ArrayView[PathSegment],
) -> Array[@model.IonValue] {
  select_typed_path_from_roots([value][:], path)
}

///|
/// Return the first value selected by an explicit path, if any.
pub fn select_first_typed_path(
  value : @model.IonValue,
  path : ArrayView[PathSegment],
) -> @model.IonValue? {
  match select_typed_path(value, path) {
    [first, ..] => Some(first)
    _ => None
  }
}

///|
/// Apply an explicit path to every root value in an Ion document.
///
/// Results retain document order and repeated-field order. An empty path copies
/// the document roots into the returned result, rather than exposing the input
/// array for mutation.
pub fn select_document_typed_path(
  values : ArrayView[@model.IonValue],
  path : ArrayView[PathSegment],
) -> Array[@model.IonValue] {
  select_typed_path_from_roots(values, path)
}

///|
fn select_typed_path_from_roots(
  roots : ArrayView[@model.IonValue],
  path : ArrayView[PathSegment],
) -> Array[@model.IonValue] {
  let mut current : Array[@model.IonValue] = []
  for root in roots {
    current.push(root)
  }
  for segment in path {
    let next : Array[@model.IonValue] = []
    for candidate in current {
      match segment {
        PathSegment::Field(name) =>
          for child in select_field(candidate, name) {
            next.push(child)
          }
        PathSegment::Index(index) =>
          match select_index(candidate, index) {
            Some(child) => next.push(child)
            None => ()
          }
      }
    }
    current = next
  }
  current
}

///|
fn parse_path_index(text : String) -> Int? {
  try @string.parse_int(text[:]) catch {
    _ => None
  } noraise {
    index => if index >= 0 { Some(index) } else { None }
  }
}
