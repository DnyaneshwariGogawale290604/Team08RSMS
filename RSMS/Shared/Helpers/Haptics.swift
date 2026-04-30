import SwiftUI
import UIKit

/// Centralized utility for haptic feedback, a key accessibility feature for tactile confirmation.
public struct Haptics {
    public static let shared = Haptics()
    
    private init() {}
    
    /// Triggers a success notification vibration (standard for completions like orders).
    public func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// Triggers an error notification vibration.
    public func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    /// Triggers a warning notification vibration.
    public func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// Triggers a light impact (good for button taps).
    public func lightImpact() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// Triggers a medium impact.
    public func mediumImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}
