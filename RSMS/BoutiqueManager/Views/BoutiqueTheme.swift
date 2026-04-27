import SwiftUI

public enum BoutiqueTheme {
    // --- Palette (Maroon Luxury) ---
    public static let primary = Color(hex: "#6E5155")         // Maroon
    public static let deepAccent = Color(hex: "#4A2E32")      // Deep Wine
    public static let background = Color(hex: "#F5EFEF")      // Soft Grey-Pink Background
    public static let surface = Color(hex: "#E6DADA")         // Soft Blush
    public static let card = Color.white                      // White Cards
    
    public static let primaryText = Color(hex: "#1A1A1A")     // Dark Charcoal
    public static let secondaryText = Color(hex: "#6B5B5B")   // Muted Maroon/Grey
    public static let mutedText = Color(hex: "#9A8A8A")       // Lighter Muted Grey
    public static let divider = Color.black.opacity(0.08)
    
    // --- Semantic Helpers ---
    public static let error = deepAccent
    public static let brandMaroon = primary
    public static let brandDeep = deepAccent
    public static let searchField = surface
    public static let imageBackground = surface
    public static let subtleCategory = Color(hex: "#8C7A7A")
    public static let priceText = deepAccent
    
    // --- Badge/Chip Colors ---
    public static let chipActiveBackground = primary
    public static let chipActiveText = Color.white
    public static let chipInactiveBackground = surface
    public static let chipInactiveText = deepAccent
    
    public static let badgeActiveBackground = primary
    public static let badgeActiveText = Color.white
    public static let badgeInactiveBackground = Color(hex: "#D8C6C6")
    public static let badgeInactiveText = secondaryText
    
    // --- Compatibility Aliases (for legacy code) ---
    public static let offWhite = background
    public static let beige = surface
    public static let border = divider
    public static let textPrimary = primaryText
    public static let textSecondary = secondaryText
    public static let success = primary
    public static let warning = deepAccent
    
    // --- UI Metrics ---
    public static let cardCornerRadius: CGFloat = 16
    public static let buttonCornerRadius: CGFloat = 16
    public static let standardPadding: CGFloat = 20
}

// MARK: - Component Modifiers
public extension View {
    func boutiqueCardChrome() -> some View {
        self
            .background(BoutiqueTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: BoutiqueTheme.cardCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    func boutiqueHeaderStyle() -> some View {
        self
            .font(.system(size: 34, weight: .bold, design: .serif)) // Serif for titles
            .foregroundColor(BoutiqueTheme.primaryText)
    }
    
    func boutiqueSubtitleStyle() -> some View {
        self
            .font(.system(size: 14, weight: .medium, design: .default))
            .foregroundColor(BoutiqueTheme.secondaryText)
            .tracking(0.5)
    }
    
    func boutiquePrimaryButtonChrome(enabled: Bool = true) -> some View {
        self
            .background(enabled ? BoutiqueTheme.deepAccent : BoutiqueTheme.deepAccent.opacity(0.4))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: BoutiqueTheme.buttonCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
