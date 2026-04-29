import SwiftUI

public struct EmptyStateView: View {
    public let icon: String
    public let title: String
    public let message: String
    
    public init(icon: String, title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color.appAccent)
            
            Text(title)
                .headingStyle()
            
            Text(message)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(Color.appSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
