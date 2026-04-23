import SwiftUI

public struct LoadingView: View {
    public let message: String
    
    public init(message: String = "Loading...") {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.appAccent)
            
            Text(message)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(Color.appSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
