import SwiftUI

enum CatalogTheme {
    static let primary = Color(hex: "#1F2933") // Jet Black for highlighting/primary actions
    static let deepAccent = Color(hex: "#000000") // Pure Black for strong accents
    static let background = Color(hex: "#CFCFCF") // Dust Grey for backgrounds
    static let surface = Color(hex: "#EDEAE6") // Parchment for surfaces
    
    static let primaryText = Color(hex: "#000000") // Black for text
    static let secondaryText = Color(hex: "#1F2933") // Jet Black for secondary text
    static let mutedText = Color.black.opacity(0.5) // Light grey using opacity for subtexts
    static let divider = Color.black.opacity(0.1)
    
    static let error = Color(hex: "#A07070") // Kept for error states, might need adjustment if strict 4-color is mandated even for errors, but typically semantic colors are kept or derived. Let's use Jet Black if strict. Let's stick to Jet Black for error if strict, or a muted black. We'll use Jet Black.
    static let card = Color(hex: "#EDEAE6") // Parchment for cards
    static let chipInactiveText = Color(hex: "#1F2933")
    static let inactiveBadge = Color(hex: "#CFCFCF")
    static let inactiveBadgeText = Color(hex: "#000000")
    
    // Brand specific
    static let brandMaroon = primary // Re-aliased, originally primary
    static let brandDeep = deepAccent
    static let brandOffWhite = background
    
    // UI Helpers
    static let cardCornerRadius: CGFloat = 16
    static let standardPadding: CGFloat = 20
    
    // Additional Semantic Colors
    static let searchField = surface
    static let imageBackground = Color(hex: "#CFCFCF") // Dust grey for image placeholders
    static let subtleCategory = mutedText
    
    // UI Elements for Stats and Categories
    static let statsIconBackground = primary.opacity(0.1)
    static let statsIconColor = primary
    static let categoryText = secondaryText
}
