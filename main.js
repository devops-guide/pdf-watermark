import fs from 'fs';
import fontkit from '@pdf-lib/fontkit';
import { PDFDocument, rgb, degrees } from 'pdf-lib';

const uint8Array = fs.readFileSync('./input.pdf')
const fontBytes = fs.readFileSync('./fonts/Microsoft Yahei.ttf')
const WATERMARK_TEXT = '仅供XXX内部使用';

const textOptions = {
    marginBottom: 50,
    marginRight: 50,
    textSize: 30,
    opacity: 0.4,
    color: rgb(228/255.0, 228/255.0, 228/255.0),
};

const pdfDoc = await PDFDocument.load(uint8Array);
pdfDoc.registerFontkit(fontkit);

const chineseFonts = await pdfDoc.embedFont(fontBytes);
const pages = pdfDoc.getPages();

const textWidth = chineseFonts.widthOfTextAtSize(WATERMARK_TEXT, textOptions.textSize) + textOptions.marginRight;
const textHeight = chineseFonts.heightAtSize(textOptions.textSize) + textOptions.marginBottom;


pages.forEach(onePage => {
    const { width, height } = onePage.getSize();
    
    for (let j = 0; j < (width / textWidth); j++) {
        for (let i = 0; i < (height / textHeight); i++) {
            onePage.drawText(WATERMARK_TEXT, {
                x: j * textWidth,
                y: height - i * textHeight,
                size: textOptions.textSize,
                font: chineseFonts,
                opacity: textOptions.opacity,
                color: textOptions.color,
                rotate: degrees(-45),
            })
        }
    }
})

const pdfBytes = await pdfDoc.save();
fs.writeFileSync('./output.pdf', pdfBytes);
