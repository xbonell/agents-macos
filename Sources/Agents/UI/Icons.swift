import AppKit
import SwiftUI

// The marks Omarchy ships: assets/<id>.svg, with an <id>-light.svg twin for
// marks that are white and need a dark one on light surfaces.
enum Icons {
  private static var cache: [String: NSImage] = [:]

  static func image(named name: String) -> NSImage? {
    if let cached = cache[name] { return cached }
    let url = Paths.assets.appendingPathComponent("\(name).svg")
    guard let image = NSImage(contentsOf: url) else { return nil }
    // A mark sized in em (Codex's is 1em square) reads as 1×1pt, which
    // SwiftUI would scale up from a single pixel. The SVG is vector, so give
    // it a working size that keeps its aspect.
    let side = max(image.size.width, image.size.height)
    if side > 0 && side < 64 {
      image.size = NSSize(width: image.size.width * 64 / side, height: image.size.height * 64 / side)
    }
    cache[name] = image
    return image
  }

  // Panel.qml's iconCandidatesForProvider: the light twin first on a light
  // surface, then the plain mark.
  static func mark(for id: String, scheme: ColorScheme) -> NSImage? {
    (scheme == .light ? image(named: "\(id)-light") : nil) ?? image(named: id)
  }

  // The bar glyph, U+F16A3 from Material Design Icons, as a template image
  // that takes the menu bar's own color.
  static let robot: NSImage = {
    let robot = (Icons.image(named: "robot")?.copy() as? NSImage) ?? NSImage(systemSymbolName: "cpu", accessibilityDescription: nil)!
    // Menu bar size: 16pt tall, like the system's own extras. image(named:)
    // gives small marks a 64pt working size, which the menu bar would keep.
    let aspect = robot.size.height > 0 ? robot.size.width / robot.size.height : 1
    robot.size = NSSize(width: (16 * aspect).rounded(), height: 16)
    robot.isTemplate = true
    return robot
  }()
}

// A provider's mark, falling back to the bar glyph when it ships none.
struct ProviderMark: View {
  let id: String
  var size: CGFloat = 18
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    Group {
      if let mark = Icons.mark(for: id, scheme: scheme) {
        Image(nsImage: mark).resizable().interpolation(.high)
      } else {
        Image(nsImage: Icons.robot).resizable().foregroundStyle(.primary)
      }
    }
    .aspectRatio(contentMode: .fit)
    .frame(width: size, height: size)
  }
}
