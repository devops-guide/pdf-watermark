///|
async fn main {
  let files = FileSession::new()
  @proton.asset("PDF 水印", "frontend/dist/index.html", width=940, height=700)
  ..config(@proton.load_config())
  ..single_instance()
  ..commands(registrar => files.bind(registrar))
  ..setup_window(context => context.add_cleanup(() => files.discard_export()))
  .run_or_abort()
}
