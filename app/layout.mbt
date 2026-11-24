///|
#derive(FromJson, ToJson)
pub(all) struct LayoutRequest {
  style : String
  page_width : Double
  page_height : Double
  crop_x : Double
  crop_y : Double
  stamp_width : Double
  stamp_height : Double
  rotate : Double
  margin_right : Double
  margin_bottom : Double
}

///|
#derive(FromJson, ToJson)
pub(all) struct StampCoord {
  x : Double
  y : Double
}

///|
#derive(FromJson, ToJson)
pub(all) struct LayoutReply {
  scale : Double
  stamps : Array[StampCoord]
  columns : Int32
  rows : Int32
}

///|
pub fn calculate_layout(req : LayoutRequest) -> LayoutReply {
  let pi = 3.141592653589793
  let angle = req.rotate * pi / 180.0
  let sin = @math.sin(angle).abs()
  let cos = @math.cos(angle).abs()
  let box_w = req.stamp_width * cos + req.stamp_height * sin
  let box_h = req.stamp_width * sin + req.stamp_height * cos
  let scale_x = if box_w > 0.0 { req.page_width * 0.97 / box_w } else { 1.0 }
  let scale_y = if box_h > 0.0 { req.page_height * 0.97 / box_h } else { 1.0 }
  let scale = @cmp.minimum(1.0, @cmp.minimum(scale_x, scale_y))

  if req.style == "centered" {
    let center = {
      x: req.crop_x + req.page_width / 2.0,
      y: req.crop_y + req.page_height / 2.0,
    }
    return { scale, stamps: [center], columns: 1, rows: 1, }
  }

  let mark_w = box_w * scale
  let mark_h = box_h * scale
  let step_x = mark_w + req.margin_right
  let step_y = mark_h + req.margin_bottom
  let cols = if step_x > 0.0 {
    ((req.page_width - mark_w) / step_x).to_int() + 1
  } else {
    1
  }
  let rows = if step_y > 0.0 {
    ((req.page_height - mark_h) / step_y).to_int() + 1
  } else {
    1
  }

  let safe_cols = @cmp.maximum(1, @cmp.minimum(cols, 100))
  let safe_rows = @cmp.maximum(1, @cmp.minimum(rows, 100))
  let first_x = (req.page_width - (safe_cols - 1).to_double() * step_x) / 2.0
  let first_y = (req.page_height + (safe_rows - 1).to_double() * step_y) / 2.0

  let stamps : Array[StampCoord] = []
  for r = 0; r < safe_rows; r = r + 1 {
    for c = 0; c < safe_cols; c = c + 1 {
      let x = req.crop_x + first_x + c.to_double() * step_x
      let y = req.crop_y + first_y - r.to_double() * step_y
      stamps.push({ x, y, })
    }
  }

  { scale, stamps, columns: safe_cols, rows: safe_rows, }
}

///|
fn parse_positive_int(s : StringView) -> Int32 {
  let trimmed = s.trim()
  if trimmed.length() == 0 {
    return 0
  }
  let mut result = 0
  for ch in trimmed {
    let code = ch.to_int()
    if code >= 48 && code <= 57 {
      result = result * 10 + (code - 48)
    } else {
      return 0
    }
  }
  result
}

///|
#derive(FromJson, ToJson)
pub(all) struct PageRangeRequest {
  range_spec : String
  total_pages : Int32
}

///|
#derive(FromJson, ToJson)
pub(all) struct PageRangeReply {
  included : Array[Int32]
}

///|
pub fn parse_page_range(req : PageRangeRequest) -> PageRangeReply {
  let spec = req.range_spec.trim().to_lower()
  let total = req.total_pages
  if spec == "all" || spec == "" {
    let all_pages : Array[Int32] = []
    for i = 1; i <= total; i = i + 1 {
      all_pages.push(i)
    }
    return { included: all_pages, }
  }
  if spec == "skip-first" {
    let pages : Array[Int32] = []
    for i = 2; i <= total; i = i + 1 {
      pages.push(i)
    }
    return { included: pages, }
  }

  let included_map : Array[Bool] = Array::make(total + 1, false)
  let parts = spec.split(",")
  for part in parts {
    let dash = part.trim().split("-").collect()
    if dash.length() == 2 {
      let start = parse_positive_int(dash[0])
      let end = parse_positive_int(dash[1])
      if start > 0 && end > 0 {
        let from_p = @cmp.maximum(1, @cmp.minimum(start, end))
        let to_p = @cmp.minimum(total, @cmp.maximum(start, end))
        for p = from_p; p <= to_p; p = p + 1 {
          included_map[p] = true
        }
      }
    } else if dash.length() == 1 {
      let p = parse_positive_int(part)
      if p >= 1 && p <= total {
        included_map[p] = true
      }
    }
  }

  let included : Array[Int32] = []
  for i = 1; i <= total; i = i + 1 {
    if included_map[i] {
      included.push(i)
    }
  }
  if included.is_empty() {
    for i = 1; i <= total; i = i + 1 {
      included.push(i)
    }
  }
  { included, }
}
