const { app, BrowserWindow, Menu, ipcMain, nativeTheme, screen } = require('electron');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const BASE = { width: 340, height: 560, minWidth: 300, maxWidth: 380, minHeight: 360 };
const ZOOM_STEPS = { min: -2, max: 6 };
const UNBOUNDED = 100000;

let win = null;
const MATERIALS = ['liquid', 'frosted', 'acrylic', 'mica'];
let settings = { zoomStep: 0, material: 'liquid' };

// ON_DECK_PREVIEW_PLATFORM=win32 shows the Windows labels and controls on a Mac.
const platform = process.env.ON_DECK_PREVIEW_PLATFORM || process.platform;

// Acrylic and Mica need Windows 11 22H2 (build 22621) or later. On a Mac they preview as vibrancy.
function supportsNativeMaterial() {
  if (process.platform === 'darwin') return true;
  if (process.platform !== 'win32') return false;
  return Number(os.release().split('.')[2]) >= 22621;
}

function effectiveMaterial() {
  const { material } = settings;
  if ((material === 'acrylic' || material === 'mica') && !supportsNativeMaterial()) return 'frosted';
  return material;
}

function opaqueBackground() {
  return nativeTheme.shouldUseDarkColors ? '#1e1e1e' : '#ffffff';
}

function applyMaterial(window) {
  const material = effectiveMaterial();
  const isNative = material === 'acrylic' || material === 'mica';
  if (process.platform === 'win32') {
    window.setBackgroundMaterial(isNative ? material : 'none');
  } else if (process.platform === 'darwin') {
    window.setVibrancy(isNative ? (material === 'acrylic' ? 'hud' : 'under-window') : null);
  }
  window.setBackgroundColor(isNative ? '#00000000' : opaqueBackground());
}
let loadError = null;

const boundedStep = (step) =>
  Math.min(Math.max(Math.round(Number(step) || 0), ZOOM_STEPS.min), ZOOM_STEPS.max);
const scaleFor = (step) => 1 + boundedStep(step) / 10;

// Shares the macOS app's location and JSON format (~/Library/Application Support/Iterate on a Mac,
// %APPDATA%\Iterate on Windows).
function tasksFile() {
  const directory = process.env.ITERATE_TEST_STORAGE || path.join(app.getPath('appData'), 'Iterate');
  return path.join(directory, 'Tasks.json');
}

function settingsFile() {
  return path.join(app.getPath('userData'), 'settings.json');
}

function writeAtomically(file, contents) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const temporary = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(temporary, contents);
  fs.renameSync(temporary, file);
}

function isTaskList(value) {
  return (
    Array.isArray(value) &&
    value.every(
      (task) =>
        task &&
        typeof task.id === 'string' &&
        typeof task.title === 'string' &&
        (task.isComplete === undefined || typeof task.isComplete === 'boolean')
    )
  );
}

function loadTasks() {
  try {
    const parsed = JSON.parse(fs.readFileSync(tasksFile(), 'utf8'));
    if (!isTaskList(parsed)) throw new Error('The task file isn’t in the expected format.');
    loadError = null;
    return parsed.map(({ id, title, isComplete }) => ({ id, title, isComplete: Boolean(isComplete) }));
  } catch (error) {
    if (error.code === 'ENOENT') return [];
    loadError = `${tasksFile()} couldn’t be read. ${error.message}`;
    return [];
  }
}

function readSettings() {
  try {
    const parsed = JSON.parse(fs.readFileSync(settingsFile(), 'utf8'));
    settings = {
      zoomStep: boundedStep(parsed.zoomStep),
      material: MATERIALS.includes(parsed.material) ? parsed.material : 'liquid',
    };
  } catch {
    settings = { zoomStep: 0, material: 'liquid' };
  }
}

function writeSettings() {
  try {
    writeAtomically(settingsFile(), JSON.stringify(settings));
  } catch {
    // The setting still applies for this session.
  }
}

function applySizeLimits(window, scale) {
  window.setMinimumSize(Math.round(BASE.minWidth * scale), Math.round(BASE.minHeight * scale));
  window.setMaximumSize(Math.round(BASE.maxWidth * scale), UNBOUNDED);
}

function rescaleWindow(window, previousScale, scale) {
  window.webContents.setZoomFactor(scale);
  const bounds = window.getBounds();
  const area = screen.getDisplayMatching(bounds).workArea;
  const width = Math.min(Math.round((bounds.width / previousScale) * scale), area.width);
  const height = Math.min(Math.round((bounds.height / previousScale) * scale), area.height);
  const centerX = bounds.x + bounds.width / 2;
  const x = Math.min(Math.max(Math.round(centerX - width / 2), area.x), area.x + area.width - width);
  const y = Math.min(Math.max(bounds.y, area.y), area.y + area.height - height);

  // Lift the limits so the new size isn't clamped by the old ones.
  window.setMinimumSize(1, 1);
  window.setMaximumSize(UNBOUNDED, UNBOUNDED);
  window.setBounds({ x, y, width, height });
  applySizeLimits(window, scale);
}

