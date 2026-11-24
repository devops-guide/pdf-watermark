///|
#derive(FromJson, ToJson)
pub(all) struct ApplyWatermarkRequest {
  watermark_type : String?
  text : String?
  image_path : String?
  font_size : Double?
  style : String?
  opacity : Double?
  rotate : Double?
  page_range : String?
  color_hex : String?
  scale : Double?
  scale_to_fit : Bool?
}

///|
#derive(FromJson, ToJson)
pub(all) struct ApplyWatermarkReply {
  output_path : String
  pages_count : Int32
}

///|
pub fn parse_colour_from_hex(hex_opt : String?) -> @colour.PdfContentColour {
  match hex_opt {
    Some(hex) => {
      let trimmed = hex.trim()
      let s = if trimmed.has_prefix("#") { trimmed[1:] } else { trimmed }
      if s.length() == 6 {
        let r = hex_pair_to_double(s[0:2])
        let g = hex_pair_to_double(s[2:4])
        let b = hex_pair_to_double(s[4:6])
        @colour.PdfContentColour::PdfContentRGB(r, g, b)
      } else {
        @colour.PdfContentColour::PdfContentRGB(0.8, 0.8, 0.8)
      }
    }
    None => @colour.PdfContentColour::PdfContentRGB(0.8, 0.8, 0.8)
  }
}

///|
fn hex_pair_to_double(s : StringView) -> Double {
  let mut val = 0
  for ch in s {
    let code = ch.to_int()
    let digit = if code >= 48 && code <= 57 {
      code - 48
    } else if code >= 65 && code <= 70 {
      code - 55
    } else if code >= 97 && code <= 102 {
      code - 87
    } else {
      0
    }
    val = val * 16 + digit
  }
  val.to_double() / 255.0
}

///|
pub async fn apply_watermark_to_file(
  source_path : String,
  destination_path : String,
  options : ApplyWatermarkRequest,
) -> ApplyWatermarkReply {
  let doc = @pdf_io.pdf_read_document_from_file(source_path)
  let pages = doc.pages_of_pagetree()
  let total_pages = pages.length()

  let range_req : PageRangeRequest = {
    range_spec: options.page_range.unwrap_or("all"),
    total_pages,
  }
  let parsed = parse_page_range(range_req)
  let page_numbers : Array[Int32] = []
  for p in parsed.included {
    page_numbers.push(p)
  }

  let watermark_type = options.watermark_type.unwrap_or("text")
  let is_image = watermark_type == "image" ||
    (options.image_path is Some(p) && p.length() > 0 && options.text is None)

  let watermarked = if is_image {
    let img_path = options.image_path.unwrap_or("")
    let ext = @path.Path(img_path).extname().to_lower()
    let stamp_raw = if ext == ".pdf" {
      @pdf_io.pdf_read_document_from_file(img_path)
    } else {
      let bytes = @fs.read_binary(img_path)
      if ext == ".png" {
        @pdflite.pdf_image_document_of_png_data(bytes[:])
      } else {
        @pdflite.pdf_image_document_of_jpeg_data(bytes[:])
      }
    }

    let scale_to_fit = options.scale_to_fit.unwrap_or(false)
    let stamp_doc = if scale_to_fit {
      stamp_raw
    } else {
      let stamp_pages = stamp_raw.pages_of_pagetree()
      let stamp_rect = stamp_raw.parse_rectangle(stamp_pages[0].mediabox)
      let stamp_w = stamp_rect.max_x - stamp_rect.min_x

      let target_page_rect = doc.parse_rectangle(pages[0].mediabox)
      let target_page_w = target_page_rect.max_x - target_page_rect.min_x

      let scale_ratio = options.scale.unwrap_or(0.35)
      let target_w = target_page_w * scale_ratio
      let actual_scale = if stamp_w > 0.0 { target_w / stamp_w } else { 1.0 }

      if actual_scale > 0.0 && actual_scale != 1.0 {
        stamp_raw.scale_pages([1][:], [(actual_scale, actual_scale)][:])
      } else {
        stamp_raw
      }
    }

    let style_str = options.style.unwrap_or("bottom-right")
    let position = match style_str {
      "bottom-right" =>
        @geometry.PdfPosition::PdfPositionBottomRight(30.0, 30.0)
      "bottom-left" => @geometry.PdfPosition::PdfPositionBottomLeft(30.0, 30.0)
      "top-right" => @geometry.PdfPosition::PdfPositionTopRight(30.0, 30.0)
      "top-left" => @geometry.PdfPosition::PdfPositionTopLeft(30.0, 30.0)
      "diagonal" => @geometry.PdfPosition::PdfPositionDiagonal
      _ => @geometry.PdfPosition::PdfPositionCentre
    }
    doc.stamp_pages(page_numbers[:], stamp_doc, position~, scale_to_fit~)
  } else {
    let font_data : @pdflite.PdfStandardFontData = {
      font: @pdflite.PdfHelvetica,
      encoding: @pdflite.PdfStandardEncoding,
    }
    let font : @pdflite.PdfFont = @pdflite.PdfFont::PdfFontStandard(font_data)

    let font_size = options.font_size.unwrap_or(48.0)
    let opacity = options.opacity.unwrap_or(0.4)
    let colour = parse_colour_from_hex(options.color_hex)
    let dummy_time = @pdf_date.pdf_strftime_dummy_time()
    let dummy_bookmarks : Array[@bookmark.PdfBookmark] = []

    let position = if options.style.unwrap_or("centered") == "centered" {
      @geometry.PdfPosition::PdfPositionCentre
    } else {
      @geometry.PdfPosition::PdfPositionDiagonal
    }

    let text = options.text.unwrap_or("WATERMARK")
    doc.addtexts_with_font(
      page_numbers[:],
      text,
      dummy_time,
      dummy_bookmarks[:],
      Some(font),
      None,
      font_data.font.pdf_name(),
      font_size,
      font_size * 1.25,
      colour,
      position,
      opacity~,
    )
  }

  @pdf_io.pdf_write_document_to_file(watermarked, destination_path)
  { output_path: destination_path, pages_count: total_pages, }
}
