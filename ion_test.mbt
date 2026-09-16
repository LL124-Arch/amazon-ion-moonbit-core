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
test "output option factories control readable text and binary markers" {
  let values = parse_text("{name: [1, 2]}")
  let compact = @model.EncodeOptions::compact()
  assert_eq(encode_text(values[:], options=compact), "{name: [1, 2]}")

  let readable = @model.EncodeOptions::readable(indent=4)
  assert_eq(
    encode_text(values[:], options=readable),
    "{\n    name: [\n        1,\n        2\n    ]\n}",
  )

  let without_bvm = compact.with_binary_version_marker(enabled=false)
  let binary = encode_binary(values[:], options=without_bvm)
  assert_eq(binary[0] == 0xE0 && binary[1] == 0x01, false)
  assert_eq(binary_version(binary), None)
}

///|
test "output options reject invalid indentation and predicted size" {
  let invalid_indent = try @model.EncodeOptions::readable(indent=0) catch {
    error => error
  } noraise {
    _ => fail("expected invalid indentation")
  }
  assert_eq(invalid_indent.kind(), @model.ErrorKind::InvalidLength)

  let invalid_legacy = @model.EncodeOptions::new(indent=17)
  let encode_error = try encode_text([], options=invalid_legacy) catch {
    error => error
  } noraise {
    _ => fail("expected invalid indentation")
  }
  assert_eq(encode_error.kind(), @model.ErrorKind::InvalidLength)

  let constrained = @model.EncodeOptions::compact(
    limits=@model.Limits::new(max_total_bytes=3),
  )
  let preflight_error = try constrained.preflight_output_size(4) catch {
    error => error
  } noraise {
    _ => fail("expected output limit")
  }
  assert_eq(preflight_error.is_limit(), true)

  let values = parse_text("{name: 1}")
  let output_error = try encode_text(values[:], options=constrained) catch {
    error => error
  } noraise {
    _ => fail("expected output limit")
  }
  assert_eq(output_error.is_limit(), true)

  let binary_output_error = try
    encode_binary(values[:], options=constrained)
  catch {
    error => error
  } noraise {
    _ => fail("expected output limit")
  }
  assert_eq(binary_output_error.is_limit(), true)
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

///|
test "document analysis counts nested payloads" {
  let values = @decode.parse_text(
    "ann::{name: \"ion\", bytes: {{aGk=}}, items: [1, 2]}",
  ) catch {
    _ => []
  }
  let stats = analyze(values[:])
  assert_eq(stats.value_count(), 6)
  assert_eq(stats.max_depth(), 3)
  assert_eq(stats.symbol_count(), 4)
  assert_eq(stats.payload_bytes(), 22)
}

///|
test "typed value projections ignore annotations" {
  let values = parse_text(
    "tag::\"ion\" tag::true tag::12345678901234567890 tag::1.20 tag::2024-01T",
  ) catch {
    _ => []
  }
  assert_eq(values.length(), 5)
  assert_eq(values[0].as_string(), Some("ion"))
  assert_eq(values[0].as_bool(), None)
  assert_eq(values[1].as_bool(), Some(true))
  match values[2].as_int() {
    Some(number) => assert_eq(number.to_string(), "12345678901234567890")
    None => assert_eq(true, false)
  }
  assert_eq(values[3].as_decimal() is Some(_), true)
  assert_eq(values[4].as_timestamp() is Some(_), true)
  assert_eq(@model.IonValue::empty_list().as_string(), None)
}

///|
test "scalar constructors retain payloads and reject type mismatches" {
  let huge_integer = @bigint.BigInt::from_string(
    "123456789012345678901234567890",
  )
  let decimal = @model.IonDecimal::new(
    coefficient=@bigint.BigInt::from_string("-1200000"),
    exponent=-6,
  )
  let timestamp = @model.IonTimestamp::new(
    year=2024,
    month=Some(2),
    day=Some(29),
    hour=Some(23),
    minute=Some(59),
    second=Some(58),
    offset_minutes=Some(0),
    fraction_exponent=Some(-9),
    fraction_coefficient=Some(@bigint.BigInt::from_string("123456789")),
  )

  assert_eq(@model.IonValue::string("ion").as_string(), Some("ion"))
  assert_eq(@model.IonValue::bool(false).as_bool(), Some(false))
  assert_eq(@model.IonValue::bool(false).as_string(), None)
  assert_eq(@model.IonValue::null(kind=@model.IonNull::Int).as_int(), None)

  match
    @model.IonValue::int(huge_integer)
    .with_annotations([@model.IonSymbol::from_text("identifier")])
    .as_int() {
    Some(actual) =>
      assert_eq(actual.to_string(), "123456789012345678901234567890")
    None => fail("expected annotated integer")
  }
  match @model.IonValue::decimal(decimal).as_decimal() {
    Some(actual) => {
      assert_eq(actual.coefficient().to_string(), "-1200000")
      assert_eq(actual.exponent(), -6)
    }
    None => fail("expected decimal")
  }
  match @model.IonValue::timestamp(timestamp).as_timestamp() {
    Some(actual) => {
      assert_eq(actual.year(), 2024)
      assert_eq(actual.offset_minutes(), Some(0))
      assert_eq(actual.fraction_exponent(), Some(-9))
      match actual.fraction_coefficient() {
        Some(coefficient) => assert_eq(coefficient.to_string(), "123456789")
        None => fail("expected fractional seconds")
      }
    }
    None => fail("expected timestamp")
  }
}

///|
test "scalar display helpers preserve Ion meaning" {
  assert_eq(@model.IonSymbol::from_text("name").display(), "name")
  assert_eq(@model.IonSymbol::from_text("name").is_resolved(), true)
  assert_eq(@model.IonSymbol::from_sid(12).display(), "$12")
  assert_eq(@model.IonSymbol::from_sid(12).is_resolved(), false)
  assert_eq(@model.IonSymbol::unknown().display(), "$0")
  assert_eq(@model.IonSymbol::unknown().is_resolved(), false)

  let negative_decimal = @model.IonDecimal::new(
    coefficient=@bigint.BigInt::from_string("-300"),
    exponent=-2,
  )
  assert_eq(negative_decimal.to_text(), "-3.00")
  assert_eq(negative_decimal.to_ion_text(), "-300d-2")
  let zero_decimal = @model.IonDecimal::new(
    coefficient=@bigint.BigInt::from_int(0),
    exponent=-3,
  )
  assert_eq(zero_decimal.to_text(), "0.000")
  assert_eq(zero_decimal.to_ion_text(), "0d-3")

  let values = parse_text("1.20 -3.00 2024-01T 2024-01-02T03:04:05Z") catch {
    _ => []
  }
  match values[0].as_decimal() {
    Some(decimal) => assert_eq(decimal.to_text(), "1.20")
    None => assert_eq(true, false)
  }
  match values[1].as_decimal() {
    Some(decimal) => assert_eq(decimal.to_text(), "-3.00")
    None => assert_eq(true, false)
  }
  match values[2].as_timestamp() {
    Some(timestamp) => {
      assert_eq(timestamp.precision(), 2)
      assert_eq(timestamp.has_offset(), false)
      assert_eq(timestamp.has_time(), false)
      assert_eq(timestamp.offset_text(), "-00:00")
    }
    None => assert_eq(true, false)
  }
  match values[3].as_timestamp() {
    Some(timestamp) => {
      assert_eq(timestamp.precision(), 6)
      assert_eq(timestamp.has_offset(), true)
      assert_eq(timestamp.has_time(), true)
      assert_eq(timestamp.offset_text(), "Z")
    }
    None => assert_eq(true, false)
  }
}

///|
test "scalar helper output aligns with writer and parser errors" {
  let offset_time = parse_one_text("2024-01-02T03:04+05:30")
  match offset_time.as_timestamp() {
    Some(timestamp) => {
      assert_eq(timestamp.has_time(), true)
      assert_eq(timestamp.offset_text(), "+05:30")
    }
    None => assert_eq(true, false)
  }
  assert_eq(encode_value_text(offset_time), "2024-01-02T03:04+05:30")

  let unknown_offset_time = parse_one_text("2024-01-02T03:04-00:00")
  match unknown_offset_time.as_timestamp() {
    Some(timestamp) => assert_eq(timestamp.offset_text(), "-00:00")
    None => assert_eq(true, false)
  }
  assert_eq(encode_value_text(unknown_offset_time), "2024-01-02T03:04-00:00")

  assert_eq(
    encode_value_text(
      @model.IonValue::decimal(
        @model.IonDecimal::new(
          coefficient=@bigint.BigInt::from_string("-300"),
          exponent=-2,
        ),
      ),
    ),
    "-300d-2",
  )

  let error = try parse_one_text("1d+") catch {
    error => error
  } noraise {
    _ => fail("expected malformed decimal")
  }
  assert_eq(error.kind(), @model.ErrorKind::InvalidSyntax)
}

///|
test "nested path queries preserve order and bounds" {
  let value = parse_one_text(
    "{service: {ports: [80, 443], tags: [\"edge\"]}, service: {ports: [8080]}}",
  ) catch {
    _ => @model.IonValue::empty_struct()
  }
  assert_eq(select_field(value, "service").length(), 2)
  assert_eq(select_index(value, 0) is Some(_), false)
  let path = ["service", "ports", "1"]
  let matches = select_path(value, path[:])
  assert_eq(matches.length(), 1)
  match matches[0].as_int() {
    Some(number) => assert_eq(number.to_string(), "443")
    None => assert_eq(true, false)
  }
  match select_first_path(value, ["service", "ports", "0"][:]) {
    Some(number) =>
      match number.as_int() {
        Some(number) => assert_eq(number.to_string(), "80")
        None => assert_eq(true, false)
      }
    None => assert_eq(true, false)
  }
  assert_eq(select_path(value, ["service", "missing"][:]).length(), 0)
  assert_eq(select_index(value.get_field("service").unwrap(), -1), None)
}

///|
test "preflight limits and error classification" {
  let values = parse_text("{name: \"ion\", items: [1, 2]}") catch { _ => [] }
  let stats = analyze(values[:])
  assert_eq(stats.fits(@model.Limits::default()), true)
  let shallow = @model.Limits::new(max_depth=1)
  assert_eq(stats.fits(shallow), false)

  let limit_error = @model.IonError::Limit(
    kind=@model.LimitKind::Values,
    offset=4,
    line=1,
    column=5,
    message="value limit exceeded",
  )
  assert_eq(limit_error.is_limit(), true)
  assert_eq(limit_error.kind(), @model.ErrorKind::LimitExceeded)
  let parse_error = @model.IonError::Parse(
    kind=@model.ErrorKind::InvalidSyntax,
    offset=0,
    line=1,
    column=1,
    message="bad value",
  )
  assert_eq(parse_error.is_limit(), false)
}

///|
test "struct editing preserves duplicates, order, annotations, and source" {
  let original = parse_one_text(
    "record::{first: 1, duplicate: 2, duplicate: 3}",
  )
  let appended = struct_append_field(
    original,
    "last",
    @model.IonValue::symbol(text="tail"),
  ).unwrap()
  let updated = struct_replace_field(
    appended,
    "duplicate",
    1,
    @model.IonValue::symbol(text="changed"),
  ).unwrap()
  let removed = struct_remove_field(updated, "duplicate", 0).unwrap()

  assert_eq(
    encode_value_text(removed),
    "record::{first: 1, duplicate: changed, last: tail}",
  )
  assert_eq(
    encode_value_text(original),
    "record::{first: 1, duplicate: 2, duplicate: 3}",
  )
}

///|
test "list editing creates independent annotated values" {
  let original = parse_one_text("numbers::[1, 2]")
  let appended = list_append(original, @model.IonValue::symbol(text="three")).unwrap()
  let replaced = list_replace(appended, 1, @model.IonValue::symbol(text="two")).unwrap()

  assert_eq(encode_value_text(replaced), "numbers::[1, two, three]")
  assert_eq(encode_value_text(original), "numbers::[1, 2]")
}

///|
test "structure editing rejects missing fields, wrong types, and invalid indexes" {
  let record = parse_one_text("{a: 1, a: 2}")
  let list = parse_one_text("[]")
  let scalar = parse_one_text("true")

  assert_eq(struct_replace_field(record, "a", 2, scalar), None)
  assert_eq(struct_remove_field(record, "missing", 0), None)
  assert_eq(struct_remove_field(record, "a", -1), None)
  assert_eq(struct_append_field(scalar, "a", record), None)
  assert_eq(list_replace(list, 0, scalar), None)
  assert_eq(list_replace(list, -1, scalar), None)
  assert_eq(list_append(scalar, record), None)
}

///|
test "hex fixture helpers are stable and reject malformed input" {
  let fixture = "# version marker and three scalar values\nE0 01 00 EA 21 01 11 83 69 6F 6E"
  let bytes = decode_hex(fixture)
  assert_eq(bytes, b"\xE0\x01\x00\xEA\x21\x01\x11\x83ion")
  assert_eq(encode_hex(bytes), "e00100ea21011183696f6e")
  assert_eq(parse_binary(bytes).length(), 3)

  let invalid = try decode_hex("E0 0G") catch {
    error => error
  } noraise {
    _ => fail("expected invalid hexadecimal")
  }
  assert_eq(invalid.kind(), @model.ErrorKind::InvalidSyntax)
  assert_eq(invalid.location().offset, 4)

  let truncated = try decode_hex("E0 0") catch {
    error => error
  } noraise {
    _ => fail("expected truncated hexadecimal")
  }
  assert_eq(truncated.kind(), @model.ErrorKind::InvalidLength)

  let binary_error = try parse_binary(decode_hex("E0 01 00 EA 82 61")) catch {
    error => error
  } noraise {
    _ => fail("expected truncated binary")
  }
  assert_eq(binary_error.kind(), @model.ErrorKind::UnexpectedEof)
}

///|
test "diagnostics expose stable error locations and text binary equivalence" {
  let syntax_error = try parse_text("{answer: }") catch {
    error => error
  } noraise {
    _ => fail("expected invalid text")
  }
  assert_eq(syntax_error.location(), { offset: 9, line: 1, column: 10 })
  assert_eq(
    syntax_error.summary(),
    "invalid_syntax: expected an Ion value at 1:10 (offset 9)",
  )

  let text = "$777::{first: $778, duplicate: 1, duplicate: bar}"
  let values = parse_text(text)
  let binary = encode_binary(values[:])
  let report = diagnose_text_binary(text, binary)
  assert_eq(report.text_value_count(), 1)
  assert_eq(report.binary_value_count(), 1)
  assert_eq(report.matches(), true)

  let mismatch = diagnose_text_binary("1", encode_binary(parse_text("2")[:]))
  assert_eq(mismatch.matches(), false)
}
