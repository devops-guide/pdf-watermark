///|
#derive(FromJson)
struct OpenPathRequest {
  path : String
}

///|
#derive(ToJson)
pub(all) struct PathReply {
  path : String?
}

///|
#derive(ToJson)
pub(all) struct ImageReply {
  path : String?
  preview_data_url : String?
}

///|
#derive(FromJson)
pub(all) struct DropDataRequest {
  name : String
  data : String
}

///|
#derive(ToJson)
pub(all) struct DropDataReply {
  name : String
  path : String
  preview_data_url : String?
}

///|
pub struct FileSession {
  lock : @async.Mutex
  mut source : String?
  mut saved : String?
}

///|
pub fn FileSession::new() -> FileSession {
  { lock: @async.Mutex(), source: None, saved: None, }
}

///|
pub fn FileSession::get_source(self : FileSession) -> String? {
  self.source
}

///|
priv suberror FileError {
  NoInput
  InvalidInput
}

///|
pub async fn FileSession::choose_pdf_dialog(self : FileSession) -> String? {
  self.lock.acquire()
  defer self.lock.release()
  guard wk_choose_file(false) is Some(path) else { return None }
  guard @path.Path(path).extname().to_lower() == ".pdf" &&
    @fs.kind(path) is Regular else {
    raise FileError::InvalidInput
  }
  self.source = Some(path)
  Some(path)
}

///|
pub async fn FileSession::open_path(
  self : FileSession,
  request : OpenPathRequest,
) -> PathReply {
  self.lock.acquire()
  defer self.lock.release()
  let path = request.path
  guard @path.Path(path).extname().to_lower() == ".pdf" &&
    @fs.kind(path) is Regular else {
    raise FileError::InvalidInput
  }
  self.source = Some(path)
  { path: Some(path), }
}

///|
pub async fn FileSession::choose_image_dialog(self : FileSession) -> ImageReply {
  self.lock.acquire()
  defer self.lock.release()
  guard wk_choose_file(true) is Some(path) else {
    return { path: None, preview_data_url: None, }
  }
  let ext = @path.Path(path).extname().to_lower()
  guard (ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".pdf") &&
    @fs.kind(path) is Regular else {
    raise FileError::InvalidInput
  }
  let preview_data_url = if ext == ".pdf" {
    None
  } else {
    let mime = if ext == ".png" { "image/png" } else { "image/jpeg" }
    let bytes = @fs.read_binary(path)
    let b64 = @base64.encode(bytes[:])
    Some("data:\{mime};base64,\{b64}")
  }
  { path: Some(path), preview_data_url, }
}

///|
pub async fn FileSession::open_image_path(
  self : FileSession,
  request : OpenPathRequest,
) -> ImageReply {
  self.lock.acquire()
  defer self.lock.release()
  let path = request.path
  let ext = @path.Path(path).extname().to_lower()
  guard (ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".pdf") &&
    @fs.kind(path) is Regular else {
    raise FileError::InvalidInput
  }
  let preview_data_url = if ext == ".pdf" {
    None
  } else {
    let mime = if ext == ".png" { "image/png" } else { "image/jpeg" }
    let bytes = @fs.read_binary(path)
    let b64 = @base64.encode(bytes[:])
    Some("data:\{mime};base64,\{b64}")
  }
  { path: Some(path), preview_data_url, }
}

///|
pub async fn FileSession::drop_pdf_data(
  self : FileSession,
  request : DropDataRequest,
) -> DropDataReply {
  self.lock.acquire()
  defer self.lock.release()

  let ext = @path.Path(request.name).extname().to_lower()
  guard ext == ".pdf" || ext == "" else { raise FileError::InvalidInput }
  let safe_name = if request.name.to_lower().has_suffix(".pdf") {
    request.name
  } else {
    request.name + ".pdf"
  }

  let tmp = @fs.tmpdir(prefix="pdf-watermark-")
  let target_path = (@path.Path(tmp) / @path.Path(safe_name)).to_string()

  let raw_data = if request.data.contains(",") {
    let parts = request.data.split(",").collect()
    if parts.length() > 1 {
      parts[1]
    } else {
      request.data
    }
  } else {
    request.data
  }

  let bytes = @base64.decode_lossy(raw_data)
  @fs.write_binary(target_path, bytes[:])

  self.source = Some(target_path)
  { name: safe_name, path: target_path, preview_data_url: None, }
}

