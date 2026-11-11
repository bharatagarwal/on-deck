import SwiftUI

enum QueuePalette {
  static let accent = Color(
    nsColor: NSColor(name: nil) { appearance in
      if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
        return NSColor(srgbRed: 0.76, green: 0.59, blue: 1, alpha: 1)
      }
      return NSColor(srgbRed: 0.58, green: 0.30, blue: 0.89, alpha: 1)
    }
  )
}

extension EnvironmentValues {
  @Entry var taskScale: CGFloat = 1

  var taskMetrics: TaskMetrics {
    TaskMetrics(zoom: taskScale, displayScale: displayScale)
  }
}

struct TaskMetrics {
  let zoom: CGFloat
  let displayScale: CGFloat

  func length(_ points: CGFloat) -> CGFloat {
    (points * zoom * displayScale).rounded() / displayScale
  }
}

struct QueueMasthead: View {
  let status: String
  @Environment(\.taskMetrics) private var metrics

  var body: some View {
    Text(status)
      .font(.system(size: metrics.length(11), weight: .semibold, design: .monospaced))
      .foregroundStyle(.secondary)
      .accessibilityIdentifier("queue-status")
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.vertical, metrics.length(7))
      .contentShape(Rectangle())
  }
}

struct QueueBackdrop: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.taskMetrics) private var metrics

  var body: some View {
    Rectangle()
      .fill(.background)
      .overlay(alignment: .bottom) {
        MeshGradient(
          width: 3, height: 3,
          points: [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.62], [0.48, 0.35], [1, 0.54],
            [0, 1], [0.49, 1], [1, 1]
          ],
          colors: gradientColors
        )
        .frame(height: metrics.length(285))
        .opacity(0.88)
      }
      .accessibilityHidden(true)
  }

  private var gradientColors: [Color] {
    let glow = colorScheme == .dark ? Glow.dark : Glow.light
    return [.clear, .clear, .clear, .clear, glow.rose.opacity(0.18), .clear]
      + [glow.violet, glow.rose, glow.amber]
  }

  private struct Glow {
    let violet: Color
    let rose: Color
    let amber: Color

    static let light = Self(
      violet: Color(red: 0.62, green: 0.49, blue: 1),
      rose: Color(red: 1, green: 0.58, blue: 0.76),
      amber: Color(red: 1, green: 0.78, blue: 0.54)
    )

    static let dark = Self(
      violet: Color(red: 0.34, green: 0.22, blue: 0.65),
      rose: Color(red: 0.55, green: 0.22, blue: 0.42),
      amber: Color(red: 0.59, green: 0.32, blue: 0.18)
    )
  }
}
