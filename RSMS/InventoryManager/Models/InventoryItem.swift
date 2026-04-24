import Foundation

public enum ItemStatus: String, Codable, CaseIterable, Sendable {
    case available = "Available"
    case reserved = "Reserved"
    case inTransit = "In Transit"
    case underRepair = "Under Repair"
    case scrapped = "Scrapped"
    case sold = "Sold"
}

public enum RepairStatus: String, Codable, CaseIterable, Sendable {
    case created = "Created"
    case diagnosed = "Diagnosed"
    case inRepair = "In Repair"
    case qaCheck = "QA Check"
    case completed = "Completed"
    case failed = "Failed"
    case scrapped = "Scrapped"
}

public struct RepairTicket: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var itemId: String // UUID of Item or RFID depending on what item.id is
    public var issueType: String
    public var description: String
    public var status: RepairStatus
    public var assignedTo: String?
    public var eta: Date?
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(id: UUID = UUID(), itemId: String, issueType: String, description: String, status: RepairStatus = .created, assignedTo: String? = nil, eta: Date? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.itemId = itemId
        self.issueType = issueType
        self.description = description
        self.status = status
        self.assignedTo = assignedTo
        self.eta = eta
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
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
    public var status: ItemStatus
    public var activeTicket: RepairTicket?
    public var timestamp: Date
    
    public init(id: String, serialId: String, productId: UUID, batchNo: String, certificateId: String? = nil, productName: String, category: String, location: String, status: ItemStatus, activeTicket: RepairTicket? = nil, timestamp: Date = Date()) {
        self.id = id
        self.serialId = serialId
        self.productId = productId
        self.batchNo = batchNo
        self.certificateId = certificateId
        self.productName = productName
        self.category = category
        self.location = location
        self.status = status
        self.activeTicket = activeTicket
        self.timestamp = timestamp
    }
}
