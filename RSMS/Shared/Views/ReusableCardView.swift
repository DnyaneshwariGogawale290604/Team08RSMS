import SwiftUI

public extension Color {
    static let appBackground = Color(hex: "#F5EFEF")
    static let appCard = Color.white
    static let appBorder = Color.black.opacity(0.08)
    static let appSecondaryText = Color(hex: "#6B5B5B")
    static let appPrimaryText = Color(hex: "#1A1A1A")
    static let appAccent = Color(hex: "#6E5155")
    static let appMaroon = Color(hex: "#6E5155")
    static let appBrown = Color(hex: "#8D6E63") // Warm brown for cycle counts

    static let brandOffWhite = appBackground
    static let brandLinen = appCard
    static let brandPebble = appBorder
    static let brandWarmGrey = appSecondaryText
    static let brandWarmBlack = appPrimaryText
    static let brandAccent = appAccent

    static let luxuryPrimary = Color(hex: "#6E5155")
    static let luxuryDeepAccent = Color(hex: "#4A2E32")
    static let luxuryBackground = Color(hex: "#F5EFEF")
    static let luxurySurface = Color(hex: "#E6DADA")
    static let luxuryPrimaryText = Color(hex: "#1A1A1A")
    static let luxurySecondaryText = Color(hex: "#6B5B5B")
    static let luxuryMutedText = Color(hex: "#9A8A8A")
    static let luxuryDivider = Color.black.opacity(0.1)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

public enum BrandFont {
    public static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

public enum AppTheme {
    public static let cardCornerRadius: CGFloat = 16
    public static let buttonCornerRadius: CGFloat = 12
    public static let sectionSpacing: CGFloat = 24
    public static let contentSpacing: CGFloat = 16
    public static let compactSpacing: CGFloat = 12
    public static let tagCornerRadius: CGFloat = 6
    public static let floatingButtonSize: CGFloat = 56
    public static let toolbarButtonSize: CGFloat = 34
}

public extension View {
    func appCardChrome() -> some View {
        self
            .background(CatalogTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: CatalogTheme.cardCornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }

    func appPrimaryButtonChrome(enabled: Bool = true) -> some View {
        self
            .background(enabled ? Color.appAccent : CatalogTheme.inactiveBadge)
            .foregroundColor(enabled ? .white : CatalogTheme.inactiveBadgeText)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
    }

    func luxuryPrimaryButtonChrome(enabled: Bool = true, cornerRadius: CGFloat = 16) -> some View {
        self
            .background(enabled ? Color.luxuryDeepAccent : Color.luxuryDeepAccent.opacity(0.45))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    func headingStyle() -> some View {
        self
            .font(.system(size: 18, weight: .bold, design: .serif))
            .foregroundColor(CatalogTheme.primaryText)
    }
}

public struct LuxuryPressStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: configuration.isPressed)
    }
}

public struct AppPlusIconButton: View {
    let size: CGFloat

    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        Image(systemName: "plus")
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(CatalogTheme.brandDeep)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

public struct AppCardChevron: View {
    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundColor(CatalogTheme.secondaryText)
    }
}

public struct ReusableCardView<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCardChrome()
    }
}
