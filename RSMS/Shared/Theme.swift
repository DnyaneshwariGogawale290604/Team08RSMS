import SwiftUI

public struct Theme {
    public static let offWhite = Color.appBackground
    public static let beige = Color.appCard
    public static let border = Color.appBorder
    public static let textPrimary = Color.appPrimaryText
    public static let textSecondary = Color.appSecondaryText
    
    // Semantic Colors
    public static let success = Color.green.opacity(0.8)
    public static let warning = Color.orange.opacity(0.8)
    public static let error = Color.red.opacity(0.8)
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
