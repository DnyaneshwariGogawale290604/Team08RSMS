import SwiftUI

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 999
}

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color(hex: "#9B4444"))

            Text(message)
                .font(BrandFont.body(13))
                .foregroundStyle(Color.luxuryPrimaryText)

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.luxurySecondaryText)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color(hex: "#9B4444").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color(hex: "#9B4444").opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.md)
    }
}

struct BadgeView: View {
    let text: String
    var color: Color = .luxurySecondaryText

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(CatalogTheme.primaryText)

            Spacer()

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(BrandFont.body(13))
                    .foregroundStyle(Color.luxuryPrimary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }
}

struct BrandDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.luxuryDivider)
            .frame(height: 0.5)
    }
}

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(Color.white)
                } else {
                    Text(title)
                        .font(BrandFont.body(15, weight: .semibold))
                        .kerning(0.3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isDisabled ? Color.luxuryMutedText : Color.luxuryDeepAccent)
            .foregroundStyle(isDisabled ? Color.luxurySecondaryText : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(LuxuryPressStyle())
    }
}
