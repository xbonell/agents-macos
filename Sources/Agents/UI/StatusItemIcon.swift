import AppKit
import SwiftUI

// The bar icon: the robot in the menu bar's own color, lit in the urgent
// color while any window is nearly out (Panel.qml's `alarming`). It's
// re-read whenever the records change; a TimelineView here makes the
// menu bar extra re-lay out its button in a loop.
struct StatusItemIcon: View {
  let store: UsageStore

  var body: some View {
    let alarming = Presentation.alarming(store.visible, now: Date())
    Image(nsImage: alarming ? Self.urgentRobot : Icons.robot)
      .accessibilityLabel(alarming ? "Agents: a limit is nearly used" : "Agents")
  }

  // Menu bar images draw as templates unless told otherwise, so the lit
  // robot is painted in the urgent color and marked as not a template.
  private static let urgentRobot: NSImage = {
    let base = Icons.robot
    let image = NSImage(size: base.size, flipped: false) { rect in
      base.draw(in: rect)
      NSColor.systemRed.set()
      rect.fill(using: .sourceAtop)
      return true
    }
    image.isTemplate = false
    return image
  }()
}
