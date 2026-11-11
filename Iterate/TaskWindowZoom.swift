import AppKit
import SwiftUI

struct TaskWindowZoom: NSViewRepresentable {
  let scale: CGFloat

  func makeNSView(context: Context) -> ZoomAnchor {
    ZoomAnchor(scale: scale)
  }

  func updateNSView(_ anchor: ZoomAnchor, context: Context) {
    anchor.updateScale(scale)
  }

  final class ZoomAnchor: NSView {
    private var appliedScale: CGFloat
    private var requestedScale: CGFloat
    private var lastZoomedSize: NSSize?
    private var actualSize: NSSize?

    init(scale: CGFloat) {
      appliedScale = scale
      requestedScale = scale
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      return nil
    }

    func updateScale(_ scale: CGFloat) {
      guard scale != requestedScale else { return }
      requestedScale = scale
      guard let window else {
        appliedScale = scale
        return
      }

      let frame = window.frame
      let actualSize = sizeAtActualScale(for: frame.size)
      let desiredSize = NSSize(width: actualSize.width * scale, height: actualSize.height * scale)
      // Resize after SwiftUI has applied the new content size limits.
      DispatchQueue.main.async { [weak self, weak window] in
        guard let self, let window, self.window === window, self.requestedScale == scale else {
          return
        }
        self.appliedScale = scale
        self.actualSize = actualSize
        let screen = window.screen
        let target = self.scaledFrame(
          frame, to: desiredSize, within: screen?.visibleFrame,
          backingScale: screen?.backingScaleFactor ?? window.backingScaleFactor
        )
        window.setFrame(target, display: true)
        self.lastZoomedSize = window.frame.size
      }
    }

    private func sizeAtActualScale(for size: NSSize) -> NSSize {
      // Keep an unrounded baseline until the user manually resizes the window.
      if let actualSize, let lastZoomedSize {
        let widthDifference = abs(lastZoomedSize.width - size.width)
        let heightDifference = abs(lastZoomedSize.height - size.height)
        if max(widthDifference, heightDifference) <= 1 {
          return actualSize
        }
      }

      return NSSize(width: size.width / appliedScale, height: size.height / appliedScale)
    }

    private func scaledFrame(
      _ frame: NSRect, to size: NSSize, within bounds: NSRect?, backingScale: CGFloat
    ) -> NSRect {
      let pixels = TaskMetrics(zoom: 1, displayScale: backingScale)
      let width = pixels.length(min(size.width, bounds?.width ?? size.width))
      let height = pixels.length(min(size.height, bounds?.height ?? size.height))
      let alignedX = pixels.length(frame.midX - width / 2)
      let alignedY = pixels.length(frame.maxY - height)
      guard let bounds else {
        return NSRect(x: alignedX, y: alignedY, width: width, height: height)
      }

      let originX = min(max(alignedX, bounds.minX), bounds.maxX - width)
      let originY = min(max(alignedY, bounds.minY), bounds.maxY - height)
      return NSRect(x: originX, y: originY, width: width, height: height)
    }
  }
}
