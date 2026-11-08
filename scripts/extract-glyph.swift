// Writes the Omarchy bar glyph (U+F16A3, Material Design Icons' robot, as
// Nerd Fonts patch it in) out as an SVG path, so the menu bar icon doesn't
// need a Nerd Font installed. Needs one installed once, to run this:
//
//   swift scripts/extract-glyph.swift > Sources/Agents/Resources/assets/robot.svg
import AppKit
import CoreText

let codepoint: UInt32 = 0xF16A3
let fontName = CommandLine.arguments.dropFirst().first ?? "JetBrainsMono Nerd Font"

let font = CTFontCreateWithName(fontName as CFString, 1000, nil)
var utf16 = Array(String(UnicodeScalar(codepoint)!).utf16)
var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
guard CTFontGetGlyphsForCharacters(font, &utf16, &glyphs, utf16.count), glyphs[0] != 0,
      let path = CTFontCreatePathForGlyph(font, glyphs[0], nil) else {
  FileHandle.standardError.write("\(fontName) has no U+F16A3\n".data(using: .utf8)!)
  exit(1)
}

let box = path.boundingBoxOfPath
func p(_ point: CGPoint) -> String {
  // Font space grows upward; SVG grows downward.
  String(format: "%.1f %.1f", point.x - box.minX, box.maxY - point.y)
}
var d = ""
path.applyWithBlock { element in
  let e = element.pointee
  switch e.type {
  case .moveToPoint: d += "M\(p(e.points[0]))"
  case .addLineToPoint: d += "L\(p(e.points[0]))"
  case .addQuadCurveToPoint: d += "Q\(p(e.points[0])) \(p(e.points[1]))"
  case .addCurveToPoint: d += "C\(p(e.points[0])) \(p(e.points[1])) \(p(e.points[2]))"
  case .closeSubpath: d += "Z"
  @unknown default: break
  }
}
print(String(format: ##"<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %.1f %.1f" width="%.0f" height="%.0f"><path fill="#000" d="%@"/></svg>"##,
             box.width, box.height, box.width / 50, box.height / 50, d))
