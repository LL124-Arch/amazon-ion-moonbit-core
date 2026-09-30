///|
fn has_limit_kind(error : @model.IonError, expected : @model.LimitKind) -> Bool {
  error.limit_kind() == Some(expected)
}

///|
test "UTF-8 payload and total-byte limits accept the exact boundary" {
  let text = "\"猫\""
  let text_limits = @model.Limits::new(max_total_bytes=5, max_text_bytes=3)
  assert_eq(@utf8.encode(text).length(), 5)
  assert_eq(
    @amazon-ion-moonbit-core.parse_text(text, limits=text_limits).length(),
    1,
  )

  let total_error = try
    @amazon-ion-moonbit-core.parse_text(
      text,
      limits=@model.Limits::new(max_total_bytes=4, max_text_bytes=3),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text total-byte limit")
  }
  assert_eq(has_limit_kind(total_error, @model.LimitKind::TotalBytes), true)

  let text_payload_error = try
    @amazon-ion-moonbit-core.parse_text(
      text,
      limits=@model.Limits::new(max_total_bytes=5, max_text_bytes=2),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text payload limit")
  }
  assert_eq(
    has_limit_kind(text_payload_error, @model.LimitKind::TextBytes),
    true,
  )

  let values = [@model.IonValue::string("猫")]
  let text_output = @amazon-ion-moonbit-core.encode_text(
    values[:],
    options=@model.EncodeOptions::compact(
      limits=@model.Limits::new(max_total_bytes=5, max_text_bytes=3),
    ),
  )
  assert_eq(text_output, text)
  let text_output_error = try
    @amazon-ion-moonbit-core.encode_text(
      values[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_total_bytes=4, max_text_bytes=3),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text output total-byte limit")
  }
  assert_eq(
    has_limit_kind(text_output_error, @model.LimitKind::TotalBytes),
    true,
  )

  let binary = @amazon-ion-moonbit-core.encode_binary(
    values[:],
    options=@model.EncodeOptions::compact(
      limits=@model.Limits::new(max_total_bytes=8, max_text_bytes=3),
    ),
  )
  assert_eq(binary.length(), 8)
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      binary,
      limits=@model.Limits::new(max_total_bytes=8, max_text_bytes=3),
    ).length(),
    1,
  )

  let binary_payload_error = try
    @amazon-ion-moonbit-core.parse_binary(
      binary,
      limits=@model.Limits::new(max_total_bytes=8, max_text_bytes=2),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary text-payload limit")
  }
  assert_eq(
    has_limit_kind(binary_payload_error, @model.LimitKind::TextBytes),
    true,
  )

  let binary_output_error = try
    @amazon-ion-moonbit-core.encode_binary(
      values[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_total_bytes=7, max_text_bytes=3),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary output total-byte limit")
  }
  assert_eq(
    has_limit_kind(binary_output_error, @model.LimitKind::TotalBytes),
    true,
  )
}

