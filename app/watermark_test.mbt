///|
async test "apply_watermark text centered" {
  let tmp = @fs.tmpdir(prefix="wm-test-")
  let out = (@path.Path(tmp) / @path.Path("out_text_centered.pdf")).to_string()
  let req : @app.ApplyWatermarkRequest = {
    watermark_type: Some("text"),
    text: Some("CONFIDENTIAL"),
    image_path: None,
    font_size: Some(48.0),
    style: Some("centered"),
    opacity: Some(0.4),
    rotate: Some(0.0),
    page_range: Some("all"),
    color_hex: Some("#cc3333"),
    scale: None,
    scale_to_fit: None,
  }
  let res = @app.apply_watermark_to_file("test/input.pdf", out, req)
  assert_true(res.pages_count > 0)
  assert_true(@fs.exists(out))
  let doc = @pdf_io.pdf_read_document_from_file(out)
  assert_eq(doc.pages_of_pagetree().length(), res.pages_count)
  @fs.remove(out, allow_missing=true)
}

///|
async test "apply_watermark text diagonal skip-first" {
  let tmp = @fs.tmpdir(prefix="wm-test-")
  let out = (@path.Path(tmp) / @path.Path("out_text_diagonal.pdf")).to_string()
  let req : @app.ApplyWatermarkRequest = {
    watermark_type: Some("text"),
    text: Some("INTERNAL USE ONLY"),
    image_path: None,
    font_size: Some(36.0),
    style: Some("diagonal"),
    opacity: Some(0.3),
    rotate: Some(-45.0),
    page_range: Some("skip-first"),
    color_hex: Some("#0033cc"),
    scale: None,
    scale_to_fit: None,
  }
  let res = @app.apply_watermark_to_file("test/input.pdf", out, req)
  assert_true(res.pages_count > 0)
  assert_true(@fs.exists(out))
  @fs.remove(out, allow_missing=true)
}

///|
async test "apply_watermark image bottom-right scaled" {
  let tmp = @fs.tmpdir(prefix="wm-test-")
  let out = (@path.Path(tmp) / @path.Path("out_image_br.pdf")).to_string()
  let req : @app.ApplyWatermarkRequest = {
    watermark_type: Some("image"),
    text: None,
    image_path: Some("icons/logo.png"),
    font_size: None,
    style: Some("bottom-right"),
    opacity: Some(0.85),
    rotate: None,
    page_range: Some("all"),
    color_hex: None,
    scale: Some(0.25),
    scale_to_fit: Some(false),
  }
  let res = @app.apply_watermark_to_file("test/input.pdf", out, req)
  assert_true(res.pages_count > 0)
  assert_true(@fs.exists(out))
  @fs.remove(out, allow_missing=true)
}

///|
async test "apply_watermark image scale-to-fit" {
  let tmp = @fs.tmpdir(prefix="wm-test-")
  let out = (@path.Path(tmp) / @path.Path("out_image_fit.pdf")).to_string()
  let req : @app.ApplyWatermarkRequest = {
    watermark_type: Some("image"),
    text: None,
    image_path: Some("icons/logo.png"),
    font_size: None,
    style: Some("center"),
    opacity: Some(0.5),
    rotate: None,
    page_range: Some("1"),
    color_hex: None,
    scale: None,
    scale_to_fit: Some(true),
  }
  let res = @app.apply_watermark_to_file("test/input.pdf", out, req)
  assert_true(res.pages_count > 0)
  assert_true(@fs.exists(out))
  @fs.remove(out, allow_missing=true)
}
