import Foundation

// Where the port keeps what Omarchy keeps under XDG: run_collector.py points
// XDG_STATE_HOME and XDG_CACHE_HOME here, so the vendored collectors write
// their records and caches inside the app's own Library folders.
enum Paths {
  static let home = FileManager.default.homeDirectoryForCurrentUser

  static let stateHome = home.appendingPathComponent("Library/Application Support/Agents", isDirectory: true)
  static let cacheHome = home.appendingPathComponent("Library/Caches/Agents", isDirectory: true)

  // The same layout as ~/.local/state/omarchy/agents/usage on Omarchy.
  // AGENTS_USAGE_DIR points the panel at other records, for development.
  static let usageDir = ProcessInfo.processInfo.environment["AGENTS_USAGE_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? stateHome.appendingPathComponent("omarchy/agents/usage", isDirectory: true)

  static let resources: URL = Bundle.module.url(forResource: "Resources", withExtension: nil)!
  static let runCollector = resources.appendingPathComponent("macos/run_collector.py")
  static let assets = resources.appendingPathComponent("assets", isDirectory: true)

  static let python = URL(fileURLWithPath: "/usr/bin/python3")
}
