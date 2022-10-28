const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  choiceFile: () => ipcRenderer.invoke('dialog:choiceFile'),
  saveFile: (text) => ipcRenderer.invoke('dialog:saveFile', text)
})

// document.addEventListener('drop', (e) => {
//   e.preventDefault();
//   e.stopPropagation();

//   for (const f of e.dataTransfer.files) {
//     console.log('File(s) you dragged here: ', f.path)
//   }
// });

// document.addEventListener('dragover', (e) => {
//   e.preventDefault();
//   e.stopPropagation();
// });



