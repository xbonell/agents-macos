import SwiftUI

// The panel: the header, then one card per subscription, limits first. Times
// are re-read every 30 seconds while it's open.
struct PanelView: View {
  let store: UsageStore
  // nil when rendering a snapshot, which must not run the collectors.
  let scheduler: Scheduler?
  var openSettings: () -> Void = {}

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
      Footer(
        updated: Presentation.updatedText(store.visible, now: now, running: scheduler?.running ?? false),
        openSettings: openSettings
      )
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

// How old the numbers are, and a gear menu with Settings and Quit for anyone
// who never right-clicks the robot.
private struct Footer: View {
  let updated: String
  let openSettings: () -> Void

  var body: some View {
    HStack {
      Text(updated)
        .font(Theme.secondary)
        .foregroundStyle(.secondary)
      Spacer()
      Menu {
        Button("Settings…", action: openSettings)
        Divider()
        Button("Quit Agents") { NSApplication.shared.terminate(nil) }
      } label: {
        Image(systemName: "gearshape")
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
      .help("Settings and Quit")
    }
    .padding(.horizontal, 4)
  }
}
