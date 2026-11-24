// WKWebView bridge declarations for macOS native desktop

///|
#borrow(title, frontend_dir, icon_path)
extern "C" fn wk_bridge_init_ffi(
  title : Bytes,
  width : Int32,
  height : Int32,
  frontend_dir : Bytes,
  icon_path : Bytes,
) -> Int32 = "wk_bridge_init"

///|
extern "C" fn wk_bridge_pump_events_ffi() -> Int32 = "wk_bridge_pump_events"

///|
#borrow(out_id, out_method, out_payload)
extern "C" fn wk_bridge_poll_request_ffi(
  out_id : Ref[Int32],
  out_method : FixedArray[Byte],
  method_max : Int32,
  out_payload : FixedArray[Byte],
  payload_max : Int32,
) -> Int32 = "wk_bridge_poll_request"

///|
#borrow(result_json)
extern "C" fn wk_bridge_reply_ffi(
  req_id : Int32,
  result_json : Bytes,
  is_error : Int32,
) = "wk_bridge_reply"

///|
#borrow(out_path)
extern "C" fn wk_bridge_choose_file_ffi(
  is_image : Int32,
  out_path : FixedArray[Byte],
  path_max : Int32,
) -> Int32 = "wk_bridge_choose_file"

///|
#borrow(title, default_path, out_path)
extern "C" fn wk_bridge_save_file_ffi(
  title : Bytes,
  default_path : Bytes,
  out_path : FixedArray[Byte],
  path_max : Int32,
) -> Int32 = "wk_bridge_save_file"

///|
#borrow(path)
extern "C" fn wk_bridge_reveal_file_ffi(path : Bytes) = "wk_bridge_reveal_file"

///|
#borrow(script)
extern "C" fn wk_bridge_eval_ffi(script : Bytes) = "wk_bridge_eval"

///|
pub fn wk_eval(script : String) -> Unit {
  wk_bridge_eval_ffi(to_cstr(script))
}

///|
fn to_cstr(s : String) -> Bytes {
  @utf8.encode(s + "\u{0000}")
}

///|
fn from_fixed_cstr(buf : FixedArray[Byte]) -> String {
  let mut end = 0
  while end < buf.length() && buf[end] != 0 {
    end = end + 1
  }
  let arr : Array[Byte] = []
  for i = 0; i < end; i = i + 1 {
    arr.push(buf[i])
  }
  let bytes = Bytes::from_array(arr[:])
  @utf8.decode_lossy(bytes[:])
}

///|
pub fn wk_choose_file(is_image : Bool) -> String? {
  let out_path = FixedArray::make(4096, Byte::default())
  let flag = if is_image { 1 } else { 0 }
  let res = wk_bridge_choose_file_ffi(flag, out_path, 4096)
  if res != 0 {
    let path = from_fixed_cstr(out_path)
    if path.length() > 0 {
      return Some(path)
    }
  }
  None
}

///|
pub fn wk_save_file(title : String, default_path : String) -> String? {
  let out_path = FixedArray::make(4096, Byte::default())
  let res = wk_bridge_save_file_ffi(
    to_cstr(title),
    to_cstr(default_path),
    out_path,
    4096,
  )
  if res != 0 {
    let path = from_fixed_cstr(out_path)
    if path.length() > 0 {
      return Some(path)
    }
  }
  None
}

///|
pub fn wk_reveal_file(path : String) -> Unit {
  wk_bridge_reveal_file_ffi(to_cstr(path))
}
