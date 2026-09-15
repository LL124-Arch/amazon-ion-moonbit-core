///|
test "text parser and deterministic writer" {
  let values = @decode.parse_text(
    "{name: \"moon\", count: 42, ratio: 1.5e0, ok: true}",
  ) catch {
    _ => []
  }
  assert_eq(values.length(), 1)
  let text = @encode.encode_text(values[:]) catch { _ => "" }
  assert_eq(text, "{name: \"moon\", count: 42, ratio: 1.5, ok: true}")
}

///|
test "binary version marker and round trip" {
  let values = @decode.parse_text("foo::[1, 2, 3]") catch { _ => [] }
  let binary = @encode.encode_binary(values[:]) catch { _ => b"" }
  assert_eq(binary.length() > 4, true)
  assert_eq(binary[0], 0xE0)
  assert_eq(binary[1], 0x01)
  assert_eq(binary[2], 0x00)
  assert_eq(binary[3], 0xEA)
  let decoded = @decode.parse_binary(binary) catch { _ => [] }
  assert_eq(decoded.length(), 1)
}

///|
test "binary scalar fixture" {
  let values = @decode.parse_text("1 true \"ion\"") catch { _ => [] }
  let binary = @encode.encode_binary(values[:]) catch { _ => b"" }
  assert_eq(binary, b"\xE0\x01\x00\xEA\x21\x01\x11\x83ion")
  let decoded = @decode.parse_binary(binary) catch { _ => [] }
  assert_eq(decoded.length(), 3)
}

///|
test "malformed binary is rejected" {
  let decoded = @decode.parse_binary(b"\xE0\x01\x00\xEA\x82a") catch { _ => [] }
  assert_eq(decoded.length(), 0)
}

///|
test "binary typed null, symbol zero, and NOP" {
  let decoded = @decode.parse_binary(
    b"\xE0\x01\x00\xEA\x1F\x2F\x70\x01\xFE\x0F",
  ) catch {
    _ => []
  }
  assert_eq(decoded.length(), 4)
}

///|
test "typed null and resource limit" {
  let values = @decode.parse_text("null.string") catch { _ => [] }
  assert_eq(values.length(), 1)
  let limits = @model.Limits::new(max_values=0)
  let limited = @decode.parse_text("1", limits~) catch { _ => [] }
  assert_eq(limited.length(), 0)
}

///|
test "rich Ion 1.0 values" {
  let source = "ann::{a: 1, a: 2, decimal: 12.30, timestamp: 2024-01-02T03:04:05.123Z, blob: {{aGk=}}, clob: {{\"hi\"}}, sexp: (add 1)}"
  let values = @decode.parse_text(source) catch { _ => [] }
  assert_eq(values.length(), 1)
  let binary = @encode.encode_binary(values[:]) catch { _ => b"" }
  let decoded = @decode.parse_binary(binary) catch { _ => [] }
  assert_eq(decoded.length(), 1)
  let text = @encode.encode_text(decoded[:]) catch { _ => "" }
  assert_eq(text.length() > 0, true)
}

///|
test "timestamp precision forms" {
  let values = @decode.parse_text("2024-01T 2024-01-02 2007T 2024-01-02T03:04Z") catch {
    _ => []
  }
  assert_eq(values.length(), 4)
}

///|
test "numeric separators and Ion escapes" {
  let sources = [
    "1_000", "0xFA_CE", "12_345.67_8", "1_0.0e2", "\"\\0\\a\\v\\x41\\u0042\\U00000043\"",
  ]
  for source in sources {
    let values = @decode.parse_text(source) catch { _ => [] }
    assert_eq(values.length(), 1)
  }
}

///|
test "long quoted strings and clobs" {
  let values = @decode.parse_text(
    "'''long \"ion\"''' ''' plus''' {{'''ABC\nDEF'''}}",
  ) catch {
    _ => []
  }
  assert_eq(values.length(), 2)
  let text = match values[0] {
    @model.IonValue::String(text) => text
    _ => ""
  }
  assert_eq(text, "long \"ion\" plus")
  let clob = match values[1] {
    @model.IonValue::Clob(bytes) => bytes
    _ => b""
  }
  assert_eq(clob, b"ABC\nDEF")
}

///|
test "value model annotation and kind helpers" {
  let original = @model.IonValue::null(kind=@model.IonNull::String)
  assert_eq(original.kind(), @model.IonNull::String)
  assert_eq(original.is_null(), true)
  let annotated = original.with_annotations(
    [@model.IonSymbol::from_text("config")][:],
  )
  assert_eq(annotated.kind(), @model.IonNull::String)
  assert_eq(annotated.is_null(), true)
  assert_eq(annotated.annotations().length(), 1)
  assert_eq(annotated.without_annotations(), original)
}

///|
test "ordered container access preserves duplicate fields" {
  let values = @decode.parse_text(
    "meta::{items: [1, 2], name: \"one\", name: \"two\"}",
  ) catch {
    _ => []
  }
  let value = values[0]
  assert_eq(value.fields().length(), 3)
  assert_eq(value.get_fields("name").length(), 2)
  match value.get_field("name") {
    Some(@model.IonValue::String(text)) => assert_eq(text, "one")
    _ => assert_eq(true, false)
  }
  match value.get_field("items") {
    Some(items) => assert_eq(items.elements().length(), 2)
    _ => assert_eq(true, false)
  }
}

///|
test "single value facade operations" {
  let value = parse_one_text("{answer: 42}") catch {
    _ => @model.IonValue::empty_struct()
  }
  assert_eq(value.kind(), @model.IonNull::Struct)
  let text = encode_value_text(value) catch { _ => "" }
  assert_eq(text, "{answer: 42}")
  let binary = encode_value_binary(value) catch { _ => b"" }
  let decoded = parse_one_binary(binary) catch {
    _ => @model.IonValue::empty_struct()
  }
  assert_eq(decoded, value)
  let error = try parse_one_text("1 2") catch {
    error => error
  } noraise {
    _ =>
      @model.IonError::Parse(
        kind=@model.ErrorKind::InvalidSyntax,
        offset=0,
        line=1,
        column=1,
        message="test",
      )
  }
  assert_eq(error.kind(), @model.ErrorKind::InvalidSyntax)
}

///|
test "byte input format detection" {
  let text_input = b"{answer: 42}"
  assert_eq(is_binary(text_input), false)
  let text_value = parse_one_bytes(text_input) catch {
    _ => @model.IonValue::empty_struct()
  }
  assert_eq(text_value.kind(), @model.IonNull::Struct)

  let binary_input = encode_value_binary(text_value) catch { _ => b"" }
  assert_eq(is_binary(binary_input), true)
  match binary_version(binary_input) {
    Some((major, minor)) => {
      assert_eq(major, 1)
      assert_eq(minor, 0)
    }
    None => assert_eq(true, false)
  }
  let binary_value = parse_one_bytes(binary_input) catch {
    _ => @model.IonValue::empty_struct()
  }
  assert_eq(binary_value, text_value)

  let error = try parse_bytes(b"\xFF") catch {
    error => error
  } noraise {
    _ =>
      @model.IonError::Parse(
        kind=@model.ErrorKind::InvalidSyntax,
        offset=0,
        line=1,
        column=1,
        message="test",
      )
  }
  assert_eq(error.kind(), @model.ErrorKind::InvalidUtf8)
}
