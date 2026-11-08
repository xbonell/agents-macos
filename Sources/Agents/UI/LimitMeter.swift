import SwiftUI

// A linear meter drawn like the system's: a thin rounded track in the fill
// color and the used share in the accent color, red when alarming.
struct Meter: View {
  let value: Double
  var alarming = false
  var thickness: CGFloat = 6

  var body: some View {
    GeometryReader { geo in
      let fill = alarming ? Theme.urgent : Color.accentColor
      Capsule()
        .fill(.quaternary)
        .overlay(alignment: .leading) {
          Capsule()
            .fill(fill)
            .frame(width: max(thickness, geo.size.width * min(1, max(0, value))))
            .opacity(value > 0 ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.16), value: value)
    }
    .frame(height: thickness)
  }
}

// One limit window: its name and, on the right, the time until it resets and
// how much is used, with the meter underneath. Model-scoped allowances on the
// same clock (Cursor's auto and named models, Claude's Fable) follow as
// labelled sub-rows; the age of kept numbers is in the tooltip.
struct LimitRow: View {
  let window: LimitWindow
  let stale: Bool
  let fetchedAt: Double
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline) {
          Text(window.title).font(Theme.body)
          Spacer(minLength: 8)
          Text(detail)
            .font(Theme.secondary)
            .monospacedDigit()
            .foregroundStyle(style(for: window.percent))
        }
        Meter(value: window.percent, alarming: window.percent >= 0.9)
      }

      ForEach(Array(window.scoped.enumerated()), id: \.offset) { _, scoped in
        HStack(spacing: 10) {
          Text(scoped.title)
            .font(Theme.secondary)
            .foregroundStyle(.secondary)
            .frame(width: 92, alignment: .leading)
            .lineLimit(1)
          Meter(value: scoped.percent, alarming: scoped.percent >= 0.9, thickness: 4)
          Text(percent(scoped.percent))
            .font(Theme.secondary)
            .monospacedDigit()
            .foregroundStyle(style(for: scoped.percent))
            .frame(width: 32, alignment: .trailing)
        }
        .padding(.leading, 10)
      }
    }
    .contentShape(Rectangle())
    .help(Presentation.limitTooltip(window, stale: stale, fetchedAt: fetchedAt, now: now))
  }

  private var detail: String {
    let used = percent(window.percent)
    guard let reset = window.resetAt, reset > now else { return used }
    return "\(Presentation.formatDuration(reset.timeIntervalSince(now))) · \(used)"
  }

  private func percent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
  }

  private func style(for value: Double) -> AnyShapeStyle {
    value >= 0.9 ? AnyShapeStyle(Theme.urgent) : AnyShapeStyle(.secondary)
  }
}
