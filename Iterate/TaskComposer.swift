import SwiftUI

struct TaskComposer: View {
  @Binding var title: String
  let submit: () -> Void
  let cancel: () -> Void
  @Environment(\.taskMetrics) private var metrics

  var body: some View {
    VStack(alignment: .leading, spacing: metrics.length(8)) {
      Text("New task")
        .font(.system(size: metrics.length(11), weight: .semibold, design: .monospaced))
        .foregroundStyle(.secondary)
        .accessibilityAddTraits(.isHeader)

      HStack(spacing: metrics.length(6)) {
        TaskInputField(
          title: $title, placeholder: "What needs doing?", identifier: "task-title",
          submit: submit, cancel: cancel
        )
        .frame(maxWidth: .infinity)

        Button("Cancel", systemImage: "xmark", action: cancel)
          .help("Cancel (Esc)")
        Button("Add Task", systemImage: "checkmark", action: submit)
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .help("Add Task (Return)")
      }
      .font(.system(size: metrics.length(13)))
      .labelStyle(.iconOnly)
      .buttonStyle(.borderless)
    }
    .padding(metrics.length(12))
    .glassEffect(
      .regular.tint(QueuePalette.accent.opacity(0.11)), in: .rect(cornerRadius: metrics.length(16)))
  }
}
