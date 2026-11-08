import AppKit
import SwiftUI

// A development aid: `Agents --snapshot panel.png [--dark]` draws the panel
// from the records on disk into a PNG and exits, without running collectors.
enum Snapshot {
  static func request() -> (path: String, scheme: ColorScheme)? {
    let args = CommandLine.arguments
    guard let flag = args.firstIndex(of: "--snapshot"), flag + 1 < args.count else { return nil }
    return (args[flag + 1], args.contains("--dark") ? .dark : .light)
  }

  @MainActor
  static func render(store: UsageStore, to path: String, scheme: ColorScheme) {
    let view = PanelView(store: store, scheduler: nil)
      .background(Color(nsColor: .windowBackgroundColor))
      .environment(\.colorScheme, scheme)
    let renderer = ImageRenderer(content: view)
    renderer.scale = 2
    NSApplication.shared.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
      FileHandle.standardError.write("Could not render the panel\n".data(using: .utf8)!)
      return
    }
    try? png.write(to: URL(fileURLWithPath: path))
  }
}
