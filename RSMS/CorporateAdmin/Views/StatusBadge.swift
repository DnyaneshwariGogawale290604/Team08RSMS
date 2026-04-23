import SwiftUI

public struct StatusBadge: View {
    public let isActive: Bool
    
    public init(isActive: Bool) {
        self.isActive = isActive
    }
    
    public var body: some View {
        Text(isActive ? "Active" : "Inactive")
            .font(.caption2)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isActive ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
            .foregroundColor(isActive ? .green : .red)
            .clipShape(Capsule())
    }
}
