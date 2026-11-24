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

///|
async test "handle_call routes calculateLayout and parsePageRange" {
  let session = @app.FileSession::new()
  let layout_param : Json = {
    "style": "centered",
    "page_width": 595.0,
    "page_height": 842.0,
    "crop_x": 0.0,
    "crop_y": 0.0,
    "stamp_width": 200.0,
    "stamp_height": 50.0,
    "rotate": 0.0,
    "margin_right": 100.0,
    "margin_bottom": 100.0,
  }
  let layout_res = session.handle_call("calculateLayout", layout_param)
  match layout_res {
    Object(map) => assert_true(map.contains("stamps"))
    _ => assert_true(false)
  }

  let range_param : Json = { "range_spec": "1-3", "total_pages": 5 }
  let range_res = session.handle_call("parsePageRange", range_param)
  match range_res {
    Object(map) => assert_true(map.contains("included"))
    _ => assert_true(false)
  }
}

///|
async test "handle_call openPdfPath and dropPdfData" {
  let session = @app.FileSession::new()
  let open_param : Json = { "path": "test/input.pdf" }
  let open_res = session.handle_call("openPdfPath", open_param)
  match open_res {
    Object(map) => assert_true(map.contains("path"))
    _ => assert_true(false)
  }

  let sample_bytes : Bytes = [1, 2, 3]
  let b64 = @base64.encode(sample_bytes[:])
  let drop_param : Json = { "name": "sample.pdf", "data": b64 }
  let drop_res = session.handle_call("dropPdfData", drop_param)
  match drop_res {
    Object(map) => {
      assert_true(map.contains("path"))
      match map.get("path") {
        Some(String(p)) => @fs.remove(p, allow_missing=true)
        _ => ()
      }
    }
    _ => assert_true(false)
  }
}
