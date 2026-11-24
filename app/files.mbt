///|
let chunk_size : Int32 = 512 * 1024

///|
#derive(FromJson)
struct ReadRequest {
  offset : Int64
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
struct PathReply {
  path : String?
}

///|
struct Export {
  destination : String
  temporary : String
  file : @fs.File
}

///|
struct FileSession {
  lock : @async.Mutex
  mut source : String?
  mut pending : Export?
  mut saved : String?
}

///|
fn FileSession::new() -> FileSession {
  { lock: @async.Mutex(), source: None, pending: None, saved: None, }
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
  registrar.bind(choose, (context, _) => { path: self.choose(context), })
  registrar.bind(read, (_, request) => self.read(request))
  registrar.bind(begin, (context, _) => self.begin(context))
  registrar.bind(write, (_, request) => { path: self.write(request), })
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
