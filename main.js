const fs = require('fs');
const path = require('path');
const fontkit = require('@pdf-lib/fontkit');
const { PDFDocument, rgb, degrees } = require('pdf-lib');

const fontBytes = fs.readFileSync(path.join(__dirname, './fonts/Microsoft Yahei.ttf'));

const defaultTextOptions = {
  marginBottom: 50,
  marginRight: 50,
  textSize: 30,
  opacity: 0.4,
  color: rgb(228 / 255.0, 228 / 255.0, 228 / 255.0),
  rotate: -45,
  text: '仅限XXX内部使用',
};

async function addWatermark(inputFilePath, outputFilePath, textOptions) {
  const options = { ...defaultTextOptions, ...textOptions };

  const uint8Array = fs.readFileSync(inputFilePath);
  const pdfDoc = await PDFDocument.load(uint8Array);
  pdfDoc.registerFontkit(fontkit);

  const chineseFonts = await pdfDoc.embedFont(fontBytes);
  const pages = pdfDoc.getPages();

  const textWidth = chineseFonts.widthOfTextAtSize(options.text, options.textSize) + options.marginRight;
  const textHeight = chineseFonts.heightAtSize(options.textSize) + options.marginBottom;

  pages.forEach((onePage) => {
    const { width, height } = onePage.getSize();

    for (let j = 0; j < (width / textWidth); j++) {
      for (let i = 0; i < (height / textHeight); i++) {
        onePage.drawText(options.text, {
          x: j * textWidth,
          y: height - i * textHeight,
          size: options.textSize,
          font: chineseFonts,
          opacity: Number(options.opacity),
          color: options.color,
          rotate: degrees(Number(options.rotate)),
        });
      }
    }
  });

  const pdfBytes = await pdfDoc.save();
  fs.writeFileSync(outputFilePath, pdfBytes);
}

module.exports = {
  addWatermark,
};
