import SwiftUI

enum TaskAction: Identifiable {
  case add
  case rename
  case toggleCompletion
  case moveUp
  case moveDown
  case delete

  var id: Self { self }

  var shortcut: KeyboardShortcut {
    switch self {
    case .add: KeyboardShortcut("n")
    case .rename: KeyboardShortcut("r")
    case .toggleCompletion: KeyboardShortcut(.return, modifiers: [])
    case .moveUp: KeyboardShortcut(.upArrow)
    case .moveDown: KeyboardShortcut(.downArrow)
    case .delete: KeyboardShortcut(.delete, modifiers: [])
    }
  }

  var shortcutLabel: String {
    switch shortcut.key {
    case .return: "Space / Return"
    case .upArrow: "⌘ ↑"
    case .downArrow: "⌘ ↓"
    case .delete: "Delete"
    default: "⌘ \(shortcut.key.character.uppercased())"
    }
  }

  func title(isComplete: Bool) -> String {
    switch self {
    case .add: "New Task"
    case .rename: "Rename Task"
    case .toggleCompletion: isComplete ? "Mark Incomplete" : "Mark Complete"
    case .moveUp: "Raise Priority"
    case .moveDown: "Lower Priority"
    case .delete: "Delete Task"
    }
  }

  func isEnabled(at index: Int?, count: Int) -> Bool {
    switch self {
    case .add: true
    case .rename, .toggleCompletion, .delete: index != nil
    case .moveUp: index.map { $0 > 0 } ?? false
    case .moveDown: index.map { $0 + 1 < count } ?? false
    }
  }
}

enum TaskZoomAction: CaseIterable, Identifiable {
  case increase
  case decrease
  case reset

  private static let steps = -2...6

  static func bounded(_ step: Int) -> Int {
    min(max(step, steps.lowerBound), steps.upperBound)
  }

  static func scale(for step: Int) -> CGFloat {
    1 + CGFloat(bounded(step)) / 10
  }

  var id: Self { self }

  var title: String {
    switch self {
    case .increase: "Zoom In"
    case .decrease: "Zoom Out"
    case .reset: "Actual Size"
    }
  }

  var key: KeyEquivalent {
    switch self {
    case .increase: "+"
    case .decrease: "-"
    case .reset: "0"
    }
  }

  func target(from step: Int) -> Int {
    switch self {
    case .increase: min(step + 1, Self.steps.upperBound)
    case .decrease: max(step - 1, Self.steps.lowerBound)
    case .reset: 0
    }
  }
}

struct TaskZoomContext {
  let step: Int
  let perform: (TaskZoomAction) -> Void
}

struct TaskCommandContext {
  let index: Int?
  let count: Int
  let isComplete: Bool
  let perform: (TaskAction) -> Void
  let showShortcuts: () -> Void
  let goToTask: (Int) -> Void
}

extension FocusedValues {
  @Entry var taskCommands: TaskCommandContext?
  @Entry var taskZoom: TaskZoomContext?
}

struct TaskCommands: Commands {
  @FocusedValue(\.taskCommands) private var context
  @FocusedValue(\.taskZoom) private var zoom

  var body: some Commands {
    CommandMenu("Task") {
      command(.add)
      command(.rename)
      command(.toggleCompletion)
      Divider()
      command(.moveUp)
      command(.moveDown)
      Divider()
      command(.delete)
      Menu("Go to Task") {
        ForEach(1...9, id: \.self) { position in
          Button("Task \(position)") { context?.goToTask(position) }
            .keyboardShortcut(KeyEquivalent(Character(String(position))))
            .disabled(position > (context?.count ?? 0))
        }
      }
      .disabled((context?.count ?? 0) == 0)
    }
    CommandGroup(after: .toolbar) {
      ForEach(TaskZoomAction.allCases) { action in
        Button(action.title) { zoom?.perform(action) }
          .keyboardShortcut(action.key)
          .disabled(zoom.map { action.target(from: $0.step) == $0.step } ?? true)
      }
    }
    CommandGroup(after: .help) {
      Button("Keyboard Shortcuts") { context?.showShortcuts() }
        .keyboardShortcut("?", modifiers: [])
        .disabled(context == nil)
    }
  }

  private func command(_ action: TaskAction) -> some View {
    Button(action.title(isComplete: context?.isComplete ?? false)) {
      context?.perform(action)
    }
    .keyboardShortcut(action.shortcut)
    .disabled(context.map { !action.isEnabled(at: $0.index, count: $0.count) } ?? true)
  }
}
