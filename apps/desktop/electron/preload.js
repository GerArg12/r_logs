const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('rLogsDesktop', {
  selectLogFile: () => ipcRenderer.invoke('select-log-file')
});

window.addEventListener('DOMContentLoaded', () => {
  document.body.dataset.shell = 'electron';
});
