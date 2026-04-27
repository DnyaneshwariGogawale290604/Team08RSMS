import SwiftUI

public struct Theme {
    public static let offWhite = CatalogTheme.background
    public static let beige = CatalogTheme.card
    public static let border = CatalogTheme.divider
    public static let textPrimary = CatalogTheme.primaryText
    public static let textSecondary = CatalogTheme.secondaryText
    
    // Semantic Colors
    public static let primary = CatalogTheme.primary
    public static let surface = CatalogTheme.surface
    public static let success = CatalogTheme.primary
    public static let warning = CatalogTheme.deepAccent
    public static let error = CatalogTheme.error
}


// MARK: - Luxury Components

struct LuxuryCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .appCardChrome()
    }
}

extension View {
    func luxuryCardStyle() -> some View {
        self.modifier(LuxuryCardStyle())
    }
}

struct PrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .appPrimaryButtonChrome()
    }
}

extension View {
    func primaryButtonStyle() -> some View {
        self.modifier(PrimaryButtonModifier())
    }
}