///|
pub async fn FileSession::drop_image_data(
  self : FileSession,
  request : DropDataRequest,
) -> DropDataReply {
  self.lock.acquire()
  defer self.lock.release()

  let ext = @path.Path(request.name).extname().to_lower()
  guard ext == ".png" || ext == ".jpg" || ext == ".jpeg" || ext == ".pdf" else {
    raise FileError::InvalidInput
  }

  let tmp = @fs.tmpdir(prefix="pdf-watermark-")
  let target_path = (@path.Path(tmp) / @path.Path(request.name)).to_string()

  let raw_data = if request.data.contains(",") {
    let parts = request.data.split(",").collect()
    if parts.length() > 1 {
      parts[1]
    } else {
      request.data
    }
  } else {
    request.data
  }

  let bytes = @base64.decode_lossy(raw_data)
  @fs.write_binary(target_path, bytes[:])

  let preview_data_url = if ext == ".pdf" {
    None
  } else {
    let mime = if ext == ".png" { "image/png" } else { "image/jpeg" }
    Some("data:\{mime};base64,\{raw_data}")
  }

  { name: request.name, path: target_path, preview_data_url, }
}

///|
pub async fn FileSession::apply_watermark_with_dialog(
  self : FileSession,
  request : ApplyWatermarkRequest,
) -> String? {
  self.lock.acquire()
  defer self.lock.release()
  guard self.source is Some(source) else { raise FileError::NoInput }

  let path = @path.Path(source)
  let name = path
    .basename()
    .strip_suffix(path.extname())
    .unwrap_or(path.basename())
  let suggested = (path.dirname() / @path.Path("\{name}-watermark.pdf")).to_string()

  guard wk_save_file("保存水印 PDF", suggested) is Some(selected) else {
    return None
  }
  let destination = if @path.Path(selected).extname().to_lower() == ".pdf" {
    selected
  } else {
    selected + ".pdf"
  }
  if @fs.exists(destination) {
    if @fs.realpath(source) == @fs.realpath(destination) {
      return None
    }
  }

  let temporary = (@path.Path(destination).dirname() /
  @path.Path(".pdf-watermark-\{@random.uint64()}.tmp")).to_string()

  let _ = apply_watermark_to_file(source, temporary, request)
  @fs.rename(temporary, destination, replace=true)
  self.saved = Some(destination)
  Some(destination)
}

///|
pub async fn FileSession::handle_call(
  self : FileSession,
  action_name : String,
  params : Json,
) -> Json {
  match action_name {
    "openPdfPath" => {
      let req : OpenPathRequest = @json.from_json(params)
      @json.to_json(self.open_path(req))
    }
    "dropPdfData" => {
      let req : DropDataRequest = @json.from_json(params)
      @json.to_json(self.drop_pdf_data(req))
    }
    "openImagePath" => {
      let req : OpenPathRequest = @json.from_json(params)
      @json.to_json(self.open_image_path(req))
    }
    "dropImageData" => {
      let req : DropDataRequest = @json.from_json(params)
      @json.to_json(self.drop_image_data(req))
    }
    "applyWatermarkNative" => {
      let req : ApplyWatermarkRequest = @json.from_json(params)
      let path = self.apply_watermark_with_dialog(req)
      let path_val = match path {
        Some(p) => Json::string(p)
        None => Json::null()
      }
      { "path": path_val }
    }
    "choosePdf" => {
      let path = self.choose_pdf_dialog()
      let path_val = match path {
        Some(p) => Json::string(p)
        None => Json::null()
      }
      { "path": path_val }
    }
    "chooseImage" => {
      let reply = self.choose_image_dialog()
      @json.to_json(reply)
    }
    "revealPdf" => {
      if self.saved is Some(path) {
        wk_reveal_file(path)
      }
      Json::null()
    }
    "calculateLayout" => {
      let req : LayoutRequest = @json.from_json(params)
      @json.to_json(calculate_layout(req))
    }
    "parsePageRange" => {
      let req : PageRangeRequest = @json.from_json(params)
      @json.to_json(parse_page_range(req))
    }
    _ => Json::null()
  }
}

///|
pub async fn FileSession::discard_export(self : FileSession) -> Unit {
  self.lock.acquire()
  defer self.lock.release()
}