///|
test "value and container budgets distinguish exact limits from one over" {
  assert_eq(
    @amazon-ion-moonbit-core.parse_text(
      "",
      limits=@model.Limits::new(max_values=0),
    ).length(),
    0,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      b"\xE0\x01\x00\xEA",
      limits=@model.Limits::new(max_values=0),
    ).length(),
    0,
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_text(
      [],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_values=0),
      ),
    ),
    "",
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_binary(
      [],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_values=0),
      ),
    ),
    b"\xE0\x01\x00\xEA",
  )

  let values = @amazon-ion-moonbit-core.parse_text("1 2")
  let exact_values = @model.Limits::new(max_values=2)
  assert_eq(
    @amazon-ion-moonbit-core.parse_text("1 2", limits=exact_values).length(),
    2,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(values[:]),
      limits=exact_values,
    ).length(),
    2,
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_text(
      values[:],
      options=@model.EncodeOptions::compact(limits=exact_values),
    ),
    "1\n2",
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_binary(
      values[:],
      options=@model.EncodeOptions::compact(limits=exact_values),
    ).length() >
    4,
    true,
  )

  let value_error = try
    @amazon-ion-moonbit-core.parse_text(
      "1 2",
      limits=@model.Limits::new(max_values=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text value-count limit")
  }
  assert_eq(has_limit_kind(value_error, @model.LimitKind::Values), true)

  let encoded_value_error = try
    @amazon-ion-moonbit-core.encode_text(
      values[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_values=1),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text encoder value-count limit")
  }
  assert_eq(has_limit_kind(encoded_value_error, @model.LimitKind::Values), true)

  let binary_value_error = try
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(values[:]),
      limits=@model.Limits::new(max_values=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary parser value-count limit")
  }
  assert_eq(has_limit_kind(binary_value_error, @model.LimitKind::Values), true)

  let binary_encoder_error = try
    @amazon-ion-moonbit-core.encode_binary(
      values[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_values=1),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary encoder value-count limit")
  }
  assert_eq(
    has_limit_kind(binary_encoder_error, @model.LimitKind::Values),
    true,
  )

  let empty_list = @amazon-ion-moonbit-core.parse_text("[]")
  assert_eq(
    @amazon-ion-moonbit-core.parse_text(
      "[]",
      limits=@model.Limits::new(max_container_items=0),
    ).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(empty_list[:]),
      limits=@model.Limits::new(max_container_items=0),
    ).length(),
    1,
  )

  let one_item_list = @amazon-ion-moonbit-core.parse_text("[1]")
  let one_item_limit = @model.Limits::new(max_container_items=1)
  assert_eq(
    @amazon-ion-moonbit-core.parse_text("[1]", limits=one_item_limit).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(one_item_list[:]),
      limits=one_item_limit,
    ).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_text(
      one_item_list[:],
      options=@model.EncodeOptions::compact(limits=one_item_limit),
    ),
    "[1]",
  )

  let container_error = try
    @amazon-ion-moonbit-core.parse_text(
      "[1]",
      limits=@model.Limits::new(max_container_items=0),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected list item limit")
  }
  assert_eq(
    has_limit_kind(container_error, @model.LimitKind::ContainerItems),
    true,
  )

  let text_encoder_error = try
    @amazon-ion-moonbit-core.encode_text(
      one_item_list[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_container_items=0),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text encoder container-item limit")
  }
  assert_eq(
    has_limit_kind(text_encoder_error, @model.LimitKind::ContainerItems),
    true,
  )

  let binary_parser_error = try
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(one_item_list[:]),
      limits=@model.Limits::new(max_container_items=0),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary parser container-item limit")
  }
  assert_eq(
    has_limit_kind(binary_parser_error, @model.LimitKind::ContainerItems),
    true,
  )

  let binary_encoder_error = try
    @amazon-ion-moonbit-core.encode_binary(
      one_item_list[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_container_items=0),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary encoder container-item limit")
  }
  assert_eq(
    has_limit_kind(binary_encoder_error, @model.LimitKind::ContainerItems),
    true,
  )
}

///|
test "sexp and struct item limits apply at exact and exceeded boundaries" {
  let sexp = @amazon-ion-moonbit-core.parse_text("(1 2)")
  let struct_values = @amazon-ion-moonbit-core.parse_text("{a:1,b:2}")
  let exact = @model.Limits::new(max_container_items=2)

  assert_eq(
    @amazon-ion-moonbit-core.parse_text("(1 2)", limits=exact).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_text("{a:1,b:2}", limits=exact).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(sexp[:]),
      limits=exact,
    ).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(struct_values[:]),
      limits=exact,
    ).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_text(
      sexp[:],
      options=@model.EncodeOptions::compact(limits=exact),
    ),
    "(1 2)",
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_text(
      struct_values[:],
      options=@model.EncodeOptions::compact(limits=exact),
    ),
    "{a: 1, b: 2}",
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_binary(
      sexp[:],
      options=@model.EncodeOptions::compact(limits=exact),
    ).length() >
    4,
    true,
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_binary(
      struct_values[:],
      options=@model.EncodeOptions::compact(limits=exact),
    ).length() >
    4,
    true,
  )

  let sexp_parse_error = try
    @amazon-ion-moonbit-core.parse_text(
      "(1 2)",
      limits=@model.Limits::new(max_container_items=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected sexp parser item limit")
  }
  assert_eq(
    has_limit_kind(sexp_parse_error, @model.LimitKind::ContainerItems),
    true,
  )

  let struct_parse_error = try
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(struct_values[:]),
      limits=@model.Limits::new(max_container_items=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected struct binary parser item limit")
  }
  assert_eq(
    has_limit_kind(struct_parse_error, @model.LimitKind::ContainerItems),
    true,
  )

  let sexp_writer_error = try
    @amazon-ion-moonbit-core.encode_text(
      sexp[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_container_items=1),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected sexp text writer item limit")
  }
  assert_eq(
    has_limit_kind(sexp_writer_error, @model.LimitKind::ContainerItems),
    true,
  )

  let struct_binary_writer_error = try
    @amazon-ion-moonbit-core.encode_binary(
      struct_values[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_container_items=1),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected struct binary writer item limit")
  }
  assert_eq(
    has_limit_kind(struct_binary_writer_error, @model.LimitKind::ContainerItems),
    true,
  )
}

