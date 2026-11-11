import SwiftUI

struct TaskQueueRow<RenameField: View>: View {
  let task: TaskItem
  let index: Int
  let isSelected: Bool
  let isRenaming: Bool
  let toggleCompletion: () -> Void
  @ViewBuilder let renameField: () -> RenameField
  @Environment(\.taskMetrics) private var metrics

  var body: some View {
    HStack(spacing: metrics.length(10)) {
      Text((index + 1).formatted(.number.precision(.integerLength(2...))))
        .font(.system(size: metrics.length(12), weight: .semibold, design: .monospaced))
        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        .frame(minWidth: metrics.length(23), alignment: .leading)
        .accessibilityLabel("Priority \(index + 1)")

      completionButton
      if isRenaming {
        renameField()
      } else {
        title
      }
    }
    .frame(maxWidth: .infinity, minHeight: metrics.length(43), alignment: .leading)
    .padding(.horizontal, metrics.length(12))
    .background {
      Color.clear
        .glassEffect(rowGlass, in: .rect(cornerRadius: metrics.length(13)))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .overlay {
      if isSelected {
        RoundedRectangle(cornerRadius: metrics.length(13))
          .strokeBorder(QueuePalette.accent, lineWidth: metrics.length(1.5))
          .allowsHitTesting(false)
      }
    }
    .contentShape(.rect(cornerRadius: metrics.length(13)))
  }

  private var completionButton: some View {
    Button(action: toggleCompletion) {
      Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
        .font(.system(size: metrics.length(16), weight: .medium))
        .foregroundStyle(
          task.isComplete ? QueuePalette.accent : Color(nsColor: .secondaryLabelColor)
        )
        .frame(width: metrics.length(23), height: metrics.length(24))
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(
      task.isComplete ? "Mark “\(task.title)” incomplete" : "Mark “\(task.title)” complete"
    )
    .help(task.isComplete ? "Mark incomplete" : "Mark complete")
  }

  private var title: some View {
    Text(task.title)
      .font(.system(size: metrics.length(14), weight: .medium))
      .strikethrough(task.isComplete)
      .foregroundStyle(Color(nsColor: task.isComplete ? .secondaryLabelColor : .labelColor))
      .lineLimit(2)
  }

  private var rowGlass: Glass {
    .regular.tint(QueuePalette.accent.opacity(isSelected ? 0.23 : 0.09))
  }
}
