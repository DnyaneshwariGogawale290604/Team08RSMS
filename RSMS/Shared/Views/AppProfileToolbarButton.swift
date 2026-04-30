import SwiftUI

public struct AppProfileToolbarButton: View {
    public init() {}

    public var body: some View {
        Image(systemName: "person.crop.circle")
            .font(.system(size: 24))
            .foregroundColor(.black)
            .frame(width: 36, height: 36)
            .background(Color.white)
            .clipShape(Circle())
            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
            .accessibilityLabel("Account")
    }
}