///|
test "depth budget agrees across analysis, text, and binary boundaries" {
  let source = "[[1]]"
  let values = @amazon-ion-moonbit-core.parse_text(source)
  assert_eq(@amazon-ion-moonbit-core.analyze(values[:]).max_depth(), 3)

  let exact_depth = @model.Limits::new(max_depth=3)
  assert_eq(
    @amazon-ion-moonbit-core.parse_text(source, limits=exact_depth).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(values[:]),
      limits=exact_depth,
    ).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_text(
      values[:],
      options=@model.EncodeOptions::compact(limits=exact_depth),
    ),
    source,
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_binary(
      values[:],
      options=@model.EncodeOptions::compact(limits=exact_depth),
    ).length() >
    4,
    true,
  )
  assert_eq(
    @amazon-ion-moonbit-core.preflight_values(values[:], limits=exact_depth).fits(
      exact_depth,
    ),
    true,
  )

  let shallow = @model.Limits::new(max_depth=2)
  let text_error = try
    @amazon-ion-moonbit-core.parse_text(source, limits=shallow)
  catch {
    error => error
  } noraise {
    _ => fail("expected text parser depth limit")
  }
  assert_eq(has_limit_kind(text_error, @model.LimitKind::Depth), true)

  let binary = @amazon-ion-moonbit-core.encode_binary(values[:])
  let binary_error = try
    @amazon-ion-moonbit-core.parse_binary(binary, limits=shallow)
  catch {
    error => error
  } noraise {
    _ => fail("expected binary parser depth limit")
  }
  assert_eq(has_limit_kind(binary_error, @model.LimitKind::Depth), true)

  let text_output_error = try
    @amazon-ion-moonbit-core.encode_text(
      values[:],
      options=@model.EncodeOptions::compact(limits=shallow),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text encoder depth limit")
  }
  assert_eq(has_limit_kind(text_output_error, @model.LimitKind::Depth), true)

  let binary_output_error = try
    @amazon-ion-moonbit-core.encode_binary(
      values[:],
      options=@model.EncodeOptions::compact(limits=shallow),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary encoder depth limit")
  }
  assert_eq(has_limit_kind(binary_output_error, @model.LimitKind::Depth), true)
}

///|
test "annotations count as one value and respect container-item limits" {
  let annotated = @amazon-ion-moonbit-core.parse_text("tag::1")
  assert_eq(@amazon-ion-moonbit-core.analyze(annotated[:]).value_count(), 1)
  let one_value = @model.Limits::new(max_values=1, max_container_items=1)
  assert_eq(
    @amazon-ion-moonbit-core.parse_text("tag::1", limits=one_value).length(),
    1,
  )

  let text = @amazon-ion-moonbit-core.encode_text(
    annotated[:],
    options=@model.EncodeOptions::compact(limits=one_value),
  )
  assert_eq(text, "tag::1")
  let binary = @amazon-ion-moonbit-core.encode_binary(
    annotated[:],
    options=@model.EncodeOptions::compact(limits=one_value),
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(binary, limits=one_value).length(),
    1,
  )

  let two_annotations = @amazon-ion-moonbit-core.parse_text("$10::$11::1")
  let exact_annotations = @model.Limits::new(
    max_container_items=2,
    max_values=1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_text("$10::$11::1", limits=exact_annotations).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_text(
      two_annotations[:],
      options=@model.EncodeOptions::compact(limits=exact_annotations),
    ),
    "$10::$11::1",
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(
        two_annotations[:],
        options=@model.EncodeOptions::compact(limits=exact_annotations),
      ),
      limits=exact_annotations,
    ).length(),
    1,
  )

  let text_annotation_error = try
    @amazon-ion-moonbit-core.parse_text(
      "$10::$11::1",
      limits=@model.Limits::new(max_container_items=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text annotation-count limit")
  }
  assert_eq(
    has_limit_kind(text_annotation_error, @model.LimitKind::ContainerItems),
    true,
  )

  let text_writer_error = try
    @amazon-ion-moonbit-core.encode_text(
      two_annotations[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_container_items=1),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text writer annotation-count limit")
  }
  assert_eq(
    has_limit_kind(text_writer_error, @model.LimitKind::ContainerItems),
    true,
  )

  let binary_annotation_error = try
    @amazon-ion-moonbit-core.parse_binary(
      @amazon-ion-moonbit-core.encode_binary(two_annotations[:]),
      limits=@model.Limits::new(max_container_items=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary annotation-count limit")
  }
  assert_eq(
    has_limit_kind(binary_annotation_error, @model.LimitKind::ContainerItems),
    true,
  )

  let binary_writer_annotation_error = try
    @amazon-ion-moonbit-core.encode_binary(
      two_annotations[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_container_items=1),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary writer annotation-count limit")
  }
  assert_eq(
    has_limit_kind(
      binary_writer_annotation_error,
      @model.LimitKind::ContainerItems,
    ),
    true,
  )
}

///|
test "binary string lengths cross the inline-prefix boundary safely" {
  let thirteen = [@model.IonValue::string("abcdefghijklm")]
  let thirteen_binary = @amazon-ion-moonbit-core.encode_binary(thirteen[:])
  assert_eq(thirteen_binary[4], 0x8D)
  assert_eq(@amazon-ion-moonbit-core.parse_binary(thirteen_binary).length(), 1)

  let fourteen = [@model.IonValue::string("abcdefghijklmn")]
  let fourteen_binary = @amazon-ion-moonbit-core.encode_binary(fourteen[:])
  assert_eq(fourteen_binary[4], 0x8E)
  assert_eq(fourteen_binary[5], 0x8E)
  assert_eq(@amazon-ion-moonbit-core.parse_binary(fourteen_binary).length(), 1)

  let empty_document = @amazon-ion-moonbit-core.parse_binary(
    b"\xE0\x01\x00\xEA",
  )
  assert_eq(empty_document.length(), 0)

  // A NOP pad is framing metadata, so it must not consume the Ion value budget.
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(
      b"\xE0\x01\x00\xEA\x01\xFF\x10",
      limits=@model.Limits::new(max_values=1),
    ).length(),
    1,
  )

  let truncated_varuint = try
    @amazon-ion-moonbit-core.parse_binary(b"\xE0\x01\x00\xEA\x8E\x00")
  catch {
    error => error
  } noraise {
    _ => fail("expected truncated VarUInt error")
  }
  assert_eq(truncated_varuint.kind(), @model.ErrorKind::UnexpectedEof)

  let truncated_payload = try
    @amazon-ion-moonbit-core.parse_binary(b"\xE0\x01\x00\xEA\x8E\x03a")
  catch {
    error => error
  } noraise {
    _ => fail("expected truncated payload error")
  }
  assert_eq(truncated_payload.kind(), @model.ErrorKind::UnexpectedEof)

  let invalid_bool = try
    @amazon-ion-moonbit-core.parse_binary(b"\xE0\x01\x00\xEA\x12\x00\x00")
  catch {
    error => error
  } noraise {
    _ => fail("expected invalid binary boolean")
  }
  assert_eq(invalid_bool.kind(), @model.ErrorKind::InvalidBinary)

  let invalid_utf8 = try
    @amazon-ion-moonbit-core.parse_binary(b"\xE0\x01\x00\xEA\x81\xFF")
  catch {
    error => error
  } noraise {
    _ => fail("expected invalid UTF-8 string")
  }
  assert_eq(invalid_utf8.kind(), @model.ErrorKind::InvalidUtf8)
}

