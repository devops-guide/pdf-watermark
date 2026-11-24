///|
async test "drop_pdf_data with valid extension" {
  let session = @app.FileSession::new()
  let sample_bytes : Bytes = [65, 66, 67, 68]
  let b64 = @base64.encode(sample_bytes[:])
  let req : @app.DropDataRequest = { name: "test_doc.pdf", data: b64, }
  let reply = session.drop_pdf_data(req)

  assert_eq(reply.name, "test_doc.pdf")
  assert_true(@fs.exists(reply.path))
  assert_eq(session.get_source(), Some(reply.path))
  assert_eq(reply.preview_data_url, None)

  let read_back = @fs.read_binary(reply.path)
  assert_eq(read_back[:], sample_bytes[:])

  @fs.remove(reply.path, allow_missing=true)
}

///|
async test "drop_pdf_data ensures pdf extension" {
  let session = @app.FileSession::new()
  let sample_bytes : Bytes = [37, 80, 68, 70]
  let b64 = @base64.encode(sample_bytes[:])
  let req : @app.DropDataRequest = { name: "invoice_2026", data: b64, }
  let reply = session.drop_pdf_data(req)

  assert_true(reply.path.has_suffix(".pdf"))
  assert_true(@fs.exists(reply.path))
  assert_eq(session.get_source(), Some(reply.path))

  @fs.remove(reply.path, allow_missing=true)
}

///|
async test "drop_image_data png preview data url" {
  let session = @app.FileSession::new()
  let sample_bytes : Bytes = [137, 80, 78, 71]
  let b64 = @base64.encode(sample_bytes[:])
  let req : @app.DropDataRequest = { name: "company_stamp.png", data: b64, }
  let reply = session.drop_image_data(req)

  assert_eq(reply.name, "company_stamp.png")
  assert_true(@fs.exists(reply.path))
  assert_eq(reply.preview_data_url, Some("data:image/png;base64," + b64))

  @fs.remove(reply.path, allow_missing=true)
}

///|
async test "drop_image_data jpeg preview data url" {
  let session = @app.FileSession::new()
  let sample_bytes : Bytes = [255, 216, 255, 224]
  let b64 = @base64.encode(sample_bytes[:])
  let req : @app.DropDataRequest = { name: "signature.jpg", data: b64, }
  let reply = session.drop_image_data(req)

  assert_eq(reply.name, "signature.jpg")
  assert_true(@fs.exists(reply.path))
  assert_eq(reply.preview_data_url, Some("data:image/jpeg;base64," + b64))

  @fs.remove(reply.path, allow_missing=true)
}

///|
async test "drop_image_data pdf stamp without preview url" {
  let session = @app.FileSession::new()
  let sample_bytes : Bytes = [37, 80, 68, 70]
  let b64 = @base64.encode(sample_bytes[:])
  let req : @app.DropDataRequest = { name: "vector_stamp.pdf", data: b64, }
  let reply = session.drop_image_data(req)

  assert_eq(reply.name, "vector_stamp.pdf")
  assert_true(@fs.exists(reply.path))
  assert_eq(reply.preview_data_url, None)

  @fs.remove(reply.path, allow_missing=true)
}

///|
test "parse_colour_from_hex variations" {
  match @app.parse_colour_from_hex(Some("#1677ff")) {
    PdfContentRGB(r, g, b) => {
      assert_true((r - 22.0 / 255.0).abs() < 0.001)
      assert_true((g - 119.0 / 255.0).abs() < 0.001)
      assert_true((b - 255.0 / 255.0).abs() < 0.001)
    }
    _ => assert_true(false)
  }

  // Without leading '#'
  match @app.parse_colour_from_hex(Some("cc3333")) {
    PdfContentRGB(r, g, b) => {
      assert_true((r - 204.0 / 255.0).abs() < 0.001)
      assert_true((g - 51.0 / 255.0).abs() < 0.001)
      assert_true((b - 51.0 / 255.0).abs() < 0.001)
    }
    _ => assert_true(false)
  }

  // Invalid or None defaults to 0.8, 0.8, 0.8
  match @app.parse_colour_from_hex(None) {
    PdfContentRGB(r, g, b) => {
      assert_eq(r, 0.8)
      assert_eq(g, 0.8)
      assert_eq(b, 0.8)
    }
    _ => assert_true(false)
  }
}

///|
test "parse_page_range all and single" {
  let all_req : @app.PageRangeRequest = { range_spec: "all", total_pages: 4, }
  let all_res = @app.parse_page_range(all_req)
  assert_eq(all_res.included, [1, 2, 3, 4])

  let single_req : @app.PageRangeRequest = { range_spec: "3", total_pages: 5, }
  let single_res = @app.parse_page_range(single_req)
  assert_eq(single_res.included, [3])

  let out_of_bounds : @app.PageRangeRequest = {
    range_spec: "1, 10",
    total_pages: 3,
  }
  let ob_res = @app.parse_page_range(out_of_bounds)
  assert_eq(ob_res.included, [1])
}

///|
async test "drop_image_data rejects unsupported formats" {
  let session = @app.FileSession::new()
  let sample_bytes : Bytes = [1, 2, 3]
  let b64 = @base64.encode(sample_bytes[:])
  let req : @app.DropDataRequest = { name: "document.txt", data: b64, }
  let mut raised = false
  try {
    let _ = session.drop_image_data(req)
  } catch {
    _ => raised = true
  }
  assert_true(raised)
}

///|
async test "drop_pdf_data rejects non-pdf extensions" {
  let session = @app.FileSession::new()
  let sample_bytes : Bytes = [1, 2, 3]
  let b64 = @base64.encode(sample_bytes[:])
  let req : @app.DropDataRequest = { name: "image.png", data: b64, }
  let mut raised = false
  try {
    let _ = session.drop_pdf_data(req)
  } catch {
    _ => raised = true
  }
  assert_true(raised)
}
