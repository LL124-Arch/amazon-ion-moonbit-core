///|
test "document sequence slicing and kind filtering preserve order" {
  let values = parse_text("$ion_1_0 tag::1 \"two\" 3 true")
  let slice = slice_values(values[:], 1, 3)
  assert_eq(encode_text(slice[:]), "\"two\"\n3\ntrue")
  assert_eq(slice_values(values[:], -1, 2).length(), 0)
  assert_eq(slice_values(values[:], 1, 0).length(), 0)
  assert_eq(slice_values(values[:], 10, 2).length(), 0)

  let integers = filter_values_by_kind(values[:], @model.IonNull::Int)
  assert_eq(encode_text(integers[:]), "tag::1\n3")
  assert_eq(
    filter_values_by_kind(values[:], @model.IonNull::Struct).length(),
    0,
  )
}

///|
test "document merge preserves empty inputs and source ordering" {
  let first = parse_text("1 2")
  let second = parse_text("")
  let third = parse_text("label::3 \"four\"")
  let documents = [first, second, third]
  let merged = merge_documents(documents[:])
  assert_eq(encode_text(merged[:]), "1\n2\nlabel::3\n\"four\"")
  assert_eq(merge_documents([]).length(), 0)
  assert_eq(encode_text(first[:]), "1\n2")
}

///|
test "document merge reports value and container resource limits" {
  let values = parse_text("1 2")
  let value_error = try
    merge_documents([values][:], limits=@model.Limits::new(max_values=1))
  catch {
    error => error
  } noraise {
    _ => fail("expected merged document value limit")
  }
  assert_eq(value_error.is_limit(), true)
  assert_eq(value_error.kind(), @model.ErrorKind::LimitExceeded)

  let nested = parse_text("[1, 2]")
  let container_error = try
    merge_documents(
      [nested][:],
      limits=@model.Limits::new(max_values=10, max_container_items=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected merged document container limit")
  }
  assert_eq(container_error.is_limit(), true)
  assert_eq(container_error.kind(), @model.ErrorKind::LimitExceeded)
}

///|
test "range reencoding applies input and output constraints" {
  let text = reencode_text_range("$ion_1_0 1 tag::2 3", 1, 2)
  assert_eq(text, "tag::2\n3")
  assert_eq(reencode_text_range("1 2", -1, 2), "")

  let source = encode_binary(parse_text("1 2 3")[:])
  let binary = reencode_binary_range(source, 1, 1)
  assert_eq(binary_version(binary), Some((1, 0)))
  assert_eq(encode_text(parse_binary(binary)[:]), "2")

  let input_error = try
    reencode_text_range(
      "1 2",
      0,
      1,
      input_limits=@model.Limits::new(max_values=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected input limit")
  }
  assert_eq(input_error.is_limit(), true)

  let output_error = try
    reencode_text_range(
      "1234",
      0,
      1,
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_total_bytes=3),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected output limit")
  }
  assert_eq(output_error.is_limit(), true)
}
