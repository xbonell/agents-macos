import AppKit
import SwiftUI

@main
struct AgentsApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  // Plain lets, not @State: the App is made once, and the Command Line Tools
  // ship no SwiftUI macro plugin, so @State doesn't build without Xcode.
  private let store: UsageStore
  private let scheduler: Scheduler

  init() {
    store = UsageStore()
    if let snapshot = Snapshot.request() {
      Snapshot.render(store: store, to: snapshot.path, scheme: snapshot.scheme)
      exit(0)
    }
    scheduler = Scheduler(store: store)
  }

  var body: some Scene {
    MenuBarExtra {
      PanelView(store: store, scheduler: scheduler)
    } label: {
      StatusItemIcon(store: store)
    }
    .menuBarExtraStyle(.window)
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  // A menu bar extra, not an app: no Dock icon even when run unbundled with
  // `swift run` (the built .app sets LSUIElement as well).
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
