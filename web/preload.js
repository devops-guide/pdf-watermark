const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
    choiceFile: () => ipcRenderer.invoke('dialog:choiceFile'),
    saveFile: (textOptions) => ipcRenderer.invoke('dialog:saveFile', textOptions)
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
