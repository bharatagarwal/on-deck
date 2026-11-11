const { contextBridge, ipcRenderer } = require('electron');

const info = ipcRenderer.sendSync('app:info');

contextBridge.exposeInMainWorld('onDeck', {
  platform: info.platform,
  material: info.material,
  showMaterialMenu: (position) => ipcRenderer.send('material:menu', position),
  onMaterialChange: (callback) =>
    ipcRenderer.on('material:changed', (_event, material) => callback(material)),
  load: () => ipcRenderer.invoke('tasks:load'),
  save: (tasks) => ipcRenderer.invoke('tasks:save', tasks),
  setZoom: (step) => ipcRenderer.invoke('zoom:set', step),
  minimize: () => ipcRenderer.send('window:minimize'),
  close: () => ipcRenderer.send('window:close'),
  showContextMenu: (items) => ipcRenderer.send('context-menu:show', items),
  onContextAction: (callback) =>
    ipcRenderer.on('context-menu:action', (_event, id) => callback(id)),
});
