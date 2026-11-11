# On Deck

A narrow, native Mac task list that opens at 340 points wide. The top task has the highest priority. New tasks start at
the bottom, and completed tasks keep their position. Drag the header to move the
window, or press ⌘W to close it. Changes are saved locally in
`~/Library/Application Support/Iterate/Tasks.json`.

| Action | Shortcut |
| --- | --- |
| Show keyboard shortcuts | ? |
| Zoom the window in, out, or reset | ⌘+, ⌘−, or ⌘0 |
| Add a task in the window | ⌘N, then Return to add or Esc to cancel |
| Select a task | ↑ / ↓ or ⌘1–⌘9 |
| Raise or lower priority | ⌘↑ / ⌘↓ |
| Rename in place | ⌘R, then Return to save or Esc to cancel |
| Toggle completion | Space or Return |
| Delete | Delete, then confirm |

## Build and test

The app requires macOS 26 or later. Open `Iterate.xcodeproj` in Xcode and run
the Iterate scheme, or build the release app from this folder. The installed copy lives in `~/Applications`.

```sh
make build
open "build.noindex/Build/Products/Release/On Deck.app"
```

Run `make verify` with Xcode and SwiftLint installed to check formatting, lint
the Swift code, run the UI tests in a logged-in desktop session, and build the
release app. Run `make format` to apply the formatter. The automated UI tests
bring the debug app to the foreground and use temporary task storage.

If you edit `project.yml`, regenerate the Xcode project with `xcodegen generate`.

## Windows (Electron)

`electron/` holds a Windows version of the app built with Electron. It has the same features and layout,
follows Windows shortcut conventions, and stores tasks in the same JSON format at
`%APPDATA%\Iterate\Tasks.json`.

| Action | Windows shortcut |
| --- | --- |
| Show keyboard shortcuts | F1 or ? |
| Zoom in, out, or reset | Ctrl+Plus, Ctrl+Minus, Ctrl+0, or Ctrl+mouse wheel |
| Add a task | Ctrl+N, then Enter to add or Esc to cancel |
| Select a task | Up / Down, Home / End |
| Raise or lower priority | Ctrl+Up / Ctrl+Down (or Alt+Up / Alt+Down) |
| Rename in place | F2, then Enter to save or Esc to cancel |
| Toggle completion | Space or Enter |
| Delete | Del, then confirm |
| Close | Alt+F4 or Ctrl+W |

The half-circle button in the title bar switches the style: **Liquid Glass** (default; an SVG refraction
filter in `src/lens.js` bends the backdrop at each surface's rim), **Frosted Glass**, and the Windows 11
system materials **Acrylic** and **Mica** (Windows 11 22H2 or later; on a Mac they preview as vibrancy).

```sh
cd electron
npm install
npm start          # run it locally
npm run dist:win   # build dist/On-Deck-Setup-1.0.0.exe and dist/On-Deck-1.0.0-Portable.exe
```

The portable `.exe` runs without installing. The setup `.exe` installs per user with a Start menu shortcut.
Both are unsigned, so Windows SmartScreen asks users to choose **More info → Run anyway** the first time.
Run `npm run icon` to regenerate `build/icon.png` from the Mac icon layers. On a Mac, running `npm start`
reads and writes the same `Tasks.json` as the native app; set `ITERATE_TEST_STORAGE` to a folder to use test data,
and `ON_DECK_PREVIEW_PLATFORM=win32` to preview the Windows shortcuts and title bar.
