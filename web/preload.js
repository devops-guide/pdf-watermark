const { contextBridge, ipcRenderer } = require('electron')
const { createApp } = require('vue')

contextBridge.exposeInMainWorld('electronAPI', {
    choiceFile: () => ipcRenderer.invoke('dialog:choiceFile'),
    saveFile: (text) => ipcRenderer.invoke('dialog:saveFile', text)
})

document.addEventListener('drop', async(e) => {
    e.preventDefault();
    e.stopPropagation();

    const [file] = e.dataTransfer.files;
    await ipcRenderer.invoke('dropFile', file.path);
});

document.addEventListener('dragover', (e) => {
    e.preventDefault();
    e.stopPropagation();
});

window.addEventListener('DOMContentLoaded', () => {
    createApp({
        data() {
          return {
            message: 'Hello Vue!'
          }
        }
    }).mount('#app')
  })