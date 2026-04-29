import Foundation

// MARK: - Audit Log Action Enum
public enum AuditLogAction: String, Codable, Sendable {
    case scanned       = "Scanned"
    case repairCreated = "Repair Created"
    case repairClosed  = "Repair Closed"
    case moved         = "Location Updated"
    case statusChanged = "Status Changed"
    case added         = "Added to Inventory"
    case flaggedMissing = "Flagged Missing"
}

// MARK: - AuditLog Model
public struct AuditLog: Identifiable, Codable, Sendable {
    public let id: UUID
    public let itemId: String
    public let action: AuditLogAction
    public let timestamp: Date
    public let userId: String?
    public let metadata: String?   // JSON string or plain text note

    enum CodingKeys: String, CodingKey {
        case id
        case itemId    = "item_id"
        case action
        case timestamp
        case userId    = "user_id"
        case metadata
    }

    public init(
        id: UUID = UUID(),
        itemId: String,
        action: AuditLogAction,
        timestamp: Date = Date(),
        userId: String? = nil,
        metadata: String? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.action = action
        self.timestamp = timestamp
        self.userId = userId
        self.metadata = metadata
    }
}
