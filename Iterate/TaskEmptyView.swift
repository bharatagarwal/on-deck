import SwiftUI

struct TaskEmptyView<Controls: View>: View {
  @ViewBuilder let controls: () -> Controls
  @Environment(\.taskMetrics) private var metrics

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Spacer(minLength: metrics.length(18))

      VStack(alignment: .leading, spacing: metrics.length(8)) {
        Text("Off duty.")
          .font(
            .system(size: metrics.length(52), weight: .black, design: .default).width(.condensed)
          )
          .tracking(metrics.length(-1.8))
          .lineLimit(1)
          .minimumScaleFactor(0.72)
          .accessibilityAddTraits(.isHeader)
          .accessibilityIdentifier("empty-heading")
        Text("Your list is clear. Enjoy the quiet.")
          .font(.system(size: metrics.length(13)))
          .foregroundStyle(.secondary)
      }

      controls()
        .padding(.top, metrics.length(22))

      Spacer(minLength: metrics.length(80))
    }
    .padding(.horizontal, metrics.length(23))
    .padding(.top, metrics.length(12))
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
