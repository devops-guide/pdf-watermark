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
    let destination = (path.dirname() / @path.Path("\{name}-watermark.pdf")).to_string()
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
    let _ = apply_watermark_to_file(source, destination, req)
    println(destination)
    return
  }

  if args.length() == 2 && (args[1] == "--help" || args[1] == "-h") {
    println("PDF Watermark (MoonBit Native)")
    println("Usage:")
    println("  Desktop GUI:  app")
    println("  CLI Mode:     app <input_pdf_path> <watermark_text>")
    return
  }

  let files = FileSession::new()
  let icon_path = if @fs.exists("icons/logo.png") {
    @fs.realpath("icons/logo.png")
  } else if @fs.exists("icons/logo.icns") {
    @fs.realpath("icons/logo.icns")
  } else if @fs.exists("frontend/logo.png") {
    @fs.realpath("frontend/logo.png")
  } else {
    let exe_dir = @path.Path(args[0]).dirname()
    let near_exe = (exe_dir / @path.Path("../Resources/icons/logo.png")).to_string()
    if @fs.exists(near_exe) {
      @fs.realpath(near_exe)
    } else {
      "icons/logo.png"
    }
  }
  @proton.asset("PDF 水印", "frontend/index.html", width=940, height=700)
  ..config(@proton.load_config())
  ..single_instance()
  ..commands(registrar => files.bind(registrar))
  ..setup_window(context => {
    context.add_cleanup(() => files.discard_export())
    context.handle().set_icon(icon_path) catch {
      _ => ()
    }
  })
  .run_or_abort()
}
