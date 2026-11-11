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
