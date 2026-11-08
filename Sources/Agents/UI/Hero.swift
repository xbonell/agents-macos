import Combine
import SwiftUI

// The panel's header: "Agents", a line under it that rotates through what
// the token counts add up to, and refresh at the trailing edge.
struct Hero: View {
  let phrases: [String]
  let running: Bool
  let onRefresh: () -> Void

  @StateObject private var rotator = PhraseRotator()
  private let tick = Timer.publish(every: 2.8, on: .main, in: .common).autoconnect()

  var body: some View {
    HStack(alignment: .center) {
      VStack(alignment: .leading, spacing: 1) {
        Text("Agents").font(Theme.title)
        Text(rotator.shown.isEmpty ? "Subscriptions" : rotator.shown)
          .font(Theme.secondary)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .opacity(rotator.opacity)
      }
      Spacer(minLength: 8)
      Button(action: onRefresh) {
        ZStack {
          if running {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise").font(.system(size: 12, weight: .medium))
          }
        }
        .frame(width: 24, height: 24)
        .contentShape(Circle())
      }
      .buttonStyle(CircleButtonStyle())
      .disabled(running)
      .help("Refresh")
    }
    .padding(.horizontal, 4)
    .onAppear { rotator.phrases = phrases }
    .onChange(of: phrases) { _, next in rotator.phrases = next }
    .onReceive(tick) { _ in rotator.advance() }
  }
}

// Every record that lands rebuilds the phrases, and a refresh lands each
// agent in turn; indexing the live list would swap the line on each, so the
// header holds what it shows until the next fade.
final class PhraseRotator: ObservableObject {
  @Published private(set) var shown = ""
  @Published private(set) var opacity = 1.0
  private var index = 0

  var phrases: [String] = [] {
    didSet { if shown.isEmpty || phrases.count <= 1 { show() } }
  }

  func advance() {
    guard phrases.count > 1 else { return }
    withAnimation(.easeOut(duration: 0.15)) { opacity = 0 }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [self] in
      index = (index + 1) % phrases.count
      show()
      withAnimation(.easeOut(duration: 0.2)) { opacity = 1 }
    }
  }

  private func show() {
    shown = phrases.isEmpty ? "" : phrases[index % phrases.count]
  }
}

// Control Center's round glyph button: a circle of the system fill that
// darkens on hover and press.
struct CircleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    HoverCircle(pressed: configuration.isPressed) { configuration.label }
  }
}

private struct HoverCircle<Content: View>: View {
  let pressed: Bool
  @ViewBuilder let content: Content
  @StateObject private var hover = HoverState()

  var body: some View {
    content
      .background(Circle().fill(.quaternary.opacity(pressed ? 1.6 : hover.on ? 1.2 : 0.8)))
      .onHover { hover.on = $0 }
  }
}

final class HoverState: ObservableObject {
  @Published var on = false
}
