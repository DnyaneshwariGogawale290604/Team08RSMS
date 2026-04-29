import SwiftUI

enum CatalogTheme {
    static let primary = Color(hex: "#6E5155")         // Maroon
    static let deepAccent = Color(hex: "#4A2E32")      // Deep Wine
    static let background = Color(hex: "#F5EFEF")      // Soft Grey-Pink Background
    static let surface = Color(hex: "#E6DADA")         // Soft Blush

    static let primaryText = Color(hex: "#1A1A1A")     // Dark Charcoal
    static let secondaryText = Color(hex: "#6B5B5B")   // Muted Maroon/Grey
    static let mutedText = Color(hex: "#9A8A8A")       // Lighter Muted Grey
    static let divider = Color.black.opacity(0.1)

    static let error = deepAccent
    static let card = Color.white
    static let chipInactiveText = secondaryText
    static let inactiveBadge = Color(hex: "#D8C6C6")
    static let inactiveBadgeText = secondaryText

    // Brand specific
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
