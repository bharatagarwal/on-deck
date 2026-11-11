import AppKit
import SwiftUI

struct TaskListFocus: NSViewRepresentable {
  let canFocus: () -> Bool

  func makeNSView(context: Context) -> FocusAnchor {
    let anchor = FocusAnchor()
    anchor.canFocus = canFocus
    return anchor
  }

  func updateNSView(_ anchor: FocusAnchor, context: Context) {
    anchor.canFocus = canFocus
  }

  final class FocusAnchor: NSView {
    var canFocus: () -> Bool = { false }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window else { return }

      // A titleless window can open without placing its list in the responder chain.
      DispatchQueue.main.async { [weak self, weak window] in
        guard let self, let window, self.window === window,
          let content = window.contentView, let list = self.firstList(in: content)
        else { return }

        list.selectionHighlightStyle = .none
        if self.canFocus() {
          window.makeFirstResponder(list)
        }
      }
    }

    private func firstList(in view: NSView) -> NSTableView? {
      if let table = view as? NSTableView { return table }
      return view.subviews.lazy.compactMap { self.firstList(in: $0) }.first
    }
  }
}
