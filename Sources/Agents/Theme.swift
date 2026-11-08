import SwiftUI

// The panel follows Control Center's modules: standard system text sizes,
// one rounded card per provider on the system fill, and meters in the
// accent color that turn red when a window is nearly out.
enum Theme {
  static let panelWidth: CGFloat = 320
  static let panelPadding: CGFloat = 12
  static let maxPanelHeight: CGFloat = 640

  static let cardSpacing: CGFloat = 8
  static let cardPadding: CGFloat = 12
  static let cardRadius: CGFloat = 10

  static let urgent = Color(nsColor: .systemRed)

  // 13pt for names and labels, 11pt for secondary text, as in system menus.
  static let title = Font.system(size: 13, weight: .semibold)
  static let body = Font.system(size: 13)
  static let secondary = Font.system(size: 11)
}

// A Control Center module: content on a rounded tile of the system fill.
struct Card<Content: View>: View {
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) { content }
      .padding(Theme.cardPadding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
  }
}
