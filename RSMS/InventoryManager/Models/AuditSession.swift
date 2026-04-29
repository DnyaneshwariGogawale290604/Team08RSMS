import Foundation

// MARK: - AuditSession Model
public struct AuditSession: Identifiable, Codable, Sendable {
    public var id: UUID
    public var location: String
    public var startedAt: Date
    public var completedAt: Date?
    public var expectedItemIds: [String]
    public var scannedRFIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case location
        case startedAt      = "started_at"
        case completedAt    = "completed_at"
        case expectedItemIds = "expected_item_ids"
        case scannedRFIDs   = "scanned_rfids"
    }

    public init(
        id: UUID = UUID(),
        location: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        expectedItemIds: [String] = [],
        scannedRFIDs: [String] = []
    ) {
        self.id = id
        self.location = location
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.expectedItemIds = expectedItemIds
        self.scannedRFIDs = scannedRFIDs
    }

    /// Items expected but NOT scanned
    public func missingRFIDs() -> [String] {
        let scanned = Set(scannedRFIDs)
        return expectedItemIds.filter { !scanned.contains($0) }
    }

    /// RFIDs that were scanned more than once
    public func duplicateRFIDs() -> [String] {
        var freq: [String: Int] = [:]
        scannedRFIDs.forEach { freq[$0, default: 0] += 1 }
        return freq.filter { $0.value > 1 }.map(\.key)
    }
}
