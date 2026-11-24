const path = require('node:path');
const { readFile, writeFile } = require('node:fs/promises');
const { watermarkPdf } = require('./watermark');

const fontPath = path.join(__dirname, 'fonts', 'Microsoft Yahei.ttf');

async function addWatermark(inputFilePath, outputFilePath, textOptions) {
  const [pdf, font] = await Promise.all([readFile(inputFilePath), readFile(fontPath)]);
  const result = await watermarkPdf(pdf, font, textOptions);
  await writeFile(outputFilePath, result);
}

module.exports = { addWatermark };
