const { watermarkPdf } = require('../watermark');

let font;

self.addEventListener('message', async ({ data: { pdf, options } }) => {
  try {
    if (!font) {
      const response = await fetch('./watermark.ttf');
      if (!response.ok) throw new Error('无法读取水印字体。');
      font = new Uint8Array(await response.arrayBuffer());
    }
    const bytes = await watermarkPdf(pdf, font, options);
    self.postMessage({ bytes }, [bytes.buffer]);
  } catch (error) {
    self.postMessage({ error: error.message });
  }
});
