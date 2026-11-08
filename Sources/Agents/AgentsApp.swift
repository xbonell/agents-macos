import AppKit

// An AppKit entry point: the menu bar item is an NSStatusItem (see
// StatusBarController), and there's no SwiftUI scene to host.
@main
enum AgentsApp {
  @MainActor
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // A menu bar extra, not an app: no Dock icon even when run unbundled
    // with `swift run` (the built .app sets LSUIElement as well).
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var controller: StatusBarController?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let prefs = Preferences()
    let store = UsageStore(prefs: prefs)
    if let snapshot = Snapshot.request() {
      Snapshot.render(store: store, to: snapshot.path, scheme: snapshot.scheme)
      exit(0)
    }
    let scheduler = Scheduler(store: store, prefs: prefs)
    controller = StatusBarController(store: store, scheduler: scheduler, prefs: prefs)
  }
}
