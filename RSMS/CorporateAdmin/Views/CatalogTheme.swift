import SwiftUI

enum CatalogTheme {
    static let primary = Color(hex: "#6E5155")
    static let deepAccent = Color(hex: "#4A2E32")
    static let background = Color(hex: "#F5EFEF")
    static let surface = Color(hex: "#E6DADA")

    static let primaryText = Color(hex: "#1A1A1A")
    static let secondaryText = Color(hex: "#6B5B5B")
    static let mutedText = Color(hex: "#9A8A8A")
    static let divider = Color.black.opacity(0.1)

    static let error = deepAccent
    static let card = Color.white
    static let chipInactiveText = secondaryText
    static let inactiveBadge = Color(hex: "#D8C6C6")
    static let inactiveBadgeText = secondaryText

    static let brandMaroon = primary
    static let brandDeep = deepAccent
    static let brandOffWhite = background

    static let cardCornerRadius: CGFloat = 16
    static let standardPadding: CGFloat = 20

    static let searchField = surface
    static let imageBackground = surface
    static let subtleCategory = mutedText

    static let statsIconBackground = primary.opacity(0.1)
    static let statsIconColor = primary
    static let categoryText = secondaryText
}
