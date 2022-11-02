const path = require('path');
const { addWatermark } = require('../main');

addWatermark(path.join(__dirname, './input.pdf'), './output.pdf', {
  textSize: 150,
  rotate: 0,
  style: 'centered',
});
