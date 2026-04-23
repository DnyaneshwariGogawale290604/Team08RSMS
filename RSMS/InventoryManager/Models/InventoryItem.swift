import Foundation

public enum InventoryStatus: String, Codable, CaseIterable, Sendable {
    case available = "Available"
    case reserved = "Reserved"
    case inTransit = "In Transit"
    case sold = "Sold"
}

public struct InventoryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String // RFID Tag acts as ID (e.g., RFID-0001)
    public var serialId: String
    public var productId: UUID
    public var batchNo: String
    public var certificateId: String?
    public var productName: String
    public var category: String
    public var location: String
    public var status: InventoryStatus
    public var timestamp: Date
    
    public init(id: String, serialId: String, productId: UUID, batchNo: String, certificateId: String? = nil, productName: String, category: String, location: String, status: InventoryStatus, timestamp: Date = Date()) {
        self.id = id
        self.serialId = serialId
        self.productId = productId
        self.batchNo = batchNo
        self.certificateId = certificateId
        self.productName = productName
        self.category = category
        self.location = location
        self.status = status
        self.timestamp = timestamp
    }
}
