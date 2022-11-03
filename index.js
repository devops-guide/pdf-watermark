const path = require('path');
const { env } = require('node:process');
const {
  app, BrowserWindow, ipcMain, dialog, shell
} = require('electron');
const { addWatermark } = require('./main');

const createWindow = () => {
  const win = new BrowserWindow({
    width: 800,
    height: 500,
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

let choiceFilePath;
async function choiceFile() {
  const { canceled, filePaths } = await dialog.showOpenDialog({ filters });
  if (canceled) return;
  ([choiceFilePath] = filePaths);
  return choiceFilePath;
}

async function dropFile(event, filePath) {
  choiceFilePath = filePath;
}

async function saveFile(event, textOptions) {
  const { canceled, filePath } = await dialog.showSaveDialog({ filters });
  if (canceled) return;
  addWatermark(choiceFilePath, filePath, textOptions);
  return filePath;
}

async function openFolder(event, fullPath) {
  shell.showItemInFolder(fullPath);
}

app.whenReady().then(() => {
  ipcMain.handle('dialog:choiceFile', choiceFile);
  ipcMain.handle('dialog:saveFile', saveFile);
  ipcMain.handle('dropFile', dropFile);
  ipcMain.handle('openFolder', openFolder);
  createWindow();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
