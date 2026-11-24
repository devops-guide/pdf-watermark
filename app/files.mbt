///|
let chunk_size : Int32 = 512 * 1024

///|
#derive(FromJson)
struct ReadRequest {
  offset : Int64
}

///|
#derive(FromJson)
struct OpenPathRequest {
  path : String
}

///|
#derive(FromJson)
struct WriteRequest {
  data : String
  final_chunk : Bool
}

///|
#derive(ToJson)
struct ReadReply {
  data : String
  next_offset : Int64
  done : Bool
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
struct Export {
  destination : String
  temporary : String
  file : @fs.File
}

///|
pub struct FileSession {
  lock : @async.Mutex
  mut source : String?
  mut pending : Export?
  mut saved : String?
}

///|
pub fn FileSession::new() -> FileSession {
  { lock: @async.Mutex(), source: None, pending: None, saved: None, }
}

///|
pub fn FileSession::get_source(self : FileSession) -> String? {
  self.source
}

///|
priv suberror FileError {
  NoInput
  NoExport
  InvalidInput
  InvalidChunk
}

///|
fn FileSession::bind(
  self : FileSession,
  registrar : @proton.CommandRegistrar,
) -> Unit raise {
  let choose : @contract.Command[Json, PathReply] = @contract.command(
    "choosePdf",
  )
  let open_path_cmd : @contract.Command[OpenPathRequest, PathReply] = @contract.command(
    "openPdfPath",
  )
  let read : @contract.Command[ReadRequest, ReadReply] = @contract.command(
    "readPdf",
  )
  let begin : @contract.Command[Json, String] = @contract.command("beginExport")
  let write : @contract.Command[WriteRequest, PathReply] = @contract.command(
    "writePdf",
  )
  let discard : @contract.Command[Json, Json] = @contract.command(
    "discardExport",
  )
  let reveal : @contract.Command[Json, Json] = @contract.command("revealPdf")
  let calc_layout : @contract.Command[LayoutRequest, LayoutReply] = @contract.command(
    "calculateLayout",
  )
  let parse_pages : @contract.Command[PageRangeRequest, PageRangeReply] = @contract.command(
    "parsePageRange",
  )
  let apply_native : @contract.Command[ApplyWatermarkRequest, PathReply] = @contract.command(
    "applyWatermarkNative",
  )
  let choose_image : @contract.Command[Json, ImageReply] = @contract.command(
    "chooseImage",
  )
  let open_image_cmd : @contract.Command[OpenPathRequest, ImageReply] = @contract.command(
    "openImagePath",
  )
  let drop_pdf : @contract.Command[DropDataRequest, DropDataReply] = @contract.command(
    "dropPdfData",
  )
  let drop_image : @contract.Command[DropDataRequest, DropDataReply] = @contract.command(
    "dropImageData",
  )
  registrar.bind(choose, (context, _) => { path: self.choose(context), })
  registrar.bind(open_path_cmd, (_, request) => self.open_path(request))
  registrar.bind(drop_pdf, (_, request) => self.drop_pdf_data(request))
  registrar.bind(choose_image, (context, _) => self.choose_image(context))
  registrar.bind(open_image_cmd, (_, request) => self.open_image_path(request))
  registrar.bind(drop_image, (_, request) => self.drop_image_data(request))
  registrar.bind(read, (_, request) => self.read(request))
  registrar.bind(begin, (context, _) => self.begin(context))
  registrar.bind(write, (_, request) => { path: self.write(request), })
  registrar.bind(calc_layout, (_, request) => calculate_layout(request))
  registrar.bind(parse_pages, (_, request) => parse_page_range(request))
  registrar.bind(apply_native, (context, request) => {
    path: self.apply_watermark(context, request),
  })
  registrar.bind(discard, (_, _) => {
    self.discard_export()
    Json::null()
  })
  registrar.bind(reveal, (_, _) => {
    if self.saved is Some(path) {
      @shell.reveal_item(path)
    }
    Json::null()
  })
}

///|
async fn FileSession::choose(
  self : FileSession,
  context : @proton.CommandContext,
) -> String? {
  self.lock.acquire()
  defer self.lock.release()
  guard context.window() is Some(window) else { return None }
  guard window.open_file(Some("选择 PDF 文件"), self.source) is Some(path) else {
    return None
  }
  guard @path.Path(path).extname().to_lower() == ".pdf" &&
    @fs.kind(path) is Regular else {
    raise FileError::InvalidInput
  }
  self.source = Some(path)
  Some(path)
}

///|
async fn FileSession::open_path(
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
async fn FileSession::choose_image(
  self : FileSession,
  context : @proton.CommandContext,
) -> ImageReply {
  self.lock.acquire()
  defer self.lock.release()
  guard context.window() is Some(window) else {
    return { path: None, preview_data_url: None, }
  }
  guard window.open_file(Some("选择水印图片或印章"), None)
    is Some(path) else {
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
async fn FileSession::open_image_path(
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
  let bytes = @base64.decode_lossy(request.data)
  let tmp = @fs.tmpdir(prefix="pdf-watermark-")
  let safe_name = if request.name.has_suffix(".pdf") {
    request.name
  } else {
    request.name + ".pdf"
  }
  let file_path = (@path.Path(tmp) / @path.Path(safe_name)).to_string()
  @fs.write_binary(file_path, bytes[:])
  self.source = Some(file_path)
  { name: request.name, path: file_path, preview_data_url: None, }
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
  let bytes = @base64.decode_lossy(request.data)
  let tmp = @fs.tmpdir(prefix="pdf-watermark-")
  let file_path = (@path.Path(tmp) / @path.Path(request.name)).to_string()
  @fs.write_binary(file_path, bytes[:])
  let preview_data_url = if ext == ".pdf" {
    None
  } else {
    let mime = if ext == ".png" { "image/png" } else { "image/jpeg" }
    Some("data:\{mime};base64,\{request.data}")
  }
  { name: request.name, path: file_path, preview_data_url, }
}

///|
async fn FileSession::read(
  self : FileSession,
  request : ReadRequest,
) -> ReadReply {
  self.lock.acquire()
  defer self.lock.release()
  guard self.source is Some(path) else { raise FileError::NoInput }
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let size = file.size()
  let offset = request.offset
  guard offset >= 0 && offset <= size else { raise FileError::InvalidChunk }
  let count = @cmp.minimum(size - offset, chunk_size.to_int64()).to_int()
  let data = if count == 0 { b"" } else { file.at(offset).read_exactly(count) }
  let next_offset = offset + count.to_int64()
  { data: @base64.encode(data), next_offset, done: next_offset == size, }
}

///|
async fn FileSession::begin(
  self : FileSession,
  context : @proton.CommandContext,
) -> String {
  self.lock.acquire()
  defer self.lock.release()
  self.remove_pending()
  guard self.source is Some(source) else { raise FileError::NoInput }
  guard context.window() is Some(window) else { return "cancelled" }
  let path = @path.Path(source)
  let name = path
    .basename()
    .strip_suffix(path.extname())
    .unwrap_or(path.basename())
  let suggested = path.dirname() / @path.Path("\{name}-watermark.pdf")
  guard window.save_file(
      Some("保存水印 PDF"),
      suggested.to_string() |> Some,
    )
    is Some(selected) else {
    return "cancelled"
  }
  let destination = if @path.Path(selected).extname().to_lower() == ".pdf" {
    selected
  } else {
    selected + ".pdf"
  }
  if @fs.exists(destination) {
    if @fs.realpath(source) == @fs.realpath(destination) {
      return "source"
    }
    // The dialog only confirmed the original path, before the suffix was added.
    if destination != selected &&
      !window.confirm(
        Some("替换文件"),
        "目标 PDF 已存在。要替换它吗？",
        "warning",
      ) {
      return "cancelled"
    }
  }
  let temporary = (@path.Path(destination).dirname() /
  @path.Path(".pdf-watermark-\{@random.uint64()}.tmp")).to_string()
  @async.protect_from_cancel(() => {
    let file = @fs.create(temporary, permission=0o600)
    self.pending = Some({ destination, temporary, file, })
  })
  "ready"
}

///|
async fn FileSession::write(
  self : FileSession,
  request : WriteRequest,
) -> String? {
  self.lock.acquire()
  defer self.lock.release()
  guard self.pending is Some(pending) else { raise FileError::NoExport }
  guard request.data.length() <= (chunk_size + 2) / 3 * 4 else {
    raise FileError::InvalidChunk
  }
  let bytes = @base64.decode(request.data)
  guard !bytes.is_empty() && bytes.length() <= chunk_size else {
    raise FileError::InvalidChunk
  }
  pending.file.write(bytes)
  guard request.final_chunk else { return None }
  @async.protect_from_cancel(() => {
    // Close before replacing the destination, including on Windows.
    pending.file.close()
    self.pending = None
    errdefer (@fs.remove(pending.temporary, allow_missing=true) catch {
      _ => ()
    })
    @fs.rename(pending.temporary, pending.destination, replace=true)
    self.saved = Some(pending.destination)
  })
  Some(pending.destination)
}

///|
async fn FileSession::apply_watermark(
  self : FileSession,
  context : @proton.CommandContext,
  request : ApplyWatermarkRequest,
) -> String? {
  self.lock.acquire()
  defer self.lock.release()
  guard self.source is Some(source) else { raise FileError::NoInput }
  guard context.window() is Some(window) else { return None }

  let path = @path.Path(source)
  let name = path
    .basename()
    .strip_suffix(path.extname())
    .unwrap_or(path.basename())
  let suggested = path.dirname() / @path.Path("\{name}-watermark.pdf")

  guard window.save_file(
      Some("保存水印 PDF"),
      suggested.to_string() |> Some,
    )
    is Some(selected) else {
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
    if destination != selected &&
      !window.confirm(
        Some("替换文件"),
        "目标 PDF 已存在。要替换它吗？",
        "warning",
      ) {
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
async fn FileSession::discard_export(self : FileSession) -> Unit {
  self.lock.acquire()
  defer self.lock.release()
  self.remove_pending()
}

///|
async fn FileSession::remove_pending(self : FileSession) -> Unit {
  if self.pending is Some(pending) {
    self.pending = None
    pending.file.close()
    @fs.remove(pending.temporary, allow_missing=true)
  }
}
