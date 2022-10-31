const { app, BrowserWindow, ipcMain, dialog } = require('electron')
const path = require('path')
const { addWatermark } = require('./main');

const createWindow = () => {
    const win = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            sandbox: false, // 为了能在 preload 中引用vue，这个方法不好
            preload: path.join(__dirname, './web/preload.js'),
        },
    })
    win.webContents.openDevTools()
    win.loadFile('index.html')
}
const filters = [
    { name: 'PDF', extensions: ['pdf'] },
];

let choiceFilePath;
async function choiceFile() {
    const { canceled, filePaths } = await dialog.showOpenDialog({ filters });
    if (canceled)
        return
    choiceFilePath = filePaths[0];
    return choiceFilePath;
}

async function dropFile(event, filePath) {
    choiceFilePath = filePath;
}

async function saveFile(event, text) {
    const { canceled, filePath } = await dialog.showSaveDialog({ filters })
    if (canceled)
        return
    addWatermark(choiceFilePath, filePath, { text });
    return filePath;
}

app.whenReady().then(() => {
    ipcMain.handle('dialog:choiceFile', choiceFile)
    ipcMain.handle('dialog:saveFile', saveFile)
    ipcMain.handle('dropFile', dropFile)
    createWindow()
})