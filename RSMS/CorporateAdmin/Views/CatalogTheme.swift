import SwiftUI

public enum CatalogTheme {
    public static let primary = Color(hex: "#6E5155")
    public static let deepAccent = Color(hex: "#4A2E32")
    public static let background = Color(hex: "#F5EFEF")
    public static let surface = Color(hex: "#E6DADA")

    public static let primaryText = Color(hex: "#1A1A1A")
    public static let secondaryText = Color(hex: "#6B5B5B")
    public static let mutedText = Color(hex: "#9A8A8A")
    public static let divider = Color.black.opacity(0.08)

    public static let error = deepAccent
    public static let card = surface
    public static let chipInactiveText = deepAccent
    public static let inactiveBadge = Color(hex: "#D8C6C6")
    public static let inactiveBadgeText = secondaryText

    public static let brandMaroon = primary
    public static let brandDeep = deepAccent
    public static let brandOffWhite = background

    public static let cardCornerRadius: CGFloat = 20
    public static let standardPadding: CGFloat = 20

    public static let searchField = surface
    public static let imageBackground = surface
    public static let subtleCategory = Color(hex: "#8C7A7A")
    public static let subtext = Color(hex: "#B5A5A5")
    public static let elevatedCard = Color(hex: "#EFE6E6")

    public static let statsIconBackground = surface
    public static let statsIconColor = primary
    public static let categoryText = Color(hex: "#8C7A7A")
}
