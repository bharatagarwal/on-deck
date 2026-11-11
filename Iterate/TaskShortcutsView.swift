import SwiftUI

struct TaskShortcutsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.taskMetrics) private var metrics

  var body: some View {
    VStack(alignment: .leading, spacing: metrics.length(12)) {
      Text("Keyboard Shortcuts")
        .font(.system(size: metrics.length(13), weight: .semibold))
        .accessibilityAddTraits(.isHeader)

      Grid(
        alignment: .leading, horizontalSpacing: metrics.length(18),
        verticalSpacing: metrics.length(6)
      ) {
        shortcut("Select a task", keys: "↑ / ↓ or ⌘1–9")
        shortcut("Add a task", keys: TaskAction.add.shortcutLabel)
        shortcut("Rename a task", keys: TaskAction.rename.shortcutLabel)
        shortcut("Reorder", keys: "⌘ ↑ / ⌘ ↓")
        shortcut("Toggle done", keys: TaskAction.toggleCompletion.shortcutLabel)
        shortcut("Delete a task", keys: TaskAction.delete.shortcutLabel)
        shortcut("Zoom", keys: "⌘ + / ⌘ −")
      }

      Button("Done") { dismiss() }
        .font(.system(size: metrics.length(13)))
        .buttonStyle(.glass)
        .keyboardShortcut(.defaultAction)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .onExitCommand { dismiss() }
    .padding(metrics.length(20))
    .frame(width: metrics.length(282))
  }

  private func shortcut(_ title: String, keys: String) -> some View {
    GridRow {
      Text(title)
        .font(.system(size: metrics.length(12)))
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(keys)
        .font(.system(size: metrics.length(12), design: .monospaced))
        .foregroundStyle(.secondary)
        .gridColumnAlignment(.trailing)
    }
  }
}
