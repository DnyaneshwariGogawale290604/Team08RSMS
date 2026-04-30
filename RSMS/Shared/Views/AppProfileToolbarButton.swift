import SwiftUI

public struct AppProfileToolbarButton: View {
    public init() {}

    public var body: some View {
        Image(systemName: "person.crop.circle")
            .font(.system(size: 24))
            .foregroundColor(.white)
            .accessibilityLabel("Account")
    }
}
