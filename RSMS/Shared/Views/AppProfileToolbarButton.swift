import SwiftUI

public struct AppProfileToolbarButton: View {
    public init() {}

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)

            Circle()
                .stroke(BoutiqueTheme.primary, lineWidth: 1)
                .frame(width: 36, height: 36)

            Image(systemName: "person.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BoutiqueTheme.primaryText)
        }
        .accessibilityLabel("Account")
    }
}
