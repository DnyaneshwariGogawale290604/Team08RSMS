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
    public var itemId: String
    public var issueType: String
    public var description: String
    public var status: RepairStatus
    public var assignedTo: String?
    public var eta: Date?
    public var createdAt: Date
    public var updatedAt: Date

    // Maps Swift camelCase → Supabase snake_case column names
    enum CodingKeys: String, CodingKey {
        case id
        case itemId       = "item_id"
        case issueType    = "issue_type"
        case description
        case status
        case assignedTo   = "assigned_to"
        case eta
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    // Custom decoder: handles Postgres date-only format "yyyy-MM-dd" for eta
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        itemId      = try c.decode(String.self, forKey: .itemId)
        issueType   = try c.decode(String.self, forKey: .issueType)
        description = try c.decode(String.self, forKey: .description)
        status      = try c.decode(RepairStatus.self, forKey: .status)
        assignedTo  = try c.decodeIfPresent(String.self, forKey: .assignedTo)
        createdAt   = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt   = (try? c.decode(Date.self, forKey: .updatedAt)) ?? Date()

        // Try full Date decode first; fall back to date-only string from Postgres
        if let date = try? c.decodeIfPresent(Date.self, forKey: .eta) {
            eta = date
        } else if let etaStr = try? c.decodeIfPresent(String.self, forKey: .eta) {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            eta = df.date(from: etaStr ?? "")
        } else {
            eta = nil
        }
    }

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
    public var id: String           // RFID Tag (e.g., RFID-9001)
    public var serialId: String
    public var productId: UUID
    public var batchNo: String
    public var certificateId: String?
    public var productName: String
    public var category: String
    public var location: String
    public var status: ItemStatus
    public var activeTicket: RepairTicket?  // Comes from the DB view as nested JSON
    public var timestamp: Date

    // Maps Swift camelCase → Supabase snake_case column names
    enum CodingKeys: String, CodingKey {
        case id
        case serialId       = "serial_id"
        case productId      = "product_id"
        case batchNo        = "batch_no"
        case certificateId  = "certificate_id"
        case productName    = "product_name"
        case category
        case location
        case status
        case activeTicket   = "active_ticket"
        case timestamp
    }

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
