const fontkit = require('@pdf-lib/fontkit');
const { PDFDocument, rgb, degrees } = require('pdf-lib');

const defaults = {
  marginRight: 50,
  marginBottom: 50,
  textSize: 30,
  opacity: 0.4,
  color: rgb(228 / 255, 228 / 255, 228 / 255),
  rotate: -45,
  text: '仅限XXX内部使用',
};

function applyToPage(page, options, font, metrics) {
  const { x, y, width, height } = page.getCropBox();
  const { style, text, textSize, opacity, color, rotate, marginRight, marginBottom } = options;
  const { textWidth, textHeight, descent, sin, cos } = metrics;
  const stampWidth = textWidth * Math.abs(cos) + textHeight * Math.abs(sin);
  const stampHeight = textWidth * Math.abs(sin) + textHeight * Math.abs(cos);
  const scale = Math.min(1, width * 0.97 / stampWidth, height * 0.97 / stampHeight);
  const size = textSize * scale;
  const centerX = textWidth * scale / 2;
  const centerY = (textHeight / 2 - descent) * scale;

  function drawAt(centerXOnPage, centerYOnPage) {
    page.drawText(text, {
      x: x + centerXOnPage - centerX * cos + centerY * sin,
      y: y + centerYOnPage - centerX * sin - centerY * cos,
      size,
      font,
      opacity,
      color,
      rotate: degrees(rotate),
    });
  }

  if (style === 'centered') {
    drawAt(width / 2, height / 2);
    return;
  }

  const markWidth = stampWidth * scale;
  const markHeight = stampHeight * scale;
  const stepX = markWidth + marginRight;
  const stepY = markHeight + marginBottom;
  const columns = Math.floor((width - markWidth) / stepX) + 1;
  const rows = Math.floor((height - markHeight) / stepY) + 1;
  if (columns * rows > 10000) {
    throw new Error('平铺水印过密，请增大字号或间距。');
  }

  // Center the grid on the visible page, including pages with a cropped origin.
  const firstX = (width - (columns - 1) * stepX) / 2;
  const firstY = (height + (rows - 1) * stepY) / 2;
  for (let row = 0; row < rows; row++) {
    for (let column = 0; column < columns; column++) {
      drawAt(firstX + column * stepX, firstY - row * stepY);
    }
  }
}

async function watermarkPdf(pdfBytes, fontBytes, textOptions = {}) {
  const options = { ...defaults, ...textOptions };
  for (const key of ['textSize', 'opacity', 'rotate', 'marginRight', 'marginBottom']) {
    options[key] = Number(options[key]);
  }

  if (!['tiled', 'centered'].includes(options.style)) {
    throw new Error('水印样式无效。');
  }
  if (typeof options.text !== 'string' || !options.text.trim()) {
    throw new Error('请输入水印文字。');
  }
  const { text, textSize, opacity, rotate, marginRight, marginBottom } = options;
  if (![textSize, opacity, rotate, marginRight, marginBottom].every(Number.isFinite)
    || textSize <= 0 || opacity < 0 || opacity > 1 || marginRight < 0 || marginBottom < 0) {
    throw new Error('水印参数无效。');
  }

  const pdf = await PDFDocument.load(pdfBytes);
  pdf.registerFontkit(fontkit);
  const font = await pdf.embedFont(fontBytes, { subset: true });
  const angle = rotate * Math.PI / 180;
  const textHeight = font.heightAtSize(textSize);
  const metrics = {
    textWidth: font.widthOfTextAtSize(text, textSize),
    textHeight,
    descent: textHeight - font.heightAtSize(textSize, { descender: false }),
    sin: Math.sin(angle),
    cos: Math.cos(angle),
  };

  for (const page of pdf.getPages()) {
    applyToPage(page, options, font, metrics);
  }
  return pdf.save();
}

module.exports = { watermarkPdf };
