import SwiftUI

// The panel: the header, then one card per subscription, limits first. Times
// are re-read every 30 seconds while it's open.
struct PanelView: View {
  let store: UsageStore
  // nil when rendering a snapshot, which must not run the collectors.
  let scheduler: Scheduler?

  @StateObject private var measured = MeasuredHeight()

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
      // The window takes the content's own height. Only content taller than
      // the cap goes in a ScrollView: one has no height of its own, and the
      // window would size itself to whatever frame it's given.
      let page = content(now: context.date)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { geo in
          Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
        })
      Group {
        if let height = measured.height, height > Theme.maxPanelHeight {
          ScrollView { page }.frame(height: Theme.maxPanelHeight)
        } else {
          page
        }
      }
      .onPreferenceChange(ContentHeightKey.self) { measured.height = $0 }
    }
    .frame(width: Theme.panelWidth)
    // Opening the panel wants the numbers that go stale on the wire, not
    // another walk over every transcript on disk.
    .onAppear { scheduler?.refreshLimits() }
  }

  private var providers: [UsageRecord] {
    let order = Scheduler.providers
    return store.visible.sorted { a, b in
      let ia = order.firstIndex(of: a.id) ?? order.count
      let ib = order.firstIndex(of: b.id) ?? order.count
      return ia != ib ? ia < ib : a.id < b.id
    }
  }

  private func content(now: Date) -> some View {
    VStack(alignment: .leading, spacing: Theme.cardSpacing) {
      Hero(
        phrases: Presentation.summaryPhrases(store.visible),
        running: scheduler?.running ?? false,
        onRefresh: { scheduler?.refresh() }
      )
      .padding(.bottom, 4)

      if scheduler?.pythonMissing == true {
        Card {
          Label("Python isn't available", systemImage: "exclamationmark.triangle.fill")
            .font(Theme.title)
            .foregroundStyle(Theme.urgent)
          Text("Agents reads usage with Python, which comes with Apple's Command Line Tools. Run `xcode-select --install` in Terminal, then refresh.")
            .font(Theme.secondary)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else if providers.isEmpty {
        Card {
          Text(scheduler?.running == true
            ? "Collecting usage…"
            : "No agents yet. Sign in to Claude Code, Codex, or Cursor and they'll show up here.")
            .font(Theme.secondary)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      ForEach(providers) { record in
        ProviderSection(record: record, now: now)
      }

      Divider().padding(.vertical, 4)
      Footer()
    }
    .padding(Theme.panelPadding)
  }
}

private final class MeasuredHeight: ObservableObject {
  @Published var height: CGFloat?
}

private struct ContentHeightKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct Footer: View {
  @StateObject private var login = LoginItem()

  var body: some View {
    HStack {
      if login.available {
        Toggle("Open at Login", isOn: Binding(get: { login.enabled }, set: { login.set($0) }))
          .toggleStyle(.checkbox)
          .font(Theme.body)
          .help(login.needsApproval ? "Allow Agents in System Settings › General › Login Items." : "")
      }
      Spacer()
      Button("Quit") { NSApplication.shared.terminate(nil) }
        .buttonStyle(.borderless)
        .font(Theme.body)
    }
    .padding(.horizontal, 4)
    .onAppear { login.refresh() }
  }
}