///|
test "blob byte limits accept exact size and reject one byte over" {
  let blob = [@model.IonValue::Blob(b"\xAA\xBB")]
  let exact = @model.Limits::new(max_blob_bytes=2)
  let encoded_binary = @amazon-ion-moonbit-core.encode_binary(
    blob[:],
    options=@model.EncodeOptions::compact(limits=exact),
  )
  assert_eq(
    @amazon-ion-moonbit-core.encode_text(
      blob[:],
      options=@model.EncodeOptions::compact(limits=exact),
    ).length() >
    0,
    true,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_binary(encoded_binary, limits=exact).length(),
    1,
  )
  assert_eq(
    @amazon-ion-moonbit-core.parse_text("{{qrs=}}", limits=exact).length(),
    1,
  )

  let parser_error = try
    @amazon-ion-moonbit-core.parse_binary(
      encoded_binary,
      limits=@model.Limits::new(max_blob_bytes=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary blob-byte limit")
  }
  assert_eq(has_limit_kind(parser_error, @model.LimitKind::BlobBytes), true)

  let text_parser_error = try
    @amazon-ion-moonbit-core.parse_text(
      "{{qrs=}}",
      limits=@model.Limits::new(max_blob_bytes=1),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text blob-byte limit")
  }
  assert_eq(
    has_limit_kind(text_parser_error, @model.LimitKind::BlobBytes),
    true,
  )

  let writer_error = try
    @amazon-ion-moonbit-core.encode_binary(
      blob[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_blob_bytes=1),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected binary writer blob-byte limit")
  }
  assert_eq(has_limit_kind(writer_error, @model.LimitKind::BlobBytes), true)

  let text_writer_error = try
    @amazon-ion-moonbit-core.encode_text(
      blob[:],
      options=@model.EncodeOptions::compact(
        limits=@model.Limits::new(max_blob_bytes=1),
      ),
    )
  catch {
    error => error
  } noraise {
    _ => fail("expected text writer blob-byte limit")
  }
  assert_eq(
    has_limit_kind(text_writer_error, @model.LimitKind::BlobBytes),
    true,
  )
}
