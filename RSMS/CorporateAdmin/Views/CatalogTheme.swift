import SwiftUI

enum CatalogTheme {
    static let primary = Color(hex: "#6E5155")
    static let deepAccent = Color(hex: "#4A2E32")
    static let background = Color(hex: "#F5EFEF")
    static let surface = Color(hex: "#E6DADA")
    
    static let primaryText = Color(hex: "#1A1A1A")
    static let secondaryText = Color(hex: "#6B5B5B")
    static let mutedText = Color(hex: "#9A8A8A")
    static let divider = Color.black.opacity(0.08)
    
    static let error = Color(hex: "#A07070")
    static let card = Color.white
    static let chipInactiveText = Color(hex: "#4A2E32")
    static let inactiveBadge = Color(hex: "#D8C6C6")
    static let inactiveBadgeText = Color(hex: "#6B5B5B")
    
    // Brand specific
    static let brandMaroon = primary
    static let brandDeep = deepAccent
    static let brandOffWhite = background
    
    // UI Helpers
    static let cardCornerRadius: CGFloat = 16
    static let standardPadding: CGFloat = 20
    
    // Additional Semantic Colors
    static let searchField = surface
    static let imageBackground = Color(hex: "#F0E9E9")
    static let subtleCategory = secondaryText.opacity(0.8)
}
