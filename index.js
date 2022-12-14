const path = require('path');
const { env } = require('node:process');
const {
  app, BrowserWindow, ipcMain, dialog, shell,
} = require('electron');
const { addWatermark } = require('./main');

const createWindow = () => {
  const win = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      preload: path.join(__dirname, './web/preload.js'),
    },
  });
  if (env.debug) {
    win.webContents.openDevTools();
  }
  win.loadFile('index.html');
};
const filters = [
  { name: 'PDF', extensions: ['pdf'] },
];

const DEFAULT_SUFFIX = '-watermark.pdf';

async function choiceFile() {
  const { canceled, filePaths } = await dialog.showOpenDialog({ filters });
  if (canceled) return;
  const [choiceFilePath] = filePaths;
  return choiceFilePath;
}

async function saveFile(event, textOptions) {
  const { inputFilePath } = textOptions;
  const defaultPath = `${path.basename(textOptions.inputFilePath, '.pdf')}${DEFAULT_SUFFIX}`;
  const { canceled, filePath } = await dialog.showSaveDialog({ filters, defaultPath });
  if (canceled) return;
  await addWatermark(inputFilePath, filePath, textOptions);
  return filePath;
}

async function openFolder(event, fullPath) {
  shell.showItemInFolder(fullPath);
}

app.whenReady().then(() => {
  ipcMain.handle('dialog:choiceFile', choiceFile);
  ipcMain.handle('dialog:saveFile', saveFile);
  ipcMain.handle('openFolder', openFolder);
  createWindow();
});

app.on('window-all-closed', () => {
  app.quit();
});
