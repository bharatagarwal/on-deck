import SwiftUI

struct TaskDock: View {
  let context: TaskCommandContext
  private let controlHeight: CGFloat = 38
  @Environment(\.taskMetrics) private var metrics

  var body: some View {
    GlassEffectContainer(spacing: metrics.length(8)) {
      HStack(spacing: metrics.length(12)) {
        HStack(spacing: 0) {
          control(.moveUp, icon: "arrow.up", shortcut: "⌘↑")
          control(.moveDown, icon: "arrow.down", shortcut: "⌘↓")
          Divider()
            .frame(height: metrics.length(15))
            .padding(.horizontal, metrics.length(3))
          control(.rename, icon: "pencil", shortcut: "⌘R")
        }
        .padding(.horizontal, metrics.length(5))
        .glassEffect(.regular.tint(QueuePalette.accent.opacity(0.12)), in: .capsule)

        NewTaskButton(height: controlHeight) { context.perform(.add) }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Task controls")
  }

  private func control(_ action: TaskAction, icon: String, shortcut: String) -> some View {
    let title = action.title(isComplete: context.isComplete)
    return Button {
      context.perform(action)
    } label: {
      Label(title, systemImage: icon)
        .labelStyle(.iconOnly)
        .font(.system(size: metrics.length(13), weight: .medium))
        .frame(width: metrics.length(36), height: metrics.length(controlHeight))
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(!action.isEnabled(at: context.index, count: context.count))
    .help("\(title) (\(shortcut))")
  }
}

struct NewTaskButton: View {
  var height: CGFloat = 28
  let action: () -> Void
  @Environment(\.taskMetrics) private var metrics

  var body: some View {
    Button(action: action) {
      Label("New Task", systemImage: "plus")
        .font(.system(size: metrics.length(12), weight: .semibold))
        .padding(.horizontal, metrics.length(20))
        .frame(height: metrics.length(height))
        .contentShape(.capsule)
    }
    .buttonStyle(.plain)
    .glassEffect(.regular.tint(QueuePalette.accent.opacity(0.18)).interactive(), in: .capsule)
    .help("New Task (⌘N)")
  }
}
