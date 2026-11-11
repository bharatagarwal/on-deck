// Renders build/icon.png (1024×1024) from the Mac app's icon layers. Run with `npm run icon`.
const { app, BrowserWindow } = require('electron');
const fs = require('node:fs');
const path = require('node:path');

const assets = path.join(__dirname, '..', '..', 'Iterate', 'AppIcon.icon', 'Assets');
const layer = (name) =>
  `data:image/svg+xml;base64,${fs.readFileSync(path.join(assets, name)).toString('base64')}`;

const html = `<!doctype html><html><body style="margin:0;background:transparent">
<div style="position:relative;width:1024px;height:1024px;overflow:hidden;border-radius:230px;
  background:linear-gradient(180deg, rgb(196,79,145), rgb(77,48,166))">
  <img src="${layer('BackCard.svg')}" style="position:absolute;inset:0;opacity:.82;
    filter:drop-shadow(0 18px 30px rgba(20,0,40,.38))">
  <img src="${layer('LeadCard.svg')}" style="position:absolute;inset:0;
    filter:drop-shadow(0 22px 34px rgba(20,0,40,.48))">
</div></body></html>`;

app.whenReady().then(async () => {
  const window = new BrowserWindow({
    width: 1024,
    height: 1024,
    show: false,
    transparent: true,
    frame: false,
    webPreferences: { offscreen: true },
  });
  await window.loadURL(`data:text/html;base64,${Buffer.from(html).toString('base64')}`);
  await new Promise((resolve) => setTimeout(resolve, 300));
  const image = await window.webContents.capturePage({ x: 0, y: 0, width: 1024, height: 1024 });
  const output = path.join(__dirname, '..', 'build', 'icon.png');
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, image.resize({ width: 1024, height: 1024 }).toPNG());
  console.log(`Wrote ${output}`);
  app.quit();
});
