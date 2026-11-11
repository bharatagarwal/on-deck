import SwiftUI

@main
struct IterateApp: App {
  @AppStorage("taskListZoomStep") private var zoomStep = 0
  @State private var store = TaskStore(fileURL: TaskStore.defaultFileURL)

  private var scale: CGFloat {
    TaskZoomAction.scale(for: zoomStep)
  }

  var body: some Scene {
    Window("On Deck", id: "tasks") {
      TaskListView(store: store, zoomStep: $zoomStep)
        .environment(\.taskScale, scale)
        .frame(minWidth: 300 * scale, maxWidth: 380 * scale, minHeight: 360 * scale)
        .background { TaskWindowZoom(scale: scale).allowsHitTesting(false) }
        .ignoresSafeArea(.container, edges: .top)
        .toolbarVisibility(.hidden, for: .windowToolbar)
    }
    .defaultSize(width: 340 * scale, height: 560 * scale)
    .windowResizability(.contentSize)
    .windowBackgroundDragBehavior(.enabled)
    .commands {
      TaskCommands()
    }
  }
}
