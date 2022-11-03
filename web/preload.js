const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  choiceFile: () => ipcRenderer.invoke('dialog:choiceFile'),
  saveFile: (textOptions) => ipcRenderer.invoke('dialog:saveFile', textOptions),
  openFolder: (fullPath) => ipcRenderer.invoke('openFolder', fullPath),
});
