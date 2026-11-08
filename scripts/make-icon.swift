// Renders the app icon: the robot mark (assets/robot.svg) in white on a
// macOS-style rounded tile with a graphite gradient, as a 1024px PNG.
// scripts/make-icon.sh turns it into Icon/AppIcon.icns.
//
//   swift scripts/make-icon.swift <robot.svg> <out.png>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let robot = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
  FileHandle.standardError.write("usage: make-icon.swift <robot.svg> <out.png>\n".data(using: .utf8)!)
  exit(1)
}

let canvas: CGFloat = 1024
let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Apple's macOS icon grid: an 824px tile centered on the 1024px canvas,
// corners at about 22.4% of the tile.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 24
NSGraphicsContext.saveGraphicsState()
shadow.set()
NSColor.black.setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(
  starting: NSColor(calibratedRed: 0.29, green: 0.31, blue: 0.36, alpha: 1),
  ending: NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 1)
)!.draw(in: shape, angle: -90)

// A faint top highlight, as on the system's own tiles.
NSGraphicsContext.saveGraphicsState()
shape.addClip()
NSGradient(colors: [NSColor.white.withAlphaComponent(0.10), NSColor.white.withAlphaComponent(0)])!
  .draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
NSGraphicsContext.restoreGraphicsState()

// The robot in white, about 56% of the tile wide, optically centered.
let mark = robot.copy() as! NSImage
let aspect = mark.size.height / max(1, mark.size.width)
let width: CGFloat = 460
let markRect = NSRect(x: (canvas - width) / 2, y: (canvas - width * aspect) / 2 - 8, width: width, height: width * aspect)
let white = NSImage(size: markRect.size, flipped: false) { rect in
  mark.draw(in: rect)
  NSColor.white.set()
  rect.fill(using: .sourceAtop)
  return true
}
white.draw(in: markRect)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
