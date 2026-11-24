///|
test "calculate_layout centered" {
  let req : @app.LayoutRequest = {
    style: "centered",
    page_width: 600.0,
    page_height: 800.0,
    crop_x: 0.0,
    crop_y: 0.0,
    stamp_width: 200.0,
    stamp_height: 50.0,
    rotate: 0.0,
    margin_right: 50.0,
    margin_bottom: 50.0,
  }
  let res = @app.calculate_layout(req)
  assert_eq(res.columns, 1)
  assert_eq(res.rows, 1)
  assert_eq(res.stamps.length(), 1)
  assert_eq(res.stamps[0].x, 300.0)
  assert_eq(res.stamps[0].y, 400.0)
}

///|
test "calculate_layout tiled" {
  let req : @app.LayoutRequest = {
    style: "tiled",
    page_width: 500.0,
    page_height: 500.0,
    crop_x: 0.0,
    crop_y: 0.0,
    stamp_width: 100.0,
    stamp_height: 50.0,
    rotate: 0.0,
    margin_right: 100.0,
    margin_bottom: 100.0,
  }
  let res = @app.calculate_layout(req)
  assert_true(res.columns >= 2)
  assert_true(res.rows >= 2)
  assert_true(res.stamps.length() >= 4)
}

///|
test "parse_page_range skip-first" {
  let req : @app.PageRangeRequest = {
    range_spec: "skip-first",
    total_pages: 5,
  }
  let res = @app.parse_page_range(req)
  assert_eq(res.included, [2, 3, 4, 5])
}

///|
test "parse_page_range custom range" {
  let req : @app.PageRangeRequest = { range_spec: "1-2, 4", total_pages: 5, }
  let res = @app.parse_page_range(req)
  assert_eq(res.included, [1, 2, 4])
}