function createWindow() {
  const scale = scaleFor(settings.zoomStep);
  win = new BrowserWindow({
    width: Math.round(BASE.width * scale),
    height: Math.round(BASE.height * scale),
    minWidth: Math.round(BASE.minWidth * scale),
    maxWidth: Math.round(BASE.maxWidth * scale),
    minHeight: Math.round(BASE.minHeight * scale),
    title: 'On Deck',
    frame: false,
    maximizable: false,
    fullscreenable: false,
    show: false,
    backgroundColor: opaqueBackground(),
    icon: path.join(__dirname, '..', 'build', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: true,
    },
  });

  applyMaterial(win);
  win.webContents.on('did-finish-load', () => {
    win.webContents.setZoomFactor(scaleFor(settings.zoomStep));
    win.webContents.setVisualZoomLevelLimits(1, 1);
  });
  win.once('ready-to-show', () => win.show());
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', (event) => event.preventDefault());
  win.on('closed', () => {
    win = null;
  });
  win.loadFile(path.join(__dirname, 'index.html'));
}

ipcMain.on('app:info', (event) => {
  event.returnValue = { platform, material: effectiveMaterial() };
});

ipcMain.handle('tasks:load', () => {
  const tasks = loadTasks();
  return { tasks, error: loadError, zoomStep: settings.zoomStep };
});

ipcMain.on('material:menu', (event, position) => {
  const window = BrowserWindow.fromWebContents(event.sender);
  const native = supportsNativeMaterial();
  const current = effectiveMaterial();
  const choose = (material) => () => {
    settings.material = material;
    writeSettings();
    if (window) applyMaterial(window);
    event.sender.send('material:changed', effectiveMaterial());
  };
  const item = (material, label, enabled = true) => ({
    label,
    type: 'radio',
    checked: current === material,
    enabled,
    click: choose(material),
  });
  const nativeNote = native ? '' : ' (Windows 11 only)';
  Menu.buildFromTemplate([
    { label: 'Style', enabled: false },
    item('liquid', 'Liquid Glass'),
    item('frosted', 'Frosted Glass'),
    { type: 'separator' },
    item('acrylic', `Acrylic${nativeNote}`, native),
    item('mica', `Mica${nativeNote}`, native),
  ]).popup({
    window,
    // The page reports CSS pixels; the menu needs window points.
    x: Math.round((position?.x ?? 0) * event.sender.getZoomFactor()),
    y: Math.round((position?.y ?? 0) * event.sender.getZoomFactor()),
  });
});

ipcMain.handle('tasks:save', (_event, tasks) => {
  try {
    if (loadError) throw new Error(loadError);
    if (!isTaskList(tasks)) throw new Error('The tasks couldn’t be saved because they were malformed.');
    writeAtomically(tasksFile(), JSON.stringify(tasks));
    return { ok: true };
  } catch (error) {
    return { ok: false, error: error.message };
  }
});

ipcMain.handle('zoom:set', (event, step) => {
  const window = BrowserWindow.fromWebContents(event.sender);
  const previousScale = scaleFor(settings.zoomStep);
  settings.zoomStep = boundedStep(step);
  writeSettings();
  if (window) rescaleWindow(window, previousScale, scaleFor(settings.zoomStep));
  return settings.zoomStep;
});

ipcMain.on('window:minimize', (event) => BrowserWindow.fromWebContents(event.sender)?.minimize());
ipcMain.on('window:close', (event) => BrowserWindow.fromWebContents(event.sender)?.close());

ipcMain.on('context-menu:show', (event, items) => {
  const window = BrowserWindow.fromWebContents(event.sender);
  const template = items.map((item) =>
    item.separator
      ? { type: 'separator' }
      : {
          label: item.label,
          enabled: item.enabled,
          click: () => event.sender.send('context-menu:action', item.id),
        }
  );
  Menu.buildFromTemplate(template).popup({ window });
});

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on('second-instance', () => {
    if (!win) return;
    if (win.isMinimized()) win.restore();
    win.focus();
  });

  app.whenReady().then(() => {
    // Shortcuts are handled by the page; the default menu would claim Ctrl+R, Ctrl+W, and zoom.
    Menu.setApplicationMenu(null);
    if (process.platform === 'win32') app.setAppUserModelId('local.iterate.tasks');
    readSettings();
    createWindow();
    nativeTheme.on('updated', () => win && applyMaterial(win));
  });

  app.on('window-all-closed', () => app.quit());
}
