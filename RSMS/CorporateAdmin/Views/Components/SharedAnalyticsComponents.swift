import SwiftUI

// MARK: - Activity Ring View
public struct ActivityRingView: View {
    public let progress: Double
    
    public init(progress: Double) {
        self.progress = progress
    }
    
    public var body: some View {
        ZStack {
            // Background Ring
            Circle()
                .stroke(CatalogTheme.surface, lineWidth: 12)
            
            // Base Progress Ring (0-100%)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    CatalogTheme.primary,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            // Overlapping Ring (if progress > 100%)
            if progress > 1.0 {
                let overlapProgress = progress.truncatingRemainder(dividingBy: 1.0)
                let finalOverlap = (overlapProgress == 0 && progress > 1.0) ? 1.0 : overlapProgress
                
                Circle()
                    .trim(from: 0, to: finalOverlap)
                    .stroke(
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .foregroundStyle(CatalogTheme.primary)
                    .brightness(0.3)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            
            VStack(spacing: 4) {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(CatalogTheme.primaryText)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                
                Text("Achieved")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(CatalogTheme.secondaryText)
                    .textCase(.uppercase)
            }
        }
    }
}

public func formatShortCurrency(_ value: Double) -> String {
    if value >= 10_000_000 {
        return String(format: "₹%.1fCr", value / 10_000_000)
    } else if value >= 100_000 {
        return String(format: "₹%.1fL", value / 100_000)
    } else if value >= 1_000 {
        return String(format: "₹%.1fK", value / 1_000)
    } else {
        return String(format: "₹%.0f", value)
    }
}
