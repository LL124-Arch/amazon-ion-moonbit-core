///|
/// Append a text-named field to a struct, keeping its field order and annotations.
///
/// Returns `None` when `value` is not a struct (after unwrapping annotations).
pub fn struct_append_field(
  value : @model.IonValue,
  name : String,
  field_value : @model.IonValue,
) -> @model.IonValue? {
  match value {
    @model.IonValue::Annotated(annotations, nested) =>
      match struct_append_field(nested, name, field_value) {
        Some(updated) => Some(@model.IonValue::Annotated(annotations, updated))
        None => None
      }
    @model.IonValue::Struct(fields) => {
      let updated : Array[(@model.IonSymbol, @model.IonValue)] = []
      for field in fields {
        updated.push(field)
      }
      updated.push((@model.IonSymbol::from_text(name), field_value))
      Some(@model.IonValue::Struct(updated))
    }
    _ => None
  }
}

///|
/// Replace the zero-based matching occurrence of a text-named struct field.
///
/// The existing field symbol is retained, so symbol IDs and field order stay intact.
/// Returns `None` for a non-struct, a negative occurrence, or no matching field.
pub fn struct_replace_field(
  value : @model.IonValue,
  name : String,
  occurrence : Int,
  field_value : @model.IonValue,
) -> @model.IonValue? {
  if occurrence < 0 {
    return None
  }
  match value {
    @model.IonValue::Annotated(annotations, nested) =>
      match struct_replace_field(nested, name, occurrence, field_value) {
        Some(updated) => Some(@model.IonValue::Annotated(annotations, updated))
        None => None
      }
    @model.IonValue::Struct(fields) => {
      let updated : Array[(@model.IonSymbol, @model.IonValue)] = []
      let mut matching = 0
      let mut replaced = false
      for field in fields {
        match field.0.text_value() {
          Some(field_name) if field_name == name && matching == occurrence => {
            updated.push((field.0, field_value))
            matching += 1
            replaced = true
          }
          Some(field_name) if field_name == name => {
            updated.push(field)
            matching += 1
          }
          _ => updated.push(field)
        }
      }
      if replaced {
        Some(@model.IonValue::Struct(updated))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Remove the zero-based matching occurrence of a text-named struct field.
///
/// Other duplicate fields retain their original relative order. Returns `None` when
/// the requested occurrence is absent, negative, or `value` is not a struct.
pub fn struct_remove_field(
  value : @model.IonValue,
  name : String,
  occurrence : Int,
) -> @model.IonValue? {
  if occurrence < 0 {
    return None
  }
  match value {
    @model.IonValue::Annotated(annotations, nested) =>
      match struct_remove_field(nested, name, occurrence) {
        Some(updated) => Some(@model.IonValue::Annotated(annotations, updated))
        None => None
      }
    @model.IonValue::Struct(fields) => {
      let updated : Array[(@model.IonSymbol, @model.IonValue)] = []
      let mut matching = 0
      let mut removed = false
      for field in fields {
        match field.0.text_value() {
          Some(field_name) if field_name == name && matching == occurrence => {
            matching += 1
            removed = true
          }
          Some(field_name) if field_name == name => {
            updated.push(field)
            matching += 1
          }
          _ => updated.push(field)
        }
      }
      if removed {
        Some(@model.IonValue::Struct(updated))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Append an element to a list, preserving any annotations on the list.
///
/// Returns `None` when `value` is not a list; s-expressions are intentionally not
/// edited by this list-specific operation.
pub fn list_append(
  value : @model.IonValue,
  element : @model.IonValue,
) -> @model.IonValue? {
  match value {
    @model.IonValue::Annotated(annotations, nested) =>
      match list_append(nested, element) {
        Some(updated) => Some(@model.IonValue::Annotated(annotations, updated))
        None => None
      }
    @model.IonValue::List(elements) => {
      let updated : Array[@model.IonValue] = []
      for item in elements {
        updated.push(item)
      }
      updated.push(element)
      Some(@model.IonValue::List(updated))
    }
    _ => None
  }
}

///|
/// Replace a zero-based list element without changing its length or annotations.
///
/// Returns `None` for a non-list or an out-of-bounds (including negative) index.
pub fn list_replace(
  value : @model.IonValue,
  index : Int,
  replacement : @model.IonValue,
) -> @model.IonValue? {
  if index < 0 {
    return None
  }
  match value {
    @model.IonValue::Annotated(annotations, nested) =>
      match list_replace(nested, index, replacement) {
        Some(updated) => Some(@model.IonValue::Annotated(annotations, updated))
        None => None
      }
    @model.IonValue::List(elements) => {
      let updated : Array[@model.IonValue] = []
      let mut replaced = false
      for position, item in elements {
        if position == index {
          updated.push(replacement)
          replaced = true
        } else {
          updated.push(item)
        }
      }
      if replaced {
        Some(@model.IonValue::List(updated))
      } else {
        None
      }
    }
    _ => None
  }
}
