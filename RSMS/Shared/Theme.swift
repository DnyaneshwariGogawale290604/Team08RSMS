import SwiftUI

public struct Theme {
    // Core Theme Setup
    public static let background = Color(hex: "#F5EFEF")
    public static let primary = Color(hex: "#6E5155")
    public static let deepAccent = Color(hex: "#4A2E32")
    public static let surface = Color(hex: "#E6DADA")
    
    // Existing variable mappings
    public static let offWhite = background
    public static let beige = Color(hex: "#FFFFFF") // For standard cards
    public static let border = Color.black.opacity(0.08)
    
    // Text
    public static let textPrimary = Color(hex: "#1A1A1A")
    public static let textSecondary = Color(hex: "#6B5B5B")
    public static let mutedText = Color(hex: "#9A8A8A")
    
    // Semantic Colors
    // Remove greens: substitute success with Deep Accent or Primary depending on context
    public static let success = Color(hex: "#4A2E32") 
    public static let warning = Color.orange.opacity(0.8)
    public static let error = Color(hex: "#8C7A7A") // Muted error color instead of harsh red
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
