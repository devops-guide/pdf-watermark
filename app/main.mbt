///|
async fn main {
  let args = @env.args()
  if args.length() >= 3 && !args[1].has_prefix("-") {
    let source = args[1]
    let text = args[2]
    let path = @path.Path(source)
    let name = path
      .basename()
      .strip_suffix(path.extname())
      .unwrap_or(path.basename())
    let destination = if args.length() >= 4 {
      args[3]
    } else {
      (path.dirname() / @path.Path("\{name}-watermark.pdf")).to_string()
    }
    let is_img = text.has_suffix(".png") ||
      text.has_suffix(".PNG") ||
      text.has_suffix(".jpg") ||
      text.has_suffix(".jpeg")
    let req : ApplyWatermarkRequest = {
      watermark_type: if is_img {
        Some("image")
      } else {
        Some("text")
      },
      text: if is_img {
        None
      } else {
        Some(text)
      },
      image_path: if is_img {
        Some(text)
      } else {
        None
      },
      font_size: Some(48.0),
      style: Some("centered"),
      opacity: Some(0.4),
      rotate: Some(0.0),
      page_range: Some("all"),
      color_hex: Some("#cc3333"),
      scale: Some(0.5),
      scale_to_fit: Some(false),
    }
    let res = apply_watermark_to_file(source, destination, req)
    println(
      "Watermark applied successfully -> \{res.output_path} (\{res.pages_count} pages)",
    )
    return
  }

  if args.length() == 2 && (args[1] == "--help" || args[1] == "-h") {
    println("PDF Watermark (Pure MoonBit Native Desktop)")
    println("Usage:")
    println("  Desktop Mode: app (or double-click application)")
    println(
      "  CLI Mode:     app <input_pdf_path> <watermark_text> [output_path]",
    )
    return
  }

  let title = "PDF 水印"
  let width = 940
  let height = 700
  let frontend_dir = if @fs.exists("frontend/index.html") {
    @fs.realpath("frontend")
  } else {
    let exe_dir = @path.Path(args[0]).dirname()
    (exe_dir / @path.Path("../Resources/frontend")).to_string()
  }
  let icon_path = if @fs.exists("icons/logo.png") {
    @fs.realpath("icons/logo.png")
  } else if @fs.exists("frontend/logo.png") {
    @fs.realpath("frontend/logo.png")
  } else {
    ""
  }

  let session = FileSession::new()
  let init_res = wk_bridge_init_ffi(
    to_cstr(title),
    width,
    height,
    to_cstr(frontend_dir),
    to_cstr(icon_path),
  )
  if init_res == 0 {
    println("Failed to initialize native window")
    return
  }

  let method_buf = FixedArray::make(256, Byte::default())
  let payload_buf = FixedArray::make(8 * 1024 * 1024, Byte::default())
  let req_id_ref = Ref(0)

  let mut initial_script = match @env.get_env_var("PDF_WATERMARK_INIT_SCRIPT") {
    Some(s) => Some(s)
    None =>
      if args.length() == 2 && !args[1].has_prefix("-") && @fs.exists(args[1]) {
        let abs = @fs.realpath(args[1])
        Some("window.__app?.setPdfSource('" + abs + "')")
      } else {
        None
      }
  }
  let mut pump_count = 0

  while wk_bridge_pump_events_ffi() != 0 {
    pump_count += 1
    if pump_count == 25 {
      match initial_script {
        Some(s) => {
          wk_eval(s)
          initial_script = None
        }
        None => ()
      }
    }

    while wk_bridge_poll_request_ffi(
            req_id_ref,
            method_buf,
            256,
            payload_buf,
            8 * 1024 * 1024,
          ) !=
          0 {
      let id = req_id_ref.val
      let action_name = from_fixed_cstr(method_buf)
      let payload_str = from_fixed_cstr(payload_buf)
      let payload_json = @json.parse(payload_str) catch { _ => Json::null() }
      try {
        let result = session.handle_call(action_name, payload_json)
        let result_json = result.stringify()
        wk_bridge_reply_ffi(id, to_cstr(result_json), 0)
      } catch {
        err => wk_bridge_reply_ffi(id, to_cstr(err.to_string()), 1)
      }
    }
  }

  session.discard_export()
}
