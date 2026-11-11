import AppKit
import SwiftUI

struct TaskInputField: NSViewRepresentable {
  @Binding var title: String
  let placeholder: String
  let identifier: String
  let submit: () -> Void
  let cancel: () -> Void

  func makeNSView(context: Context) -> NSTextField {
    let field = AutofocusingTextField()
    field.stringValue = title
    field.placeholderString = placeholder
    field.font = .systemFont(ofSize: context.environment.taskMetrics.length(NSFont.systemFontSize))
    field.setAccessibilityLabel("Task title")
    field.setAccessibilityIdentifier(identifier)
    field.isEditable = true
    field.isSelectable = true
    field.isBezeled = true
    field.bezelStyle = .roundedBezel
    field.drawsBackground = true
    field.usesSingleLineMode = true
    field.cell?.wraps = false
    field.cell?.isScrollable = true
    field.delegate = context.coordinator
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return field
  }

  func updateNSView(_ field: NSTextField, context: Context) {
    context.coordinator.view = self
    let font = NSFont.systemFont(
      ofSize: context.environment.taskMetrics.length(NSFont.systemFontSize))
    if field.font != font {
      field.font = font
      field.currentEditor()?.font = font
    }
    if field.stringValue != title {
      field.stringValue = title
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(view: self)
  }

  @MainActor
  final class Coordinator: NSObject, NSTextFieldDelegate {
    var view: TaskInputField

    init(view: TaskInputField) {
      self.view = view
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let field = notification.object as? NSTextField else { return }
      view.title = field.stringValue
    }

    func control(
      _ control: NSControl, textView: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
      switch selector {
      case #selector(NSResponder.insertNewline(_:)):
        view.title = textView.string
        view.submit()
      case #selector(NSResponder.cancelOperation(_:)):
        view.cancel()
      default:
        return false
      }
      return true
    }
  }

  private final class AutofocusingTextField: NSTextField {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window else { return }

      // Hand off focus after the hosting view has installed the field.
      DispatchQueue.main.async { [weak self, weak window] in
        guard let self, let window, self.window === window, window.makeFirstResponder(self) else {
          return
        }
        self.selectText(nil)
      }
    }
  }
}
