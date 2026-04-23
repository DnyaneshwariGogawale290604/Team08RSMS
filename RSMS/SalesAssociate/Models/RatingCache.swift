import Foundation
import Combine

/// In-memory cache for the current sales associate's rating.
/// Populated once from Supabase on app load; updated locally on every new
/// rating submission using incremental averaging — no re-fetch required.
@MainActor
final class RatingCache: ObservableObject {

    static let shared = RatingCache()
    private init() {}

    @Published private(set) var averageRating: Double = 0
    @Published private(set) var ratingsCount: Int = 0

    /// Called once during the initial dashboard refresh.
    /// Sets the baseline average and count from the full remote data.
    func seed(average: Double, count: Int) {
        averageRating = average
        ratingsCount  = count
    }

    /// Adds a new rating locally without a network fetch.
    /// Uses the incremental mean formula:
    ///   newAvg = (oldAvg × oldCount + newValue) / (oldCount + 1)
    func addRating(_ value: Double) {
        let newCount = ratingsCount + 1
        averageRating = (averageRating * Double(ratingsCount) + value) / Double(newCount)
        ratingsCount  = newCount
    }
}
